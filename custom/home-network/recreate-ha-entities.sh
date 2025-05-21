#!/bin/bash
# Recreate all Nuclei scanner entities in Home Assistant
# This script will restore entities if they've become unknown

# Load environment for HA token
cd "$(dirname "$0")"
source ./nas-config.sh
if [ -f .env ]; then
    source .env
fi

# Get token if not already set
if [ -z "$HOME_ASSISTANT_API_TOKEN" ]; then
    echo "ℹ️ No Home Assistant token found in environment"
    echo "Enter your Home Assistant long-lived access token:"
    read -s HOME_ASSISTANT_API_TOKEN
    echo
fi

# Configuration
HA_URL="http://192.168.10.89:8123"

# Check if token works
echo "🔄 Checking Home Assistant API connectivity..."
status_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "${HA_URL}/api/")

if [ "$status_code" -ne 200 ]; then
    echo "❌ ERROR: Could not connect to Home Assistant API (HTTP $status_code)"
    echo "Please check your token and Home Assistant availability"
    exit 1
fi

echo "✅ Connected to Home Assistant API"
echo "Recreating all Nuclei scanner entities..."

# Create main scanner entity
echo "1. Creating main scanner entity..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
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
    "${HA_URL}/api/states/sensor.nuclei_scanner"

# Create status sensor
echo "2. Creating status entity..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"idle\",
        \"attributes\": {
            \"friendly_name\": \"Scanner Status\",
            \"icon\": \"mdi:shield-check\",
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\"
            }
        }
    }" \
    "${HA_URL}/api/states/sensor.nuclei_scanner_status"

# Create findings sensor
echo "3. Creating findings entity..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
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
    "${HA_URL}/api/states/sensor.nuclei_scanner_findings"

# Create hosts sensor
echo "4. Creating hosts entity..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
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
    "${HA_URL}/api/states/sensor.nuclei_scanner_hosts"

# Create last scan sensor
echo "5. Creating last scan entity..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
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
    "${HA_URL}/api/states/sensor.nuclei_scanner_last_scan"

# Create summary sensor
echo "6. Creating summary entity..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"No recent scans\",
        \"attributes\": {
            \"friendly_name\": \"Scanner Summary\",
            \"icon\": \"mdi:shield-search\",
            \"device_class\": \"diagnostic\",
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\"
            }
        }
    }" \
    "${HA_URL}/api/states/sensor.nuclei_scanner_summary"

# Create button entity
echo "7. Creating button entity..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"ready\",
        \"attributes\": {
            \"friendly_name\": \"Run Security Scan\",
            \"icon\": \"mdi:shield-search\",
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\"
            }
        }
    }" \
    "${HA_URL}/api/states/button.run_security_scan"

echo "✅ All entities recreated successfully!"
echo ""
echo "You should now see all the Nuclei scanner entities in Home Assistant."
echo "If they are still showing as unknown after a few seconds, try restarting Home Assistant."