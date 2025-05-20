#!/bin/bash
# Deploy and fix Home Assistant multi-entity integration with the NAS container

echo "🚀 Deploying and Fixing Home Assistant Multi-Entity Integration"
echo "=============================================================="
echo ""

# Source configuration
source ./nas-config.sh

# Verify connection to NAS
echo "1. Verifying NAS connection..."
if ${NAS_SSH} "echo Connected successfully"; then
    echo "✅ Connected to NAS at ${NAS_HOST}"
else
    echo "❌ Failed to connect to NAS"
    exit 1
fi

# Create temporary directory for files
echo ""
echo "2. Preparing deployment files..."
TEMP_DIR=$(mktemp -d)

# Create enhanced ha-sensor-update script
cat > "${TEMP_DIR}/ha-sensor-update.sh" << 'EOF'
#!/bin/sh
# Update Home Assistant sensors for Nuclei Scanner
# Enhanced version that updates the actual Home Assistant entities

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

# Update the summary with a generic message if not provided
if [ -z "$5" ]; then
    SUMMARY="Last scan completed with ${FINDINGS} findings across ${HOSTS_SCANNED} hosts"
else
    SUMMARY="$5"
fi

# Update summary sensor
update_sensor "sensor.nuclei_scanner_summary" \
    "${SUMMARY}" \
    "Nuclei Scanner Summary" \
    "mdi:shield-search" \
    "diagnostic" \
    ""

echo "Sensors updated successfully!"
EOF

# Create script to modify improved-multi-vlan-scan.sh to update HA
cat > "${TEMP_DIR}/ha-scan-integration.sh" << 'EOF'
#!/bin/sh
# Script to inject Home Assistant integration into the multi-VLAN scan script

# Insert HA update at the end of the improved-multi-vlan-scan.sh script
sed -i '/Create symlink to latest results/a\
\
# Update Home Assistant entities\
if [ -x "/home/nuclei/scripts/ha-sensor-update.sh" ] && [ -n "${HOME_ASSISTANT_API_TOKEN}" ]; then\
    echo "Updating Home Assistant entities..."\
    status="idle"\
    if [ "$total_findings" -gt 0 ]; then\
        status="alert"\
    fi\
    summary="Scan complete: $port_scan_count hosts scanned, $total_findings vulnerabilities found"\
    /home/nuclei/scripts/ha-sensor-update.sh "$status" "$total_findings" "$port_scan_count" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)" "$summary"\
fi' /home/nuclei/scripts/improved-multi-vlan-scan.sh

# Insert HA update at the beginning of the scan to show "scanning" status
sed -i '/Starting improved multi-VLAN security scan/a\
\
# Update Home Assistant entities to show scanning status\
if [ -x "/home/nuclei/scripts/ha-sensor-update.sh" ] && [ -n "${HOME_ASSISTANT_API_TOKEN}" ]; then\
    echo "Updating Home Assistant to show scanning status..."\
    /home/nuclei/scripts/ha-sensor-update.sh "scanning" "0" "0" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)" "Scan in progress..."\
fi' /home/nuclei/scripts/improved-multi-vlan-scan.sh

echo "Integration script installed successfully!"
EOF

# Create script to update all the entities right now
cat > "${TEMP_DIR}/update-entities-now.sh" << 'EOF'
#!/bin/sh
# Update all entities with current values from the latest scan

# Find the latest results
LATEST_DIR="/home/nuclei/results/latest"
SUMMARY_FILE="$LATEST_DIR/summary.txt"

if [ -f "$SUMMARY_FILE" ]; then
    # Extract values from summary file
    hosts_scanned=$(grep "Total hosts scanned:" "$SUMMARY_FILE" | tail -1 | awk '{print $4}')
    findings=$(grep "Total vulnerabilities found:" "$SUMMARY_FILE" | tail -1 | awk '{print $4}')
    
    # Get last scan time from directory name
    if [ -L "$LATEST_DIR" ]; then
        target_dir=$(readlink "$LATEST_DIR")
        dir_name=$(basename "$target_dir")
        scan_date=$(echo "$dir_name" | grep -o "^[0-9]\{8\}-[0-9]\{6\}")
        if [ -n "$scan_date" ]; then
            # Convert YYYYMMDD-HHMMSS to ISO format
            year=${scan_date:0:4}
            month=${scan_date:4:2}
            day=${scan_date:6:2}
            hour=${scan_date:9:2}
            minute=${scan_date:11:2}
            second=${scan_date:13:2}
            scan_time="${year}-${month}-${day}T${hour}:${minute}:${second}+00:00"
        else
            scan_time=$(date -u +%Y-%m-%dT%H:%M:%S+00:00)
        fi
    else
        scan_time=$(date -u +%Y-%m-%dT%H:%M:%S+00:00)
    fi
    
    # Determine status
    if [ "$findings" -gt 0 ]; then
        status="alert"
    else
        status="idle"
    fi
    
    # Generate summary
    summary=$(cat "$SUMMARY_FILE" | head -20 | tail -10 | tr '\n' ' ' | sed 's/  / /g')
    
    # Update all entities
    echo "Updating entities with data from latest scan:"
    echo "  Status: $status"
    echo "  Findings: $findings"
    echo "  Hosts scanned: $hosts_scanned"
    echo "  Scan time: $scan_time"
    
    # Run the update
    /home/nuclei/scripts/ha-sensor-update.sh "$status" "$findings" "$hosts_scanned" "$scan_time" "$summary"
else
    echo "No scan summary found. Updating with default values."
    /home/nuclei/scripts/ha-sensor-update.sh "idle" "0" "0" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)" "No scan results available"
fi
EOF

# Make all scripts executable
chmod +x "${TEMP_DIR}"/*.sh

# Deploy scripts to NAS Docker volume
echo ""
echo "3. Deploying scripts to NAS..."
${NAS_SSH} "mkdir -p /volume2/docker/nuclei/scripts"
scp "${TEMP_DIR}"/*.sh ${NAS_USER}@${NAS_HOST}:/volume2/docker/nuclei/scripts/

# Copy scripts from NAS volume to container
echo ""
echo "4. Installing scripts in container..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner chmod +x /home/nuclei/scripts/ha-sensor-update.sh /home/nuclei/scripts/ha-scan-integration.sh /home/nuclei/scripts/update-entities-now.sh"

# Modify the scan script to include HA integration
echo ""
echo "5. Integrating with scan scripts..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/ha-scan-integration.sh"

# Update the entities with current values
echo ""
echo "6. Updating entities with current values..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/update-entities-now.sh"

# Clean up
rm -rf "${TEMP_DIR}"

echo ""
echo "=============================================================="
echo "✅ Deployment complete!"
echo ""
echo "Home Assistant integration is now using the 6-entity model:"
echo "1. sensor.nuclei_scanner - Main entity"
echo "2. sensor.nuclei_scanner_status - Current status"
echo "3. sensor.nuclei_scanner_findings - Vulnerability count"
echo "4. sensor.nuclei_scanner_hosts - Hosts scanned"
echo "5. sensor.nuclei_scanner_last_scan - Timestamp"
echo "6. sensor.nuclei_scanner_summary - Text summary"
echo ""
echo "The multi-VLAN scan script now updates these entities with real values."