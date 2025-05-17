#!/bin/bash
# Update Home Assistant via webhook when scan completes

# Configuration
HA_WEBHOOK_URL="http://192.168.10.89:8123/api/webhook/nuclei_scan_update"
RESULTS_DIR="/home/nuclei/results"

# Function to send update to Home Assistant
send_ha_update() {
    local status=$1
    local findings=$2
    local critical=$3
    local high=$4
    local scan_time=$5
    
    curl -X POST "${HA_WEBHOOK_URL}" \
        -H "Content-Type: application/json" \
        -d "{
            \"status\": \"${status}\",
            \"findings\": ${findings},
            \"critical\": ${critical},
            \"high\": ${high},
            \"scan_time\": \"${scan_time}\"
        }"
}

# Parse results from latest scan
get_scan_results() {
    local latest_dir=$(ls -t "${RESULTS_DIR}" | head -1)
    local summary_file="${RESULTS_DIR}/${latest_dir}/summary.txt"
    
    if [ -f "$summary_file" ]; then
        local findings=$(grep -oP 'Total findings: \K\d+' "$summary_file" || echo 0)
        local critical=$(grep -oP 'Critical: \K\d+' "$summary_file" || echo 0)
        local high=$(grep -oP 'High: \K\d+' "$summary_file" || echo 0)
        echo "$findings $critical $high"
    else
        echo "0 0 0"
    fi
}

# Main execution
SCAN_TIME=$(date -Iseconds)
send_ha_update "scanning" 0 0 0 "$SCAN_TIME"

# Run the actual scan
/home/nuclei/scripts/multi-vlan-scan.sh

# Get results
read findings critical high <<< $(get_scan_results)

# Determine status
if [ "$findings" -gt 0 ]; then
    STATUS="alert"
else
    STATUS="ok"
fi

# Send final update
send_ha_update "$STATUS" "$findings" "$critical" "$high" "$SCAN_TIME"