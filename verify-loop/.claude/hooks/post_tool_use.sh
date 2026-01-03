#!/usr/bin/env bash
# .claude/hooks/post_tool_use.sh
# Auto-format files after edit and run quick checks
# Language-agnostic with auto-detection

set -euo pipefail

MEMORY_DIR=".claude/memory"
ERRORS_LOG="$MEMORY_DIR/errors.log"

mkdir -p "$MEMORY_DIR"

# Load config if exists
CONFIG_FILE=".claude/hooks.config"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Get modified files from environment
get_modified_files() {
    local files="${CLAUDE_FILE_PATHS:-}"

    if [[ -z "$files" ]]; then
        local output="${CLAUDE_TOOL_OUTPUT:-}"
        if [[ -n "$output" ]]; then
            files=$(echo "$output" | jq -r '.file_path // .path // ""' 2>/dev/null || echo "")
        fi
    fi

    echo "$files"
}

# Detect file language from extension
detect_language() {
    local file="$1"
    case "$file" in
        *.go)
            echo "go"
            ;;
        *.py)
            echo "python"
            ;;
        *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs)
            echo "node"
            ;;
        *.json)
            echo "json"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Format Go files
format_go() {
    local file="$1"
    local formatted=0

    if [[ -f "$file" ]]; then
        # gofmt
        if command -v gofmt &>/dev/null; then
            if gofmt -w "$file" 2>/dev/null; then
                ((formatted++)) || true
            fi
        fi

        # goimports (if available)
        if command -v goimports &>/dev/null; then
            goimports -w "$file" 2>/dev/null || true
        fi
    fi

    echo "$formatted"
}

# Format Python files
format_python() {
    local file="$1"
    local formatted=0

    if [[ -f "$file" ]]; then
        # Prefer ruff (faster)
        if command -v ruff &>/dev/null; then
            ruff format "$file" 2>/dev/null && ((formatted++)) || true
            ruff check --fix "$file" 2>/dev/null || true
        # Fallback to black
        elif command -v black &>/dev/null; then
            black --quiet "$file" 2>/dev/null && ((formatted++)) || true
        fi

        # isort for imports (if available and ruff not used)
        if ! command -v ruff &>/dev/null && command -v isort &>/dev/null; then
            isort --quiet "$file" 2>/dev/null || true
        fi
    fi

    echo "$formatted"
}

# Format Node/JS/TS files
format_node() {
    local file="$1"
    local formatted=0

    if [[ -f "$file" ]]; then
        # Prefer biome (faster)
        if command -v biome &>/dev/null; then
            biome format --write "$file" 2>/dev/null && ((formatted++)) || true
        # Fallback to prettier
        elif command -v prettier &>/dev/null; then
            prettier --write "$file" 2>/dev/null && ((formatted++)) || true
        # Fallback to npx prettier
        elif command -v npx &>/dev/null; then
            npx prettier --write "$file" 2>/dev/null && ((formatted++)) || true
        fi
    fi

    echo "$formatted"
}

# Format JSON files
format_json() {
    local file="$1"
    local formatted=0

    if [[ -f "$file" ]]; then
        if command -v biome &>/dev/null; then
            biome format --write "$file" 2>/dev/null && ((formatted++)) || true
        elif command -v prettier &>/dev/null; then
            prettier --write "$file" 2>/dev/null && ((formatted++)) || true
        fi
    fi

    echo "$formatted"
}

# Format files based on language
format_files() {
    local files="$1"
    local total_formatted=0

    for file in $files; do
        if [[ ! -f "$file" ]]; then
            continue
        fi

        local lang=$(detect_language "$file")
        local formatted=0

        case "$lang" in
            go)
                formatted=$(format_go "$file")
                ;;
            python)
                formatted=$(format_python "$file")
                ;;
            node)
                formatted=$(format_node "$file")
                ;;
            json)
                formatted=$(format_json "$file")
                ;;
        esac

        total_formatted=$((total_formatted + formatted))
    done

    # Handle package manager files
    if echo "$files" | grep -q "go.mod"; then
        if command -v go &>/dev/null; then
            go mod tidy 2>/dev/null || true
        fi
    fi

    if echo "$files" | grep -q "package.json"; then
        # Don't auto-run npm install - just note it
        echo "[$(date -Iseconds)] package.json modified - consider running npm install" >> "$ERRORS_LOG"
    fi

    echo "$total_formatted"
}

# Quick build check based on language
run_quick_build() {
    local files="$1"
    local has_go=false
    local has_ts=false

    for file in $files; do
        case "$file" in
            *.go) has_go=true ;;
            *.ts|*.tsx) has_ts=true ;;
        esac
    done

    # Go build check
    if [[ "$has_go" == "true" ]] && command -v go &>/dev/null; then
        local build_output
        local build_exit=0
        build_output=$(go build ./... 2>&1) || build_exit=$?
        if [[ $build_exit -ne 0 ]]; then
            echo "[$(date -Iseconds)] Quick build check failed: $build_output" >> "$ERRORS_LOG"
            echo "$build_output"
            return 1
        fi
    fi

    # TypeScript type check (quick)
    if [[ "$has_ts" == "true" ]] && command -v tsc &>/dev/null; then
        local tsc_output
        tsc_output=$(tsc --noEmit 2>&1) || true
        # Don't fail on TS errors in post-hook, just log
        if [[ -n "$tsc_output" ]]; then
            echo "[$(date -Iseconds)] TypeScript warnings: $tsc_output" >> "$ERRORS_LOG"
        fi
    fi

    return 0
}

# Main
main() {
    local files=$(get_modified_files)

    # Skip if no files
    if [[ -z "$files" ]]; then
        echo "{\"status\": \"skipped\", \"reason\": \"No files to process\"}"
        exit 0
    fi

    # Format files
    local formatted=$(format_files "$files")

    # Quick build check
    local build_status="ok"
    local build_error=""
    if ! build_error=$(run_quick_build "$files"); then
        build_status="warning"
    fi

    # Output result
    if [[ "$build_status" == "ok" ]]; then
        echo "{\"status\": \"ok\", \"formatted\": $formatted}"
    else
        # Escape build error for JSON
        local escaped_error=$(echo "$build_error" | head -c 200 | tr '\n' ' ' | sed 's/"/\\"/g')
        echo "{\"status\": \"warning\", \"formatted\": $formatted, \"build_note\": \"$escaped_error\"}"
    fi

    exit 0
}

main
