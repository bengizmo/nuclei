#!/bin/bash
# Deploy HA entity monitoring to NAS

# Load NAS configuration 
cd "$(dirname "$0")"
source ./nas-config.sh

echo "🚀 Deploying Home Assistant entity monitoring to NAS"
echo "=================================================="

# Copy the relevant files
scp auto-restore-ha-entities.sh cron-ha-entity-monitor.txt "${NAS_USER}@${NAS_HOST}:/volume1/docker/nuclei/"

# Set permissions
ssh "${NAS_USER}@${NAS_HOST}" "chmod +x /volume1/docker/nuclei/auto-restore-ha-entities.sh"

# Show instructions for setting up cron
echo ""
echo "✅ Files deployed successfully!"
echo ""
echo "To set up the cron job, run the following commands:"
echo "  ssh ${NAS_USER}@${NAS_HOST}"
echo "  crontab -e"
echo "  Add the entries from /volume1/docker/nuclei/cron-ha-entity-monitor.txt"
echo ""
echo "Or run this command to set up the cron job:"
echo "  ssh ${NAS_USER}@${NAS_HOST} \"(crontab -l 2>/dev/null; cat /volume1/docker/nuclei/cron-ha-entity-monitor.txt) | crontab -\""