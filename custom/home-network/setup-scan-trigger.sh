#!/bin/bash
# Setup Home Assistant scan trigger webhook on NAS
# This script configures the Home Assistant webhook and deploys necessary files

# Load NAS configuration 
cd "$(dirname "$0")"
source ./nas-config.sh

echo "🔄 Setting up Home Assistant scan trigger"
echo "======================================="

# Copy webhook handler script to NAS
echo "Copying webhook handler to NAS..."
scp ./scripts/handle-ha-webhook.sh "${NAS_USER}@${NAS_HOST}:/volume1/docker/nuclei/scripts/"
ssh "${NAS_USER}@${NAS_HOST}" "chmod +x /volume1/docker/nuclei/scripts/handle-ha-webhook.sh"

# Copy HA button integration to NAS
echo "Copying HA button integration to NAS..."
scp ./ha-button-integration.yaml "${NAS_USER}@${NAS_HOST}:/volume1/docker/nuclei/"

# Create run-now script
echo "Creating run-now script on NAS..."
cat > /tmp/run-scan-now.sh << 'EOF'
#!/bin/bash
# Run Nuclei scan now (from manual trigger)
echo "Starting Nuclei scan..."
docker exec nuclei-scanner /home/nuclei/scripts/handle-ha-webhook.sh
echo "Scan started. Check Home Assistant for updates."
EOF

scp /tmp/run-scan-now.sh "${NAS_USER}@${NAS_HOST}:/volume1/docker/nuclei/"
ssh "${NAS_USER}@${NAS_HOST}" "chmod +x /volume1/docker/nuclei/run-scan-now.sh"

# Setup cron for webhook to avoid needing to run a server
echo "Adding cron entry to check for webhook triggers..."
ssh "${NAS_USER}@${NAS_HOST}" "cat > /volume1/docker/nuclei/cron-ha-webhook.txt << 'EOF'
# Check every minute if HA has requested a scan
* * * * * cd /volume1/docker/nuclei && ./scripts/check-ha-trigger.sh >> /volume1/docker/nuclei/logs/webhook-check.log 2>&1
EOF"

# Create webhook check script
echo "Creating webhook check script..."
cat > /tmp/check-ha-trigger.sh << 'EOF'
#!/bin/bash
# Check if HA has requested a scan and run it if needed

# Define paths
TRIGGER_FLAG="/volume1/docker/nuclei/.ha_trigger_scan"
LOCK_FILE="/volume1/docker/nuclei/.webhook_lock"

# Exit if already running (avoid duplicate scans)
if [ -f "$LOCK_FILE" ]; then
    # Check if lock is stale (older than 30 minutes)
    if [ -z "$(find "$LOCK_FILE" -mmin +30)" ]; then
        # Lock is fresh, exit
        exit 0
    else
        # Lock is stale, remove it
        rm -f "$LOCK_FILE"
    fi
fi

# Create lock file
touch "$LOCK_FILE"

# Check if trigger file exists
if [ -f "$TRIGGER_FLAG" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Trigger file found, starting scan"
    
    # Remove trigger file
    rm -f "$TRIGGER_FLAG"
    
    # Run the scan
    docker exec nuclei-scanner /home/nuclei/scripts/handle-ha-webhook.sh
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Scan triggered successfully"
fi

# Remove lock
rm -f "$LOCK_FILE"
EOF

scp /tmp/check-ha-trigger.sh "${NAS_USER}@${NAS_HOST}:/volume1/docker/nuclei/scripts/"
ssh "${NAS_USER}@${NAS_HOST}" "chmod +x /volume1/docker/nuclei/scripts/check-ha-trigger.sh"

# Create script to create the trigger flag
echo "Creating trigger file creator script..."
cat > /tmp/create-ha-trigger.sh << 'EOF'
#!/bin/bash
# Create a trigger file for HA webhook
echo "Creating trigger file for Home Assistant webhook"
touch /volume1/docker/nuclei/.ha_trigger_scan
echo "Trigger file created. The scan will start within 1 minute."
EOF

scp /tmp/create-ha-trigger.sh "${NAS_USER}@${NAS_HOST}:/volume1/docker/nuclei/scripts/"
ssh "${NAS_USER}@${NAS_HOST}" "chmod +x /volume1/docker/nuclei/scripts/create-ha-trigger.sh"

# Clean up temp files
rm -f /tmp/check-ha-trigger.sh /tmp/create-ha-trigger.sh /tmp/run-scan-now.sh

echo ""
echo "✅ Home Assistant scan trigger setup complete!"
echo ""
echo "To enable automatic checking for triggers, run the following commands:"
echo "  ssh ${NAS_USER}@${NAS_HOST}"
echo "  crontab -e"
echo "  Add the entries from /volume1/docker/nuclei/cron-ha-webhook.txt"
echo ""
echo "To manually trigger a scan from NAS, run:"
echo "  ssh ${NAS_USER}@${NAS_HOST}"
echo "  cd /volume1/docker/nuclei"
echo "  ./run-scan-now.sh"
echo ""
echo "In Home Assistant, add the configuration from ha-button-integration.yaml"
echo "to your configuration and restart Home Assistant to add the scan button."