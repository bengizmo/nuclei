#!/bin/bash
# NAS connection configuration

# Set these according to your setup
NAS_USER="ben"  # Change this to your NAS username
NAS_HOST="192.168.10.163"
NAS_SSH="./ssh-wrapper.sh"

# Docker binaries on NAS
DOCKER_BIN="/usr/local/bin/docker"
DOCKER_COMPOSE_BIN="/usr/local/bin/docker-compose"

# Export for use in other scripts
export NAS_SSH
export NAS_HOST
export NAS_USER
export DOCKER_BIN
export DOCKER_COMPOSE_BIN
