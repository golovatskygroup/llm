#!/usr/bin/env bash
# setup-hooks.sh
# Installs Claude Code quality hooks into a project
# Usage: ./setup-hooks.sh [--path /path/to/project]

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
            echo "Installs Claude Code quality hooks into the specified project."
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
echo "  Claude Code Hooks Setup"
echo "============================================="
echo ""
echo "Target: $TARGET_PATH"
echo ""

# Detect project language
detect_language() {
    local path="$1"

    if [[ -f "$path/go.mod" ]]; then
        echo "go"
    elif [[ -f "$path/package.json" ]]; then
        echo "node"
    elif [[ -f "$path/pyproject.toml" ]] || [[ -f "$path/setup.py" ]]; then
        echo "python"
    else
        echo "generic"
    fi
}

LANGUAGE=$(detect_language "$TARGET_PATH")
echo "Detected language: $LANGUAGE"
echo ""

# Create directories
echo "Creating directories..."
mkdir -p "$TARGET_PATH/.claude/hooks"
mkdir -p "$TARGET_PATH/.claude/scripts"
mkdir -p "$TARGET_PATH/.claude/memory"

# Backup existing files
backup_if_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "  Backing up: $file -> $backup"
        cp "$file" "$backup"
    fi
}

# Copy hooks
echo "Installing hooks..."
backup_if_exists "$TARGET_PATH/.claude/hooks/pre_tool_use.sh"
backup_if_exists "$TARGET_PATH/.claude/hooks/post_tool_use.sh"
backup_if_exists "$TARGET_PATH/.claude/hooks/stop.sh"

cp "$SCRIPT_DIR/.claude/hooks/pre_tool_use.sh" "$TARGET_PATH/.claude/hooks/"
cp "$SCRIPT_DIR/.claude/hooks/post_tool_use.sh" "$TARGET_PATH/.claude/hooks/"
cp "$SCRIPT_DIR/.claude/hooks/stop.sh" "$TARGET_PATH/.claude/hooks/"

# Copy scripts
echo "Installing scripts..."
backup_if_exists "$TARGET_PATH/.claude/scripts/verify_loop.sh"
backup_if_exists "$TARGET_PATH/.claude/scripts/reconfig.sh"

cp "$SCRIPT_DIR/.claude/scripts/verify_loop.sh" "$TARGET_PATH/.claude/scripts/"
cp "$SCRIPT_DIR/.claude/scripts/reconfig.sh" "$TARGET_PATH/.claude/scripts/"

# Make executable
chmod +x "$TARGET_PATH/.claude/hooks/"*.sh
chmod +x "$TARGET_PATH/.claude/scripts/"*.sh

# Create hooks.config based on language
echo "Creating hooks.config for $LANGUAGE..."
backup_if_exists "$TARGET_PATH/.claude/hooks.config"

case "$LANGUAGE" in
    go)
        cp "$SCRIPT_DIR/templates/hooks.config.go" "$TARGET_PATH/.claude/hooks.config"
        # Copy .golangci.yml if it doesn't exist
        if [[ ! -f "$TARGET_PATH/.golangci.yml" ]]; then
            echo "  Copying .golangci.yml template..."
            cp "$SCRIPT_DIR/templates/.golangci.yml" "$TARGET_PATH/"
        fi
        ;;
    node)
        cp "$SCRIPT_DIR/templates/hooks.config.node" "$TARGET_PATH/.claude/hooks.config"
        # Copy biome.json if it doesn't exist and no eslint config
        if [[ ! -f "$TARGET_PATH/biome.json" ]] && [[ ! -f "$TARGET_PATH/.eslintrc.js" ]] && [[ ! -f "$TARGET_PATH/.eslintrc.json" ]]; then
            echo "  Copying biome.json template..."
            cp "$SCRIPT_DIR/templates/biome.json" "$TARGET_PATH/"
        fi
        ;;
    python)
        cp "$SCRIPT_DIR/templates/hooks.config.python" "$TARGET_PATH/.claude/hooks.config"
        # Copy ruff.toml if it doesn't exist
        if [[ ! -f "$TARGET_PATH/ruff.toml" ]] && [[ ! -f "$TARGET_PATH/pyproject.toml" ]]; then
            echo "  Copying ruff.toml template..."
            cp "$SCRIPT_DIR/templates/ruff.toml" "$TARGET_PATH/"
        fi
        ;;
    *)
        # Generic config
        cat > "$TARGET_PATH/.claude/hooks.config" << 'EOF'
