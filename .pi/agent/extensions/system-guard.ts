import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";

const DANGEROUS_GIT_PATTERNS = [
  /\bgit\s+push\b/,
  /\bgit\s+remote\s+(add|remove|rm|rename|set-url)\b/,
  /\bgit\s+force-push\b/,
  /\bgit\s+push\s+.*--force\b/,
  /\bgit\s+push\s+.*-f\b/,
];

// Patterns for commands that require approval due to system-wide state modification
const PACKAGE_MANAGER_PATTERNS = [
  // brew commands that modify system state (install, uninstall, upgrade, tap, untap, link, unlink, etc.)
  // Read-only commands like info, list, search, config, doctor, deps, desc, cat, home, log are allowed
  /\bbrew\s+(install|reinstall|uninstall|remove|rm|upgrade|tap|untap|link|ln|unlink|pin|unpin|cleanup|autoremove|migrate|postinstall|services|cask)\b/,
  // npm global install/uninstall: -g, --global, or --location=global
  /\bnpm\s+(install|i|add)\b(?=[\s\S]*\s(-g|--global|--location=global))/,
  /\bnpm\s+(uninstall|remove|rm|un|r)\b(?=[\s\S]*\s(-g|--global|--location=global))/,
  // cargo install / uninstall (always global)
  /\bcargo\s+(install|uninstall)\b/,
  // sudo — anything run as root modifies system state
  /\bsudo\b/,
  // gem — global by default on macOS
  /\bgem\s+(install|uninstall)\b/,
  // pipx — explicitly for global user-level Python tools
  /\bpipx\s+(install|uninstall)\b/,
  // pip/pip3 install without --user (i.e. modifies system/global Python env)
  /\bpip3?\s+install\b(?!(?:[\s\S]*\s--user))/,
  // launchctl — macOS service management, persists across reboots
  /\blaunchctl\s+(load|unload|bootstrap|bootout)\b/,
  // softwareupdate — macOS system updates
  /\bsoftwareupdate\b/,
  // defaults write — modifies macOS system/app preferences persistently
  /\bdefaults\s+write\b/,
  // mas — Mac App Store CLI
  /\bmas\s+(install|uninstall)\b/,
  // deno install — global Deno tool installs
  /\bdeno\s+install\b/,
  // go install — installs to GOPATH/bin
  /\bgo\s+install\b/,
];

// Skills that are allowed to run dangerous git commands without confirmation
const ALLOWED_SKILLS = ["/skill:git-push"];

function matchesDangerousPattern(command: string): string | null {
  for (const pattern of DANGEROUS_GIT_PATTERNS) {
    if (pattern.test(command)) return pattern.source;
  }
  return null;
}

function matchesPackageManagerPattern(command: string): string | null {
  for (const pattern of PACKAGE_MANAGER_PATTERNS) {
    if (pattern.test(command)) return pattern.source;
  }
  return null;
}

export default function (pi: ExtensionAPI) {
  let skillAllowed = false;

  pi.on("input", async (event) => {
    skillAllowed = ALLOWED_SKILLS.some((s) => event.text.startsWith(s));
    return { action: "continue" };
  });

  pi.on("agent_end", async () => {
    skillAllowed = false;
  });

  pi.on("tool_call", async (event, ctx) => {
    if (!isToolCallEventType("bash", event)) return;

    const command = event.input.command;
    if (!command) return;

    const matched = matchesDangerousPattern(command);
    if (matched) {
      if (skillAllowed) return;

      const ok = await ctx.ui.confirm(
        "Git Guard",
        `This command may modify a remote:\n\n  ${command}\n\nAllow?`,
      );

      if (!ok) return { block: true, reason: "Blocked by system-guard: remote-modifying git command not approved" };
      return;
    }

    const pkgMatched = matchesPackageManagerPattern(command);
    if (!pkgMatched) return;

    const ok = await ctx.ui.confirm(
      "Package Manager Guard",
      `This command modifies system packages:\n\n  ${command}\n\nAllow?`,
    );

    if (!ok) return { block: true, reason: "Blocked by system-guard: system package command not approved" };
  });
}
