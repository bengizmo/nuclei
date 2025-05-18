#!/bin/bash
# Create VLAN interfaces manually on Synology NAS

echo "Creating VLAN interfaces on Synology NAS..."

# Check if running with appropriate privileges
if [ "$EUID" -ne 0 ]; then 
   echo "This script needs to run with sudo privileges on the NAS"
   echo "Run: sudo -i to become root first"
fi

# Load 8021q module for VLAN support
modprobe 8021q

# Create VLAN interfaces
echo "Creating VLAN 2 (IOT)..."
ip link add link eth0 name eth0.2 type vlan id 2
ip link set eth0.2 up

echo "Creating VLAN 3 (Guest)..."
ip link add link eth0 name eth0.3 type vlan id 3
ip link set eth0.3 up

echo "Creating VLAN 4 (Clients)..."
ip link add link eth0 name eth0.4 type vlan id 4
ip link set eth0.4 up

# Show created interfaces
echo ""
echo "Created VLAN interfaces:"
ip link show | grep -E "eth0\.[234]"

# Create startup script to make VLANs persistent
cat > /etc/init/vlans.conf << 'EOF'
description "Configure VLANs at startup"

start on started networking

script
    # Load VLAN module
    modprobe 8021q
    
    # Create VLAN interfaces
    ip link add link eth0 name eth0.2 type vlan id 2
    ip link add link eth0 name eth0.3 type vlan id 3
    ip link add link eth0 name eth0.4 type vlan id 4
    
    # Bring interfaces up
    ip link set eth0.2 up
    ip link set eth0.3 up
    ip link set eth0.4 up
end script
EOF

echo ""
echo "VLAN startup script created at /etc/init/vlans.conf"
echo "VLANs will be recreated on reboot"

# Alternative for systemd-based Synology DSM
if [ -d /etc/systemd/system ]; then
    cat > /etc/systemd/system/vlans.service << 'EOF'
[Unit]
Description=Configure VLANs
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-vlans.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Create the setup script
    cat > /usr/local/bin/setup-vlans.sh << 'EOF'
#!/bin/bash
modprobe 8021q
ip link add link eth0 name eth0.2 type vlan id 2
ip link add link eth0 name eth0.3 type vlan id 3
ip link add link eth0 name eth0.4 type vlan id 4
ip link set eth0.2 up
ip link set eth0.3 up
ip link set eth0.4 up
EOF

    chmod +x /usr/local/bin/setup-vlans.sh
    systemctl enable vlans.service
    echo "SystemD service created and enabled"
fi

echo ""
echo "VLAN configuration complete!"
echo "Your NAS can now access all VLANs through eth0"