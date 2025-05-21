#!/bin/bash
# Deploy email notification system to NAS container

cd "$(dirname "$0")"
source ./nas-config.sh

echo "📧 Deploying Email Notification System"
echo "====================================="

# Update .env file on NAS
echo "1. Updating environment variables on NAS..."
scp ./.env "${NAS_USER}@${NAS_HOST}:/volume1/homes/ben/nuclei/"

# Copy email notification script
echo "2. Copying email notification script..."
cat ./scripts/email-notifications.sh | ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec -i nuclei-scanner tee /home/nuclei/scripts/email-notifications.sh > /dev/null"
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner chmod +x /home/nuclei/scripts/email-notifications.sh"

# Update the robust scan script
echo "3. Updating robust scan script with email alerts..."
cat ./scripts/scan-with-ha-robust.sh | ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec -i nuclei-scanner tee /home/nuclei/scripts/scan-with-ha-robust.sh > /dev/null"
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner chmod +x /home/nuclei/scripts/scan-with-ha-robust.sh"

# Copy updated entrypoint script
echo "4. Copying updated entrypoint script..."
scp ./entrypoint.sh "${NAS_USER}@${NAS_HOST}:/volume1/homes/ben/nuclei/"

# Test email functionality
echo "5. Testing email functionality..."
echo "Sending test email to verify configuration..."
TEST_OUTPUT=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner /home/nuclei/scripts/email-notifications.sh test" 2>&1)

if echo "$TEST_OUTPUT" | grep -q "Email sent successfully"; then
    echo "   ✅ Test email sent successfully"
else
    echo "   ❌ Test email failed:"
    echo "$TEST_OUTPUT"
fi

# Check if Python 3 is available for email sending
echo "6. Checking Python availability in container..."
PYTHON_CHECK=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner which python3" 2>/dev/null)

if [ -n "$PYTHON_CHECK" ]; then
    echo "   ✅ Python 3 is available at: $PYTHON_CHECK"
else
    echo "   ❌ Python 3 not found - installing..."
    ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner apk add --no-cache python3" 2>/dev/null || echo "Failed to install Python 3"
fi

# Restart container to apply all changes
echo "7. Restarting container to apply email system changes..."
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker restart nuclei-scanner"

# Wait for restart
echo "8. Waiting for container to restart..."
sleep 15

# Verify container is running with new configuration
CONTAINER_STATUS=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker ps --filter name=nuclei-scanner --format '{{.Status}}'" 2>/dev/null)

if [ -n "$CONTAINER_STATUS" ]; then
    echo "   ✅ Container restarted successfully: $CONTAINER_STATUS"
    
    # Check if email scheduling is working
    echo ""
    echo "9. Verifying email scheduling setup..."
    sleep 5
    
    # Check recent container logs for email setup messages
    LOGS_CHECK=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker logs nuclei-scanner --tail 10" 2>/dev/null | grep -i email)
    
    if [ -n "$LOGS_CHECK" ]; then
        echo "   ✅ Email system setup confirmed:"
        echo "$LOGS_CHECK"
    else
        echo "   ⚠️  Email system setup not confirmed in logs"
    fi
    
else
    echo "   ❌ Container failed to restart"
fi

echo ""
echo "====================================="
echo "Email system deployment complete!"
echo ""
echo "Email Features Configured:"
echo "✅ Weekly summary emails (Sundays at 5:00 AM)"
echo "✅ Critical vulnerability alerts (immediate)"
echo "✅ HTML-formatted email reports"
echo "✅ SMTP configuration via Gmail"
echo ""
echo "Email recipient: ben@tealmaker.com"
echo ""
echo "To manually test the email system:"
echo "ssh ${NAS_USER}@${NAS_HOST} '/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner /home/nuclei/scripts/email-notifications.sh test'"
echo ""
echo "To send a manual weekly summary:"
echo "ssh ${NAS_USER}@${NAS_HOST} '/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner /home/nuclei/scripts/email-notifications.sh weekly-summary'"