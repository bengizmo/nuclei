#!/bin/bash
# Check the automated scanning configuration and status

cd "$(dirname "$0")"
source ./nas-config.sh

echo "🔄 Checking Automated Nuclei Scanning Configuration"
echo "================================================="

# Check container environment variables
echo "1. Checking container environment configuration..."
CONTAINER_ENV=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker inspect nuclei-scanner --format='{{range .Config.Env}}{{println .}}{{end}}'" 2>/dev/null)

echo "Container environment variables:"
echo "$CONTAINER_ENV" | grep -E "(NETWORK_DISCOVERY|DAILY_SCAN|DISCOVERY_INTERVAL|MULTIPLE_DAILY)"

# Check if discovery service is running
echo ""
echo "2. Checking network discovery service status..."
DISCOVERY_PROCESS=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner pgrep -f network-discovery" 2>/dev/null)

if [ -n "$DISCOVERY_PROCESS" ]; then
    echo "   ✅ Network discovery process is running (PID: $DISCOVERY_PROCESS)"
else
    echo "   ❌ Network discovery process is NOT running"
fi

# Check discovery logs
echo ""
echo "3. Checking discovery logs..."
echo "Recent discovery activity:"
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner tail -20 /home/nuclei/logs/discovery-watchdog.log" 2>/dev/null || echo "No discovery watchdog log found"

echo ""
echo "Network discovery log:"
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner tail -20 /home/nuclei/logs/network-discovery.log" 2>/dev/null || echo "No network discovery log found"

# Check container logs for startup info
echo ""
echo "4. Checking container startup logs..."
echo "Recent container logs:"
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker logs nuclei-scanner --tail 30" 2>/dev/null

# Check if discovery directory has recent activity
echo ""
echo "5. Checking discovery directory for recent activity..."
DISCOVERY_FILES=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner find /home/nuclei/discovery -type f -mtime -1 2>/dev/null | wc -l" 2>/dev/null)

echo "Discovery files modified in last 24 hours: $DISCOVERY_FILES"

if [ "$DISCOVERY_FILES" -gt 0 ]; then
    echo "Recent discovery files:"
    ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner find /home/nuclei/discovery -type f -mtime -1 -exec ls -la {} \;" 2>/dev/null
fi

# Check for network discovery script
echo ""
echo "6. Checking if network discovery script exists..."
DISCOVERY_SCRIPT=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner test -f /home/nuclei/scripts/network-discovery.sh && echo 'exists' || echo 'missing'" 2>/dev/null)

if [ "$DISCOVERY_SCRIPT" = "exists" ]; then
    echo "   ✅ Network discovery script exists"
    
    # Check if it's executable
    DISCOVERY_EXEC=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner test -x /home/nuclei/scripts/network-discovery.sh && echo 'executable' || echo 'not-executable'" 2>/dev/null)
    echo "   Script is: $DISCOVERY_EXEC"
    
    # Show script configuration
    echo ""
    echo "Network discovery script configuration:"
    ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner head -50 /home/nuclei/scripts/network-discovery.sh" 2>/dev/null | grep -E "(SCAN_INTERVAL|VLAN|CONFIG)"
    
else
    echo "   ❌ Network discovery script is missing"
fi

# Check scheduled scan configuration
echo ""
echo "7. Checking scheduled scan processes..."
SCHEDULED_PROCESSES=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner ps aux" 2>/dev/null | grep -E "(3:00|15:00|daily|scan)" | grep -v grep)

if [ -n "$SCHEDULED_PROCESSES" ]; then
    echo "   Scheduled scan processes:"
    echo "$SCHEDULED_PROCESSES"
else
    echo "   ❌ No scheduled scan processes found"
fi

# Check recent scan activity
echo ""
echo "8. Checking recent automated scan activity..."
RECENT_SCANS=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner find /home/nuclei/results -maxdepth 1 -type d -mtime -3" 2>/dev/null | grep -v "^/home/nuclei/results$")

if [ -n "$RECENT_SCANS" ]; then
    echo "   Recent scans (last 3 days):"
    echo "$RECENT_SCANS"
else
    echo "   ❌ No recent automated scans found"
fi

# Check logs for scan execution
echo ""
echo "9. Checking logs for scan execution..."
echo "Daily scan logs:"
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner tail -20 /home/nuclei/logs/daily-scan.log" 2>/dev/null || echo "No daily scan log found"

echo ""
echo "Afternoon scan logs:"
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner tail -20 /home/nuclei/logs/afternoon-scan.log" 2>/dev/null || echo "No afternoon scan log found"

echo ""
echo "================================================="
echo "Automated scanning check complete!"
echo ""
echo "Expected configuration:"
echo "- NETWORK_DISCOVERY_ENABLED=true (5-minute host discovery)"
echo "- DAILY_SCAN_ENABLED=true (3:00 AM daily scan)"
echo "- MULTIPLE_DAILY_SCANS=true (3:00 AM and 3:00 PM scans)"
echo "- Discovery should run continuously with 300-second intervals"