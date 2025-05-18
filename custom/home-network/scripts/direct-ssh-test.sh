#!/bin/sh
# Direct SSH connectivity test

echo "Direct SSH test for Think Tank (192.168.10.249)..."
TARGET="192.168.10.249"

echo "1. Testing from NAS host network..."
# This runs on the host, not in the container
ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes $TARGET exit 2>&1 || echo "SSH connection attempt completed"

echo ""
echo "2. Getting SSH banner..."
echo "QUIT" | nc -w 5 $TARGET 22 2>&1 || echo "Banner grab failed"

echo ""
echo "3. Port availability test..."
nc -zv -w 5 $TARGET 22 2>&1 || echo "Port test failed"

echo ""
echo "4. Direct nuclei SSH template..."
/home/nuclei/nuclei-templates/network/ssh-auth.yaml
nuclei -u $TARGET -p ssh://22 -t /root/nuclei-templates/network/ssh-auth.yaml -j

echo ""
echo "5. Testing with explicit protocol..."
nuclei -u ssh://$TARGET -t /root/nuclei-templates/network/enumeration/ssh-auth-methods.yaml -j