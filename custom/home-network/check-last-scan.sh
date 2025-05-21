#!/bin/bash
# Check the last scan results from the Nuclei container

cd "$(dirname "$0")"
source ./nas-config.sh

echo "🔍 Checking Last Nuclei Scan Results"
echo "===================================="

# Check if container is running
echo "1. Checking container status..."
CONTAINER_STATUS=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker ps --filter name=nuclei-scanner --format '{{.Status}}'" 2>/dev/null)

if [ -n "$CONTAINER_STATUS" ]; then
    echo "   ✅ Container is running: $CONTAINER_STATUS"
else
    echo "   ❌ Container is not running"
    exit 1
fi

# Check for latest results directory
echo ""
echo "2. Finding latest scan results..."
LATEST_SCAN=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner find /home/nuclei/results -maxdepth 1 -type d -name '*-*' | sort -r | head -1" 2>/dev/null)

if [ -n "$LATEST_SCAN" ]; then
    echo "   Latest scan directory: $LATEST_SCAN"
    SCAN_DATE=$(basename "$LATEST_SCAN")
    echo "   Scan date: $SCAN_DATE"
else
    echo "   ❌ No scan results found"
    echo "   Checking if results directory exists..."
    ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner ls -la /home/nuclei/results/" 2>/dev/null
    exit 1
fi

# Check scan summary
echo ""
echo "3. Checking scan summary..."
SUMMARY_FILE="$LATEST_SCAN/summary.txt"
SUMMARY_EXISTS=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner test -f $SUMMARY_FILE && echo 'exists' || echo 'missing'" 2>/dev/null)

if [ "$SUMMARY_EXISTS" = "exists" ]; then
    echo "   Reading summary file..."
    ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner cat $SUMMARY_FILE" 2>/dev/null
else
    echo "   No summary file found, checking other result files..."
    
    # Check for JSON status file
    STATUS_FILE="$LATEST_SCAN/status.json"
    STATUS_EXISTS=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner test -f $STATUS_FILE && echo 'exists' || echo 'missing'" 2>/dev/null)
    
    if [ "$STATUS_EXISTS" = "exists" ]; then
        echo "   Reading status file..."
        ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner cat $STATUS_FILE" 2>/dev/null
    fi
fi

# Check vulnerability findings
echo ""
echo "4. Checking vulnerability findings..."
VULN_DIR="$LATEST_SCAN/vulnerabilities"
VULN_COUNT=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner find $VULN_DIR -name '*.json' -type f 2>/dev/null | wc -l" 2>/dev/null)

if [ "$VULN_COUNT" -gt 0 ]; then
    echo "   Found $VULN_COUNT vulnerability result files"
    
    # Count total findings
    TOTAL_FINDINGS=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner find $VULN_DIR -name '*.json' -exec grep -c 'matched-at' {} \; 2>/dev/null | awk '{sum += \$1} END {print sum}'" 2>/dev/null)
    
    if [ -n "$TOTAL_FINDINGS" ] && [ "$TOTAL_FINDINGS" -gt 0 ]; then
        echo "   🚨 Total vulnerabilities found: $TOTAL_FINDINGS"
        
        # Show severity breakdown
        echo ""
        echo "   Severity breakdown:"
        CRITICAL=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner find $VULN_DIR -name '*.json' -exec grep -c '\"severity\":\"critical\"' {} \; 2>/dev/null | awk '{sum += \$1} END {print sum}'" 2>/dev/null)
        HIGH=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner find $VULN_DIR -name '*.json' -exec grep -c '\"severity\":\"high\"' {} \; 2>/dev/null | awk '{sum += \$1} END {print sum}'" 2>/dev/null)
        MEDIUM=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner find $VULN_DIR -name '*.json' -exec grep -c '\"severity\":\"medium\"' {} \; 2>/dev/null | awk '{sum += \$1} END {print sum}'" 2>/dev/null)
        
        echo "   - Critical: ${CRITICAL:-0}"
        echo "   - High: ${HIGH:-0}"
        echo "   - Medium: ${MEDIUM:-0}"
    else
        echo "   ✅ No vulnerabilities found in scan results"
    fi
else
    echo "   No vulnerability result files found"
fi

# Check hosts scanned
echo ""
echo "5. Checking hosts scanned..."
PORTS_DIR="$LATEST_SCAN/ports"
HOST_COUNT=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner find $PORTS_DIR -name '*.json' -type f 2>/dev/null | wc -l" 2>/dev/null)

if [ "$HOST_COUNT" -gt 0 ]; then
    echo "   Hosts scanned: $HOST_COUNT"
else
    echo "   No port scan results found"
fi

# Check Home Assistant current status
echo ""
echo "6. Checking current Home Assistant status..."
if [ -n "$HOME_ASSISTANT_API_TOKEN" ]; then
    HA_STATUS=$(curl -s -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
        "http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_status" | \
        jq -r '.state' 2>/dev/null)
    
    HA_SUMMARY=$(curl -s -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
        "http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_summary" | \
        jq -r '.state' 2>/dev/null)
    
    HA_FINDINGS=$(curl -s -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
        "http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_findings" | \
        jq -r '.state' 2>/dev/null)
    
    echo "   Home Assistant Status: $HA_STATUS"
    echo "   Home Assistant Summary: $HA_SUMMARY"
    echo "   Home Assistant Findings: $HA_FINDINGS"
else
    echo "   Home Assistant API token not available"
fi

echo ""
echo "===================================="
echo "Last scan check complete!"