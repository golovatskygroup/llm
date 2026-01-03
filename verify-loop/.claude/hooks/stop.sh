#!/usr/bin/env bash
# .claude/hooks/stop.sh
# Quality Gate: Full verification before task completion
# Implements the Verify Feedback Loop pattern
# Language-agnostic with configurable commands

set -euo pipefail

MEMORY_DIR=".claude/memory"
ERRORS_LOG="$MEMORY_DIR/errors.log"

mkdir -p "$MEMORY_DIR"

# Load config
CONFIG_FILE=".claude/hooks.config"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Warning: No hooks.config found, using defaults" >&2
fi

# Default weights (can be overridden in config)
FORMAT_WEIGHT="${FORMAT_WEIGHT:-10}"
BUILD_WEIGHT="${BUILD_WEIGHT:-40}"
VET_WEIGHT="${VET_WEIGHT:-10}"
LINT_WEIGHT="${LINT_WEIGHT:-20}"
TYPE_WEIGHT="${TYPE_WEIGHT:-10}"
TEST_WEIGHT="${TEST_WEIGHT:-20}"
THRESHOLD="${THRESHOLD:-80}"

# Run a check and capture output
run_check() {
    local name="$1"
    local cmd="$2"
    local output
    local exit_code=0

    if [[ -z "$cmd" ]]; then
        echo "SKIPPED"
        return 0
    fi

    echo "Running: $name..." >&2
    output=$(eval "$cmd" 2>&1) || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo "$output"
        return 1
    fi

    # For lint commands, check if there are actual issues
    if [[ "$name" == "Lint" ]] && [[ -n "$output" ]]; then
        local issues=$(echo "$output" | grep -v "^$" | grep -v "^[[:space:]]*$" | grep -v "INFO" | grep -v "WARN" | head -20)
        if echo "$issues" | grep -qiE "(error|failed|issue)"; then
            echo "$output"
            return 1
        fi
    fi

    echo "OK"
    return 0
}

