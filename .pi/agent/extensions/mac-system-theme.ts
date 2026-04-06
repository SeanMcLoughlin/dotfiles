/**
 * Adds a /theme command to toggle between dark and light themes.
 *
 * Usage:
 *   /theme        - toggle between dark and light
 *   /theme dark   - switch to dark
 *   /theme light  - switch to light
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
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
				ctx.ui.setTheme(arg);
				ctx.ui.notify(`Theme: ${arg}`, "info");
			} else if (!arg) {
				// Toggle: detect current macOS mode, flip it
				let isDark = false;
				try {
					const { execFileSync } = await import("node:child_process");
					execFileSync("defaults", ["read", "-g", "AppleInterfaceStyle"], {
						stdio: "pipe",
					});
					isDark = true;
				} catch {
					isDark = false;
				}
				const next = isDark ? "light" : "dark";
				ctx.ui.setTheme(next);
				ctx.ui.notify(`Theme: ${next}`, "info");
			} else {
				ctx.ui.notify(`Unknown theme: ${arg}. Use "dark" or "light".`, "error");
			}
		},
	});

	// Still set the initial theme on startup based on macOS appearance
	pi.on("session_start", (_event, ctx) => {
		try {
			const { execFileSync } = require("node:child_process");
			execFileSync("defaults", ["read", "-g", "AppleInterfaceStyle"], {
				stdio: "pipe",
			});
			ctx.ui.setTheme("dark");
		} catch {
			ctx.ui.setTheme("light");
		}
	});
}
