import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";

const DANGEROUS_GIT_PATTERNS = [
  /\bgit\s+push\b/,
  /\bgit\s+remote\s+(add|remove|rm|rename|set-url)\b/,
  /\bgit\s+force-push\b/,
  /\bgit\s+push\s+.*--force\b/,
  /\bgit\s+push\s+.*-f\b/,
];

function matchesDangerousPattern(command: string): string | null {
  for (const pattern of DANGEROUS_GIT_PATTERNS) {
    if (pattern.test(command)) return pattern.source;
  }
  return null;
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (!isToolCallEventType("bash", event)) return;

    const command = event.input.command;
    if (!command) return;

    const matched = matchesDangerousPattern(command);
    if (!matched) return;

    const ok = await ctx.ui.confirm(
      "Git Guard",
      `This command may modify a remote:\n\n  ${command}\n\nAllow?`,
    );

    if (!ok) return { block: true, reason: "Blocked by git-guard: remote-modifying git command not approved" };
  });
}
