#!/usr/bin/env bash
# .claude/scripts/verify_loop.sh
# Standalone verification script - can be run manually
# Usage: .claude/scripts/verify_loop.sh [--quick]

set -euo pipefail

QUICK_MODE=false
if [[ "${1:-}" == "--quick" ]]; then
    QUICK_MODE=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load config
CONFIG_FILE=".claude/hooks.config"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo -e "${RED}Error: No hooks.config found${NC}"
    echo "Run setup-hooks.sh first or create .claude/hooks.config"
    exit 1
fi

print_header() {
    echo -e "${BLUE}$1${NC}"
}

print_step() {
    echo -e "${YELLOW}[STEP]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

# Run a single check
run_single_check() {
    local name="$1"
    local cmd="$2"
    local output
    local exit_code=0

    if [[ -z "$cmd" ]]; then
        print_skip "$name (not configured)"
        return 0
    fi

    print_step "$name"

    output=$(eval "$cmd" 2>&1) || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        print_pass "$name"
        return 0
    else
        print_fail "$name"
        echo "$output" | head -30
        return 1
    fi
}

main() {
    local failed=0
    local passed=0
    local skipped=0

    echo "============================================="
    print_header "       QUALITY VERIFICATION LOOP"
    echo "============================================="
    echo ""
    echo "Language: ${LANGUAGE:-unknown}"
    echo ""

    # 1. Format check
    if [[ -n "${FORMAT_CMD:-}" ]]; then
        if run_single_check "Format Check" "$FORMAT_CMD"; then
            ((passed++))
        else
            ((failed++))
            echo "  Hint: Run the format command to fix"
        fi
    else
        ((skipped++))
        print_skip "Format Check (not configured)"
    fi
    echo ""

    # 2. Build
    if [[ -n "${BUILD_CMD:-}" ]]; then
        if run_single_check "Build Check" "$BUILD_CMD"; then
            ((passed++))
        else
            ((failed++))
        fi
    else
        ((skipped++))
        print_skip "Build Check (not configured)"
    fi
    echo ""

    # 3. Vet/Static analysis
    if [[ -n "${VET_CMD:-}" ]]; then
        if run_single_check "Static Analysis (vet)" "$VET_CMD"; then
            ((passed++))
        else
            ((failed++))
        fi
    else
        ((skipped++))
        print_skip "Static Analysis (not configured)"
    fi
    echo ""

    # 4. Lint
    if [[ -n "${LINT_CMD:-}" ]]; then
        if run_single_check "Lint Check" "$LINT_CMD"; then
            ((passed++))
        else
            ((failed++))
        fi
    else
        ((skipped++))
        print_skip "Lint Check (not configured)"
    fi
    echo ""

    # 5. Type check
    if [[ -n "${TYPE_CMD:-}" ]]; then
        if run_single_check "Type Check" "$TYPE_CMD"; then
            ((passed++))
        else
            ((failed++))
        fi
    else
        ((skipped++))
        print_skip "Type Check (not configured)"
    fi
    echo ""

    # 6. Tests (skip in quick mode)
    if [[ "$QUICK_MODE" == "true" ]]; then
        print_skip "Tests (SKIPPED - quick mode)"
        echo ""
    elif [[ -n "${TEST_CMD:-}" ]]; then
        if run_single_check "Tests" "$TEST_CMD"; then
            ((passed++))
        else
            ((failed++))
        fi
        echo ""
    else
        ((skipped++))
        print_skip "Tests (not configured)"
        echo ""
    fi

    echo "============================================="

    local total=$((passed + failed))
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
