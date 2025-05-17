#!/bin/bash
# Remote management script for Nuclei scanner

# Load configuration
source ./nas-config.sh

REMOTE_PATH="/volume2/docker/nuclei"

case "$1" in
    deploy)
        echo "🚀 Deploying to NAS..."
        ./deploy-remote.sh
        ;;
    
    start)
        echo "▶️  Starting container..."
        ${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} up -d"
        ;;
    
    stop)
        echo "⏹️  Stopping container..."
        ${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} down"
        ;;
    
    restart)
        echo "🔄 Restarting container..."
        ${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} restart"
        ;;
    
    logs)
        echo "📜 Showing logs..."
        ${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} logs -f"
        ;;
    
    status)
        echo "📊 Container status..."
        ${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} ps"
        ;;
    
    scan)
        echo "🔍 Running manual scan..."
        ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/multi-vlan-scan.sh"
        ;;
    
    results)
        echo "📋 Latest scan results..."
        ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner cat /home/nuclei/results/latest/summary.txt"
        ;;
    
    shell)
        echo "🐚 Opening shell in container..."
        ${NAS_SSH} "${DOCKER_BIN} exec -it nuclei-scanner /bin/sh"
        ;;
    
    update)
        echo "📦 Updating configuration..."
        cat docker-compose.yml | ${NAS_SSH} "cat > ${REMOTE_PATH}/docker-compose.yml"
        cat critical-hosts.txt | ${NAS_SSH} "cat > ${REMOTE_PATH}/critical-hosts.txt"
        for script in scripts/*.sh; do
            cat "$script" | ${NAS_SSH} "cat > ${REMOTE_PATH}/$script"
        done
        ${NAS_SSH} "chmod +x ${REMOTE_PATH}/scripts/*.sh"
        ${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} up -d"
        ;;
    
    pull)
        echo "⬇️  Pulling latest image..."
        ${NAS_SSH} "cd ${REMOTE_PATH} && ${DOCKER_COMPOSE_BIN} pull"
        ;;
    
    *)
        echo "Usage: $0 {deploy|start|stop|restart|logs|status|scan|results|shell|update|pull}"
        echo ""
        echo "Commands:"
        echo "  deploy   - Initial deployment to NAS"
        echo "  start    - Start the container"
        echo "  stop     - Stop the container"
        echo "  restart  - Restart the container"
        echo "  logs     - View container logs"
        echo "  status   - Show container status"
        echo "  scan     - Run a manual scan"
        echo "  results  - View latest scan results"
        echo "  shell    - Open shell in container"
        echo "  update   - Update configuration files"
        echo "  pull     - Pull latest Docker image"
        exit 1
        ;;
esac