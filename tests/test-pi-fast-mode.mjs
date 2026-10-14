import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { mock, test } from "node:test";
import { fileURLToPath, pathToFileURL } from "node:url";

const repoDir = fileURLToPath(new URL("..", import.meta.url));
const piDir = process.env.PI_PACKAGE_DIR ?? join(
	execFileSync("npm", ["root", "-g"], { encoding: "utf8", timeout: 10_000 }).trim(),
	"@earendil-works/pi-coding-agent",
);
const loaderPath = join(piDir, "dist/core/extensions/loader.js");

if (!existsSync(loaderPath)) {
	test("Pi fast-mode integration", { skip: "Requires an installed Pi npm package" }, () => {});
} else {
	const { loadExtensions } = await import(pathToFileURL(loaderPath).href);
	const { SessionManager } = await import(pathToFileURL(join(piDir, "dist/core/session-manager.js")).href);

	async function createHarness(t, id = "gpt-6.1-sol") {
		const loaded = await loadExtensions([join(repoDir, "dot/.pi/agent/extensions/openai-fast-mode.ts")], repoDir);
		assert.deepEqual(loaded.errors, []);
		assert.equal(loaded.extensions.length, 1);
		const extension = loaded.extensions[0];
		const notices = [];
		let footer;
		loaded.runtime.getThinkingLevel = () => "xhigh";
		const ctx = {
			model: { provider: "openai-codex", id, reasoning: true, contextWindow: 200_000 },
			sessionManager: SessionManager.inMemory(repoDir),
			getContextUsage: () => undefined,
			ui: {
				notify: (text, level) => notices.push({ text, level }),
				setStatus() {},
				setFooter: (factory) => { footer = factory; },
			},
		};
		async function emit(type, fields = {}) {
			let result;
			for (const handler of extension.handlers.get(type) ?? []) {
				result = await handler({ type, ...fields }, ctx);
			}
			return result;
		}
		t.after(() => emit("session_shutdown"));
		return {
			ctx, notices, emit,
			command: (args) => extension.commands.get("fast").handler(args, ctx),
			request: async (payload = { model: ctx.model?.id, input: "hello" }) =>
				(await emit("before_provider_request", { payload })) ?? payload,
			footerText() {
				assert.equal(typeof footer, "function");
				const component = footer(
					{ requestRender() {} },
					{ fg: (_color, text) => text },
					{ getGitBranch: () => undefined, getExtensionStatuses: () => new Map(), onBranchChange: () => () => {} },
				);
				try { return component.render(160).join("\n"); }
				finally { component.dispose(); }
			},
			get hasFooter() { return footer !== undefined; },
		};
	}

	test("/fast controls priority for the current Codex model, including unknown future IDs", async (t) => {
		const h = await createHarness(t);
		for (const id of ["gpt-6.1-sol", "gpt-future", "gpt-5.6-sol"]) {
			h.ctx.model.id = id;
			await h.emit("model_select");
			assert.deepEqual(await h.request(), { model: id, input: "hello", service_tier: "priority" });
			await h.command("off");
			assert.match(h.notices.at(-1).text, new RegExp(`Fast mode off for ${id.replaceAll(".", "\\.")}`));
			assert.deepEqual(await h.request(), { model: id, input: "hello" });
			await h.command("on");
			assert.deepEqual(await h.request(), { model: id, input: "hello", service_tier: "priority" });
		}
	});

	test("status, footer and toggles follow model switches without resetting the chosen mode", async (t) => {
		const h = await createHarness(t);
		await h.emit("session_start");
		assert.match(h.footerText(), /0\.0 TPS.*gpt-6\.1-sol.*fast/);
		await h.command("");
		assert.deepEqual(await h.request(), { model: "gpt-6.1-sol", input: "hello" });
		h.ctx.model.id = "gpt-future";
		await h.emit("model_select");
		await h.command("status");
		assert.equal(h.notices.at(-1).text, "Fast mode off for gpt-future. Latest: fast 0.0 TPS, standard 0.0 TPS.");
		assert.match(h.footerText(), /gpt-future.*standard/);
		await h.command("toggle");
		assert.deepEqual(await h.request(), { model: "gpt-future", input: "hello", service_tier: "priority" });
		await h.command("invalid");
		assert.deepEqual(h.notices.at(-1), { text: "Usage: /fast [on|off|toggle|status]", level: "warning" });
	});

	test("TPS uses the current model's visible output and resets comparisons on model changes", async (t) => {
		const h = await createHarness(t);
		let now = 1_000;
		const clock = mock.method(performance, "now", () => now);
		t.after(() => clock.mock.restore());
		assert.equal((await h.request()).service_tier, "priority");
		const message = {
			role: "assistant", provider: "openai-codex", model: "gpt-6.1-sol",
			content: [{ type: "text", text: "visible output" }], usage: { output: 30, reasoning: 10 },
		};
		await h.emit("message_update", { message, assistantMessageEvent: { type: "text_start" } });
		now = 2_000;
		await h.emit("message_update", { message, assistantMessageEvent: { type: "text_end" } });
		await h.emit("message_end", { message });
		await h.command("status");
		assert.equal(h.notices.at(-1).text, "Fast mode on for gpt-6.1-sol. Latest: fast 20.0 TPS, standard 0.0 TPS.");
		h.ctx.model.id = "gpt-future";
		await h.emit("model_select");
		await h.command("status");
		assert.equal(h.notices.at(-1).text, "Fast mode on for gpt-future. Latest: fast 0.0 TPS, standard 0.0 TPS.");
		assert.equal((await h.request()).service_tier, "priority");
		const currentMessage = { ...message, model: "gpt-future" };
		await h.emit("message_update", { message: currentMessage, assistantMessageEvent: { type: "text_start" } });
		now = 2_500;
		await h.emit("message_end", { message }); // Ignore a late response from the previous model.
		await h.emit("message_update", { message: currentMessage, assistantMessageEvent: { type: "text_end" } });
		await h.emit("message_end", { message: currentMessage });
		await h.command("status");
		assert.equal(h.notices.at(-1).text, "Fast mode on for gpt-future. Latest: fast 40.0 TPS, standard 0.0 TPS.");
	});

	test("other providers and missing models are left alone and cannot change the toggle", async (t) => {
		const h = await createHarness(t);
		assert.equal((await h.request()).service_tier, "priority");
		h.ctx.model.provider = "anthropic";
		await h.emit("model_select");
		assert.equal(h.hasFooter, false);
		assert.deepEqual(await h.request(), { model: "gpt-6.1-sol", input: "hello" });
		await h.command("off");
		assert.equal(h.notices.at(-1).level, "warning");
		h.ctx.model = undefined;
		await h.command("off");
		assert.equal(h.notices.at(-1).level, "warning");
		h.ctx.model = { provider: "openai-codex", id: "gpt-future" };
		await h.emit("model_select");
		assert.deepEqual(await h.request(), { model: "gpt-future", input: "hello", service_tier: "priority" });
	});

	test("only matching object payloads are changed and the original request is preserved", async (t) => {
		const h = await createHarness(t);
		const original = { model: "gpt-6.1-sol", input: "hello", service_tier: "auto" };
		assert.deepEqual(await h.request(original), { model: "gpt-6.1-sol", input: "hello", service_tier: "priority" });
		assert.deepEqual(original, { model: "gpt-6.1-sol", input: "hello", service_tier: "auto" });
		for (const payload of [null, "text", [], {}, { model: "different-model" }]) {
			assert.deepEqual(await h.request(payload), payload);
		}
	});
}
