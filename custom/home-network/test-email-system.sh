#!/bin/bash
# Test the email notification system

cd "$(dirname "$0")"
source ./nas-config.sh

echo "📧 Testing Email Notification System"
echo "==================================="

# Check if email script exists
echo "1. Checking if email script exists in container..."
SCRIPT_EXISTS=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner test -f /home/nuclei/scripts/email-notifications.sh && echo 'exists' || echo 'missing'" 2>/dev/null)

if [ "$SCRIPT_EXISTS" = "exists" ]; then
    echo "   ✅ Email script exists"
else
    echo "   ❌ Email script missing - run deploy-email-system.sh first"
    exit 1
fi

# Test email functionality
echo ""
echo "2. Testing email functionality..."
echo "Sending test email..."

TEST_RESULT=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner /home/nuclei/scripts/email-notifications.sh test" 2>&1)

echo "Test result:"
echo "$TEST_RESULT"

if echo "$TEST_RESULT" | grep -q "Email sent successfully"; then
    echo "   ✅ Test email sent successfully!"
else
    echo "   ❌ Test email failed"
    echo "   Checking detailed error..."
    
    # Check for common issues
    if echo "$TEST_RESULT" | grep -q "python3"; then
        echo "   Issue: Python 3 not available"
    fi
    
    if echo "$TEST_RESULT" | grep -q "Authentication"; then
        echo "   Issue: SMTP authentication failed - check credentials"
    fi
    
    if echo "$TEST_RESULT" | grep -q "Connection"; then
        echo "   Issue: Cannot connect to SMTP server"
    fi
fi

# Check environment variables
echo ""
echo "3. Checking email environment variables..."
ENV_CHECK=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner env | grep -E 'SMTP|EMAIL'" 2>/dev/null)

if [ -n "$ENV_CHECK" ]; then
    echo "   Email environment variables found:"
    echo "$ENV_CHECK" | sed 's/SMTP_PASSWORD=.*/SMTP_PASSWORD=***HIDDEN***/'
else
    echo "   ❌ No email environment variables found"
    echo "   Make sure .env file is properly loaded"
fi

# Test weekly summary generation (without sending)
echo ""
echo "4. Testing weekly summary generation..."
SUMMARY_TEST=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner timeout 30 /home/nuclei/scripts/email-notifications.sh weekly-summary" 2>&1)

if echo "$SUMMARY_TEST" | grep -q "Email sent successfully"; then
    echo "   ✅ Weekly summary generated and sent successfully"
elif echo "$SUMMARY_TEST" | grep -q "weekly summary"; then
    echo "   ✅ Weekly summary generated (check email)"
else
    echo "   ⚠️  Weekly summary test result:"
    echo "$SUMMARY_TEST"
fi

# Check email logs
echo ""
echo "5. Checking email logs..."
EMAIL_LOGS=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner tail -10 /home/nuclei/logs/email-notifications.log" 2>/dev/null)

if [ -n "$EMAIL_LOGS" ]; then
    echo "   Recent email activity:"
    echo "$EMAIL_LOGS"
else
    echo "   No email logs found yet"
fi

echo ""
echo "==================================="
echo "Email testing complete!"
echo ""
echo "If the test email was successful, you should receive:"
echo "📧 A test email at ben@tealmaker.com"
echo ""
echo "Email system features:"
echo "• Weekly summaries: Sundays at 5:00 AM"
echo "• Critical alerts: Immediate after each scan"
echo "• HTML formatting for better readability"