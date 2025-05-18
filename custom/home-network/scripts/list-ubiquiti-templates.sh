#!/bin/sh
# List available Ubiquiti and router templates

echo "Finding Ubiquiti-specific templates..."
nuclei -tl | grep -i ubiquiti

echo ""
echo "Finding router/network device templates..."
nuclei -tl | grep -E -i "(router|unifi|ubnt|network-device|firewall)"

echo ""
echo "Finding exposed panels templates..."
nuclei -tl | grep -E -i "(exposed-panels|panel)"

echo ""
echo "Finding default login templates..."
nuclei -tl | grep -E -i "(default-login|default-creds)"