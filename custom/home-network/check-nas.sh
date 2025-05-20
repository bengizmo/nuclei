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

# Check discovery info
echo ""
echo "🔍 Discovery status:"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner cat /home/nuclei/discovery/status.json 2>/dev/null || echo '{}'" | grep -E '"total_hosts"|"vulnerable_hosts"|"status"|"last_scan"' | sed 's/^ */  /'

# Check hosts discovered by VLAN
echo ""
echo "📡 Hosts by VLAN:"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner grep -E '^192\.168\.(10|14|5|6)\.' /home/nuclei/discovery/discovery.db 2>/dev/null | wc -l | xargs echo '  Total hosts discovered:'" || echo "  Could not get host count"

# Check connectivity from container instead of NAS host
echo ""
echo "🌐 Network connectivity from container:"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner ping -c 1 192.168.10.1 >/dev/null 2>&1 && echo '✓ UDM PRO reachable' || echo '✗ UDM PRO not reachable'"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner ping -c 1 192.168.10.89 >/dev/null 2>&1 && echo '✓ Home Assistant reachable' || echo '✗ Home Assistant not reachable'"

# Check VLAN connectivity from container
echo ""
echo "🔌 VLAN connectivity from container:"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner ping -c 1 192.168.14.1 >/dev/null 2>&1 && echo '✓ IOT VLAN reachable' || echo '✗ IOT VLAN not reachable'"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner ping -c 1 192.168.5.1 >/dev/null 2>&1 && echo '✓ Guest VLAN reachable' || echo '✗ Guest VLAN not reachable'"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner ping -c 1 192.168.6.1 >/dev/null 2>&1 && echo '✓ Clients VLAN reachable' || echo '✗ Clients VLAN not reachable'"

# Check discovery log for errors
echo ""
echo "📝 Recent discovery log:"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner tail -5 /home/nuclei/logs/discovery.log" | sed 's/^/  /'

echo ""
echo "🔄 To restart container: ./manage-remote.sh restart"
echo "🚀 To force full scan: ./trigger-full-scan.sh"