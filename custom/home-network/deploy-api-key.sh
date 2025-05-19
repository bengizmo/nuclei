#!/bin/bash
# Deploy PDCP API key to NAS

# Load NAS configuration
source ./nas-config.sh

echo "🔑 Deploying PDCP API key to NAS..."

# Configuration
REMOTE_PATH="/volume2/docker/nuclei"
PDCP_API_KEY="b1e5b881-f0b7-4cf8-95b3-05de6b978052"

# Update .env file on NAS
echo "📝 Updating environment file..."
${NAS_SSH} "cd ${REMOTE_PATH} && grep -v PDCP_API_KEY .env > .env.tmp 2>/dev/null || true"
echo "PDCP_API_KEY=${PDCP_API_KEY}" | ${NAS_SSH} "cat >> ${REMOTE_PATH}/.env.tmp"
${NAS_SSH} "cd ${REMOTE_PATH} && mv .env.tmp .env"

# Restart container to load new environment
echo "🐳 Restarting container with API key..."
${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} restart"

# Wait for container to start
echo "⏳ Waiting for container to start..."
sleep 10

# Verify API key is loaded
echo "✅ Verifying API key deployment..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner printenv | grep PDCP_API_KEY" > /dev/null
if [ $? -eq 0 ]; then
    echo "   ✅ PDCP API key is loaded in container"
else
    echo "   ❌ PDCP API key not found in container"
fi

# Restart discovery service to use new API key
echo "🔄 Restarting discovery service..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pkill -f network-discovery.sh"
${NAS_SSH} "${DOCKER_BIN} exec -d nuclei-scanner /home/nuclei/scripts/network-discovery.sh"

echo ""
echo "✨ API key deployment complete!"
echo ""
echo "The system now has AI-powered template generation enabled:"
echo "- ProjectDiscovery Cloud Platform API integrated"
echo "- Custom AI templates will be generated for each device type"
echo "- Better vulnerability coverage with intelligent template selection"