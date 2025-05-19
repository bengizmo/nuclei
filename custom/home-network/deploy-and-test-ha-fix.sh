#!/bin/bash
# Deploy HA fixes and test

# Load NAS configuration
source ./nas-config.sh

echo "🔧 Deploying Home Assistant Fixes"
echo "================================"

# Configuration
REMOTE_PATH="/volume2/docker/nuclei"

# Read local .env
export $(grep -v '^#' .env | xargs)

echo "📤 Deploying fixed scripts..."
${NAS_SSH} "mkdir -p ${REMOTE_PATH}/scripts"

# Copy fixed scripts
for script in scripts/*.sh; do
    echo "   Copying $(basename $script)..."
    cat "$script" | ${NAS_SSH} "cat > ${REMOTE_PATH}/$script"
done

# Set permissions
${NAS_SSH} "chmod +x ${REMOTE_PATH}/scripts/*.sh"

# Update .env file on NAS
echo "📝 Updating environment file..."
cat .env | ${NAS_SSH} "cat > ${REMOTE_PATH}/.env"

# Restart container with environment
echo "🐳 Restarting container..."
${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} down"
${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} up -d"

# Wait for container
echo "⏳ Waiting for container to start..."
sleep 10

# Test HA connection from container
echo ""
echo "🏠 Testing Home Assistant connection from container..."
HA_TEST=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'curl -s -o /dev/null -w \"%{http_code}\" -H \"Authorization: Bearer \${HOME_ASSISTANT_API_TOKEN}\" http://192.168.10.89:8123/api/'")
echo "Response code: $HA_TEST"

if [ "$HA_TEST" = "200" ]; then
    echo "✅ HA connection successful!"
    
    # Test updating a sensor
    echo ""
    echo "📊 Testing sensor update..."
    ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'curl -X POST -H \"Authorization: Bearer \${HOME_ASSISTANT_API_TOKEN}\" -H \"Content-Type: application/json\" -d \"{\\\"state\\\": \\\"test_update\\\", \\\"attributes\\\": {\\\"test\\\": true}}\" http://192.168.10.89:8123/api/states/sensor.nuclei_test'"
    
    # Check if sensor was created
    SENSOR_CHECK=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'curl -s -H \"Authorization: Bearer \${HOME_ASSISTANT_API_TOKEN}\" http://192.168.10.89:8123/api/states/sensor.nuclei_test | jq -r .state'")
    
    if [ "$SENSOR_CHECK" = "test_update" ]; then
        echo "✅ Sensor update successful!"
    else
        echo "❌ Sensor update failed"
    fi
else
    echo "❌ HA connection failed"
fi

# Start discovery service
echo ""
echo "🔍 Starting discovery service..."
${NAS_SSH} "${DOCKER_BIN} exec -d nuclei-scanner /home/nuclei/scripts/network-discovery.sh"

# Run a test AI summary
echo ""
echo "🤖 Testing AI summary with HA update..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/generate-ai-summary.sh /home/nuclei/results/latest"

echo ""
echo "✨ Deployment complete!"
echo ""
echo "Monitor the logs to verify HA updates:"
echo "  ${NAS_SSH} '${DOCKER_BIN} exec nuclei-scanner tail -f /home/nuclei/logs/discovery.log'"