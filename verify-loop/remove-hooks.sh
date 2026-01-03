#!/usr/bin/env bash
# remove-hooks.sh
# Removes Claude Code quality hooks from a project
# Only removes specific files installed by setup-hooks.sh
# Usage: ./remove-hooks.sh [--path /path/to/project]

set -euo pipefail

# Default target is current directory
TARGET_PATH="."

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --path)
            TARGET_PATH="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--path /path/to/project]"
            echo ""
            echo "Removes Claude Code quality hooks from the specified project."
            echo "Only removes files installed by setup-hooks.sh."
            echo ""
            echo "Options:"
            echo "  --path    Target project directory (default: current directory)"
            echo "  -h        Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Resolve target path
TARGET_PATH=$(cd "$TARGET_PATH" && pwd)

echo "============================================="
echo "  Claude Code Hooks Removal"
echo "============================================="
echo ""
echo "Target: $TARGET_PATH"
echo ""

# Files to remove (only our specific files)
HOOK_FILES=(
    ".claude/hooks/pre_tool_use.sh"
    ".claude/hooks/post_tool_use.sh"
    ".claude/hooks/stop.sh"
)

SCRIPT_FILES=(
    ".claude/scripts/verify_loop.sh"
    ".claude/scripts/reconfig.sh"
)

CONFIG_FILES=(
    ".claude/hooks.config"
)

# Remove files
remove_file() {
    local file="$TARGET_PATH/$1"
    if [[ -f "$file" ]]; then
        echo "  Removing: $1"
        rm "$file"
        return 0
    else
        echo "  Skipping: $1 (not found)"
        return 1
    fi
}

echo "Removing hook files..."
for file in "${HOOK_FILES[@]}"; do
    remove_file "$file" || true
done

echo ""
echo "Removing script files..."
for file in "${SCRIPT_FILES[@]}"; do
    remove_file "$file" || true
done

echo ""
echo "Removing config files..."
for file in "${CONFIG_FILES[@]}"; do
    remove_file "$file" || true
done

# Remove empty directories (only if empty)
echo ""
echo "Cleaning up empty directories..."
if [[ -d "$TARGET_PATH/.claude/hooks" ]] && [[ -z "$(ls -A "$TARGET_PATH/.claude/hooks" 2>/dev/null)" ]]; then
    echo "  Removing empty: .claude/hooks/"
    rmdir "$TARGET_PATH/.claude/hooks"
fi

if [[ -d "$TARGET_PATH/.claude/scripts" ]] && [[ -z "$(ls -A "$TARGET_PATH/.claude/scripts" 2>/dev/null)" ]]; then
    echo "  Removing empty: .claude/scripts/"
    rmdir "$TARGET_PATH/.claude/scripts"
fi

# Update settings.local.json - remove only our hook entries
SETTINGS_FILE="$TARGET_PATH/.claude/settings.local.json"
echo ""
echo "Updating settings.local.json..."

if [[ -f "$SETTINGS_FILE" ]]; then
    if command -v jq &>/dev/null; then
        TEMP_FILE=$(mktemp)

        # Remove only our specific hooks
        jq '
            # Remove PreToolUse hooks that reference our scripts
            .hooks.PreToolUse = ((.hooks.PreToolUse // []) | map(
                select(.hooks[0].command | contains("pre_tool_use.sh") | not)
            )) |
            # Remove PostToolUse hooks that reference our scripts
            .hooks.PostToolUse = ((.hooks.PostToolUse // []) | map(
                select(.hooks[0].command | contains("post_tool_use.sh") | not)
            )) |
            # Remove Stop hooks that reference our scripts
            .hooks.Stop = ((.hooks.Stop // []) | map(
                select(.hooks[0].command | contains("stop.sh") | not)
            )) |
            # Clean up empty arrays
            if .hooks.PreToolUse == [] then del(.hooks.PreToolUse) else . end |
            if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end |
            if .hooks.Stop == [] then del(.hooks.Stop) else . end |
            # Clean up empty hooks object
            if .hooks == {} then del(.hooks) else . end
        ' "$SETTINGS_FILE" > "$TEMP_FILE"

        mv "$TEMP_FILE" "$SETTINGS_FILE"
        echo "  Removed hook entries from settings"

        # Check if settings file is now effectively empty
        local remaining=$(jq 'keys | length' "$SETTINGS_FILE")
        if [[ "$remaining" == "0" ]]; then
            echo "  Settings file is empty, removing..."
            rm "$SETTINGS_FILE"
        fi
    else
        echo "  Warning: jq not found, cannot update settings"
        echo "  Please manually remove hooks from $SETTINGS_FILE"
    fi
else
    echo "  No settings file found, skipping"
fi

echo ""
echo "============================================="
echo "  Removal Complete!"
echo "============================================="
echo ""
echo "The following were preserved:"
echo "  - .claude/memory/ (logs)"
echo "  - .claude/skills/ (if any)"
echo "  - .claude/docs/ (if any)"
echo "  - Other settings in settings.local.json"
echo "  - Linter configs (.golangci.yml, biome.json, ruff.toml)"
echo ""
