#!/usr/bin/env bash
# setup-hooks.sh - Installs Claude Code quality hooks into a project
# Usage: ./setup-hooks.sh [--path /path/to/project]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_PATH="."

while [[ $# -gt 0 ]]; do
    case $1 in
        --path) TARGET_PATH="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--path /path/to/project]"
            echo "Installs Claude Code quality hooks into the specified project."
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

TARGET_PATH=$(cd "$TARGET_PATH" && pwd)

echo "============================================="
echo "  Claude Code Hooks Setup"
echo "============================================="
echo ""
echo "Target: $TARGET_PATH"

# Detect project language
detect_language() {
    [[ -f "$1/go.mod" ]] && { echo "go"; return; }
    [[ -f "$1/package.json" ]] && { echo "node"; return; }
    [[ -f "$1/pyproject.toml" ]] || [[ -f "$1/setup.py" ]] && { echo "python"; return; }
    echo "generic"
}

LANGUAGE=$(detect_language "$TARGET_PATH")
echo "Detected language: $LANGUAGE"
echo ""

# Create directories
mkdir -p "$TARGET_PATH/.claude/hooks" "$TARGET_PATH/.claude/scripts" "$TARGET_PATH/.claude/memory"

# Backup helper
backup_if_exists() {
    [[ -f "$1" ]] && cp "$1" "${1}.backup.$(date +%Y%m%d_%H%M%S)" && echo "  Backed up: $1"
}

# Copy hooks and scripts
echo "Installing hooks and scripts..."
for file in hooks/pre_tool_use.sh hooks/post_tool_use.sh hooks/stop.sh scripts/verify_loop.sh scripts/reconfig.sh; do
    backup_if_exists "$TARGET_PATH/.claude/$file"
    cp "$SCRIPT_DIR/.claude/$file" "$TARGET_PATH/.claude/$file"
done
chmod +x "$TARGET_PATH/.claude/hooks/"*.sh "$TARGET_PATH/.claude/scripts/"*.sh

# Create hooks.config based on language
echo "Creating hooks.config for $LANGUAGE..."
backup_if_exists "$TARGET_PATH/.claude/hooks.config"

case "$LANGUAGE" in
    go)
        cp "$SCRIPT_DIR/templates/hooks.config.go" "$TARGET_PATH/.claude/hooks.config"
        [[ ! -f "$TARGET_PATH/.golangci.yml" ]] && cp "$SCRIPT_DIR/templates/.golangci.yml" "$TARGET_PATH/" && echo "  Added .golangci.yml"
        ;;
    node)
        cp "$SCRIPT_DIR/templates/hooks.config.node" "$TARGET_PATH/.claude/hooks.config"
        [[ ! -f "$TARGET_PATH/biome.json" ]] && [[ ! -f "$TARGET_PATH/.eslintrc.js" ]] && [[ ! -f "$TARGET_PATH/.eslintrc.json" ]] && \
            cp "$SCRIPT_DIR/templates/biome.json" "$TARGET_PATH/" && echo "  Added biome.json"
        ;;
    python)
        cp "$SCRIPT_DIR/templates/hooks.config.python" "$TARGET_PATH/.claude/hooks.config"
        [[ ! -f "$TARGET_PATH/ruff.toml" ]] && [[ ! -f "$TARGET_PATH/pyproject.toml" ]] && \
            cp "$SCRIPT_DIR/templates/ruff.toml" "$TARGET_PATH/" && echo "  Added ruff.toml"
        ;;
    *)
        cat > "$TARGET_PATH/.claude/hooks.config" << 'EOF'
# Claude Code Hooks Configuration (generic)
LANGUAGE="generic"
FORMAT_CMD="" IMPORTS_CMD="" BUILD_CMD="" VET_CMD="" LINT_CMD="" TYPE_CMD="" TEST_CMD=""
FORMAT_WEIGHT=10 BUILD_WEIGHT=40 VET_WEIGHT=10 LINT_WEIGHT=20 TYPE_WEIGHT=10 TEST_WEIGHT=20
THRESHOLD=80
EOF
        ;;
esac

# Update or create settings.local.json
SETTINGS_FILE="$TARGET_PATH/.claude/settings.local.json"
echo "Configuring settings.local.json..."

HOOKS_JSON='{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": ".claude/hooks/pre_tool_use.sh bash", "timeout": 2000}]},
      {"matcher": "Edit|Write|MultiEdit", "hooks": [{"type": "command", "command": ".claude/hooks/pre_tool_use.sh edit", "timeout": 2000}]}
    ],
    "PostToolUse": [
      {"matcher": "Edit|Write|MultiEdit", "hooks": [{"type": "command", "command": ".claude/hooks/post_tool_use.sh", "timeout": 30000}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": ".claude/hooks/stop.sh", "timeout": 180000}]}
    ]
  }
}'

if [[ -f "$SETTINGS_FILE" ]] && command -v jq &>/dev/null; then
    backup_if_exists "$SETTINGS_FILE"
    TEMP_FILE=$(mktemp)
    jq --argjson hooks "$(echo "$HOOKS_JSON" | jq '.hooks')" '
        .hooks = (.hooks // {}) |
        .hooks.PreToolUse = ((.hooks.PreToolUse // []) | map(select(.hooks[0].command | contains("pre_tool_use.sh") | not))) + $hooks.PreToolUse |
        .hooks.PostToolUse = ((.hooks.PostToolUse // []) | map(select(.hooks[0].command | contains("post_tool_use.sh") | not))) + $hooks.PostToolUse |
        .hooks.Stop = ((.hooks.Stop // []) | map(select(.hooks[0].command | contains("stop.sh") | not))) + $hooks.Stop
    ' "$SETTINGS_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$SETTINGS_FILE"
    echo "  Merged hooks into existing settings"
elif [[ -f "$SETTINGS_FILE" ]]; then
    echo "  Warning: jq not found, please manually merge hooks"
else
    echo "$HOOKS_JSON" > "$SETTINGS_FILE"
    echo "  Created new settings file"
fi

echo ""
echo "============================================="
echo "  Setup Complete!"
echo "============================================="
echo ""
echo "Next steps:"
echo "  1. Review .claude/hooks.config"
echo "  2. Or run: .claude/scripts/reconfig.sh"
echo "  3. Test: .claude/scripts/verify_loop.sh --quick"
