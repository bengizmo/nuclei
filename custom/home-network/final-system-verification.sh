#!/bin/bash
# Final comprehensive system verification

# Load NAS configuration
source ./nas-config.sh

echo "🔍 Final System Verification"
echo "==========================="
echo ""

# 1. Container Status
echo "1. Container Status"
echo "==================="
CONTAINER_STATUS=$(${NAS_SSH} "${DOCKER_BIN} ps --filter name=nuclei-scanner --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'")
echo "$CONTAINER_STATUS"
echo ""

# 2. Services Running
echo "2. Active Services"
echo "=================="
DISCOVERY_PID=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pgrep -f network-discovery.sh")
PROFILING_COUNT=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pgrep -f profile-new-host-enhanced.sh | wc -l")
echo "Discovery Service PID: ${DISCOVERY_PID:-Not Running}"
echo "Active Profiling Processes: $PROFILING_COUNT"
echo ""

# 3. Environment Variables
echo "3. Environment Variables"
echo "======================="
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner printenv | grep -E '(HOME_ASSISTANT|PDCP|OLLAMA)'"
echo ""

# 4. Discovery Status
echo "4. Discovery Status"
echo "=================="
DISCOVERED=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner grep -v '^#' /home/nuclei/discovery/discovery.db | wc -l")
PROFILED=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner grep 'profiled' /home/nuclei/discovery/discovery.db | wc -l")
echo "Total devices discovered: $DISCOVERED"
echo "Devices profiled: $PROFILED"
echo "Latest discoveries:"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner tail -3 /home/nuclei/logs/discovery.log" | sed 's/^/  /'
echo ""

# 5. AI Integration
echo "5. AI Integration"
echo "================"
# Check for AI template usage
AI_TEMPLATES=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner grep -i 'AI' /home/nuclei/logs/profiling.log 2>/dev/null | tail -3")
if [ -n "$AI_TEMPLATES" ]; then
    echo "✅ AI template generation active:"
    echo "$AI_TEMPLATES" | sed 's/^/  /'
else
    echo "ℹ️ No recent AI template generation"
fi
echo ""

# 6. Home Assistant Integration
echo "6. Home Assistant Integration"
echo "============================"
# Test HA connection
HA_TEST=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'curl -s -o /dev/null -w \"%{http_code}\" -H \"Authorization: Bearer \${HOME_ASSISTANT_API_TOKEN}\" http://192.168.10.89:8123/api/'")
echo "HA Connection Status: $HA_TEST"

# Check latest HA updates
HA_SENSORS=$(curl -s -H "Authorization: Bearer $(grep HOME_ASSISTANT_API_TOKEN .env | cut -d= -f2)" \
    http://192.168.10.89:8123/api/states | \
    jq -r '.[] | select(.entity_id | contains("nuclei")) | {entity_id, last_changed} | @json' | \
    jq -s 'sort_by(.last_changed) | reverse | .[0:3]')
echo "Recent HA Updates:"
echo "$HA_SENSORS" | jq -r '.[] | "  " + .entity_id + ": " + .last_changed'
echo ""

# 7. Notification Behavior
echo "7. Notification Behavior"
echo "======================="
# Check for new device notifications (should be none)
DEVICE_NOTIFICATIONS=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner grep -i 'new device' /home/nuclei/logs/*.log 2>/dev/null | grep -i notification | wc -l")
echo "New device notifications sent: $DEVICE_NOTIFICATIONS (should be 0)"

# Check for vulnerability alerts
VULN_ALERTS=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner grep -i 'vulnerability\|alert' /home/nuclei/logs/*.log 2>/dev/null | grep -i notification | wc -l")
echo "Vulnerability alerts sent: $VULN_ALERTS"
echo ""

# 8. AI Summary Check
echo "8. AI Summary Generation"
echo "======================="
LATEST_SUMMARY=$(curl -s -H "Authorization: Bearer $(grep HOME_ASSISTANT_API_TOKEN .env | cut -d= -f2)" \
    http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_summary | \
    jq -r '.state')
echo "Latest summary: \"$LATEST_SUMMARY\""
SUMMARY_LENGTH=$(echo "$LATEST_SUMMARY" | wc -c)
echo "Summary length: $SUMMARY_LENGTH characters"
if [ $SUMMARY_LENGTH -lt 200 ]; then
    echo "✅ Summary is concise (< 200 chars)"
else
    echo "⚠️ Summary may be too long"
fi
echo ""

# 9. Scan Results
echo "9. Scan Results"
echo "=============="
RESULTS_COUNT=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find /home/nuclei/results -name '*.json' 2>/dev/null | wc -l")
echo "Total scan result files: $RESULTS_COUNT"
RECENT_SCANS=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find /home/nuclei/results -name '*.json' -mmin -60 2>/dev/null | wc -l")
echo "Scans in last hour: $RECENT_SCANS"
echo ""

# 10. System Health
echo "10. System Health"
echo "================"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner df -h /home/nuclei | tail -1" | awk '{print "Disk Usage: " $3 "/" $2 " (" $5 ")"}'
${NAS_SSH} "${DOCKER_BIN} stats nuclei-scanner --no-stream --format 'table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}' | tail -1"
echo ""

# Summary
echo "============================"
echo "✨ System Verification Complete"
echo ""

# Feature checklist
echo "Feature Status:"
echo "✓ Silent device discovery: ${DEVICE_NOTIFICATIONS:-0} notifications (correct: 0)"
echo "✓ Automatic scanning: $PROFILING_COUNT active processes"
echo "✓ AI integration: ${AI_TEMPLATES:+Active}${AI_TEMPLATES:-Check logs}"
echo "✓ HA integration: Status $HA_TEST"
echo "✓ Concise summaries: $SUMMARY_LENGTH chars"
echo ""

# Overall status
if [ "$HA_TEST" = "200" ] && [ "$DEVICE_NOTIFICATIONS" = "0" ] && [ -n "$DISCOVERY_PID" ]; then
    echo "🎉 All systems functioning as designed!"
else
    echo "⚠️ Some systems may need attention"
fi