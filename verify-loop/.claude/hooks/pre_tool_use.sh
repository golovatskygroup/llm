#!/usr/bin/env bash
# .claude/hooks/pre_tool_use.sh
# Security guard: blocks dangerous commands before execution
# Language-agnostic version

set -euo pipefail

TOOL_TYPE="${1:-unknown}"

# Load config if exists
CONFIG_FILE=".claude/hooks.config"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Default protected files (can be extended in hooks.config)
DEFAULT_PROTECTED_FILES=(
    ".env"
    ".env.local"
    ".env.production"
    ".env.secret"
    ".env.*"
    ".git/config"
    ".git/HEAD"
    "id_rsa"
    "id_ed25519"
    "*.pem"
    "*.key"
    "secrets.yaml"
    "secrets.json"
    "credentials.json"
    "*.tfstate"
    "*.tfstate.backup"
)

# Merge with custom protected files from config
PROTECTED_FILES=("${DEFAULT_PROTECTED_FILES[@]}" ${CUSTOM_PROTECTED_FILES:-})

# Read tool input from environment or stdin
read_tool_input() {
    local input="${CLAUDE_TOOL_INPUT:-}"
    if [[ -z "$input" ]]; then
        input=$(cat 2>/dev/null || echo "{}")
    fi
    echo "$input"
}

# Guard for Bash commands
guard_bash() {
    local input="$1"
    local cmd=$(echo "$input" | jq -r '.command // ""' 2>/dev/null || echo "")

    # Blocked dangerous commands
    local blocked_commands=(
        "rm -rf"
        "rm -fr"
        "rm -r /"
        "sudo"
        "chmod 777"
        "chmod -R 777"
        "mv .git"
        "rm .git"
        "rm -rf .git"
        "git push --force"
        "git push -f"
        "git reset --hard"
        "git clean -fd"
        "> /dev"
        "dd if="
        "mkfs"
        "fdisk"
        "shutdown"
        "reboot"
        "init 0"
        "curl | sh"
        "wget | sh"
        "curl | bash"
        "wget | bash"
        "curl -s | sh"
        "wget -q | sh"
    )

    for blocked in "${blocked_commands[@]}"; do
        if echo "$cmd" | grep -qi "$blocked"; then
            echo "{\"decision\": \"block\", \"reason\": \"Blocked dangerous command: $blocked\"}"
            return 2
        fi
    done

    # Block piped shell execution patterns
    if echo "$cmd" | grep -qE "(curl|wget).*\|.*(sh|bash)"; then
        echo "{\"decision\": \"block\", \"reason\": \"Blocked piped shell execution\"}"
        return 2
    fi

    return 0
}

# Guard for file editing
guard_edit() {
    local input="$1"
    local file=$(echo "$input" | jq -r '.file_path // .path // ""' 2>/dev/null || echo "")

    for pattern in "${PROTECTED_FILES[@]}"; do
        case "$file" in
            $pattern|*/$pattern)
                echo "{\"decision\": \"block\", \"reason\": \"Protected file: $file cannot be modified directly\"}"
                return 2
                ;;
        esac
    done

    # Block vendor/node_modules directories
    if [[ "$file" == vendor/* ]] || [[ "$file" == */vendor/* ]]; then
        echo "{\"decision\": \"block\", \"reason\": \"Vendor directory is read-only. Use package manager to update.\"}"
        return 2
    fi

    if [[ "$file" == node_modules/* ]] || [[ "$file" == */node_modules/* ]]; then
        echo "{\"decision\": \"block\", \"reason\": \"node_modules is read-only. Use npm/yarn to manage dependencies.\"}"
        return 2
    fi

    return 0
}

# Main
main() {
    local input=$(read_tool_input)

    case "$TOOL_TYPE" in
        bash)
            guard_bash "$input"
            ;;
        edit)
            guard_edit "$input"
            ;;
        *)
            # Unknown tool type - allow
            ;;
    esac

    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "{\"decision\": \"allow\"}"
    fi

    exit $exit_code
}

main
