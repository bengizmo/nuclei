#!/bin/sh
# Generate AI summary of scan results using Ollama

echo "Generating AI summary of scan results..."

# Configuration
RESULTS_DIR="${1:-/home/nuclei/results/latest}"
OLLAMA_HOST="192.168.10.249"
OLLAMA_MODEL="qwen2.5:32b"

# Check if results directory exists
if [ ! -d "$RESULTS_DIR" ]; then
    echo "Error: Results directory not found: $RESULTS_DIR"
    exit 1
fi

# Compile scan data for analysis
SCAN_DATA=""

# Count open ports
if [ -d "$RESULTS_DIR/ports" ]; then
    PORT_COUNT=$(find "$RESULTS_DIR/ports" -type f | wc -l)
    OPEN_PORTS=$(cat "$RESULTS_DIR/ports"/*.txt 2>/dev/null | grep "OPEN" | wc -l)
    SCAN_DATA="$SCAN_DATA\nDiscovered $PORT_COUNT hosts with $OPEN_PORTS open ports total"
fi

# Count vulnerabilities
if [ -d "$RESULTS_DIR/vulnerabilities" ]; then
    VULN_COUNT=0
    CRITICAL_COUNT=0
    HIGH_COUNT=0
    
    for file in "$RESULTS_DIR/vulnerabilities"/*.json; do
        if [ -f "$file" ] && [ -s "$file" ]; then
            matches=$(grep -c "matched-at" "$file" 2>/dev/null || echo 0)
            VULN_COUNT=$((VULN_COUNT + matches))
            
            critical=$(grep -c '"severity":"critical"' "$file" 2>/dev/null || echo 0)
            CRITICAL_COUNT=$((CRITICAL_COUNT + critical))
            
            high=$(grep -c '"severity":"high"' "$file" 2>/dev/null || echo 0)
            HIGH_COUNT=$((HIGH_COUNT + high))
        fi
    done
    
    SCAN_DATA="$SCAN_DATA\nFound $VULN_COUNT vulnerabilities: $CRITICAL_COUNT critical, $HIGH_COUNT high"
fi

# Get recent vulnerability details
RECENT_VULNS=""
if [ -d "$RESULTS_DIR/vulnerabilities" ] && [ "$VULN_COUNT" -gt 0 ]; then
    RECENT_VULNS=$(find "$RESULTS_DIR/vulnerabilities" -name "*.json" -exec jq -r 'select(.info.severity == "critical" or .info.severity == "high") | "[\(.info.severity)] \(.info.name) on \(.host)"' {} \; 2>/dev/null | head -5)
fi

# Create prompt for LLM
PROMPT="You are a cybersecurity expert analyzing nuclei scan results for a home network. Provide a brief, actionable summary suitable for a mobile notification (max 200 chars).

Scan results:
$SCAN_DATA

Recent high/critical findings:
$RECENT_VULNS

Generate a concise summary focusing on the most important security issues that need immediate attention. Use clear, non-technical language."

echo "Scan data compiled, sending to LLM..."

# Send to Ollama
RESPONSE=$(curl -s -X POST "http://$OLLAMA_HOST:11434/api/generate" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"$OLLAMA_MODEL\",
        \"prompt\": \"$PROMPT\",
        \"stream\": false,
        \"options\": {
            \"temperature\": 0.3,
            \"max_tokens\": 100
        }
    }")

# Extract the response text
SUMMARY=$(echo "$RESPONSE" | jq -r '.response' 2>/dev/null)

if [ -z "$SUMMARY" ] || [ "$SUMMARY" = "null" ]; then
    SUMMARY="Scan complete. Found $VULN_COUNT vulnerabilities ($CRITICAL_COUNT critical). Review details."
fi

echo "AI Summary: $SUMMARY"

# Save summary to file
echo "$SUMMARY" > "$RESULTS_DIR/ai_summary.txt"

# Return the summary
echo "$SUMMARY"