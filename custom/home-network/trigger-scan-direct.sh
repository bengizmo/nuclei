#!/bin/bash
# Direct script to trigger a scan from Home Assistant
# This script is intended to be called directly from Home Assistant's shell_command
# No complex automation required - just call this script directly

# Log start
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting direct scan trigger" > /tmp/nuclei-scan.log

# Check if HA API token is available
if [ -z "$HOME_ASSISTANT_API_TOKEN" ] && [ -f "/Users/ben/dev/nuclei/custom/home-network/.env" ]; then
    source "/Users/ben/dev/nuclei/custom/home-network/.env"
fi

# Load NAS configuration
if [ -f "/Users/ben/dev/nuclei/custom/home-network/nas-config.sh" ]; then
    source "/Users/ben/dev/nuclei/custom/home-network/nas-config.sh"
else
    # Default values if not available
    NAS_USER="ben"
    NAS_HOST="192.168.10.163"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Using NAS: ${NAS_USER}@${NAS_HOST}" >> /tmp/nuclei-scan.log

# Update scanner status in Home Assistant directly
if [ -n "$HOME_ASSISTANT_API_TOKEN" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Updating HA status to scanning" >> /tmp/nuclei-scan.log
    curl -s -X POST \
        -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "state": "scanning",
            "attributes": {
                "friendly_name": "Scanner Status",
                "icon": "mdi:shield-search",
                "device": {
                    "identifiers": ["nuclei_scanner_001"],
                    "name": "Nuclei Scanner"
                }
            }
        }' \
        "http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_status"
fi

# Trigger the scan on the NAS
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Triggering scan on NAS" >> /tmp/nuclei-scan.log
ssh -o StrictHostKeyChecking=no "${NAS_USER}@${NAS_HOST}" "docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-robust.sh" > /tmp/nuclei-scan-output.log 2>&1 &

# Log completion
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Scan triggered successfully" >> /tmp/nuclei-scan.log
echo "Scan triggered successfully"