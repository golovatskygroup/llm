#!/usr/bin/env bash
# remove-hooks.sh - Removes Claude Code quality hooks from a project
# Usage: ./remove-hooks.sh [--path /path/to/project]

set -euo pipefail

TARGET_PATH="."

while [[ $# -gt 0 ]]; do
    case $1 in
        --path) TARGET_PATH="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--path /path/to/project]"
            echo "Removes Claude Code quality hooks from the specified project."
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

TARGET_PATH=$(cd "$TARGET_PATH" && pwd)

echo "============================================="
echo "  Claude Code Hooks Removal"
echo "============================================="
echo ""
echo "Target: $TARGET_PATH"
echo ""

# All files to remove
FILES_TO_REMOVE=(
    ".claude/hooks/pre_tool_use.sh"
    ".claude/hooks/post_tool_use.sh"
    ".claude/hooks/stop.sh"
    ".claude/scripts/verify_loop.sh"
    ".claude/scripts/reconfig.sh"
    ".claude/hooks.config"
)

echo "Removing files..."
for file in "${FILES_TO_REMOVE[@]}"; do
    local_path="$TARGET_PATH/$file"
    if [[ -f "$local_path" ]]; then
        echo "  Removing: $file"
        rm "$local_path"
    else
        echo "  Skipping: $file (not found)"
    fi
done

# Remove empty directories
echo ""
echo "Cleaning up empty directories..."
for dir in ".claude/hooks" ".claude/scripts"; do
    local_dir="$TARGET_PATH/$dir"
    if [[ -d "$local_dir" ]] && [[ -z "$(ls -A "$local_dir" 2>/dev/null)" ]]; then
        echo "  Removing empty: $dir/"
        rmdir "$local_dir"
    fi
done

# Update settings.local.json
SETTINGS_FILE="$TARGET_PATH/.claude/settings.local.json"
echo ""
echo "Updating settings.local.json..."

if [[ -f "$SETTINGS_FILE" ]] && command -v jq &>/dev/null; then
    TEMP_FILE=$(mktemp)
    jq '
        .hooks.PreToolUse = ((.hooks.PreToolUse // []) | map(select(.hooks[0].command | contains("pre_tool_use.sh") | not))) |
        .hooks.PostToolUse = ((.hooks.PostToolUse // []) | map(select(.hooks[0].command | contains("post_tool_use.sh") | not))) |
        .hooks.Stop = ((.hooks.Stop // []) | map(select(.hooks[0].command | contains("stop.sh") | not))) |
        if .hooks.PreToolUse == [] then del(.hooks.PreToolUse) else . end |
        if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end |
        if .hooks.Stop == [] then del(.hooks.Stop) else . end |
        if .hooks == {} then del(.hooks) else . end
    ' "$SETTINGS_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$SETTINGS_FILE"
    echo "  Removed hook entries from settings"

    # Remove if empty
    if [[ $(jq 'keys | length' "$SETTINGS_FILE") == "0" ]]; then
        echo "  Settings file empty, removing..."
        rm "$SETTINGS_FILE"
    fi
elif [[ -f "$SETTINGS_FILE" ]]; then
    echo "  Warning: jq not found, manually remove hooks from $SETTINGS_FILE"
else
    echo "  No settings file found"
fi

echo ""
echo "============================================="
echo "  Removal Complete!"
echo "============================================="
echo ""
echo "Preserved: .claude/memory/, .claude/skills/, linter configs"
