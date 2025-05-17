#!/bin/bash
# multi-vlan-scan.sh - Comprehensive multi-VLAN scanning script

SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

# Function to update Home Assistant
update_home_assistant() {
    curl -X POST \
      -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"state\": \"$1\", \"attributes\": {\"last_scan\": \"${SCAN_DATE}\", \"status\": \"$2\", \"findings\": $3}}" \
      http://192.168.10.89:8123/api/states/sensor.nuclei_scanner
}

# Start scan notification
update_home_assistant "scanning" "Running multi-VLAN scan" 0

# Scan each VLAN
VLANS=("192.168.10.0/24:default" "192.168.14.0/24:iot" "192.168.5.0/24:guest" "192.168.6.0/24:clients")

for vlan in "${VLANS[@]}"; do
    IFS=':' read -r subnet name <<< "$vlan"
    echo "Scanning $name VLAN: $subnet"
    
    nuclei -target "$subnet" \
           -o "$RESULTS_DIR/scan-$name.json" \
           -json \
           -severity medium,high,critical \
           -tags network,cve,router,iot,exposed-panels,default-logins \
           -stats-json \
           -si 30 \
           -exclude-hosts "192.168.10.163" # Exclude self (NAS)
done

# Scan critical infrastructure with enhanced checks
nuclei -list /home/nuclei/critical-hosts.txt \
       -o "$RESULTS_DIR/critical-infrastructure.json" \
       -json \
       -severity low,medium,high,critical \
       -t network/ -t ssl/ -t exposed-panels/ -t default-logins/ \
       -stats-json

# Compile results and check for findings
FINDINGS=$(jq -s '[.[] | select(.info.severity == "critical" or .info.severity == "high")] | length' "$RESULTS_DIR"/*.json 2>/dev/null || echo 0)

if [ "$FINDINGS" -gt 0 ]; then
    update_home_assistant "alert" "Found $FINDINGS vulnerabilities" "$FINDINGS"
    # Send notification to Home Assistant
    curl -X POST \
      -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"message\": \"Nuclei scan completed: $FINDINGS high/critical vulnerabilities found\", \"title\": \"Security Alert\"}" \
      http://192.168.10.89:8123/api/services/notify/notify
else
    update_home_assistant "ok" "No vulnerabilities found" 0
fi

# Generate summary report
echo "Scan completed at $SCAN_DATE" > "$RESULTS_DIR/summary.txt"
echo "Total high/critical findings: $FINDINGS" >> "$RESULTS_DIR/summary.txt"
cat "$RESULTS_DIR"/*.json | jq -r '.info.severity' | sort | uniq -c >> "$RESULTS_DIR/summary.txt"