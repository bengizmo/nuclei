#!/bin/sh
# Initialize the discovery database with known hosts

DISCOVERY_DB="/home/nuclei/discovery/discovery.db"
CRITICAL_HOSTS="/home/nuclei/critical-hosts.txt"

# Create database structure
mkdir -p $(dirname "$DISCOVERY_DB")

echo "# Network Discovery Database" > "$DISCOVERY_DB"
echo "# Format: IP|MAC|FirstSeen|LastSeen|Hostname|OS|Services|ProfileStatus" >> "$DISCOVERY_DB"

# Add known critical infrastructure
echo "Importing critical infrastructure hosts..."

# Parse critical hosts file with space or tab delimiter
grep -v "^#" "$CRITICAL_HOSTS" | while read -r line; do
    # Parse line with spaces or tabs
    ip=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ *//' | sed 's/#.*//')
    
    if [ -n "$ip" ] && [ -n "$name" ]; then
        # Determine device type based on name
        device_type="unknown"
        os_guess=""
        
        case "$name" in
            *"UDM"*|*"Router"*) 
                device_type="network-device"
                os_guess="UniFi Dream Machine"
                ;;
            *"AP"*) 
                device_type="network-device"
                os_guess="UniFi Access Point"
                ;;
            *"Think Tank"*|*"Ubuntu"*) 
                device_type="linux-server"
                os_guess="Ubuntu Linux"
                ;;
            *"NAS"*) 
                device_type="linux-server"
                os_guess="Synology DSM"
                ;;
            *"Home Assistant"*) 
                device_type="linux-server"
                os_guess="Home Assistant OS"
                ;;
        esac
        
        # Add to database
        echo "$ip||$(date '+%Y-%m-%d %H:%M:%S')|$(date '+%Y-%m-%d %H:%M:%S')|$name|$os_guess||profiled-$device_type" >> "$DISCOVERY_DB"
        echo "Added: $ip ($name) as $device_type"
    fi
done

# Run initial discovery scan to populate MAC addresses and services
echo "Running initial discovery scan..."
/home/nuclei/scripts/network-discovery.sh &

echo "Discovery database initialized with $(grep -v '^#' "$DISCOVERY_DB" | wc -l) hosts"