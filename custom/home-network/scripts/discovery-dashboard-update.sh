#!/bin/sh
# Update Home Assistant with network discovery statistics

DISCOVERY_DB="/home/nuclei/discovery/discovery.db"
HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"

# Calculate statistics
TOTAL_DEVICES=$(grep -v "^#" "$DISCOVERY_DB" | wc -l)
ONLINE_DEVICES=$(grep -v "^#" "$DISCOVERY_DB" | awk -F'|' -v cutoff=$(date -d '15 minutes ago' +%s) '
    {
        cmd = "date -d \"" $4 "\" +%s"
        cmd | getline last_seen_epoch
        close(cmd)
        if (last_seen_epoch > cutoff) print
    }
' | wc -l)

# Count by device type
LINUX_SERVERS=$(grep "linux-server" "$DISCOVERY_DB" | wc -l)
WINDOWS_HOSTS=$(grep "windows-host" "$DISCOVERY_DB" | wc -l)
CAMERAS=$(grep "camera" "$DISCOVERY_DB" | wc -l)
NETWORK_DEVICES=$(grep "network-device" "$DISCOVERY_DB" | wc -l)
APPLE_DEVICES=$(grep "apple-device" "$DISCOVERY_DB" | wc -l)
IOT_DEVICES=$(grep -E "iot|camera|printer" "$DISCOVERY_DB" | wc -l)
UNKNOWN_DEVICES=$(grep "unknown" "$DISCOVERY_DB" | wc -l)

# Get recent discoveries
RECENT_DISCOVERIES=$(awk -F'|' -v cutoff=$(date -d '24 hours ago' +%s) '
    {
        cmd = "date -d \"" $3 "\" +%s"
        cmd | getline first_seen_epoch
        close(cmd)
        if (first_seen_epoch > cutoff) print $1 " (" $5 ")"
    }
' "$DISCOVERY_DB" | head -5 | tr '\n' ';')

# Update main discovery sensor
curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"${ONLINE_DEVICES}/${TOTAL_DEVICES} devices online\",
        \"attributes\": {
            \"friendly_name\": \"Network Discovery\",
            \"icon\": \"mdi:lan\",
            \"total_devices\": $TOTAL_DEVICES,
            \"online_devices\": $ONLINE_DEVICES,
            \"linux_servers\": $LINUX_SERVERS,
            \"windows_hosts\": $WINDOWS_HOSTS,
            \"cameras\": $CAMERAS,
            \"network_devices\": $NETWORK_DEVICES,
            \"apple_devices\": $APPLE_DEVICES,
            \"iot_devices\": $IOT_DEVICES,
            \"unknown_devices\": $UNKNOWN_DEVICES,
            \"recent_discoveries\": \"$RECENT_DISCOVERIES\",
            \"last_scan\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\",
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\",
                \"model\": \"Network Vulnerability Scanner\",
                \"manufacturer\": \"ProjectDiscovery\",
                \"sw_version\": \"3.4.2\"
            }
        }
    }" \
    "${HA_BASE_URL}/api/states/sensor.nuclei_network_discovery"

# Update VLAN-specific sensors
for vlan in "10:default" "14:iot" "5:guest" "6:clients"; do
    IFS=':' read -r subnet_num vlan_name <<< "$vlan"
    vlan_devices=$(grep -E "^192\.168\.$subnet_num\." "$DISCOVERY_DB" | wc -l)
    
    curl -s -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"state\": \"$vlan_devices\",
            \"attributes\": {
                \"friendly_name\": \"Devices on $vlan_name VLAN\",
                \"icon\": \"mdi:lan\",
                \"vlan\": \"$vlan_name\",
                \"subnet\": \"192.168.$subnet_num.0/24\",
                \"device\": {
                    \"identifiers\": [\"nuclei_scanner_001\"],
                    \"name\": \"Nuclei Scanner\",
                    \"model\": \"Network Vulnerability Scanner\",
                    \"manufacturer\": \"ProjectDiscovery\",
                    \"sw_version\": \"3.4.2\"
                }
            }
        }" \
        "${HA_BASE_URL}/api/states/sensor.nuclei_vlan_${vlan_name}"
done