#!/bin/sh
# Simple test scan to verify functionality

SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/test-${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

echo "Starting test scan..."
echo "Results will be saved to: $RESULTS_DIR"

# Test scan on a single host
echo "Scanning UDM PRO..."
nuclei -u https://192.168.10.1 \
       -o "$RESULTS_DIR/udm-pro.json" \
       -j

echo ""
echo "Scan completed!"
echo "Files created:"
ls -la "$RESULTS_DIR"

if [ -f "$RESULTS_DIR/udm-pro.json" ]; then
    echo ""
    echo "Sample output:"
    head -5 "$RESULTS_DIR/udm-pro.json"
fi