/**
 * Shared subagent infrastructure.
 *
 * Used by both the subagent tool (subagent.ts) and the /btw command (btw.ts).
 * Contains the core runner, types, rendering helpers, and TUI rendering.
 */

import { agentLoop } from "@mariozechner/pi-agent-core";
import type { AgentContext, AgentLoopConfig, AgentMessage, AgentTool } from "@mariozechner/pi-agent-core";
import { convertToLlm, getMarkdownTheme } from "@mariozechner/pi-coding-agent";
import type { Theme } from "@mariozechner/pi-coding-agent";
import type { Component, MarkdownTheme } from "@mariozechner/pi-tui";
import { Container, Markdown, Spacer, Text } from "@mariozechner/pi-tui";

import * as os from "node:os";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

export const MINIBOX_LINES = 10;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface UsageStats {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
	contextTokens: number;
	turns: number;
}

export interface SingleResult {
	task: string;
	exitCode: number;
	displayItems: DisplayItem[];
	finalOutput: string;
	usage: UsageStats;
	model?: string;
	stopReason?: string;
	errorMessage?: string;
}

export interface SubagentDetails {
	results: SingleResult[];
}

export type DisplayItem =
	| { type: "text"; text: string }
	| { type: "toolCall"; name: string; args: Record<string, any> };

// ---------------------------------------------------------------------------
// Usage helpers
// ---------------------------------------------------------------------------

export function emptyUsage(): UsageStats {
	return { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 };
}

export function formatTokens(n: number): string {
	if (n < 1000) return n.toString();
	if (n < 10000) return `${(n / 1000).toFixed(1)}k`;
	if (n < 1_000_000) return `${Math.round(n / 1000)}k`;
	return `${(n / 1_000_000).toFixed(1)}M`;
}

export function formatUsage(u: UsageStats, model?: string): string {
	const parts: string[] = [];
	if (u.turns) parts.push(`${u.turns} turn${u.turns > 1 ? "s" : ""}`);
	if (u.input) parts.push(`↑${formatTokens(u.input)}`);
	if (u.output) parts.push(`↓${formatTokens(u.output)}`);
	if (u.cacheRead) parts.push(`R${formatTokens(u.cacheRead)}`);
	if (u.cacheWrite) parts.push(`W${formatTokens(u.cacheWrite)}`);
	if (u.cost) parts.push(`$${u.cost.toFixed(4)}`);
	if (u.contextTokens > 0) parts.push(`ctx:${formatTokens(u.contextTokens)}`);
	if (model) parts.push(model);
	return parts.join(" ");
}

export function aggregateUsage(results: SingleResult[]): UsageStats {
	const total = emptyUsage();
	for (const r of results) {
		total.input += r.usage.input;
		total.output += r.usage.output;
		total.cacheRead += r.usage.cacheRead;
		total.cacheWrite += r.usage.cacheWrite;
		total.cost += r.usage.cost;
		total.turns += r.usage.turns;
	}
	return total;
}

// ---------------------------------------------------------------------------
// Path / tool-call formatting
// ---------------------------------------------------------------------------

export function shortenPath(p: string): string {
	const home = os.homedir();
	return p.startsWith(home) ? `~${p.slice(home.length)}` : p;
}

export function formatToolCall(
	toolName: string,
	args: Record<string, unknown>,
	fg: (color: any, text: string) => string,
): string {
	switch (toolName) {
		case "bash": {
			let cmd = (args.command as string) || "...";
			const home = os.homedir();
			cmd = cmd.replaceAll(home, "~");
			const firstLine = cmd.split("\n")[0];
			return fg("muted", "$ ") + fg("toolOutput", firstLine);
		}
		case "read": {
			const rawPath = (args.file_path || args.path || "...") as string;
			const filePath = shortenPath(rawPath);
			const offset = args.offset as number | undefined;
			const limit = args.limit as number | undefined;
			let text = fg("accent", filePath);
			if (offset !== undefined || limit !== undefined) {
				const startLine = offset ?? 1;
				const endLine = limit !== undefined ? startLine + limit - 1 : "";
				text += fg("warning", `:${startLine}${endLine ? `-${endLine}` : ""}`);
			}
			return fg("muted", "read ") + text;
		}
		case "write": {
			const rawPath = (args.file_path || args.path || "...") as string;
			const content = (args.content || "") as string;
			const lines = content.split("\n").length;
			let text = fg("muted", "write ") + fg("accent", shortenPath(rawPath));
			if (lines > 1) text += fg("dim", ` (${lines} lines)`);
			return text;
		}
		case "edit": {
			const rawPath = (args.file_path || args.path || "...") as string;
			return fg("muted", "edit ") + fg("accent", shortenPath(rawPath));
		}
		default: {
			const argsStr = JSON.stringify(args);
			const preview = argsStr.length > 50 ? `${argsStr.slice(0, 50)}...` : argsStr;
			return fg("accent", toolName) + fg("dim", ` ${preview}`);
		}
	}
}

