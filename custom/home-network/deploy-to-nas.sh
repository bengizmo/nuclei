#!/bin/bash
# Deploy all Nuclei files to NAS and start the container
# This script will set up everything needed on the NAS

cd "$(dirname "$0")"
source ./nas-config.sh

echo "🚀 Deploying Nuclei Scanner to NAS"
echo "=================================="

# Create directories
echo "1. Creating directories on NAS..."
ssh "${NAS_USER}@${NAS_HOST}" "mkdir -p /volume1/docker/nuclei/scripts /volume1/docker/nuclei/logs /volume1/docker/nuclei/results /volume1/docker/nuclei/discovery"

# Copy docker-compose.yml
echo "2. Copying docker-compose.yml..."
scp ./docker-compose.yml "${NAS_USER}@${NAS_HOST}:/volume1/docker/nuclei/"

# Copy entrypoint script
echo "3. Copying entrypoint script..."
scp ./entrypoint.sh "${NAS_USER}@${NAS_HOST}:/volume1/docker/nuclei/"
ssh "${NAS_USER}@${NAS_HOST}" "chmod +x /volume1/docker/nuclei/entrypoint.sh"

# Copy all scripts
echo "4. Copying scripts..."
scp ./scripts/*.sh "${NAS_USER}@${NAS_HOST}:/volume1/docker/nuclei/scripts/"
ssh "${NAS_USER}@${NAS_HOST}" "chmod +x /volume1/docker/nuclei/scripts/*.sh"

# Copy .env file if it exists
if [ -f .env ]; then
    echo "5. Copying .env file..."
    scp ./.env "${NAS_USER}@${NAS_HOST}:/volume1/docker/nuclei/"
else
    echo "5. Creating .env file..."
    ssh "${NAS_USER}@${NAS_HOST}" "cat > /volume1/docker/nuclei/.env << 'EOF'
HOME_ASSISTANT_API_TOKEN=${HOME_ASSISTANT_API_TOKEN}
PDCP_API_KEY=${PDCP_API_KEY:-}
EOF"
fi

# Copy critical hosts if it exists
if [ -f critical-hosts.txt ]; then
    echo "6. Copying critical hosts file..."
    scp ./critical-hosts.txt "${NAS_USER}@${NAS_HOST}:/volume1/docker/nuclei/"
else
    echo "6. Creating default critical hosts file..."
    ssh "${NAS_USER}@${NAS_HOST}" "cat > /volume1/docker/nuclei/critical-hosts.txt << 'EOF'
# Critical hosts for priority scanning
192.168.10.89
192.168.10.163
EOF"
fi

# Start the container
echo "7. Starting Nuclei container..."
ssh "${NAS_USER}@${NAS_HOST}" "cd /volume1/docker/nuclei && docker-compose up -d"

# Wait for container to start
echo "8. Waiting for container to start..."
sleep 10

# Check if container is running
CONTAINER_STATUS=$(ssh "${NAS_USER}@${NAS_HOST}" "docker ps --filter name=nuclei-scanner --format '{{.Status}}'" 2>/dev/null)

if [ -n "$CONTAINER_STATUS" ]; then
    echo "   ✅ Container started successfully: $CONTAINER_STATUS"
    
    # Test the script in the container
    echo "9. Testing scan script in container..."
    SCRIPT_TEST=$(ssh "${NAS_USER}@${NAS_HOST}" "docker exec nuclei-scanner test -x /home/nuclei/scripts/scan-with-ha-robust.sh && echo 'executable' || echo 'not-executable'" 2>/dev/null)
    
    if [ "$SCRIPT_TEST" = "executable" ]; then
        echo "   ✅ Scan script is executable in container"
    else
        echo "   ❌ Scan script is not executable in container"
        echo "   Fixing permissions..."
        ssh "${NAS_USER}@${NAS_HOST}" "docker exec nuclei-scanner chmod +x /home/nuclei/scripts/*.sh"
    fi
    
else
    echo "   ❌ Container failed to start"
    echo "   Checking logs..."
    ssh "${NAS_USER}@${NAS_HOST}" "docker logs nuclei-scanner"
fi

echo ""
echo "=================================="
echo "Deployment complete!"
echo ""
echo "Container status:"
ssh "${NAS_USER}@${NAS_HOST}" "docker ps --filter name=nuclei-scanner"
echo ""
echo "You can now test the Home Assistant scan button."
echo "The container should be running and ready to receive scan commands."