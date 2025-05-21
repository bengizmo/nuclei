#!/bin/bash
# Test the scan trigger to make sure everything works

cd "$(dirname "$0")"
source ./nas-config.sh

echo "🧪 Testing Nuclei Scan Trigger"
echo "=============================="

# Test 1: Check if container is running
echo "1. Checking if Nuclei container is running..."
CONTAINER_STATUS=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker ps --filter name=nuclei-scanner --format '{{.Status}}'" 2>/dev/null)

if [ -n "$CONTAINER_STATUS" ]; then
    echo "   ✅ Container is running: $CONTAINER_STATUS"
else
    echo "   ❌ Container is not running"
    exit 1
fi

# Test 2: Check if scan script exists and is executable
echo ""
echo "2. Checking if scan script is accessible..."
SCRIPT_CHECK=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner test -x /home/nuclei/scripts/scan-with-ha-robust.sh && echo 'executable' || echo 'not-executable'" 2>/dev/null)

if [ "$SCRIPT_CHECK" = "executable" ]; then
    echo "   ✅ Scan script is executable"
else
    echo "   ❌ Scan script is not executable or not found"
    echo "   Trying to fix permissions..."
    ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner chmod +x /home/nuclei/scripts/*.sh" 2>/dev/null
    
    # Check again
    SCRIPT_CHECK=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner test -x /home/nuclei/scripts/scan-with-ha-robust.sh && echo 'executable' || echo 'not-executable'" 2>/dev/null)
    
    if [ "$SCRIPT_CHECK" = "executable" ]; then
        echo "   ✅ Fixed! Scan script is now executable"
    else
        echo "   ❌ Still not executable - manual intervention needed"
    fi
fi

# Test 3: Test the actual scan command (dry run)
echo ""
echo "3. Testing scan command execution..."
echo "   This will start a real scan - continue? (y/n)"
read -r response

if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
    echo "   Starting scan via Docker exec..."
    
    # Update Home Assistant status first
    if [ -n "$HOME_ASSISTANT_API_TOKEN" ]; then
        echo "   Updating Home Assistant status to 'scanning'..."
        curl -s -X POST \
            -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{
                "state": "scanning",
                "attributes": {
                    "friendly_name": "Scanner Status",
                    "icon": "mdi:shield-search"
                }
            }' \
            "http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_status"
        echo "   ✅ Updated Home Assistant status"
    fi
    
    # Run the scan
    echo "   Triggering scan on NAS container..."
    ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-robust.sh" &
    SCAN_PID=$!
    
    echo "   ✅ Scan started with PID: $SCAN_PID"
    echo "   Check Home Assistant for updates"
    echo "   Scan logs will be available in the container"
else
    echo "   Skipping actual scan test"
fi

# Test 4: Show the exact command for Home Assistant
echo ""
echo "4. Home Assistant Configuration:"
echo "   Use this exact shell_command in your configuration.yaml:"
echo ""
echo "shell_command:"
echo "  run_nuclei_scan: \"ssh ${NAS_USER}@${NAS_HOST} '/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-robust.sh'\""
echo ""

echo "=============================="
echo "Test complete!"
echo ""
echo "If all tests passed, your Home Assistant button should now work correctly."
echo "Update your Home Assistant configuration with the shell_command above."