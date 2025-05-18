#!/bin/sh
# Check all Nuclei Scanner sensors including AI summary

HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"

echo "=== Nuclei Scanner Complete Sensor Status ==="
echo ""

# List of all sensors

for sensor in sensor.nuclei_scanner sensor.nuclei_scanner_status sensor.nuclei_scanner_findings sensor.nuclei_scanner_hosts sensor.nuclei_scanner_last_scan sensor.nuclei_scanner_summary; do
    echo "=== $sensor ==="
    response=$(curl -s -X GET \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        "${HA_BASE_URL}/api/states/${sensor}")
    
    if echo "$response" | jq -e . >/dev/null 2>&1; then
        echo "State: $(echo "$response" | jq -r '.state')"
        echo "Friendly Name: $(echo "$response" | jq -r '.attributes.friendly_name // "N/A"')"
        
        # Show specific attributes for AI summary
        if [ "$sensor" = "sensor.nuclei_scanner_summary" ]; then
            echo "Model: $(echo "$response" | jq -r '.attributes.model // "N/A"')"
            echo "Generated At: $(echo "$response" | jq -r '.attributes.generated_at // "N/A"')"
            echo "Critical Count: $(echo "$response" | jq -r '.attributes.critical_count // "N/A"')"
            echo "High Count: $(echo "$response" | jq -r '.attributes.high_count // "N/A"')"
        fi
    else
        echo "Entity not found or error occurred"
    fi
    echo ""
done

echo "=== End of sensor check ==="