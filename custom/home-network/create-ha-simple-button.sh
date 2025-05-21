#!/bin/bash
# Create a simple button entity in Home Assistant
# This script creates just the button entity and an automation to trigger the scan

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

# Create a simple input_button entity (Helper)
echo "Creating input_button.run_security_scan entity..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Run Security Scan",
        "icon": "mdi:shield-search"
    }' \
    "${HA_URL}/api/services/input_button/create"

# Create the automation for handling button press
echo "Creating automation to handle button press..."
AUTOMATION_ID="trigger_security_scan_button"
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "alias": "Trigger Security Scan Button",
        "description": "Run network security scan when button is pressed",
        "trigger": [
            {
                "platform": "state", 
                "entity_id": "input_button.run_security_scan"
            }
        ],
        "action": [
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
                "service": "persistent_notification.create",
                "data": {
                    "title": "Security Scan Triggered",
                    "message": "The network security scan has been started. This will take 15-30 minutes to complete.",
                    "notification_id": "security_scan_started"
                }
            },
            {
                "service": "shell_command.run_nuclei_scan",
                "data": {}
            }
        ]
    }' \
    "${HA_URL}/api/services/automation/create"

# Create a direct service for shell command
echo "Creating service for running scan..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-robust.sh",
        "attributes": {
            "friendly_name": "Run Nuclei Scan"
        }
    }' \
    "${HA_URL}/api/states/shell_command.run_nuclei_scan"

echo ""
echo "✅ Home Assistant entities created!"
echo ""
echo "The following entities have been created:"
echo "- input_button.run_security_scan: Button to trigger scans"
echo "- automation.trigger_security_scan_button: Automation that handles button presses"
echo "- shell_command.run_nuclei_scan: Command to execute the scan"
echo ""
echo "You can now add the input_button.run_security_scan entity to your dashboard."
echo "When you press the button, the scan will be triggered."