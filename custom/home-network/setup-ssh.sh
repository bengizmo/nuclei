#!/bin/bash
# Setup SSH connection to NAS

echo "🔐 Setting up SSH connection to NAS..."
echo ""

# Load current config
source ./nas-config.sh

echo "Current configuration:"
echo "  NAS User: ${NAS_USER}"
echo "  NAS Host: ${NAS_HOST}"
echo ""

read -p "Is this correct? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    read -p "Enter NAS username: " new_user
    read -p "Enter NAS IP address: " new_host
    
    # Update config file
    cat > nas-config.sh << EOF
#!/bin/bash
# NAS connection configuration

# Set these according to your setup
NAS_USER="${new_user}"
NAS_HOST="${new_host}"
NAS_SSH="\${NAS_USER}@\${NAS_HOST}"

# Export for use in other scripts
export NAS_SSH
export NAS_HOST
export NAS_USER
EOF
    
    echo "✅ Configuration updated"
    source ./nas-config.sh
fi

echo ""
echo "🔑 Testing SSH connection..."
ssh -o ConnectTimeout=5 ${NAS_SSH} "echo '✅ SSH connection successful!'" || {
    echo "❌ SSH connection failed"
    echo ""
    echo "To set up passwordless SSH:"
    echo "1. Generate SSH key (if not already done):"
    echo "   ssh-keygen -t rsa -b 4096"
    echo ""
    echo "2. Copy key to NAS:"
    echo "   ssh-copy-id ${NAS_SSH}"
    echo ""
    echo "3. Test connection:"
    echo "   ssh ${NAS_SSH} 'echo test'"
    exit 1
}

echo ""
echo "🐳 Checking Docker on NAS..."
ssh ${NAS_SSH} "docker --version" || {
    echo "❌ Docker not found on NAS"
    echo "Please install Docker on your Synology NAS"
    exit 1
}

echo ""
echo "✨ Setup complete! You can now run:"
echo "  ./check-nas.sh    - Check current status"
echo "  ./manage-remote.sh deploy - Deploy Nuclei scanner"