// ---------------------------------------------------------------------------
// TUI rendering: shared building blocks
// ---------------------------------------------------------------------------

/**
 * Render a single result as a collapsed "minibox" string.
 * Shows icon, optional task preview, error, last N tool calls/text, and usage.
 * Used by both subagent tool (collapsed view) and btw (collapsed view).
 */
export function renderMinibox(
	r: SingleResult,
	options: { showTask: boolean; expanded: boolean },
	theme: Theme,
): string {
	const isRunning = r.exitCode === -1;
	const isError = r.exitCode > 0;
	const icon = isRunning
		? theme.fg("warning", "⏳")
		: isError
			? theme.fg("error", "✗")
			: theme.fg("success", "✓");

	const lines: string[] = [];

	if (options.showTask) {
		// No truncation — let terminal wrap; full task shown on one line
		lines.push(`${icon} ${theme.fg("dim", r.task)}`);
	} else {
		lines.push(icon);
	}

	if (isError && r.errorMessage) {
		lines.push(theme.fg("error", `Error: ${r.errorMessage}`));
	}

	const items = r.displayItems;
	const itemsToShow = options.expanded ? items : items.slice(-MINIBOX_LINES);
	const skipped = items.length - itemsToShow.length;

	if (skipped > 0) {
		lines.push(theme.fg("muted", `... ${skipped} earlier items`));
	}

	for (const item of itemsToShow) {
		if (item.type === "text") {
			if (options.expanded) {
				continue;
			}
			const textLines = item.text.split("\n").filter((l) => l.trim());
			const preview = textLines.slice(0, 5).join("\n");
			lines.push(theme.fg("toolOutput", preview));
			if (textLines.length > 5) lines.push(theme.fg("muted", `... +${textLines.length - 5} lines`));
		} else {
			lines.push(
				theme.fg("muted", "→ ") +
					formatToolCall(item.name, item.args, theme.fg.bind(theme)),
			);
		}
	}

	if (!isRunning) {
		const usageStr = formatUsage(r.usage, r.model);
		if (usageStr) lines.push(theme.fg("dim", usageStr));
	}

	return lines.join("\n");
}

/**
 * Render a single result in expanded form as TUI components added to a container.
 * Shows separator + icon + task + all tool calls + markdown output + usage.
 * Used by both subagent tool (expanded view) and btw (expanded view).
 */
export function renderResultExpanded(
	r: SingleResult,
	container: Container,
	theme: Theme,
	mdTheme: MarkdownTheme,
): void {
	const rIcon = r.exitCode === 0
		? theme.fg("success", "✓")
		: r.exitCode === -1
			? theme.fg("warning", "⏳")
			: theme.fg("error", "✗");

	container.addChild(new Spacer(1));
	// Expanded: show full task prompt
	container.addChild(
		new Text(`${theme.fg("muted", "─── ")}${rIcon} ${theme.fg("dim", r.task)}`, 0, 0),
	);

	if (r.exitCode > 0 && r.errorMessage) {
		container.addChild(new Text(theme.fg("error", `Error: ${r.errorMessage}`), 0, 0));
	}

	for (const item of r.displayItems) {
		if (item.type === "toolCall") {
			container.addChild(new Text(
				theme.fg("muted", "→ ") +
					formatToolCall(item.name, item.args, theme.fg.bind(theme)),
				0, 0,
			));
		}
	}

	if (r.finalOutput) {
		container.addChild(new Spacer(1));
		container.addChild(new Markdown(r.finalOutput.trim(), 0, 0, mdTheme));
	}

	const taskUsage = formatUsage(r.usage, r.model);
	if (taskUsage) container.addChild(new Text(theme.fg("dim", taskUsage), 0, 0));
}

