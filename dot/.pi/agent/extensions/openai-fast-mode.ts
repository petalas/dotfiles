import { isAbsolute, relative, resolve, sep } from "node:path";
import type { AssistantMessage, Usage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const TARGET_PROVIDER = "openai-codex";
const TARGET_MODEL = "gpt-5.6-sol";
const SEPARATOR = " • ";
const LIVE_RENDER_INTERVAL_MS = 250;
const ROLLING_MIN_WINDOW_MS = 1_500;
const ROLLING_MAX_WINDOW_MS = 6_000;
const ROLLING_TARGET_TOKENS = 32;
const MIN_RATE_INTERVAL_MS = 250;
const DEFAULT_CHARS_PER_TOKEN = 4;
const MIN_CHARS_PER_TOKEN = 2;
const MAX_CHARS_PER_TOKEN = 8;
const SAMPLE_INTERVAL_MS = 75;

type Mode = "fast" | "standard";

type ThroughputSample = {
	at: number;
	chars: number;
};

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
	return `${(tps ?? 0).toFixed(1)} TPS`;
}

/**
 * Estimate the current token rate with an adaptive rolling window.
 *
 * Fast streams use at least 1.5 seconds to avoid chunk-boundary jitter. Slow
 * streams expand toward six seconds until the window contains about 32 tokens.
 * A recency-weighted regression is steadier than dividing the newest chunk by
 * its arrival interval, while a synthetic sample at `now` lets the rate decay
 * naturally when a stream stalls.
 */
