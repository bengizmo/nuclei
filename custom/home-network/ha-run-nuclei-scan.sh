#!/bin/bash
# Home Assistant script to run Nuclei scan
# This script should be placed in your Home Assistant config directory

# Log startup
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Home Assistant triggered Nuclei scan" > /config/nuclei-scan.log

# Set the scan status to "scanning"
curl -s -X POST \
    -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
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
    "http://supervisor/core/api/states/sensor.nuclei_scanner_status"

# Run the scan on the NAS
ssh -o StrictHostKeyChecking=no -i /config/.ssh/id_rsa ben@192.168.10.163 "docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-robust.sh"

# Log completion
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Nuclei scan triggered successfully" >> /config/nuclei-scan.log