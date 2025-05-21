#!/bin/bash
# Deploy Home Assistant Button Integration
# This script copies and configures the necessary files for the Home Assistant button integration

# Load NAS configuration 
cd "$(dirname "$0")"
source ./nas-config.sh

echo "🔄 Deploying Home Assistant Button Integration"
echo "==========================================="

# First, ensure the script exists on the NAS container
echo "Checking if robust scan script exists on container..."
SCRIPT_EXISTS=$(ssh ${NAS_USER}@${NAS_HOST} "docker exec nuclei-scanner test -f /home/nuclei/scripts/scan-with-ha-robust.sh && echo 'exists' || echo 'missing'")

if [ "$SCRIPT_EXISTS" == "missing" ]; then
    echo "❌ Robust scan script not found on container!"
    echo "Copying script to NAS..."
    
    # Copy to NAS first
    scp ./scripts/scan-with-ha-robust.sh ${NAS_USER}@${NAS_HOST}:/volume1/docker/nuclei/scripts/
    ssh ${NAS_USER}@${NAS_HOST} "chmod +x /volume1/docker/nuclei/scripts/scan-with-ha-robust.sh"
    
    # Restart container to make sure it picks up the new script
    echo "Restarting Nuclei container to ensure script is available..."
    ssh ${NAS_USER}@${NAS_HOST} "docker restart nuclei-scanner"
    
    # Wait for container to restart
    echo "Waiting for container to restart..."
    sleep 10
fi

# Now that we know the script exists, let's create the direct run script
echo "Setting up direct run script..."
echo "Copying direct button configuration to Home Assistant..."

# Create integration directory if it doesn't exist
ssh ${NAS_USER}@${NAS_HOST} "mkdir -p /volume1/homeassistant/nuclei"

# Copy configuration files
scp ./ha-direct-button.yaml ${NAS_USER}@${NAS_HOST}:/volume1/homeassistant/nuclei/

# Create direct shell script on Home Assistant
ssh ${NAS_USER}@${NAS_HOST} "cat > /volume1/homeassistant/nuclei/run-nuclei-scan.sh << 'EOF'
#!/bin/bash
# Direct script for Home Assistant to trigger security scan
echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Triggering Nuclei scan from Home Assistant\" > /config/nuclei-scan.log
docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-robust.sh
echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Scan triggered successfully\" >> /config/nuclei-scan.log
EOF"

# Make it executable
ssh ${NAS_USER}@${NAS_HOST} "chmod +x /volume1/homeassistant/nuclei/run-nuclei-scan.sh"

# Update Home Assistant configuration
echo "Adding include to Home Assistant configuration..."
ssh ${NAS_USER}@${NAS_HOST} "grep -q 'nuclei/ha-direct-button.yaml' /volume1/homeassistant/configuration.yaml || echo 'include: !include nuclei/ha-direct-button.yaml' >> /volume1/homeassistant/configuration.yaml"

# Create the Home Assistant helpers
echo "Creating Home Assistant shell_command integration..."
ssh ${NAS_USER}@${NAS_HOST} "cat > /volume1/homeassistant/nuclei/shell_commands.yaml << 'EOF'
# Shell command to run Nuclei scan
shell_command:
  run_nuclei_scan: 'bash /config/nuclei/run-nuclei-scan.sh'
EOF"

# Add the include for shell commands if it doesn't exist
ssh ${NAS_USER}@${NAS_HOST} "grep -q 'nuclei/shell_commands.yaml' /volume1/homeassistant/configuration.yaml || echo 'include: !include nuclei/shell_commands.yaml' >> /volume1/homeassistant/configuration.yaml"

# Update the button configuration to use the local script
ssh ${NAS_USER}@${NAS_HOST} "cat > /volume1/homeassistant/nuclei/button.yaml << 'EOF'
# Button for triggering Nuclei scans
button:
  - platform: template
    buttons:
      run_security_scan:
        friendly_name: 'Run Network Security Scan'
        icon_template: 'mdi:shield-search'
        press:
          service: script.run_security_scan

# Script that runs the scan and provides feedback
script:
  run_security_scan:
    alias: 'Run Security Scan'
    icon: mdi:shield-search
    sequence:
      # Update the status entity to show scanning
      - service: homeassistant.update_entity
        target:
          entity_id: sensor.nuclei_scanner_status
        data:
          state: 'scanning'
      
      # Run the actual scan
      - service: shell_command.run_nuclei_scan
      
      # Show notification that scan was triggered
      - service: persistent_notification.create
        data:
          title: 'Security Scan Triggered'
          message: 'The network security scan has been started. You will be notified when it completes.'
          notification_id: 'security_scan_started'
EOF"

# Add the include for button if it doesn't exist
ssh ${NAS_USER}@${NAS_HOST} "grep -q 'nuclei/button.yaml' /volume1/homeassistant/configuration.yaml || echo 'include: !include nuclei/button.yaml' >> /volume1/homeassistant/configuration.yaml"

echo ""
echo "✅ Home Assistant button integration deployed!"
echo ""
echo "Please restart Home Assistant to activate the integration:"
echo "1. Go to Home Assistant > Configuration > Settings > System"
echo "2. Click the 'RESTART' button in the top right"
echo ""
echo "After restarting, you should see a 'Run Network Security Scan' button"
echo "in your Home Assistant dashboard that you can add to Lovelace."