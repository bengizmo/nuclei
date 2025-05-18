#!/bin/sh
# Update Home Assistant with final scan results

echo "Updating Home Assistant with scan results..."

# Configuration
HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"
RESULTS_DIR="/home/nuclei/results/20250518-124134"

# Count results
FINDINGS=0
CRITICAL=0
HOSTS_SCANNED=0

# Count hosts scanned
if [ -d "$RESULTS_DIR/ports" ]; then
    HOSTS_SCANNED=$(ls -1 "$RESULTS_DIR/ports" | wc -l)
fi

# Count findings - check non-empty JSON files
for file in "$RESULTS_DIR/vulnerabilities"/*.json; do
    if [ -s "$file" ]; then
        echo "Found data in: $file"
        FINDINGS=$((FINDINGS + 1))
    fi
done

# Determine status
if [ "$FINDINGS" -gt 0 ]; then
    STATUS="alert"
else
    STATUS="ok"
fi

echo "Status: $STATUS"
echo "Findings: $FINDINGS"
echo "Hosts scanned: $HOSTS_SCANNED"

# Update Home Assistant
curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"entity_id\": \"input_text.nuclei_status\", \"state\": \"${STATUS}\"}" \
    "${HA_BASE_URL}/api/states/input_text.nuclei_status"

curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"entity_id\": \"input_number.nuclei_findings\", \"state\": \"${FINDINGS}\"}" \
    "${HA_BASE_URL}/api/states/input_number.nuclei_findings"

curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"entity_id\": \"input_number.nuclei_hosts_scanned\", \"state\": \"${HOSTS_SCANNED}\"}" \
    "${HA_BASE_URL}/api/states/input_number.nuclei_hosts_scanned"

# Send notification if findings
if [ "$FINDINGS" -gt 0 ]; then
    echo "Sending notification..."
    curl -s -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "title": "🔒 Security Scan Complete",
            "message": "Found '"$FINDINGS"' security issues",
            "data": {
                "push": {
                    "badge": '"$FINDINGS"',
                    "sound": "default"
                }
            }
        }' \
        "${HA_BASE_URL}/api/services/notify/mobile_app_ben_s_iphone_15"
fi

echo "Home Assistant updated successfully!"