# Email Notification System Setup

This document describes how to set up and configure the email notification system for Nuclei scanner.

## Security Notice

**IMPORTANT**: This email notification system requires SMTP credentials to send emails. These credentials are sensitive and should **never** be stored in the code or committed to the repository. Instead, they should be securely provided through environment variables.

## Configuration Options

There are two main methods to provide email credentials to the container:

### Method 1: Docker Environment Variables (Recommended)

Create a `.env` file in the same directory as your `docker-compose.yml`:

```bash
# Create .env file (do not commit this file to git!)
cat > .env << EOF
# Home Assistant integration
HOME_ASSISTANT_API_TOKEN=your_ha_token_here

# Email configuration
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-gmail@gmail.com
SMTP_PASSWORD=your-app-password
EMAIL_RECIPIENT=recipient@example.com
EMAIL_FROM=your-gmail@gmail.com
EOF

# Set secure permissions
chmod 600 .env
```

This `.env` file will be automatically loaded by Docker Compose when you start the container. The docker-compose.yml is already configured to pass these variables to the container.

### Method 2: Environment File Inside Container

If you prefer to manage the environment variables directly inside the container:

1. Create a `.env` file in the container:

```bash
ssh user@nas_host '/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner sh -c "cat > /home/nuclei/.env << EOF
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-gmail@gmail.com
SMTP_PASSWORD=your-app-password
EMAIL_RECIPIENT=recipient@example.com
EMAIL_FROM=your-gmail@gmail.com
EOF"'
```

2. Ensure the file has restricted permissions:

```bash
ssh user@nas_host '/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner chmod 600 /home/nuclei/.env'
```

## Gmail Configuration

If you're using Gmail, you'll need to:

1. Use an App Password instead of your regular Gmail password
   - Go to your Google Account → Security → App passwords
   - Create a new app password for "Mail" and "Other (Custom name)" - name it "Nuclei Scanner"
   - Copy the generated password (it will look like: xxxx xxxx xxxx xxxx)

2. Use these settings:
   - SMTP_SERVER: smtp.gmail.com
   - SMTP_PORT: 587
   - SMTP_USERNAME: your.gmail.address@gmail.com
   - SMTP_PASSWORD: your-app-password (spaces are okay)

## Deployment and Testing

After setting up your environment variables, deploy and test the system:

1. Start or restart the container to apply the changes:

```bash
# If using docker-compose with .env file:
docker-compose up -d

# If using internal .env file:
docker restart nuclei-scanner
```

2. Test the email system:

```bash
ssh user@nas_host '/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner /home/nuclei/scripts/email-notifications.sh test'
```

If successful, you should see:

```
Sending email: Nuclei Scanner Email Test
Email sent successfully
```

## Features

The email notification system provides:

1. **Weekly Summary Emails**: Sent every Sunday at 5:00 AM
2. **Critical Vulnerability Alerts**: Sent immediately when critical vulnerabilities are detected
3. **HTML-formatted Reports**: Detailed formatting for better readability
4. **Test Email Functionality**: For verifying the system is working correctly

## Troubleshooting

If you encounter issues with the email system:

1. Check if environment variables are correctly set:
   ```bash
   ssh user@nas_host '/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner env | grep SMTP'
   ```

2. Verify permissions on the .env file (if using method 2):
   ```bash
   ssh user@nas_host '/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner ls -la /home/nuclei/.env'
   ```

3. Check email logs:
   ```bash
   ssh user@nas_host '/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner cat /home/nuclei/logs/email-notifications.log'
   ```

4. Test environment variable loading:
   ```bash
   ssh user@nas_host '/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner sh /home/nuclei/scripts/load-env.sh'
   ssh user@nas_host '/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner cat /home/nuclei/logs/env-loading.log'
   ```

## Security Best Practices

1. **Never commit your .env file to version control**
2. **Limit access to the environment file** with restrictive permissions
3. **Regularly rotate your application passwords**
4. **Use app-specific passwords** rather than your main account password
5. **Monitor email logs** for any unauthorized access attempts