#!/bin/sh
# Ollama LLM service scan

echo "Starting Ollama service scan..."
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/ollama-${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

TARGET="192.168.10.249"
OLLAMA_PORT="11434"

echo "1. Checking Ollama API..."
# Test Ollama endpoints
curl -s http://$TARGET:$OLLAMA_PORT/api/tags > "$RESULTS_DIR/models.json" 2>/dev/null
curl -s http://$TARGET:$OLLAMA_PORT/ > "$RESULTS_DIR/root.html" 2>/dev/null

echo "2. Security scan on Ollama port..."
nuclei -u http://$TARGET:$OLLAMA_PORT \
       -t technologies/ \
       -t exposed-panels/ \
       -t misconfiguration/ \
       -s info,low,medium,high,critical \
       -j -o "$RESULTS_DIR/ollama-security.json"

echo "3. Testing Ollama API accessibility..."
# Check if API requires authentication
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$TARGET:$OLLAMA_PORT/api/tags)
echo "API Status Code: $API_STATUS" > "$RESULTS_DIR/api-status.txt"

echo "4. Available models..."
if [ -s "$RESULTS_DIR/models.json" ]; then
    echo "Models found:" >> "$RESULTS_DIR/api-status.txt"
    jq -r '.models[]?.name' "$RESULTS_DIR/models.json" >> "$RESULTS_DIR/api-status.txt" 2>/dev/null
fi

echo ""
echo "Ollama scan completed!"
echo "Results: $RESULTS_DIR"
cat "$RESULTS_DIR/api-status.txt" 2>/dev/null