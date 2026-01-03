#!/usr/bin/env bash
# .claude/hooks/pre_tool_use.sh
# Security guard: blocks dangerous commands before execution

set -euo pipefail

TOOL_TYPE="${1:-unknown}"

# Load config
CONFIG_FILE=".claude/hooks.config"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Protected files (can be extended via CUSTOM_PROTECTED_FILES in config)
PROTECTED_FILES=(
    ".env" ".env.local" ".env.production" ".env.secret" ".env.*"
    ".git/config" ".git/HEAD" "id_rsa" "id_ed25519"
    "*.pem" "*.key" "secrets.yaml" "secrets.json" "credentials.json"
    "*.tfstate" "*.tfstate.backup"
    ${CUSTOM_PROTECTED_FILES:-}
)

# Read tool input
read_tool_input() {
    local input="${CLAUDE_TOOL_INPUT:-}"
    [[ -z "$input" ]] && input=$(cat 2>/dev/null || echo "{}")
    echo "$input"
}

# Guard for Bash commands
guard_bash() {
    local input="$1"
    local cmd=$(echo "$input" | jq -r '.command // ""' 2>/dev/null || echo "")

    # Blocked dangerous commands
    local blocked=(
        "rm -rf" "rm -fr" "rm -r /" "sudo" "chmod 777" "chmod -R 777"
        "mv .git" "rm .git" "rm -rf .git"
        "git push --force" "git push -f" "git reset --hard" "git clean -fd"
        "> /dev" "dd if=" "mkfs" "fdisk" "shutdown" "reboot" "init 0"
        "curl | sh" "wget | sh" "curl | bash" "wget | bash" "curl -s | sh" "wget -q | sh"
    )

    for pattern in "${blocked[@]}"; do
        if echo "$cmd" | grep -qi "$pattern"; then
            echo "{\"decision\":\"block\",\"reason\":\"Blocked: $pattern\"}"
            return 2
        fi
    done

    # Block piped shell execution
    if echo "$cmd" | grep -qE "(curl|wget).*\|.*(sh|bash)"; then
        echo "{\"decision\":\"block\",\"reason\":\"Blocked piped shell execution\"}"
        return 2
    fi
}

# Guard for file editing
guard_edit() {
    local input="$1"
    local file=$(echo "$input" | jq -r '.file_path // .path // ""' 2>/dev/null || echo "")

    for pattern in "${PROTECTED_FILES[@]}"; do
        case "$file" in
            $pattern|*/$pattern)
                echo "{\"decision\":\"block\",\"reason\":\"Protected file: $file\"}"
                return 2 ;;
        esac
    done

    # Block vendor/node_modules
    if [[ "$file" == vendor/* ]] || [[ "$file" == */vendor/* ]] || \
       [[ "$file" == node_modules/* ]] || [[ "$file" == */node_modules/* ]]; then
        echo "{\"decision\":\"block\",\"reason\":\"Dependencies dir is read-only\"}"
        return 2
    fi
}

main() {
    local input=$(read_tool_input)

    case "$TOOL_TYPE" in
        bash) guard_bash "$input" ;;
        edit) guard_edit "$input" ;;
    esac

    local exit_code=$?
    [[ $exit_code -eq 0 ]] && echo "{\"decision\":\"allow\"}"
    exit $exit_code
}

main
