#!/bin/sh
# Monitoring script for discovery service
# Run this in a separate container or cron job to ensure discovery is always running

# Configuration
LOG_FILE="/home/nuclei/logs/monitor.log"
STATUS_FILE="/home/nuclei/discovery/status.json"
RESTART_THRESHOLD=1800  # 30 minutes without updates
HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"

# Create log directory
mkdir -p $(dirname "$LOG_FILE")

# Log message with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Send notification to Home Assistant
notify_ha() {
    if [ -n "$HA_TOKEN" ]; then
        curl -s -X POST \
            -H "Authorization: Bearer ${HA_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{
                \"message\": \"$1\",
                \"title\": \"Discovery Monitoring\",
                \"data\": {
                    \"tag\": \"nuclei-monitor\",
                    \"ttl\": 0,
                    \"priority\": \"high\"
                }
            }" \
            "${HA_BASE_URL}/api/services/notify/notify"
    fi
}

# Update monitor status in Home Assistant
update_ha_status() {
    if [ -n "$HA_TOKEN" ]; then
        curl -s -X POST \
            -H "Authorization: Bearer ${HA_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{
                \"state\": \"$1\",
                \"attributes\": {
                    \"friendly_name\": \"Nuclei Monitor\",
                    \"icon\": \"mdi:eye\",
                    \"message\": \"$2\",
                    \"last_check\": \"$(date -Iseconds)\"
                }
            }" \
            "${HA_BASE_URL}/api/states/sensor.nuclei_monitor"
    fi
}

log_message "Starting discovery monitoring service"
update_ha_status "starting" "Monitor service initialized"

# Main monitoring loop
while true; do
    # Check if status file exists
    if [ ! -f "$STATUS_FILE" ]; then
        log_message "ERROR: Status file not found. Discovery service may not be running."
        update_ha_status "error" "Status file missing"
        notify_ha "Network discovery status file missing - service may be down!"
        
        # Wait before checking again
        sleep 300
        continue
    fi
    
    # Check last update time
    LAST_UPDATE=$(grep -o '"last_update":"[^"]*"' "$STATUS_FILE" | cut -d'"' -f4)
    if [ -z "$LAST_UPDATE" ]; then
        log_message "ERROR: Cannot parse last update time from status file"
        update_ha_status "error" "Invalid status file format"
        sleep 300
        continue
    fi
    
    # Convert to epoch for comparison
    LAST_UPDATE_EPOCH=$(date -d "$LAST_UPDATE" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S%z" "$LAST_UPDATE" +%s 2>/dev/null)
    CURRENT_EPOCH=$(date +%s)
    
    if [ -z "$LAST_UPDATE_EPOCH" ]; then
        log_message "ERROR: Cannot convert last update time to epoch"
        update_ha_status "error" "Cannot parse timestamp"
        sleep 300
        continue
    fi
    
    # Calculate time since last update
    TIME_DIFF=$((CURRENT_EPOCH - LAST_UPDATE_EPOCH))
    
    # Get discovery status
    DISCOVERY_STATUS=$(grep -o '"status":"[^"]*"' "$STATUS_FILE" | head -1 | cut -d'"' -f4)
    
    # Log current status
    log_message "Discovery status: $DISCOVERY_STATUS, Last update: $TIME_DIFF seconds ago"
    
    # Check if update is too old
    if [ $TIME_DIFF -gt $RESTART_THRESHOLD ]; then
        log_message "WARNING: Discovery service hasn't updated in $TIME_DIFF seconds (threshold: $RESTART_THRESHOLD)"
        update_ha_status "warning" "Discovery inactive for $TIME_DIFF seconds"
        
        # Check if discovery process is running
        if docker exec nuclei-scanner pgrep -f "network-discovery.sh" >/dev/null; then
            log_message "Process is running but not updating status - attempting restart"
            notify_ha "Discovery process is running but not updating status. Attempting restart..."
            
            # Kill and restart the process
            docker exec nuclei-scanner pkill -f "network-discovery.sh"
            sleep 5
            docker exec nuclei-scanner nohup /home/nuclei/scripts/network-discovery.sh >/dev/null 2>&1 &
        else
            log_message "Process not running - attempting to restart container"
            notify_ha "Discovery process is not running. Restarting container..."
            
            # Restart the container
            docker restart nuclei-scanner
        fi
        
        # Wait for service to restart
        sleep 60
    else
        # Service is running normally
        update_ha_status "active" "Discovery running normally, last update $TIME_DIFF seconds ago"
    fi
    
    # Check again in 5 minutes
    sleep 300
done