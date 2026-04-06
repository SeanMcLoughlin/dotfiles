/**
 * Auto-switches between ansi-dark and ansi-light themes based on macOS
 * appearance, and provides a /theme command to toggle manually.
 *
 * Usage:
 *   /theme        - toggle between ansi-dark and ansi-light
 *   /theme dark   - switch to ansi-dark
 *   /theme light  - switch to ansi-light
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { spawn, execFileSync, type ChildProcess } from "node:child_process";
import { createInterface } from "node:readline";

const SWIFT_WATCHER = `
import Cocoa

func isDark() -> Bool {
    UserDefaults.standard.string(forKey: "AppleInterfaceStyle")?.lowercased() == "dark"
}

func emit() {
    print(isDark() ? "dark" : "light")
    fflush(stdout)
}

emit()

DistributedNotificationCenter.default().addObserver(
    forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
    object: nil,
    queue: .main
) { _ in emit() }

RunLoop.main.run()
`;

function isMacOSDark(): boolean {
	try {
		execFileSync("defaults", ["read", "-g", "AppleInterfaceStyle"], {
			stdio: "pipe",
		});
		return true;
	} catch {
		return false;
	}
}

function themeForMode(dark: boolean): string {
	return dark ? "ansi-dark" : "ansi-light";
}

export default function (pi: ExtensionAPI) {
	let watcher: ChildProcess | null = null;

	pi.on("session_start", (_event, ctx) => {
		// Set theme immediately
		ctx.ui.setTheme(themeForMode(isMacOSDark()));

		// Spawn a Swift process that watches for appearance changes
		if (watcher) watcher.kill();
		const child = spawn("swift", ["-e", SWIFT_WATCHER], {
			stdio: ["ignore", "pipe", "ignore"],
		});
		watcher = child;

		const rl = createInterface({ input: child.stdout! });
		rl.on("line", (line) => {
			const mode = line.trim();
			if (mode === "dark" || mode === "light") {
				ctx.ui.setTheme(themeForMode(mode === "dark"));
			}
		});

		child.on("exit", () => {
			if (watcher === child) watcher = null;
		});
	});

	pi.on("session_shutdown", () => {
		if (watcher) {
			watcher.kill();
			watcher = null;
		}
	});

	pi.registerCommand("theme", {
		description: "Toggle or set theme (dark/light)",
		getArgumentCompletions: (prefix: string) => {
			const options = ["dark", "light"];
			const filtered = options
				.filter((o) => o.startsWith(prefix))
				.map((o) => ({ value: o, label: o }));
			return filtered.length > 0 ? filtered : null;
		},
		handler: async (args, ctx) => {
			const arg = args?.trim().toLowerCase();
			if (arg === "dark" || arg === "light") {
				const theme = themeForMode(arg === "dark");
				const result = ctx.ui.setTheme(theme);
				if (result.success) {
					ctx.ui.notify(`Theme: ${theme}`, "info");
				} else {
					ctx.ui.notify(`Failed to set theme: ${result.error}`, "error");
				}
			} else if (!arg) {
				// Toggle: detect current macOS mode, flip it
				const next = themeForMode(!isMacOSDark());
				const result = ctx.ui.setTheme(next);
				if (result.success) {
					ctx.ui.notify(`Theme: ${next}`, "info");
				} else {
					ctx.ui.notify(`Failed to set theme: ${result.error}`, "error");
				}
			} else {
				ctx.ui.notify(`Unknown theme: ${arg}. Use "dark" or "light".`, "error");
			}
		},
	});

}
