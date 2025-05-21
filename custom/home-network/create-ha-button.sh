#!/bin/bash
# Create button entity directly in Home Assistant using the API
# This avoids the need to modify configuration.yaml

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

# Function to create or update a script entity
create_script() {
    local script_id="$1"
    local script_name="$2"
    local script_icon="$3"
    local script_seq="$4"
    
    echo "Creating script.${script_id}..."
    
    curl -s -X POST \
        -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"alias\": \"${script_name}\",
            \"icon\": \"${script_icon}\",
            \"sequence\": ${script_seq}
        }" \
        "${HA_URL}/api/services/script/reload"
        
    # Create the script file in Home Assistant config
    curl -s -X POST \
        -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"script\": {
                \"${script_id}\": {
                    \"alias\": \"${script_name}\",
                    \"icon\": \"${script_icon}\",
                    \"sequence\": ${script_seq}
                }
            }
        }" \
        "${HA_URL}/api/config/script/config/${script_id}"
}

# Function to create a button entity
create_button() {
    local button_id="$1"
    local button_name="$2"
    local button_icon="$3"
    
    echo "Creating input_button.${button_id}..."
    
    curl -s -X POST \
        -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"${button_name}\",
            \"icon\": \"${button_icon}\"
        }" \
        "${HA_URL}/api/services/input_button/create"
}

# Create the run_security_scan script
SCRIPT_SEQ='[
    {
        "service": "homeassistant.update_entity",
        "target": {
            "entity_id": "sensor.nuclei_scanner_status"
        },
        "data": {
            "state": "scanning"
        }
    },
    {
        "service": "shell_command.run_nuclei_scan",
        "data": {}
    },
    {
        "service": "persistent_notification.create",
        "data": {
            "title": "Security Scan Triggered",
            "message": "The network security scan has been started. You will be notified when it completes.",
            "notification_id": "security_scan_started"
        }
    }
]'

# Create shell_command entity
echo "Creating shell_command entity..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "run_nuclei_scan": "docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-robust.sh"
    }' \
    "${HA_URL}/api/services/shell_command/reload"

# Create the script 
create_script "run_security_scan" "Run Security Scan" "mdi:shield-search" "$SCRIPT_SEQ"

# Create the button entity
create_button "run_security_scan" "Run Network Security Scan" "mdi:shield-search"

echo ""
echo "✅ Home Assistant entities created!"
echo ""
echo "The following entities have been created:"
echo "- input_button.run_security_scan: A button to trigger the scan"
echo "- script.run_security_scan: Script that runs the scan and shows notifications"
echo "- shell_command.run_nuclei_scan: Command that executes the actual scan"
echo ""
echo "You can now add these entities to your dashboard."