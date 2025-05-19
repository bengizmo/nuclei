#!/bin/bash
# Test the simplified HA integration with actual scanner

# Load NAS configuration
source ./nas-config.sh

echo "🧪 Testing Simplified HA Integration"
echo "=================================="
echo ""

# Force a new AI summary to test the update
echo "1. Triggering AI Summary Update"
echo "------------------------------"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/generate-ai-summary.sh"
echo ""

# Check the updated entity
echo "2. Checking Updated Entity"
echo "-------------------------"
HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

sleep 3  # Give it time to update

ENTITY_DATA=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
    "$HA_URL/api/states/sensor.nuclei_scanner_summary")

echo "Current state:"
echo "$ENTITY_DATA" | jq -r '.state'
echo ""
echo "Attributes:"
echo "$ENTITY_DATA" | jq '.attributes'
echo ""

# Create a simple automation example
echo "3. Home Assistant Automation Example"
echo "-----------------------------------"
cat << 'EOF'
# Add this to your automations.yaml
- alias: "Nuclei Security Alert"
  trigger:
    - platform: state
      entity_id: sensor.nuclei_scanner_summary
  condition:
    - condition: or
      conditions:
        - condition: numeric_state
          entity_id: sensor.nuclei_scanner_summary
          attribute: critical_count
          above: 0
        - condition: numeric_state
          entity_id: sensor.nuclei_scanner_summary
          attribute: high_count
          above: 0
  action:
    - service: notify.notify
      data:
        title: "Security Alert!"
        message: "{{ states('sensor.nuclei_scanner_summary') }}"
        data:
          priority: high
          tag: security-alert
EOF

echo ""
echo "4. Dashboard Card Example"
echo "------------------------"
cat << 'EOF'
# Minimal Security Status Card
type: entity
entity: sensor.nuclei_scanner_summary
name: Network Security
icon: mdi:shield-search

# Or use a template card for more detail
type: custom:mushroom-template-card
primary: Network Security
secondary: >
  {{ states('sensor.nuclei_scanner_summary') }}
icon: mdi:shield-search
icon_color: >
  {% set critical = state_attr('sensor.nuclei_scanner_summary', 'critical_count') | int(0) %}
  {% set high = state_attr('sensor.nuclei_scanner_summary', 'high_count') | int(0) %}
  {% if critical > 0 %} red
  {% elif high > 0 %} orange
  {% else %} green
  {% endif %}
badge_icon: >
  {% set status = state_attr('sensor.nuclei_scanner_summary', 'scan_status') %}
  {% if status == 'scanning' %} mdi:refresh
  {% endif %}
badge_color: >
  {% set status = state_attr('sensor.nuclei_scanner_summary', 'scan_status') %}
  {% if status == 'scanning' %} blue
  {% endif %}
tap_action:
  action: more-info
EOF

echo ""
echo "=================================="
echo "✅ Simplified integration tested!"
echo ""
echo "The system now uses a single entity:"
echo "- sensor.nuclei_scanner_summary"
echo ""
echo "This contains:"
echo "- AI-generated security summary"
echo "- Vulnerability counts"
echo "- Scan status and timing"
echo "- Host count"
echo ""
echo "All unnecessary entities have been removed!"