#!/bin/sh
# Test scheduler with more frequent scans

echo "Test Scheduler Starting at $(date)"

# Create logs directory
mkdir -p /home/nuclei/logs

while true; do
    # Run a test scan every 5 minutes
    if [ $(($(date +%M) % 5)) -eq 0 ]; then
        echo "$(date): Running test scan..." | tee -a /home/nuclei/logs/test-scheduler.log
        /home/nuclei/scripts/quick-network-overview.sh > /home/nuclei/logs/test-scan-$(date +%Y%m%d-%H%M%S).log 2>&1
        sleep 60
    fi
    
    # Sleep for 30 seconds
    sleep 30
done