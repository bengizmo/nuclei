#!/bin/bash
# Verify container and trigger full network scan

# Load NAS configuration
source ./nas-config.sh

echo "🔍 Container Status & Full Network Scan"
echo "====================================="
echo ""

# 1. Container Health Check
echo "1. Container Health Check"
echo "-----------------------"
CONTAINER_STATUS=$(${NAS_SSH} "${DOCKER_BIN} inspect nuclei-scanner --format '{{.State.Status}}'")
echo "Container status: $CONTAINER_STATUS"

CONTAINER_UPTIME=$(${NAS_SSH} "${DOCKER_BIN} inspect nuclei-scanner --format '{{.State.StartedAt}}'")
echo "Container started: $CONTAINER_UPTIME"

# Check services
DISCOVERY_PID=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pgrep -f network-discovery.sh")
echo "Discovery service PID: ${DISCOVERY_PID:-Not Running}"
echo ""

# 2. Current Discovery Status
echo "2. Current Discovery Status"
echo "-------------------------"
DISCOVERED=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner grep -v '^#' /home/nuclei/discovery/discovery.db | wc -l")
echo "Devices in database: $DISCOVERED"

# Show recent discoveries
echo "Recent discovery activity:"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner tail -3 /home/nuclei/logs/discovery.log"
echo ""

# 3. Kill any existing scans and start fresh
echo "3. Preparing for Full Scan"
echo "------------------------"
echo "Stopping any active scans..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pkill -f nuclei"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pkill -f profile-new-host"
sleep 2

# 4. Trigger full VLAN scan
echo ""
echo "4. Triggering Full Network Scan"
echo "-----------------------------"
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
echo "Scan ID: $SCAN_DATE"

# Create scan results directory
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner mkdir -p /home/nuclei/results/full-scan-$SCAN_DATE"

# Define all VLANs to scan
VLANS=(
    "192.168.10.0/24:default"
    "192.168.14.0/24:iot"
    "192.168.5.0/24:guest"
    "192.168.6.0/24:clients"
)

# Start comprehensive scan
echo "Scanning all VLANs..."
for vlan in "${VLANS[@]}"; do
    IFS=':' read -r subnet name <<< "$vlan"
    echo "Scanning $name VLAN: $subnet"
    
    ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner nuclei \
        -target $subnet \
        -exclude-hosts '192.168.10.163' \
        -severity low,medium,high,critical \
        -tags network,cve,panel,misconfiguration,default-login \
        -o /home/nuclei/results/full-scan-$SCAN_DATE/scan-$name.json \
        -jsonl \
        -stats-interval 30s \
        -timeout 10s \
        -concurrency 25" &
done

# Also scan critical infrastructure
echo ""
echo "Scanning critical infrastructure..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner nuclei \
    -list /home/nuclei/critical-hosts.txt \
    -severity info,low,medium,high,critical \
    -t exposed-panels/ -t default-logins/ -t misconfigurations/ -t cves/ \
    -o /home/nuclei/results/full-scan-$SCAN_DATE/critical-infrastructure.json \
    -jsonl \
    -stats-interval 30s" &

# 5. Monitor scan progress
echo ""
echo "5. Monitoring Scan Progress"
echo "-------------------------"
echo "Waiting for scans to start..."
sleep 10

# Check active nuclei processes
ACTIVE_SCANS=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pgrep -f nuclei | wc -l")
echo "Active nuclei processes: $ACTIVE_SCANS"

# Show scan progress
echo ""
echo "Scan output (first 10 seconds):"
timeout 10 ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner tail -f /home/nuclei/logs/nuclei.log 2>/dev/null" || true

# 6. Wait and check results
echo ""
echo "6. Preliminary Results"
echo "--------------------"
echo "Waiting 30 seconds for initial results..."
sleep 30

# Check for findings
FINDINGS=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find /home/nuclei/results/full-scan-$SCAN_DATE -name '*.json' -exec cat {} \; | wc -l")
echo "Vulnerabilities found so far: $FINDINGS"

# 7. Generate AI summary
echo ""
echo "7. Generating AI Summary"
echo "----------------------"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/generate-ai-summary.sh /home/nuclei/results/full-scan-$SCAN_DATE"

# 8. Check Home Assistant update
echo ""
echo "8. Home Assistant Status"
echo "----------------------"
HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

SUMMARY=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
    "$HA_URL/api/states/sensor.nuclei_scanner_summary" | \
    jq -r '.state')
echo "Current HA summary: $SUMMARY"

echo ""
echo "====================================="
echo "✅ Full scan triggered!"
echo ""
echo "Scan ID: full-scan-$SCAN_DATE"
echo "Results location: /home/nuclei/results/full-scan-$SCAN_DATE"
echo ""
echo "Note: Full network scan may take 10-30 minutes to complete"
echo "Monitor progress with:"
echo "  ${NAS_SSH} '${DOCKER_BIN} exec nuclei-scanner tail -f /home/nuclei/logs/nuclei.log'"
echo ""
echo "Check final results with:"
echo "  ${NAS_SSH} '${DOCKER_BIN} exec nuclei-scanner ls -la /home/nuclei/results/full-scan-$SCAN_DATE/'"