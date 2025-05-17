#!/bin/sh
# Minimal test scan

echo "Testing nuclei..."
nuclei -u https://192.168.10.1 -t ssl/