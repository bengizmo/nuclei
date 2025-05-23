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
    pkill -f "network-discovery" || true
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
        sed -i "s/SCAN_INTERVAL=300/SCAN_INTERVAL=$DISCOVERY_INTERVAL/" /home/nuclei/scripts/network-discovery-resilient.sh
    fi
    
    # Launch discovery in background with restart capability
    (
        while true; do
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting/restarting network discovery process..." | tee -a /home/nuclei/logs/discovery-watchdog.log
            sh /home/nuclei/scripts/network-discovery-resilient.sh &
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
    
    # Start enhanced monitoring service
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting enhanced monitoring service..." | tee -a /home/nuclei/logs/container.log
    (sh /home/nuclei/scripts/enhanced-monitor.sh &)
    notify_ha "Enhanced monitoring service started"
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
                # Use the new robust scan script
                if [ -x "/home/nuclei/scripts/scan-with-ha-robust.sh" ]; then
                    sh /home/nuclei/scripts/scan-with-ha-robust.sh
                else
                    sh /home/nuclei/scripts/scan-with-ha-modern.sh
                fi
                
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

# Run a scan immediately on startup if needed
if [ "${RUN_SCAN_ON_STARTUP}" = "true" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running startup scan..." | tee -a /home/nuclei/logs/container.log
    
    # Run the scan in background
    (
        # Wait 30 seconds for container to fully initialize
        sleep 30
        
        # Use robust scan script if available
        if [ -x "/home/nuclei/scripts/scan-with-ha-robust.sh" ]; then
            sh /home/nuclei/scripts/scan-with-ha-robust.sh
        else
            sh /home/nuclei/scripts/scan-with-ha-modern.sh
        fi
    ) &
    
    notify_ha "Startup scan initiated"
fi

# Set up additional scan at 15:00 (3:00 PM) for better coverage
if [ "${MULTIPLE_DAILY_SCANS}" = "true" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting up additional scan at 15:00" | tee -a /home/nuclei/logs/container.log
    
    # Set up additional scan
    (
        while true; do
            # Get current hour and minute
            HOUR=$(date +%H)
            MIN=$(date +%M)
            
            # If it's 15:00, run the scan
            if [ "$HOUR" = "15" ] && [ "$MIN" = "00" ]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running afternoon scan..." | tee -a /home/nuclei/logs/afternoon-scan.log
                # Use the new robust scan script
                if [ -x "/home/nuclei/scripts/scan-with-ha-robust.sh" ]; then
                    sh /home/nuclei/scripts/scan-with-ha-robust.sh
                else
                    sh /home/nuclei/scripts/scan-with-ha-modern.sh
                fi
                
                # Wait until it's not 15:00 anymore to avoid multiple executions
                while [ "$(date +%H)" = "15" ] && [ "$(date +%M)" = "00" ]; do
                    sleep 30
                done
            fi
            
            # Check every minute
            sleep 60
        done
    ) &
    
    notify_ha "Multiple daily scans enabled (3:00 AM and 3:00 PM)"
fi

# Set up weekly email summary (Sunday at 5:00 AM)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting up weekly email summary..." | tee -a /home/nuclei/logs/container.log

(
    while true; do
        # Get current day and time
        DAY=$(date +%u)  # 1=Monday, 7=Sunday
        HOUR=$(date +%H)
        MIN=$(date +%M)
        
        # If it's Sunday (7) at 5:00 AM, send weekly summary
        if [ "$DAY" = "7" ] && [ "$HOUR" = "05" ] && [ "$MIN" = "00" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sending weekly email summary..." | tee -a /home/nuclei/logs/weekly-email.log
            
            # Send weekly summary
            if [ -x "/home/nuclei/scripts/email-notifications.sh" ]; then
                /home/nuclei/scripts/email-notifications.sh weekly-summary >> /home/nuclei/logs/weekly-email.log 2>&1
            else
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Email notification script not found" | tee -a /home/nuclei/logs/weekly-email.log
            fi
            
            # Wait until it's not 5:00 AM anymore to avoid multiple executions
            while [ "$(date +%H)" = "05" ] && [ "$(date +%M)" = "00" ]; do
                sleep 30
            done
        fi
        
        # Check every minute
        sleep 60
    done
) &

notify_ha "Weekly email summary scheduled for Sundays at 5:00 AM"

# Keep container running
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Entrypoint completed, container running..." | tee -a /home/nuclei/logs/container.log

# Stay alive - better than sleep infinity as it handles signals properly
while true; do
    sleep 3600 &
    wait $!
done