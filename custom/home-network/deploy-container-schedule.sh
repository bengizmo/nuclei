#!/bin/bash
# Deploy container scheduling fixes and secure email configuration to the NAS

cd "$(dirname "$0")"
source ./nas-config.sh

echo "🕒 Deploying Container Scheduling & Email Configuration"
echo "======================================================"

# Verify connection
echo "1. Verifying NAS connection..."
if ${NAS_SSH} "echo Connected successfully"; then
    echo "✅ Connected to NAS at ${NAS_HOST}"
else
    echo "❌ Failed to connect to NAS"
    exit 1
fi

# Deploy entrypoint and docker-compose
echo ""
echo "2. Deploying updated scripts..."
${NAS_SSH} "cat > /volume2/docker/nuclei/entrypoint.sh" < entrypoint.sh
${NAS_SSH} "cat > /volume2/docker/nuclei/docker-compose.yml" < docker-compose.yml
${NAS_SSH} "chmod +x /volume2/docker/nuclei/entrypoint.sh"

# Ensure robust script is in place
echo ""
echo "3. Deploying robust scan script..."
${NAS_SSH} "cat > /volume2/docker/nuclei/scripts-new/scan-with-ha-robust.sh" < scripts/scan-with-ha-robust.sh
${NAS_SSH} "chmod +x /volume2/docker/nuclei/scripts-new/scan-with-ha-robust.sh"
${NAS_SSH} "${DOCKER_BIN} cp /volume2/docker/nuclei/scripts-new/scan-with-ha-robust.sh nuclei-scanner:/home/nuclei/scripts/"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner chmod +x /home/nuclei/scripts/scan-with-ha-robust.sh"

# Deploy email configuration scripts
echo ""
echo "4. Setting up email notification system..."
# Create email environment loader
${NAS_SSH} "cat > /volume2/docker/nuclei/scripts-new/load-env.sh" < scripts/load-env.sh
${NAS_SSH} "chmod +x /volume2/docker/nuclei/scripts-new/load-env.sh"
${NAS_SSH} "${DOCKER_BIN} cp /volume2/docker/nuclei/scripts-new/load-env.sh nuclei-scanner:/home/nuclei/scripts/"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner chmod +x /home/nuclei/scripts/load-env.sh"

# Deploy email notification script
${NAS_SSH} "cat > /volume2/docker/nuclei/scripts-new/email-notifications.sh" < scripts/email-notifications.sh
${NAS_SSH} "chmod +x /volume2/docker/nuclei/scripts-new/email-notifications.sh"
${NAS_SSH} "${DOCKER_BIN} cp /volume2/docker/nuclei/scripts-new/email-notifications.sh nuclei-scanner:/home/nuclei/scripts/"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner chmod +x /home/nuclei/scripts/email-notifications.sh"

# Ask for email configuration if needed
echo ""
echo "5. Configure email credentials? (y/n)"
read -r EMAIL_SETUP
if [[ "$EMAIL_SETUP" =~ ^[Yy]$ ]]; then
    echo "Setting up secure email configuration"
    echo "------------------------------------"
    echo "Note: These values will be stored in a secure .env file on the NAS."
    
    # Ask for Gmail credentials
    read -p "Gmail username (email): " GMAIL_USER
    read -sp "Gmail app password: " GMAIL_PASS
    echo
    read -p "Email recipient: " EMAIL_RECIPIENT
    read -p "Email from (default: $GMAIL_USER): " EMAIL_FROM
    EMAIL_FROM=${EMAIL_FROM:-$GMAIL_USER}
    
    # Create secure .env file on NAS
    echo "Creating secure .env file on NAS..."
    ${NAS_SSH} "cat > /volume2/docker/nuclei/.env << EOF
