#!/bin/sh
# Test Ollama directly

echo "Testing Ollama connection..."

# Test basic connection
echo "1. Testing API endpoint..."
curl -s http://192.168.10.249:11434/api/tags | jq -r '.models[0].name'

# Test generation with structured output
echo -e "\n2. Testing generation with JSON format..."
RESPONSE=$(curl -s -X POST \
    http://192.168.10.249:11434/api/generate \
    -H "Content-Type: application/json" \
    -d '{
        "model": "qwen3:latest",
        "prompt": "Return a JSON object with a summary field: {\"summary\": \"test message\"}",
        "format": "json",
        "stream": false
    }')

echo "Raw response:"
echo "$RESPONSE" | jq .

echo -e "\n3. Testing our specific use case..."
PROMPT="Analyze these network scan results. Return a JSON object with a single 'summary' field containing 1-2 sentences about the security status and recommended actions.

Scan results:
Critical: 0, High: 0, Medium: 0, Low: 0
Hosts scanned: 11

Example format: {\"summary\": \"Your network appears secure with no critical vulnerabilities detected. Continue regular monitoring and ensure all devices receive security updates.\"}"

RESPONSE=$(curl -s -X POST \
    http://192.168.10.249:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"qwen3:latest\",
        \"prompt\": \"$PROMPT\",
        \"format\": \"json\",
        \"stream\": false,
        \"options\": {
            \"temperature\": 0.5
        }
    }")

echo "Response:"
echo "$RESPONSE" | jq .

if echo "$RESPONSE" | jq -e '.response' >/dev/null 2>&1; then
    SUMMARY=$(echo "$RESPONSE" | jq -r '.response' | jq -r '.summary' 2>/dev/null)
    echo -e "\nExtracted summary: $SUMMARY"
fi