# Run full quality check
run_quality_check() {
    local errors=()
    local score=0
    local max_score=0
    local check_output

    echo "=== QUALITY GATE CHECK ===" >&2
    echo "" >&2

    # 1. Format check
    if [[ -n "${FORMAT_CMD:-}" ]]; then
        max_score=$((max_score + FORMAT_WEIGHT))
        echo "Step 1/6: Format check..." >&2
        if check_output=$(run_check "Format" "$FORMAT_CMD"); then
            if [[ "$check_output" != "SKIPPED" ]]; then
                score=$((score + FORMAT_WEIGHT))
            fi
        else
            errors+=("FORMAT CHECK FAILED:\n$check_output")
        fi
    fi

    # 2. Build check
    if [[ -n "${BUILD_CMD:-}" ]]; then
        max_score=$((max_score + BUILD_WEIGHT))
        echo "Step 2/6: Build check..." >&2
        if check_output=$(run_check "Build" "$BUILD_CMD"); then
            if [[ "$check_output" != "SKIPPED" ]]; then
                score=$((score + BUILD_WEIGHT))
            fi
        else
            errors+=("BUILD FAILED:\n$check_output")
        fi
    fi

    # 3. Vet/Static analysis
    if [[ -n "${VET_CMD:-}" ]]; then
        max_score=$((max_score + VET_WEIGHT))
        echo "Step 3/6: Static analysis..." >&2
        if check_output=$(run_check "Vet" "$VET_CMD"); then
            if [[ "$check_output" != "SKIPPED" ]]; then
                score=$((score + VET_WEIGHT))
            fi
        else
            errors+=("VET/STATIC ANALYSIS WARNINGS:\n$check_output")
        fi
    fi

    # 4. Lint check
    if [[ -n "${LINT_CMD:-}" ]]; then
        max_score=$((max_score + LINT_WEIGHT))
        echo "Step 4/6: Lint check..." >&2
        if check_output=$(run_check "Lint" "$LINT_CMD"); then
            if [[ "$check_output" != "SKIPPED" ]]; then
                score=$((score + LINT_WEIGHT))
            fi
        else
            errors+=("LINT ERRORS:\n$check_output")
        fi
    fi

    # 5. Type check
    if [[ -n "${TYPE_CMD:-}" ]]; then
        max_score=$((max_score + TYPE_WEIGHT))
        echo "Step 5/6: Type check..." >&2
        if check_output=$(run_check "Type" "$TYPE_CMD"); then
            if [[ "$check_output" != "SKIPPED" ]]; then
                score=$((score + TYPE_WEIGHT))
            fi
        else
            errors+=("TYPE CHECK ERRORS:\n$check_output")
        fi
    fi

    # 6. Tests
    if [[ -n "${TEST_CMD:-}" ]]; then
        max_score=$((max_score + TEST_WEIGHT))
        echo "Step 6/6: Running tests..." >&2
        if check_output=$(run_check "Tests" "$TEST_CMD"); then
            if [[ "$check_output" != "SKIPPED" ]]; then
                score=$((score + TEST_WEIGHT))
            fi
        else
            errors+=("TEST FAILURES:\n$check_output")
        fi
    fi

    echo "" >&2
    echo "=== CHECK COMPLETE ===" >&2

    # Calculate percentage if max_score > 0
    local percentage=100
    if [[ $max_score -gt 0 ]]; then
        percentage=$((score * 100 / max_score))
    fi

    # Determine pass/fail
    local status="pass"
    local passed=true
    if [[ $percentage -lt $THRESHOLD ]]; then
        status="fail"
        passed=false
    fi

    # Format errors as JSON array
    local errors_json="[]"
    if [[ ${#errors[@]} -gt 0 ]]; then
        errors_json=$(printf '%s\n' "${errors[@]}" | jq -R -s 'split("\n") | map(select(. != ""))')
    fi

    jq -n \
        --arg status "$status" \
        --arg score "$score" \
        --arg max_score "$max_score" \
        --arg percentage "$percentage" \
        --argjson errors "$errors_json" \
        --arg threshold "$THRESHOLD" \
        --argjson passed "$passed" \
        '{
            quality_gate: $status,
            score: ($score | tonumber),
            max_score: ($max_score | tonumber),
            percentage: ($percentage | tonumber),
            errors: $errors,
            threshold: ($threshold | tonumber),
            passed: $passed
        }'
}

# Main
main() {
    echo "[$(date -Iseconds)] Quality Gate triggered" >&2

    # Run quality check
    local result=$(run_quality_check)
    local passed=$(echo "$result" | jq -r '.passed')
    local score=$(echo "$result" | jq -r '.score')
    local max_score=$(echo "$result" | jq -r '.max_score')
    local percentage=$(echo "$result" | jq -r '.percentage')
    local errors=$(echo "$result" | jq -r '.errors | join("\n\n")')

    # Log result
    echo "[$(date -Iseconds)] Quality Gate result: score=$score/$max_score ($percentage%) passed=$passed" >> "$ERRORS_LOG"

    # If not passed, block completion
    if [[ "$passed" != "true" ]]; then
        echo "" >&2
        echo "=============================================" >&2
        echo "QUALITY GATE FAILED (Score: $percentage%)" >&2
        echo "Threshold: $THRESHOLD%" >&2
        echo "=============================================" >&2
        echo "" >&2
        echo "Please fix the following issues:" >&2
        echo "$errors" >&2
        echo "" >&2

        # Return blocking response
        jq -n \
            --arg reason "Quality gate failed (score: $percentage%). Fix the errors and try again." \
            --arg errors "$errors" \
            '{
                "decision": "block",
                "reason": $reason,
                "systemMessage": ("Your work is blocked by the quality gate. Analyze the errors below, fix the code, and try to complete again.\n\n" + $errors)
            }'

        exit 2
    fi

    echo "" >&2
    echo "=============================================" >&2
    echo "QUALITY GATE PASSED (Score: $percentage%)" >&2
    echo "=============================================" >&2

    # Return success
    echo "$result"
    exit 0
}

main
