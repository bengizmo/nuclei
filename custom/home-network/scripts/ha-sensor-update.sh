#!/bin/sh
# Update Home Assistant sensors for Nuclei Scanner
# This creates/updates sensor entities properly

HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"

# Function to create/update a sensor
update_sensor() {
    local entity_id=$1
    local state=$2
    local friendly_name=$3
    local icon=$4
    local device_class=$5
    local unit=$6
    
    # Prepare attributes JSON
    attributes="{
        \"friendly_name\": \"${friendly_name}\",
        \"icon\": \"${icon}\",
        \"device_class\": \"${device_class}\",
        \"attribution\": \"Nuclei Scanner\",
        \"device\": {
            \"identifiers\": [\"nuclei_scanner_001\"],
            \"name\": \"Nuclei Scanner\",
            \"model\": \"Docker Container\",
            \"manufacturer\": \"ProjectDiscovery\",
            \"sw_version\": \"3.4.2\"
        }"
    
    # Add unit if specified
    if [ -n "$unit" ]; then
        attributes="${attributes%\}}, \"unit_of_measurement\": \"${unit}\"}"
    else
        attributes="${attributes}}"
    fi
    
    # Update the sensor
    curl -s -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"state\": \"${state}\",
            \"attributes\": ${attributes}
        }" \
        "${HA_BASE_URL}/api/states/${entity_id}"
}

# Parse command line arguments or use defaults
STATUS="${1:-idle}"
FINDINGS="${2:-0}"
HOSTS_SCANNED="${3:-0}"
LAST_SCAN="${4:-$(date -u +%Y-%m-%dT%H:%M:%S+00:00)}"

echo "Updating Nuclei Scanner sensors..."

# Update status sensor
update_sensor "sensor.nuclei_scanner_status" \
    "${STATUS}" \
    "Nuclei Scanner Status" \
    "mdi:shield-search" \
    "" \
    ""

# Update findings sensor
update_sensor "sensor.nuclei_scanner_findings" \
    "${FINDINGS}" \
    "Vulnerabilities Found" \
    "mdi:bug" \
    "" \
    ""

# Update hosts scanned sensor
update_sensor "sensor.nuclei_scanner_hosts" \
    "${HOSTS_SCANNED}" \
    "Hosts Scanned" \
    "mdi:server-network" \
    "" \
    ""

# Update last scan sensor
update_sensor "sensor.nuclei_scanner_last_scan" \
    "${LAST_SCAN}" \
    "Last Scan Time" \
    "mdi:clock-outline" \
    "timestamp" \
    ""

# Create a main sensor that aggregates all info
main_attributes="{
    \"friendly_name\": \"Nuclei Scanner\",
    \"icon\": \"mdi:shield-search\",
    \"status\": \"${STATUS}\",
    \"findings\": ${FINDINGS},
    \"hosts_scanned\": ${HOSTS_SCANNED},
    \"last_scan\": \"${LAST_SCAN}\",
    \"device\": {
        \"identifiers\": [\"nuclei_scanner_001\"],
        \"name\": \"Nuclei Scanner\",
        \"model\": \"Network Vulnerability Scanner\",
        \"manufacturer\": \"ProjectDiscovery\",
        \"sw_version\": \"3.4.2\",
        \"configuration_url\": \"http://192.168.10.163:9090\"
    }
}"

curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"${STATUS}\",
        \"attributes\": ${main_attributes}
    }" \
    "${HA_BASE_URL}/api/states/sensor.nuclei_scanner"

echo "Sensors updated successfully!"