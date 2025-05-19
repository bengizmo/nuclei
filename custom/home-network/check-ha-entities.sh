#!/bin/bash
# Check all nuclei entities in Home Assistant

echo "🏠 Checking Nuclei Entities in Home Assistant"
echo "==========================================="
echo ""

# Get HA token
HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

# Get all nuclei entities
echo "All nuclei-related entities:"
echo ""
curl -s -H "Authorization: Bearer $HA_TOKEN" \
    $HA_URL/api/states | \
    jq -r '.[] | select(.entity_id | contains("nuclei")) | .entity_id' | \
    sort

echo ""
echo "Grouped by type:"
echo ""
echo "Input helpers:"
curl -s -H "Authorization: Bearer $HA_TOKEN" \
    $HA_URL/api/states | \
    jq -r '.[] | select(.entity_id | startswith("input") and (.entity_id | contains("nuclei"))) | .entity_id' | \
    sort

echo ""
echo "Sensors:"
curl -s -H "Authorization: Bearer $HA_TOKEN" \
    $HA_URL/api/states | \
    jq -r '.[] | select(.entity_id | startswith("sensor.nuclei")) | .entity_id' | \
    sort

echo ""
echo "Binary sensors:"
curl -s -H "Authorization: Bearer $HA_TOKEN" \
    $HA_URL/api/states | \
    jq -r '.[] | select(.entity_id | startswith("binary_sensor.nuclei")) | .entity_id' | \
    sort

echo ""
echo "Switches:"
curl -s -H "Authorization: Bearer $HA_TOKEN" \
    $HA_URL/api/states | \
    jq -r '.[] | select(.entity_id | startswith("switch.nuclei")) | .entity_id' | \
    sort

echo ""
echo "Scripts:"
curl -s -H "Authorization: Bearer $HA_TOKEN" \
    $HA_URL/api/states | \
    jq -r '.[] | select(.entity_id | startswith("script") and (.entity_id | contains("nuclei"))) | .entity_id' | \
    sort

echo ""
echo "Automations:"
curl -s -H "Authorization: Bearer $HA_TOKEN" \
    $HA_URL/api/states | \
    jq -r '.[] | select(.entity_id | startswith("automation") and (.entity_id | contains("nuclei"))) | .entity_id' | \
    sort

echo ""
echo "==========================================="
echo "Total nuclei entities: $(curl -s -H "Authorization: Bearer $HA_TOKEN" $HA_URL/api/states | jq -r '.[] | select(.entity_id | contains("nuclei")) | .entity_id' | wc -l)"
echo ""
echo "Based on the system design, we should keep:"
echo "- sensor.nuclei_scanner_summary (AI summary)"
echo "- sensor.nuclei_scanner_status (scan status)"
echo "- Webhook automation for receiving alerts"
echo ""
echo "All other entities can be removed"