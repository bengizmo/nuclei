#!/bin/sh
# Simple scheduler for Nuclei scans

echo "Nuclei Scanner Scheduler"
echo "======================="
echo ""

# Create logs directory
mkdir -p /home/nuclei/logs

while true; do
    current_hour=$(date +%H)
    current_minute=$(date +%M)
    current_day=$(date +%d)
    current_weekday=$(date +%w)
    
    # Daily quick scan at 2:00 AM
    if [ "$current_hour" = "02" ] && [ "$current_minute" = "00" ]; then
        echo "$(date): Running daily quick scan..."
        /home/nuclei/scripts/quick-network-overview.sh >> /home/nuclei/logs/daily.log 2>&1
        sleep 60
    fi
    
    # Daily full scan at 3:00 AM
    if [ "$current_hour" = "03" ] && [ "$current_minute" = "00" ]; then
        echo "$(date): Running daily full scan..."
        /home/nuclei/scripts/improved-multi-vlan-scan.sh >> /home/nuclei/logs/daily.log 2>&1
        sleep 60
    fi
    
    # Weekly comprehensive scan on Sunday at 4:00 AM
    if [ "$current_weekday" = "0" ] && [ "$current_hour" = "04" ] && [ "$current_minute" = "00" ]; then
        echo "$(date): Running weekly comprehensive scan..."
        /home/nuclei/scripts/comprehensive-host-scan.sh 192.168.10.1 udm-pro >> /home/nuclei/logs/weekly.log 2>&1
        /home/nuclei/scripts/comprehensive-host-scan.sh 192.168.10.249 think-tank >> /home/nuclei/logs/weekly.log 2>&1
        sleep 60
    fi
    
    # Monthly device scans on the 1st at 5:00 AM
    if [ "$current_day" = "01" ] && [ "$current_hour" = "05" ] && [ "$current_minute" = "00" ]; then
        echo "$(date): Running monthly device scans..."
        /home/nuclei/scripts/specific-device-scans.sh router >> /home/nuclei/logs/monthly.log 2>&1
        /home/nuclei/scripts/specific-device-scans.sh nas >> /home/nuclei/logs/monthly.log 2>&1
        sleep 60
    fi
    
    # Sleep for 30 seconds between checks
    sleep 30
done