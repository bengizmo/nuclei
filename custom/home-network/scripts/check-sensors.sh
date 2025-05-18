#!/bin/sh
# Check the new sensor entities in Home Assistant

HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"

echo "=== Nuclei Scanner Sensor Status ==="
echo ""

# Check main sensor
echo "Main sensor (sensor.nuclei_scanner):"
curl -s -X GET \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    "${HA_BASE_URL}/api/states/sensor.nuclei_scanner" | jq '.'

echo ""
echo "Individual sensors:"
echo ""

# Check individual sensors
sensors="sensor.nuclei_scanner_status sensor.nuclei_scanner_findings sensor.nuclei_scanner_hosts sensor.nuclei_scanner_last_scan"

for sensor in $sensors; do
    echo "Sensor: $sensor"
    curl -s -X GET \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        "${HA_BASE_URL}/api/states/${sensor}" | jq '{state: .state, friendly_name: .attributes.friendly_name}'
    echo ""
done

echo "=== End of sensor check ==="