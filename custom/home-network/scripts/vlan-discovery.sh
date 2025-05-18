#!/bin/sh
# Quick VLAN host discovery script

echo "VLAN Host Discovery"
echo "=================="

# Default VLAN
echo ""
echo "Default VLAN (192.168.10.0/24):"
DEFAULT_COUNT=$(nmap -sn 192.168.10.0/24 | grep "Host is up" | wc -l)
echo "Found $DEFAULT_COUNT hosts"

# IOT VLAN
echo ""
echo "IOT VLAN (192.168.14.0/24):"
if ip link show eth0.2 >/dev/null 2>&1; then
    IOT_COUNT=$(nmap -sn 192.168.14.0/24 | grep "Host is up" | wc -l)
    echo "Found $IOT_COUNT hosts"
else
    echo "VLAN interface not available"
fi

# Guest VLAN
echo ""
echo "Guest VLAN (192.168.5.0/24):"
if ip link show eth0.3 >/dev/null 2>&1; then
    GUEST_COUNT=$(nmap -sn 192.168.5.0/24 | grep "Host is up" | wc -l)
    echo "Found $GUEST_COUNT hosts"
else
    echo "VLAN interface not available"
fi

# Clients VLAN
echo ""
echo "Clients VLAN (192.168.6.0/24):"
if ip link show eth0.4 >/dev/null 2>&1; then
    CLIENTS_COUNT=$(nmap -sn 192.168.6.0/24 | grep "Host is up" | wc -l)
    echo "Found $CLIENTS_COUNT hosts"
else
    echo "VLAN interface not available"
fi

# Total
TOTAL=$((DEFAULT_COUNT + IOT_COUNT + GUEST_COUNT + CLIENTS_COUNT))
echo ""
echo "==================="
echo "Total hosts: $TOTAL"
echo ""

# Show some sample hosts
echo "Sample hosts found:"
echo ""
echo "Default VLAN:"
nmap -sn 192.168.10.0/24 | grep "report for" | head -5

if [ "$IOT_COUNT" -gt 0 ]; then
    echo ""
    echo "IOT VLAN:"
    nmap -sn 192.168.14.0/24 | grep "report for" | head -5
fi

if [ "$GUEST_COUNT" -gt 0 ]; then
    echo ""
    echo "Guest VLAN:"
    nmap -sn 192.168.5.0/24 | grep "report for" | head -5
fi

if [ "$CLIENTS_COUNT" -gt 0 ]; then
    echo ""
    echo "Clients VLAN:"
    nmap -sn 192.168.6.0/24 | grep "report for" | head -5
fi