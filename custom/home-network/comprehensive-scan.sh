#!/bin/bash
# Comprehensive network scan with proper flags

# Load NAS configuration
source ./nas-config.sh

echo "🔍 Comprehensive Network Security Scan"
echo "===================================="
echo ""

SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/comprehensive-$SCAN_DATE"

# 1. Prepare scan
echo "1. Preparing Scan"
echo "---------------"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner mkdir -p $RESULTS_DIR"
echo "Results directory: $RESULTS_DIR"
echo ""

# 2. Scan all VLANs
echo "2. Scanning Network VLANs"
echo "-----------------------"

# Default VLAN
echo "Scanning Default VLAN (192.168.10.0/24)..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner nuclei \
    -target 192.168.10.0/24 \
    -exclude-hosts 192.168.10.163 \
    -severity critical,high,medium,low \
    -o $RESULTS_DIR/default-vlan.json \
    -jsonl \
    -silent" &

# IoT VLAN
echo "Scanning IoT VLAN (192.168.14.0/24)..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner nuclei \
    -target 192.168.14.0/24 \
    -severity critical,high,medium,low \
    -tags iot,camera,panel \
    -o $RESULTS_DIR/iot-vlan.json \
    -jsonl \
    -silent" &

# Guest VLAN
echo "Scanning Guest VLAN (192.168.5.0/24)..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner nuclei \
    -target 192.168.5.0/24 \
    -severity critical,high,medium,low \
    -o $RESULTS_DIR/guest-vlan.json \
    -jsonl \
    -silent" &

# Clients VLAN
echo "Scanning Clients VLAN (192.168.6.0/24)..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner nuclei \
    -target 192.168.6.0/24 \
    -severity critical,high,medium,low \
    -o $RESULTS_DIR/clients-vlan.json \
    -jsonl \
    -silent" &

echo "All VLAN scans started..."
echo ""

# 3. Scan critical infrastructure
echo "3. Scanning Critical Infrastructure"
echo "---------------------------------"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner nuclei \
    -list /home/nuclei/critical-hosts.txt \
    -severity critical,high,medium,low,info \
    -tags panel,cve,misconfiguration,network \
    -o $RESULTS_DIR/critical-infrastructure.json \
    -jsonl \
    -silent" &

echo "Critical infrastructure scan started..."
echo ""

# 4. Monitor progress
echo "4. Monitoring Scan Progress"
echo "-------------------------"
sleep 5

# Check active scans
ACTIVE_SCANS=1
ITERATIONS=0
while [ $ACTIVE_SCANS -gt 0 ] && [ $ITERATIONS -lt 120 ]; do  # Max 10 minutes
    ACTIVE_SCANS=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pgrep -f nuclei | wc -l")
    echo -ne "\rActive scans: $ACTIVE_SCANS | Time: $((ITERATIONS * 5))s | Results: $(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find $RESULTS_DIR -name '*.json' -exec cat {} \; | wc -l") "
    sleep 5
    ITERATIONS=$((ITERATIONS + 1))
done
echo ""
echo ""

# 5. Compile results
echo "5. Scan Results"
echo "--------------"
TOTAL_FINDINGS=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find $RESULTS_DIR -name '*.json' -exec cat {} \; | wc -l")
echo "Total vulnerabilities found: $TOTAL_FINDINGS"

# Count by severity
if [ $TOTAL_FINDINGS -gt 0 ]; then
    echo ""
    echo "By severity:"
    ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find $RESULTS_DIR -name '*.json' -exec cat {} \;" | \
        ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner jq -r '.info.severity'" | \
        sort | uniq -c
fi
echo ""

# 6. Generate AI summary
echo "6. Generating AI Summary"
echo "----------------------"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/generate-ai-summary.sh $RESULTS_DIR"
echo ""

# 7. Check Home Assistant
echo "7. Home Assistant Update"
echo "----------------------"
HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

ENTITY_DATA=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
    "$HA_URL/api/states/sensor.nuclei_scanner_summary")

echo "Current state:"
echo "$ENTITY_DATA" | jq -r '.state'
echo ""
echo "Vulnerability counts:"
echo "$ENTITY_DATA" | jq '.attributes | {critical_count, high_count, medium_count, low_count}'
echo ""

# 8. Notable findings
echo "8. Notable Findings"
echo "-----------------"
if [ $TOTAL_FINDINGS -gt 0 ]; then
    echo "High/Critical issues:"
    ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find $RESULTS_DIR -name '*.json' -exec cat {} \;" | \
        ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner jq -r 'select(.info.severity == \"high\" or .info.severity == \"critical\") | \"[\(.info.severity)] \(.host) - \(.info.name)\"'" | \
        head -10
else
    echo "No vulnerabilities found - network appears secure!"
fi

echo ""
echo "===================================="
echo "✅ Comprehensive scan complete!"
echo ""
echo "Results saved to: $RESULTS_DIR"
echo "Scan ID: comprehensive-$SCAN_DATE"
echo ""
echo "To view detailed results:"
echo "  ${NAS_SSH} '${DOCKER_BIN} exec nuclei-scanner ls -la $RESULTS_DIR/'"
echo ""
echo "To check specific findings:"
echo "  ${NAS_SSH} '${DOCKER_BIN} exec nuclei-scanner cat $RESULTS_DIR/*.json | jq'\"