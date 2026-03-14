#!/usr/bin/env bash
# Merge dotfiles Claude settings into existing ~/.claude/settings.json
# This preserves settings managed by external tools while adding your permissions

set -e

DOTFILES_SETTINGS="${HOME}/.dotfiles/.claude/settings.json"
TARGET_SETTINGS="${HOME}/.claude/settings.json"

if [[ ! -f "$DOTFILES_SETTINGS" ]]; then
    echo "Error: Dotfiles settings not found at $DOTFILES_SETTINGS"
    exit 1
fi

if [[ ! -f "$TARGET_SETTINGS" ]]; then
    echo "Target settings not found. Creating from dotfiles..."
    mkdir -p "$(dirname "$TARGET_SETTINGS")"
    cp "$DOTFILES_SETTINGS" "$TARGET_SETTINGS"
    echo "Created $TARGET_SETTINGS"
    exit 0
fi

# Use jq to merge the settings
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for merging JSON files"
    echo "Install with: sudo yum install jq"
    exit 1
fi

# Backup existing settings
cp "$TARGET_SETTINGS" "${TARGET_SETTINGS}.backup"

# Merge strategy:
# - Start with existing settings as base
# - Add permissions.allow from dotfiles
# - Merge env settings (dotfiles env overrides existing)
jq --slurpfile dotfiles <(cat "$DOTFILES_SETTINGS") \
   '. + {permissions: $dotfiles[0].permissions} | .env = (.env // {}) + ($dotfiles[0].env // {})' \
    "$TARGET_SETTINGS" > "${TARGET_SETTINGS}.tmp"

mv "${TARGET_SETTINGS}.tmp" "$TARGET_SETTINGS"

echo "Successfully merged Claude settings"
echo "Permissions and env from dotfiles applied to $TARGET_SETTINGS"
echo "Backup saved to ${TARGET_SETTINGS}.backup"
