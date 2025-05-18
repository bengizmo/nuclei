#!/bin/sh
# Setup scheduled scans for Nuclei

echo "Setting up scheduled scans..."

# Create cron jobs file
cat > /tmp/nuclei-cron.txt <<EOF
# Nuclei Security Scanner Schedule
# Format: minute hour day month weekday command

# Daily quick overview scan at 2 AM
0 2 * * * docker exec nuclei-scanner /home/nuclei/scripts/quick-network-overview.sh >> /volume2/docker/nuclei/logs/cron.log 2>&1

# Daily critical infrastructure scan at 3 AM
0 3 * * * docker exec nuclei-scanner /home/nuclei/scripts/improved-multi-vlan-scan.sh >> /volume2/docker/nuclei/logs/cron.log 2>&1

# Weekly comprehensive scan on Sundays at 4 AM
0 4 * * 0 docker exec nuclei-scanner /home/nuclei/scripts/comprehensive-host-scan.sh 192.168.10.1 udm-pro >> /volume2/docker/nuclei/logs/cron.log 2>&1
30 4 * * 0 docker exec nuclei-scanner /home/nuclei/scripts/comprehensive-host-scan.sh 192.168.10.249 think-tank >> /volume2/docker/nuclei/logs/cron.log 2>&1

# Monthly device-specific scans on the 1st at 5 AM
0 5 1 * * docker exec nuclei-scanner /home/nuclei/scripts/specific-device-scans.sh router >> /volume2/docker/nuclei/logs/cron.log 2>&1
30 5 1 * * docker exec nuclei-scanner /home/nuclei/scripts/specific-device-scans.sh nas >> /volume2/docker/nuclei/logs/cron.log 2>&1

# Test scan every hour (can be disabled after testing)
# 0 * * * * docker exec nuclei-scanner echo "Nuclei scanner is running at $(date)" >> /volume2/docker/nuclei/logs/test.log 2>&1
EOF

echo "Cron configuration created. To install on NAS:"
echo "1. SSH to your NAS"
echo "2. Run: crontab -e"
echo "3. Add the contents from /tmp/nuclei-cron.txt"
echo ""
echo "Or run: cat /tmp/nuclei-cron.txt | crontab -"