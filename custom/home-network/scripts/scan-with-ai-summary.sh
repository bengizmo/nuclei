#!/bin/sh
# Complete scan with sensor updates and AI summary

echo "Starting scan with AI summary generation..."
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

# Update sensors to show scanning status
/home/nuclei/scripts/ha-sensor-update.sh "scanning" "0" "0" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"

# Update AI summary sensor to show scanning
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"Scanning in progress...\",
        \"attributes\": {
            \"friendly_name\": \"Nuclei AI Summary\",
            \"icon\": \"mdi:robot\",
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
    "http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_summary"

# Run the scan
echo "Scanning critical infrastructure..."
nuclei -list /home/nuclei/critical-hosts.txt \
    -severity critical,high,medium \
    -t exposed-panels/ -t default-logins/ -t cves/ \
    -j -o "$RESULTS_DIR/scan.json" \
    -silent -stats 2>/dev/null || true

# Count findings and hosts
if [ -f "$RESULTS_DIR/scan.json" ]; then
    findings=$(cat "$RESULTS_DIR/scan.json" | wc -l)
    critical=$(cat "$RESULTS_DIR/scan.json" | jq -r 'select(.info.severity == "critical") | .info.severity' | wc -l)
    high=$(cat "$RESULTS_DIR/scan.json" | jq -r 'select(.info.severity == "high") | .info.severity' | wc -l)
else
    findings=0
    critical=0
    high=0
fi

hosts_scanned=$(cat /home/nuclei/critical-hosts.txt | grep -v "^#" | wc -l)

# Determine status
if [ "$critical" -gt 0 ] || [ "$high" -gt 0 ]; then
    status="alert"
    echo "Found $findings vulnerabilities ($critical critical, $high high)!"
    
    # Send notification
    curl -s -X POST \
        -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"message\": \"Nuclei found ${findings} vulnerabilities (${critical} critical, ${high} high)\", \"title\": \"Security Alert\"}" \
        "http://192.168.10.89:8123/api/services/notify/mobile_app_ben_s_iphone_15"
else
    status="ok"
    echo "No critical vulnerabilities found"
fi

# Update sensors with results
/home/nuclei/scripts/ha-sensor-update.sh "${status}" "${findings}" "${hosts_scanned}" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"

# Generate AI summary
echo "Generating AI summary..."
/home/nuclei/scripts/generate-ai-summary.sh "$RESULTS_DIR"

echo "Scan complete with AI summary. Results in: $RESULTS_DIR"