#!/bin/bash
# Complete deployment of enhanced network discovery system with PDCP API

# Load NAS configuration
source ./nas-config.sh

echo "🚀 Deploying Complete Enhanced Network Discovery System"
echo "====================================================="
echo ""

# Configuration
REMOTE_PATH="/volume2/docker/nuclei"
PDCP_API_KEY="b1e5b881-f0b7-4cf8-95b3-05de6b978052"

# Create backup
echo "📋 Creating backup..."
${NAS_SSH} "mkdir -p ${REMOTE_PATH}/backups/$(date +%Y%m%d-%H%M%S)"
${NAS_SSH} "cp -r ${REMOTE_PATH}/scripts ${REMOTE_PATH}/backups/$(date +%Y%m%d-%H%M%S)/ 2>/dev/null"

# Deploy all enhanced scripts
echo "📤 Deploying enhanced scripts..."
${NAS_SSH} "mkdir -p ${REMOTE_PATH}/scripts"

for script in scripts/*.sh; do
    if [ -f "$script" ]; then
        echo "   Copying $(basename $script)..."
        cat "$script" | ${NAS_SSH} "cat > ${REMOTE_PATH}/$script"
    fi
done

# Set permissions
echo "🔧 Setting permissions..."
${NAS_SSH} "chmod +x ${REMOTE_PATH}/scripts/*.sh"

# Deploy API key
echo "🔑 Deploying PDCP API key..."
echo "PDCP_API_KEY=${PDCP_API_KEY}" | ${NAS_SSH} "cat >> ${REMOTE_PATH}/.env.tmp"
echo "HOME_ASSISTANT_API_TOKEN=\${HOME_ASSISTANT_API_TOKEN}" | ${NAS_SSH} "cat >> ${REMOTE_PATH}/.env.tmp"
${NAS_SSH} "mv ${REMOTE_PATH}/.env.tmp ${REMOTE_PATH}/.env"

# Restart container
echo "🐳 Restarting container..."
${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} down"
${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} up -d"

# Wait for container
echo "⏳ Waiting for container to start..."
sleep 10

# Initialize discovery service
echo "🔍 Starting discovery service..."
${NAS_SSH} "${DOCKER_BIN} exec -d nuclei-scanner /home/nuclei/scripts/network-discovery.sh"

# Verify deployment
echo ""
echo "✅ Verification:"
echo ""

# Check services
DISCOVERY_PID=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pgrep -f network-discovery.sh")
if [ -n "$DISCOVERY_PID" ]; then
    echo "✅ Discovery service running (PID: $DISCOVERY_PID)"
else
    echo "❌ Discovery service not running"
fi

# Check API key
API_KEY_CHECK=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner printenv | grep PDCP_API_KEY")
if [ -n "$API_KEY_CHECK" ]; then
    echo "✅ PDCP API key configured"
else
    echo "❌ PDCP API key missing"
fi

echo ""
echo "=========================================="
echo "✨ Deployment Complete!"
echo ""
echo "Enhanced features enabled:"
echo "✅ Silent device discovery (no new device notifications)"
echo "✅ Automatic device profiling and scanning"
echo "✅ AI-powered template generation with PDCP API"
echo "✅ Concise AI summaries (under 200 chars when secure)"
echo "✅ Notifications only for actual vulnerabilities"
echo ""
echo "Monitor the system:"
echo "  Logs:     ${NAS_SSH} '${DOCKER_BIN} exec nuclei-scanner tail -f /home/nuclei/logs/discovery.log'"
echo "  Devices:  ${NAS_SSH} '${DOCKER_BIN} exec nuclei-scanner cat /home/nuclei/discovery/discovery.db | column -t -s \"|\"'"
echo "  Status:   ./verify-enhancements.sh"
echo ""