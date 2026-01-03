# LLM Configuration Files

This repository contains LLM-related configuration files organized by feature.

## Features

### [verify-loop](./verify-loop/)

Automated verification hooks for Claude Code that enforce code quality checks (linting, type checking, tests) after every tool use. Prevents committing broken code by running configurable verification commands automatically.

## Claude Code Commands

Custom slash commands for Claude Code located in `.claude/commands/`.

### `/git-push [message]`

Stage all changes, commit with a message, and push to remote in one command.

```
/git-push fix: resolve login bug
```

### `/search [query]`

Quick web search using Perplexity Sonar Pro via OpenRouter API.

```
/search latest React 19 features
```

**Requires**: `OPENROUTER_API_KEY` environment variable.

### `/deep-research [topic]`

Comprehensive deep research using Perplexity Sonar Deep Research model. Performs multi-step research synthesis with cross-referencing.

```
/deep-research quantum computing applications in cryptography
```

**Requires**: `OPENROUTER_API_KEY` environment variable.

### `/recursive-research [topic]`

Multi-iteration recursive research with user-controlled depth. Builds on previous findings with each iteration, allowing exploration of subtopics and gaps.

```
/recursive-research machine learning optimization techniques
```

**Requires**: `OPENROUTER_API_KEY` environment variable.

### `/crawl-docs <url> [name]`

Crawl documentation from a URL and save as markdown to `docs/` folder. Uses trafilatura for content extraction (max 30 pages by default).

```
/crawl-docs https://openrouter.ai/docs/quickstart openrouter
```

Creates `docs/openrouter.md` with crawled documentation.

**Requires**: `trafilatura` package (`pip install trafilatura[all]`).

### `/simplify [target]`

Simplify code to reduce complexity while preserving functionality. Targets 30-50% reduction in lines of code. Use after code generation or on over-engineered code.

```
/simplify src/utils/helpers.ts
```
