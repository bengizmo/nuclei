#!/bin/bash
# Resilient Network Discovery Script with comprehensive error handling

# Configuration
SCAN_INTERVAL=${DISCOVERY_INTERVAL:-300}
DISCOVERY_DIR="/home/nuclei/discovery"
PROFILES_DIR="$DISCOVERY_DIR/profiles"
DB_FILE="$DISCOVERY_DIR/discovery.db"
STATUS_FILE="$DISCOVERY_DIR/status.json"
LOG_FILE="/home/nuclei/logs/network-discovery.log"
ERROR_LOG="/home/nuclei/logs/network-discovery-errors.log"
MAX_LOG_SIZE=104857600  # 100MB

# Timeout configurations
NMAP_TIMEOUT=30
NUCLEI_TIMEOUT=300
NETWORK_CHECK_TIMEOUT=5

# Create required directories
mkdir -p "$PROFILES_DIR" "/home/nuclei/logs" "/home/nuclei/results/auto-discovery"

# VLANs to scan
VLANS="10 14 5 6"

# Error counter for circuit breaker
ERROR_COUNT=0
ERROR_THRESHOLD=5
ERROR_RESET_TIME=3600  # 1 hour
LAST_ERROR_RESET=$(date +%s)

# Logging with automatic rotation
log() {
    local level=$1
    shift
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    
    # Rotate log if too large
    if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null) -gt $MAX_LOG_SIZE ]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
        gzip "${LOG_FILE}.old" &
    fi
    
    echo "$message" >> "$LOG_FILE"
    
    # Also log errors to separate file
    if [ "$level" = "ERROR" ]; then
        echo "$message" >> "$ERROR_LOG"
    fi
}

# Network connectivity check with timeout
check_network() {
    local network=$1
    if ! timeout "$NETWORK_CHECK_TIMEOUT" ping -c 1 -W 1 "${network%.*}.1" &>/dev/null; then
        log "WARN" "Network $network appears unreachable"
        return 1
    fi
    return 0
}

# Circuit breaker implementation
circuit_breaker_check() {
    local current_time=$(date +%s)
    
    # Reset error count if enough time has passed
    if [ $((current_time - LAST_ERROR_RESET)) -gt $ERROR_RESET_TIME ]; then
        ERROR_COUNT=0
        LAST_ERROR_RESET=$current_time
        log "INFO" "Circuit breaker reset"
    fi
    
    # Check if circuit should be open
    if [ $ERROR_COUNT -ge $ERROR_THRESHOLD ]; then
        log "ERROR" "Circuit breaker OPEN - too many errors ($ERROR_COUNT)"
        return 1
    fi
    
    return 0
}

# Record error with circuit breaker
record_error() {
    ERROR_COUNT=$((ERROR_COUNT + 1))
    log "WARN" "Error count: $ERROR_COUNT/$ERROR_THRESHOLD"
}

# Scan VLAN with timeout and error handling
scan_vlan() {
    local vlan=$1
    local network="192.168.${vlan}.0/24"
    
    # Check if network is reachable
    if ! check_network "$network"; then
        log "WARN" "Skipping unreachable network $network"
        return 1
    fi
    
    log "INFO" "Scanning VLAN $vlan (network $network)"
    
    # Run nmap with timeout and capture both stdout and stderr
    local scan_output
    local scan_error
    
    if scan_output=$(timeout "$NMAP_TIMEOUT" nmap -sn "$network" 2>&1); then
        # Extract IPs from successful scan
        echo "$scan_output" | grep "Nmap scan report" | \
            sed -n 's/.*(\([0-9.]*\)).*/\1/p; s/Nmap scan report for \([0-9.]*\)$/\1/p' | \
            grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' | sort -V | uniq
    else
        log "ERROR" "nmap scan failed for $network: timeout or error"
        record_error
        return 1
    fi
}

# Profile host with timeout and retry
profile_host() {
    local host=$1
    local profile_file="$PROFILES_DIR/${host}.nmap"
    local retry_count=0
    local max_retries=2
    
    log "INFO" "Profiling host: $host"
    
    while [ $retry_count -le $max_retries ]; do
        if timeout "$NMAP_TIMEOUT" nmap -sS -sU -O -sV --script=default -oN "$profile_file" "$host" 2>/dev/null; then
            if [ -f "$profile_file" ]; then
                log "INFO" "Host $host profiled successfully"
                return 0
            fi
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -le $max_retries ]; then
            log "WARN" "Profile attempt $retry_count failed for $host, retrying..."
            sleep $((retry_count * 2))  # Exponential backoff
        fi
    done
    
    log "ERROR" "Failed to profile host $host after $max_retries retries"
    record_error
    return 1
}

