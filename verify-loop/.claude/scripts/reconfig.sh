#!/usr/bin/env bash
# .claude/scripts/reconfig.sh
# Runs Claude Code non-interactively to adapt hooks for this project
# Usage: .claude/scripts/reconfig.sh

set -euo pipefail

CONFIG_FILE=".claude/hooks.config"

# Check if claude is available
if ! command -v claude &>/dev/null; then
    echo "Error: Claude Code CLI not found"
    echo "Install it from: https://github.com/anthropics/claude-code"
    exit 1
fi

# Check if config exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: $CONFIG_FILE not found"
    echo "Run setup-hooks.sh first to create the initial configuration"
    exit 1
fi

echo "============================================="
echo "  Claude-Powered Hooks Configuration"
echo "============================================="
echo ""
echo "This script will analyze your project and update"
echo ".claude/hooks.config with project-specific commands."
echo ""

# Create the prompt
PROMPT=$(cat <<'PROMPT_EOF'
Analyze this project and update .claude/hooks.config to match the project's actual tools and style.

## Steps:

1. **Detect Language & Tools**
   - Check for: go.mod (Go), package.json (Node/TS), pyproject.toml/setup.py (Python)
   - Look at existing tool configs: .golangci.yml, biome.json, .eslintrc*, ruff.toml, mypy.ini

2. **Check Makefile**
   - Look for targets: build, test, lint, fmt, format, check, vet
   - Use make targets if they exist (e.g., `make lint` instead of direct tool call)

3. **Check CI/CD configs**
   - Look in: .github/workflows/, .gitlab-ci.yml, Jenkinsfile
   - Extract the actual commands used in CI for testing/linting

4. **Update .claude/hooks.config**
   Edit the file to set appropriate values for:
   - LANGUAGE (go/python/node/generic)
   - FORMAT_CMD (formatter command)
   - IMPORTS_CMD (import organizer, mainly for Go)
   - BUILD_CMD (build/compile command)
   - VET_CMD (static analysis)
   - LINT_CMD (linter command)
   - TYPE_CMD (type checker)
   - TEST_CMD (test runner)

   Leave commands empty if the tool isn't used in this project.

5. **Check for custom protected files**
   If the project has special files that should be protected (terraform state, custom secrets, etc.),
   add them to CUSTOM_PROTECTED_FILES in the config.

## Important Rules:
- Use `make <target>` if a Makefile target exists for that operation
- For Go: prefer golangci-lint over individual linters
- For Node/TS: prefer biome over eslint+prettier if biome.json exists
- For Python: prefer ruff over flake8/black if ruff.toml exists
- Only set commands for tools that are actually installed/configured

## Output:
After updating the config file, output a brief summary of what you changed.
PROMPT_EOF
)

echo "Running Claude to analyze project..."
echo ""

# Run claude non-interactively
claude --print -p "$PROMPT"

echo ""
echo "============================================="
echo "Configuration complete!"
echo ""
echo "To verify the configuration, run:"
echo "  .claude/scripts/verify_loop.sh --quick"
echo "============================================="
