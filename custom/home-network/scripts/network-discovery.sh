#!/bin/sh
# Network discovery and monitoring system
# Scans all VLANs every 5 minutes for new devices

# Configuration
DISCOVERY_DB="/home/nuclei/discovery/discovery.db"
NEW_HOSTS_FILE="/home/nuclei/discovery/new_hosts.txt"
SCAN_INTERVAL=300  # 5 minutes
LOG_FILE="/home/nuclei/logs/discovery.log"

# Create necessary directories
mkdir -p $(dirname "$DISCOVERY_DB")
mkdir -p $(dirname "$LOG_FILE")

# Initialize database if it doesn't exist
if [ ! -f "$DISCOVERY_DB" ]; then
    echo "# Network Discovery Database" > "$DISCOVERY_DB"
    echo "# Format: IP|MAC|FirstSeen|LastSeen|Hostname|OS|Services|ProfileStatus" >> "$DISCOVERY_DB"
fi

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to scan a subnet and extract host info
scan_subnet() {
    local subnet=$1
    local vlan_name=$2
    local temp_file="/tmp/nmap_discovery_${vlan_name}.txt"
    
    log_message "Scanning $vlan_name VLAN: $subnet"
    
    # Quick host discovery scan
    nmap -sn "$subnet" -oG "$temp_file" >/dev/null 2>&1
    
    # Parse results
    grep "Host:" "$temp_file" | while read -r line; do
        ip=$(echo "$line" | awk '{print $2}')
        hostname=$(echo "$line" | grep -o '(\([^)]*\))' | tr -d '()')
        
        # Skip gateway IPs (x.x.x.1)
        if echo "$ip" | grep -E '\.1$' >/dev/null; then
            continue
        fi
        
        # Get MAC address if available
        mac=$(arp -n "$ip" 2>/dev/null | grep -v "incomplete" | awk '{print $3}' | grep -E '^[0-9a-fA-F:]+$' | head -1)
        
        # Check if this host is already in our database
        if grep -q "^$ip|" "$DISCOVERY_DB"; then
            # Update last seen time
            sed -i "s|^$ip|[^|]*|[^|]*|\([^|]*\)|.*|$ip|$mac|\\1|$(date '+%Y-%m-%d %H:%M:%S')|" "$DISCOVERY_DB" 2>/dev/null || \
            sed -i '' "s|^$ip|[^|]*|[^|]*|\([^|]*\)|.*|$ip|$mac|\\1|$(date '+%Y-%m-%d %H:%M:%S')|" "$DISCOVERY_DB" 2>/dev/null
        else
            # New host discovered!
            log_message "NEW HOST DISCOVERED: $ip ($hostname) on $vlan_name VLAN"
            echo "$ip|$mac|$(date '+%Y-%m-%d %H:%M:%S')|$(date '+%Y-%m-%d %H:%M:%S')|$hostname|||pending" >> "$DISCOVERY_DB"
            echo "$ip" >> "$NEW_HOSTS_FILE"
            
            # Trigger immediate profiling with enhanced script
            /home/nuclei/scripts/profile-new-host-enhanced.sh "$ip" "$vlan_name" &
        fi
    done
    
    rm -f "$temp_file"
}

# Function to mark hosts as offline if not seen recently
mark_offline_hosts() {
    local threshold_minutes=15
    local current_time=$(date +%s)
    
    while IFS='|' read -r ip mac first_seen last_seen hostname os services status; do
        if [ -n "$last_seen" ]; then
            last_seen_epoch=$(date -d "$last_seen" +%s 2>/dev/null)
            if [ -n "$last_seen_epoch" ]; then
                diff=$((current_time - last_seen_epoch))
                if [ $diff -gt $((threshold_minutes * 60)) ]; then
                    log_message "Host $ip appears to be offline (not seen for ${diff} seconds)"
                fi
            fi
        fi
    done < "$DISCOVERY_DB"
}

# Main discovery loop
log_message "Starting network discovery service..."

while true; do
    log_message "Starting discovery scan cycle..."
    
    # Clear new hosts file
    > "$NEW_HOSTS_FILE"
    
    # Scan each VLAN
    scan_subnet "192.168.10.0/24" "default"
    scan_subnet "192.168.14.0/24" "iot"
    scan_subnet "192.168.5.0/24" "guest"
    scan_subnet "192.168.6.0/24" "clients"
    
    # Check for any hosts that haven't been seen recently
    mark_offline_hosts
    
    # Update Home Assistant with discovery stats
    total_hosts=$(grep -v "^#" "$DISCOVERY_DB" | wc -l)
    new_hosts=$(wc -l < "$NEW_HOSTS_FILE")
    
    if [ "$new_hosts" -gt 0 ]; then
        log_message "Discovery cycle complete. Found $new_hosts new hosts out of $total_hosts total"
    else
        log_message "Discovery cycle complete. No new hosts found. Total: $total_hosts"
    fi
    
    # Wait for next scan
    sleep $SCAN_INTERVAL
done