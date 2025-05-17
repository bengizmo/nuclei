#!/bin/sh
# Quick scan for testing

echo "Starting quick network scan..."
RESULTS_DIR="/home/nuclei/results/quickscan-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Scan a few key hosts with targeted templates
echo "Scanning router..."
nuclei -u https://192.168.10.1 -t ssl/ -t exposed-panels/ -j -o "$RESULTS_DIR/router.json"

echo "Scanning Home Assistant..."
nuclei -u http://192.168.10.89:8123 -t technologies/ -t exposed-panels/ -j -o "$RESULTS_DIR/homeassistant.json"

echo "Scanning NAS..."
nuclei -u https://192.168.10.163:5001 -t exposed-panels/ -t technologies/ -j -o "$RESULTS_DIR/nas.json"

echo ""
echo "Quick scan completed!"
echo "Results in: $RESULTS_DIR"
ls -la "$RESULTS_DIR/"