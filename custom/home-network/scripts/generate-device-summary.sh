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

# Create prompt for Ollama
PROMPT_TEXT="Analyze this newly discovered network device and provide a security assessment in 1-2 sentences. Device details: IP=$IP, Type=$DEVICE_TYPE, OS=$OS, Services=$SERVICES, Hostname=$HOSTNAME, Vulnerabilities found=$FINDINGS. Provide actionable security recommendations."

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
    SUMMARY="New $DEVICE_TYPE device at $IP requires security review. Found $FINDINGS potential vulnerabilities."
fi

# Update Home Assistant with device summary
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