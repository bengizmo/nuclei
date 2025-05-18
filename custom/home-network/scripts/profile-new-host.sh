#!/bin/sh
# Profile a newly discovered host with detailed NMAP scan
# Then run targeted Nuclei scans based on the profile

IP="$1"
VLAN_NAME="$2"
PROFILE_DIR="/home/nuclei/discovery/profiles"
DISCOVERY_DB="/home/nuclei/discovery/discovery.db"
LOG_FILE="/home/nuclei/logs/profiling.log"

# Create profile directory
mkdir -p "$PROFILE_DIR"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "Starting profile scan for new host: $IP on $VLAN_NAME"

# Detailed OS and service detection
PROFILE_FILE="$PROFILE_DIR/${IP}.json"
log_message "Running detailed NMAP scan on $IP..."

# Comprehensive scan with OS detection, service detection, and script scanning
nmap -sS -sV -O -A -p- --script-timeout 30s \
    -oX "$PROFILE_DIR/${IP}.xml" \
    "$IP" 2>/dev/null | \
    grep -E "(Running:|Service Info:|open)" > "$PROFILE_DIR/${IP}.txt"

# Parse the results
OS_GUESS=$(nmap -O "$IP" 2>/dev/null | grep "Running: " | head -1 | sed 's/Running: //')
if [ -z "$OS_GUESS" ]; then
    OS_GUESS=$(nmap -O "$IP" 2>/dev/null | grep "OS details: " | head -1 | sed 's/OS details: //')
fi

# Get open ports and services
SERVICES=$(nmap -sV "$IP" 2>/dev/null | grep "open" | awk '{print $1 "/" $3}' | tr '\n' ',' | sed 's/,$//')

# Detect device type based on services and OS
DEVICE_TYPE="unknown"
NUCLEI_TEMPLATES=""

# Enhanced detection logic
if echo "$SERVICES" | grep -E "22/tcp/ssh" >/dev/null; then
    DEVICE_TYPE="linux-server"
    NUCLEI_TEMPLATES="exposed-panels/ default-logins/ cves/2024/ cves/2023/ ssh/"
fi

if echo "$SERVICES" | grep -E "(80/tcp|443/tcp|8080/tcp|8443/tcp)" >/dev/null; then
    if [ "$DEVICE_TYPE" = "unknown" ]; then
        DEVICE_TYPE="web-server"
    fi
    NUCLEI_TEMPLATES="$NUCLEI_TEMPLATES http/ exposed-panels/ default-logins/"
fi

if echo "$SERVICES" | grep -E "445/tcp|139/tcp" >/dev/null; then
    if echo "$OS_GUESS" | grep -i "windows" >/dev/null; then
        DEVICE_TYPE="windows-host"
        NUCLEI_TEMPLATES="smb/ rdp/ windows/ cves/windows/"
    fi
fi

if echo "$SERVICES" | grep -E "554/tcp|8554/tcp" >/dev/null; then
    DEVICE_TYPE="camera"
    NUCLEI_TEMPLATES="iot/ cameras/ default-logins/ rtsp/"
fi

if echo "$OS_GUESS" | grep -i "router\|switch\|cisco\|juniper" >/dev/null; then
    DEVICE_TYPE="network-device"
    NUCLEI_TEMPLATES="exposed-panels/ routers/ network-devices/ default-logins/"
fi

if echo "$SERVICES" | grep -E "1900/tcp|5353/udp" >/dev/null; then
    if echo "$OS_GUESS" | grep -i "apple\|macos\|ios" >/dev/null; then
        DEVICE_TYPE="apple-device"
        NUCLEI_TEMPLATES="apple/ mdns/"
    fi
fi

if echo "$SERVICES" | grep -E "9100/tcp" >/dev/null; then
    DEVICE_TYPE="printer"
    NUCLEI_TEMPLATES="printers/ exposed-panels/"
fi

if echo "$SERVICES" | grep -E "5900/tcp" >/dev/null; then
    DEVICE_TYPE="vnc-server"
    NUCLEI_TEMPLATES="vnc/ remote-access/"
fi

log_message "Profile complete for $IP: OS=$OS_GUESS, Type=$DEVICE_TYPE, Services=$SERVICES"

# Update discovery database with profile info
awk -v ip="$IP" -v os="$OS_GUESS" -v services="$SERVICES" -v type="$DEVICE_TYPE" \
    'BEGIN{FS=OFS="|"} $1==ip {$6=os; $7=services; $8="profiled-"type} 1' \
    "$DISCOVERY_DB" > "$DISCOVERY_DB.tmp" && mv "$DISCOVERY_DB.tmp" "$DISCOVERY_DB"

# Create targeted Nuclei scan based on profile
if [ "$DEVICE_TYPE" != "unknown" ] && [ -n "$NUCLEI_TEMPLATES" ]; then
    log_message "Running targeted Nuclei scan for $DEVICE_TYPE device at $IP"
    
    SCAN_DATE=$(date +%Y%m%d-%H%M%S)
    RESULTS_DIR="/home/nuclei/results/auto-discovery/${SCAN_DATE}-${IP}"
    mkdir -p "$RESULTS_DIR"
    
    # Run Nuclei with appropriate templates
    for template_dir in $NUCLEI_TEMPLATES; do
        log_message "Scanning $IP with templates: $template_dir"
        nuclei -target "$IP" \
            -t "$template_dir" \
            -severity low,medium,high,critical \
            -o "$RESULTS_DIR/nuclei-$(echo $template_dir | tr '/' '_').json" \
            -json \
            -silent \
            2>/dev/null
    done
    
    # Check for findings and update Home Assistant
    FINDINGS=$(find "$RESULTS_DIR" -name "*.json" -exec cat {} \; | wc -l)
    
    if [ "$FINDINGS" -gt 0 ]; then
        log_message "Found $FINDINGS vulnerabilities on new $DEVICE_TYPE device at $IP"
        
        # Send alert to Home Assistant
        curl -s -X POST \
            -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{
                \"state\": \"New device alert\",
                \"attributes\": {
                    \"friendly_name\": \"New Device Security Alert\",
                    \"icon\": \"mdi:alert\",
                    \"device_ip\": \"$IP\",
                    \"device_type\": \"$DEVICE_TYPE\",
                    \"os\": \"$OS_GUESS\",
                    \"vulnerabilities\": $FINDINGS,
                    \"vlan\": \"$VLAN_NAME\",
                    \"discovered_at\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\",
                    \"device\": {
                        \"identifiers\": [\"nuclei_scanner_001\"],
                        \"name\": \"Nuclei Scanner\",
                        \"model\": \"Network Vulnerability Scanner\",
                        \"manufacturer\": \"ProjectDiscovery\",
                        \"sw_version\": \"3.4.2\"
                    }
                }
            }" \
            "http://192.168.10.89:8123/api/states/sensor.nuclei_new_device_alert"
        
        # Generate AI summary for the new device
        /home/nuclei/scripts/generate-device-summary.sh "$IP" "$DEVICE_TYPE" "$FINDINGS"
    fi
else
    log_message "Unknown device type for $IP, skipping targeted scan"
fi

log_message "Profile and scan complete for $IP"