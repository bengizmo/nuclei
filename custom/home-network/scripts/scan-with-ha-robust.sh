#!/bin/bash
# Enhanced Home Assistant integration with robust error handling
# This script is designed to be more reliable and handle edge cases

# Enable error handling
set -eo pipefail

# Configuration
echo "Initializing robust Home Assistant integration..."
HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/${SCAN_DATE}"
LOG_DIR="/home/nuclei/logs"
LOG_FILE="${LOG_DIR}/ha-integration-${SCAN_DATE}.log"

# Create directories
mkdir -p "$RESULTS_DIR"
mkdir -p "$LOG_DIR"

# Log function with timestamps
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting Home Assistant integration scan script"

# Check if HA token is set
if [ -z "$HA_TOKEN" ]; then
    log "WARNING: HOME_ASSISTANT_API_TOKEN not set, attempting to read from env file..."
    
    # Try to source from a .env file if it exists
    if [ -f "/home/nuclei/.env" ]; then
        log "Found .env file, sourcing it..."
        # shellcheck disable=SC1091
        . "/home/nuclei/.env"
    elif [ -f "/home/nuclei/config/.env" ]; then
        log "Found config/.env file, sourcing it..."
        # shellcheck disable=SC1091
        . "/home/nuclei/config/.env"
    fi
    
    # Check again after trying to source env
    if [ -z "$HOME_ASSISTANT_API_TOKEN" ]; then
        log "ERROR: HOME_ASSISTANT_API_TOKEN still not available, HA integration disabled"
        HA_ENABLED=false
    else
        HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"
        HA_ENABLED=true
        log "Successfully loaded HA token from env file"
    fi
else
    HA_ENABLED=true
    log "HOME_ASSISTANT_API_TOKEN is set, HA integration enabled"
fi

# Function to update Home Assistant entities with better error handling
update_ha_entity() {
    if [ "$HA_ENABLED" = "true" ]; then
        local entity_id=$1
        local state=$2
        local attributes=$3
        
        log "Updating entity: $entity_id with state: $state"
        
        # Attempt to update HA entity with proper error handling
        status_code=$(curl -s -o /tmp/ha_response -w "%{http_code}" \
            -H "Authorization: Bearer ${HA_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{\"state\": \"${state}\", \"attributes\": ${attributes}}" \
            "${HA_BASE_URL}/api/states/${entity_id}")
        
        if [ "$status_code" -ge 200 ] && [ "$status_code" -lt 300 ]; then
            log "Successfully updated entity: $entity_id"
            return 0
        else
            log "ERROR: Failed to update entity: $entity_id, status code: $status_code"
            log "Response: $(cat /tmp/ha_response)"
            return 1
        fi
    else
        log "HA integration disabled, skipping update for entity: $entity_id"
        return 0
    fi
}

# Update multiple HA entities - more reliable approach
update_all_ha_entities() {
    local status=$1
    local findings=$2
    local hosts_scanned=$3
    local scan_time=$4
    local summary=$5
    
    # Prepare attributes for main sensor
    local main_attributes="{
        \"friendly_name\": \"Nuclei Scanner\",
        \"icon\": \"mdi:shield-search\",
        \"status\": \"${status}\",
        \"findings\": ${findings},
        \"hosts_scanned\": ${hosts_scanned},
        \"last_scan\": \"${scan_time}\",
        \"device\": {
            \"identifiers\": [\"nuclei_scanner_001\"],
            \"name\": \"Nuclei Scanner\",
            \"model\": \"Network Vulnerability Scanner\",
            \"manufacturer\": \"ProjectDiscovery\",
            \"sw_version\": \"3.4.2\",
            \"configuration_url\": \"http://192.168.10.163:9090\"
        }
    }"
    
    # Update main sensor
    update_ha_entity "sensor.nuclei_scanner" "${status}" "${main_attributes}"
    
    # Update individual sensors
    update_ha_entity "sensor.nuclei_scanner_status" "${status}" "{
        \"friendly_name\": \"Nuclei Scanner Status\",
        \"icon\": \"mdi:shield-search\",
        \"device\": {
            \"identifiers\": [\"nuclei_scanner_001\"],
            \"name\": \"Nuclei Scanner\"
        }
    }"
    
    update_ha_entity "sensor.nuclei_scanner_findings" "${findings}" "{
        \"friendly_name\": \"Vulnerabilities Found\",
        \"icon\": \"mdi:bug\",
        \"device\": {
            \"identifiers\": [\"nuclei_scanner_001\"],
            \"name\": \"Nuclei Scanner\"
        }
    }"
    
    update_ha_entity "sensor.nuclei_scanner_hosts" "${hosts_scanned}" "{
        \"friendly_name\": \"Hosts Scanned\",
        \"icon\": \"mdi:server-network\",
        \"device\": {
            \"identifiers\": [\"nuclei_scanner_001\"],
            \"name\": \"Nuclei Scanner\"
        }
    }"
    
    update_ha_entity "sensor.nuclei_scanner_last_scan" "${scan_time}" "{
        \"friendly_name\": \"Last Scan Time\",
        \"icon\": \"mdi:clock-outline\",
        \"device_class\": \"timestamp\",
        \"device\": {
            \"identifiers\": [\"nuclei_scanner_001\"],
            \"name\": \"Nuclei Scanner\"
        }
    }"
    
    update_ha_entity "sensor.nuclei_scanner_summary" "${summary}" "{
        \"friendly_name\": \"Nuclei Scanner Summary\",
        \"icon\": \"mdi:shield-search\",
        \"device_class\": \"diagnostic\",
        \"device\": {
            \"identifiers\": [\"nuclei_scanner_001\"],
            \"name\": \"Nuclei Scanner\"
        }
    }"
}

