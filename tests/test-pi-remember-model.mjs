import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath, pathToFileURL } from "node:url";

const repoDir = fileURLToPath(new URL("..", import.meta.url));
const piDir = process.env.PI_PACKAGE_DIR ?? join(
	execFileSync("npm", ["root", "-g"], { encoding: "utf8", timeout: 10_000 }).trim(),
	"@earendil-works/pi-coding-agent",
);
const loaderPath = join(piDir, "dist/core/extensions/loader.js");

if (!existsSync(loaderPath)) {
	test("Pi model persistence integration", { skip: "Requires an installed Pi npm package" }, () => {});
} else {
	const { discoverAndLoadExtensions } = await import(pathToFileURL(loaderPath).href);
	const { SettingsManager } = await import(pathToFileURL(join(piDir, "dist/core/settings-manager.js")).href);
	const { findInitialModel } = await import(pathToFileURL(join(piDir, "dist/core/model-resolver.js")).href);
	const oldModel = { provider: "openai-codex", id: "gpt-5.6-sol" };
	const nextModel = { provider: "openai-codex", id: "gpt-6.1-sol" };

	async function createHarness(t) {
		const dir = mkdtempSync(join(tmpdir(), "dotfiles-pi-model-"));
		const agentDir = join(dir, "agent");
		const cwd = join(dir, "project");
		mkdirSync(agentDir);
		mkdirSync(cwd);
		const settingsPath = join(agentDir, "settings.json");
		const initialSettings = {
			defaultProvider: oldModel.provider, defaultModel: oldModel.id,
			theme: "seashells", defaultThinkingLevel: "xhigh",
		};
		writeFileSync(settingsPath, JSON.stringify(initialSettings));
		symlinkSync(join(repoDir, "dot/.pi/agent/extensions"), join(agentDir, "extensions"), "dir");
		const previousAgentDir = process.env.PI_CODING_AGENT_DIR;
		process.env.PI_CODING_AGENT_DIR = agentDir;
		t.after(() => {
			if (previousAgentDir === undefined) delete process.env.PI_CODING_AGENT_DIR;
			else process.env.PI_CODING_AGENT_DIR = previousAgentDir;
			rmSync(dir, { recursive: true, force: true });
		});
		const loaded = await discoverAndLoadExtensions([], cwd, agentDir);
		assert.deepEqual(loaded.errors, []);
		const ctx = { cwd, mode: "tui", model: oldModel, ui: { setFooter() {}, setStatus() {} } };
		async function emit(type, fields = {}) {
			for (const extension of loaded.extensions) {
				for (const handler of extension.handlers.get(type) ?? []) await handler({ type, ...fields }, ctx);
			}
		}
		return {
			ctx, cwd, settingsPath, initialSettings, emit,
			settings: () => JSON.parse(readFileSync(settingsPath, "utf8")),
			async select(model = nextModel, source = "set") {
				const previousModel = ctx.model;
				ctx.model = model;
				await emit("model_select", { model, previousModel, source });
			},
			async startupModel(models = [oldModel, nextModel]) {
				const settings = SettingsManager.create(cwd, agentDir);
				const result = await findInitialModel({
					scopedModels: [], isContinuing: false,
					defaultProvider: settings.getDefaultProvider(), defaultModelId: settings.getDefaultModel(),
					modelRuntime: {
						getModel: (provider, id) => models.find((model) => model.provider === provider && model.id === id),
						hasConfiguredAuth: () => true, getAvailableSnapshot: () => models,
					},
				});
				return result.model;
			},
		};
	}

	test("a /model selection becomes the next fresh session's model", async (t) => {
		const h = await createHarness(t);
		assert.deepEqual(await h.startupModel(), oldModel);
		await h.select();
		assert.deepEqual(await h.startupModel(), nextModel);
		assert.deepEqual(h.settings(), { ...h.initialSettings, defaultModel: "gpt-6.1-sol" });
	});

	test("cycling and other providers remember the last choice without model ID pins", async (t) => {
		const h = await createHarness(t);
		await h.select();
		const future = { provider: "openai-codex", id: "gpt-future" };
		await h.select(future, "cycle");
		assert.deepEqual(await h.startupModel([oldModel, nextModel, future]), future);
		const other = { provider: "anthropic", id: "claude-future" };
		await h.select(other);
		assert.deepEqual(await h.startupModel([oldModel, nextModel, other]), other);
	});

	test("startup and restoring an older session do not replace the last explicit choice", async (t) => {
		const h = await createHarness(t);
		await h.emit("session_start");
		assert.deepEqual(h.settings(), h.initialSettings);
		await h.select();
		await h.select(oldModel, "restore");
		assert.deepEqual(await h.startupModel(), nextModel);
	});

	test("automated invocations do not change interactive defaults", async (t) => {
		const h = await createHarness(t);
		for (const mode of ["rpc", "json", "print"]) {
			h.ctx.mode = mode;
			await h.select();
			assert.deepEqual(h.settings(), h.initialSettings);
		}
	});

	test("model persistence preserves external preference edits and project settings", async (t) => {
		const h = await createHarness(t);
		writeFileSync(h.settingsPath, JSON.stringify({ ...h.initialSettings, theme: "seashells-light" }));
		mkdirSync(join(h.cwd, ".pi"));
		const projectPath = join(h.cwd, ".pi/settings.json");
		const projectSettings = '{"defaultModel":"project-model"}';
		writeFileSync(projectPath, projectSettings);
		await h.select();
		assert.deepEqual(h.settings(), { ...h.initialSettings, defaultModel: "gpt-6.1-sol", theme: "seashells-light" });
		assert.equal(readFileSync(projectPath, "utf8"), projectSettings);
	});

	test("invalid settings are reported without replacing the file", async (t) => {
		const h = await createHarness(t);
		writeFileSync(h.settingsPath, "{invalid json\n");
		await assert.rejects(h.select(), /JSON|Unexpected|property/);
		assert.equal(readFileSync(h.settingsPath, "utf8"), "{invalid json\n");
	});
}
