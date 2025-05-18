#!/bin/bash
# Setup scheduled scans on NAS

source ./nas-config.sh

echo "Setting up scheduled scans for Nuclei..."
echo ""

# Create schedule directory
${NAS_SSH} "mkdir -p /volume2/docker/nuclei/schedule"

# Copy scheduler script
cat scripts/scheduler.sh | ${NAS_SSH} "cat > /volume2/docker/nuclei/schedule/scheduler.sh"
${NAS_SSH} "chmod +x /volume2/docker/nuclei/schedule/scheduler.sh"

# Create simple cron entry
cat > cron-nuclei.txt <<EOF
# Nuclei Security Scanner - Daily scan at 3 AM
0 3 * * * ${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/improved-multi-vlan-scan.sh >> /volume2/docker/nuclei/logs/cron.log 2>&1

# Quick scan every 6 hours
0 */6 * * * ${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/quick-network-overview.sh >> /volume2/docker/nuclei/logs/quick.log 2>&1

# Weekly comprehensive scan on Sundays at 4 AM
0 4 * * 0 ${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/comprehensive-host-scan.sh 192.168.10.249 think-tank >> /volume2/docker/nuclei/logs/weekly.log 2>&1
EOF

echo "Cron configuration created in: cron-nuclei.txt"
echo ""
echo "To set up scheduled scans, choose one option:"
echo ""
echo "Option 1: Use cron (recommended)"
echo "  1. SSH to NAS: ssh-nas"
echo "  2. Edit crontab: crontab -e"
echo "  3. Add contents from cron-nuclei.txt"
echo ""
echo "Option 2: Run scheduler in container"
echo "  ${NAS_SSH} '${DOCKER_BIN} exec -d nuclei-scanner /home/nuclei/scripts/scheduler.sh'"
echo ""
echo "Option 3: Use Synology Task Scheduler"
echo "  1. Open Synology Control Panel"
echo "  2. Go to Task Scheduler"
echo "  3. Create task to run:"
echo "     ${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/improved-multi-vlan-scan.sh"
echo ""
echo "To test a scan now:"
echo "./manage-remote.sh scan"