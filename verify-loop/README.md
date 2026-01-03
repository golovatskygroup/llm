# Claude Code Quality Hooks

Reusable quality control hooks for Claude Code. Ensures code quality through automated formatting, linting, and testing before task completion.

## Quick Start

### Install hooks into your project

```bash
# From this directory
./setup-hooks.sh --path /path/to/your/project

# Or from your project directory
/path/to/llm-docs/nyarum/setup-hooks.sh
```

### Auto-configure for your project

After installation, let Claude analyze your project and configure the hooks:

```bash
cd /path/to/your/project
.claude/scripts/reconfig.sh
```

### Remove hooks from your project

```bash
./remove-hooks.sh --path /path/to/your/project
```

## What Gets Installed

```
your-project/
├── .claude/
│   ├── hooks/
│   │   ├── pre_tool_use.sh    # Blocks dangerous commands
│   │   ├── post_tool_use.sh   # Auto-formats files
│   │   └── stop.sh            # Quality gate (6 checks)
│   ├── scripts/
│   │   ├── verify_loop.sh     # Manual verification
│   │   └── reconfig.sh        # Claude-powered config
│   ├── hooks.config           # Quality check commands
│   └── settings.local.json    # Claude Code settings
```

## Supported Languages

| Language | Format | Lint | Type Check | Test |
|----------|--------|------|------------|------|
| **Go** | gofmt, goimports | golangci-lint | (compile-time) | go test -race |
| **Node/TS** | Biome/Prettier | Biome/ESLint | tsc | npm test |
| **Python** | Ruff/Black | Ruff | Mypy | pytest |

## Configuration

Edit `.claude/hooks.config` to customize commands:

```bash
# Example for a Go project with Makefile
FORMAT_CMD="make fmt"
BUILD_CMD="make build"
LINT_CMD="make lint"
TEST_CMD="make test"
```

### Scoring Weights

Each check has a weight. Total score must meet threshold (default 80%):

| Check | Default Weight |
|-------|---------------|
| Format | 10 |
| Build | 40 |
| Vet | 10 |
| Lint | 20 |
| Type | 10 |
| Test | 20 |

## Manual Verification

Run checks manually:

```bash
# Full verification
.claude/scripts/verify_loop.sh

# Skip tests (faster)
.claude/scripts/verify_loop.sh --quick
```

## Hook Behavior

### PreToolUse (Security Guard)
- **Blocks**: `rm -rf`, `sudo`, `git push --force`, piped shell execution
- **Protects**: `.env*`, `*.key`, `*.pem`, `secrets.*`, `vendor/`, `node_modules/`

### PostToolUse (Auto-Format)
- Detects language from file extension
- Runs appropriate formatter (gofmt/biome/ruff)
- Quick build check after formatting

### Stop (Quality Gate)
- Runs all configured checks
- Calculates weighted score
- Blocks completion if score < threshold
- Provides detailed error messages

## Adding Custom Protected Files

In `.claude/hooks.config`:

```bash
CUSTOM_PROTECTED_FILES=("terraform.tfstate" "my_secrets.json")
```

## Requirements

- **jq** - For JSON manipulation in setup/remove scripts
- **Claude Code CLI** - For reconfig.sh

### Language-Specific Tools

**Go:**
- gofmt (built-in)
- goimports: `go install golang.org/x/tools/cmd/goimports@latest`
- golangci-lint: https://golangci-lint.run/docs/install/

**Node/TS:**
- Biome: `npm install --save-dev @biomejs/biome`
- Or ESLint + Prettier

**Python:**
- Ruff: `pip install ruff`
- Mypy: `pip install mypy`
- pytest: `pip install pytest`

## Troubleshooting

### Hooks not running
Check `.claude/settings.local.json` has the hooks configured.

### Quality gate always fails
Run `.claude/scripts/verify_loop.sh` to see which checks fail.

### Commands not found
Ensure the tools are installed and in PATH, or use `make` targets.

## License

MIT
