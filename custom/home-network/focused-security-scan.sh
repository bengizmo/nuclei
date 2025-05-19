#!/bin/bash
# Focused security scan on specific hosts

# Load NAS configuration
source ./nas-config.sh

echo "🎯 Focused Security Scan"
echo "======================="
echo ""

SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/focused-$SCAN_DATE"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner mkdir -p $RESULTS_DIR"

# 1. Kill any existing scans
echo "1. Stopping existing scans..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pkill -f nuclei"
sleep 2
echo "Done"
echo ""

# 2. Create target list
echo "2. Creating target list..."
cat > targets.txt << EOF
192.168.10.1
192.168.10.89
192.168.10.249
192.168.10.251
192.168.10.163
192.168.10.156
192.168.10.50
192.168.10.7
192.168.10.130
192.168.14.10
192.168.14.50
192.168.14.150
EOF

# Copy to container
cat targets.txt | ${NAS_SSH} "${DOCKER_BIN} exec -i nuclei-scanner tee /home/nuclei/scan-targets.txt > /dev/null"
echo "Targets: $(cat targets.txt | wc -l) hosts"
echo ""

# 3. Run focused scan
echo "3. Running focused scan..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner nuclei \
    -list /home/nuclei/scan-targets.txt \
    -severity critical,high,medium \
    -tags network,panel,cve \
    -o $RESULTS_DIR/focused-scan.json \
    -jsonl \
    -timeout 10 \
    -retries 2 \
    -rate-limit 50 \
    -stats -si 10"

echo ""

# 4. Check results
echo "4. Scan Results"
echo "--------------"
FINDINGS=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner cat $RESULTS_DIR/focused-scan.json 2>/dev/null | wc -l")
echo "Total findings: $FINDINGS"

if [ $FINDINGS -gt 0 ]; then
    echo ""
    echo "Issues found:"
    ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner cat $RESULTS_DIR/focused-scan.json" | \
        ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner jq -r '\"[\(.info.severity)] \(.host) - \(.info.name)\"'" | \
        sort | uniq
fi
echo ""

# 5. Generate AI summary
echo "5. AI Summary"
echo "------------"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/generate-ai-summary.sh $RESULTS_DIR"
echo ""

# 6. Update Home Assistant
echo "6. Home Assistant Update"
echo "----------------------"
HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
CURRENT_STATE=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
    "http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_summary" | \
    jq -r '.state')
echo "Current HA state: $CURRENT_STATE"

# Cleanup
rm -f targets.txt

echo ""
echo "======================="
echo "✅ Focused scan complete!"
echo "Results: $RESULTS_DIR"