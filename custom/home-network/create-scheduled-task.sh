#!/bin/bash
# Create scheduled scan task on Synology NAS

source ./nas-config.sh

echo "Creating scheduled scan task..."

# Create task script
cat > task-script.sh <<'EOF'
#!/bin/bash
# Nuclei scheduled scan

LOG_DIR="/volume2/docker/nuclei/logs"
mkdir -p "$LOG_DIR"

DATE=$(date +%Y%m%d-%H%M%S)
echo "$DATE: Starting scheduled scan" >> "$LOG_DIR/scheduled.log"

# Run the scan
/usr/local/bin/docker exec nuclei-scanner /home/nuclei/scripts/improved-multi-vlan-scan.sh >> "$LOG_DIR/scan-$DATE.log" 2>&1

echo "$DATE: Scan completed" >> "$LOG_DIR/scheduled.log"
EOF

# Copy to NAS
cat task-script.sh | ${NAS_SSH} "cat > /volume2/docker/nuclei/scheduled-scan.sh"
${NAS_SSH} "chmod +x /volume2/docker/nuclei/scheduled-scan.sh"

echo ""
echo "Task script created at: /volume2/docker/nuclei/scheduled-scan.sh"
echo ""
echo "To schedule this task:"
echo "1. Log into Synology DSM"
echo "2. Open Control Panel > Task Scheduler"
echo "3. Create > Scheduled Task > User-defined Script"
echo "4. Task Settings:"
echo "   - Name: Nuclei Security Scan"
echo "   - User: root"
echo "   - Schedule: Daily at 3:00 AM (or your preference)"
echo "   - Task Settings > Run command:"
echo "     /volume2/docker/nuclei/scheduled-scan.sh"
echo ""
echo "Alternative: Manual test"
echo "${NAS_SSH} '/volume2/docker/nuclei/scheduled-scan.sh'"