# Claude Code Hooks Configuration
# Language: generic (auto-detected)
LANGUAGE="generic"

# Commands (empty = skip check)
# Configure these for your project
FORMAT_CMD=""
IMPORTS_CMD=""
BUILD_CMD=""
VET_CMD=""
LINT_CMD=""
TYPE_CMD=""
TEST_CMD=""

# Scoring weights
FORMAT_WEIGHT=10
BUILD_WEIGHT=40
VET_WEIGHT=10
LINT_WEIGHT=20
TYPE_WEIGHT=10
TEST_WEIGHT=20

# Threshold to pass quality gate (percentage)
THRESHOLD=80

# Custom protected files (add project-specific patterns)
# CUSTOM_PROTECTED_FILES=("terraform.tfstate" "custom_secrets.json")
EOF
        ;;
esac

# Update or create settings.local.json
SETTINGS_FILE="$TARGET_PATH/.claude/settings.local.json"
echo "Configuring settings.local.json..."

if [[ -f "$SETTINGS_FILE" ]]; then
    backup_if_exists "$SETTINGS_FILE"

    # Merge hooks into existing settings using jq
    if command -v jq &>/dev/null; then
        TEMP_FILE=$(mktemp)

        jq '.hooks = (.hooks // {}) |
            .hooks.PreToolUse = ((.hooks.PreToolUse // []) | map(select(.hooks[0].command | contains("pre_tool_use.sh") | not))) + [
                {"matcher": "Bash", "hooks": [{"type": "command", "command": ".claude/hooks/pre_tool_use.sh bash", "timeout": 2000}]},
                {"matcher": "Edit|Write|MultiEdit", "hooks": [{"type": "command", "command": ".claude/hooks/pre_tool_use.sh edit", "timeout": 2000}]}
            ] |
            .hooks.PostToolUse = ((.hooks.PostToolUse // []) | map(select(.hooks[0].command | contains("post_tool_use.sh") | not))) + [
                {"matcher": "Edit|Write|MultiEdit", "hooks": [{"type": "command", "command": ".claude/hooks/post_tool_use.sh", "timeout": 30000}]}
            ] |
            .hooks.Stop = ((.hooks.Stop // []) | map(select(.hooks[0].command | contains("stop.sh") | not))) + [
                {"hooks": [{"type": "command", "command": ".claude/hooks/stop.sh", "timeout": 180000}]}
            ]' "$SETTINGS_FILE" > "$TEMP_FILE"

        mv "$TEMP_FILE" "$SETTINGS_FILE"
        echo "  Merged hooks into existing settings"
    else
        echo "  Warning: jq not found, cannot merge settings"
        echo "  Please manually add hooks to $SETTINGS_FILE"
    fi
else
    # Create new settings file
    cat > "$SETTINGS_FILE" << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/pre_tool_use.sh bash",
            "timeout": 2000
          }
        ]
      },
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/pre_tool_use.sh edit",
            "timeout": 2000
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/post_tool_use.sh",
            "timeout": 30000
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/stop.sh",
            "timeout": 180000
          }
        ]
      }
    ]
  }
}
EOF
    echo "  Created new settings file"
fi

echo ""
echo "============================================="
echo "  Setup Complete!"
echo "============================================="
echo ""
echo "Installed files:"
echo "  - .claude/hooks/pre_tool_use.sh"
echo "  - .claude/hooks/post_tool_use.sh"
echo "  - .claude/hooks/stop.sh"
echo "  - .claude/scripts/verify_loop.sh"
echo "  - .claude/scripts/reconfig.sh"
echo "  - .claude/hooks.config"
echo "  - .claude/settings.local.json"
echo ""
echo "Next steps:"
echo "  1. Review .claude/hooks.config and adjust commands if needed"
echo "  2. Or run: .claude/scripts/reconfig.sh"
echo "     to let Claude analyze and configure hooks automatically"
echo "  3. Test with: .claude/scripts/verify_loop.sh --quick"
echo ""
