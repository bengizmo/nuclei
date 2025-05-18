#!/bin/sh
# Generate network map visualization data for Home Assistant

DISCOVERY_DB="/home/nuclei/discovery/discovery.db"
OUTPUT_FILE="/home/nuclei/results/network-map.json"
HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"

# Generate network topology in JSON format
echo "Generating network map..."

# Create nodes array
NODES='['
FIRST=true

while IFS='|' read -r ip mac first_seen last_seen hostname os services profile_status; do
    # Skip comments
    if echo "$ip" | grep -q '^#'; then
        continue
    fi
    
    # Determine device icon based on type
    icon="mdi:help-circle"
    color="#808080"
    
    case "$profile_status" in
        *"network-device"*) icon="mdi:router"; color="#4CAF50" ;;
        *"linux-server"*) icon="mdi:server"; color="#2196F3" ;;
        *"windows-host"*) icon="mdi:microsoft-windows"; color="#FF9800" ;;
        *"camera"*) icon="mdi:cctv"; color="#9C27B0" ;;
        *"apple-device"*) icon="mdi:apple"; color="#607D8B" ;;
        *"printer"*) icon="mdi:printer"; color="#795548" ;;
    esac
    
    # Determine VLAN
    vlan="unknown"
    vlan_id=0
    case "$ip" in
        "192.168.10."*) vlan="default"; vlan_id=1 ;;
        "192.168.14."*) vlan="iot"; vlan_id=2 ;;
        "192.168.5."*) vlan="guest"; vlan_id=3 ;;
        "192.168.6."*) vlan="clients"; vlan_id=4 ;;
    esac
    
    # Add comma if not first entry
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        NODES="$NODES,"
    fi
    
    # Add node
    NODES="$NODES{
        \"id\": \"$ip\",
        \"label\": \"$hostname\",
        \"ip\": \"$ip\",
        \"vlan\": \"$vlan\",
        \"vlan_id\": $vlan_id,
        \"type\": \"$profile_status\",
        \"os\": \"$os\",
        \"icon\": \"$icon\",
        \"color\": \"$color\",
        \"last_seen\": \"$last_seen\"
    }"
done < "$DISCOVERY_DB"

NODES="$NODES]"

# Create edges (connections) based on VLAN
EDGES='['
# Connect all devices to their VLAN router
for vlan_gateway in "192.168.10.1:default" "192.168.14.1:iot" "192.168.5.1:guest" "192.168.6.1:clients"; do
    IFS=':' read -r gateway vlan_name <<< "$vlan_gateway"
    
    grep -E "^192\.168\.[0-9]+\." "$DISCOVERY_DB" | while IFS='|' read -r ip rest; do
        if [ "$ip" != "$gateway" ] && echo "$ip" | grep -q "${gateway%.*}\."; then
            if [ "$EDGES" != "[" ]; then
                EDGES="$EDGES,"
            fi
            EDGES="$EDGES{\"from\": \"$gateway\", \"to\": \"$ip\", \"vlan\": \"$vlan_name\"}"
        fi
    done
done
EDGES="$EDGES]"

# Create complete network map
NETWORK_MAP="{
    \"nodes\": $NODES,
    \"edges\": $EDGES,
    \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\",
    \"total_devices\": $(grep -cv '^#' "$DISCOVERY_DB"),
    \"vlans\": {
        \"default\": $(grep -c '^192\.168\.10\.' "$DISCOVERY_DB"),
        \"iot\": $(grep -c '^192\.168\.14\.' "$DISCOVERY_DB"),
        \"guest\": $(grep -c '^192\.168\.5\.' "$DISCOVERY_DB"),
        \"clients\": $(grep -c '^192\.168\.6\.' "$DISCOVERY_DB")
    }
}"

# Save to file
echo "$NETWORK_MAP" | jq . > "$OUTPUT_FILE"

# Update Home Assistant with network map data
curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"updated\",
        \"attributes\": {
            \"friendly_name\": \"Network Map\",
            \"icon\": \"mdi:lan\",
            \"total_devices\": $(grep -cv '^#' "$DISCOVERY_DB"),
            \"map_file\": \"$OUTPUT_FILE\",
            \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\",
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\",
                \"model\": \"Network Vulnerability Scanner\",
                \"manufacturer\": \"ProjectDiscovery\",
                \"sw_version\": \"3.4.2\"
            }
        }
    }" \
    "${HA_BASE_URL}/api/states/sensor.nuclei_network_map"

echo "Network map generated and updated in Home Assistant"