/**
 * Render a list of results as a complete TUI component.
 * Handles both collapsed and expanded views, single and multi-task.
 * Used by both subagent tool renderResult and btw message renderer.
 *
 * @param label - The label to show in the header (e.g. "subagent" or "btw")
 */
export function renderResults(
	results: SingleResult[],
	options: { expanded: boolean; label: string },
	theme: Theme,
): Component {
	const mdTheme = getMarkdownTheme();

	const running = results.filter((r) => r.exitCode === -1).length;
	const successCount = results.filter((r) => r.exitCode === 0).length;
	const failCount = results.filter((r) => r.exitCode > 0).length;
	const isRunning = running > 0;
	const icon = isRunning
		? theme.fg("warning", "⏳")
		: failCount > 0
			? theme.fg("warning", "◐")
			: theme.fg("success", "✓");
	const status = isRunning
		? `${successCount + failCount}/${results.length} done, ${running} running`
		: results.length === 1
			? ""
			: `${successCount}/${results.length} tasks`;

	// --- Expanded view (only when finished) ---
	if (options.expanded && !isRunning) {
		const container = new Container();
		container.addChild(
			new Text(
				`${icon} ${theme.fg("toolTitle", theme.bold(`${options.label} `))}${status ? theme.fg("accent", status) : ""}`,
				0, 0,
			),
		);

		for (const r of results) {
			renderResultExpanded(r, container, theme, mdTheme);
		}

		if (results.length > 1) {
			const totalUsage = aggregateUsage(results);
			const totalStr = formatUsage(totalUsage);
			if (totalStr) {
				container.addChild(new Spacer(1));
				container.addChild(new Text(theme.fg("dim", `Total: ${totalStr}`), 0, 0));
			}
		}

		return container;
	}

	// --- Collapsed / running view ---
	let text = `${icon} ${theme.fg("toolTitle", theme.bold(`${options.label} `))}${status ? theme.fg("accent", status) : ""}`;
	for (const r of results) {
		text += `\n\n${renderMinibox(r, { showTask: true, expanded: options.expanded }, theme)}`;
	}
	if (!isRunning && results.length > 1) {
		const totalUsage = aggregateUsage(results);
		const totalStr = formatUsage(totalUsage);
		if (totalStr) text += `\n\n${theme.fg("dim", `Total: ${totalStr}`)}`;
	}
	if (!options.expanded && !isRunning) text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
	return new Text(text, 0, 0);
}

/**
 * Render a result as plain-text lines (no theme colors).
 * Used for setWidget() which only supports string[].
 */
export function btwTaskPreview(task: string): string {
	const taskFirstLine = task.split("\n")[0];
	const taskMultiline = taskFirstLine.length < task.length;
	const maxLen = (process.stdout.columns ?? 120) - "⏳ btw: ".length - 3 - 5;
	const taskTrimmed = taskFirstLine.length > maxLen ? `${taskFirstLine.slice(0, maxLen)}...` : taskFirstLine;
	return taskMultiline && !taskTrimmed.endsWith("...") ? `${taskTrimmed}...` : taskTrimmed;
}

export function renderProgressPlainLines(task: string, result: SingleResult): string[] {
	const taskPreview = btwTaskPreview(task);
	const lines: string[] = [];

	lines.push(`⏳ btw: ${taskPreview}`);

	const items = result.displayItems;
	const itemsToShow = items.slice(-MINIBOX_LINES);
	const skipped = items.length - itemsToShow.length;

	if (skipped > 0) {
		lines.push(`  ... ${skipped} earlier items`);
	}

	for (const item of itemsToShow) {
		if (item.type === "text") {
			const textLines = item.text.split("\n").filter((l) => l.trim());
			const preview = textLines.slice(0, 3).join("\n  ");
			lines.push(`  ${preview}`);
			if (textLines.length > 3) lines.push(`  ... +${textLines.length - 3} lines`);
		} else {
			switch (item.name) {
				case "bash": {
					const cmd = (item.args.command as string) || "...";
					lines.push(`  $ ${cmd.split("\n")[0]}`);
					break;
				}
				case "read":
					lines.push(`  read ${item.args.file_path || item.args.path || "..."}`);
					break;
				case "write":
					lines.push(`  write ${item.args.file_path || item.args.path || "..."}`);
					break;
				case "edit":
					lines.push(`  edit ${item.args.file_path || item.args.path || "..."}`);
					break;
				default:
					lines.push(`  → ${item.name}`);
			}
		}
	}

	return lines;
}

