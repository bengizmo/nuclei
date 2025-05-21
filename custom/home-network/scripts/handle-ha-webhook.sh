#!/bin/bash
# Handle Home Assistant webhook for manual scan trigger
# This script should be called by a webhook server or cron job

# Log start with timestamp
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Home Assistant webhook handler triggered" >> /home/nuclei/logs/ha-webhook.log

# Run the scan
if [ -x "/home/nuclei/scripts/scan-with-ha-robust.sh" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting robust scan via webhook trigger" >> /home/nuclei/logs/ha-webhook.log
    
    # Run scan in background to allow webhook to return quickly
    nohup /home/nuclei/scripts/scan-with-ha-robust.sh > /home/nuclei/logs/webhook-scan-$(date +%Y%m%d-%H%M%S).log 2>&1 &
    
    # Store PID for potential future use
    echo $! > /home/nuclei/webhook-scan.pid
    
    # Log success
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Scan started successfully with PID $!" >> /home/nuclei/logs/ha-webhook.log
    exit 0
else
    # Try the modern script as fallback
    if [ -x "/home/nuclei/scripts/scan-with-ha-modern.sh" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting modern scan via webhook trigger (robust scan not found)" >> /home/nuclei/logs/ha-webhook.log
        
        # Run scan in background
        nohup /home/nuclei/scripts/scan-with-ha-modern.sh > /home/nuclei/logs/webhook-scan-$(date +%Y%m%d-%H%M%S).log 2>&1 &
        
        # Store PID for potential future use
        echo $! > /home/nuclei/webhook-scan.pid
        
        # Log success
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Scan started successfully with PID $!" >> /home/nuclei/logs/ha-webhook.log
        exit 0
    else
        # No scan script found
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: No scan script found! Webhook trigger failed." >> /home/nuclei/logs/ha-webhook.log
        exit 1
    fi
fi