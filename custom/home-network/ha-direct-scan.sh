#!/bin/bash
# Direct script for Home Assistant to run security scan
# Place this in your Home Assistant config directory and make executable

# Update the path to SSH key if needed
SSH_KEY="$HOME/.ssh/id_rsa" 

# Log the trigger
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Home Assistant is triggering security scan" > /config/nuclei-scan.log

# Run scan via SSH
ssh -i "$SSH_KEY" ben@192.168.10.163 'docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-robust.sh'

# Log completion
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Security scan trigger request complete" >> /config/nuclei-scan.log