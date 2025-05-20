#!/bin/sh
# Entrypoint script for Nuclei container
# Handles startup of discovery service and sets up scheduled scans

# Create required directories
mkdir -p /home/nuclei/logs
mkdir -p /home/nuclei/discovery
mkdir -p /home/nuclei/results

# Log startup
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Container starting..." | tee -a /home/nuclei/logs/container.log

# Function to send HA notification
notify_ha() {
    if [ -n "$HOME_ASSISTANT_API_TOKEN" ]; then
        curl -s -X POST \
            -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{
                \"message\": \"$1\",
                \"title\": \"Nuclei Scanner\",
                \"data\": {
                    \"tag\": \"nuclei-system\"
                }
            }" \
            "http://192.168.10.89:8123/api/services/notify/notify"
    fi
}

# Function to update HA entity
update_ha_entity() {
    if [ -n "$HOME_ASSISTANT_API_TOKEN" ]; then
        curl -s -X POST \
            -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{
                \"state\": \"$1\",
                \"attributes\": {
                    \"friendly_name\": \"Nuclei Scanner\",
                    \"icon\": \"mdi:shield-search\",
                    \"status\": \"$2\",
                    \"discovery_enabled\": \"${NETWORK_DISCOVERY_ENABLED:-false}\",
                    \"daily_scan_enabled\": \"${DAILY_SCAN_ENABLED:-false}\",
                    \"last_container_start\": \"$(date -Iseconds)\"
                }
            }" \
            "http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_system"
    fi
}

# Handle system signals
handle_sigterm() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Received SIGTERM, shutting down..." | tee -a /home/nuclei/logs/container.log
    # Kill any running discovery process
    pkill -f "network-discovery.sh" || true
    notify_ha "Nuclei scanner service stopping"
    exit 0
}

# Set up signal handler
trap handle_sigterm SIGTERM SIGINT

# Start discovery service if enabled
if [ "${NETWORK_DISCOVERY_ENABLED}" = "true" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting network discovery service..." | tee -a /home/nuclei/logs/container.log
    
    # Check for custom interval
    if [ -n "$DISCOVERY_INTERVAL" ]; then
        echo "Setting custom discovery interval: $DISCOVERY_INTERVAL seconds"
        sed -i "s/SCAN_INTERVAL=300/SCAN_INTERVAL=$DISCOVERY_INTERVAL/" /home/nuclei/scripts/network-discovery.sh
    fi
    
    # Launch discovery in background with restart capability
    (
        while true; do
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting/restarting network discovery process..." | tee -a /home/nuclei/logs/discovery-watchdog.log
            sh /home/nuclei/scripts/network-discovery.sh &
            DISCOVERY_PID=$!
            
            # Wait for process to end
            wait $DISCOVERY_PID
            
            # If process ended, log and restart after delay
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Discovery process exited, restarting in 60 seconds..." | tee -a /home/nuclei/logs/discovery-watchdog.log
            notify_ha "Network discovery service restarting after unexpected exit"
            sleep 60
        done
    ) &
    
    notify_ha "Network discovery service started"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Network discovery service disabled" | tee -a /home/nuclei/logs/container.log
fi

# Set up daily scan if enabled
if [ "${DAILY_SCAN_ENABLED}" = "true" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting up daily scan at 3:00 AM" | tee -a /home/nuclei/logs/container.log
    
    # Set up cron job for daily scan
    (
        # Run scan at 3:00 AM every day
        while true; do
            # Get current hour and minute
            HOUR=$(date +%H)
            MIN=$(date +%M)
            
            # If it's 3:00 AM, run the scan
            if [ "$HOUR" = "03" ] && [ "$MIN" = "00" ]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running daily scan..." | tee -a /home/nuclei/logs/daily-scan.log
                sh /home/nuclei/scripts/scan-with-ha-modern.sh
                
                # Wait until it's not 3:00 anymore to avoid multiple executions
                while [ "$(date +%H)" = "03" ] && [ "$(date +%M)" = "00" ]; do
                    sleep 30
                done
            fi
            
            # Check every minute
            sleep 60
        done
    ) &
    
    notify_ha "Daily scan service started (scheduled for 3:00 AM)"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Daily scan disabled" | tee -a /home/nuclei/logs/container.log
fi

# Update HA entity with startup info
update_ha_entity "running" "Container started at $(date)"

# Keep container running
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Entrypoint completed, container running..." | tee -a /home/nuclei/logs/container.log

# Stay alive - better than sleep infinity as it handles signals properly
while true; do
    sleep 3600 &
    wait $!
done