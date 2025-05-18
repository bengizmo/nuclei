#!/bin/bash
# Deploy Nuclei container to Synology NAS

NAS_HOST="192.168.10.163"
NAS_USER="ben"
NAS_PATH="/volume1/docker/nuclei"
LOCAL_PATH="/Users/ben/dev/nuclei/custom/home-network"

echo "=== Deploying Nuclei to Synology NAS ==="
echo "Target: ${NAS_USER}@${NAS_HOST}:${NAS_PATH}"
echo ""

# Create directory on NAS
echo "Creating directory on NAS..."
ssh ${NAS_USER}@${NAS_HOST} "mkdir -p ${NAS_PATH}"

# Copy files to NAS
echo "Copying files to NAS..."
rsync -avz --progress \
    --exclude='*.json' \
    --exclude='results/*' \
    --exclude='.git' \
    --exclude='__pycache__' \
    ${LOCAL_PATH}/ ${NAS_USER}@${NAS_HOST}:${NAS_PATH}/

# Set execute permissions on scripts
echo ""
echo "Setting execute permissions on scripts..."
ssh ${NAS_USER}@${NAS_HOST} "chmod +x ${NAS_PATH}/scripts/*.sh"

# Deploy container
echo ""
echo "Deploying container..."
ssh ${NAS_USER}@${NAS_HOST} "cd ${NAS_PATH} && docker-compose -f docker-compose-vlans.yml up -d"

# Check container status
echo ""
echo "Checking container status..."
ssh ${NAS_USER}@${NAS_HOST} "docker ps | grep nuclei"

echo ""
echo "=== Deployment complete ==="
echo "Access logs with: ssh ${NAS_USER}@${NAS_HOST} 'docker logs nuclei-scanner'"
echo "Run scan with: ssh ${NAS_USER}@${NAS_HOST} 'docker exec nuclei-scanner /home/nuclei/scripts/full-vlan-scan.sh'"