#!/bin/bash
# Create scanner button directly in Home Assistant using raw API calls
# This approach creates entities without modifying configuration.yaml

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

# Create the button entity directly
echo "Creating button.run_security_scan entity..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "press",
        "attributes": {
            "friendly_name": "Run Network Security Scan",
            "icon": "mdi:shield-search",
            "device_class": "button",
            "device": {
                "identifiers": ["nuclei_scanner_001"],
                "name": "Nuclei Scanner",
                "model": "Network Security Scanner",
                "manufacturer": "ProjectDiscovery",
                "suggested_area": "Network"
            }
        }
    }' \
    "${HA_URL}/api/states/button.run_security_scan"

# Create the button handler service
echo "Creating service to handle button press..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "domain": "automation",
        "service": "trigger",
        "service_data": {
            "entity_id": "automation.trigger_security_scan"
        }
    }' \
    "${HA_URL}/api/services/button/press"

# Create the automation for button press
echo "Creating automation to handle button press..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "on",
        "attributes": {
            "friendly_name": "Trigger Security Scan",
            "last_triggered": null,
            "mode": "single",
            "trigger": [{
                "platform": "event",
                "event_type": "call_service",
                "event_data": {
                    "domain": "button",
                    "service": "press",
                    "service_data": {
                        "entity_id": "button.run_security_scan"
                    }
                }
            }],
            "action": [
                {
                    "service": "homeassistant.update_entity",
                    "data": {
                        "entity_id": "sensor.nuclei_scanner_status"
                    },
                    "target": {
                        "entity_id": "sensor.nuclei_scanner_status"
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
            ]
        }
    }' \
    "${HA_URL}/api/states/automation.trigger_security_scan"

# Create shell command service
echo "Creating shell command to run scan..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "command": "docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-robust.sh"
    }' \
    "${HA_URL}/api/services/shell_command/reload"

echo ""
echo "✅ Home Assistant entities created!"
echo ""
echo "The following entities have been created:"
echo "- button.run_security_scan: Button entity to trigger scans"
echo "- automation.trigger_security_scan: Automation that handles button presses"
echo "- shell_command.run_nuclei_scan: Command to execute the scan"
echo ""
echo "You can now add the button.run_security_scan entity to your dashboard."
echo "Press the button to trigger a network security scan."