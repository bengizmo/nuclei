#!/bin/sh
# Generate AI summary and update Home Assistant sensor

echo "Generating AI summary of scan results..."

# Configuration
RESULTS_DIR="${1:-/home/nuclei/results/latest}"
OLLAMA_HOST="192.168.10.249"
OLLAMA_MODEL="qwen3:latest"
HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"

# Get most recent results directory if "latest" is specified
if [ "$RESULTS_DIR" = "/home/nuclei/results/latest" ]; then
    RESULTS_DIR=$(find /home/nuclei/results -maxdepth 1 -type d -name "20*" | sort -r | head -1)
fi

if [ ! -d "$RESULTS_DIR" ]; then
    echo "Error: Results directory not found: $RESULTS_DIR"
    # Update sensor with error message
    curl -s -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"state\": \"No scan results available\",
            \"attributes\": {
                \"friendly_name\": \"Nuclei AI Summary\",
                \"icon\": \"mdi:robot\",
                \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\",
                \"model\": \"${OLLAMA_MODEL}\",
                \"device\": {
                    \"identifiers\": [\"nuclei_scanner_001\"],
                    \"name\": \"Nuclei Scanner\",
                    \"model\": \"Network Vulnerability Scanner\",
                    \"manufacturer\": \"ProjectDiscovery\",
                    \"sw_version\": \"3.4.2\"
                }
            }
        }" \
        "${HA_BASE_URL}/api/states/sensor.nuclei_scanner_summary"
    exit 1
fi

# Compile scan data
echo "Analyzing scan results from: $RESULTS_DIR"
SCAN_DATA=""

# Count vulnerabilities by severity
if [ -d "$RESULTS_DIR/vulnerabilities" ] || [ -d "$RESULTS_DIR" ]; then
    # Look for JSON files
    json_files=$(find "$RESULTS_DIR" -name "*.json" -type f 2>/dev/null)
    
    if [ -n "$json_files" ]; then
        CRITICAL_COUNT=0
        HIGH_COUNT=0
        MEDIUM_COUNT=0
        LOW_COUNT=0
        
        for file in $json_files; do
            if [ -f "$file" ]; then
                # Count vulnerabilities by severity
                critical=$(cat "$file" | jq -r 'select(.info.severity == "critical") | .info.severity' 2>/dev/null | wc -l)
                high=$(cat "$file" | jq -r 'select(.info.severity == "high") | .info.severity' 2>/dev/null | wc -l)
                medium=$(cat "$file" | jq -r 'select(.info.severity == "medium") | .info.severity' 2>/dev/null | wc -l)
                low=$(cat "$file" | jq -r 'select(.info.severity == "low") | .info.severity' 2>/dev/null | wc -l)
                
                CRITICAL_COUNT=$((CRITICAL_COUNT + critical))
                HIGH_COUNT=$((HIGH_COUNT + high))
                MEDIUM_COUNT=$((MEDIUM_COUNT + medium))
                LOW_COUNT=$((LOW_COUNT + low))
                
                # Extract specific vulnerability names
                vulns=$(cat "$file" | jq -r '.info.name' 2>/dev/null)
                if [ -n "$vulns" ]; then
                    SCAN_DATA="$SCAN_DATA\nVulnerabilities found: $vulns"
                fi
            fi
        done
        
        SCAN_DATA="Critical: $CRITICAL_COUNT, High: $HIGH_COUNT, Medium: $MEDIUM_COUNT, Low: $LOW_COUNT"
    else
        SCAN_DATA="No vulnerabilities found"
    fi
fi

# Count hosts scanned
hosts_count=$(cat /home/nuclei/critical-hosts.txt | grep -v "^#" | wc -l)
SCAN_DATA="$SCAN_DATA\nHosts scanned: $hosts_count"

# Create structured prompt for Ollama - prepare data and prompt
SCAN_DATA_CLEAN=$(echo "$SCAN_DATA" | tr '\n' ' ' | sed 's/"/\\"/g')
# Determine prompt based on findings
TOTAL_VULNS=$((CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT))
if [ "$TOTAL_VULNS" -eq 0 ]; then
    PROMPT_TEXT="Report security status for network scan in JSON with 'summary' field. Keep under 200 characters, be concise. Scan results: $SCAN_DATA_CLEAN"
else
    PROMPT_TEXT="Analyze vulnerabilities and return JSON with 'summary' field including vulnerability list and required actions. Scan results: $SCAN_DATA_CLEAN"
fi

# Create the JSON request body
REQUEST_BODY=$(jq -n \
    --arg model "$OLLAMA_MODEL" \
    --arg prompt "$PROMPT_TEXT" \
    --arg format "json" \
    --argjson stream false \
    --argjson options '{"temperature": 0.5}' \
    '{model: $model, prompt: $prompt, format: $format, stream: $stream, options: $options}')

# Call Ollama for summary with structured output
echo "Generating AI summary..."
SUMMARY_RAW=$(curl -s -X POST \
    http://${OLLAMA_HOST}:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "$REQUEST_BODY" | jq -r '.response' 2>/dev/null)

# Parse the JSON response and extract the summary
if echo "$SUMMARY_RAW" | jq -e . >/dev/null 2>&1; then
    # Extract the summary field from the JSON response
    SUMMARY=$(echo "$SUMMARY_RAW" | jq -r '.summary')
    # No need to escape quotes since we're putting it in JSON later
else
    # If not JSON, use the raw response and clean it
    SUMMARY=$(echo "$SUMMARY_RAW" | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g')
fi

# If Ollama fails, use a fallback summary
if [ -z "$SUMMARY" ] || [ "$SUMMARY" = "null" ]; then
    echo "Ollama request failed, using fallback summary"
    if [ "$TOTAL_VULNS" -eq 0 ]; then
        SUMMARY="Scan complete: ${hosts_count} hosts secure, no vulnerabilities found."
    else
        SUMMARY="Alert: Found ${CRITICAL_COUNT:-0} critical, ${HIGH_COUNT:-0} high, ${MEDIUM_COUNT:-0} medium vulnerabilities. Immediate action required."
    fi
fi

echo "Summary: $SUMMARY"

# Update Home Assistant sensor with the summary
echo "Updating Home Assistant sensor..."
# Ensure we have the token
if [ -z "$HA_TOKEN" ]; then
    HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"
fi

# Debug: Show token status
if [ -n "$HA_TOKEN" ]; then
    echo "Using HA token: ${HA_TOKEN:0:20}..."
else
    echo "Warning: No HA token found"
fi

# Create JSON payload
JSON_PAYLOAD=$(cat <<EOF
{
    "state": "${SUMMARY}",
    "attributes": {
        "friendly_name": "Nuclei AI Summary",
        "icon": "mdi:robot",
        "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)",
        "model": "${OLLAMA_MODEL}",
        "scan_directory": "${RESULTS_DIR}",
        "critical_count": ${CRITICAL_COUNT:-0},
        "high_count": ${HIGH_COUNT:-0},
        "medium_count": ${MEDIUM_COUNT:-0},
        "low_count": ${LOW_COUNT:-0},
        "hosts_scanned": ${hosts_count},
        "device": {
            "identifiers": ["nuclei_scanner_001"],
            "name": "Nuclei Scanner",
            "model": "Network Vulnerability Scanner",
            "manufacturer": "ProjectDiscovery",
            "sw_version": "3.4.2"
        }
    }
}
EOF
)

# Send update
curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${JSON_PAYLOAD}" \
    "${HA_BASE_URL}/api/states/sensor.nuclei_scanner_summary"

echo "AI summary updated in Home Assistant"