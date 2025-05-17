#!/bin/bash
# Check Docker installation on NAS

source ./nas-config.sh

echo "🐳 Checking Docker installation on NAS..."
echo ""

echo "Docker version:"
${NAS_SSH} "docker --version" || echo "❌ Docker not found"

echo ""
echo "Docker Compose version:"
${NAS_SSH} "docker-compose --version" || {
    echo "❌ docker-compose not found"
    echo ""
    echo "Trying alternative locations..."
    ${NAS_SSH} "docker compose version" || echo "❌ docker compose (v2) not found"
    ${NAS_SSH} "/usr/local/bin/docker-compose --version" || echo "❌ /usr/local/bin/docker-compose not found"
}

echo ""
echo "Docker service status:"
${NAS_SSH} "systemctl status docker 2>/dev/null || service docker status 2>/dev/null" || echo "❌ Cannot check service status"