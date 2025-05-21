#!/bin/bash
# Simplest possible email system fix

# Load NAS configuration
cd "$(dirname "$0")"
source ./nas-config.sh

echo "📧 Simplest Email System Fix"
echo "=========================="

# Simple test
echo "Testing send-email.py script..."
TEST_OUTPUT=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner python3 /home/nuclei/scripts/send-email.py" 2>&1)
echo "$TEST_OUTPUT"

if echo "$TEST_OUTPUT" | grep -q "successfully"; then
    echo "   ✅ Email system is working!"
    echo ""
    echo "=========================="
    echo "🎉 Email notification system is operational!"
    echo ""
    echo "Features enabled:"
    echo "✅ Email functionality (tested and verified)"
    echo ""
    echo "To test the email system:"
    echo "ssh ${NAS_USER}@${NAS_HOST} '/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner python3 /home/nuclei/scripts/send-email.py'"
    echo ""
    echo "You have successfully implemented the email notification system!"
else
    echo "   ❌ Email system has issues"
    echo "   Error details:"
    echo "$TEST_OUTPUT"
fi