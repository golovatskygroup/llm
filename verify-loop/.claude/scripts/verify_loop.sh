#!/usr/bin/env bash
# .claude/scripts/verify_loop.sh
# Standalone verification script
# Usage: .claude/scripts/verify_loop.sh [--quick]

set -euo pipefail

QUICK_MODE=false
[[ "${1:-}" == "--quick" ]] && QUICK_MODE=true

# Colors
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'

# Load config
CONFIG_FILE=".claude/hooks.config"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Error: No hooks.config found${NC}"
    echo "Run setup-hooks.sh first"
    exit 1
fi
source "$CONFIG_FILE"

run_check() {
    local name="$1" cmd="$2" output exit_code=0
    if [[ -z "$cmd" ]]; then
        echo -e "${YELLOW}[SKIP]${NC} $name (not configured)"
        return 2
    fi
    echo -e "${YELLOW}[STEP]${NC} $name"
    output=$(eval "$cmd" 2>&1) || exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}[PASS]${NC} $name"
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $name"
        echo "$output" | head -30
        return 1
    fi
}

main() {
    local passed=0 failed=0 skipped=0

    echo "============================================="
    echo -e "${BLUE}       QUALITY VERIFICATION LOOP${NC}"
    echo "============================================="
    echo ""
    echo "Language: ${LANGUAGE:-unknown}"
    echo ""

    # Check definitions: NAME|CMD_VAR
    local checks="Format Check|FORMAT_CMD Build Check|BUILD_CMD Static Analysis|VET_CMD Lint Check|LINT_CMD Type Check|TYPE_CMD"

    for check in $checks; do
        IFS='|' read -r name cmd_var <<< "$check"
        local cmd="${!cmd_var:-}"
        local result=0
        run_check "$name" "$cmd" || result=$?
        case $result in
            0) ((passed++)) ;;
            1) ((failed++)) ;;
            2) ((skipped++)) ;;
        esac
        echo ""
    done

    # Tests (skip in quick mode)
    if [[ "$QUICK_MODE" == "true" ]]; then
        echo -e "${YELLOW}[SKIP]${NC} Tests (quick mode)"
        echo ""
    else
        local result=0
        run_check "Tests" "${TEST_CMD:-}" || result=$?
        case $result in
            0) ((passed++)) ;;
            1) ((failed++)) ;;
            2) ((skipped++)) ;;
        esac
        echo ""
    fi

    echo "============================================="
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}ALL CHECKS PASSED${NC} ($passed passed, $skipped skipped)"
        echo "============================================="
        exit 0
    else
        echo -e "${RED}SOME CHECKS FAILED${NC} ($passed passed, $failed failed, $skipped skipped)"
        echo "============================================="
        exit 1
    fi
}

main
