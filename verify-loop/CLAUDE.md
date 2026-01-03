# Claude Code Instructions

## Quality Control Hooks

This project uses Claude Code Hooks for automated quality control. The hooks implement a **Verify Feedback Loop** that ensures code quality before task completion.

### Active Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| **PreToolUse** | Before Bash/Edit | Blocks dangerous commands and protects sensitive files |
| **PostToolUse** | After Edit/Write | Auto-formats files based on language |
| **Stop** | Before completion | Quality gate: all checks must pass |

### Quality Gate Checks

When completing a task, the Stop hook runs these checks (configurable in `.claude/hooks.config`):

1. **Format Check** - Code formatting (gofmt/biome/ruff)
2. **Build Check** - Compilation must succeed
3. **Vet/Static Analysis** - Static analysis warnings
4. **Lint Check** - Linter (golangci-lint/biome/ruff)
5. **Type Check** - Type checking (tsc/mypy)
6. **Tests** - Test suite must pass

If any check fails, completion is blocked and you'll receive feedback to fix the issues.

### Protected Files (DO NOT MODIFY DIRECTLY)

- `.env*` - Environment files (contains secrets)
- `*.key`, `*.pem` - Certificates and keys
- `secrets.*`, `credentials.json` - Secret files
- `*.tfstate` - Terraform state files
- `vendor/`, `node_modules/` - Dependencies (use package manager)

### Blocked Commands

The following dangerous commands are blocked:
- `rm -rf`, `rm -fr` (recursive delete)
- `sudo` (privilege escalation)
- `chmod 777` (insecure permissions)
- `git push --force`, `git reset --hard` (destructive git)
- Piped shell execution (`curl | sh`, `wget | bash`)

---

## Configuration

### hooks.config

The quality checks are configured in `.claude/hooks.config`:

```bash
# Commands (empty = skip check)
FORMAT_CMD="..."    # Formatter
BUILD_CMD="..."     # Build/compile
VET_CMD="..."       # Static analysis
LINT_CMD="..."      # Linter
TYPE_CMD="..."      # Type checker
TEST_CMD="..."      # Test runner

# Scoring
THRESHOLD=80        # Minimum score to pass (percentage)
```

### Reconfigure with Claude

To automatically configure hooks for your project:

```bash
.claude/scripts/reconfig.sh
```

This runs Claude to analyze your project and update the configuration.

---

## Manual Verification

Run the verification script manually:

```bash
.claude/scripts/verify_loop.sh        # Full verification
.claude/scripts/verify_loop.sh --quick # Skip tests
```

---

## Language Support

### Go
- **Format**: gofmt, goimports
- **Lint**: golangci-lint (50+ linters)
- **Test**: go test -race

### JavaScript/TypeScript
- **Format**: Biome (or Prettier)
- **Lint**: Biome (or ESLint)
- **Type**: tsc --noEmit
- **Test**: npm test

### Python
- **Format**: Ruff format (or Black)
- **Lint**: Ruff check (100x faster than Flake8)
- **Type**: Mypy
- **Test**: pytest
