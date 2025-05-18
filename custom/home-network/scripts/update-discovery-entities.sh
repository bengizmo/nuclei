#!/bin/sh
# Simple entity updater for Home Assistant - no dashboards, just entities

DISCOVERY_DB="/home/nuclei/discovery/discovery.db"
HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"

# Main discovery sensor
TOTAL_DEVICES=$(grep -cv '^#' "$DISCOVERY_DB")
curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"${TOTAL_DEVICES}\",
        \"attributes\": {
            \"friendly_name\": \"Network Devices Found\",
            \"icon\": \"mdi:lan\",
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\",
                \"model\": \"Network Vulnerability Scanner\",
                \"manufacturer\": \"ProjectDiscovery\",
                \"sw_version\": \"3.4.2\"
            }
        }
    }" \
    "${HA_BASE_URL}/api/states/sensor.nuclei_devices_found"

# New devices sensor
NEW_DEVICES=$(cat /home/nuclei/discovery/new_hosts.txt 2>/dev/null | wc -l)
if [ "$NEW_DEVICES" -gt 0 ]; then
    curl -s -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"state\": \"${NEW_DEVICES}\",
            \"attributes\": {
                \"friendly_name\": \"New Devices Found\",
                \"icon\": \"mdi:new-box\",
                \"device\": {
                    \"identifiers\": [\"nuclei_scanner_001\"],
                    \"name\": \"Nuclei Scanner\",
                    \"model\": \"Network Vulnerability Scanner\",
                    \"manufacturer\": \"ProjectDiscovery\",
                    \"sw_version\": \"3.4.2\"
                }
            }
        }" \
        "${HA_BASE_URL}/api/states/sensor.nuclei_new_devices"
fi