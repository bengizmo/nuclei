#!/bin/sh
# Scan with Home Assistant integration

echo "Starting scan with Home Assistant notification..."

# Configuration
HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/${SCAN_DATE}"

# Check if HA token is set
if [ -z "$HA_TOKEN" ]; then
    echo "Warning: HOME_ASSISTANT_API_TOKEN not set, HA integration disabled"
    HA_ENABLED=false
else
    HA_ENABLED=true
fi

# Function to update Home Assistant
update_ha() {
    if [ "$HA_ENABLED" = "true" ]; then
        local state=$1
        local attributes=$2
        
        curl -s -X POST \
            -H "Authorization: Bearer ${HA_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{\"state\": \"${state}\", \"attributes\": ${attributes}}" \
            "${HA_BASE_URL}/api/states/sensor.nuclei_scanner" || echo "Failed to update HA"
    fi
}

# Send starting notification
update_ha "scanning" "{\"status\": \"Starting scan\", \"last_scan\": \"${SCAN_DATE}\"}"

# Run the actual scan
echo "Running quick network overview..."
/home/nuclei/scripts/quick-network-overview.sh

# Count findings in results
FINDINGS=0
HOSTS_SCANNED=0
CRITICAL_HOSTS=""

# Check for open ports or vulnerabilities
if [ -d "$RESULTS_DIR" ]; then
    # Count hosts with open ports
    HOSTS_SCANNED=$(find "$RESULTS_DIR" -name "*.txt" | wc -l)
    
    # Look for critical services
    if grep -q "MySQL\|Docker-API\|MongoDB\|Redis" "$RESULTS_DIR"/*.txt 2>/dev/null; then
        FINDINGS=$((FINDINGS + 1))
        CRITICAL_HOSTS="Exposed sensitive services detected"
    fi
fi

# Determine final status
if [ "$FINDINGS" -gt 0 ]; then
    STATUS="alert"
    MESSAGE="Found $FINDINGS security issues"
else
    STATUS="ok"
    MESSAGE="No vulnerabilities found"
fi

# Send completion notification
ATTRIBUTES="{
    \"status\": \"${MESSAGE}\",
    \"last_scan\": \"${SCAN_DATE}\",
    \"hosts_scanned\": ${HOSTS_SCANNED},
    \"findings\": ${FINDINGS},
    \"details\": \"${CRITICAL_HOSTS}\"
}"

update_ha "$STATUS" "$ATTRIBUTES"

# Also send a notification
if [ "$HA_ENABLED" = "true" ] && [ "$FINDINGS" -gt 0 ]; then
    curl -s -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"message\": \"Nuclei scan found ${FINDINGS} issues\", \"title\": \"Security Alert\"}" \
        "${HA_BASE_URL}/api/services/notify/notify"
fi

echo "Scan completed. Status: $STATUS"
echo "Results saved to: $RESULTS_DIR"