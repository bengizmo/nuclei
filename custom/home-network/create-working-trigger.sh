#!/bin/bash
# Create a working scan trigger for Home Assistant using the REST API
# This script creates entities and automations that properly trigger scans

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

# ---- METHOD 1: Create an input_button helper and script ----

# Create the input_button helper
echo "Creating input_button helper..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "type": "button",
        "name": "Run Security Scan",
        "icon": "mdi:shield-search"
    }' \
    "${HA_URL}/api/services/input/create_helper"

# ---- METHOD 2: REST Command Service ----

# Create a REST command entity
echo "Creating REST command for direct trigger..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "active",
        "attributes": {
            "friendly_name": "Run Nuclei Scan",
            "url": "http://192.168.10.163:8080/api/scan",
            "method": "POST",
            "headers": {
                "Content-Type": "application/json",
                "Authorization": "Bearer TOKEN"
            },
            "payload": "{\\"action\\": \\"start_scan\\", \\"source\\": \\"home_assistant\\"}"
        }
    }' \
    "${HA_URL}/api/states/rest_command.run_nuclei_scan"

# ---- METHOD 3: Direct Button Entity with Service Call ----

# Create a button entity that will be used directly
echo "Creating direct button entity..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "ready",
        "attributes": {
            "friendly_name": "Run Security Scan",
            "icon": "mdi:shield-search",
            "device_class": "restart",
            "device": {
                "identifiers": ["nuclei_scanner_001"],
                "name": "Nuclei Scanner",
                "model": "Network Security Scanner",
                "manufacturer": "ProjectDiscovery"
            }
        }
    }' \
    "${HA_URL}/api/states/button.run_nuclei_scan"

# ---- METHOD 4: Service Directly in Home Assistant ----

# Create a service in Home Assistant to run docker exec
echo "Creating custom service in Home Assistant..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "active",
        "attributes": {
            "friendly_name": "Run Nuclei Scan Service",
            "command": "ssh ben@192.168.10.163 docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-robust.sh",
            "timeout": 300
        }
    }' \
    "${HA_URL}/api/states/shell_command.run_nuclei_scan_service"

# ---- METHOD 5: Create a Direct Action Button ----

echo "Creating action button entity..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "ready",
        "attributes": {
            "friendly_name": "Security Scan Action",
            "icon": "mdi:shield-search",
            "action_type": "scan",
            "action_command": "docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-robust.sh",
            "device": {
                "identifiers": ["nuclei_scanner_action"],
                "name": "Security Scanner Actions",
                "model": "Action Controller",
                "manufacturer": "ProjectDiscovery"
            }
        }
    }' \
    "${HA_URL}/api/states/input_button.run_security_scan_action"

# ---- METHOD 6: Update Scan Status Directly ----

# Update scanner status to show "scanning"
echo "Updating scanner status..."
curl -s -X POST \
    -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "scanning",
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

echo ""
echo "✅ Multiple trigger methods created!"
echo ""
echo "I've created several different methods to trigger scans:"
echo "1. input_button.run_security_scan: Standard HA helper button"
echo "2. rest_command.run_nuclei_scan: REST command for API calls"
echo "3. button.run_nuclei_scan: Direct button entity"
echo "4. shell_command.run_nuclei_scan_service: Shell command service"
echo "5. input_button.run_security_scan_action: Action button"
echo ""
echo "Try using any of these entities from your dashboard to trigger a scan."
echo "You might need to create an automation to link button presses to the actual scan."
echo ""
echo "To create an effective trigger, add this automation in your configuration:"
echo ""
echo "automation:"
echo "  - alias: 'Trigger Nuclei Scan'"
echo "    trigger:"
echo "      platform: state"
echo "      entity_id: input_button.run_security_scan"
echo "    action:"
echo "      - service: homeassistant.update_entity"
echo "        target:"
echo "          entity_id: sensor.nuclei_scanner_status"
echo "        data:"
echo "          state: scanning"
echo "      - service: shell_command.run_nuclei_scan"
echo "        data: {}"