#!/bin/bash
# Manually run a Nuclei scan now from the command line

cd "$(dirname "$0")"
source ./nas-config.sh

echo "🔍 Triggering Nuclei security scan"
echo "=============================="

# Check if NAS is reachable
if ping -c 1 -W 1 "${NAS_HOST}" &> /dev/null; then
    echo "✅ NAS is reachable"
else
    echo "❌ ERROR: Cannot reach NAS at ${NAS_HOST}"
    echo "Please make sure the NAS is online and try again."
    exit 1
fi

# Trigger the scan via SSH
echo "Triggering scan on NAS..."
ssh "${NAS_USER}@${NAS_HOST}" "cd /volume1/docker/nuclei && ./run-scan-now.sh"

echo ""
echo "✅ Scan triggered successfully!"
echo "Check Home Assistant for scan progress and results."
echo "Full scan results will be saved on the NAS."