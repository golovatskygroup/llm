# Claude Code Hooks Configuration
# Language: Go
LANGUAGE="go"

# Format: gofmt (built-in, always available)
FORMAT_CMD="gofmt -l -w ."

# Imports: goimports (organizes imports)
# Install: go install golang.org/x/tools/cmd/goimports@latest
IMPORTS_CMD="goimports -w ."

# Build: compile all packages
BUILD_CMD="go build ./..."

# Vet: static analysis (built-in)
VET_CMD="go vet ./..."

# Lint: golangci-lint (meta-linter with 50+ checks)
# Install: https://golangci-lint.run/docs/install/
# If you have a Makefile with 'lint' target, use: LINT_CMD="make lint"
LINT_CMD="golangci-lint run"

# Type check: not needed for Go (compile-time checked)
TYPE_CMD=""

# Tests: with race detector
# If you have a Makefile with 'test' target, use: TEST_CMD="make test"
TEST_CMD="go test -race ./..."

# Scoring weights (total: 110)
FORMAT_WEIGHT=10
BUILD_WEIGHT=40
VET_WEIGHT=10
LINT_WEIGHT=20
TYPE_WEIGHT=0
TEST_WEIGHT=20

# Threshold to pass quality gate (percentage)
THRESHOLD=80

# Custom protected files (add project-specific patterns)
# CUSTOM_PROTECTED_FILES=("go.sum")
