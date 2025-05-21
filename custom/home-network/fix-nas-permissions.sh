#!/bin/bash
# Fix NAS permissions and Docker setup
# This script addresses the permission and Docker issues on the Synology NAS

cd "$(dirname "$0")"
source ./nas-config.sh

echo "🔧 Fixing NAS Permissions and Docker Setup"
echo "=========================================="

# Check if user has sudo access
echo "1. Checking user permissions..."
SSH_RESULT=$(ssh "${NAS_USER}@${NAS_HOST}" "whoami && groups" 2>/dev/null)
echo "Current user info: $SSH_RESULT"

# Try to create directories with different approaches
echo ""
echo "2. Creating directories with proper permissions..."

# Method 1: Try standard docker directory
echo "Trying standard docker directory..."
ssh "${NAS_USER}@${NAS_HOST}" "mkdir -p /volume1/docker/nuclei" 2>/dev/null && echo "✅ Standard path works" || echo "❌ Standard path failed"

# Method 2: Try home directory
echo "Trying home directory approach..."
ssh "${NAS_USER}@${NAS_HOST}" "mkdir -p ~/nuclei/scripts ~/nuclei/logs ~/nuclei/results" 2>/dev/null && echo "✅ Home directory works" || echo "❌ Home directory failed"

# Method 3: Try shared folder
echo "Trying shared folder approach..."
ssh "${NAS_USER}@${NAS_HOST}" "mkdir -p /volume1/homes/${NAS_USER}/nuclei/scripts" 2>/dev/null && echo "✅ Shared folder works" || echo "❌ Shared folder failed"

# Check Docker availability
echo ""
echo "3. Checking Docker availability..."
DOCKER_VERSION=$(ssh "${NAS_USER}@${NAS_HOST}" "docker --version" 2>/dev/null)
if [ -n "$DOCKER_VERSION" ]; then
    echo "✅ Docker is available: $DOCKER_VERSION"
    
    # Check if user can run Docker commands
    DOCKER_TEST=$(ssh "${NAS_USER}@${NAS_HOST}" "docker ps" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "✅ User can run Docker commands"
    else
        echo "❌ User cannot run Docker commands"
        echo "Adding user to docker group..."
        ssh "${NAS_USER}@${NAS_HOST}" "sudo usermod -aG docker ${NAS_USER}" 2>/dev/null || echo "❌ Cannot add user to docker group"
    fi
else
    echo "❌ Docker not found or not accessible"
    echo "Checking if Docker is installed..."
    ssh "${NAS_USER}@${NAS_HOST}" "which docker" 2>/dev/null || echo "Docker not in PATH"
fi

# Check for container manager
echo ""
echo "4. Checking Synology Container Manager..."
CONTAINER_MANAGER=$(ssh "${NAS_USER}@${NAS_HOST}" "ls /var/packages/ContainerManager/target/usr/bin/ 2>/dev/null | grep docker" 2>/dev/null)
if [ -n "$CONTAINER_MANAGER" ]; then
    echo "✅ Container Manager found"
    echo "Docker path: /var/packages/ContainerManager/target/usr/bin/docker"
else
    echo "❌ Container Manager not found"
fi

# Try alternative deployment locations
echo ""
echo "5. Finding the best deployment location..."

# Check available locations
LOCATIONS=(
    "/volume1/docker/nuclei"
    "/volume1/homes/${NAS_USER}/nuclei"
    "~/nuclei"
    "/tmp/nuclei"
)

WORKING_LOCATION=""
for location in "${LOCATIONS[@]}"; do
    if ssh "${NAS_USER}@${NAS_HOST}" "mkdir -p $location && touch $location/test && rm $location/test" 2>/dev/null; then
        echo "✅ $location is writable"
        WORKING_LOCATION="$location"
        break
    else
        echo "❌ $location is not writable"
    fi
done

if [ -n "$WORKING_LOCATION" ]; then
    echo "Using location: $WORKING_LOCATION"
    
    # Create the deployment in the working location
    echo ""
    echo "6. Deploying to working location..."
    
    # Create directory structure
    ssh "${NAS_USER}@${NAS_HOST}" "mkdir -p $WORKING_LOCATION/scripts $WORKING_LOCATION/logs $WORKING_LOCATION/results"
    
    # Copy files
    scp ./docker-compose.yml "${NAS_USER}@${NAS_HOST}:$WORKING_LOCATION/"
    scp ./entrypoint.sh "${NAS_USER}@${NAS_HOST}:$WORKING_LOCATION/"
    scp ./scripts/*.sh "${NAS_USER}@${NAS_HOST}:$WORKING_LOCATION/scripts/"
    
    # Set permissions
    ssh "${NAS_USER}@${NAS_HOST}" "chmod +x $WORKING_LOCATION/entrypoint.sh $WORKING_LOCATION/scripts/*.sh"
    
    # Copy or create .env file
    if [ -f .env ]; then
        scp ./.env "${NAS_USER}@${NAS_HOST}:$WORKING_LOCATION/"
    else
        ssh "${NAS_USER}@${NAS_HOST}" "cat > $WORKING_LOCATION/.env << 'EOF'
HOME_ASSISTANT_API_TOKEN=${HOME_ASSISTANT_API_TOKEN}
PDCP_API_KEY=${PDCP_API_KEY:-}
EOF"
    fi
    
    # Try to start container
    echo ""
    echo "7. Starting container..."
    DOCKER_CMD="docker"
    if [ -n "$CONTAINER_MANAGER" ]; then
        DOCKER_CMD="/var/packages/ContainerManager/target/usr/bin/docker"
    fi
    
    ssh "${NAS_USER}@${NAS_HOST}" "cd $WORKING_LOCATION && $DOCKER_CMD-compose up -d" 2>/dev/null
    
    # Check if container started
    sleep 5
    CONTAINER_STATUS=$(ssh "${NAS_USER}@${NAS_HOST}" "$DOCKER_CMD ps --filter name=nuclei-scanner" 2>/dev/null)
    
    if [ -n "$CONTAINER_STATUS" ]; then
        echo "✅ Container started successfully!"
        echo "$CONTAINER_STATUS"
    else
        echo "❌ Container failed to start"
        echo "Checking logs..."
        ssh "${NAS_USER}@${NAS_HOST}" "$DOCKER_CMD logs nuclei-scanner" 2>/dev/null || echo "No logs available"
    fi
    
    echo ""
    echo "Deployment location: $WORKING_LOCATION"
    echo "Update your Home Assistant shell command to use:"
    echo "ssh ${NAS_USER}@${NAS_HOST} '$DOCKER_CMD exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-robust.sh'"
    
else
    echo "❌ No writable location found"
    echo "Manual intervention required"
fi

echo ""
echo "=========================================="
echo "NAS fix complete!"