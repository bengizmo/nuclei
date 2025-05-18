#!/bin/bash
# Correct VLAN setup for Synology NAS
# DO NOT tag VLAN 1 - it should remain as the native/untagged VLAN

echo "Setting up VLAN interfaces on Synology NAS (correct method)..."

# In DSM Control Panel > Network > Network Interface:
# 1. Keep the main interface (eth0) as is - NO VLAN tagging
# 2. Click "Create" > "Create VLAN" for each additional VLAN

# VLANs to configure:
# VLAN 1 (Default): Leave as untagged on main interface
# VLAN 2 (IOT): Create tagged interface
# VLAN 3 (Guest): Create tagged interface  
# VLAN 4 (Clients): Create tagged interface

cat << 'EOF'
Manual steps in Synology DSM:

1. Control Panel > Network > Network Interface
2. DO NOT enable VLAN on the main interface
3. Click "Create" > "Create VLAN" 
4. Add VLANs:
   - VLAN ID: 2, Interface: eth0 (for IOT)
   - VLAN ID: 3, Interface: eth0 (for Guest)
   - VLAN ID: 4, Interface: eth0 (for Clients)

The main interface will handle VLAN 1 (untagged) traffic
The VLAN interfaces will handle tagged traffic for other VLANs
EOF

# Alternative: Create via SSH if DSM supports it
ssh nas << 'EOF'
# Check if VLAN module is loaded
lsmod | grep 8021q || sudo modprobe 8021q

# Create VLAN interfaces (NOT VLAN 1!)
sudo ip link add link eth0 name eth0.2 type vlan id 2
sudo ip link add link eth0 name eth0.3 type vlan id 3
sudo ip link add link eth0 name eth0.4 type vlan id 4

# Bring interfaces up
sudo ip link set eth0.2 up
sudo ip link set eth0.3 up
sudo ip link set eth0.4 up

# Show interfaces
ip addr show

echo "VLAN interfaces created (VLAN 1 remains untagged on eth0)"
EOF