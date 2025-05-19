#!/bin/bash
# Quick comprehensive scan with monitoring

# Load NAS configuration
source ./nas-config.sh

echo "🚀 Quick Comprehensive Security Scan"
echo "=================================="
echo ""

SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/quick-scan-$SCAN_DATE"

# Create results directory
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner mkdir -p $RESULTS_DIR"

# 1. Quick scan of main subnet
echo "1. Scanning Main Network (192.168.10.0/24)"
echo "----------------------------------------"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner nuclei \
    -target 192.168.10.0/24 \
    -exclude-hosts 192.168.10.163 \
    -severity critical,high \
    -t exposed-panels/ -t cves/2024/ -t cves/2023/ \
    -o $RESULTS_DIR/main-network.json \
    -jsonl \
    -rate-limit 50 \
    -timeout 5s \
    -retries 1" &

SCAN_PID=$!
echo "Scan started (PID: $SCAN_PID)"
echo ""

# 2. Scan critical hosts
echo "2. Scanning Critical Infrastructure"
echo "---------------------------------"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner nuclei \
    -list /home/nuclei/critical-hosts.txt \
    -severity critical,high,medium \
    -t exposed-panels/ -t misconfigurations/ -t default-logins/ \
    -o $RESULTS_DIR/critical-hosts.json \
    -jsonl \
    -rate-limit 50" &

CRITICAL_PID=$!
echo "Critical scan started (PID: $CRITICAL_PID)"
echo ""

# 3. Monitor progress
echo "3. Monitoring Scan Progress"
echo "--------------------------"
echo "Waiting for scans to complete..."

# Check progress every 10 seconds
for i in {1..30}; do
    ACTIVE=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pgrep -f nuclei | wc -l")
    RESULTS=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find $RESULTS_DIR -name '*.json' -exec wc -l {} \; | paste -sd+ | bc 2>/dev/null || echo 0")
    echo -ne "\rProgress: $((i*10))s | Active: $ACTIVE | Results: $RESULTS  "
    
    if [ $ACTIVE -eq 0 ]; then
        echo -e "\n✓ Scans complete!"
        break
    fi
    sleep 10
done
echo ""
echo ""

# 4. Analyze results
echo "4. Scan Results"
echo "--------------"
TOTAL_FINDINGS=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find $RESULTS_DIR -name '*.json' -exec cat {} \; | wc -l")
echo "Total findings: $TOTAL_FINDINGS"

if [ $TOTAL_FINDINGS -gt 0 ]; then
    echo ""
    echo "Top findings:"
    ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find $RESULTS_DIR -name '*.json' -exec cat {} \;" | \
        ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner jq -r '\"[\(.info.severity)] \(.host) - \(.info.name)\"'" | \
        sort | uniq | head -10
fi
echo ""

# 5. Generate summary
echo "5. AI Summary Generation"
echo "----------------------"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/generate-ai-summary.sh $RESULTS_DIR"
echo ""

# 6. Check Home Assistant
echo "6. Home Assistant Status"
echo "----------------------"
HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
SUMMARY=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
    "http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_summary" | \
    jq -r '.state')
echo "HA Summary: $SUMMARY"

echo ""
echo "=================================="
echo "✅ Quick scan complete!"
echo ""
echo "Results: $RESULTS_DIR"
echo "Total findings: $TOTAL_FINDINGS"