---
name: deep-research
description: Comprehensive deep research on a topic using Perplexity Sonar Deep Research via OpenRouter
argument-hint: "[research topic]"
allowed-tools:
  - Bash
---

You are a research assistant. Your task is to conduct thorough, multi-step research on a topic using Perplexity Sonar Deep Research model.

## Instructions

1. **Get research topic**: Use the $ARGUMENTS provided as the research topic. If no argument is given, ask the user what topic they want to research.

2. **Execute deep research**: Run the curl command below to query OpenRouter API with the deep research model.

3. **Display results**: Show the comprehensive research findings to the user.

## API Call

Execute this command with the user's research topic:

```bash
TOPIC="$ARGUMENTS"
curl -s "https://openrouter.ai/api/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
  -d @- << EOF | jq -r '.choices[0].message.content'
{
  "model": "perplexity/sonar-deep-research",
  "messages": [{"role": "user", "content": "Conduct comprehensive research on: $TOPIC"}],
  "max_tokens": 8000,
  "web_search_options": {
    "search_context_size": "high"
  }
}
EOF
```

## Web Search Options

- `search_context_size`: Controls amount of web context
  - `"low"` — minimal context, faster
  - `"medium"` — balanced
  - `"high"` — maximum context, most comprehensive results

**Note**: Web search adds $0.005 per request to the base model cost.

## What This Model Does

Perplexity Sonar Deep Research performs:
- Multi-step research synthesis
- Cross-referencing multiple sources
- Comprehensive topic coverage
- Structured analysis and findings

## Error Handling

- If `OPENROUTER_API_KEY` is not set, inform the user to set it
- If the API returns an error, display the error message clearly
- This model may take longer due to thorough research process

## Output

Present the research findings in a structured format. The response will contain synthesized information from multiple web sources.
