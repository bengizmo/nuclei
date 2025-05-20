#!/bin/bash
# SSH wrapper that uses the defined NAS variables

# Source the NAS configuration if it exists
if [ -f "$(dirname "$0")/nas-config.sh" ]; then
    source "$(dirname "$0")/nas-config.sh"
fi

# Use predefined variables or defaults
NAS_USER=${NAS_USER:-ben}
NAS_HOST=${NAS_HOST:-192.168.10.163}

ssh ${NAS_USER}@${NAS_HOST} "$@"
