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

# 4. Trigger improved multi-VLAN scan
echo ""
echo "4. Triggering Full Network Scan"
echo "-----------------------------"
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
echo "Scan ID: $SCAN_DATE"

# Execute the improved multi-VLAN script
echo "Starting enhanced multi-VLAN scan (with full vulnerability assessment)..."
${NAS_SSH} "${DOCKER_BIN} exec -d nuclei-scanner /bin/sh -c '/home/nuclei/scripts/improved-multi-vlan-scan.sh > /home/nuclei/logs/full-scan-$SCAN_DATE.log 2>&1'"

# 5. Monitor scan progress
echo ""
echo "5. Monitoring Scan Progress"
echo "-------------------------"
echo "Waiting for scan to start..."
sleep 5

# Check active nuclei processes
ACTIVE_SCANS=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pgrep -f nuclei | wc -l")
echo "Active nuclei processes: $ACTIVE_SCANS"

# Show scan progress (first 10 seconds)
echo ""
echo "Scan output (first 10 seconds):"
timeout 10 ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner tail -f /home/nuclei/logs/full-scan-$SCAN_DATE.log 2>/dev/null" || true

# 6. Update Home Assistant
echo ""
echo "6. Updating Home Assistant"
echo "------------------------"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner curl -s -X POST \
    -H \"Authorization: Bearer \${HOME_ASSISTANT_API_TOKEN}\" \
    -H \"Content-Type: application/json\" \
    -d '{\"state\": \"scanning\", \"attributes\": {\"friendly_name\": \"Nuclei Scanner\", \"icon\": \"mdi:shield-search\", \"status\": \"Full scan in progress\", \"last_scan_start\": \"$(date -Iseconds)\"}}' \
    \"http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_system\"" >/dev/null 2>&1

# Send notification to Home Assistant
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner curl -s -X POST \
    -H \"Authorization: Bearer \${HOME_ASSISTANT_API_TOKEN}\" \
    -H \"Content-Type: application/json\" \
    -d '{\"message\": \"Enhanced full network scan initiated manually. This scan will cover all devices across all VLANs.\", \"title\": \"Nuclei Scanner\"}' \
    \"http://192.168.10.89:8123/api/services/notify/notify\"" >/dev/null 2>&1

echo ""
echo "====================================="
echo "✅ Full scan triggered!"
echo ""
echo "Scan log: /home/nuclei/logs/full-scan-$SCAN_DATE.log"
echo "Results will be in: /home/nuclei/results/$SCAN_DATE/"
echo ""
echo "Note: Full network scan may take 30-60 minutes to complete"
echo "Monitor progress with:"
echo "  ${NAS_SSH} '${DOCKER_BIN} exec nuclei-scanner tail -f /home/nuclei/logs/full-scan-$SCAN_DATE.log'"
echo ""
echo "Check status when complete:"
echo "  ./check-nas.sh"