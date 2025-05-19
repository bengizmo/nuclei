#!/bin/sh
# Enhanced profile script for newly discovered hosts
# Includes ProjectDiscovery API integration for AI-powered template selection

IP="$1"
VLAN_NAME="$2"
PROFILE_DIR="/home/nuclei/discovery/profiles"
DISCOVERY_DB="/home/nuclei/discovery/discovery.db"
LOG_FILE="/home/nuclei/logs/profiling.log"
PDCP_API_KEY="${PDCP_API_KEY}"

# Create profile directory
mkdir -p "$PROFILE_DIR"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "Starting enhanced profile scan for new host: $IP on $VLAN_NAME"

# Step 1: Comprehensive NMAP scan
PROFILE_FILE="$PROFILE_DIR/${IP}.json"
log_message "Running comprehensive NMAP scan on $IP..."

# Deep scan with all script categories
nmap -sS -sV -O -A -p- \
    --script-args unsafe=1 \
    --script "default,discovery,exploit,vuln" \
    --script-timeout 60s \
    -oA "$PROFILE_DIR/${IP}" \
    "$IP" 2>/dev/null

# Parse NMAP results
OS_GUESS=$(grep "Running: " "$PROFILE_DIR/${IP}.nmap" | head -1 | sed 's/Running: //')
if [ -z "$OS_GUESS" ]; then
    OS_GUESS=$(grep "OS details: " "$PROFILE_DIR/${IP}.nmap" | head -1 | sed 's/OS details: //')
fi

# Extract detailed service information
SERVICES=$(grep -E "^[0-9]+/tcp.*open" "$PROFILE_DIR/${IP}.nmap" | \
    awk '{print $1 "|" $3 "|" $4 "|" $5}' | tr '\n' ';')

# Extract HTTP titles and headers if available
HTTP_INFO=$(grep -E "http-title:|http-headers:" "$PROFILE_DIR/${IP}.nmap" -A 5)

# Extract vulnerability findings from NMAP scripts
NMAP_VULNS=$(grep -E "VULNERABLE:|CVE-" "$PROFILE_DIR/${IP}.nmap")

# Step 2: Device fingerprinting and classification
DEVICE_TYPE="unknown"
DEVICE_CONTEXT=""

# Enhanced device detection with context
if echo "$SERVICES" | grep -E "22/tcp.*ssh" >/dev/null; then
    DEVICE_TYPE="linux-server"
    SSH_VERSION=$(grep "22/tcp" "$PROFILE_DIR/${IP}.nmap" | grep -oE "OpenSSH_[0-9.]+")
    DEVICE_CONTEXT="SSH server ${SSH_VERSION}"
fi

if echo "$SERVICES" | grep -E "(80|443|8080|8443)/tcp.*http" >/dev/null; then
    WEB_TECH=$(grep -E "http-server-header:|http-generator:" "$PROFILE_DIR/${IP}.nmap" | \
        sed 's/.*: //' | tr '\n' ' ')
    DEVICE_CONTEXT="${DEVICE_CONTEXT} Web: ${WEB_TECH}"
    
    # Check for specific web applications
    if echo "$HTTP_INFO" | grep -iE "synology|dsm" >/dev/null; then
        DEVICE_TYPE="synology-nas"
    elif echo "$HTTP_INFO" | grep -iE "unifi|ubiquiti" >/dev/null; then
        DEVICE_TYPE="ubiquiti-device"
    elif echo "$HTTP_INFO" | grep -iE "plex|media|server" >/dev/null; then
        DEVICE_TYPE="media-server"
    elif echo "$HTTP_INFO" | grep -iE "home.?assistant|hass" >/dev/null; then
        DEVICE_TYPE="home-automation"
    fi
fi

if echo "$SERVICES" | grep -E "445/tcp.*microsoft-ds" >/dev/null; then
    DEVICE_TYPE="windows-host"
    DEVICE_CONTEXT="${DEVICE_CONTEXT} SMB/CIFS enabled"
