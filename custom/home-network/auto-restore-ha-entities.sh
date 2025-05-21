#!/bin/bash
# Auto-restore Home Assistant entities if they are missing
# Run this on a schedule to ensure entities always exist

# Load configuration 
cd "$(dirname "$0")"
source ./nas-config.sh

echo "🔄 Checking Home Assistant Entities"
echo "=================================="

# Function to extract token from env file
get_token() {
    if [ -f .env ]; then
        grep HOME_ASSISTANT_API_TOKEN .env | cut -d= -f2
    else
        echo ""
    fi
}

HA_TOKEN=$(get_token)
if [ -z "$HA_TOKEN" ]; then
    echo "❌ ERROR: No Home Assistant token found in .env file"
    exit 1
fi

# Check if nuclei entities exist
echo "Checking Nuclei sensors in Home Assistant..."
ENTITIES=$(curl -s -H "Authorization: Bearer ${HA_TOKEN}" \
    http://192.168.10.89:8123/api/states | \
    jq -r '.[] | select(.entity_id | contains("nuclei")) | .entity_id')

if [ -z "$ENTITIES" ]; then
    echo "❌ No Nuclei entities found in Home Assistant"
    echo "Running verify-ha-integration.sh to restore entities"
    ./verify-ha-integration.sh
else
    entity_count=$(echo "$ENTITIES" | wc -l | tr -d ' ')
    echo "✅ Found $entity_count Nuclei entities in Home Assistant"
    echo "$ENTITIES"
fi