#!/bin/bash
# Restore the previous 6-entity model for Home Assistant integration

echo "🔄 Restoring Multiple Entity Model for Home Assistant"
echo "==================================================="
echo ""

# Get HA token
HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

# Check current status
echo "1. Checking current entities..."
EXISTING=$(curl -s -H "Authorization: Bearer $HA_TOKEN" $HA_URL/api/states | \
    jq -r '.[] | select(.entity_id | contains("nuclei")) | .entity_id' | sort)

echo "Found entities:"
echo "$EXISTING" | sed 's/^/  /'
echo ""

# Define the 6 entities we need
declare -A REQUIRED_ENTITIES=(
    ["sensor.nuclei_scanner"]="Main aggregated sensor"
    ["sensor.nuclei_scanner_status"]="Current scan status (idle/scanning/alert)"
    ["sensor.nuclei_scanner_findings"]="Count of vulnerabilities found"
    ["sensor.nuclei_scanner_hosts"]="Number of hosts scanned"
    ["sensor.nuclei_scanner_last_scan"]="Timestamp of last completed scan"
    ["sensor.nuclei_scanner_summary"]="AI-generated summary of scan results"
)

echo "2. Creating/updating 6 entity model..."

# Update the main scanner entity
echo "Creating main sensor.nuclei_scanner entity..."
curl -s -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "idle",
        "attributes": {
            "friendly_name": "Nuclei Scanner",
            "icon": "mdi:shield-search",
            "status": "idle",
            "findings": 0,
            "hosts_scanned": 0,
            "last_scan": "'"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"'",
            "device": {
                "identifiers": ["nuclei_scanner_001"],
                "name": "Nuclei Scanner",
                "model": "Network Vulnerability Scanner",
                "manufacturer": "ProjectDiscovery",
                "sw_version": "3.4.2",
                "configuration_url": "http://192.168.10.163:9090"
            }
        }
    }' \
    "$HA_URL/api/states/sensor.nuclei_scanner" \
    -o /dev/null -w "  %{http_code}\n"

# Update the scanner status entity
echo "Creating sensor.nuclei_scanner_status entity..."
curl -s -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "idle",
        "attributes": {
            "friendly_name": "Nuclei Scanner Status",
            "icon": "mdi:shield-check",
            "device_class": "enum",
            "options": ["idle", "scanning", "alert"],
            "device": {
                "identifiers": ["nuclei_scanner_001"],
                "name": "Nuclei Scanner",
                "model": "Network Vulnerability Scanner",
                "manufacturer": "ProjectDiscovery",
                "sw_version": "3.4.2"
            }
        }
    }' \
    "$HA_URL/api/states/sensor.nuclei_scanner_status" \
    -o /dev/null -w "  %{http_code}\n"

# Update the findings entity
echo "Creating sensor.nuclei_scanner_findings entity..."
curl -s -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "0",
        "attributes": {
            "friendly_name": "Vulnerabilities Found",
            "icon": "mdi:bug",
            "device_class": "measurement",
            "device": {
                "identifiers": ["nuclei_scanner_001"],
                "name": "Nuclei Scanner",
                "model": "Network Vulnerability Scanner",
                "manufacturer": "ProjectDiscovery",
                "sw_version": "3.4.2"
            }
        }
    }' \
    "$HA_URL/api/states/sensor.nuclei_scanner_findings" \
    -o /dev/null -w "  %{http_code}\n"

# Update the hosts scanned entity
echo "Creating sensor.nuclei_scanner_hosts entity..."
curl -s -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "0",
        "attributes": {
            "friendly_name": "Hosts Scanned",
            "icon": "mdi:server-network",
            "device_class": "measurement",
            "device": {
                "identifiers": ["nuclei_scanner_001"],
                "name": "Nuclei Scanner",
                "model": "Network Vulnerability Scanner",
                "manufacturer": "ProjectDiscovery",
                "sw_version": "3.4.2"
            }
        }
    }' \
    "$HA_URL/api/states/sensor.nuclei_scanner_hosts" \
    -o /dev/null -w "  %{http_code}\n"

# Update the last scan entity
echo "Creating sensor.nuclei_scanner_last_scan entity..."
CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%S+00:00)
curl -s -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "'"$CURRENT_TIME"'",
        "attributes": {
            "friendly_name": "Last Scan Time",
            "icon": "mdi:clock-outline",
            "device_class": "timestamp",
            "device": {
                "identifiers": ["nuclei_scanner_001"],
                "name": "Nuclei Scanner",
                "model": "Network Vulnerability Scanner",
                "manufacturer": "ProjectDiscovery",
                "sw_version": "3.4.2"
            }
        }
    }' \
    "$HA_URL/api/states/sensor.nuclei_scanner_last_scan" \
    -o /dev/null -w "  %{http_code}\n"

# Update the summary entity with initialization message
echo "Creating sensor.nuclei_scanner_summary entity..."
curl -s -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "Scanner initialized with multi-entity model",
        "attributes": {
            "friendly_name": "Nuclei Scanner Summary",
            "icon": "mdi:shield-search",
            "device_class": "diagnostic",
            "device": {
                "identifiers": ["nuclei_scanner_001"],
                "name": "Nuclei Scanner",
                "model": "Network Vulnerability Scanner",
                "manufacturer": "ProjectDiscovery",
                "sw_version": "3.4.2"
            }
        }
    }' \
    "$HA_URL/api/states/sensor.nuclei_scanner_summary" \
    -o /dev/null -w "  %{http_code}\n"

