#!/bin/sh
# Comprehensive scan for Ubiquiti Dream Machine Pro

echo "Starting comprehensive UDM PRO scan..."
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/comprehensive-${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

# Update templates first
echo "Updating templates..."
nuclei -ut

# Target
TARGET="https://192.168.10.1"

echo "Phase 1: Technology detection..."
nuclei -u $TARGET \
       -t technologies/ \
       -s info,low,medium,high,critical \
       -j -o "$RESULTS_DIR/tech-detect.json"

echo "Phase 2: Network device specific scans..."
nuclei -u $TARGET \
       -t network/ \
       -t iot/ \
       -t exposed-panels/unifi-panel.yaml \
       -t exposed-panels/unifi-network-panel.yaml \
       -t exposed-panels/ubnt-panel.yaml \
       -s info,low,medium,high,critical \
       -j -o "$RESULTS_DIR/network-devices.json"

echo "Phase 3: SSL/TLS analysis..."
nuclei -u $TARGET \
       -t ssl/ \
       -s info,low,medium,high,critical \
       -j -o "$RESULTS_DIR/ssl-analysis.json"

echo "Phase 4: Vulnerability scan..."
nuclei -u $TARGET \
       -t cves/ \
       -t vulnerabilities/ \
       -s medium,high,critical \
       -j -o "$RESULTS_DIR/vulnerabilities.json"

echo "Phase 5: Default credentials check..."
nuclei -u $TARGET \
       -t default-logins/ \
       -t exposed-panels/ \
       -s low,medium,high,critical \
       -j -o "$RESULTS_DIR/default-creds.json"

echo "Phase 6: Generic security misconfigurations..."
nuclei -u $TARGET \
       -t misconfiguration/ \
       -t misconfigurations/ \
       -t exposures/ \
       -s low,medium,high,critical \
       -j -o "$RESULTS_DIR/misconfig.json"

echo "Phase 7: Port scan on common services..."
# Scan multiple ports that UDM typically uses
for port in 22 80 443 8080 8443 8883 6789 10001; do
    echo "Scanning port $port..."
    nuclei -u "${TARGET%:*}:$port" \
           -t exposed-panels/ \
           -t technologies/ \
           -s info,low,medium,high,critical \
           -j -o "$RESULTS_DIR/port-$port.json" \
           -stats-interval 30
done

echo ""
echo "Scan completed!"
echo "Results saved to: $RESULTS_DIR"
echo ""
echo "Summary:"
find "$RESULTS_DIR" -name "*.json" -exec sh -c 'echo "File: $1 (Size: $(wc -c < "$1") bytes)"' _ {} \;

# Create a summary report
echo "Creating summary report..."
cat > "$RESULTS_DIR/summary.txt" <<EOF
Comprehensive UDM PRO Security Scan
Date: $SCAN_DATE
Target: $TARGET

Scan Results:
EOF

# Add findings to summary
for file in "$RESULTS_DIR"/*.json; do
    if [ -s "$file" ]; then
        echo "" >> "$RESULTS_DIR/summary.txt"
        echo "=== $(basename $file .json) ===" >> "$RESULTS_DIR/summary.txt"
        echo "Findings: $(grep -c '"matched-at"' "$file" 2>/dev/null || echo 0)" >> "$RESULTS_DIR/summary.txt"
    fi
done

echo ""
echo "Summary report: $RESULTS_DIR/summary.txt"
ln -sf "$RESULTS_DIR" "/home/nuclei/results/latest-comprehensive"