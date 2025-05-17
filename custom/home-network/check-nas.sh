#!/bin/bash
# Quick status check for Nuclei on NAS

# Load configuration
source ./nas-config.sh

REMOTE_PATH="/volume2/docker/nuclei"

echo "🔍 Checking Nuclei scanner on NAS..."
echo "🔗 Connecting to: ${NAS_SSH}"
echo ""

# Check if directory exists
echo "📁 Checking deployment directory..."
${NAS_SSH} "[ -d ${REMOTE_PATH} ] && echo '✓ Directory exists' || echo '✗ Directory not found'"

# Check container status
echo ""
echo "🐳 Container status:"
${NAS_SSH} "cd ${REMOTE_PATH} 2>/dev/null && ${DOCKER_COMPOSE_BIN} ps" || echo "✗ Not deployed"

# Check recent scan results
echo ""
echo "📊 Recent scan activity:"
${NAS_SSH} "ls -la ${REMOTE_PATH}/results/ 2>/dev/null | tail -5" || echo "✗ No results found"

# Check network connectivity to critical hosts
echo ""
echo "🌐 Network connectivity from NAS:"
${NAS_SSH} "ping -c 1 192.168.10.1 >/dev/null 2>&1 && echo '✓ UDM PRO reachable' || echo '✗ UDM PRO not reachable'"
${NAS_SSH} "ping -c 1 192.168.10.89 >/dev/null 2>&1 && echo '✓ Home Assistant reachable' || echo '✗ Home Assistant not reachable'"

echo ""
echo "Ready to deploy? Run: ./manage-remote.sh deploy"