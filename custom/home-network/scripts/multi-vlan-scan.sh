#!/bin/sh
# multi-vlan-scan.sh - Comprehensive multi-VLAN scanning script

SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

# Function to update Home Assistant
update_home_assistant() {
    # TODO: Add Home Assistant integration
    echo "Status: $1 - $2"
}

# Start scan notification
update_home_assistant "scanning" "Running multi-VLAN scan" 0

# Scan each VLAN
VLANS="192.168.10.0/24:default 192.168.14.0/24:iot 192.168.5.0/24:guest 192.168.6.0/24:clients"

for vlan in $VLANS; do
    subnet=$(echo $vlan | cut -d: -f1)
    name=$(echo $vlan | cut -d: -f2)
    echo "Scanning $name VLAN: $subnet"
    
    nuclei -target "$subnet" \
           -o "$RESULTS_DIR/scan-$name.json" \
           -j \
           -s medium,high,critical \
           -t network/ -t cve/ -t exposed-panels/ -t default-logins/ \
           -si 30
done

# Scan critical infrastructure with enhanced checks
nuclei -l /home/nuclei/critical-hosts.txt \
       -o "$RESULTS_DIR/critical-infrastructure.json" \
       -j \
       -s low,medium,high,critical \
       -t network/ -t ssl/ -t exposed-panels/ -t default-logins/

# Compile results and check for findings
echo "Scan completed at $SCAN_DATE" > "$RESULTS_DIR/summary.txt"
echo "Results available in: $RESULTS_DIR" >> "$RESULTS_DIR/summary.txt"

# Count JSON files
JSON_COUNT=$(find "$RESULTS_DIR" -name "*.json" | wc -l)
echo "Generated $JSON_COUNT result files" >> "$RESULTS_DIR/summary.txt"

# Simple check for findings
if grep -l "severity" "$RESULTS_DIR"/*.json 2>/dev/null; then
    update_home_assistant "alert" "Found vulnerabilities" "1"
    echo "Vulnerabilities found - check JSON files for details" >> "$RESULTS_DIR/summary.txt"
else
    update_home_assistant "ok" "No vulnerabilities found" "0"
    echo "No vulnerabilities found" >> "$RESULTS_DIR/summary.txt"
fi

# Create a latest symlink
ln -sf "$RESULTS_DIR" "/home/nuclei/results/latest"