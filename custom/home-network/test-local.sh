#!/bin/bash
# Test script for running nuclei locally without Docker

# Check if nuclei is installed
if ! command -v nuclei &> /dev/null; then
    echo "Nuclei is not installed. Installing..."
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
fi

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo "Starting local Nuclei test..."

# Create results directory
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="./results/local-test-${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

# Test nuclei version
echo "Nuclei version:"
nuclei -version

# Update templates
echo "Updating templates..."
nuclei -ut

# Test basic scan on localhost
echo "Testing localhost..."
nuclei -target localhost \
       -t network/detection/ \
       -o "$RESULTS_DIR/localhost.txt" \
       -v

# Test AI functionality if API key is present
if [ ! -z "$PDCP_API_KEY" ]; then
    echo "Testing AI template generation..."
    nuclei -ai "detect exposed services on network devices" | head -20
fi

# Scan test hosts
echo "Scanning test hosts..."
nuclei -list test-hosts.txt \
       -t network/detection/ \
       -t exposed-panels/ \
       -t technologies/ \
       -severity low,medium,high,critical \
       -o "$RESULTS_DIR/test-hosts.json" \
       -j \
       -stats

echo "Test completed. Results in: $RESULTS_DIR"
ls -la "$RESULTS_DIR"