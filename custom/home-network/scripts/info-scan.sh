#!/bin/sh
# Information gathering scan

echo "Starting information scan..."
RESULTS_DIR="/home/nuclei/results/info-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Run with info severity templates
echo "Scanning router for basic info..."
nuclei -u https://192.168.10.1 -t technologies/ -t exposed-panels/ -s info -j -o "$RESULTS_DIR/router-info.json"

echo "Checking SSL certificate..."
nuclei -u https://192.168.10.1 -t ssl/detect-ssl-issuer.yaml -j -o "$RESULTS_DIR/ssl-check.json"

echo "Results:"
ls -la "$RESULTS_DIR/"