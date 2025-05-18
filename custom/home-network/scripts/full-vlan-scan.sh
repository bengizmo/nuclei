#!/bin/sh
# Full multi-VLAN scanning script using tagged VLANs

echo "Starting full multi-VLAN security scan..."
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/${SCAN_DATE}"
mkdir -p "$RESULTS_DIR/ports"
mkdir -p "$RESULTS_DIR/vulnerabilities"

# Update Home Assistant
HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"

update_ha_status() {
    if [ -n "$HA_TOKEN" ]; then
        curl -s -X POST \
            -H "Authorization: Bearer ${HA_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{\"entity_id\": \"input_text.nuclei_status\", \"state\": \"$1\"}" \
            "${HA_BASE_URL}/api/states/input_text.nuclei_status"
    fi
}

# Notify start of scan
update_ha_status "scanning"

# Function to scan a subnet
scan_subnet() {
    local subnet=$1
    local vlan_name=$2
    local count=0
    
    echo "=== Scanning $vlan_name ($subnet) ==="
    
    # Use nmap for host discovery
    echo "Discovering hosts in $subnet..."
    # Get only IP addresses, not hostnames
    HOSTS=$(nmap -sn "$subnet" | grep "report for" | awk '{print $NF}' | tr -d '()')
    
    for host in $HOSTS; do
        count=$((count + 1))
        echo "Found host: $host"
        
        # Quick port scan
        echo "Scanning ports on $host..."
        nmap -p 22,80,443,445,3389,5900,8080,8443 "$host" > "$RESULTS_DIR/ports/${vlan_name}-${host}.txt"
        
        # Vulnerability scan for web services
        if nmap -p 80,443 "$host" | grep -E "80/tcp.*open|443/tcp.*open" > /dev/null; then
            echo "Scanning vulnerabilities on $host..."
            
            # HTTP scan
            if nmap -p 80 "$host" | grep "80/tcp.*open" > /dev/null; then
                nuclei -u "http://$host" \
                       -t exposures/ \
                       -t vulnerabilities/ \
                       -t technologies/ \
                       -s medium,high,critical \
                       -j -o "$RESULTS_DIR/vulnerabilities/${vlan_name}-${host}-http.json"
            fi
            
            # HTTPS scan
            if nmap -p 443 "$host" | grep "443/tcp.*open" > /dev/null; then
                nuclei -u "https://$host" \
                       -t ssl/ \
                       -t exposures/ \
                       -s medium,high,critical \
                       -j -o "$RESULTS_DIR/vulnerabilities/${vlan_name}-${host}-https.json"
            fi
        fi
    done
    
    echo "Found $count hosts in $vlan_name"
    echo $count
}

# Scan each VLAN
TOTAL_HOSTS=0

# Default VLAN (untagged)
HOSTS_DEFAULT=$(scan_subnet "192.168.10.0/24" "default")
TOTAL_HOSTS=$((TOTAL_HOSTS + HOSTS_DEFAULT))

# IOT VLAN (VLAN 2) - if interface exists
if ip link show eth0.2 >/dev/null 2>&1; then
    HOSTS_IOT=$(scan_subnet "192.168.14.0/24" "iot")
    TOTAL_HOSTS=$((TOTAL_HOSTS + HOSTS_IOT))
fi

# Guest VLAN (VLAN 3) - if interface exists  
if ip link show eth0.3 >/dev/null 2>&1; then
    HOSTS_GUEST=$(scan_subnet "192.168.5.0/24" "guest")
    TOTAL_HOSTS=$((TOTAL_HOSTS + HOSTS_GUEST))
fi

# Clients VLAN (VLAN 4) - if interface exists
if ip link show eth0.4 >/dev/null 2>&1; then
    HOSTS_CLIENTS=$(scan_subnet "192.168.6.0/24" "clients")
    TOTAL_HOSTS=$((TOTAL_HOSTS + HOSTS_CLIENTS))
fi

# Count vulnerabilities
FINDINGS=0
CRITICAL=0
HIGH=0

for file in "$RESULTS_DIR/vulnerabilities"/*.json; do
    if [ -f "$file" ] && [ -s "$file" ]; then
        matches=$(grep -c "matched-at" "$file" 2>/dev/null || echo 0)
        FINDINGS=$((FINDINGS + matches))
        
        critical_matches=$(grep -c '"severity":"critical"' "$file" 2>/dev/null || echo 0)
        CRITICAL=$((CRITICAL + critical_matches))
        
        high_matches=$(grep -c '"severity":"high"' "$file" 2>/dev/null || echo 0)
        HIGH=$((HIGH + high_matches))
    fi
done

# Generate summary
cat > "$RESULTS_DIR/summary.txt" <<EOF
Full Network Security Scan Summary
Date: $SCAN_DATE

=== Hosts Found ===
Default VLAN: $HOSTS_DEFAULT hosts
IOT VLAN: $HOSTS_IOT hosts  
Guest VLAN: $HOSTS_GUEST hosts
Clients VLAN: $HOSTS_CLIENTS hosts
Total: $TOTAL_HOSTS hosts

=== Vulnerabilities ===
Total: $FINDINGS
Critical: $CRITICAL
High: $HIGH
EOF

# Update Home Assistant
if [ -n "$HA_TOKEN" ]; then
    if [ "$FINDINGS" -gt 0 ]; then
        update_ha_status "alert"
    else
        update_ha_status "ok"
    fi
    
    curl -s -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"entity_id\": \"input_number.nuclei_hosts_scanned\", \"state\": \"${TOTAL_HOSTS}\"}" \
        "${HA_BASE_URL}/api/states/input_number.nuclei_hosts_scanned"
fi

# Generate AI summary and send notification
if [ -n "$OLLAMA_API" ]; then
    AI_SUMMARY=$(/home/nuclei/scripts/generate-scan-summary.sh "$RESULTS_DIR")
else
    AI_SUMMARY="Scanned $TOTAL_HOSTS hosts, found $FINDINGS vulnerabilities ($CRITICAL critical)"
fi

# Send notification
NOTIFICATION_DATA="{
    \"title\": \"🔍 Full Network Scan Complete\",
    \"message\": \"$AI_SUMMARY\",
    \"data\": {
        \"push\": {
            \"badge\": $FINDINGS,
            \"sound\": $([ "$FINDINGS" -gt 0 ] && echo '"critical"' || echo '"default"')
        }
    }
}"

curl -s -X POST "$HA_BASE_URL/api/services/notify/mobile_app_ben_s_iphone_15" \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$NOTIFICATION_DATA"

echo ""
echo "Scan complete!"
echo "Results saved to: $RESULTS_DIR"
cat "$RESULTS_DIR/summary.txt"

# Create symlink to latest results
ln -sf "$RESULTS_DIR" "/home/nuclei/results/latest"