# Send starting notification
log "Setting scan status to 'scanning'"
update_all_ha_entities "scanning" "0" "0" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)" "Scan in progress..."

# Run the actual scan with error handling
log "Starting multi-VLAN security scan..."
if /home/nuclei/scripts/improved-multi-vlan-scan.sh > "$RESULTS_DIR/scan.log" 2>&1; then
    log "Scan completed successfully"
else
    scan_exit_code=$?
    log "ERROR: Scan failed with exit code $scan_exit_code"
    # Update HA to show error
    update_all_ha_entities "error" "0" "0" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)" "Scan failed with error code $scan_exit_code"
    exit $scan_exit_code
fi

# Count findings in results
FINDINGS=0
HOSTS_SCANNED=0
CRITICAL=0
HIGH=0

log "Analyzing scan results..."

# Get hosts scanned count
if [ -d "$RESULTS_DIR/ports" ]; then
    HOSTS_SCANNED=$(find "$RESULTS_DIR/ports" -type f | wc -l | tr -d ' ')
    log "Found $HOSTS_SCANNED hosts scanned"
fi

# Check for vulnerabilities
if [ -d "$RESULTS_DIR/vulnerabilities" ]; then
    for file in "$RESULTS_DIR/vulnerabilities"/*.json; do
        if [ -f "$file" ] && [ -s "$file" ]; then
            file_findings=$(grep -c "matched-at" "$file" 2>/dev/null || echo 0)
            log "Found $file_findings findings in $(basename "$file")"
            FINDINGS=$((FINDINGS + file_findings))
            
            # Count by severity
            critical_findings=$(grep -c '"severity":"critical"' "$file" 2>/dev/null || echo 0)
            CRITICAL=$((CRITICAL + critical_findings))
            
            high_findings=$(grep -c '"severity":"high"' "$file" 2>/dev/null || echo 0)
            HIGH=$((HIGH + high_findings))
        fi
    done
fi

log "Summary: $FINDINGS total findings ($CRITICAL critical, $HIGH high)"

# Check if summary.txt exists, if not create one
if [ ! -f "$RESULTS_DIR/summary.txt" ]; then
    log "Creating summary.txt file..."
    cat > "$RESULTS_DIR/summary.txt" <<EOF
Network Security Scan Summary
Date: $SCAN_DATE

=== Scan Summary ===
Total hosts scanned: $HOSTS_SCANNED
Total vulnerabilities found: $FINDINGS
Critical vulnerabilities: $CRITICAL
High vulnerabilities: $HIGH
EOF
fi

# Determine final status
if [ "$FINDINGS" -gt 0 ]; then
    STATUS="alert"
    MESSAGE="Found $FINDINGS security issues ($CRITICAL critical, $HIGH high)"
else
    STATUS="idle"
    MESSAGE="No vulnerabilities found"
fi

# Create symlink to latest results
ln -sf "$RESULTS_DIR" "/home/nuclei/results/latest"

# Generate summary for HA
SUMMARY="$MESSAGE across $HOSTS_SCANNED hosts"
log "Final status: $STATUS - $SUMMARY"

# Send completion notification to Home Assistant
log "Updating Home Assistant with final results..."
update_all_ha_entities "$STATUS" "$FINDINGS" "$HOSTS_SCANNED" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)" "$SUMMARY"

# Send notification if issues found
if [ "$HA_ENABLED" = "true" ] && [ "$FINDINGS" -gt 0 ]; then
    log "Sending alert notification to Home Assistant..."
    notification_status=$(curl -s -o /tmp/ha_notification -w "%{http_code}" \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"title\": \"Security Scan Alert\",
            \"message\": \"${MESSAGE}. Click for details.\",
            \"data\": {
                \"push\": {
                    \"category\": \"security\"
                }
            }
        }" \
        "${HA_BASE_URL}/api/services/notify/notify")
    
    if [ "$notification_status" -ge 200 ] && [ "$notification_status" -lt 300 ]; then
        log "Successfully sent notification to Home Assistant"
    else
        log "ERROR: Failed to send notification, status code: $notification_status"
        log "Response: $(cat /tmp/ha_notification)"
    fi
fi

log "Scan and Home Assistant update completed"
log "Results saved to: $RESULTS_DIR"
log "Logs saved to: $LOG_FILE"

# Create a status file that other scripts can easily parse
cat > "$RESULTS_DIR/status.json" <<EOF
{
    "scan_date": "${SCAN_DATE}",
    "iso_date": "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)",
    "status": "${STATUS}",
    "findings": ${FINDINGS},
    "critical": ${CRITICAL},
    "high": ${HIGH},
    "hosts_scanned": ${HOSTS_SCANNED}
}
EOF

echo "Scan completed successfully. Status: $STATUS"
echo "Findings: $FINDINGS (Critical: $CRITICAL, High: $HIGH)"
echo "Hosts scanned: $HOSTS_SCANNED"
echo "Results saved to: $RESULTS_DIR"
echo "Logs saved to: $LOG_FILE"