#!/bin/sh
# Deploy enhanced network discovery and profiling system

echo "Deploying enhanced network discovery system..."

# Configuration
NAS_IP="192.168.10.163"
NAS_USER="nuclei"
DEPLOY_PATH="/volume1/docker/nuclei"

# Check if PDCP API key is set
if [ -z "$PDCP_API_KEY" ]; then
    echo "Warning: PDCP_API_KEY not set. AI-powered template generation will be disabled."
    echo "To enable, set PDCP_API_KEY environment variable or add to .env file"
fi

# Create deployment package
echo "Creating deployment package..."
TEMP_DIR="/tmp/nuclei-deploy-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$TEMP_DIR/scripts"

# Copy enhanced scripts
cp scripts/network-discovery.sh "$TEMP_DIR/scripts/"
cp scripts/profile-new-host-enhanced.sh "$TEMP_DIR/scripts/"
cp scripts/generate-ai-summary.sh "$TEMP_DIR/scripts/"
cp scripts/generate-device-summary.sh "$TEMP_DIR/scripts/"

# Create environment file if needed
if [ -n "$PDCP_API_KEY" ]; then
    echo "PDCP_API_KEY=$PDCP_API_KEY" >> "$TEMP_DIR/.env"
fi
if [ -n "$HOME_ASSISTANT_API_TOKEN" ]; then
    echo "HOME_ASSISTANT_API_TOKEN=$HOME_ASSISTANT_API_TOKEN" >> "$TEMP_DIR/.env"
fi

# Create backup script for existing setup
cat > "$TEMP_DIR/backup.sh" << 'EOF'
#!/bin/sh
# Backup existing scripts before deployment
BACKUP_DIR="/home/nuclei/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp /home/nuclei/scripts/* "$BACKUP_DIR/" 2>/dev/null
echo "Backup created at: $BACKUP_DIR"
EOF

# Create installation script
cat > "$TEMP_DIR/install.sh" << 'EOF'
#!/bin/sh
# Install enhanced scripts
echo "Installing enhanced network discovery system..."

# Backup existing scripts
/home/nuclei/backup.sh

# Install new scripts
cp /home/nuclei/deploy/scripts/* /home/nuclei/scripts/
chmod +x /home/nuclei/scripts/*.sh

# Update environment
if [ -f /home/nuclei/deploy/.env ]; then
    cp /home/nuclei/deploy/.env /home/nuclei/.env
    echo "Environment variables updated"
fi

# Create necessary directories
mkdir -p /home/nuclei/discovery/profiles
mkdir -p /home/nuclei/logs
mkdir -p /home/nuclei/results/auto-discovery

# Initialize discovery database if not exists
if [ ! -f /home/nuclei/discovery/discovery.db ]; then
    echo "# Network Discovery Database" > /home/nuclei/discovery/discovery.db
    echo "# Format: IP|MAC|FirstSeen|LastSeen|Hostname|OS|Services|ProfileStatus" >> /home/nuclei/discovery/discovery.db
fi

# Update nuclei templates
echo "Updating nuclei templates..."
nuclei -ut

# Restart discovery service
pkill -f "network-discovery.sh" 2>/dev/null
nohup /home/nuclei/scripts/network-discovery.sh > /home/nuclei/logs/discovery.log 2>&1 &

echo "Enhanced network discovery system installed successfully!"
echo ""
echo "Features enabled:"
echo "- Comprehensive NMAP profiling for new devices"
echo "- ProjectDiscovery AI template generation (if API key provided)"
echo "- Concise AI summaries (under 200 chars for secure networks)"
echo "- Automatic scanning of newly discovered devices"
echo "- Notifications only for security vulnerabilities"
echo ""
echo "Check logs at: /home/nuclei/logs/"
EOF

chmod +x "$TEMP_DIR/backup.sh"
chmod +x "$TEMP_DIR/install.sh"

# Create README
cat > "$TEMP_DIR/README.md" << 'EOF'
# Enhanced Nuclei Network Discovery

This deployment includes the following enhancements:

## Features
1. **No notifications for new device discovery** - Silent discovery
2. **Automatic scanning of new devices** - Immediate profiling and vulnerability assessment
3. **Concise AI summaries** - Under 200 characters when no issues found
4. **ProjectDiscovery API integration** - AI-powered template generation for better coverage

## Configuration
- Set `PDCP_API_KEY` for AI template generation
- Set `HOME_ASSISTANT_API_TOKEN` for Home Assistant integration

## Directory Structure
```
/home/nuclei/
├── scripts/              # All executable scripts
├── discovery/           # Discovery database and profiles
├── logs/               # Application logs
├── results/            # Scan results
└── nuclei-templates/   # Nuclei templates
```

## Monitoring
- Check discovery: `tail -f /home/nuclei/logs/discovery.log`
- Check profiling: `tail -f /home/nuclei/logs/profiling.log`
- View database: `cat /home/nuclei/discovery/discovery.db`
EOF

# Deploy to NAS
echo "Deploying to NAS at $NAS_IP..."
ssh "$NAS_USER@$NAS_IP" "mkdir -p $DEPLOY_PATH/deploy"
scp -r "$TEMP_DIR"/* "$NAS_USER@$NAS_IP:$DEPLOY_PATH/deploy/"

# Execute installation on NAS
echo "Installing on NAS..."
ssh "$NAS_USER@$NAS_IP" "cd $DEPLOY_PATH/deploy && ./install.sh"

# Cleanup
rm -rf "$TEMP_DIR"

echo "Deployment complete!"
echo ""
echo "To monitor the system:"
echo "  ssh $NAS_USER@$NAS_IP"
echo "  tail -f $DEPLOY_PATH/logs/discovery.log"
echo ""
echo "To check discovered devices:"
echo "  ssh $NAS_USER@$NAS_IP"
echo "  cat $DEPLOY_PATH/discovery/discovery.db | column -t -s '|'"