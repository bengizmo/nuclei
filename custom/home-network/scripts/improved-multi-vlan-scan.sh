#!/bin/sh
# Improved multi-VLAN scanning script with better port detection

echo "Starting improved multi-VLAN security scan..."
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR/ports"
mkdir -p "$RESULTS_DIR/vulnerabilities"

# Function to scan ports on a target
scan_ports() {
    local ip=$1
    local name=$2
    echo "Scanning ports on $name ($ip)..."
    
    # Common ports to check
    PORTS="22 23 80 443 445 3389 5900 8080 8443 8883 6789 10001 11434 2375 2376 3000 5000 9000"
    
    echo "=== Port Scan: $name ($ip) ===" > "$RESULTS_DIR/ports/$name.txt"
    for port in $PORTS; do
        if nc -zv -w 2 $ip $port 2>&1 | grep -q "open\|succeeded"; then
            echo "Port $port: OPEN" >> "$RESULTS_DIR/ports/$name.txt"
            
            # Get service banner
            case $port in
                22)  banner=$(echo "QUIT" | nc -w 2 $ip 22 | head -1) ;;
                80)  banner=$(curl -s -I "http://$ip" | head -1) ;;
                443) banner=$(curl -s -I -k "https://$ip" | head -1) ;;
                *)   banner="Service detected" ;;
            esac
            echo "  Banner: $banner" >> "$RESULTS_DIR/ports/$name.txt"
        fi
    done
}

# Function to scan for vulnerabilities
scan_vulnerabilities() {
    local ip=$1
    local name=$2
    
    echo "Scanning for vulnerabilities on $name ($ip)..."
    
    # Web vulnerabilities (if port 80/443 open)
    if nc -zv -w 1 $ip 80 2>&1 | grep -q "open"; then
        echo "Scanning HTTP service..."
        nuclei -u "http://$ip" \
               -t technologies/ \
               -t vulnerabilities/ \
               -t exposures/ \
               -t cves/ \
               -s low,medium,high,critical \
               -j -o "$RESULTS_DIR/vulnerabilities/$name-http.json"
    fi
    
    if nc -zv -w 1 $ip 443 2>&1 | grep -q "open"; then
        echo "Scanning HTTPS service..."
        nuclei -u "https://$ip" \
               -t ssl/ \
               -t technologies/ \
               -s low,medium,high,critical \
               -j -o "$RESULTS_DIR/vulnerabilities/$name-https.json"
    fi
    
    # SSH vulnerabilities (if port 22 open)
    if nc -zv -w 1 $ip 22 2>&1 | grep -q "open"; then
        echo "Scanning SSH service..."
        nuclei -u "$ip" \
               -t network/enumeration/ssh-auth-methods.yaml \
               -t network/openssh-detect.yaml \
               -j -o "$RESULTS_DIR/vulnerabilities/$name-ssh.json"
    fi
}

# Scan critical infrastructure
echo "=== Scanning Critical Infrastructure ==="
scan_ports "192.168.10.1" "udm-pro"
scan_ports "192.168.10.249" "think-tank"
scan_ports "192.168.10.251" "rbhome"
scan_ports "192.168.10.89" "home-assistant"
scan_ports "192.168.10.163" "nas"

# Scan vulnerabilities on critical systems
scan_vulnerabilities "192.168.10.1" "udm-pro"
scan_vulnerabilities "192.168.10.249" "think-tank"
scan_vulnerabilities "192.168.10.251" "rbhome"
scan_vulnerabilities "192.168.10.89" "home-assistant"

# Scan VLANs
echo ""
echo "=== Scanning VLANs ==="

# Default VLAN (192.168.10.0/24)
echo "Scanning Default VLAN..."
for i in $(seq 1 254); do
    ip="192.168.10.$i"
    if nc -zv -w 1 $ip 80 2>/dev/null | grep -q "open"; then
        echo "Found web service at $ip"
        scan_ports "$ip" "default-vlan-$i"
        scan_vulnerabilities "$ip" "default-vlan-$i"
    fi
done

# Generate summary report
cat > "$RESULTS_DIR/summary.txt" <<EOF
Network Security Scan Summary
Date: $SCAN_DATE

=== Open Ports Summary ===
EOF

# Consolidate port scan results
for file in "$RESULTS_DIR/ports"/*.txt; do
    if [ -f "$file" ]; then
        echo "" >> "$RESULTS_DIR/summary.txt"
        cat "$file" >> "$RESULTS_DIR/summary.txt"
    fi
done

echo "" >> "$RESULTS_DIR/summary.txt"
echo "=== Vulnerability Summary ===" >> "$RESULTS_DIR/summary.txt"

# Count vulnerabilities by severity
for file in "$RESULTS_DIR/vulnerabilities"/*.json; do
    if [ -s "$file" ]; then
        name=$(basename "$file" .json)
        count=$(grep -c "matched-at" "$file" 2>/dev/null || echo 0)
        if [ "$count" -gt 0 ]; then
            echo "$name: $count findings" >> "$RESULTS_DIR/summary.txt"
        fi
    fi
done

echo ""
echo "Scan complete!"
echo "Results saved to: $RESULTS_DIR"
echo ""
cat "$RESULTS_DIR/summary.txt"

# Create symlink to latest results
ln -sf "$RESULTS_DIR" "/home/nuclei/results/latest"