#!/bin/sh
# Proper SSH scan for Think Tank

echo "SSH Security Scan for Think Tank..."
TARGET="192.168.10.249"

echo "1. SSH Banner:"
echo "QUIT" | nc -w 5 $TARGET 22 | head -1

echo ""
echo "2. Running SSH-specific nuclei templates..."
# Use correct URL format for SSH
nuclei -u $TARGET -t network/enumeration/ssh-auth-methods.yaml -j -o ssh-auth.json
nuclei -u $TARGET -t network/enumeration/ssh-server-enumeration.yaml -j -o ssh-server.json
nuclei -u $TARGET -t network/openssh-detect.yaml -j -o ssh-detect.json

echo ""
echo "3. Common SSH vulnerabilities..."
nuclei -u $TARGET -t cves/ -tags ssh -j -o ssh-cves.json

echo ""
echo "4. SSH security misconfigurations..."
nuclei -u $TARGET -t misconfiguration/ -tags ssh -j -o ssh-misconfig.json

echo ""
echo "5. Weak algorithms check..."
# Test for weak SSH algorithms
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
    -o KexAlgorithms=diffie-hellman-group1-sha1 \
    $TARGET exit 2>&1 | grep -q "no matching" && echo "✓ Weak kex algorithms disabled" || echo "⚠ Weak kex algorithms might be enabled"

echo ""
echo "Results saved to current directory"
ls -la *ssh*.json 2>/dev/null || echo "No results files found"