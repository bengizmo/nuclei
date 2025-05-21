#!/bin/bash
# Deploy the fixed network discovery script

cd "$(dirname "$0")"
source ./nas-config.sh

echo "🔧 Deploying Fixed Network Discovery Script"
echo "=========================================="

# Copy the fixed script to the NAS
echo "1. Copying fixed discovery script to container..."
cat ./scripts/network-discovery-fixed.sh | ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec -i nuclei-scanner tee /home/nuclei/scripts/network-discovery-fixed.sh > /dev/null"

# Make it executable
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner chmod +x /home/nuclei/scripts/network-discovery-fixed.sh"

# Replace the broken script with the fixed one
echo "2. Replacing broken script with fixed version..."
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner cp /home/nuclei/scripts/network-discovery-fixed.sh /home/nuclei/scripts/network-discovery.sh"

# Test the fixed script
echo "3. Testing the fixed script..."
TEST_OUTPUT=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner bash -n /home/nuclei/scripts/network-discovery.sh" 2>&1)

if [ -z "$TEST_OUTPUT" ]; then
    echo "   ✅ Script syntax is valid"
else
    echo "   ❌ Script still has syntax errors:"
    echo "$TEST_OUTPUT"
fi

# Restart the container to pick up the fixed script
echo "4. Restarting container to apply the fix..."
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker restart nuclei-scanner"

# Wait for restart
echo "5. Waiting for container to restart..."
sleep 15

# Check if discovery is now working
echo "6. Checking if discovery service is now running..."
DISCOVERY_RUNNING=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner pgrep -f network-discovery" 2>/dev/null)

if [ -n "$DISCOVERY_RUNNING" ]; then
    echo "   ✅ Network discovery is now running (PID: $DISCOVERY_RUNNING)"
    
    # Check logs
    echo ""
    echo "7. Checking discovery logs..."
    ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner tail -10 /home/nuclei/logs/network-discovery.log" 2>/dev/null || echo "No logs yet - service just started"
    
    # Check status
    echo ""
    echo "8. Checking discovery status..."
    ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner cat /home/nuclei/discovery/status.json" 2>/dev/null || echo "Status file not created yet"
    
else
    echo "   ❌ Network discovery still not running"
    
    # Check recent logs for errors
    echo ""
    echo "Recent container logs:"
    ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker logs nuclei-scanner --tail 20" 2>/dev/null
fi

echo ""
echo "=========================================="
echo "Deployment complete!"
echo ""
echo "The system should now properly:"
echo "1. Discover new hosts every 5 minutes"
echo "2. Profile new hosts with nmap"
echo "3. Trigger targeted vulnerability scans for new hosts"
echo "4. Maintain a database of discovered hosts"
echo "5. Run full scans at 3:00 AM and 3:00 PM daily"