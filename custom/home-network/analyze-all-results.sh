#!/bin/bash
# Analyze all existing scan results

# Load NAS configuration
source ./nas-config.sh

echo "📊 Analyzing All Scan Results"
echo "==========================="
echo ""

# 1. Find all JSON results
echo "1. Finding all scan results..."
RESULTS=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find /home/nuclei/results -name '*.json' -type f")
TOTAL_FILES=$(echo "$RESULTS" | wc -l)
echo "Found $TOTAL_FILES result files"
echo ""

# 2. Count total vulnerabilities
echo "2. Counting vulnerabilities..."
TOTAL_VULNS=0
while IFS= read -r file; do
    if [ -n "$file" ]; then
        count=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner cat $file 2>/dev/null | wc -l")
        TOTAL_VULNS=$((TOTAL_VULNS + count))
    fi
done <<< "$RESULTS"
echo "Total vulnerabilities found: $TOTAL_VULNS"
echo ""

# 3. Group by severity
echo "3. Vulnerabilities by severity:"
echo "------------------------------"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find /home/nuclei/results -name '*.json' -exec cat {} \;" | \
    ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner jq -r '.info.severity' 2>/dev/null" | \
    sort | uniq -c | sort -nr
echo ""

# 4. Top affected hosts
echo "4. Top affected hosts:"
echo "--------------------"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find /home/nuclei/results -name '*.json' -exec cat {} \;" | \
    ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner jq -r '.host' 2>/dev/null" | \
    sort | uniq -c | sort -nr | head -10
echo ""

# 5. Common vulnerabilities
echo "5. Most common vulnerabilities:"
echo "-----------------------------"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find /home/nuclei/results -name '*.json' -exec cat {} \;" | \
    ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner jq -r '.info.name' 2>/dev/null" | \
    sort | uniq -c | sort -nr | head -10
echo ""

# 6. Critical/High issues
echo "6. Critical/High severity issues:"
echo "-------------------------------"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find /home/nuclei/results -name '*.json' -exec cat {} \;" | \
    ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner jq -r 'select(.info.severity == \"critical\" or .info.severity == \"high\") | \"[\(.info.severity)] \(.host) - \(.info.name)\"' 2>/dev/null" | \
    sort | uniq | head -10
echo ""

# 7. Generate comprehensive AI summary
echo "7. Generating AI summary..."
echo "-------------------------"
# Find the most recent results directory
LATEST_DIR=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find /home/nuclei/results -maxdepth 1 -type d | sort -r | head -2 | tail -1")
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/generate-ai-summary.sh $LATEST_DIR"
echo ""

# 8. Current HA status
echo "8. Home Assistant Status:"
echo "-----------------------"
HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
curl -s -H "Authorization: Bearer $HA_TOKEN" \
    "http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_summary" | \
    jq '{state, last_changed, attributes: {critical_count, high_count, medium_count, low_count}}'

echo ""
echo "==========================="
echo "✅ Analysis complete!"