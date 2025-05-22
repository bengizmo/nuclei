#!/usr/bin/env python3
# Email notification system for Nuclei scanner

import smtplib
import ssl
import sys
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta

# Email configuration - use environment variables for credentials
SMTP_SERVER = os.environ.get("SMTP_SERVER", "smtp.gmail.com")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USERNAME = os.environ.get("SMTP_USERNAME", "")
SMTP_PASSWORD = os.environ.get("SMTP_PASSWORD", "")
EMAIL_RECIPIENT = os.environ.get("EMAIL_RECIPIENT", "")
EMAIL_FROM = os.environ.get("EMAIL_FROM", SMTP_USERNAME)

def send_email(subject, body):
    """Send an email with the given subject and body"""
    print(f"Sending email: {subject}")
    
    # Check for credentials
    if not SMTP_USERNAME or not SMTP_PASSWORD or not EMAIL_RECIPIENT:
        print("ERROR: Email credentials not set. Please set environment variables:")
        print("SMTP_USERNAME, SMTP_PASSWORD, EMAIL_RECIPIENT")
        return False
    
    # Create message
    message = MIMEMultipart()
    message["Subject"] = subject
    message["From"] = EMAIL_FROM
    message["To"] = EMAIL_RECIPIENT

    # Add body
    message.attach(MIMEText(body, "plain"))
    
    try:
        # Connect to server
        context = ssl.create_default_context()
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls(context=context)
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.sendmail(EMAIL_FROM, EMAIL_RECIPIENT, message.as_string())
        print("Email sent successfully")
        return True
    except Exception as e:
        print(f"Error sending email: {e}")
        return False

def send_weekly_summary():
    """Send weekly summary email"""
    print("Preparing weekly summary email")
    
    # Get date range
    end_date = datetime.now()
    start_date = end_date - timedelta(days=7)
    
    # Create summary
    subject = f"Nuclei Security Scanner - Weekly Summary ({datetime.now().strftime('%Y-%m-%d')})"
    body = f"""NUCLEI SECURITY SCANNER - WEEKLY SUMMARY
========================================
Report Period: {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}
Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

This is your weekly security scan summary.
"""
    
    return send_email(subject, body)

def send_critical_alert():
    """Send critical vulnerability alert"""
    print("Sending critical vulnerability alert")
    
    # Create alert
    subject = "🚨 CRITICAL SECURITY ALERT - Vulnerabilities Found"
    body = f"""CRITICAL VULNERABILITIES DETECTED
=====================================
Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

Critical vulnerabilities have been detected in your network.
Please review your system immediately for potential security issues.
"""
    
    return send_email(subject, body)

def send_test_email():
    """Send a test email"""
    print("Sending test email")
    subject = "Nuclei Scanner Email Test"
    body = f"""This is a test email from the Nuclei scanner email notification system. 
    
If you receive this, the email functionality is working correctly.

This email was sent on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""
    
    return send_email(subject, body)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 email_system.py {weekly-summary|critical-alert|test}")
        sys.exit(1)
    
    command = sys.argv[1]
    if command == "weekly-summary":
        send_weekly_summary()
    elif command == "critical-alert":
        send_critical_alert()
    elif command == "test":
        send_test_email()
    else:
        print(f"Unknown command: {command}")
        print("Usage: python3 email_system.py {weekly-summary|critical-alert|test}")
        sys.exit(1)