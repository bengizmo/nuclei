#!/bin/bash
# Validate configuration and container functionality

echo "=== Nuclei Container Configuration Validation ==="
echo ""

# Check if .env file exists
if [ -f "../.env" ]; then
    echo "✓ .env file found"
    
    # Check required environment variables
    if grep -q "HOME_ASSISTANT_API_TOKEN=" "../.env"; then
        echo "✓ HOME_ASSISTANT_API_TOKEN is set"
    else
        echo "✗ HOME_ASSISTANT_API_TOKEN is missing"
    fi
    
    if grep -q "PDCP_API_KEY=" "../.env"; then
        echo "✓ PDCP_API_KEY is set"
    else
        echo "✗ PDCP_API_KEY is missing"
    fi
else
    echo "✗ .env file not found"
fi

echo ""

# Check docker-compose.yml
if [ -f "../docker-compose-vlans.yml" ]; then
    echo "✓ docker-compose-vlans.yml found"
    
    # Check if environment variables are referenced correctly
    if grep -q "PDCP_API_KEY=\${PDCP_API_KEY}" "../docker-compose-vlans.yml"; then
        echo "✓ PDCP_API_KEY uses environment variable"
    else
        echo "✗ PDCP_API_KEY may be hardcoded"
    fi
    
    if grep -q "HOME_ASSISTANT_API_TOKEN=\${HOME_ASSISTANT_API_TOKEN}" "../docker-compose-vlans.yml"; then
        echo "✓ HOME_ASSISTANT_API_TOKEN uses environment variable"
    else
        echo "✗ HOME_ASSISTANT_API_TOKEN may be hardcoded"
    fi
else
    echo "✗ docker-compose-vlans.yml not found"
fi

echo ""

# Check required scripts
REQUIRED_SCRIPTS=(
    "full-vlan-scan.sh"
    "generate-scan-summary.sh"
    "ha-update-final.sh"
    "create-vlans-manual.sh"
)

echo "Checking required scripts:"
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        echo "✓ $script found"
    else
        echo "✗ $script missing"
    fi
done

echo ""

# Check critical configuration files
if [ -f "../critical-hosts.txt" ]; then
    echo "✓ critical-hosts.txt found"
    echo "  Contains $(wc -l < ../critical-hosts.txt) entries"
else
    echo "✗ critical-hosts.txt missing"
fi

echo ""

# Test environment variable loading
echo "Testing environment variable loading:"
if [ -f "../.env" ]; then
    source ../.env
    if [ -n "$PDCP_API_KEY" ]; then
        echo "✓ PDCP_API_KEY loaded successfully (${PDCP_API_KEY:0:8}...)"
    else
        echo "✗ PDCP_API_KEY failed to load"
    fi
    
    if [ -n "$HOME_ASSISTANT_API_TOKEN" ]; then
        echo "✓ HOME_ASSISTANT_API_TOKEN loaded successfully (${HOME_ASSISTANT_API_TOKEN:0:20}...)"
    else
        echo "✗ HOME_ASSISTANT_API_TOKEN failed to load"
    fi
fi

echo ""
echo "=== Configuration validation complete ==="