function estimateRollingTps(
	samples: ThroughputSample[],
	now: number,
	charsPerToken: number,
): number | undefined {
	if (samples.length < 2) return undefined;
	const newest = samples[samples.length - 1];
	if (!newest || now - newest.at >= ROLLING_MAX_WINDOW_MS) return 0;

	let startIndex = samples.length - 2;
	for (let index = samples.length - 2; index >= 0; index--) {
		const sample = samples[index];
		if (!sample) continue;
		startIndex = index;
		const elapsed = now - sample.at;
		const estimatedTokens = (newest.chars - sample.chars) / charsPerToken;
		if (elapsed >= ROLLING_MAX_WINDOW_MS) break;
		if (elapsed >= ROLLING_MIN_WINDOW_MS && estimatedTokens >= ROLLING_TARGET_TOKENS) break;
	}

	const first = samples[startIndex];
	if (!first || now - first.at < MIN_RATE_INTERVAL_MS) return undefined;

	const points = samples.slice(startIndex);
	if (now > newest.at) points.push({ at: now, chars: newest.chars });
	const windowMs = Math.max(MIN_RATE_INTERVAL_MS, now - first.at);
	const decayMs = Math.max(MIN_RATE_INTERVAL_MS, windowMs / 2);

	let weightTotal = 0;
	let weightedTime = 0;
	let weightedTokens = 0;
	for (const point of points) {
		const weight = Math.exp(-(now - point.at) / decayMs);
		weightTotal += weight;
		weightedTime += weight * ((point.at - first.at) / 1_000);
		weightedTokens += weight * (point.chars / charsPerToken);
	}
	if (weightTotal === 0) return undefined;

	const meanTime = weightedTime / weightTotal;
	const meanTokens = weightedTokens / weightTotal;
	let covariance = 0;
	let timeVariance = 0;
	for (const point of points) {
		const weight = Math.exp(-(now - point.at) / decayMs);
		const time = (point.at - first.at) / 1_000;
		const tokens = point.chars / charsPerToken;
		covariance += weight * (time - meanTime) * (tokens - meanTokens);
		timeVariance += weight * (time - meanTime) ** 2;
	}

	return timeVariance > 0 ? Math.max(0, covariance / timeVariance) : undefined;
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
	let streamedTextChars = 0;
	let throughputSamples: ThroughputSample[] = [];
	let liveTps = 0;
	let hasLiveEstimate = false;
	let liveRateUpdatedAt: number | undefined;
	let liveRenderTimer: ReturnType<typeof setInterval> | undefined;
	let requestRender: (() => void) | undefined;
	const latestTps: Partial<Record<Mode, number>> = {};
	const charsPerToken: Record<Mode, number> = {
		fast: DEFAULT_CHARS_PER_TOKEN,
		standard: DEFAULT_CHARS_PER_TOKEN,
	};

	function mode(): Mode {
		return fastMode ? "fast" : "standard";
	}

	function renderFooter(): void {
		requestRender?.();
	}

	function stopLiveRenderTimer(): void {
		if (liveRenderTimer !== undefined) clearInterval(liveRenderTimer);
		liveRenderTimer = undefined;
	}

	function updateLiveTps(now: number): void {
		const activeMode = requestMode;
		if (!activeMode) return;
		const estimate = estimateRollingTps(throughputSamples, now, charsPerToken[activeMode]);
		if (estimate === undefined) {
			if (!hasLiveEstimate) liveTps = 0;
			return;
		}

		if (!hasLiveEstimate || liveRateUpdatedAt === undefined) {
			liveTps = estimate;
			hasLiveEstimate = true;
		} else {
			const elapsed = Math.max(0, now - liveRateUpdatedAt);
			// React quickly to acceleration, but release more slowly to suppress
			// transient network gaps between provider chunks.
			const timeConstant = estimate > liveTps ? 450 : 900;
			const alpha = 1 - Math.exp(-elapsed / timeConstant);
			liveTps += alpha * (estimate - liveTps);
		}
		liveRateUpdatedAt = now;
	}

	function startLiveRenderTimer(): void {
		stopLiveRenderTimer();
		liveRenderTimer = setInterval(() => {
			updateLiveTps(performance.now());
			renderFooter();
		}, LIVE_RENDER_INTERVAL_MS);
	}

	function resetLiveRequest(): void {
		stopLiveRenderTimer();
		requestMode = undefined;
		textStartedAt = undefined;
		textEndedAt = undefined;
		streamedTextChars = 0;
		throughputSamples = [];
		liveTps = 0;
		hasLiveEstimate = false;
		liveRateUpdatedAt = undefined;
	}

	function recordTextDelta(delta: string, now: number): void {
		streamedTextChars += delta.length;
		const latest = throughputSamples[throughputSamples.length - 1];
		if (latest && throughputSamples.length > 1 && now - latest.at < SAMPLE_INTERVAL_MS) {
			latest.at = now;
			latest.chars = streamedTextChars;
		} else {
			throughputSamples.push({ at: now, chars: streamedTextChars });
		}

		const oldestAllowed = now - ROLLING_MAX_WINDOW_MS * 1.25;
		while (throughputSamples.length > 2 && (throughputSamples[1]?.at ?? now) < oldestAllowed) {
			throughputSamples.shift();
		}
		updateLiveTps(now);
	}

	function displayedTps(): number {
		return requestMode === mode() ? liveTps : (latestTps[mode()] ?? 0);
	}

	function installFooter(ctx: ExtensionContext): void {
		ctx.ui.setFooter((tui, theme, footerData) => {
			const footerRender = () => tui.requestRender();
			requestRender = footerRender;
			const unsubscribe = footerData.onBranchChange(footerRender);

			return {
				dispose() {
					unsubscribe();
					if (requestRender === footerRender) requestRender = undefined;
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

					if (isTargetModel(ctx)) stats.push(formatTps(displayedTps()));

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
		resetLiveRequest();
		if (isTargetModel(ctx)) {
			installFooter(ctx);
		} else {
			ctx.ui.setFooter(undefined);
			requestRender = undefined;
		}
	});

	pi.on("thinking_level_select", () => {
		renderFooter();
	});

	pi.on("before_provider_request", (event, ctx) => {
		resetLiveRequest();

		if (!isTargetModel(ctx)) return;
		requestMode = mode();
		startLiveRenderTimer();
		renderFooter();
		if (!fastMode || !event.payload || typeof event.payload !== "object") return;

		const payload = event.payload as RequestPayload;
		if (payload.model !== TARGET_MODEL) return;
		return { ...payload, service_tier: "priority" };
	});

	pi.on("message_update", (event) => {
		if (event.message.role !== "assistant" || requestMode === undefined) return;
		const message = event.message as AssistantMessage;
		if (message.provider !== TARGET_PROVIDER || message.model !== TARGET_MODEL) return;

		const now = performance.now();
		if (event.assistantMessageEvent.type === "text_start" && textStartedAt === undefined) {
			textStartedAt = now;
			throughputSamples = [{ at: now, chars: streamedTextChars }];
		}
		if (event.assistantMessageEvent.type === "text_delta") {
			if (textStartedAt === undefined) {
				textStartedAt = now;
				throughputSamples = [{ at: now, chars: streamedTextChars }];
			}
			recordTextDelta(event.assistantMessageEvent.delta, now);
		}
		if (event.assistantMessageEvent.type === "text_end") textEndedAt = now;
		renderFooter();
	});

	pi.on("message_end", (event) => {
		if (event.message.role !== "assistant") return;
		const message = event.message as AssistantMessage;
		if (message.provider !== TARGET_PROVIDER || message.model !== TARGET_MODEL) return;

		const startedAt = textStartedAt;
		const endedAt = textEndedAt ?? performance.now();
		const completedMode = requestMode;
		const completedTextChars = streamedTextChars;
		resetLiveRequest();

		const visibleOutput = message.usage.output - (message.usage.reasoning ?? 0);
		if (startedAt !== undefined && completedMode !== undefined && visibleOutput > 0 && endedAt > startedAt) {
			latestTps[completedMode] = visibleOutput / ((endedAt - startedAt) / 1_000);

			// Calibrate the next stream's character-based live estimate against
			// provider usage. Tool-call JSON can be counted in output usage without
			// appearing in text deltas, so only clean text responses train it.
			const hasToolCall = message.content.some((block) => block.type === "toolCall");
			if (!hasToolCall && visibleOutput >= 16 && completedTextChars >= 32) {
				const observed = Math.min(
					MAX_CHARS_PER_TOKEN,
					Math.max(MIN_CHARS_PER_TOKEN, completedTextChars / visibleOutput),
				);
				const confidence = Math.min(0.35, visibleOutput / 400);
				charsPerToken[completedMode] += confidence * (observed - charsPerToken[completedMode]);
			}
		}
		renderFooter();
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

			resetLiveRequest();
			renderFooter();
			ctx.ui.notify(
				`Fast mode ${fastMode ? "on" : "off"} for ${TARGET_MODEL}. Latest: fast ${formatTps(latestTps.fast)}, standard ${formatTps(latestTps.standard)}.`,
				"info",
			);
		},
	});

	pi.on("session_shutdown", () => {
		resetLiveRequest();
	});
}