# Email configuration
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=${GMAIL_USER}
SMTP_PASSWORD=${GMAIL_PASS}
EMAIL_RECIPIENT=${EMAIL_RECIPIENT}
EMAIL_FROM=${EMAIL_FROM}
EOF"
    
    # Set secure permissions
    ${NAS_SSH} "chmod 600 /volume2/docker/nuclei/.env"
    
    # Copy to container
    ${NAS_SSH} "${DOCKER_BIN} cp /volume2/docker/nuclei/.env nuclei-scanner:/home/nuclei/.env"
    ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner chmod 600 /home/nuclei/.env"
    
    echo "Secure email configuration complete."
    echo "Will test email functionality after container restart."
    EMAIL_TEST=true
fi

# Restart the container to apply changes
echo ""
echo "6. Restarting container to apply changes..."
# Check if docker-compose exists
if ${NAS_SSH} "which docker-compose > /dev/null 2>&1"; then
    ${NAS_SSH} "cd /volume2/docker/nuclei && docker-compose down && docker-compose up -d"
else
    # Fallback to manual container restart
    ${NAS_SSH} "${DOCKER_BIN} stop nuclei-scanner && ${DOCKER_BIN} rm nuclei-scanner && cd /volume2/docker/nuclei && ${DOCKER_BIN} run -d --name nuclei-scanner --restart unless-stopped --network host -v /volume2/docker/nuclei/scripts:/home/nuclei/scripts -v /volume2/docker/nuclei/results:/home/nuclei/results -v /volume2/docker/nuclei/logs:/home/nuclei/logs -v /volume2/docker/nuclei/discovery:/home/nuclei/discovery -v /volume2/docker/nuclei/critical-hosts.txt:/home/nuclei/critical-hosts.txt:ro -v /volume2/docker/nuclei/entrypoint.sh:/home/nuclei/entrypoint.sh:ro -e HOME_ASSISTANT_API_TOKEN=${HA_TOKEN} -e NETWORK_DISCOVERY_ENABLED=true -e DAILY_SCAN_ENABLED=true -e RUN_SCAN_ON_STARTUP=true -e MULTIPLE_DAILY_SCANS=true --cap-add NET_ADMIN nuclei-nuclei sh /home/nuclei/entrypoint.sh"
fi

# Wait for container to initialize
echo "   Waiting for container to initialize..."
sleep 10

# Check container status
echo ""
echo "7. Checking container status..."
${NAS_SSH} "${DOCKER_BIN} ps | grep nuclei-scanner" || echo "⚠️ Container not running"

# Test email if configured
if [ "$EMAIL_TEST" = true ]; then
    echo ""
    echo "8. Testing email functionality..."
    sleep 5 # Allow container to fully initialize
    ${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/email-notifications.sh test"
    echo "If you don't receive a test email, check logs with:"
    echo "${NAS_SSH} '${DOCKER_BIN} exec nuclei-scanner cat /home/nuclei/logs/email-notifications.log'"
fi

echo ""
echo "========================================================"
echo "✅ Deployment complete!"
echo ""
echo "The container now has built-in scheduling with:"
echo "- Startup scan when container starts"
echo "- Daily scan at 3:00 AM"
echo "- Additional scan at 3:00 PM"
echo "- Automatic updates to Home Assistant"
echo "- Weekly email summaries on Sundays at 5:00 AM"
echo "- Critical vulnerability email alerts"
echo ""
echo "To check if everything is working:"
echo "- Check Home Assistant to see the entity updates"
echo "- Review container logs: ${NAS_SSH} '${DOCKER_BIN} exec nuclei-scanner cat /home/nuclei/logs/container.log'"
echo "- Check email logs: ${NAS_SSH} '${DOCKER_BIN} exec nuclei-scanner cat /home/nuclei/logs/email-notifications.log'"
echo "- You can manually trigger a scan: ${NAS_SSH} '${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-robust.sh'"
echo "- You can send a test email: ${NAS_SSH} '${DOCKER_BIN} exec nuclei-scanner /home/nuclei/scripts/email-notifications.sh test'"
echo ""
echo "No need to set up cron jobs on the NAS host - everything runs inside the container!"
echo ""
echo "Email notifications will be sent:"
echo "- Weekly summary: Every Sunday at 5:00 AM"
echo "- Critical alerts: Immediately when vulnerabilities are found"