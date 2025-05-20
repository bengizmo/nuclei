#!/bin/bash
# Script to update services and restart container

# Load NAS configuration
source ./nas-config.sh

echo "Updating Nuclei services..."

# Ensure directories exist
${NAS_SSH} "mkdir -p /volume2/docker/nuclei/scripts"
${NAS_SSH} "mkdir -p /volume2/docker/nuclei/logs"
${NAS_SSH} "mkdir -p /volume2/docker/nuclei/discovery"

# Copy service files to NAS
scp schedule/nuclei-scan.service ${NAS_USER}@${NAS_HOST}:/tmp/nuclei-scan.service
scp schedule/monitor.service ${NAS_USER}@${NAS_HOST}:/tmp/monitor.service

# Move service files to system location - use echo for testing since this may need sudo
echo "Would install service files with:"
echo "mv /tmp/nuclei-scan.service /etc/systemd/system/"
echo "mv /tmp/monitor.service /etc/systemd/system/"
echo "systemctl daemon-reload"
echo "systemctl enable nuclei-scan.service"
echo "systemctl enable monitor.service"

# Copy updated scripts
echo "Copying updated scripts and configuration..."
scp -r scripts/* ${NAS_USER}@${NAS_HOST}:/volume2/docker/nuclei/scripts/
scp entrypoint.sh ${NAS_USER}@${NAS_HOST}:/volume2/docker/nuclei/

# Update permissions
${NAS_SSH} "chmod +x /volume2/docker/nuclei/scripts/*.sh || true"
${NAS_SSH} "chmod +x /volume2/docker/nuclei/entrypoint.sh || true"

# Update docker-compose.yml
scp docker-compose.yml ${NAS_USER}@${NAS_HOST}:/volume2/docker/nuclei/

# Restart container to apply changes - use echo for testing
echo "Would restart container with:"
echo "cd /volume2/docker/nuclei && docker-compose down && docker-compose up -d"

# Start services - use echo for testing
echo "Would start monitoring service with:"
echo "systemctl start monitor.service"

echo "Configuration files copied successfully!"
echo ""
echo "To manually complete installation and start services:"
echo ""
echo "1. SSH to your NAS: ssh ${NAS_USER}@${NAS_HOST}"
echo "2. Install service files:"
echo "   sudo mv /tmp/nuclei-scan.service /etc/systemd/system/"
echo "   sudo mv /tmp/monitor.service /etc/systemd/system/"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl enable nuclei-scan.service"
echo "   sudo systemctl enable monitor.service"
echo ""
echo "3. Restart the container:"
echo "   cd /volume2/docker/nuclei && docker-compose down && docker-compose up -d"
echo ""
echo "4. Start the monitor service:"
echo "   sudo systemctl start monitor.service"
echo ""
echo "To verify the installation:"
echo "1. Check container logs: docker logs nuclei-scanner"
echo "2. Check discovery status: cat /volume2/docker/nuclei/discovery/status.json"
echo "3. Verify monitor service: sudo systemctl status monitor.service"
echo "4. Check Home Assistant for new sensors"
echo ""
echo "If needed, you can manually trigger a scan with:"
echo "sudo systemctl start nuclei-scan.service"