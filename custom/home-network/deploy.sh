#!/bin/bash
# Deploy script for Synology NAS

# Configuration
NAS_HOST="192.168.10.163"
NAS_USER="your_nas_user"
DEPLOY_PATH="/volume1/docker/nuclei"

echo "Deploying Nuclei Scanner to Synology NAS..."

# Create directory on NAS
ssh ${NAS_USER}@${NAS_HOST} "mkdir -p ${DEPLOY_PATH}"

# Copy files to NAS
scp -r docker-compose.yml Dockerfile scripts/ critical-hosts.txt ${NAS_USER}@${NAS_HOST}:${DEPLOY_PATH}/

# Copy environment file if it exists
if [ -f .env ]; then
    scp .env ${NAS_USER}@${NAS_HOST}:${DEPLOY_PATH}/
else
    echo "Warning: .env file not found. Using example file..."
    scp .env.example ${NAS_USER}@${NAS_HOST}:${DEPLOY_PATH}/.env
fi

# Deploy with docker-compose
ssh ${NAS_USER}@${NAS_HOST} "cd ${DEPLOY_PATH} && docker-compose up -d"

echo "Deployment complete!"
echo "Check logs with: ssh ${NAS_USER}@${NAS_HOST} 'cd ${DEPLOY_PATH} && docker-compose logs -f'"