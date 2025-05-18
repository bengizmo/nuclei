#!/bin/sh
# Specific scan for Ubiquiti/UniFi devices

echo "Starting Ubiquiti-specific scan..."
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/ubiquiti-${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

# Define targets - UDM PRO and APs
cat > "$RESULTS_DIR/ubiquiti-targets.txt" <<EOF
https://192.168.10.1
https://192.168.10.156
https://192.168.10.50  
https://192.168.10.7
https://192.168.10.130
EOF

echo "Scanning Ubiquiti devices..."

# Run targeted scans
echo "1. Checking for UniFi exposed panels..."
nuclei -l "$RESULTS_DIR/ubiquiti-targets.txt" \
       -tags unifi,ubiquiti,panel \
       -s info,low,medium,high,critical \
       -j -o "$RESULTS_DIR/unifi-panels.json"

echo "2. Checking SSH services..."
nuclei -l "$RESULTS_DIR/ubiquiti-targets.txt" \
       -t network/ssh-auth.yaml \
       -t network/ssh-fingerprint.yaml \
       -t network/ssh-weakkey-exchange-algo.yaml \
       -s info,low,medium,high,critical \
       -j -o "$RESULTS_DIR/ssh-check.json"

echo "3. Checking for known vulnerabilities..."
nuclei -l "$RESULTS_DIR/ubiquiti-targets.txt" \
       -t cves/ -tags ubiquiti,unifi \
       -s medium,high,critical \
       -j -o "$RESULTS_DIR/cves.json"

echo "4. Port scan common Ubiquiti services..."
# Common UniFi ports
UNIFI_PORTS="22 80 443 8080 8443 8843 8880 6789 3478 10001 1900"
for port in $UNIFI_PORTS; do
    echo "Checking port $port..."
    for ip in 192.168.10.1 192.168.10.156 192.168.10.50 192.168.10.7 192.168.10.130; do
        nuclei -u "https://$ip:$port" \
               -t exposed-panels/ \
               -silent \
               -j -o "$RESULTS_DIR/port-$port-$ip.json" \
               -stats-interval 30
    done
done

echo "5. Technology fingerprinting..."
nuclei -l "$RESULTS_DIR/ubiquiti-targets.txt" \
       -t technologies/tech-detect.yaml \
       -t technologies/ubiquiti-unifi-detect.yaml \
       -s info \
       -j -o "$RESULTS_DIR/tech-detect.json"

echo ""
echo "Scan completed!"
echo "Results: $RESULTS_DIR"

# Create summary
echo "Generating summary..."
cat > "$RESULTS_DIR/summary.txt" <<EOF
Ubiquiti Network Device Security Scan
Date: $SCAN_DATE

Devices Scanned:
- UDM PRO: 192.168.10.1
- AP 1: 192.168.10.156
- AP 2: 192.168.10.50
- AP 3: 192.168.10.7
- AP 4: 192.168.10.130

Findings:
EOF

find "$RESULTS_DIR" -name "*.json" -size +0c -exec sh -c '
    echo "" >> "'$RESULTS_DIR'/summary.txt"
    echo "=== $(basename "$1" .json) ===" >> "'$RESULTS_DIR'/summary.txt"
    echo "Size: $(wc -c < "$1") bytes" >> "'$RESULTS_DIR'/summary.txt"
    echo "Matches: $(grep -c "matched-at" "$1" 2>/dev/null || echo 0)" >> "'$RESULTS_DIR'/summary.txt"
' _ {} \;

echo ""
cat "$RESULTS_DIR/summary.txt"