#!/bin/bash
# Manage Home Assistant entities for Nuclei scanner

echo "🏠 Managing Nuclei Entities in Home Assistant"
echo "==========================================="
echo ""

# Get HA token
HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

# Define the required entities and their purposes
declare -A REQUIRED_ENTITIES=(
    ["sensor.nuclei_scanner_summary"]="AI-generated summary of scan results"
    ["sensor.nuclei_scanner_status"]="Current scan status (scanning/idle/alert)"
    ["sensor.nuclei_vulnerabilities"]="Vulnerability counts by severity"
    ["sensor.nuclei_last_scan"]="Timestamp of last completed scan"
)

echo "1. Current Status"
echo "================"
echo "Checking existing entities..."
EXISTING=$(curl -s -H "Authorization: Bearer $HA_TOKEN" $HA_URL/api/states | \
    jq -r '.[] | select(.entity_id | contains("nuclei")) | .entity_id' | sort)

echo "Found $(echo "$EXISTING" | wc -l) nuclei entities"
echo ""

echo "2. Entity Analysis"
echo "================="
echo "Required entities:"
for entity in "${!REQUIRED_ENTITIES[@]}"; do
    desc="${REQUIRED_ENTITIES[$entity]}"
    if echo "$EXISTING" | grep -q "^$entity$"; then
        echo "  ✓ $entity - $desc"
    else
        echo "  ✗ $entity - $desc (MISSING)"
    fi
done
echo ""

echo "Unnecessary entities to remove:"
while read -r entity; do
    if [[ -z "$entity" ]]; then continue; fi
    
    is_required=false
    for req_entity in "${!REQUIRED_ENTITIES[@]}"; do
        if [[ "$entity" == "$req_entity" ]]; then
            is_required=true
            break
        fi
    done
    
    if [ "$is_required" = false ]; then
        echo "  - $entity"
    fi
done <<< "$EXISTING"
echo ""

echo "3. Cleanup Actions"
echo "================="
read -p "Remove unnecessary entities? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing unnecessary entities..."
    while read -r entity; do
        if [[ -z "$entity" ]]; then continue; fi
        
        is_required=false
        for req_entity in "${!REQUIRED_ENTITIES[@]}"; do
            if [[ "$entity" == "$req_entity" ]]; then
                is_required=true
                break
            fi
        done
        
        if [ "$is_required" = false ]; then
            echo "  Removing: $entity"
            curl -X DELETE \
                -H "Authorization: Bearer $HA_TOKEN" \
                "$HA_URL/api/states/$entity" \
                -s -o /dev/null
        fi
    done <<< "$EXISTING"
    echo "✅ Cleanup complete"
else
    echo "⏭️ Skipping cleanup"
fi
echo ""

echo "4. Entity Updates"
echo "================"
echo "Updating required entities with current data..."

# Update main summary sensor
curl -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "System initialized",
        "attributes": {
            "friendly_name": "Nuclei Scanner Summary",
            "icon": "mdi:shield-search",
            "device_class": "diagnostic"
        }
    }' \
    "$HA_URL/api/states/sensor.nuclei_scanner_summary" \
    -s -o /dev/null
echo "✓ Updated sensor.nuclei_scanner_summary"

# Update status sensor
curl -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "idle",
        "attributes": {
            "friendly_name": "Nuclei Scanner Status",
            "icon": "mdi:shield-check",
            "device_class": "enum",
            "options": ["idle", "scanning", "alert"]
        }
    }' \
    "$HA_URL/api/states/sensor.nuclei_scanner_status" \
    -s -o /dev/null
echo "✓ Updated sensor.nuclei_scanner_status"

# Update vulnerabilities sensor
curl -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "state": "0",
        "attributes": {
            "friendly_name": "Nuclei Vulnerabilities",
            "icon": "mdi:bug",
            "device_class": "measurement",
            "critical": 0,
            "high": 0,
            "medium": 0,
            "low": 0,
            "unit_of_measurement": "vulnerabilities"
        }
    }' \
    "$HA_URL/api/states/sensor.nuclei_vulnerabilities" \
    -s -o /dev/null
echo "✓ Updated sensor.nuclei_vulnerabilities"

# Update last scan sensor
curl -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\",
        \"attributes\": {
            \"friendly_name\": \"Nuclei Last Scan\",
            \"icon\": \"mdi:clock-check\",
            \"device_class\": \"timestamp\"
        }
    }" \
    "$HA_URL/api/states/sensor.nuclei_last_scan" \
    -s -o /dev/null
echo "✓ Updated sensor.nuclei_last_scan"

echo ""
echo "5. Final Status"
echo "=============="
echo "Current nuclei entities:"
curl -s -H "Authorization: Bearer $HA_TOKEN" $HA_URL/api/states | \
    jq -r '.[] | select(.entity_id | contains("nuclei")) | .entity_id' | sort

echo ""
echo "✅ Entity management complete!"
echo ""
echo "Next steps:"
echo "1. Update scripts to use only these entities"
echo "2. Create a Lovelace card for the scanner status"
echo "3. Set up automations based on sensor.nuclei_scanner_status"