#!/bin/sh
# Wrapper script for Home Assistant updates that properly handles the token

# Get the token from environment
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"
HA_URL="http://192.168.10.89:8123"

if [ -z "$HA_TOKEN" ]; then
    echo "Error: HOME_ASSISTANT_API_TOKEN not set"
    exit 1
fi

# Function to update Home Assistant
update_ha_state() {
    local entity_id=$1
    local state=$2
    local attributes=$3
    
    curl -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"state\": \"${state}\", \"attributes\": ${attributes}}" \
        "${HA_URL}/api/states/${entity_id}"
}

# Function to send notification
send_ha_notification() {
    local message=$1
    local title=$2
    
    curl -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"message\": \"${message}\", \"title\": \"${title}\"}" \
        "${HA_URL}/api/services/notify/notify"
}

# Export functions for use by other scripts
export -f update_ha_state
export -f send_ha_notification