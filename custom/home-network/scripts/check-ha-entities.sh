#!/bin/sh
# Check Home Assistant entities related to Nuclei scanning

HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"

echo "=== Home Assistant Nuclei Entity Status ==="
echo ""

# Check each entity
for entity in input_text.nuclei_status input_number.nuclei_findings input_number.nuclei_hosts_scanned input_datetime.nuclei_last_scan sensor.nuclei_scanner; do
    echo "Checking entity: $entity"
    response=$(curl -s -X GET \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        "${HA_BASE_URL}/api/states/${entity}")
    
    if [ $? -eq 0 ]; then
        state=$(echo "$response" | jq -r '.state // "not found"')
        if [ "$state" != "not found" ]; then
            echo "  State: $state"
            echo "  Attributes: $(echo "$response" | jq -c '.attributes // {}')"
        else
            echo "  Entity not found"
        fi
    else
        echo "  Failed to query entity"
    fi
    echo ""
done

echo "=== End of entity check ==="