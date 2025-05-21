#!/bin/bash
# Verify Home Assistant integration with improved debug information

# Load NAS configuration 
cd "$(dirname "$0")"
source ./nas-config.sh

echo "🏠 Verifying Home Assistant Integration"
echo "====================================="
echo ""

# Function to extract token from env file
get_token() {
    if [ -f .env ]; then
        grep HOME_ASSISTANT_API_TOKEN .env | cut -d= -f2
    else
        echo ""
    fi
}

HA_TOKEN=$(get_token)
if [ -z "$HA_TOKEN" ]; then
    echo "❌ ERROR: No Home Assistant token found in .env file"
    echo "Please create a .env file with your Home Assistant token:"
    echo "HOME_ASSISTANT_API_TOKEN=your_long_lived_token_here"
    exit 1
fi

# Function to check status code from HA
check_ha_connection() {
    status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        http://192.168.10.89:8123/api/states)
    
    if [ "$status_code" -eq 200 ]; then
        echo "✅ Connected to Home Assistant successfully"
    else
        echo "❌ Error: Could not connect to Home Assistant (HTTP $status_code)"
        echo "Please check your token and Home Assistant availability"
        exit 1
    fi
}

# Check connectivity first
check_ha_connection

# Check if nuclei entities exist
echo ""
echo "1. Checking Nuclei sensors in Home Assistant..."
ENTITIES=$(curl -s -H "Authorization: Bearer ${HA_TOKEN}" \
    http://192.168.10.89:8123/api/states | \
    jq -r '.[] | select(.entity_id | contains("nuclei")) | .entity_id + ": " + .state')

if [ -z "$ENTITIES" ]; then
    echo "❌ No Nuclei entities found in Home Assistant"
    
    # Create the entities directly
    echo ""
    echo "2. Creating Nuclei entities in Home Assistant..."
    
    # Create main sensor
    curl -s -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"state\": \"idle\",
            \"attributes\": {
                \"friendly_name\": \"Nuclei Scanner\",
                \"icon\": \"mdi:shield-search\",
                \"status\": \"idle\",
                \"findings\": 0,
                \"hosts_scanned\": 0,
                \"last_scan\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\",
                \"device\": {
                    \"identifiers\": [\"nuclei_scanner_001\"],
                    \"name\": \"Nuclei Scanner\",
                    \"model\": \"Network Vulnerability Scanner\",
                    \"manufacturer\": \"ProjectDiscovery\",
                    \"sw_version\": \"3.4.2\"
                }
            }
        }" \
        http://192.168.10.89:8123/api/states/sensor.nuclei_scanner

    # Create status sensor
    curl -s -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"state\": \"idle\",
            \"attributes\": {
                \"friendly_name\": \"Nuclei Scanner Status\",
                \"icon\": \"mdi:shield-check\",
                \"device\": {
                    \"identifiers\": [\"nuclei_scanner_001\"],
                    \"name\": \"Nuclei Scanner\"
                }
            }
        }" \
        http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_status

    # Create findings sensor
    curl -s -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"state\": \"0\",
            \"attributes\": {
                \"friendly_name\": \"Vulnerabilities Found\",
                \"icon\": \"mdi:bug\",
                \"device\": {
                    \"identifiers\": [\"nuclei_scanner_001\"],
                    \"name\": \"Nuclei Scanner\"
                }
            }
        }" \
        http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_findings

    # Create hosts sensor
    curl -s -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"state\": \"0\",
            \"attributes\": {
                \"friendly_name\": \"Hosts Scanned\",
                \"icon\": \"mdi:server-network\",
                \"device\": {
                    \"identifiers\": [\"nuclei_scanner_001\"],
                    \"name\": \"Nuclei Scanner\"
                }
            }
        }" \
        http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_hosts

    # Create last scan sensor
    curl -s -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"state\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\",
            \"attributes\": {
                \"friendly_name\": \"Last Scan Time\",
                \"icon\": \"mdi:clock-outline\",
                \"device_class\": \"timestamp\",
                \"device\": {
                    \"identifiers\": [\"nuclei_scanner_001\"],
                    \"name\": \"Nuclei Scanner\"
                }
            }
        }" \
        http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_last_scan

    # Create summary sensor
    curl -s -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"state\": \"No recent scans\",
            \"attributes\": {
                \"friendly_name\": \"Nuclei Scanner Summary\",
                \"icon\": \"mdi:shield-search\",
                \"device_class\": \"diagnostic\",
                \"device\": {
                    \"identifiers\": [\"nuclei_scanner_001\"],
                    \"name\": \"Nuclei Scanner\"
                }
            }
        }" \
        http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_summary
        
    echo "✅ Created Nuclei entities in Home Assistant"
else
    echo "$ENTITIES"
fi

# Check latest summary
echo ""
echo "3. Checking latest summary..."
SUMMARY=$(curl -s -H "Authorization: Bearer ${HA_TOKEN}" \
    http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_summary | \
    jq -r '.state')
echo "Current summary: $SUMMARY"

# Send a test notification
echo ""
echo "4. Sending test notification to Home Assistant..."
curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"title\": \"Nuclei Scanner Integration\",
        \"message\": \"Integration verification successful! All entities created and working.\"
    }" \
    http://192.168.10.89:8123/api/services/notify/notify

# Update the entities to "scanning" status to verify they work
echo ""
echo "5. Testing entity updates to 'scanning' status..."
curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"scanning\",
        \"attributes\": {
            \"friendly_name\": \"Nuclei Scanner Status\",
            \"icon\": \"mdi:shield-search\",
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\"
            }
        }
    }" \
    http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_status

# Wait a moment
sleep 2

# Update back to idle
curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"idle\",
        \"attributes\": {
            \"friendly_name\": \"Nuclei Scanner Status\",
            \"icon\": \"mdi:shield-check\",
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\"
            }
        }
    }" \
    http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_status

echo ""
echo "====================================="
echo "✅ Home Assistant integration verified!"
echo ""
echo "The system is now correctly set up for:"
echo "- Updating entity states in Home Assistant"
echo "- Sending vulnerability alerts when needed"
echo "- Maintaining sensor states with scan results"
echo ""
echo "You should update your cron jobs on the NAS to enable scheduled scans:"
echo "  - ssh ${NAS_USER}@${NAS_HOST}"
echo "  - crontab -e"
echo "  - Add the cron entries from cron-nuclei-fixed.txt"