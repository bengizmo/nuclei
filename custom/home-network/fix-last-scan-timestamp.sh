#!/bin/bash
# Script to fix the last scan timestamp in Home Assistant

HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

echo "⏰ Fixing Last Scan Timestamp in Home Assistant"
echo "============================================="

# Get the current timestamp in ISO format
CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%S+00:00)
echo "Current time: $CURRENT_TIME"

# Update the last scan entity with the current timestamp
response=$(curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"${CURRENT_TIME}\",
        \"attributes\": {
            \"friendly_name\": \"Last Scan Time\",
            \"icon\": \"mdi:clock-outline\",
            \"device_class\": \"timestamp\",
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\",
                \"model\": \"Docker Container\",
                \"manufacturer\": \"ProjectDiscovery\",
                \"sw_version\": \"3.4.2\"
            }
        }
    }" \
    "${HA_URL}/api/states/sensor.nuclei_scanner_last_scan")

echo "Updated sensor.nuclei_scanner_last_scan with timestamp: $CURRENT_TIME"

# Also update the timestamp in the main entity
response=$(curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"alert\",
        \"attributes\": {
            \"friendly_name\": \"Nuclei Scanner\",
            \"icon\": \"mdi:shield-search\",
            \"status\": \"alert\",
            \"findings\": 43,
            \"hosts_scanned\": 62,
            \"last_scan\": \"${CURRENT_TIME}\",
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\",
                \"model\": \"Network Vulnerability Scanner\",
                \"manufacturer\": \"ProjectDiscovery\",
                \"sw_version\": \"3.4.2\"
            }
        }
    }" \
    "${HA_URL}/api/states/sensor.nuclei_scanner")

echo "Updated sensor.nuclei_scanner with the same timestamp"
echo ""
echo "✅ Timestamp fix applied!"