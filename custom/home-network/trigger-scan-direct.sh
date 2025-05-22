#\!/bin/bash
# Directly trigger a Nuclei scan

cd "$(dirname "$0")"
source ./nas-config.sh

echo "🔍 Triggering Nuclei security scan"
echo "=============================="

# Check if NAS is reachable
if ping -c 1 -W 1 "${NAS_HOST}" &> /dev/null; then
    echo "✅ NAS is reachable"
else
    echo "❌ ERROR: Cannot reach NAS at ${NAS_HOST}"
    exit 1
fi

# Trigger scan directly in container
echo "Starting scan..."
ssh "${NAS_USER}@${NAS_HOST}" "/usr/local/bin/docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-robust.sh"

echo ""
echo "✅ Scan completed\!"
echo "Check Home Assistant for results."
EOF < /dev/null