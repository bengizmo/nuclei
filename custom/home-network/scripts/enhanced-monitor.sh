#!/bin/bash
# Enhanced monitoring script with robust error handling

# Configuration
CHECK_INTERVAL=60
MAX_RESTART_ATTEMPTS=5
RESTART_COOLDOWN=300  # 5 minutes
DISK_THRESHOLD=90     # percentage
MEMORY_THRESHOLD=85   # percentage

# State tracking
RESTART_COUNT=0
LAST_RESTART=0
MONITOR_PID=$$

# Logging function with severity levels
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a /home/nuclei/logs/monitor.log
}

# Check disk usage
check_disk_space() {
    local usage=$(df /home/nuclei | awk 'NR==2 {print int($5)}')
    if [ "$usage" -gt "$DISK_THRESHOLD" ]; then
        log "ERROR" "Disk usage critical: ${usage}%"
        # Rotate logs if disk is full
        find /home/nuclei/logs -type f -name "*.log" -size +100M -exec truncate -s 0 {} \;
        return 1
    fi
    return 0
}

# Check memory usage
check_memory() {
    local usage=$(free | awk '/^Mem:/ {print int($3/$2 * 100)}')
    if [ "$usage" -gt "$MEMORY_THRESHOLD" ]; then
        log "WARN" "Memory usage high: ${usage}%"
        return 1
    fi
    return 0
}

# Check network connectivity with timeout
check_network() {
    if ! timeout 5 ping -c 1 192.168.10.89 &>/dev/null; then
        log "ERROR" "Network connectivity lost"
        return 1
    fi
    return 0
}

# Restart service with exponential backoff
restart_service() {
    local service=$1
    local current_time=$(date +%s)
    
    # Check if we're in cooldown period
    if [ $((current_time - LAST_RESTART)) -lt "$RESTART_COOLDOWN" ]; then
        log "WARN" "In cooldown period, skipping restart"
        return 1
    fi
    
    # Check restart limit
    if [ "$RESTART_COUNT" -ge "$MAX_RESTART_ATTEMPTS" ]; then
        log "ERROR" "Max restart attempts reached, manual intervention required"
        notify_ha "CRITICAL: Nuclei scanner requires manual intervention - too many restarts"
        return 1
    fi
    
    log "INFO" "Attempting to restart $service (attempt $((RESTART_COUNT + 1)))"
    
    case "$service" in
        "discovery")
            pkill -f "network-discovery" || true
            sleep 2
            /home/nuclei/scripts/network-discovery-fixed-final.sh &
            ;;
        "container")
            # This would need to be handled externally
            log "ERROR" "Container restart requested - manual intervention needed"
            ;;
    esac
    
    RESTART_COUNT=$((RESTART_COUNT + 1))
    LAST_RESTART=$current_time
    
    # Exponential backoff for next cooldown
    RESTART_COOLDOWN=$((RESTART_COOLDOWN * 2))
    
    return 0
}

# Send HA notification with retry logic
notify_ha() {
    local message=$1
    local retries=3
    local delay=2
    
    if [ -z "$HOME_ASSISTANT_API_TOKEN" ]; then
        log "WARN" "HA API token not set, skipping notification"
        return 1
    fi
    
    for i in $(seq 1 $retries); do
        if timeout 10 curl -s -o /dev/null -w "%{http_code}" \
            -X POST \
            -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{
                \"message\": \"$message\",
                \"title\": \"Nuclei Monitor\",
                \"data\": {
                    \"priority\": \"high\",
                    \"tag\": \"nuclei-monitor\"
                }
            }" \
            "http://192.168.10.89:8123/api/services/notify/notify" | grep -q "^2"; then
            log "INFO" "HA notification sent successfully"
            return 0
        fi
        
        log "WARN" "HA notification failed (attempt $i/$retries)"
        sleep $((delay * i))
    done
    
    log "ERROR" "Failed to send HA notification after $retries attempts"
    return 1
}

# Main health check function
perform_health_check() {
    local healthy=true
    
    # System resource checks
    if ! check_disk_space; then
        healthy=false
        notify_ha "WARNING: Nuclei scanner disk space critical"
    fi
    
    if ! check_memory; then
        healthy=false
    fi
    
    if ! check_network; then
        healthy=false
        log "ERROR" "Network down, skipping service checks"
        return 1
    fi
    
    # Check discovery service
    if ! pgrep -f "network-discovery" >/dev/null; then
        log "ERROR" "Discovery service not running"
        healthy=false
        restart_service "discovery"
    else
        # Check if discovery is actually working
        local status_file="/home/nuclei/discovery/status.json"
        if [ -f "$status_file" ]; then
            local last_scan=$(jq -r '.last_scan' "$status_file" 2>/dev/null || echo "1970-01-01T00:00:00+00:00")
            local last_scan_epoch=$(date -d "$last_scan" +%s 2>/dev/null || echo 0)
            local current_epoch=$(date +%s)
            local time_diff=$((current_epoch - last_scan_epoch))
            
            if [ "$time_diff" -gt 600 ]; then  # 10 minutes
                log "WARN" "Discovery service appears stuck (no scan for ${time_diff}s)"
                restart_service "discovery"
                healthy=false
            fi
        fi
    fi
    
    # Update HA sensor with health status
    if [ "$healthy" = true ]; then
        update_ha_health "healthy"
    else
        update_ha_health "degraded"
    fi
    
    return 0
}

# Update HA with system health
update_ha_health() {
    local status=$1
    local disk_usage=$(df /home/nuclei | awk 'NR==2 {print int($5)}')
    local memory_usage=$(free | awk '/^Mem:/ {print int($3/$2 * 100)}')
    
    timeout 10 curl -s -X POST \
        -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"state\": \"$status\",
            \"attributes\": {
                \"friendly_name\": \"Nuclei System Health\",
                \"icon\": \"mdi:shield-check\",
                \"disk_usage\": \"${disk_usage}%\",
                \"memory_usage\": \"${memory_usage}%\",
                \"restart_count\": $RESTART_COUNT,
                \"monitor_pid\": $MONITOR_PID,
                \"last_check\": \"$(date -Iseconds)\"
            }
        }" \
        "http://192.168.10.89:8123/api/states/sensor.nuclei_system_health" >/dev/null 2>&1
}

# Signal handlers
cleanup() {
    log "INFO" "Monitor shutting down gracefully"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Main monitoring loop
log "INFO" "Enhanced monitor starting (PID: $MONITOR_PID)"
notify_ha "Nuclei enhanced monitor started"

while true; do
    perform_health_check
    sleep "$CHECK_INTERVAL"
done