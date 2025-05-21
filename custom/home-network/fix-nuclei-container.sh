#!/bin/bash
# Fix Nuclei container issues on the NAS
# This script will check and restart the Nuclei container if needed

cd "$(dirname "$0")"
source ./nas-config.sh

echo "🔧 Fixing Nuclei Container Issues"
echo "================================="

# Check if container exists
echo "1. Checking if Nuclei container exists..."
CONTAINER_EXISTS=$(ssh "${NAS_USER}@${NAS_HOST}" "docker ps -a --filter name=nuclei-scanner --format '{{.Names}}'" 2>/dev/null)

if [ -n "$CONTAINER_EXISTS" ]; then
    echo "   ✅ Container exists: $CONTAINER_EXISTS"
    
    # Check if it's running
    CONTAINER_STATUS=$(ssh "${NAS_USER}@${NAS_HOST}" "docker ps --filter name=nuclei-scanner --format '{{.Status}}'" 2>/dev/null)
    
    if [ -n "$CONTAINER_STATUS" ]; then
        echo "   ✅ Container is running: $CONTAINER_STATUS"
    else
        echo "   ❌ Container is not running"
        echo "   Starting container..."
        ssh "${NAS_USER}@${NAS_HOST}" "docker start nuclei-scanner"
        
        # Wait a moment and check again
        sleep 3
        CONTAINER_STATUS=$(ssh "${NAS_USER}@${NAS_HOST}" "docker ps --filter name=nuclei-scanner --format '{{.Status}}'" 2>/dev/null)
        
        if [ -n "$CONTAINER_STATUS" ]; then
            echo "   ✅ Container started successfully: $CONTAINER_STATUS"
        else
            echo "   ❌ Failed to start container"
            echo "   Checking container logs..."
            ssh "${NAS_USER}@${NAS_HOST}" "docker logs nuclei-scanner --tail 20"
        fi
    fi
else
    echo "   ❌ Container does not exist"
    echo "   Creating and starting container..."
    
    # Check if docker-compose file exists
    COMPOSE_EXISTS=$(ssh "${NAS_USER}@${NAS_HOST}" "test -f /volume1/docker/nuclei/docker-compose.yml && echo 'exists' || echo 'missing'")
    
    if [ "$COMPOSE_EXISTS" = "exists" ]; then
        echo "   Found docker-compose.yml, starting with docker-compose..."
        ssh "${NAS_USER}@${NAS_HOST}" "cd /volume1/docker/nuclei && docker-compose up -d"
    else
        echo "   ❌ docker-compose.yml not found"
        echo "   You need to deploy the docker-compose.yml file to your NAS first"
        echo "   Run: scp docker-compose.yml ${NAS_USER}@${NAS_HOST}:/volume1/docker/nuclei/"
    fi
fi

# Check if script exists in the container
echo ""
echo "2. Checking if scan script exists in container..."
if [ -n "$CONTAINER_EXISTS" ]; then
    SCRIPT_EXISTS=$(ssh "${NAS_USER}@${NAS_HOST}" "docker exec nuclei-scanner test -f /home/nuclei/scripts/scan-with-ha-robust.sh && echo 'exists' || echo 'missing'" 2>/dev/null)
    
    if [ "$SCRIPT_EXISTS" = "exists" ]; then
        echo "   ✅ Scan script exists in container"
    else
        echo "   ❌ Scan script not found in container"
        echo "   Copying script to NAS..."
        
        # Copy script to NAS
        scp ./scripts/scan-with-ha-robust.sh "${NAS_USER}@${NAS_HOST}:/volume1/docker/nuclei/scripts/"
        ssh "${NAS_USER}@${NAS_HOST}" "chmod +x /volume1/docker/nuclei/scripts/scan-with-ha-robust.sh"
        
        # Restart container to pick up new script
        echo "   Restarting container to pick up new script..."
        ssh "${NAS_USER}@${NAS_HOST}" "docker restart nuclei-scanner"
        
        # Wait and check again
        sleep 5
        SCRIPT_EXISTS=$(ssh "${NAS_USER}@${NAS_HOST}" "docker exec nuclei-scanner test -f /home/nuclei/scripts/scan-with-ha-robust.sh && echo 'exists' || echo 'missing'" 2>/dev/null)
        
        if [ "$SCRIPT_EXISTS" = "exists" ]; then
            echo "   ✅ Script now exists in container"
        else
            echo "   ❌ Script still not found in container"
            echo "   Check the volume mounts in your docker-compose.yml"
        fi
    fi
fi

# Test the container
echo ""
echo "3. Testing container functionality..."
if [ -n "$CONTAINER_EXISTS" ]; then
    TEST_RESULT=$(ssh "${NAS_USER}@${NAS_HOST}" "docker exec nuclei-scanner echo 'Container test successful'" 2>/dev/null)
    
    if [ "$TEST_RESULT" = "Container test successful" ]; then
        echo "   ✅ Container is responding to commands"
    else
        echo "   ❌ Container is not responding to commands"
        echo "   Container may have issues - check logs:"
        ssh "${NAS_USER}@${NAS_HOST}" "docker logs nuclei-scanner --tail 10"
    fi
fi

echo ""
echo "================================="
echo "Container fix complete!"
echo ""
echo "Next steps:"
echo "1. Test the Home Assistant button again"
echo "2. Check Home Assistant logs if it still doesn't work"
echo "3. Run the troubleshooting script again to verify all issues are resolved"