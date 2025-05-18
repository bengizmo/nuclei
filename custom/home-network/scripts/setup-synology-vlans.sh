#!/bin/bash
# Script to configure VLAN interfaces on Synology NAS

echo "Setting up VLAN interfaces on Synology NAS..."

# VLANs to configure
# VLAN 1 (Default): Already on main interface
# VLAN 2 (IOT): 192.168.14.0/24
# VLAN 3 (Guest): 192.168.5.0/24  
# VLAN 4 (Clients): 192.168.6.0/24

# First, enable VLAN tagging in Synology DSM:
# Control Panel > Network > Network Interface > Edit > Enable VLAN > Apply

# Create VLAN interfaces via SSH
ssh nas << 'EOF'
# Create VLAN interfaces
sudo ip link add link eth0 name eth0.2 type vlan id 2
sudo ip link add link eth0 name eth0.3 type vlan id 3
sudo ip link add link eth0 name eth0.4 type vlan id 4

# Bring interfaces up
sudo ip link set eth0.2 up
sudo ip link set eth0.3 up
sudo ip link set eth0.4 up

# Optional: Assign IPs to the VLAN interfaces (for NAS access)
# sudo ip addr add 192.168.14.163/24 dev eth0.2
# sudo ip addr add 192.168.5.163/24 dev eth0.3
# sudo ip addr add 192.168.6.163/24 dev eth0.4

# Make changes persistent (Synology specific)
echo "#!/bin/sh" > /usr/local/etc/rc.d/vlans.sh
echo "ip link add link eth0 name eth0.2 type vlan id 2" >> /usr/local/etc/rc.d/vlans.sh
echo "ip link add link eth0 name eth0.3 type vlan id 3" >> /usr/local/etc/rc.d/vlans.sh
echo "ip link add link eth0 name eth0.4 type vlan id 4" >> /usr/local/etc/rc.d/vlans.sh
echo "ip link set eth0.2 up" >> /usr/local/etc/rc.d/vlans.sh
echo "ip link set eth0.3 up" >> /usr/local/etc/rc.d/vlans.sh
echo "ip link set eth0.4 up" >> /usr/local/etc/rc.d/vlans.sh
chmod +x /usr/local/etc/rc.d/vlans.sh

echo "VLAN interfaces created successfully!"
EOF