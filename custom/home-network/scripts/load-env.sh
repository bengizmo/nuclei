#!/bin/sh
# Load environment variables from .env file
# This script ensures all email configuration variables are properly loaded

# Logging function
log_env() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> /home/nuclei/logs/env-loading.log
}

log_env "Loading environment variables"

# First check for standard environment variables
if [ -n "$SMTP_USERNAME" ] && [ -n "$SMTP_PASSWORD" ]; then
    log_env "Email credentials already set in environment"
else
    log_env "Checking for .env file"
    
    # Try loading from .env file
    if [ -f "/home/nuclei/.env" ]; then
        log_env "Loading from /home/nuclei/.env"
        # Export all variables from .env file
        export $(grep -v '^#' /home/nuclei/.env | xargs)
    elif [ -f "/home/nuclei/config/.env" ]; then
        log_env "Loading from /home/nuclei/config/.env"
        export $(grep -v '^#' /home/nuclei/config/.env | xargs)
    else
        log_env "WARNING: No .env file found"
    fi
fi

# Check if email variables are set after loading
if [ -n "$SMTP_USERNAME" ] && [ -n "$SMTP_PASSWORD" ] && [ -n "$EMAIL_RECIPIENT" ]; then
    log_env "Email configuration loaded successfully"
else
    log_env "WARNING: Email configuration incomplete. Check environment variables or .env file."
fi