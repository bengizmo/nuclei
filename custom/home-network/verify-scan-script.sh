#!/bin/bash
# Verify the robust scan script exists on the NAS and in the container
# This script will check for and copy the script if needed

# Load NAS configuration 
cd "$(dirname "$0")"
source ./nas-config.sh

echo "🔍 Verifying scan script availability"
echo "==================================="

# Check if script exists on NAS
echo "1. Checking if script exists on NAS..."
ssh "${NAS_USER}@${NAS_HOST}" "test -f /volume1/docker/nuclei/scripts/scan-with-ha-robust.sh && echo 'exists' || echo 'missing'" > /tmp/script_check.txt
NAS_SCRIPT_EXISTS=$(cat /tmp/script_check.txt)

if [ "$NAS_SCRIPT_EXISTS" = "exists" ]; then
    echo "✅ Script exists on NAS"
else
    echo "❌ Script not found on NAS"
    echo "Copying script to NAS..."
    
    # Check if directory exists
    ssh "${NAS_USER}@${NAS_HOST}" "mkdir -p /volume1/docker/nuclei/scripts"
    
    # Copy script
    scp ./scripts/scan-with-ha-robust.sh "${NAS_USER}@${NAS_HOST}:/volume1/docker/nuclei/scripts/"
    
    # Make executable
    ssh "${NAS_USER}@${NAS_HOST}" "chmod +x /volume1/docker/nuclei/scripts/scan-with-ha-robust.sh"
    
    echo "✅ Script copied to NAS"
fi

# Check if script exists in container
echo ""
echo "2. Checking if script exists in container..."
CONTAINER_SCRIPT_EXISTS=$(ssh "${NAS_USER}@${NAS_HOST}" "docker exec nuclei-scanner test -f /home/nuclei/scripts/scan-with-ha-robust.sh && echo 'exists' || echo 'missing'")

if [ "$CONTAINER_SCRIPT_EXISTS" = "exists" ]; then
    echo "✅ Script exists in container"
else
    echo "❌ Script not found in container"
    
    # Restart container to mount the script
    echo "Restarting container to update mounted scripts..."
    ssh "${NAS_USER}@${NAS_HOST}" "docker restart nuclei-scanner"
    
    # Wait for container to restart
    echo "Waiting for container to restart..."
    sleep 10
    
    # Check again
    CONTAINER_SCRIPT_EXISTS=$(ssh "${NAS_USER}@${NAS_HOST}" "docker exec nuclei-scanner test -f /home/nuclei/scripts/scan-with-ha-robust.sh && echo 'exists' || echo 'missing'")
    
    if [ "$CONTAINER_SCRIPT_EXISTS" = "exists" ]; then
        echo "✅ Script now exists in container after restart"
    else
        echo "❌ Script still not found in container after restart"
        echo "Please check the volume mounts in your docker-compose.yml"
    fi
fi

# Test running the script
echo ""
echo "3. Testing script execution..."
echo "This will NOT run a full scan, just verify the script can be executed"

TEST_RESULT=$(ssh "${NAS_USER}@${NAS_HOST}" "docker exec nuclei-scanner test -x /home/nuclei/scripts/scan-with-ha-robust.sh && echo 'executable' || echo 'not-executable'")

if [ "$TEST_RESULT" = "executable" ]; then
    echo "✅ Script is executable in container"
else
    echo "❌ Script is not executable in container"
    echo "Setting permissions..."
    ssh "${NAS_USER}@${NAS_HOST}" "docker exec nuclei-scanner chmod +x /home/nuclei/scripts/scan-with-ha-robust.sh"
    
    # Check again
    TEST_RESULT=$(ssh "${NAS_USER}@${NAS_HOST}" "docker exec nuclei-scanner test -x /home/nuclei/scripts/scan-with-ha-robust.sh && echo 'executable' || echo 'not-executable'")
    
    if [ "$TEST_RESULT" = "executable" ]; then
        echo "✅ Script is now executable in container"
    else
        echo "❌ Script is still not executable in container"
    fi
fi

echo ""
echo "==================================="
if [ "$CONTAINER_SCRIPT_EXISTS" = "exists" ] && [ "$TEST_RESULT" = "executable" ]; then
    echo "✅ Verification complete! Script is ready to use."
    echo ""
    echo "You can now trigger scans from Home Assistant using:"
    echo "docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-robust.sh"
else
    echo "❌ Verification failed. The script is not ready to use."
    echo "Please check the errors above and fix them."
fi