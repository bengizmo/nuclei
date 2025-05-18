#!/bin/sh
# Quick targeted scan for UDM PRO

echo "Starting targeted UDM PRO scan..."
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/udm-quick-${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

TARGET="192.168.10.1"

echo "1. Checking UniFi panels..."
nuclei -u https://$TARGET \
       -t http/exposed-panels/unifi-panel.yaml \
       -t http/misconfiguration/installer/unifi-wizard-install.yaml \
       -j -o "$RESULTS_DIR/unifi-panels.json"

echo "2. Checking for Log4j vulnerability..."
nuclei -u https://$TARGET \
       -t http/vulnerabilities/other/unifi-network-log4j-rce.yaml \
       -j -o "$RESULTS_DIR/log4j.json"

echo "3. SSL certificate check..."
nuclei -u https://$TARGET \
       -t ssl/ssl-dns-names.yaml \
       -t ssl/expired-ssl.yaml \
       -t ssl/self-signed-ssl.yaml \
       -t ssl/weak-cipher-suites.yaml \
       -j -o "$RESULTS_DIR/ssl.json"

echo "4. Basic tech detection..."
nuclei -u https://$TARGET \
       -t technologies/tech-detect.yaml \
       -j -o "$RESULTS_DIR/tech.json"

echo "5. Check alternative ports..."
for port in 8443 8080 22; do
    echo "Checking port $port..."
    nuclei -u https://$TARGET:$port \
           -t exposed-panels/ \
           -t technologies/ \
           -timeout 5 \
           -j -o "$RESULTS_DIR/port-$port.json"
done

echo ""
echo "Scan completed!"
echo "Results:"
ls -la "$RESULTS_DIR/"
echo ""
echo "Non-empty results:"
find "$RESULTS_DIR" -name "*.json" -size +0c -exec sh -c 'echo "$(basename "$1"): $(wc -l < "$1") lines"' _ {} \;