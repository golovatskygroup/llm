---
name: crawl-docs
description: Crawl documentation from URL and save as markdown to docs/ folder
argument-hint: "<url> [output-name]"
allowed-tools:
  - Bash
---

You are a documentation crawler assistant. Your task is to crawl a documentation website and save the extracted content as markdown.

## Instructions

1. **Parse arguments**: Use the $ARGUMENTS provided. First argument is URL (required), second is output name (optional).

2. **Determine output name**: If no name provided, extract from URL domain (e.g., "openrouter" from "https://openrouter.ai/docs").

3. **Create docs directory**: Ensure `docs/` folder exists.

4. **Execute crawl**: Run trafilatura to discover URLs and extract content.

## Workflow

Execute these commands:

```bash
# Create docs directory
mkdir -p docs

# Parse arguments
URL="<first argument from $ARGUMENTS>"
NAME="<second argument or derived from URL>"

# Step 1: Crawl and discover URLs (max 30 pages by default)
/Users/nyarum/Library/Python/3.9/bin/trafilatura --crawl "$URL" > /tmp/crawl-urls.txt

# Step 2: Extract content as markdown
/Users/nyarum/Library/Python/3.9/bin/trafilatura -i /tmp/crawl-urls.txt --output-format markdown > "docs/${NAME}.md"

# Report results
echo "URLs found: $(wc -l < /tmp/crawl-urls.txt)"
echo "Output: docs/${NAME}.md"
echo "Size: $(du -h docs/${NAME}.md | cut -f1)"
```

## Example Usage

```
/crawl-docs https://openrouter.ai/docs/quickstart openrouter
```

Creates `docs/openrouter.md` with crawled documentation.

## Error Handling

- If trafilatura is not installed, inform the user to run: `pip install trafilatura[all]`
- If URL is invalid or unreachable, display the error clearly
- If no content extracted, report empty result