// ---------------------------------------------------------------------------
// Core: run a single subagent loop
// ---------------------------------------------------------------------------

export async function runSubagent(
	systemPrompt: string,
	task: string,
	tools: AgentTool<any>[],
	model: any,
	thinkingLevel: string,
	apiKeyResolver: (provider: string) => Promise<string | undefined>,
	signal: AbortSignal | undefined,
	onProgress: (result: SingleResult) => void,
): Promise<SingleResult> {
	const result: SingleResult = {
		task,
		exitCode: -1,
		displayItems: [],
		finalOutput: "",
		usage: emptyUsage(),
		model: `${model.provider}/${model.id}`,
	};

	const subagentPrompt: AgentMessage = {
		role: "user" as const,
		content: [
			{
				type: "text" as const,
				text: [
					"You are operating as a subagent within a larger agent session.",
					"Complete the following task thoroughly, then provide your final response as text.",
					"Be concise and focused. Do NOT attempt to hand off or spawn further subagents.",
					"",
					task,
				].join("\n"),
			},
		],
		timestamp: Date.now(),
	};

	// Fresh context: just the system prompt, no message history
	const context: AgentContext = {
		systemPrompt,
		messages: [],
		tools,
	};

	const config: AgentLoopConfig = {
		model,
		convertToLlm: (msgs: AgentMessage[]) => convertToLlm(msgs),
		getApiKey: apiKeyResolver,
		reasoning: thinkingLevel !== "off" ? (thinkingLevel as any) : undefined,
	};

	try {
		const stream = agentLoop([subagentPrompt], context, config, signal);

		for await (const event of stream) {
			if (signal?.aborted) break;

			switch (event.type) {
				case "message_end": {
					const msg = event.message as any;
					if (msg.role === "assistant") {
						result.usage.turns++;
						const usage = msg.usage;
						if (usage) {
							result.usage.input += usage.input || 0;
							result.usage.output += usage.output || 0;
							result.usage.cacheRead += usage.cacheRead || 0;
							result.usage.cacheWrite += usage.cacheWrite || 0;
							result.usage.cost += usage.cost?.total || 0;
							result.usage.contextTokens = usage.totalTokens || 0;
						}
						if (msg.model) result.model = msg.model;
						if (msg.stopReason) result.stopReason = msg.stopReason;
						if (msg.errorMessage) result.errorMessage = msg.errorMessage;

						for (const part of msg.content) {
							if (part.type === "text") {
								result.displayItems.push({ type: "text", text: part.text });
								result.finalOutput = part.text;
							} else if (part.type === "toolCall") {
								result.displayItems.push({
									type: "toolCall",
									name: part.name,
									args: part.arguments,
								});
							}
						}
					}
					onProgress(result);
					break;
				}
				case "tool_execution_end": {
					onProgress(result);
					break;
				}
			}
		}

		if (result.stopReason === "error" || result.stopReason === "aborted") {
			result.exitCode = 1;
		} else if (result.exitCode === -1) {
			result.exitCode = 0;
		}
	} catch (err) {
		result.exitCode = 1;
		result.errorMessage = err instanceof Error ? err.message : String(err);
		if (signal?.aborted) {
			result.stopReason = "aborted";
		}
	}

	return result;
}

// ---------------------------------------------------------------------------
// Parallel execution helper
// ---------------------------------------------------------------------------

export async function mapWithConcurrency<TIn, TOut>(
	items: TIn[],
	concurrency: number,
	fn: (item: TIn, index: number) => Promise<TOut>,
): Promise<TOut[]> {
	if (items.length === 0) return [];
	const limit = Math.max(1, Math.min(concurrency, items.length));
	const results: TOut[] = new Array(items.length);
	let nextIndex = 0;
	const workers = new Array(limit).fill(null).map(async () => {
		while (true) {
			const current = nextIndex++;
			if (current >= items.length) return;
			results[current] = await fn(items[current], current);
		}
	});
	await Promise.all(workers);
	return results;
}
