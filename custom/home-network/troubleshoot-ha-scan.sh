#!/bin/bash
# Comprehensive troubleshooting script for Home Assistant scan trigger
# This script will diagnose common issues with the scan trigger system

cd "$(dirname "$0")"

echo "🔍 Home Assistant Nuclei Scan Troubleshooting"
echo "============================================="
echo ""

# Load configuration
if [ -f .env ]; then
    source .env
fi
if [ -f nas-config.sh ]; then
    source ./nas-config.sh
fi

# 1. Check Home Assistant API connectivity
echo "1. Testing Home Assistant API connectivity..."
if [ -n "$HOME_ASSISTANT_API_TOKEN" ]; then
    status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
        -H "Content-Type: application/json" \
        "http://192.168.10.89:8123/api/")
    
    if [ "$status_code" -eq 200 ]; then
        echo "   ✅ Home Assistant API is accessible"
    else
        echo "   ❌ Home Assistant API returned status: $status_code"
    fi
else
    echo "   ❌ HOME_ASSISTANT_API_TOKEN not found"
fi

# 2. Check NAS connectivity
echo ""
echo "2. Testing NAS connectivity..."
if ping -c 1 -W 1 "${NAS_HOST:-192.168.10.163}" &> /dev/null; then
    echo "   ✅ NAS is reachable at ${NAS_HOST:-192.168.10.163}"
else
    echo "   ❌ Cannot reach NAS at ${NAS_HOST:-192.168.10.163}"
fi

# 3. Check SSH connectivity to NAS
echo ""
echo "3. Testing SSH connectivity to NAS..."
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${NAS_USER:-ben}@${NAS_HOST:-192.168.10.163}" "echo 'SSH connection successful'" 2>/dev/null; then
    echo "   ✅ SSH connection to NAS successful"
else
    echo "   ❌ SSH connection to NAS failed"
    echo "   Check your SSH keys and NAS settings"
fi

# 4. Check if Nuclei container is running
echo ""
echo "4. Checking Nuclei container status..."
CONTAINER_STATUS=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${NAS_USER:-ben}@${NAS_HOST:-192.168.10.163}" "docker ps --filter name=nuclei-scanner --format '{{.Status}}'" 2>/dev/null)
if [ -n "$CONTAINER_STATUS" ]; then
    echo "   ✅ Nuclei container status: $CONTAINER_STATUS"
else
    echo "   ❌ Nuclei container not found or not running"
fi

# 5. Check if scan script exists in container
echo ""
echo "5. Checking if scan script exists in container..."
SCRIPT_EXISTS=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${NAS_USER:-ben}@${NAS_HOST:-192.168.10.163}" "docker exec nuclei-scanner test -f /home/nuclei/scripts/scan-with-ha-robust.sh && echo 'exists' || echo 'missing'" 2>/dev/null)
if [ "$SCRIPT_EXISTS" = "exists" ]; then
    echo "   ✅ Scan script exists in container"
else
    echo "   ❌ Scan script not found in container"
fi

# 6. Check Home Assistant entities
echo ""
echo "6. Checking Home Assistant entities..."
if [ -n "$HOME_ASSISTANT_API_TOKEN" ]; then
    ENTITIES=$(curl -s -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
        "http://192.168.10.89:8123/api/states" | \
        jq -r '.[] | select(.entity_id | contains("nuclei")) | .entity_id' 2>/dev/null)
    
    if [ -n "$ENTITIES" ]; then
        echo "   ✅ Found Nuclei entities:"
        echo "$ENTITIES" | while read -r entity; do
            echo "      - $entity"
        done
    else
        echo "   ❌ No Nuclei entities found"
    fi
fi

# 7. Test direct scan trigger
echo ""
echo "7. Testing direct scan trigger (this will actually start a scan)..."
echo "   Would you like to test the direct scan trigger? (y/n)"
read -r response
if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
    echo "   Starting scan test..."
    
    # Update status to scanning
    if [ -n "$HOME_ASSISTANT_API_TOKEN" ]; then
        curl -s -X POST \
            -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{
                "state": "scanning",
                "attributes": {
                    "friendly_name": "Scanner Status",
                    "icon": "mdi:shield-search"
                }
            }' \
            "http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_status"
        echo "   ✅ Updated HA status to scanning"
    fi
    
    # Trigger scan
    echo "   Triggering scan on NAS..."
    ssh -o StrictHostKeyChecking=no "${NAS_USER:-ben}@${NAS_HOST:-192.168.10.163}" "docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-robust.sh" &
    SCAN_PID=$!
    
    echo "   ✅ Scan triggered with PID: $SCAN_PID"
    echo "   Check Home Assistant for status updates"
else
    echo "   Skipping scan test"
fi

# 8. Check Home Assistant logs
echo ""
echo "8. Checking for common issues..."
echo "   Common issues to check:"
echo "   - Is the shell_command properly configured in configuration.yaml?"
echo "   - Is the script path correct in Home Assistant?"
echo "   - Do you have proper SSH key authentication set up?"
echo "   - Is the input_button helper properly created?"
echo "   - Is the automation properly configured and enabled?"

echo ""
echo "============================================="
echo "Troubleshooting complete!"
echo ""
echo "If issues persist, check:"
echo "1. Home Assistant logs: Settings > System > Logs"
echo "2. NAS Docker logs: docker logs nuclei-scanner"
echo "3. SSH key authentication between HA and NAS"