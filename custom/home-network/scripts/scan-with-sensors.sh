#!/bin/sh
# Scanning script that updates proper sensor entities

echo "Starting scan with Home Assistant sensor integration..."
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

# Update sensors to show scanning status
/home/nuclei/scripts/ha-sensor-update.sh "scanning" "0" "0" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"

# Quick scan of critical hosts
echo "Scanning critical infrastructure..."
nuclei -list /home/nuclei/critical-hosts.txt \
    -severity critical,high,medium \
    -t exposed-panels/ -t default-logins/ \
    -j -o "$RESULTS_DIR/critical.json" \
    -silent -stats 2>/dev/null || true

# Count findings and hosts
if [ -f "$RESULTS_DIR/critical.json" ]; then
    findings=$(cat "$RESULTS_DIR/critical.json" | wc -l)
else
    findings=0
fi

hosts_scanned=$(wc -l < /home/nuclei/critical-hosts.txt)

# Determine status based on findings
if [ "$findings" -gt 0 ]; then
    status="alert"
    echo "Found $findings vulnerabilities!"
    
    # Send notification
    curl -s -X POST \
        -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"message\": \"Nuclei found ${findings} vulnerabilities\", \"title\": \"Security Alert\"}" \
        "http://192.168.10.89:8123/api/services/notify/mobile_app_ben_s_iphone_15"
else
    status="ok"
    echo "No vulnerabilities found"
fi

# Update sensors with results
/home/nuclei/scripts/ha-sensor-update.sh "${status}" "${findings}" "${hosts_scanned}" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"

echo "Scan complete. Results in: $RESULTS_DIR"
echo "Home Assistant sensors updated with status: $status"