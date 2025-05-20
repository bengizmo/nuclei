#!/bin/bash
# Script to deploy Home Assistant integration changes to NAS container

echo "🚀 Deploying Home Assistant Integration to NAS"
echo "============================================="
echo ""

# Source configuration
source ./nas-config.sh

# Verify connection to NAS
echo "1. Verifying NAS connection..."
if ${NAS_SSH} "echo Connected successfully"; then
    echo "✅ Connected to NAS at ${NAS_HOST}"
else
    echo "❌ Failed to connect to NAS"
    exit 1
fi

# Create temporary directory for files
echo ""
echo "2. Preparing deployment files..."
TEMP_DIR=$(mktemp -d)
cp scripts/ha-sensor-update.sh "${TEMP_DIR}/"
cp scripts/scan-with-ha-multi.sh "${TEMP_DIR}/"

# Create wrapper script to update all sensors
cat > "${TEMP_DIR}/update-ha-multi-entities.sh" << 'EOF'
#!/bin/sh
# One-time script to update all Nuclei HA entities from inside the container

# Update all sensors using ha-sensor-update.sh
/home/nuclei/scripts/ha-sensor-update.sh "idle" "0" "0" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"

echo "All Home Assistant entities updated successfully!"
EOF

# Make all scripts executable
chmod +x "${TEMP_DIR}"/*.sh

# Deploy scripts to NAS Docker volume
echo ""
echo "3. Deploying scripts to NAS..."
${NAS_SSH} "mkdir -p /volume2/docker/nuclei/scripts"
scp "${TEMP_DIR}"/*.sh ${NAS_USER}@${NAS_HOST}:/volume2/docker/nuclei/scripts/

# Copy scripts from NAS volume to container
echo ""
echo "4. Installing scripts in container..."
${NAS_SSH} "cd /volume2/docker/nuclei && ${DOCKER_BIN} exec -w /home/nuclei/scripts nuclei-scanner sh -c 'chmod +x /home/nuclei/scripts/*.sh'"

# Run the update script inside the container
echo ""
echo "5. Updating Home Assistant entities from container..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/update-ha-multi-entities.sh"

# Clean up
rm -rf "${TEMP_DIR}"

echo ""
echo "============================================="
echo "✅ Deployment complete!"
echo ""
echo "The system now uses 6 separate Home Assistant entities:"
echo "1. sensor.nuclei_scanner - Main aggregated sensor"
echo "2. sensor.nuclei_scanner_status - Current status"
echo "3. sensor.nuclei_scanner_findings - Vulnerability count"
echo "4. sensor.nuclei_scanner_hosts - Hosts scanned"
echo "5. sensor.nuclei_scanner_last_scan - Timestamp"
echo "6. sensor.nuclei_scanner_summary - Text summary"
echo ""
echo "To check the entities, run: ./scripts/check-sensors.sh"
echo "To update the entities manually, run: ./restore-multiple-entities.sh"