echo ""
echo "3. Verifying entities..."
UPDATED_ENTITIES=$(curl -s -H "Authorization: Bearer $HA_TOKEN" $HA_URL/api/states | \
    jq -r '.[] | select(.entity_id | contains("nuclei")) | .entity_id' | sort)

echo "Current entities in Home Assistant:"
echo "$UPDATED_ENTITIES" | sed 's/^/  /'

# Check if all required entities exist
all_exist=true
for entity in "${!REQUIRED_ENTITIES[@]}"; do
    if ! echo "$UPDATED_ENTITIES" | grep -q "^$entity$"; then
        echo "❌ Missing: $entity"
        all_exist=false
    fi
done

echo ""
if [ "$all_exist" = true ]; then
    echo "✅ All required entities created successfully"
else
    echo "⚠️ Some entities are missing"
fi

echo ""
echo "4. Modifying scan-with-ha.sh script to use multiple entities..."

# Create a backup of the original file
cp /Users/ben/dev/nuclei/custom/home-network/scripts/scan-with-ha.sh /Users/ben/dev/nuclei/custom/home-network/scripts/scan-with-ha.sh.bak

# Update the scan-with-ha.sh script to use ha-sensor-update.sh instead of generate-ai-summary.sh
cat > /Users/ben/dev/nuclei/custom/home-network/scripts/scan-with-ha-multi.sh << 'EOF'
#!/bin/bash
# Enhanced scan script that updates all 6 Home Assistant entities

echo "🔍 Running Nuclei scan with multi-entity Home Assistant integration"
echo "=================================================================="

# Configuration
export RESULTS_DIR="/home/nuclei/results/$(date +'%Y%m%d-%H%M%S')"
CRITICAL_HOSTS_FILE="/home/nuclei/critical-hosts.txt"
HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"

# Create results directory
mkdir -p "${RESULTS_DIR}"

# Update HA to show we're scanning
/home/nuclei/scripts/ha-sensor-update.sh "scanning" "0" "0" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"

echo "Scanning hosts from: ${CRITICAL_HOSTS_FILE}"
echo "Results will be saved to: ${RESULTS_DIR}"

# Count hosts for progress tracking
HOST_COUNT=$(grep -v "^#" "${CRITICAL_HOSTS_FILE}" | wc -l)
echo "Found ${HOST_COUNT} hosts to scan..."

# Initialize counters
FINDINGS_COUNT=0
HOSTS_SCANNED=0

# Scan each host
while read -r target; do
    # Skip comments and empty lines
    if [[ "$target" == \#* ]] || [[ -z "$target" ]]; then
        continue
    fi
    
    # Extract hostname/IP and description if available
    host_info=(${target//,/ })
    host="${host_info[0]}"
    
    echo "Scanning host: ${host}"
    nuclei -u "${host}" -o "${RESULTS_DIR}/${host}.txt" -j "${RESULTS_DIR}/${host}.json" -silent
    
    # Count vulnerabilities
    if [ -f "${RESULTS_DIR}/${host}.json" ]; then
        vuln_count=$(cat "${RESULTS_DIR}/${host}.json" | wc -l)
        FINDINGS_COUNT=$((FINDINGS_COUNT + vuln_count))
    fi
    
    HOSTS_SCANNED=$((HOSTS_SCANNED + 1))
    
    # Update Home Assistant with progress
    /home/nuclei/scripts/ha-sensor-update.sh "scanning" "${FINDINGS_COUNT}" "${HOSTS_SCANNED}" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"
done < "${CRITICAL_HOSTS_FILE}"

# Create symlink to latest results
ln -sfn "${RESULTS_DIR}" /home/nuclei/results/latest

# Generate AI summary if helper script exists
if [ -x "/home/nuclei/scripts/generate-ai-summary.sh" ]; then
    /home/nuclei/scripts/generate-ai-summary.sh "${RESULTS_DIR}"
fi

# Set final status based on findings
if [ "${FINDINGS_COUNT}" -gt 0 ]; then
    STATUS="alert"
else
    STATUS="idle"
fi

# Update Home Assistant with final results
/home/nuclei/scripts/ha-sensor-update.sh "${STATUS}" "${FINDINGS_COUNT}" "${HOSTS_SCANNED}" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"

echo "Scan complete!"
echo "Scanned ${HOSTS_SCANNED} hosts and found ${FINDINGS_COUNT} vulnerabilities."
echo "Results saved to: ${RESULTS_DIR}"
echo "Home Assistant entities updated with scanner state: ${STATUS}"
EOF

# Make the script executable
chmod +x /Users/ben/dev/nuclei/custom/home-network/scripts/scan-with-ha-multi.sh

echo "✅ Created scan-with-ha-multi.sh script with multiple entity updates"

echo ""
echo "==================================================="
echo "Done! The Nuclei scanner now uses 6 separate entities:"
for entity in "${!REQUIRED_ENTITIES[@]}"; do
    description="${REQUIRED_ENTITIES[$entity]}"
    echo "- $entity: $description"
done
echo ""
echo "To test the integration, run: ./scripts/scan-with-ha-multi.sh"
echo "To see entity status, run: ./scripts/check-sensors.sh"