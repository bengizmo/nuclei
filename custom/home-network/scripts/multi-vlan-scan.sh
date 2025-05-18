#!/bin/sh
# Improved multi-VLAN scanning with better port detection

SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR/ports"
mkdir -p "$RESULTS_DIR/scans"

# Function to check if host is alive
host_alive() {
    nc -zv -w 1 $1 80 2>/dev/null || nc -zv -w 1 $1 443 2>/dev/null || nc -zv -w 1 $1 22 2>/dev/null
}

# Function to scan common ports
scan_ports() {
    local ip=$1
    local vlan=$2
    
    COMMON_PORTS="22 80 443 8080 8443"
    for port in $COMMON_PORTS; do
        if nc -zv -w 1 $ip $port 2>&1 | grep -q "open"; then
            echo "$ip:$port:open" >> "$RESULTS_DIR/ports/$vlan.txt"
        fi
    done
}

# Scan VLANs
VLANS="10:default 14:iot 5:guest 6:clients"

for vlan_info in $VLANS; do
    vlan_id=$(echo $vlan_info | cut -d: -f1)
    vlan_name=$(echo $vlan_info | cut -d: -f2)
    
    echo "Scanning $vlan_name VLAN (192.168.$vlan_id.0/24)..."
    
    # Quick alive check for all IPs
    for i in $(seq 1 254); do
        ip="192.168.$vlan_id.$i"
        if host_alive $ip; then
            echo "Found live host: $ip"
            scan_ports $ip $vlan_name
            
            # Run nuclei on live hosts
            if nc -zv -w 1 $ip 80 2>/dev/null; then
                nuclei -u "http://$ip" -t technologies/ -j -o "$RESULTS_DIR/scans/$vlan_name-$i.json"
            fi
            if nc -zv -w 1 $ip 443 2>/dev/null; then
                nuclei -u "https://$ip" -t technologies/ -j -o "$RESULTS_DIR/scans/$vlan_name-$i-ssl.json"
            fi
        fi
    done
done

# Scan critical infrastructure with enhanced checks
nuclei -l /home/nuclei/critical-hosts.txt \
       -o "$RESULTS_DIR/critical-infrastructure.json" \
       -j \
       -s low,medium,high,critical \
       -t network/ -t ssl/ -t exposed-panels/ -t default-logins/

# Compile results and check for findings
echo "Scan completed at $SCAN_DATE" > "$RESULTS_DIR/summary.txt"
echo "Results available in: $RESULTS_DIR" >> "$RESULTS_DIR/summary.txt"

# Count JSON files
JSON_COUNT=$(find "$RESULTS_DIR" -name "*.json" | wc -l)
echo "Generated $JSON_COUNT result files" >> "$RESULTS_DIR/summary.txt"

# Simple check for findings
if grep -l "severity" "$RESULTS_DIR"/*.json 2>/dev/null; then
    update_home_assistant "alert" "Found vulnerabilities" "1"
    echo "Vulnerabilities found - check JSON files for details" >> "$RESULTS_DIR/summary.txt"
else
    update_home_assistant "ok" "No vulnerabilities found" "0"
    echo "No vulnerabilities found" >> "$RESULTS_DIR/summary.txt"
fi

# Create a latest symlink
ln -sf "$RESULTS_DIR" "/home/nuclei/results/latest"