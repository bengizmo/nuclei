#!/bin/bash
# Fix Home Assistant token in deployment

# Load NAS configuration
source ./nas-config.sh

echo "🔧 Fixing Home Assistant API Token..."

# Configuration
REMOTE_PATH="/volume2/docker/nuclei"
LOCAL_ENV_FILE=".env"

# Read tokens from local .env file
if [ -f "$LOCAL_ENV_FILE" ]; then
    HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" "$LOCAL_ENV_FILE" | cut -d'=' -f2)
    PDCP_API_KEY=$(grep "PDCP_API_KEY=" "$LOCAL_ENV_FILE" | head -1 | cut -d'=' -f2)
else
    echo "❌ .env file not found!"
    exit 1
fi

if [ -z "$HA_TOKEN" ]; then
    echo "❌ HOME_ASSISTANT_API_TOKEN not found in .env file!"
    exit 1
fi

echo "📝 Updating environment file on NAS..."
# Create new .env file with both tokens
${NAS_SSH} "cat > ${REMOTE_PATH}/.env << EOF
HOME_ASSISTANT_API_TOKEN=$HA_TOKEN
PDCP_API_KEY=$PDCP_API_KEY
OLLAMA_API=http://192.168.10.249:11434/v1
EOF"

# Verify the .env file
echo "✅ Verifying .env file on NAS:"
${NAS_SSH} "cat ${REMOTE_PATH}/.env"

# Restart container to load environment
echo "🐳 Restarting container..."
${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} restart"

# Wait for container to start
echo "⏳ Waiting for container to start..."
sleep 10

# Verify tokens are loaded
echo "✅ Verifying tokens in container:"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner printenv | grep -E '(HOME_ASSISTANT|PDCP)'"

# Test Home Assistant connection
echo ""
echo "🏠 Testing Home Assistant connection..."
TEST_RESULT=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner curl -s -o /dev/null -w '%{http_code}' -H \"Authorization: Bearer \${HOME_ASSISTANT_API_TOKEN}\" http://192.168.10.89:8123/api/states")

if [ "$TEST_RESULT" = "200" ]; then
    echo "✅ Home Assistant connection successful!"
else
    echo "❌ Home Assistant connection failed with code: $TEST_RESULT"
fi

# Restart discovery service
echo "🔄 Restarting discovery service..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner pkill -f network-discovery.sh"
${NAS_SSH} "${DOCKER_BIN} exec -d nuclei-scanner /home/nuclei/scripts/network-discovery.sh"

echo ""
echo "✨ Fix complete!"
echo ""
echo "The system should now properly update Home Assistant with:"
echo "- Device discovery information"
echo "- Vulnerability alerts"
echo "- AI-generated summaries"