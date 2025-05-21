#!/bin/bash
# Manual deployment of email system with better error handling

cd "$(dirname "$0")"
source ./nas-config.sh

echo "📧 Manual Email System Deployment"
echo "================================="

# Step 1: Copy email script using a different method
echo "1. Manually copying email script..."
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner rm -f /home/nuclei/scripts/email-notifications.sh"

# Create the script inside the container directly
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner sh -c 'cat > /home/nuclei/scripts/email-notifications.sh' < ./scripts/email-notifications.sh"

# Make it executable
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner chmod +x /home/nuclei/scripts/email-notifications.sh"

# Verify it was created
SCRIPT_SIZE=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner stat -c%s /home/nuclei/scripts/email-notifications.sh" 2>/dev/null)
echo "   Script size: $SCRIPT_SIZE bytes"

# Step 2: Copy environment variables directly into container
echo "2. Setting environment variables in container..."
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner sh -c 'cat > /home/nuclei/.env << \"EOF\"
HOME_ASSISTANT_API_TOKEN=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI3ZDU0NWNmMDBhYzQ0NGJkYjY2MjcwNTNjMjA2MGViMyIsImlhdCI6MTc0NzUxNDQ3NiwiZXhwIjoyMDYyODc0NDc2fQ.ZrYGer1Q4qfZt2j5PIV0kwOOeZEkFs-sgiLtsBfpTOM
PDCP_API_KEY=b1e5b881-f0b7-4cf8-95b3-05de6b978052
OLLAMA_API=http://192.168.10.249:11434/v1
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USE_TLS=True
SMTP_USERNAME=ben@tealmaker.com
SMTP_PASSWORD=vxcc lyyo gtsn nibc
EMAIL_RECIPIENT=ben@tealmaker.com
EMAIL_FROM=ben@tealmaker.com
EOF'"

# Step 3: Test the email system
echo "3. Testing email functionality..."
EMAIL_TEST_RESULT=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner sh -c 'source /home/nuclei/.env && /home/nuclei/scripts/email-notifications.sh test'" 2>&1)

echo "Test result:"
echo "$EMAIL_TEST_RESULT"

if echo "$EMAIL_TEST_RESULT" | grep -q "Email sent successfully"; then
    echo "   ✅ Email test successful!"
else
    echo "   Checking environment variables..."
    ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner sh -c 'source /home/nuclei/.env && env | grep SMTP'"
fi

# Step 4: Test weekly summary
echo "4. Testing weekly summary generation..."
SUMMARY_TEST=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner sh -c 'source /home/nuclei/.env && timeout 60 /home/nuclei/scripts/email-notifications.sh weekly-summary'" 2>&1)

echo "Summary test result:"
echo "$SUMMARY_TEST"

echo ""
echo "================================="
echo "Manual deployment complete!"
echo ""
echo "If successful, you should receive test emails shortly."