fi

if echo "$SERVICES" | grep -E "(554|8554)/tcp.*rtsp" >/dev/null; then
    DEVICE_TYPE="ip-camera"
    DEVICE_CONTEXT="${DEVICE_CONTEXT} RTSP streaming"
fi

if echo "$OS_GUESS" | grep -iE "router|switch|cisco|juniper|mikrotik" >/dev/null; then
    DEVICE_TYPE="network-infrastructure"
    DEVICE_CONTEXT="${DEVICE_CONTEXT} Network device: ${OS_GUESS}"
fi

# Step 3: Use ProjectDiscovery AI to generate custom templates
if [ -n "$PDCP_API_KEY" ]; then
    log_message "Generating AI-powered templates for $DEVICE_TYPE at $IP"
    
    # Create AI prompt based on device profile
    AI_PROMPT="Generate nuclei templates for ${DEVICE_TYPE} device with: OS=${OS_GUESS}, Services=${SERVICES}, Context=${DEVICE_CONTEXT}"
    
    # Add specific vulnerability context if found
    if [ -n "$NMAP_VULNS" ]; then
        AI_PROMPT="${AI_PROMPT}. Known vulnerabilities: ${NMAP_VULNS}"
    fi
    
    # Call nuclei with AI flag to generate and run templates
    nuclei -ai "$AI_PROMPT" -target "$IP" \
        -severity low,medium,high,critical \
        -o "$PROFILE_DIR/${IP}-ai-scan.json" \
        -jsonl \
        2>&1 | tee -a "$LOG_FILE"
    
    # Store the generated template IDs for future reference
    TEMPLATE_IDS=$(grep "Template ID:" "$LOG_FILE" | tail -5 | awk '{print $3}')
    echo "$TEMPLATE_IDS" > "$PROFILE_DIR/${IP}-templates.txt"
else
    log_message "PDCP API key not found, using standard template selection"
fi

# Step 4: Run comprehensive scan with standard templates
log_message "Running comprehensive Nuclei scan for $DEVICE_TYPE"

SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/auto-discovery/${SCAN_DATE}-${IP}"
mkdir -p "$RESULTS_DIR"

# Define template categories based on device type
case "$DEVICE_TYPE" in
    "synology-nas")
        TEMPLATES="exposed-panels/synology/ cves/synology/ default-logins/ network/synology/"
        ;;
    "ubiquiti-device")
        TEMPLATES="exposed-panels/unifi/ default-logins/unifi/ cves/unifi/ routers/"
        ;;
    "media-server")
        TEMPLATES="exposed-panels/plex/ exposed-panels/jellyfin/ exposed-panels/emby/ misconfiguration/"
        ;;
    "home-automation")
        TEMPLATES="iot/ exposed-panels/home-assistant/ misconfiguration/ default-logins/"
        ;;
    "windows-host")
        TEMPLATES="windows/ smb/ rdp/ cves/windows/ exposures/configs/"
        ;;
    "ip-camera")
        TEMPLATES="iot/cameras/ rtsp/ default-logins/ exposures/"
        ;;
    "network-infrastructure")
        TEMPLATES="routers/ network-devices/ default-logins/ snmp/ exposures/"
        ;;
    *)
        TEMPLATES="misc/ exposures/ default-logins/ technologies/"
        ;;
esac

# Add general security checks
TEMPLATES="$TEMPLATES misconfigurations/ exposures/tokens/ exposures/files/"

# Run scans with each template category
for template in $TEMPLATES; do
    if [ -d "/home/nuclei/nuclei-templates/$template" ]; then
        log_message "Scanning with templates: $template"
        nuclei -target "$IP" \
            -t "$template" \
            -severity low,medium,high,critical \
            -o "$RESULTS_DIR/scan-$(echo $template | tr '/' '-').json" \
            -json \
            -silent \
            2>/dev/null
    fi
