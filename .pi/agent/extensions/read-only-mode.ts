/**
 * Read-Only Mode Extension
 *
 * Toggle a "read-only" lock with Alt+L that prevents the agent from
 * executing any mutating tools (write, edit, bash, subagent, mcp).
 * Read-only tools (read, grep, find, ls) remain allowed.
 *
 * When locked and the agent attempts a mutating tool, you're prompted:
 *   - Approve → mode switches to UNLOCKED and the tool executes
 *   - Deny    → stays LOCKED, tool is blocked, agent continues thinking
 *
 * A status indicator in the footer shows the current mode:
 *   🔒 READ-ONLY  /  🔓 UNLOCKED
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const ALLOWED_TOOLS = new Set(["read", "grep", "find", "ls"]);

export default function (pi: ExtensionAPI) {
	let locked = false;

	function updateStatus(ctx: { ui: { theme: any; setStatus: (key: string, text: string) => void } }) {
		const theme = ctx.ui.theme;
		if (locked) {
			ctx.ui.setStatus(
				"read-only-mode",
				theme.fg("error", "🔒 READ-ONLY"),
			);
		} else {
			ctx.ui.setStatus(
				"read-only-mode",
				theme.fg("success", "🔓 UNLOCKED"),
			);
		}
	}

	// Show initial status on session start
	pi.on("session_start", async (_event, ctx) => {
		updateStatus(ctx);
	});

	// Register the keyboard shortcut: Alt+L to toggle
	pi.registerShortcut("alt+l", {
		description: "Toggle read-only mode (lock/unlock mutating tools)",
		handler: async (ctx) => {
			locked = !locked;
			updateStatus(ctx);
			ctx.ui.notify(
				locked ? "🔒 Read-only mode ON — mutating tools blocked" : "🔓 Read-only mode OFF — all tools allowed",
				locked ? "warning" : "success",
			);
		},
	});

	// Inject a system prompt hint so the LLM knows it's in read-only mode
	pi.on("before_agent_start", async (_event, _ctx) => {
		if (locked) {
			return {
				systemPrompt:
					"IMPORTANT: Read-only mode is active. You MUST NOT call write, edit, bash, subagent, or mcp tools. " +
					"You may only use read, grep, find, and ls. If the user asks you to make changes, explain that " +
					"read-only mode is enabled and they need to unlock it first (Alt+L). " +
					"If a tool call is denied, do NOT retry the same tool. Continue answering with text only.",
			};
		}
		return undefined;
	});

	// Prompt for approval on mutating tools when locked
	pi.on("tool_call", async (event, ctx) => {
		if (!locked) return undefined;

		if (ALLOWED_TOOLS.has(event.toolName)) {
			return undefined;
		}

		// In non-interactive mode, block outright
		if (!ctx.hasUI) {
			return {
				block: true,
				reason: "Read-only mode is active and no UI is available for approval.",
			};
		}

		// Build a summary of what the agent wants to do
		let detail = event.toolName;
		const input = event.input as Record<string, unknown>;
		if (event.toolName === "bash" && input.command) {
			detail = `bash: ${input.command}`;
		} else if ((event.toolName === "write" || event.toolName === "edit") && input.path) {
			detail = `${event.toolName}: ${input.path}`;
		}

		const approved = await ctx.ui.confirm(
			"🔒 Read-only mode",
			`Agent wants to run:\n\n  ${detail}\n\nApprove and unlock?`,
		);

		if (approved) {
			// Unlock and allow this + all future tool calls
			locked = false;
			updateStatus(ctx);
			ctx.ui.notify("🔓 Approved — read-only mode OFF", "success");
			return undefined;
		}

		// Denied — stay locked, block this call
		ctx.ui.notify(`🔒 Denied ${event.toolName} — staying in read-only mode`, "warning");
		return {
			block: true,
			reason:
				"The user denied this tool call. Read-only mode remains active. " +
				"Do NOT retry this or any other mutating tool. Continue answering with text only.",
		};
	});
}