# Trigger scan with proper error handling
trigger_host_scan() {
    local host=$1
    local output_file="/home/nuclei/results/auto-discovery/${host}-$(date +%Y%m%d-%H%M%S).json"
    
    log "INFO" "Triggering nuclei scan for host: $host"
    
    # Check if nuclei is available
    if ! command -v nuclei &>/dev/null; then
        log "ERROR" "nuclei command not found"
        record_error
        return 1
    fi
    
    # Run scan with timeout in background
    (
        if timeout "$NUCLEI_TIMEOUT" nuclei -target "$host" \
            -t /home/nuclei/nuclei-templates/ \
            -o "$output_file" \
            -j 2>&1 | grep -v "^\[INF\]" >> "$ERROR_LOG"; then
            log "INFO" "Nuclei scan completed for $host"
        else
            log "ERROR" "Nuclei scan failed or timed out for $host"
            record_error
        fi
    ) &
    
    # Don't wait for background scan
    return 0
}

# Update status with error handling
update_status() {
    local status=$1
    local extra_json=$2
    
    local json_status="{
        \"status\": \"$status\",
        \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\",
        \"error_count\": $ERROR_COUNT,
        \"circuit_breaker\": \"$([ $ERROR_COUNT -ge $ERROR_THRESHOLD ] && echo 'open' || echo 'closed')\"
        ${extra_json:+,$extra_json}
    }"
    
    if ! echo "$json_status" > "$STATUS_FILE"; then
        log "ERROR" "Failed to update status file"
        record_error
    fi
}

# Initialize database with error handling
init_database() {
    if [ ! -f "$DB_FILE" ]; then
        if ! touch "$DB_FILE"; then
            log "ERROR" "Failed to create discovery database"
            exit 1
        fi
        log "INFO" "Initialized discovery database"
    fi
    
    # Validate database is readable/writable
    if ! [ -r "$DB_FILE" ] || ! [ -w "$DB_FILE" ]; then
        log "ERROR" "Discovery database is not accessible"
        exit 1
    fi
}

# Graceful shutdown
cleanup() {
    log "INFO" "Discovery service shutting down gracefully"
    update_status "stopped" "\"reason\": \"graceful_shutdown\""
    exit 0
}

trap cleanup SIGTERM SIGINT

# Main discovery loop with comprehensive error handling
main() {
    log "INFO" "Starting resilient network discovery (interval: ${SCAN_INTERVAL}s)"
    
    # Initialize
    init_database
    
    while true; do
        # Check circuit breaker
        if ! circuit_breaker_check; then
            log "ERROR" "Circuit breaker open, waiting before retry..."
            sleep 300  # Wait 5 minutes when circuit is open
            continue
        fi
        
        # Update scanning status
        update_status "scanning" "\"vlans\": [$(printf '%s\n' $VLANS | paste -sd, | sed 's/,/","/g' | sed 's/^/"/;s/$/"/')]"
        
        local scan_start=$(date +%s)
        local hosts_found=0
        local new_hosts=0
        
        # Scan all VLANs
        for vlan in $VLANS; do
            # Get current active hosts
            if current_hosts=$(scan_vlan "$vlan"); then
                # Process discovered hosts
                for host in $current_hosts; do
                    [ -z "$host" ] && continue
                    hosts_found=$((hosts_found + 1))
                    
                    # Check if new host
                    if ! grep -q "^$host$" "$DB_FILE" 2>/dev/null; then
                        log "INFO" "New host discovered: $host"
                        echo "$host" >> "$DB_FILE"
                        new_hosts=$((new_hosts + 1))
                        
                        # Profile new host
                        if profile_host "$host"; then
                            trigger_host_scan "$host"
                        fi
                    fi
                done
            fi
        done
        
        local scan_duration=$(($(date +%s) - scan_start))
        
        # Update idle status with scan results
        update_status "idle" "\"last_scan\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\", \"scan_duration\": $scan_duration, \"hosts_found\": $hosts_found, \"new_hosts\": $new_hosts"
        
        log "INFO" "Discovery cycle complete. Found $hosts_found hosts ($new_hosts new) in ${scan_duration}s. Sleeping for ${SCAN_INTERVAL}s..."
        
        # Interruptible sleep
        for i in $(seq 1 $SCAN_INTERVAL); do
            sleep 1
            # Check if we should exit
            [ -f "/tmp/discovery-stop" ] && cleanup
        done
    done
}

# Start main function
main