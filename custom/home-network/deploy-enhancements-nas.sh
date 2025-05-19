#!/bin/bash
# Deploy enhanced network discovery system using NAS SSH wrapper

# Load NAS configuration
source ./nas-config.sh

echo "🚀 Deploying enhanced network discovery system to NAS..."

# Configuration
REMOTE_PATH="/volume2/docker/nuclei"
LOCAL_PATH="."

# Create backup directory on NAS
echo "📋 Creating backup of existing scripts..."
${NAS_SSH} "mkdir -p ${REMOTE_PATH}/backups/$(date +%Y%m%d-%H%M%S)"
${NAS_SSH} "cp ${REMOTE_PATH}/scripts/* ${REMOTE_PATH}/backups/$(date +%Y%m%d-%H%M%S)/ 2>/dev/null"

# Copy enhanced scripts to NAS
echo "📤 Copying enhanced scripts to NAS..."
${NAS_SSH} "mkdir -p ${REMOTE_PATH}/scripts"

# Copy enhanced network discovery script
echo "Copying network-discovery.sh..."
cat scripts/network-discovery.sh | ${NAS_SSH} "cat > ${REMOTE_PATH}/scripts/network-discovery.sh"

# Copy enhanced profile script
echo "Copying profile-new-host-enhanced.sh..."
cat scripts/profile-new-host-enhanced.sh | ${NAS_SSH} "cat > ${REMOTE_PATH}/scripts/profile-new-host-enhanced.sh"

# Copy updated AI summary scripts
echo "Copying generate-ai-summary.sh..."
cat scripts/generate-ai-summary.sh | ${NAS_SSH} "cat > ${REMOTE_PATH}/scripts/generate-ai-summary.sh"

echo "Copying generate-device-summary.sh..."
cat scripts/generate-device-summary.sh | ${NAS_SSH} "cat > ${REMOTE_PATH}/scripts/generate-device-summary.sh"

# Make scripts executable
echo "🔧 Setting script permissions..."
${NAS_SSH} "chmod +x ${REMOTE_PATH}/scripts/*.sh"

# Check if PDCP API key is set
echo "🔑 Checking API keys..."
if [ -n "$PDCP_API_KEY" ]; then
    echo "Adding PDCP_API_KEY to container environment..."
    ${NAS_SSH} "grep -v PDCP_API_KEY ${REMOTE_PATH}/.env > ${REMOTE_PATH}/.env.tmp"
    echo "PDCP_API_KEY=$PDCP_API_KEY" | ${NAS_SSH} "cat >> ${REMOTE_PATH}/.env.tmp"
    ${NAS_SSH} "mv ${REMOTE_PATH}/.env.tmp ${REMOTE_PATH}/.env"
    echo "✅ PDCP API key configured"
else
    echo "⚠️  PDCP_API_KEY not set - AI template generation will be disabled"
fi

# Recreate the container to load new scripts
echo "🐳 Recreating Docker container with enhanced scripts..."
${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} down"
${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} up -d"

# Wait for container to start
echo "⏳ Waiting for container to start..."
sleep 5

# Verify deployment
echo "✅ Verifying deployment..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner ls -la /home/nuclei/scripts/" || echo "Container not ready yet"

# Start network discovery service
echo "🔍 Starting enhanced network discovery service..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/network-discovery.sh > /home/nuclei/logs/discovery.log 2>&1 &"

# Check if discovery is running
sleep 2
echo "📊 Checking discovery service status..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pgrep -f network-discovery.sh" && echo "✅ Discovery service is running" || echo "❌ Discovery service not running"

# Check recent logs
echo "📜 Recent discovery logs:"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner tail -10 /home/nuclei/logs/discovery.log"

echo ""
echo "✨ Deployment complete!"
echo ""
echo "Enhanced features enabled:"
echo "- ✅ No notifications for new device discovery"
echo "- ✅ Automatic scanning of newly discovered devices"
echo "- ✅ Concise AI summaries (under 200 chars for secure networks)"
if [ -n "$PDCP_API_KEY" ]; then
    echo "- ✅ ProjectDiscovery AI template generation enabled"
else
    echo "- ❌ ProjectDiscovery AI template generation disabled (no API key)"
fi
echo ""
echo "Monitor the system:"
echo "  View discovery: ${NAS_SSH} '${DOCKER_BIN} exec nuclei-scanner tail -f /home/nuclei/logs/discovery.log'"
echo "  View devices:   ${NAS_SSH} '${DOCKER_BIN} exec nuclei-scanner cat /home/nuclei/discovery/discovery.db | column -t -s \"|\"'"
echo ""
echo "To test the system:"
echo "  1. Connect a new device to the network"
echo "  2. Wait up to 5 minutes for discovery"
echo "  3. Check logs for automatic profiling and scanning"