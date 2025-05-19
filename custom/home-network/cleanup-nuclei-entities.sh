#!/bin/bash
# Clean up and reorganize nuclei entities in Home Assistant

echo "🧹 Nuclei Entity Cleanup for Home Assistant"
echo "========================================"
echo ""

# Get HA token
HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

# Entities we want to keep (for the enhanced system)
KEEP_ENTITIES=(
    "sensor.nuclei_scanner_summary"
)

# First, get all existing nuclei entities
echo "1. Finding all nuclei entities..."
ALL_ENTITIES=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
    "$HA_URL/api/states" | \
    jq -r '.[] | select(.entity_id | contains("nuclei")) | .entity_id')

echo "Found $(echo "$ALL_ENTITIES" | wc -l) entities:"
echo "$ALL_ENTITIES" | sed 's/^/  /'
echo ""

# Identify entities to remove
REMOVE_ENTITIES=()
while IFS= read -r entity; do
    if [[ -n "$entity" ]]; then
        should_remove=true
        for keeper in "${KEEP_ENTITIES[@]}"; do
            if [[ "$entity" == "$keeper" ]]; then
                should_remove=false
                break
            fi
        done
        if $should_remove; then
            REMOVE_ENTITIES+=("$entity")
        fi
    fi
done <<< "$ALL_ENTITIES"

echo "2. Entities to remove (${#REMOVE_ENTITIES[@]} entities):"
for entity in "${REMOVE_ENTITIES[@]}"; do
    echo "  ✗ $entity"
done
echo ""

echo "3. Entities to keep:"
for entity in "${KEEP_ENTITIES[@]}"; do
    echo "  ✓ $entity"
done
echo ""

# Confirm cleanup
echo "⚠️  Warning: This will permanently remove the entities listed above."
read -p "Proceed with cleanup? (yes/no): " -r
echo ""

if [[ $REPLY == "yes" ]]; then
    echo "4. Removing entities..."
    for entity in "${REMOVE_ENTITIES[@]}"; do
        echo "  Removing: $entity"
        curl -X DELETE \
            -H "Authorization: Bearer $HA_TOKEN" \
            "$HA_URL/api/states/$entity" \
            -s -o /dev/null -w "     Status: %{http_code}\n"
    done
    echo ""
    
    echo "5. Creating/updating required entities..."
    
    # Ensure the summary sensor exists with proper attributes
    curl -X POST \
        -H "Authorization: Bearer $HA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"state\": \"Initializing...\",
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
                \"hosts_scanned\": 0
            }
        }" \
        "$HA_URL/api/states/sensor.nuclei_scanner_summary" \
        -s -o /dev/null -w "  sensor.nuclei_scanner_summary - Status: %{http_code}\n"
    
    echo ""
    echo "✅ Cleanup complete!"
else
    echo "❌ Cleanup cancelled"
fi

echo ""
echo "6. Final entity list:"
FINAL_ENTITIES=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
    "$HA_URL/api/states" | \
    jq -r '.[] | select(.entity_id | contains("nuclei")) | .entity_id')
echo "$FINAL_ENTITIES" | sed 's/^/  /'

echo ""
echo "========================================"
echo "Done! The Nuclei scanner now uses only:"
echo "- sensor.nuclei_scanner_summary (all data in one place)"
echo ""
echo "This sensor contains:"
echo "- AI-generated summary text"
echo "- Vulnerability counts by severity"
echo "- Last scan timestamp"
echo "- Scan status"
echo "- Number of hosts scanned"