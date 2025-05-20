#!/bin/bash
# Check the status of all Nuclei-related sensors in Home Assistant

# Get HA token
HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" ../.env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

echo "🏠 Nuclei Sensor Status in Home Assistant"
echo "======================================="

# Array of sensors to check
SENSORS=(
    "sensor.nuclei_scanner"
    "sensor.nuclei_scanner_status"
    "sensor.nuclei_scanner_findings"
    "sensor.nuclei_scanner_hosts"
    "sensor.nuclei_scanner_last_scan"
    "sensor.nuclei_scanner_summary"
)

# Get current time for timestamp comparison
CURRENT_TIME=$(date -u +%s)

for sensor in "${SENSORS[@]}"; do
    echo ""
    echo "⚙️ $sensor"
    echo "-----------------------------------"
    
    # Get sensor data
    RESPONSE=$(curl -s -H "Authorization: Bearer $HA_TOKEN" "$HA_URL/api/states/$sensor")
    
    # Check if sensor exists
    if echo "$RESPONSE" | grep -q "entity_id"; then
        # Extract state and relevant attributes
        STATE=$(echo "$RESPONSE" | jq -r '.state')
        FRIENDLY_NAME=$(echo "$RESPONSE" | jq -r '.attributes.friendly_name // "Unknown"')
        ICON=$(echo "$RESPONSE" | jq -r '.attributes.icon // "None"')
        
        echo "Name: $FRIENDLY_NAME"
        echo "State: $STATE"
        echo "Icon: $ICON"
        
        # Special handling for timestamp sensor
        if [[ "$sensor" == *"last_scan"* ]] && [[ "$STATE" != "unavailable" ]]; then
            # Try to convert the timestamp to seconds since epoch
            STATE_TIME=$(date -d "$STATE" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S%z" "$STATE" +%s 2>/dev/null)
            if [ -n "$STATE_TIME" ]; then
                # Calculate how long ago
                TIME_DIFF=$((CURRENT_TIME - STATE_TIME))
                if [ $TIME_DIFF -lt 60 ]; then
                    echo "Last scan: $TIME_DIFF seconds ago"
                elif [ $TIME_DIFF -lt 3600 ]; then
                    echo "Last scan: $((TIME_DIFF / 60)) minutes ago"
                else
                    echo "Last scan: $((TIME_DIFF / 3600)) hours ago"
                fi
            fi
        fi
        
        # Show additional attributes for main scanner entity
        if [[ "$sensor" == "sensor.nuclei_scanner" ]]; then
            FINDINGS=$(echo "$RESPONSE" | jq -r '.attributes.findings // 0')
            HOSTS=$(echo "$RESPONSE" | jq -r '.attributes.hosts_scanned // 0')
            STATUS=$(echo "$RESPONSE" | jq -r '.attributes.status // "unknown"')
            
            echo "Status: $STATUS"
            echo "Findings: $FINDINGS"
            echo "Hosts scanned: $HOSTS"
        fi
        
        echo "Status: ✅ Present"
    else
        echo "Status: ❌ Not found"
    fi
done

echo ""
echo "======================================="
echo "To update these sensors, use:"
echo "./ha-sensor-update.sh <status> <findings> <hosts> <timestamp>"
echo ""
echo "Example:"
echo "./ha-sensor-update.sh idle 0 5 \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\""