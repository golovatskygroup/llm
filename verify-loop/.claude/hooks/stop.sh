#!/usr/bin/env bash
# .claude/hooks/stop.sh
# Quality Gate: Full verification before task completion

set -euo pipefail

MEMORY_DIR=".claude/memory"
ERRORS_LOG="$MEMORY_DIR/errors.log"
mkdir -p "$MEMORY_DIR"

# Load config
CONFIG_FILE=".claude/hooks.config"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE" || echo "Warning: No hooks.config found" >&2

# Default weights
: "${FORMAT_WEIGHT:=10}" "${BUILD_WEIGHT:=40}" "${VET_WEIGHT:=10}"
: "${LINT_WEIGHT:=20}" "${TYPE_WEIGHT:=10}" "${TEST_WEIGHT:=20}" "${THRESHOLD:=80}"

# Run a check and capture output
run_check() {
    local name="$1" cmd="$2" output exit_code=0
    [[ -z "$cmd" ]] && { echo "SKIPPED"; return 0; }
    echo "Running: $name..." >&2
    output=$(eval "$cmd" 2>&1) || exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo "$output"
        return 1
    fi
    # For lint: check for actual issues
    if [[ "$name" == "LINT" ]] && [[ -n "$output" ]]; then
        local issues=$(echo "$output" | grep -v "^$" | grep -v "^[[:space:]]*$" | grep -v "INFO" | grep -v "WARN" | head -20)
        if echo "$issues" | grep -qiE "(error|failed|issue)"; then
            echo "$output"
            return 1
        fi
    fi
    echo "OK"
}

# Run full quality check
run_quality_check() {
    local errors=() score=0 max_score=0 check_output step=1

    echo "=== QUALITY GATE CHECK ===" >&2
    echo "" >&2

    # Check definitions: NAME|CMD_VAR|WEIGHT_VAR
    local checks="FORMAT|FORMAT_CMD|FORMAT_WEIGHT BUILD|BUILD_CMD|BUILD_WEIGHT VET|VET_CMD|VET_WEIGHT LINT|LINT_CMD|LINT_WEIGHT TYPE|TYPE_CMD|TYPE_WEIGHT TEST|TEST_CMD|TEST_WEIGHT"

    for check in $checks; do
        IFS='|' read -r name cmd_var weight_var <<< "$check"
        local cmd="${!cmd_var:-}" weight="${!weight_var:-0}"

        if [[ -n "$cmd" ]]; then
            max_score=$((max_score + weight))
            echo "Step $step/6: $name check..." >&2
            if check_output=$(run_check "$name" "$cmd"); then
                [[ "$check_output" != "SKIPPED" ]] && score=$((score + weight))
            else
                errors+=("$name FAILED:\n$check_output")
            fi
        fi
        ((step++))
    done

    echo "" >&2
    echo "=== CHECK COMPLETE ===" >&2

    # Calculate percentage
    local percentage=100
    [[ $max_score -gt 0 ]] && percentage=$((score * 100 / max_score))

    local passed=true status="pass"
    [[ $percentage -lt $THRESHOLD ]] && { status="fail"; passed=false; }

    # Format errors as JSON
    local errors_json="[]"
    [[ ${#errors[@]} -gt 0 ]] && errors_json=$(printf '%s\n' "${errors[@]}" | jq -R -s 'split("\n") | map(select(. != ""))')

    jq -n --arg status "$status" --arg score "$score" --arg max_score "$max_score" \
        --arg percentage "$percentage" --argjson errors "$errors_json" \
        --arg threshold "$THRESHOLD" --argjson passed "$passed" \
        '{quality_gate:$status,score:($score|tonumber),max_score:($max_score|tonumber),percentage:($percentage|tonumber),errors:$errors,threshold:($threshold|tonumber),passed:$passed}'
}

main() {
    echo "[$(date -Iseconds)] Quality Gate triggered" >&2

    local result=$(run_quality_check)
    local passed=$(echo "$result" | jq -r '.passed')
    local percentage=$(echo "$result" | jq -r '.percentage')
    local errors=$(echo "$result" | jq -r '.errors | join("\n\n")')

    echo "[$(date -Iseconds)] Quality Gate: $percentage% passed=$passed" >> "$ERRORS_LOG"

    if [[ "$passed" != "true" ]]; then
        echo -e "\n=============================================\nQUALITY GATE FAILED (Score: $percentage%)\nThreshold: $THRESHOLD%\n=============================================\n\nPlease fix:\n$errors\n" >&2
        jq -n --arg reason "Quality gate failed ($percentage%). Fix errors and retry." --arg errors "$errors" \
            '{"decision":"block","reason":$reason,"systemMessage":("Fix these errors:\n\n"+$errors)}'
        exit 2
    fi

    echo -e "\n=============================================\nQUALITY GATE PASSED (Score: $percentage%)\n=============================================" >&2
    echo "$result"
}

main
