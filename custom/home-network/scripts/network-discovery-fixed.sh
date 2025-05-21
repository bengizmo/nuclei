#!/bin/bash
# Network Discovery Script for Nuclei - Fixed Version
# Scans all VLANs every 5 minutes for new devices

# Configuration
SCAN_INTERVAL=${DISCOVERY_INTERVAL:-300}  # 5 minutes by default
DISCOVERY_DIR="/home/nuclei/discovery"
PROFILES_DIR="$DISCOVERY_DIR/profiles"
DB_FILE="$DISCOVERY_DIR/discovery.db"
STATUS_FILE="$DISCOVERY_DIR/status.json"
LOG_FILE="/home/nuclei/logs/network-discovery.log"

# Create required directories
mkdir -p "$PROFILES_DIR"
mkdir -p "/home/nuclei/logs"
mkdir -p "/home/nuclei/results/auto-discovery"

# VLANs to scan
VLANS="10 14 5 6"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to scan a VLAN for active hosts
scan_vlan() {
    local vlan=$1
    local network="192.168.${vlan}.0/24"
    
    log "Scanning VLAN $vlan (network $network)"
    
    # Quick ping scan to find active hosts
    nmap -sn $network 2>/dev/null | grep "Nmap scan report" | awk '{print $5}' | sort -V
}

# Function to profile a new host
profile_host() {
    local host=$1
    local profile_file="$PROFILES_DIR/${host}.nmap"
    
    log "Profiling new host: $host"
    
    # Run nmap scan to profile the host
    nmap -sS -sU -O -sV --script=default -oA "$PROFILES_DIR/$host" $host 2>/dev/null
    
    # If it's a new host, trigger a targeted scan
    if [ -f "$profile_file" ]; then
        log "Host $host profiled successfully"
        
        # Trigger targeted vulnerability scan
        trigger_host_scan $host
    fi
}

# Function to trigger a targeted scan for a specific host
trigger_host_scan() {
    local host=$1
    log "Triggering targeted scan for host: $host"
    
    # Run nuclei scan against the specific host
    nuclei -target $host \
        -t /home/nuclei/nuclei-templates/ \
        -o "/home/nuclei/results/auto-discovery/${host}-$(date +%Y%m%d-%H%M%S).json" \
        -json 2>/dev/null &
}

# Initialize database if it doesn't exist
if [ ! -f "$DB_FILE" ]; then
    touch "$DB_FILE"
    log "Initialized discovery database"
fi

# Main discovery loop
log "Starting network discovery service (interval: ${SCAN_INTERVAL}s)"

while true; do
    # Update status
    echo "{\"status\": \"scanning\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\", \"vlans\": [\"$(echo $VLANS | tr ' ' ',')\"]}" > "$STATUS_FILE"
    
    # Scan all VLANs
    for vlan in $VLANS; do
        log "Scanning VLAN $vlan"
        
        # Get current active hosts
        current_hosts=$(scan_vlan $vlan)
        
        # Check each host
        for host in $current_hosts; do
            # Skip if host is already in database
            if ! grep -q "$host" "$DB_FILE" 2>/dev/null; then
                log "New host discovered: $host"
                echo "$host" >> "$DB_FILE"
                
                # Profile the new host
                profile_host $host
            fi
        done
    done
    
    # Update status to idle
    echo "{\"status\": \"idle\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\", \"last_scan\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\"}" > "$STATUS_FILE"
    
    log "Discovery cycle complete. Sleeping for ${SCAN_INTERVAL} seconds..."
    sleep $SCAN_INTERVAL
done