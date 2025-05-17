#!/bin/bash
# local-test-scan.sh - Test script for local development

echo "Running Nuclei in local test mode..."

SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/local-test-${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

# Test basic functionality
echo "Testing Nuclei installation..."
nuclei -version

# Test template loading
echo "Testing template loading..."
nuclei -tl | head -10

# Test with minimal targets
echo "Running test scan on localhost..."
nuclei -target localhost \
       -t network/detection/openssh-detect.yaml \
       -o "$RESULTS_DIR/localhost-test.json" \
       -json \
       -v

# Test AI template generation (if API key is configured)
if [ ! -z "$PDCP_API_KEY" ]; then
    echo "Testing AI template generation..."
    nuclei -ai "detect exposed web services" \
           -silent \
           -no-color | head -20
fi

# Test custom targets if available
if [ -f /home/nuclei/test-hosts.txt ]; then
    echo "Scanning test hosts..."
    nuclei -list /home/nuclei/test-hosts.txt \
           -t network/detection/ \
           -o "$RESULTS_DIR/test-hosts.json" \
           -json \
           -severity low,medium,high,critical
fi

echo "Local test completed. Results in: $RESULTS_DIR"
ls -la "$RESULTS_DIR"