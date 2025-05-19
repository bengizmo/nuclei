#!/bin/sh
# Generate AI summary for newly discovered device

IP="$1"
DEVICE_TYPE="$2"
FINDINGS="$3"
DISCOVERY_DB="/home/nuclei/discovery/discovery.db"
OLLAMA_HOST="192.168.10.249"
OLLAMA_MODEL="qwen3:latest"
HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"

# Get device details from database
DEVICE_INFO=$(grep "^$IP|" "$DISCOVERY_DB" | head -1)
OS=$(echo "$DEVICE_INFO" | cut -d'|' -f6)
SERVICES=$(echo "$DEVICE_INFO" | cut -d'|' -f7)
HOSTNAME=$(echo "$DEVICE_INFO" | cut -d'|' -f5)

# Create prompt for Ollama based on findings
if [ "$FINDINGS" -eq 0 ]; then
    PROMPT_TEXT="Brief security summary for new device in JSON with 'summary' field. Keep under 200 chars. Device: IP=$IP, Type=$DEVICE_TYPE, OS=$OS."
else
    PROMPT_TEXT="Security alert for device in JSON with 'summary' field. List vulnerabilities and actions. Device: IP=$IP, Type=$DEVICE_TYPE, Vulnerabilities=$FINDINGS."
fi

# Create JSON request
REQUEST_BODY=$(jq -n \
    --arg model "$OLLAMA_MODEL" \
    --arg prompt "$PROMPT_TEXT" \
    --arg format "json" \
    --argjson stream false \
    --argjson options '{"temperature": 0.7}' \
    '{model: $model, prompt: $prompt, format: $format, stream: $stream, options: $options}')

# Call Ollama
SUMMARY_RAW=$(curl -s -X POST \
    http://${OLLAMA_HOST}:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "$REQUEST_BODY" | jq -r '.response' 2>/dev/null)

# Parse the response
if echo "$SUMMARY_RAW" | jq -e . >/dev/null 2>&1; then
    SUMMARY=$(echo "$SUMMARY_RAW" | jq -r '.summary')
else
    if [ "$FINDINGS" -eq 0 ]; then
        SUMMARY="New $DEVICE_TYPE device at $IP detected and secure."
    else
        SUMMARY="Alert: New $DEVICE_TYPE at $IP has $FINDINGS vulnerabilities. Immediate review required."
    fi
fi

# Update Home Assistant with device summary
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

curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"${SUMMARY}\",
        \"attributes\": {
            \"friendly_name\": \"Device Discovery Summary\",
            \"icon\": \"mdi:devices\",
            \"device_ip\": \"$IP\",
            \"device_type\": \"$DEVICE_TYPE\",
            \"vulnerabilities\": $FINDINGS,
            \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\",
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\",
                \"model\": \"Network Vulnerability Scanner\",
                \"manufacturer\": \"ProjectDiscovery\",
                \"sw_version\": \"3.4.2\"
            }
        }
    }" \
    "${HA_BASE_URL}/api/states/sensor.nuclei_device_discovery_summary"

echo "Device summary generated for $IP"