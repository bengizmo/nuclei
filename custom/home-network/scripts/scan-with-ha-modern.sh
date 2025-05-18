#!/bin/sh
# Modern Home Assistant integration for Nuclei scanner

echo "Starting scan with Home Assistant integration..."

# Configuration
HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

# Check if HA token is set
if [ -z "$HA_TOKEN" ]; then
    echo "Warning: HOME_ASSISTANT_API_TOKEN not set, HA integration disabled"
    HA_ENABLED=false
else
    HA_ENABLED=true
fi

# Function to update Home Assistant input helpers
update_ha_input() {
    if [ "$HA_ENABLED" = "true" ]; then
        local entity_id=$1
        local value=$2
        
        curl -s -X POST \
            -H "Authorization: Bearer ${HA_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{\"entity_id\": \"${entity_id}\", \"state\": \"${value}\"}" \
            "${HA_BASE_URL}/api/states/${entity_id}"
    fi
}

# Function to call HA service
call_ha_service() {
    if [ "$HA_ENABLED" = "true" ]; then
        local service=$1
        local data=$2
        
        curl -s -X POST \
            -H "Authorization: Bearer ${HA_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "${data}" \
            "${HA_BASE_URL}/api/services/${service}"
    fi
}

# Update scan status to "scanning"
update_ha_input "input_text.nuclei_status" "scanning"
update_ha_input "input_datetime.nuclei_last_scan" "$(date -Iseconds)"

# Run the actual scan
echo "Running network security scan..."
/home/nuclei/scripts/improved-multi-vlan-scan.sh > "$RESULTS_DIR/scan.log" 2>&1

# Analyze results
FINDINGS=0
CRITICAL=0
HOSTS_SCANNED=0

# Count hosts scanned
if [ -d "$RESULTS_DIR/ports" ]; then
    HOSTS_SCANNED=$(find "$RESULTS_DIR/ports" -type f | wc -l)
fi

# Check for vulnerabilities
if [ -d "$RESULTS_DIR/vulnerabilities" ]; then
    for file in "$RESULTS_DIR/vulnerabilities"/*.json; do
        if [ -f "$file" ] && [ -s "$file" ]; then
            matches=$(grep -c "matched-at" "$file" 2>/dev/null || echo 0)
            FINDINGS=$((FINDINGS + matches))
            
            # Count critical findings
            critical_matches=$(grep -c '"severity":"critical"' "$file" 2>/dev/null || echo 0)
            CRITICAL=$((CRITICAL + critical_matches))
        fi
    done
fi

# Determine final status
if [ "$FINDINGS" -gt 0 ]; then
    STATUS="alert"
else
    STATUS="ok"
fi

# Update Home Assistant with results
update_ha_input "input_text.nuclei_status" "$STATUS"
update_ha_input "input_number.nuclei_findings" "$FINDINGS"
update_ha_input "input_number.nuclei_critical_count" "$CRITICAL"
update_ha_input "input_number.nuclei_hosts_scanned" "$HOSTS_SCANNED"

# Generate AI summary if configured
AI_SUMMARY=""
if [ -n "$OLLAMA_API" ]; then
    echo "Generating AI summary..."
    AI_SUMMARY=$(/home/nuclei/scripts/generate-scan-summary.sh "$RESULTS_DIR")
fi

# Send notification if issues found
if [ "$FINDINGS" -gt 0 ]; then
    # Use AI summary if available, otherwise use default message
    if [ -n "$AI_SUMMARY" ] && [ "$AI_SUMMARY" != "null" ]; then
        MESSAGE="$AI_SUMMARY"
    else
        MESSAGE="Found ${FINDINGS} security issues (${CRITICAL} critical)"
    fi
    
    NOTIFICATION_DATA="{
        \"title\": \"🔒 Security Scan Alert\",
        \"message\": \"$MESSAGE\",
        \"data\": {
            \"push\": {
                \"badge\": ${FINDINGS},
                \"sound\": \"critical\"
            },
            \"action_data\": {
                \"entity_id\": \"sensor.nuclei_security_scanner\"
            }
        }
    }"
    
    call_ha_service "notify/mobile_app_ben_s_iphone_15" "$NOTIFICATION_DATA"
else
    # Send success notification
    NOTIFICATION_DATA="{
        \"title\": \"✅ Security Scan Complete\",
        \"message\": \"No vulnerabilities found. Network is secure.\",
        \"data\": {
            \"push\": {
                \"sound\": \"default\"
            }
        }
    }"
    
    call_ha_service "notify/mobile_app_ben_s_iphone_15" "$NOTIFICATION_DATA"
fi

echo "Scan completed. Status: $STATUS"
echo "Findings: $FINDINGS (Critical: $CRITICAL)"
echo "Hosts scanned: $HOSTS_SCANNED"
echo "Results saved to: $RESULTS_DIR"

# Create summary for HA
cat > "$RESULTS_DIR/summary.json" <<EOF
{
    "scan_date": "${SCAN_DATE}",
    "status": "${STATUS}",
    "findings": ${FINDINGS},
    "critical": ${CRITICAL},
    "hosts_scanned": ${HOSTS_SCANNED}
}
EOF