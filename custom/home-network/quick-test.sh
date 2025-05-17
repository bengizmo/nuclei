#!/bin/bash
# Quick test script for accessible infrastructure

echo "Testing connectivity first..."
ping -c 1 192.168.10.1 > /dev/null && echo "✓ UDM PRO reachable" || echo "✗ UDM PRO not reachable"
ping -c 1 192.168.10.89 > /dev/null && echo "✓ Home Assistant reachable" || echo "✗ Home Assistant not reachable"
ping -c 1 192.168.10.249 > /dev/null && echo "✓ Think Tank reachable" || echo "✗ Think Tank not reachable"
ping -c 1 192.168.10.163 > /dev/null && echo "✓ NAS reachable" || echo "✗ NAS not reachable"

echo -e "\nStarting targeted Nuclei scan..."

# Create results directory
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="./results/quick-${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

# Scan UDM PRO specifically
echo -e "\nScanning UDM PRO (192.168.10.1)..."
nuclei -target 192.168.10.1 \
       -t http/exposures/panels/ \
       -t http/vulnerabilities/ \
       -t network/detection/ \
       -o "$RESULTS_DIR/udm-pro.txt" \
       -v

# Scan Home Assistant
echo -e "\nScanning Home Assistant (192.168.10.89)..."
nuclei -target 192.168.10.89 \
       -t http/exposures/panels/ \
       -t http/technologies/ \
       -o "$RESULTS_DIR/home-assistant.txt" \
       -v

# Scan NAS
echo -e "\nScanning NAS (192.168.10.163)..."
nuclei -target 192.168.10.163 \
       -t http/exposures/panels/ \
       -t network/detection/ \
       -o "$RESULTS_DIR/nas.txt" \
       -v

echo -e "\nTest completed. Results in: $RESULTS_DIR"
ls -la "$RESULTS_DIR"