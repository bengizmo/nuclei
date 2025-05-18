#!/bin/sh
# Quick scan to test Home Assistant integration

echo "Running quick scan with Home Assistant integration..."
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

# Update HA status to scanning
HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"

# Update status
curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"entity_id\": \"input_text.nuclei_status\", \"state\": \"scanning\"}" \
    "${HA_BASE_URL}/api/states/input_text.nuclei_status"

# Update last scan time
scan_time=$(date -u +%Y-%m-%dT%H:%M:%S+00:00)
curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"entity_id\": \"input_datetime.nuclei_last_scan\", \"state\": \"${scan_time}\"}" \
    "${HA_BASE_URL}/api/states/input_datetime.nuclei_last_scan"

# Quick scan of critical hosts
echo "Scanning critical infrastructure..."
nuclei -list /home/nuclei/critical-hosts.txt \
    -severity critical,high \
    -t exposed-panels/ -t default-logins/ \
    -json -o "$RESULTS_DIR/critical.json" \
    -silent -stats

# Count findings
if [ -f "$RESULTS_DIR/critical.json" ]; then
    findings=$(cat "$RESULTS_DIR/critical.json" | wc -l)
else
    findings=0
fi

# Update HA with results
curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"entity_id\": \"input_number.nuclei_findings\", \"state\": \"${findings}\"}" \
    "${HA_BASE_URL}/api/states/input_number.nuclei_findings"

curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"entity_id\": \"input_number.nuclei_hosts_scanned\", \"state\": \"13\"}" \
    "${HA_BASE_URL}/api/states/input_number.nuclei_hosts_scanned"

# Update status based on findings
if [ "$findings" -gt 0 ]; then
    status="alert"
    echo "Found $findings vulnerabilities!"
    
    # Send notification
    curl -s -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"message\": \"Nuclei found ${findings} vulnerabilities\", \"title\": \"Security Alert\"}" \
        "${HA_BASE_URL}/api/services/notify/mobile_app_ben_s_iphone_15"
else
    status="ok"
    echo "No vulnerabilities found"
fi

curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"entity_id\": \"input_text.nuclei_status\", \"state\": \"${status}\"}" \
    "${HA_BASE_URL}/api/states/input_text.nuclei_status"

echo "Scan complete. Results in: $RESULTS_DIR"
echo "Home Assistant updated with status: $status"