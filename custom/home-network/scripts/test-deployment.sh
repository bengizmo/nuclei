#!/bin/bash
# Test deployment simulation

echo "=== Nuclei Deployment Test ==="
echo ""

# Load environment variables
if [ -f "../.env" ]; then
    source ../.env
    echo "✓ Environment variables loaded"
else
    echo "✗ Cannot load .env file"
    exit 1
fi

echo ""
echo "Simulating container deployment with:"
echo "- HOME_ASSISTANT_API_TOKEN: ${HOME_ASSISTANT_API_TOKEN:0:20}..."
echo "- PDCP_API_KEY: ${PDCP_API_KEY:0:8}..."
echo "- OLLAMA_API: http://192.168.10.249:11434/v1"
echo ""

# Test Home Assistant connectivity (if reachable)
echo "Testing Home Assistant connectivity..."
HA_URL="http://192.168.10.89:8123/api/"
response=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" "$HA_URL" 2>/dev/null || echo "unreachable")

if [ "$response" = "200" ]; then
    echo "✓ Home Assistant API accessible"
elif [ "$response" = "unreachable" ]; then
    echo "⚠ Home Assistant not reachable from this location (expected if not on home network)"
else
    echo "✗ Home Assistant API returned: $response"
fi

echo ""

# Test Ollama connectivity (if reachable)
echo "Testing Ollama connectivity..."
OLLAMA_URL="http://192.168.10.249:11434/api/tags"
response=$(curl -s -o /dev/null -w "%{http_code}" "$OLLAMA_URL" 2>/dev/null || echo "unreachable")

if [ "$response" = "200" ]; then
    echo "✓ Ollama API accessible"
elif [ "$response" = "unreachable" ]; then
    echo "⚠ Ollama not reachable from this location (expected if not on home network)"
else
    echo "✗ Ollama API returned: $response"
fi

echo ""

# Check for nuclei binary (simulate container environment)
echo "Checking for nuclei binary..."
if command -v nuclei &> /dev/null; then
    echo "✓ Nuclei binary found"
    nuclei_version=$(nuclei -version | grep -o "v[0-9.]*" | head -1)
    echo "  Version: $nuclei_version"
else
    echo "⚠ Nuclei binary not found (expected outside container)"
fi

echo ""

# Test AI template generation capability
echo "Testing AI template generation (dry run)..."
if [ -n "$PDCP_API_KEY" ]; then
    echo "✓ PDCP API key available for AI template generation"
    echo "  Example command: nuclei -ai \"detect exposed Synology NAS admin panels\""
else
    echo "✗ PDCP API key not available"
fi

echo ""

# Show deployment command
echo "To deploy on Synology NAS:"
echo "1. Copy this directory to NAS: /volume1/docker/nuclei/"
echo "2. SSH to NAS and run:"
echo "   cd /volume1/docker/nuclei"
echo "   docker-compose -f docker-compose-vlans.yml up -d"
echo ""
echo "=== Test complete ==="