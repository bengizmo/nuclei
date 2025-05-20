#!/bin/bash
# Script to manually update Home Assistant entities

HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

echo "🔄 Manually Updating Home Assistant Entities"
echo "=========================================="

# Get discovery data from the NAS
source ./nas-config.sh
echo "1. Fetching data from NAS..."

# Get the total number of hosts
hosts=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner grep -v '^#' /home/nuclei/discovery/discovery.db | wc -l")
echo "   Hosts discovered: $hosts"

# Get the number of vulnerabilities
vulns=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'find /home/nuclei/results -name \"*.json\" | xargs cat 2>/dev/null | grep -c \"matched-at\" || echo 0'")
echo "   Vulnerabilities found: $vulns"

# Get the timestamp of the last scan
last_scan=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner cat /home/nuclei/discovery/status.json 2>/dev/null | grep -o '\"last_scan\":\"[^\"]*\"' | cut -d'\"' -f4")
echo "   Last scan: $last_scan"

# Determine status
if [ "$vulns" -gt 0 ]; then
    status="alert"
else
    status="idle"
fi
echo "   Status: $status"

echo ""
echo "2. Updating entities..."

# Function to update a sensor entity
update_sensor() {
    local entity_id=$1
    local state=$2
    local friendly_name=$3
    local icon=$4
    local device_class=$5
    local attributes=$6
    
    # Create base attributes
    if [ -z "$attributes" ]; then
        attributes="{
            \"friendly_name\": \"${friendly_name}\",
            \"icon\": \"${icon}\",
            \"device_class\": \"${device_class}\",
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\",
                \"model\": \"Docker Container\",
                \"manufacturer\": \"ProjectDiscovery\",
                \"sw_version\": \"3.4.2\"
            }
        }"
    fi
    
    # Update the entity
    response=$(curl -s -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"state\": \"${state}\",
            \"attributes\": ${attributes}
        }" \
        "${HA_URL}/api/states/${entity_id}")
    
    echo "   Updated $entity_id: $state"
}

# Update the main nuclei_scanner entity
update_sensor "sensor.nuclei_scanner" "${status}" "Nuclei Scanner" "mdi:shield-search" "" "{
    \"friendly_name\": \"Nuclei Scanner\",
    \"icon\": \"mdi:shield-search\",
    \"status\": \"${status}\",
    \"findings\": ${vulns},
    \"hosts_scanned\": ${hosts},
    \"last_scan\": \"${last_scan}\",
    \"device\": {
        \"identifiers\": [\"nuclei_scanner_001\"],
        \"name\": \"Nuclei Scanner\",
        \"model\": \"Network Vulnerability Scanner\",
        \"manufacturer\": \"ProjectDiscovery\",
        \"sw_version\": \"3.4.2\"
    }
}"

# Update status entity
update_sensor "sensor.nuclei_scanner_status" "${status}" "Nuclei Scanner Status" "mdi:shield-check" ""

# Update findings entity
update_sensor "sensor.nuclei_scanner_findings" "${vulns}" "Vulnerabilities Found" "mdi:bug" ""

# Update hosts entity
update_sensor "sensor.nuclei_scanner_hosts" "${hosts}" "Hosts Scanned" "mdi:server-network" ""

# Update last scan entity
update_sensor "sensor.nuclei_scanner_last_scan" "${last_scan}" "Last Scan Time" "mdi:clock-outline" "timestamp"

# Create summary
summary="Last scan found ${vulns} vulnerabilities across ${hosts} hosts"
update_sensor "sensor.nuclei_scanner_summary" "${summary}" "Nuclei Scanner Summary" "mdi:shield-search" "diagnostic"

echo ""
echo "=========================================="
echo "✅ All entities updated successfully!"
echo ""
echo "Check the entities in Home Assistant dashboard"