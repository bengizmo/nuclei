#!/bin/bash
# Deploy with proper environment variables

# Load NAS configuration
source ./nas-config.sh

echo "🚀 Deploying with Environment Variables"
echo "====================================="

# Configuration
REMOTE_PATH="/volume2/docker/nuclei"

# Read local .env file
if [ -f ".env" ]; then
    echo "📖 Reading local .env file..."
    export $(grep -v '^#' .env | xargs)
else
    echo "❌ .env file not found!"
    exit 1
fi

# Verify tokens are loaded
echo "✅ Environment variables loaded:"
echo "  HA Token: ${HOME_ASSISTANT_API_TOKEN:0:20}..."
echo "  PDCP Key: ${PDCP_API_KEY:0:20}..."

# Copy .env file to NAS
echo "📤 Copying .env file to NAS..."
cat .env | ${NAS_SSH} "cat > ${REMOTE_PATH}/.env"

# Create docker-compose override with explicit env values
echo "📝 Creating docker-compose override..."
cat > docker-compose.override.yml << EOF
version: '3.8'
services:
  nuclei:
    environment:
      - HOME_ASSISTANT_API_TOKEN=${HOME_ASSISTANT_API_TOKEN}
      - PDCP_API_KEY=${PDCP_API_KEY}
      - OLLAMA_API=http://192.168.10.249:11434/v1
EOF

# Copy override file
cat docker-compose.override.yml | ${NAS_SSH} "cat > ${REMOTE_PATH}/docker-compose.override.yml"

# Deploy with explicit environment
echo "🐳 Deploying with environment variables..."
${NAS_SSH} "cd ${REMOTE_PATH} && export HOME_ASSISTANT_API_TOKEN='${HOME_ASSISTANT_API_TOKEN}' && export PDCP_API_KEY='${PDCP_API_KEY}' && ${DOCKER_COMPOSE_BIN} down && ${DOCKER_COMPOSE_BIN} up -d"

# Wait for container
echo "⏳ Waiting for container to start..."
sleep 10

# Verify environment in container
echo "✅ Verifying environment in container:"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner printenv | grep -E '(HOME_ASSISTANT|PDCP)'"

# Test HA connection
echo ""
echo "🏠 Testing Home Assistant connection..."
HA_TEST=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner curl -s -H \"Authorization: Bearer \${HOME_ASSISTANT_API_TOKEN}\" http://192.168.10.89:8123/api/states | jq '.[0].entity_id' 2>/dev/null")

if [ -n "$HA_TEST" ]; then
    echo "✅ Home Assistant connection successful!"
    echo "   First entity: $HA_TEST"
else
    echo "❌ Home Assistant connection failed"
    # Try direct test
    echo "Trying direct test..."
    ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner curl -v -H \"Authorization: Bearer \${HOME_ASSISTANT_API_TOKEN}\" http://192.168.10.89:8123/api/"
fi

# Start discovery service
echo ""
echo "🔍 Starting discovery service..."
${NAS_SSH} "${DOCKER_BIN} exec -d nuclei-scanner /home/nuclei/scripts/network-discovery.sh"

echo ""
echo "✨ Deployment complete with proper environment!"