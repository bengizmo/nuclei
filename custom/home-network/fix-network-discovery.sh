#!/bin/bash
# Fix the network discovery script that's failing to run

cd "$(dirname "$0")"
source ./nas-config.sh

echo "🔧 Fixing Network Discovery Script"
echo "=================================="

# Check what's in the discovery script
echo "1. Examining the network discovery script..."
echo "First 100 lines of the script:"
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner head -100 /home/nuclei/scripts/network-discovery.sh" 2>/dev/null

# Check if required tools are available
echo ""
echo "2. Checking required tools in container..."
echo "nmap availability:"
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner which nmap" 2>/dev/null || echo "nmap not found"

echo "nuclei availability:"
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner which nuclei" 2>/dev/null || echo "nuclei not found"

echo "curl availability:"
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner which curl" 2>/dev/null || echo "curl not found"

# Try to run the script manually and see the error
echo ""
echo "3. Running discovery script manually to see error..."
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner timeout 30 /home/nuclei/scripts/network-discovery.sh" 2>&1 || echo "Script execution failed"

# Check if the issue is with missing network-discovery.sh
echo ""
echo "4. Checking for network-discovery.sh script..."
DISCOVERY_SCRIPT_EXISTS=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner ls -la /home/nuclei/scripts/" 2>/dev/null | grep discovery)
echo "Discovery-related scripts:"
echo "$DISCOVERY_SCRIPT_EXISTS"

# Check if we need to create/fix the network discovery script
echo ""
echo "5. Checking if network-discovery.sh script needs to be created..."
if [ -z "$DISCOVERY_SCRIPT_EXISTS" ]; then
    echo "Network discovery script is missing - creating it..."
    
    # Create the network discovery script
    ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner cat > /home/nuclei/scripts/network-discovery.sh << 'EOF'
#!/bin/bash
# Network Discovery Script for Nuclei
# Scans all VLANs every 5 minutes for new devices

# Configuration
SCAN_INTERVAL=\${DISCOVERY_INTERVAL:-300}  # 5 minutes by default
DISCOVERY_DIR=\"/home/nuclei/discovery\"
PROFILES_DIR=\"\$DISCOVERY_DIR/profiles\"
DB_FILE=\"\$DISCOVERY_DIR/discovery.db\"
STATUS_FILE=\"\$DISCOVERY_DIR/status.json\"
LOG_FILE=\"/home/nuclei/logs/network-discovery.log\"

# Create required directories
mkdir -p \"\$PROFILES_DIR\"
mkdir -p \"/home/nuclei/logs\"

# VLANs to scan
VLANS=\"10 14 5 6\"

# Function to log with timestamp
log() {
    echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] \$1\" | tee -a \"\$LOG_FILE\"
}

# Function to scan a VLAN for active hosts
scan_vlan() {
    local vlan=\$1
    local network=\"192.168.\${vlan}.0/24\"
    
    log \"Scanning VLAN \$vlan (network \$network)\"
    
    # Quick ping scan to find active hosts
    nmap -sn \$network 2>/dev/null | grep \"Nmap scan report\" | awk '{print \$5}' | sort -V
}

# Function to profile a new host
profile_host() {
    local host=\$1
    local profile_file=\"\$PROFILES_DIR/\${host}.nmap\"
    
    log \"Profiling new host: \$host\"
    
    # Run nmap scan to profile the host
    nmap -sS -sU -O -sV --script=default -oA \"\$PROFILES_DIR/\$host\" \$host 2>/dev/null
    
    # If it's a new host, trigger a targeted scan
    if [ -f \"\$profile_file\" ]; then
        log \"Host \$host profiled successfully\"
        
        # Trigger targeted vulnerability scan
        trigger_host_scan \$host
    fi
}

# Function to trigger a targeted scan for a specific host
trigger_host_scan() {
    local host=\$1
    log \"Triggering targeted scan for host: \$host\"
    
    # Run nuclei scan against the specific host
    nuclei -target \$host \\
        -t /home/nuclei/nuclei-templates/ \\
        -o \"/home/nuclei/results/auto-discovery/\${host}-\$(date +%Y%m%d-%H%M%S).json\" \\
        -json 2>/dev/null &
}

# Initialize database if it doesn't exist
if [ ! -f \"\$DB_FILE\" ]; then
    touch \"\$DB_FILE\"
    log \"Initialized discovery database\"
fi

# Main discovery loop
log \"Starting network discovery service (interval: \${SCAN_INTERVAL}s)\"

while true; do
    # Update status
    echo \"{\\\"status\\\": \\\"scanning\\\", \\\"timestamp\\\": \\\"\$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\\\", \\\"vlans\\\": [\\\"\$(echo \$VLANS | tr ' ' ',')\\\"]}\\\"}\" > \"\$STATUS_FILE\"
    
    # Scan all VLANs
    for vlan in \$VLANS; do
        log \"Scanning VLAN \$vlan\"
        
        # Get current active hosts
        current_hosts=\$(scan_vlan \$vlan)
        
        # Check each host
        for host in \$current_hosts; do
            # Skip if host is already in database
            if ! grep -q \"\$host\" \"\$DB_FILE\" 2>/dev/null; then
                log \"New host discovered: \$host\"
                echo \"\$host\" >> \"\$DB_FILE\"
                
                # Profile the new host
                profile_host \$host
            fi
        done
    done
    
    # Update status to idle
    echo \"{\\\"status\\\": \\\"idle\\\", \\\"timestamp\\\": \\\"\$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\\\", \\\"last_scan\\\": \\\"\$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\\\"}\\\"}\" > \"\$STATUS_FILE\"
    
    log \"Discovery cycle complete. Sleeping for \${SCAN_INTERVAL} seconds...\"
    sleep \$SCAN_INTERVAL
done
EOF"
    
    # Make it executable
    ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner chmod +x /home/nuclei/scripts/network-discovery.sh"
    
    echo "✅ Created network discovery script"
else
    echo "Network discovery script exists but may have issues"
fi

# Restart the container to pick up the new script
echo ""
echo "6. Restarting container to apply fixes..."
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker restart nuclei-scanner"

# Wait for restart
sleep 10

# Check if discovery is now working
echo ""
echo "7. Checking if discovery service is now running..."
DISCOVERY_RUNNING=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner pgrep -f network-discovery" 2>/dev/null)

if [ -n "$DISCOVERY_RUNNING" ]; then
    echo "✅ Network discovery is now running (PID: $DISCOVERY_RUNNING)"
else
    echo "❌ Network discovery still not running"
    
    # Check recent logs
    echo "Recent container logs:"
    ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker logs nuclei-scanner --tail 20" 2>/dev/null
fi

echo ""
echo "=================================="
echo "Network discovery fix complete!"
echo ""
echo "The system should now:"
echo "1. Run network discovery every 5 minutes"
echo "2. Profile new hosts automatically"
echo "3. Trigger targeted scans for new hosts"
echo "4. Run full scans at 3:00 AM and 3:00 PM daily"