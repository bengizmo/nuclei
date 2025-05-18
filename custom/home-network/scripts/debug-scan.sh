#!/bin/sh
# Debug scan to test connectivity

echo "Debug scan starting..."
RESULTS_DIR="/home/nuclei/results/debug-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "1. Testing connectivity to UDM..."
curl -k -s --connect-timeout 5 https://192.168.10.1 > "$RESULTS_DIR/curl-test.txt"
echo "Curl exit code: $?"

echo "2. Running nuclei with verbose output..."
nuclei -u https://192.168.10.1 \
       -t ssl/ssl-dns-names.yaml \
       -debug \
       -j -o "$RESULTS_DIR/debug.json" 2>&1 | tee "$RESULTS_DIR/debug.log"

echo "3. Testing with http instead of https..."
nuclei -u http://192.168.10.1 \
       -t technologies/ \
       -j -o "$RESULTS_DIR/http-test.json"

echo "4. Available templates in ssl directory..."
ls -la /root/nuclei-templates/ssl/ | head -10

echo ""
echo "Results:"
ls -la "$RESULTS_DIR/"
echo ""
echo "Curl response (first 100 chars):"
head -c 100 "$RESULTS_DIR/curl-test.txt"