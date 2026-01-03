#!/usr/bin/env bash
# .claude/hooks/post_tool_use.sh
# Auto-format files after edit and run quick checks

set -euo pipefail

MEMORY_DIR=".claude/memory"
ERRORS_LOG="$MEMORY_DIR/errors.log"
mkdir -p "$MEMORY_DIR"

# Load config
CONFIG_FILE=".claude/hooks.config"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Helper: check if command exists
cmd_exists() { command -v "$1" &>/dev/null; }

# Get modified files from environment
get_modified_files() {
    local files="${CLAUDE_FILE_PATHS:-}"
    if [[ -z "$files" ]]; then
        local output="${CLAUDE_TOOL_OUTPUT:-}"
        [[ -n "$output" ]] && files=$(echo "$output" | jq -r '.file_path // .path // ""' 2>/dev/null || echo "")
    fi
    echo "$files"
}

# Detect file language
detect_lang() {
    case "$1" in
        *.go) echo "go" ;;
        *.py) echo "python" ;;
        *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs) echo "node" ;;
        *.json) echo "json" ;;
        *) echo "unknown" ;;
    esac
}

# Format a single file based on language
format_file() {
    local file="$1" lang="$2"
    [[ ! -f "$file" ]] && return 1

    case "$lang" in
        go)
            cmd_exists gofmt && gofmt -w "$file" 2>/dev/null
            cmd_exists goimports && goimports -w "$file" 2>/dev/null
            ;;
        python)
            if cmd_exists ruff; then
                ruff format "$file" 2>/dev/null
                ruff check --fix "$file" 2>/dev/null || true
            elif cmd_exists black; then
                black --quiet "$file" 2>/dev/null
                cmd_exists isort && isort --quiet "$file" 2>/dev/null
            fi
            ;;
        node|json)
            if cmd_exists biome; then
                biome format --write "$file" 2>/dev/null
            elif cmd_exists prettier; then
                prettier --write "$file" 2>/dev/null
            elif cmd_exists npx; then
                npx prettier --write "$file" 2>/dev/null
            fi
            ;;
    esac
    return 0
}

# Format all files
format_files() {
    local files="$1" formatted=0

    for file in $files; do
        [[ ! -f "$file" ]] && continue
        local lang=$(detect_lang "$file")
        format_file "$file" "$lang" && ((formatted++)) || true
    done

    # Handle package manager files
    if echo "$files" | grep -q "go.mod"; then
        cmd_exists go && go mod tidy 2>/dev/null || true
    fi
    if echo "$files" | grep -q "package.json"; then
        echo "[$(date -Iseconds)] package.json modified - consider npm install" >> "$ERRORS_LOG"
    fi

    echo "$formatted"
}

# Quick build check
run_quick_build() {
    local files="$1" has_go=false has_ts=false

    for file in $files; do
        case "$file" in
            *.go) has_go=true ;;
            *.ts|*.tsx) has_ts=true ;;
        esac
    done

    if [[ "$has_go" == "true" ]] && cmd_exists go; then
        local output exit_code=0
        output=$(go build ./... 2>&1) || exit_code=$?
        if [[ $exit_code -ne 0 ]]; then
            echo "[$(date -Iseconds)] Build failed: $output" >> "$ERRORS_LOG"
            echo "$output"
            return 1
        fi
    fi

    if [[ "$has_ts" == "true" ]] && cmd_exists tsc; then
        local output
        output=$(tsc --noEmit 2>&1) || true
        [[ -n "$output" ]] && echo "[$(date -Iseconds)] TS warnings: $output" >> "$ERRORS_LOG"
    fi
}

main() {
    local files=$(get_modified_files)

    if [[ -z "$files" ]]; then
        echo '{"status":"skipped","reason":"No files"}'
        exit 0
    fi

    local formatted=$(format_files "$files")
    local build_status="ok" build_error=""

    if ! build_error=$(run_quick_build "$files"); then
        build_status="warning"
    fi

    if [[ "$build_status" == "ok" ]]; then
        echo "{\"status\":\"ok\",\"formatted\":$formatted}"
    else
        local escaped=$(echo "$build_error" | head -c 200 | tr '\n' ' ' | sed 's/"/\\"/g')
        echo "{\"status\":\"warning\",\"formatted\":$formatted,\"build_note\":\"$escaped\"}"
    fi
}

main
