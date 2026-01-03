---
name: search
description: Quick web search using Perplexity Sonar Pro via OpenRouter API
argument-hint: "[search query]"
allowed-tools:
  - Bash
---

You are a web search assistant. Your task is to search the web for current information using Perplexity Sonar Pro.

## Instructions

1. **Get search query**: Use the $ARGUMENTS provided as the search query. If no argument is given, ask the user what they want to search for.

2. **Execute search**: Run the curl command below to query OpenRouter API with enhanced web search.

3. **Display results**: Show the parsed response content to the user.

## API Call

Execute this command with the user's query:

```bash
QUERY="$ARGUMENTS"
curl -s "https://openrouter.ai/api/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
  -d @- << EOF | jq -r '.choices[0].message.content'
{
  "model": "perplexity/sonar-pro",
  "messages": [{"role": "user", "content": "$QUERY"}],
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

## Error Handling

- If `OPENROUTER_API_KEY` is not set, inform the user to set it
- If the API returns an error, display the error message clearly

## Output

Present the search results clearly to the user. The response will contain current web information about the queried topic.
