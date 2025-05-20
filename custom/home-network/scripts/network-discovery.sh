#!/bin/sh
# Network discovery and monitoring system
# Scans all VLANs every 5 minutes for new devices
# Enhanced with better error handling and status reporting

# Configuration
DISCOVERY_DB="/home/nuclei/discovery/discovery.db"
NEW_HOSTS_FILE="/home/nuclei/discovery/new_hosts.txt"
SCAN_INTERVAL=${DISCOVERY_INTERVAL:-300}  # 5 minutes by default, configurable
LOG_FILE="/home/nuclei/logs/discovery.log"
STATUS_FILE="/home/nuclei/discovery/status.json"
PING_INTERVAL=60  # Check hosts every minute between full scans
HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"

# Create necessary directories
mkdir -p $(dirname "$DISCOVERY_DB")
mkdir -p $(dirname "$LOG_FILE")
mkdir -p $(dirname "$STATUS_FILE")

# Initialize database if it doesn't exist
if [ ! -f "$DISCOVERY_DB" ]; then
    echo "# Network Discovery Database" > "$DISCOVERY_DB"
    echo "# Format: IP|MAC|FirstSeen|LastSeen|Hostname|OS|Services|ProfileStatus" >> "$DISCOVERY_DB"
fi

# Initialize status file if it doesn't exist
if [ ! -f "$STATUS_FILE" ]; then
    cat > "$STATUS_FILE" <<EOF
{
    "status": "starting",
    "last_update": "$(date -Iseconds)",
    "total_hosts": 0,
    "active_hosts": 0,
    "new_hosts": 0,
    "last_scan": "never",
    "errors": []
}
EOF
fi

# Signal handling
trap 'echo "Received signal, shutting down discovery service..."; update_status "stopped" "Shutdown requested"; exit 0' INT TERM

# Logging with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error logging
log_error() {
    log_message "ERROR: $1"
    update_status "error" "$1"
}

# Update status file
update_status() {
    local status="$1"
    local message="$2"
    local total_hosts=$(grep -v "^#" "$DISCOVERY_DB" | wc -l || echo 0)
    local active_hosts=$(grep -v "^#" "$DISCOVERY_DB" | grep -v "offline" | wc -l || echo 0)
    local new_hosts_count=0
    
    if [ -f "$NEW_HOSTS_FILE" ]; then
        new_hosts_count=$(wc -l < "$NEW_HOSTS_FILE" || echo 0)
    fi
    
    # Update status file
    cat > "$STATUS_FILE" <<EOF
{
    "status": "$status",
    "message": "$message",
    "last_update": "$(date -Iseconds)",
    "total_hosts": $total_hosts,
    "active_hosts": $active_hosts,
    "new_hosts": $new_hosts_count,
    "last_scan": "$(date -Iseconds)",
    "scan_interval": $SCAN_INTERVAL
}
EOF

    # Update Home Assistant if token is available
    if [ -n "$HA_TOKEN" ]; then
        curl -s -X POST \
            -H "Authorization: Bearer ${HA_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{
                \"state\": \"$status\",
                \"attributes\": {
                    \"friendly_name\": \"Network Discovery\",
                    \"icon\": \"mdi:magnify-scan\",
                    \"message\": \"$message\",
                    \"total_hosts\": $total_hosts,
                    \"active_hosts\": $active_hosts,
                    \"new_hosts\": $new_hosts_count,
                    \"last_scan\": \"$(date -Iseconds)\",
                    \"scan_interval\": $SCAN_INTERVAL
                }
            }" \
            "${HA_BASE_URL}/api/states/sensor.nuclei_discovery" || \
            log_error "Failed to update Home Assistant sensor"
    fi
}

