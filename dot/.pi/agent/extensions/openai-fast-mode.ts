import { isAbsolute, relative, resolve, sep } from "node:path";
import type { AssistantMessage, Usage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const TARGET_PROVIDER = "openai-codex";
const TARGET_MODEL = "gpt-5.6-sol";
const SEPARATOR = " • ";

type Mode = "fast" | "standard";

type RequestPayload = Record<string, unknown> & {
	model?: unknown;
	service_tier?: unknown;
};

type UsageEntry = {
	type: string;
	message?: {
		role?: string;
		usage?: Usage;
	};
	usage?: Usage;
};

function isTargetModel(ctx: ExtensionContext): boolean {
	return ctx.model?.provider === TARGET_PROVIDER && ctx.model.id === TARGET_MODEL;
}

function formatTps(tps: number | undefined): string {
	return tps === undefined ? "-- TPS" : `${tps.toFixed(1)} TPS`;
}

function formatTokens(count: number): string {
	if (count < 1_000) return count.toString();
	if (count < 10_000) return `${(count / 1_000).toFixed(1)}k`;
	if (count < 1_000_000) return `${Math.round(count / 1_000)}k`;
	if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
	return `${Math.round(count / 1_000_000)}M`;
}

function formatCwd(cwd: string): string {
	const home = process.env.HOME ?? process.env.USERPROFILE;
	if (!home) return cwd;

	const relativeToHome = relative(resolve(home), resolve(cwd));
	const insideHome =
		relativeToHome === "" ||
		(relativeToHome !== ".." && !relativeToHome.startsWith(`..${sep}`) && !isAbsolute(relativeToHome));
	if (!insideHome) return cwd;
	return relativeToHome === "" ? "~" : `~${sep}${relativeToHome}`;
}

function sanitizeStatus(text: string): string {
	return text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();
}

function addUsage(target: Usage, usage: Usage): void {
	target.input += usage.input;
	target.output += usage.output;
	target.cacheRead += usage.cacheRead;
	target.cacheWrite += usage.cacheWrite;
	target.totalTokens += usage.totalTokens;
	target.cost.input += usage.cost.input;
	target.cost.output += usage.cost.output;
	target.cost.cacheRead += usage.cost.cacheRead;
	target.cost.cacheWrite += usage.cost.cacheWrite;
	target.cost.total += usage.cost.total;
}

function collectUsage(ctx: ExtensionContext): { totals: Usage; latestCacheHitRate?: number } {
	const totals: Usage = {
		input: 0,
		output: 0,
		cacheRead: 0,
		cacheWrite: 0,
		totalTokens: 0,
		cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
	};
	let latestCacheHitRate: number | undefined;

	for (const rawEntry of ctx.sessionManager.getEntries()) {
		const entry = rawEntry as UsageEntry;
		const usage = entry.type === "message" ? entry.message?.usage : entry.usage;
		if (!usage) continue;

		addUsage(totals, usage);
		if (entry.type === "message" && entry.message?.role === "assistant") {
			const promptTokens = usage.input + usage.cacheRead + usage.cacheWrite;
			latestCacheHitRate = promptTokens > 0 ? (usage.cacheRead / promptTokens) * 100 : undefined;
		}
	}

	return { totals, latestCacheHitRate };
}

function alignFooter(left: string, right: string, width: number): string {
	const leftWidth = visibleWidth(left);
	const rightWidth = visibleWidth(right);
	if (leftWidth + 2 + rightWidth <= width) {
		return left + " ".repeat(width - leftWidth - rightWidth) + right;
	}

	const availableForRight = width - leftWidth - 2;
	if (availableForRight <= 0) return truncateToWidth(left, width, "...");
	const truncatedRight = truncateToWidth(right, availableForRight, "");
	return left + " ".repeat(Math.max(2, width - leftWidth - visibleWidth(truncatedRight))) + truncatedRight;
}

export default function (pi: ExtensionAPI) {
	let fastMode = true;
	let requestMode: Mode | undefined;
	let textStartedAt: number | undefined;
	let textEndedAt: number | undefined;
	let measuring = false;
	let requestRender: (() => void) | undefined;
	const latestTps: Partial<Record<Mode, number>> = {};

	function mode(): Mode {
		return fastMode ? "fast" : "standard";
	}

	function renderFooter(ctx: ExtensionContext): void {
		requestRender?.();
	}

	function installFooter(ctx: ExtensionContext): void {
		ctx.ui.setFooter((tui, theme, footerData) => {
			requestRender = () => tui.requestRender();
			const unsubscribe = footerData.onBranchChange(requestRender);

			return {
				dispose() {
					unsubscribe();
					requestRender = undefined;
				},
				invalidate() {},
				render(width: number): string[] {
					let cwd = formatCwd(ctx.sessionManager.getCwd());
					const branch = footerData.getGitBranch();
					if (branch) cwd += ` (${branch})`;
					const sessionName = ctx.sessionManager.getSessionName();
					if (sessionName) cwd += `${SEPARATOR}${sessionName}`;

					const { totals, latestCacheHitRate } = collectUsage(ctx);
					const stats: string[] = [];
					if (totals.input) stats.push(`↑${formatTokens(totals.input)}`);
					if (totals.output) stats.push(`↓${formatTokens(totals.output)}`);
					if (totals.cacheRead) stats.push(`R${formatTokens(totals.cacheRead)}`);
					if (totals.cacheWrite) stats.push(`W${formatTokens(totals.cacheWrite)}`);
					if ((totals.cacheRead || totals.cacheWrite) && latestCacheHitRate !== undefined) {
						stats.push(`CH${latestCacheHitRate.toFixed(1)}%`);
					}
					if (totals.cost.total) stats.push(`$${totals.cost.total.toFixed(3)}`);

					const contextUsage = ctx.getContextUsage();
					const contextWindow = contextUsage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
					const contextPercent = contextUsage?.percent;
					stats.push(
						contextPercent === null || contextPercent === undefined
							? `?/${formatTokens(contextWindow)}`
							: `${contextPercent.toFixed(1)}%/${formatTokens(contextWindow)}`,
					);

					if (isTargetModel(ctx)) {
						stats.push(measuring ? "measuring…" : formatTps(latestTps[mode()]));
					}

					const rightParts = [ctx.model?.id ?? "no-model"];
					if (ctx.model?.reasoning) {
						const thinkingLevel = pi.getThinkingLevel();
						rightParts.push(thinkingLevel === "off" ? "thinking off" : thinkingLevel);
					}
					if (isTargetModel(ctx)) rightParts.push(mode());

					const statsLine = alignFooter(stats.join(" "), rightParts.join(SEPARATOR), width);
					const lines = [
						truncateToWidth(theme.fg("dim", cwd), width, theme.fg("dim", "...")),
						theme.fg("dim", statsLine),
					];

					const extensionStatuses = Array.from(footerData.getExtensionStatuses().entries())
						.sort(([a], [b]) => a.localeCompare(b))
						.map(([, text]) => sanitizeStatus(text));
					if (extensionStatuses.length > 0) {
						lines.push(truncateToWidth(extensionStatuses.join(" "), width, theme.fg("dim", "...")));
					}
					return lines;
				},
			};
		});
	}

	pi.on("session_start", (_event, ctx) => {
		// Clear the separate status line used by the first version of this extension.
		ctx.ui.setStatus("openai-fast-mode", undefined);
		if (isTargetModel(ctx)) installFooter(ctx);
	});

	pi.on("model_select", (_event, ctx) => {
		requestMode = undefined;
		textStartedAt = undefined;
		textEndedAt = undefined;
		measuring = false;
		if (isTargetModel(ctx)) {
			installFooter(ctx);
		} else {
			ctx.ui.setFooter(undefined);
			requestRender = undefined;
		}
	});

	pi.on("thinking_level_select", (_event, ctx) => {
		renderFooter(ctx);
	});

	pi.on("before_provider_request", (event, ctx) => {
		requestMode = undefined;
		textStartedAt = undefined;
		textEndedAt = undefined;
		measuring = false;

		if (!isTargetModel(ctx)) return;
		requestMode = mode();
		measuring = true;
		renderFooter(ctx);
		if (!fastMode || !event.payload || typeof event.payload !== "object") return;

		const payload = event.payload as RequestPayload;
		if (payload.model !== TARGET_MODEL) return;
		return { ...payload, service_tier: "priority" };
	});

	pi.on("message_update", (event) => {
		if (event.message.role !== "assistant") return;
		const message = event.message as AssistantMessage;
		if (message.provider !== TARGET_PROVIDER || message.model !== TARGET_MODEL) return;

		if (event.assistantMessageEvent.type === "text_start" && textStartedAt === undefined) {
			textStartedAt = performance.now();
		}
		if (event.assistantMessageEvent.type === "text_end") {
			textEndedAt = performance.now();
		}
	});

	pi.on("message_end", (event, ctx) => {
		if (event.message.role !== "assistant") return;
		const message = event.message as AssistantMessage;
		if (message.provider !== TARGET_PROVIDER || message.model !== TARGET_MODEL) return;

		const startedAt = textStartedAt;
		const endedAt = textEndedAt ?? performance.now();
		const completedMode = requestMode;
		requestMode = undefined;
		textStartedAt = undefined;
		textEndedAt = undefined;
		measuring = false;

		const visibleOutput = message.usage.output - (message.usage.reasoning ?? 0);
		if (startedAt !== undefined && completedMode !== undefined && visibleOutput > 0 && endedAt > startedAt) {
			latestTps[completedMode] = visibleOutput / ((endedAt - startedAt) / 1_000);
		}
		renderFooter(ctx);
	});

	pi.registerCommand("fast", {
		description: "Toggle OpenAI priority processing and show TPS comparisons",
		handler: async (args, ctx) => {
			const action = args.trim().toLowerCase();
			if (action === "on") fastMode = true;
			else if (action === "off") fastMode = false;
			else if (action === "" || action === "toggle") fastMode = !fastMode;
			else if (action !== "status") {
				ctx.ui.notify("Usage: /fast [on|off|toggle|status]", "warning");
				return;
			}

			requestMode = undefined;
			textStartedAt = undefined;
			textEndedAt = undefined;
			measuring = false;
			renderFooter(ctx);
			ctx.ui.notify(
				`Fast mode ${fastMode ? "on" : "off"} for ${TARGET_MODEL}. Latest: fast ${formatTps(latestTps.fast)}, standard ${formatTps(latestTps.standard)}.`,
				"info",
			);
		},
	});
}
