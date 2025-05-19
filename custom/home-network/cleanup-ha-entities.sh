#!/bin/bash
# Clean up unnecessary nuclei entities in Home Assistant

echo "🧹 Cleaning Up Nuclei Entities in Home Assistant"
echo "=============================================="
echo ""

# Get HA token
HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

# List of entities to keep
KEEP_ENTITIES=(
    "sensor.nuclei_scanner_summary"
    "sensor.nuclei_scanner_status"
)

# Get all nuclei entities
ALL_ENTITIES=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
    $HA_URL/api/states | \
    jq -r '.[] | select(.entity_id | contains("nuclei")) | .entity_id')

echo "Entities to keep:"
for entity in "${KEEP_ENTITIES[@]}"; do
    echo "  ✓ $entity"
done
echo ""

echo "Entities to remove:"
for entity in $ALL_ENTITIES; do
    keep=false
    for keeper in "${KEEP_ENTITIES[@]}"; do
        if [[ "$entity" == "$keeper" ]]; then
            keep=true
            break
        fi
    done
    
    if [ "$keep" = false ]; then
        echo "  ✗ $entity"
    fi
done
echo ""

read -p "Proceed with cleanup? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
echo "Removing unnecessary entities..."

# Remove entities
for entity in $ALL_ENTITIES; do
    keep=false
    for keeper in "${KEEP_ENTITIES[@]}"; do
        if [[ "$entity" == "$keeper" ]]; then
            keep=true
            break
        fi
    done
    
    if [ "$keep" = false ]; then
        echo "Removing: $entity"
        # Remove the entity
        curl -X DELETE \
            -H "Authorization: Bearer $HA_TOKEN" \
            "$HA_URL/api/states/$entity" \
            -s -o /dev/null
    fi
done

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Remaining nuclei entities:"
curl -s -H "Authorization: Bearer $HA_TOKEN" \
    $HA_URL/api/states | \
    jq -r '.[] | select(.entity_id | contains("nuclei")) | .entity_id' | \
    sort

echo ""
echo "=============================================="
echo "Next steps:"
echo "1. Update only the required entities from the scripts"
echo "2. Configure dashboards to use the main summary sensor"
echo "3. Set up notifications based on status changes"