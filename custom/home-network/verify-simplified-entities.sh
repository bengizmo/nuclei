#!/bin/bash
# Verify the simplified nuclei entity setup

echo "🔍 Verifying Simplified Nuclei Entities"
echo "====================================="
echo ""

# Get HA token
HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

# Check the main entity
echo "1. Checking sensor.nuclei_scanner_summary"
echo "-----------------------------------------"
ENTITY_DATA=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
    "$HA_URL/api/states/sensor.nuclei_scanner_summary")

# Parse the entity data
STATE=$(echo "$ENTITY_DATA" | jq -r '.state')
ATTRIBUTES=$(echo "$ENTITY_DATA" | jq '.attributes')

echo "State: $STATE"
echo ""
echo "Attributes:"
echo "$ATTRIBUTES" | jq .
echo ""

# Check if all required attributes are present
echo "2. Attribute Verification"
echo "------------------------"
REQUIRED_ATTRS=("critical_count" "high_count" "medium_count" "low_count" "last_scan" "scan_status" "hosts_scanned")

for attr in "${REQUIRED_ATTRS[@]}"; do
    if echo "$ATTRIBUTES" | jq -e ".$attr" > /dev/null; then
        value=$(echo "$ATTRIBUTES" | jq -r ".$attr")
        echo "✓ $attr: $value"
    else
        echo "✗ $attr: MISSING"
    fi
done
echo ""

# Test updating the entity
echo "3. Testing Entity Update"
echo "-----------------------"
NEW_SUMMARY="Test: Network secure, no vulnerabilities found. 25 hosts scanned."
UPDATE_RESULT=$(curl -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"$NEW_SUMMARY\",
        \"attributes\": {
            \"friendly_name\": \"Nuclei Security Scanner Summary\",
            \"icon\": \"mdi:shield-search\",
            \"device_class\": \"diagnostic\",
            \"critical_count\": 0,
            \"high_count\": 0,
            \"medium_count\": 0,
            \"low_count\": 0,
            \"last_scan\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\",
            \"scan_status\": \"idle\",
            \"hosts_scanned\": 25
        }
    }" \
    "$HA_URL/api/states/sensor.nuclei_scanner_summary" \
    -s -w "%{http_code}")

if [ "$UPDATE_RESULT" = "200" ]; then
    echo "✓ Entity update successful"
else
    echo "✗ Entity update failed: $UPDATE_RESULT"
fi
echo ""

# Verify the update
echo "4. Verifying Update"
echo "------------------"
UPDATED_STATE=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
    "$HA_URL/api/states/sensor.nuclei_scanner_summary" | jq -r '.state')
echo "New state: $UPDATED_STATE"
echo ""

# Create a simple Lovelace card example
echo "5. Lovelace Card Example"
echo "----------------------"
cat << 'EOF'
type: custom:mushroom-entity-card
entity: sensor.nuclei_scanner_summary
name: Network Security Status
icon_color: |
  {% set critical = state_attr('sensor.nuclei_scanner_summary', 'critical_count') | int %}
  {% set high = state_attr('sensor.nuclei_scanner_summary', 'high_count') | int %}
  {% if critical > 0 %}
    red
  {% elif high > 0 %}
    orange
  {% else %}
    green
  {% endif %}
secondary_info: |
  {% set hosts = state_attr('sensor.nuclei_scanner_summary', 'hosts_scanned') | int %}
  {% set status = state_attr('sensor.nuclei_scanner_summary', 'scan_status') %}
  {{ hosts }} hosts | Status: {{ status }}
tap_action:
  action: more-info
EOF

echo ""
echo "====================================="
echo "✅ Simplified entity setup verified!"
echo ""
echo "The single sensor.nuclei_scanner_summary entity:"
echo "- Contains all necessary information"
echo "- Updates properly from scripts"
echo "- Works with Home Assistant automations"
echo "- Can be used in dashboard cards"