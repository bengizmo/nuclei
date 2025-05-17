#!/bin/bash
# Remote deployment script for Nuclei scanner to NAS

# Load configuration
source ./nas-config.sh

# Configuration
REMOTE_PATH="/volume2/docker/nuclei"
LOCAL_PATH="."

echo "🚀 Starting remote deployment to NAS..."
echo "🔗 Deploying to: ${NAS_SSH}"

# Create remote directory
echo "📁 Creating remote directory..."
${NAS_SSH} "mkdir -p ${REMOTE_PATH}"

# Copy configuration files
echo "📤 Copying configuration files..."
${NAS_SSH} "mkdir -p ${REMOTE_PATH}/scripts"

# Copy files using SSH and cat
cat docker-compose.yml | ${NAS_SSH} "cat > ${REMOTE_PATH}/docker-compose.yml"
cat Dockerfile | ${NAS_SSH} "cat > ${REMOTE_PATH}/Dockerfile"
cat critical-hosts.txt | ${NAS_SSH} "cat > ${REMOTE_PATH}/critical-hosts.txt"

# Copy scripts directory
for script in scripts/*.sh; do
    echo "Copying $script..."
    cat "$script" | ${NAS_SSH} "cat > ${REMOTE_PATH}/$script"
done

# Copy environment file if it exists locally
if [ -f .env ]; then
    echo "🔐 Copying environment file..."
    cat .env | ${NAS_SSH} "cat > ${REMOTE_PATH}/.env"
else
    echo "⚠️  No .env file found. Creating from example..."
    cat .env.example | ${NAS_SSH} "cat > ${REMOTE_PATH}/.env"
fi

# Create necessary directories on NAS
echo "📁 Creating necessary directories..."
${NAS_SSH} "mkdir -p ${REMOTE_PATH}/templates ${REMOTE_PATH}/results ${REMOTE_PATH}/config"

# Make scripts executable
echo "🔧 Setting script permissions..."
${NAS_SSH} "chmod +x ${REMOTE_PATH}/scripts/*.sh"

# Deploy with docker-compose
echo "🐳 Starting Docker containers..."
${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} up -d"

# Check deployment status
echo "✅ Checking deployment status..."
${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} ps"

# Show logs
echo "📜 Recent logs:"
${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} logs --tail=20"

echo "✨ Deployment complete!"
echo ""
echo "Useful commands:"
echo "  View logs:    ${NAS_SSH} 'cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} logs -f'"
echo "  Stop:         ${NAS_SSH} 'cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} down'"
echo "  Restart:      ${NAS_SSH} 'cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} restart'"
echo "  Manual scan:  ${NAS_SSH} '${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/multi-vlan-scan.sh'"