done

# Step 5: Update discovery database
log_message "Updating discovery database for $IP"

# Update with comprehensive profile
sed -i "s|^$IP|.*|$IP|$(arp -n $IP | awk '{print $3}' | grep -E '^[0-9a-fA-F:]+$' | head -1)|$(grep "^$IP|" "$DISCOVERY_DB" | cut -d'|' -f3)|$(date '+%Y-%m-%d %H:%M:%S')|$HOSTNAME|$OS_GUESS|$SERVICES|profiled-$DEVICE_TYPE|" "$DISCOVERY_DB" 2>/dev/null

# Step 6: Check findings and alert
ALL_FINDINGS=$(find "$RESULTS_DIR" -name "*.json" -exec cat {} \; 2>/dev/null | jq -s 'length' 2>/dev/null || echo 0)
AI_FINDINGS=$([ -f "$PROFILE_DIR/${IP}-ai-scan.json" ] && cat "$PROFILE_DIR/${IP}-ai-scan.json" | jq -s 'length' 2>/dev/null || echo 0)
TOTAL_FINDINGS=$((ALL_FINDINGS + AI_FINDINGS))

if [ "$TOTAL_FINDINGS" -gt 0 ]; then
    # Count by severity
    CRITICAL=$(find "$RESULTS_DIR" "$PROFILE_DIR" -name "*.json" -exec cat {} \; 2>/dev/null | \
        jq -r 'select(.info.severity == "critical")' | jq -s 'length')
    HIGH=$(find "$RESULTS_DIR" "$PROFILE_DIR" -name "*.json" -exec cat {} \; 2>/dev/null | \
        jq -r 'select(.info.severity == "high")' | jq -s 'length')
    
    log_message "Found $TOTAL_FINDINGS vulnerabilities (Critical: $CRITICAL, High: $HIGH) on $DEVICE_TYPE at $IP"
    
    # Alert only for critical/high findings
    if [ "$((CRITICAL + HIGH))" -gt 0 ]; then
        # Send priority alert
        # Ensure we have the token
        if [ -z "$HOME_ASSISTANT_API_TOKEN" ]; then
            echo "Warning: HOME_ASSISTANT_API_TOKEN not set"
        fi
        
        curl -s -X POST \
            -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{
                \"message\": \"Critical security alert: New $DEVICE_TYPE device at $IP has $CRITICAL critical and $HIGH high vulnerabilities\",
                \"title\": \"Security Alert - Immediate Action Required\",
                \"data\": {
                    \"priority\": \"high\",
                    \"ttl\": 0,
                    \"tag\": \"security-alert-$IP\"
                }
            }" \
            "http://192.168.10.89:8123/api/services/notify/notify"
    fi
    
    # Update sensor
    curl -s -X POST \
        -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"state\": \"alert\",
            \"attributes\": {
                \"friendly_name\": \"New Device Alert\",
                \"icon\": \"mdi:alert-circle\",
                \"device_ip\": \"$IP\",
                \"device_type\": \"$DEVICE_TYPE\",
                \"os\": \"$OS_GUESS\",
                \"vulnerabilities\": {
                    \"total\": $TOTAL_FINDINGS,
                    \"critical\": $CRITICAL,
                    \"high\": $HIGH
                },
                \"vlan\": \"$VLAN_NAME\",
                \"ai_scan\": $([ -n "$PDCP_API_KEY" ] && echo "true" || echo "false"),
                \"discovered_at\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\"
            }
        }" \
        "http://192.168.10.89:8123/api/states/sensor.nuclei_new_device_$IP"
else
    log_message "Device $IP ($DEVICE_TYPE) scanned successfully - no vulnerabilities found"
fi

# Generate comprehensive summary
/home/nuclei/scripts/generate-device-summary.sh "$IP" "$DEVICE_TYPE" "$TOTAL_FINDINGS"

log_message "Enhanced profile scan complete for $IP"