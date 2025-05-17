#!/bin/bash
# Test SSH connection to NAS

source ./nas-config.sh

echo "🔗 Testing SSH connection to NAS..."
echo "   Connecting to: ${NAS_SSH}"
echo ""

# Test basic connection
ssh -o ConnectTimeout=5 -o PasswordAuthentication=no ${NAS_SSH} "echo 'SSH connection successful!'" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ SSH connection working!"
    echo ""
    echo "Testing Docker access..."
    ssh ${NAS_SSH} "docker --version" && echo "✅ Docker is available"
else
    echo "❌ SSH connection failed"
    echo ""
    echo "If you're trying to use your 'ssh-nas' alias, you can:"
    echo "1. Run this command directly:"
    echo "   ssh-nas 'echo test'"
    echo ""
    echo "2. Or update nas-config.sh with the correct username"
    echo ""
    echo "3. Or create an SSH config file (~/.ssh/config):"
    echo "Host nas"
    echo "    HostName 192.168.10.163"
    echo "    User your_username"
    echo "    IdentityFile ~/.ssh/id_rsa"
fi