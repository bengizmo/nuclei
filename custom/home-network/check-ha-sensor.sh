#!/bin/bash
# Script to check the status of the nuclei sensor in Home Assistant

# Get HA token
HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

# Display HA sensor information
echo "📊 Nuclei Scanner Status in Home Assistant"
echo "========================================"
echo ""

# Get sensor data
SENSOR_DATA=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
    "$HA_URL/api/states/sensor.nuclei_scanner_summary")

# Extract key information
STATE=$(echo "$SENSOR_DATA" | jq -r '.state')
SCAN_STATUS=$(echo "$SENSOR_DATA" | jq -r '.attributes.scan_status // "unknown"')
CRITICAL=$(echo "$SENSOR_DATA" | jq -r '.attributes.critical_count // 0')
HIGH=$(echo "$SENSOR_DATA" | jq -r '.attributes.high_count // 0')
MEDIUM=$(echo "$SENSOR_DATA" | jq -r '.attributes.medium_count // 0')
LOW=$(echo "$SENSOR_DATA" | jq -r '.attributes.low_count // 0')
HOSTS=$(echo "$SENSOR_DATA" | jq -r '.attributes.hosts_scanned // 0')
LAST_SCAN=$(echo "$SENSOR_DATA" | jq -r '.attributes.last_scan // "never"')

# Display information
echo "Current State: $STATE"
echo ""
echo "Scan Status: $SCAN_STATUS"
echo "Last Scan: $LAST_SCAN"
echo "Hosts Scanned: $HOSTS"
echo ""
echo "Vulnerability Summary:"
echo "- Critical: $CRITICAL"
echo "- High: $HIGH"
echo "- Medium: $MEDIUM"
echo "- Low: $LOW"
echo ""
echo "========================================"
echo "Integration Status: $([ -n "$STATE" ] && echo "✅ Working" || echo "❌ Not Working")"
echo ""
echo "This entity contains all necessary data for Home Assistant integration"
echo "and replaces the previous collection of separate entities."