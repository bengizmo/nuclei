#!/bin/bash
# Update Nuclei Scanner entities in Home Assistant
# This script uses direct API calls to create/update the entities

# Load environment for HA token
cd "$(dirname "$0")"
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

# Create a scan button using REST controls
echo "Creating button for manual scanning..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "run_scan",
        "attributes": {
            "friendly_name": "Run Security Scan",
            "icon": "mdi:shield-search",
            "entity_picture": "/local/icons/shield-scan.png",
            "command_on": "docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-robust.sh",
            "entity_id": "switch.run_security_scan"
        }
    }' \
    "${HA_URL}/api/states/switch.run_security_scan"

# Create a master toggle for enabling/disabling automated scanning
echo "Creating scan master switch..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "on",
        "attributes": {
            "friendly_name": "Automated Security Scans",
            "icon": "mdi:shield-check",
            "device": {
                "identifiers": ["nuclei_scanner_001"],
                "name": "Nuclei Scanner"
            }
        }
    }' \
    "${HA_URL}/api/states/input_boolean.automated_security_scans"

# Create a scan status indicator
echo "Updating scanner status indicator..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "idle",
        "attributes": {
            "friendly_name": "Scanner Status",
            "icon": "mdi:shield-search",
            "device": {
                "identifiers": ["nuclei_scanner_001"],
                "name": "Nuclei Scanner"
            }
        }
    }' \
    "${HA_URL}/api/states/sensor.nuclei_scanner_status"

# Add a timestamp for last successful scan
echo "Updating last scan time..."
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

echo ""
echo "✅ Home Assistant entities updated!"
echo ""
echo "The following entities have been created/updated:"
echo "- switch.run_security_scan: Switch to manually trigger a scan"
echo "- input_boolean.automated_security_scans: Master toggle for automated scans"
echo "- sensor.nuclei_scanner_status: Current scanner status"
echo "- sensor.nuclei_scanner_last_scan: Timestamp of last scan"
echo ""
echo "You can now add these entities to your dashboard."
echo "To trigger a scan, add the switch.run_security_scan to your dashboard."