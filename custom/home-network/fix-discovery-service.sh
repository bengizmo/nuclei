#!/bin/bash
# Script to fix the network discovery service issue
source ./nas-config.sh

echo "🔄 Updating discovery service configuration on NAS..."

# Create necessary directories if they don't exist
${NAS_SSH} "mkdir -p /volume2/docker/nuclei/logs"
${NAS_SSH} "mkdir -p /volume2/docker/nuclei/discovery"

# Copy the updated docker-compose file
scp docker-compose-vlans.yml ${NAS_USER}@${NAS_HOST}:/volume2/docker/nuclei/docker-compose.yml

# Copy entrypoint.sh to ensure it's available
scp entrypoint.sh ${NAS_USER}@${NAS_HOST}:/volume2/docker/nuclei/entrypoint.sh
${NAS_SSH} "chmod +x /volume2/docker/nuclei/entrypoint.sh"

# Restart the container to apply changes
echo "🔄 Restarting container to apply changes..."
${NAS_SSH} "cd /volume2/docker/nuclei && ${DOCKER_COMPOSE_BIN} down && ${DOCKER_COMPOSE_BIN} up -d"

# Wait for container to start
echo "⏳ Waiting for container to start..."
sleep 5

# Check if discovery service is running
echo "🔍 Checking if discovery service is running..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pgrep -f network-discovery.sh" > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Discovery service is now running!"
else
    echo "❌ Discovery service is still not running. Starting it manually..."
    ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner nohup /home/nuclei/scripts/network-discovery.sh >/dev/null 2>&1 &"
    
    # Verify again
    sleep 3
    ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pgrep -f network-discovery.sh" > /dev/null
    if [ $? -eq 0 ]; then
        echo "✅ Discovery service successfully started manually!"
    else
        echo "❌ Unable to start discovery service. Additional debugging required."
        echo "Check container logs with: ./manage-remote.sh logs"
    fi
fi

# Check discovery service status via status file
echo "📊 Current discovery status:"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner cat /home/nuclei/discovery/status.json"

echo ""
echo "Done! Verify the service is working with: ./verify-enhancements.sh"