# Function to scan a subnet and extract host info
scan_subnet() {
    local subnet="$1"
    local vlan_name="$2"
    local temp_file="/tmp/nmap_discovery_${vlan_name}.txt"
    
    log_message "Scanning $vlan_name VLAN: $subnet"
    update_status "scanning" "Scanning $vlan_name VLAN"
    
    # Check if subnet is reachable before scanning
    if ! ping -c 1 -W 2 "$(echo "$subnet" | sed 's/0\/24/1/')" >/dev/null 2>&1; then
        log_message "Warning: $vlan_name VLAN gateway not responding, skipping scan"
        return
    fi
    
    # Quick host discovery scan with retry
    for attempt in 1 2; do
        if nmap -sn "$subnet" -oG "$temp_file" >/dev/null 2>&1; then
            break
        fi
        
        if [ $attempt -eq 1 ]; then
            log_message "Warning: nmap scan failed for $subnet, retrying..."
            sleep 2
        else
            log_error "Failed to scan $subnet after $attempt attempts"
            return
        fi
    done
    
    # Check if temporary file exists and has content
    if [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; then
        log_error "Scan output empty for $vlan_name VLAN"
        return
    fi
    
    # Parse results
    grep "Host:" "$temp_file" | while read -r line; do
        ip=$(echo "$line" | awk '{print $2}')
        hostname=$(echo "$line" | grep -o '(\([^)]*\))' | tr -d '()')
        
        # Skip gateway IPs (x.x.x.1) unless scanning for gateways
        if echo "$ip" | grep -E '\.1$' >/dev/null && [ "$vlan_name" != "gateways" ]; then
            continue
        fi
        
        # Get MAC address if available
        mac=$(arp -n "$ip" 2>/dev/null | grep -v "incomplete" | awk '{print $3}' | grep -E '^[0-9a-fA-F:]+$' | head -1)
        if [ -z "$mac" ]; then
            mac="unknown"
        fi
        
        # Check if this host is already in our database
        if grep -q "^$ip|" "$DISCOVERY_DB"; then
            # Update last seen time
            if ! sed -i "s|^$ip|[^|]*|[^|]*|\([^|]*\)|.*|$ip|$mac|\\1|$(date '+%Y-%m-%d %H:%M:%S')|$hostname|" "$DISCOVERY_DB" 2>/dev/null; then
                # Try alternative sed syntax for macOS
                sed -i '' "s|^$ip|[^|]*|[^|]*|\([^|]*\)|.*|$ip|$mac|\\1|$(date '+%Y-%m-%d %H:%M:%S')|$hostname|" "$DISCOVERY_DB" 2>/dev/null || \
                log_error "Failed to update database for $ip"
            fi
        else
            # New host discovered!
            log_message "NEW HOST DISCOVERED: $ip ($hostname) on $vlan_name VLAN"
            echo "$ip|$mac|$(date '+%Y-%m-%d %H:%M:%S')|$(date '+%Y-%m-%d %H:%M:%S')|$hostname|||pending" >> "$DISCOVERY_DB"
            echo "$ip" >> "$NEW_HOSTS_FILE"
            
            # Trigger immediate profiling with enhanced script
            if [ -x "/home/nuclei/scripts/profile-new-host-enhanced.sh" ]; then
                nohup /home/nuclei/scripts/profile-new-host-enhanced.sh "$ip" "$vlan_name" >/dev/null 2>&1 &
            else
                log_error "Profile script not found or not executable"
            fi
        fi
    done
    
    rm -f "$temp_file"
}

# Function to mark hosts as offline if not seen recently
mark_offline_hosts() {
    local threshold_minutes=15
    local current_time=$(date +%s)
    local offline_count=0
    
    # Skip if database empty or just headers
    if [ ! -s "$DISCOVERY_DB" ] || [ "$(wc -l < "$DISCOVERY_DB")" -le 2 ]; then
        return
    fi
    
    while IFS='|' read -r ip mac first_seen last_seen hostname os services status; do
        # Skip comment lines and empty lines
        if echo "$ip" | grep -q "^#" || [ -z "$ip" ]; then
            continue
        fi
        
        if [ -n "$last_seen" ]; then
            # Try to parse date in a format-independent way
            last_seen_epoch=$(date -d "$last_seen" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$last_seen" +%s 2>/dev/null)
            
            if [ -n "$last_seen_epoch" ]; then
                diff=$((current_time - last_seen_epoch))
                if [ $diff -gt $((threshold_minutes * 60)) ]; then
                    offline_count=$((offline_count + 1))
                    log_message "Host $ip appears to be offline (not seen for ${diff} seconds)"
                    
                    # Update status to offline
                    if ! grep -q "offline" <<< "$status"; then
                        if ! sed -i "s|^$ip|.*|$ip|$mac|$first_seen|$last_seen|$hostname|$os|$services|offline|" "$DISCOVERY_DB" 2>/dev/null; then
                            # Try alternative sed syntax for macOS
                            sed -i '' "s|^$ip|.*|$ip|$mac|$first_seen|$last_seen|$hostname|$os|$services|offline|" "$DISCOVERY_DB" 2>/dev/null || \
                            log_error "Failed to mark $ip as offline"
                        fi
                    fi
                fi
            fi
        fi
    done < "$DISCOVERY_DB"
    
    if [ $offline_count -gt 0 ]; then
        log_message "Marked $offline_count hosts as offline"
    fi
}

# Function to check if known hosts are still online between full scans
check_known_hosts() {
    local counter=0
    local start_time=$(date +%s)
    
    log_message "Performing quick check of known hosts"
    
    # Skip if database empty or just headers
    if [ ! -s "$DISCOVERY_DB" ] || [ "$(wc -l < "$DISCOVERY_DB")" -le 2 ]; then
        return
    fi
    
    # Only process active hosts that aren't marked offline
    grep -v "^#" "$DISCOVERY_DB" | grep -v "offline" | while IFS='|' read -r ip mac first_seen last_seen hostname os services status; do
        # Skip empty lines
        if [ -z "$ip" ]; then
            continue
        fi
        
        counter=$((counter + 1))
        
        # Only update every 10 hosts to avoid flooding logs
        if [ $((counter % 10)) -eq 0 ]; then
            log_message "Checking host $counter..."
        fi
        
        # Quick ping to see if host is still alive
        if ping -c 1 -W 1 "$ip" >/dev/null 2>&1; then
            # Update last seen time
            if ! sed -i "s|^$ip|[^|]*|[^|]*|\([^|]*\)|.*|$ip|$mac|\\1|$(date '+%Y-%m-%d %H:%M:%S')|" "$DISCOVERY_DB" 2>/dev/null; then
                # Try alternative sed syntax for macOS
                sed -i '' "s|^$ip|[^|]*|[^|]*|\([^|]*\)|.*|$ip|$mac|\\1|$(date '+%Y-%m-%d %H:%M:%S')|" "$DISCOVERY_DB" 2>/dev/null
            fi
        fi
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_message "Quick check completed in $duration seconds. Checked $counter hosts."
}

# Main discovery loop
log_message "Starting network discovery service with scan interval: $SCAN_INTERVAL seconds"
update_status "starting" "Discovery service initializing"

while true; do
    start_time=$(date +%s)
    log_message "Starting discovery scan cycle..."
    update_status "scanning" "Full network scan in progress"
    
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
    active_hosts=$(grep -v "^#" "$DISCOVERY_DB" | grep -v "offline" | wc -l)
    new_hosts=$(wc -l < "$NEW_HOSTS_FILE")
    
    end_time=$(date +%s)
    scan_duration=$((end_time - start_time))
    
    if [ "$new_hosts" -gt 0 ]; then
        log_message "Discovery cycle complete in $scan_duration seconds. Found $new_hosts new hosts out of $total_hosts total ($active_hosts active)"
        update_status "active" "Found $new_hosts new devices"
    else
        log_message "Discovery cycle complete in $scan_duration seconds. No new hosts found. Total: $total_hosts ($active_hosts active)"
        update_status "active" "$active_hosts devices online"
    fi
    
    # Calculate remaining time until next full scan
    remaining_time=$((SCAN_INTERVAL - scan_duration))
    
    # If we have a long wait and multiple hosts, do quicker pings to known hosts
    if [ $remaining_time -gt 120 ] && [ $total_hosts -gt 5 ]; then
        cycles=$((remaining_time / PING_INTERVAL))
        log_message "Will perform $cycles quick checks before next full scan"
        
        for i in $(seq 1 $cycles); do
            # Break if the script is being shut down
            if [ ! -f "$STATUS_FILE" ] || grep -q "stopped" "$STATUS_FILE"; then
                break
            fi
            
            sleep $PING_INTERVAL
            check_known_hosts
        done
    else
        log_message "Waiting $remaining_time seconds until next scan..."
        sleep $remaining_time
    fi
done