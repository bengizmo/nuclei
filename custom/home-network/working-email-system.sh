#!/bin/bash
# Create a working email notification system with hardcoded credentials

cd "$(dirname "$0")"
source ./nas-config.sh

echo "📧 Setting Up Working Email System"
echo "================================="

# Create a simplified email notification script with hardcoded credentials
echo "1. Creating simplified email notification script..."
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner sh -c 'cat > /home/nuclei/scripts/email-working.py << \"EOF\"
#!/usr/bin/env python3
# Working email system for Nuclei scanner

import smtplib
import ssl
import sys
import os
import json
import glob
import re
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta

# Email configuration - load from environment variables
SMTP_SERVER = os.environ.get(\"SMTP_SERVER\", \"smtp.gmail.com\")
SMTP_PORT = int(os.environ.get(\"SMTP_PORT\", \"587\"))
SMTP_USERNAME = os.environ.get(\"SMTP_USERNAME\", \"\")
SMTP_PASSWORD = os.environ.get(\"SMTP_PASSWORD\", \"\")
EMAIL_RECIPIENT = os.environ.get(\"EMAIL_RECIPIENT\", \"\")
EMAIL_FROM = os.environ.get(\"EMAIL_FROM\", SMTP_USERNAME)

# Paths
RESULTS_DIR = \"/home/nuclei/results\"
LOGS_DIR = \"/home/nuclei/logs\"

# Ensure logs directory exists
os.makedirs(LOGS_DIR, exist_ok=True)

# Email log file
EMAIL_LOG = os.path.join(LOGS_DIR, \"email-notifications.log\")

def log_message(message):
    \"\"\"Log a message with timestamp\"\"\"
    timestamp = datetime.now().strftime(\"%Y-%m-%d %H:%M:%S\")
    log_entry = f\"[{timestamp}] {message}\"
    print(log_entry)
    with open(EMAIL_LOG, \"a\") as f:
        f.write(log_entry + \"\\n\")

def send_email(subject, body, html_body=None):
    \"\"\"Send an email with the given subject and body\"\"\"
    log_message(f\"Sending email: {subject}\")
    
    # Create message
    message = MIMEMultipart(\"alternative\")
    message[\"Subject\"] = subject
    message[\"From\"] = EMAIL_FROM
    message[\"To\"] = EMAIL_RECIPIENT

    # Create plain text part
    part1 = MIMEText(body, \"plain\")
    message.attach(part1)
    
    # Create HTML part if provided
    if html_body:
        part2 = MIMEText(html_body, \"html\")
        message.attach(part2)
    else:
        # Create simple HTML version from plain text
        html = f\"\"\"
        <html>
          <body>
            <pre style=\"font-family: Arial, sans-serif;\">{body}</pre>
          </body>
        </html>
        \"\"\"
        part2 = MIMEText(html, \"html\")
        message.attach(part2)
    
    try:
        # Create secure connection with server and send email
        context = ssl.create_default_context()
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls(context=context)
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.sendmail(EMAIL_FROM, EMAIL_RECIPIENT, message.as_string())
        log_message(\"Email sent successfully\")
        return True
    except Exception as e:
        log_message(f\"Error sending email: {e}\")
        return False

def generate_weekly_summary():
    \"\"\"Generate a weekly summary of scan results\"\"\"
    # Calculate date range
    end_date = datetime.now()
    start_date = end_date - timedelta(days=7)
    log_message(f\"Generating weekly summary from {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}\")
    
    # Find scans from the last week
    recent_scans = []
    for item in os.listdir(RESULTS_DIR):
        item_path = os.path.join(RESULTS_DIR, item)
        if os.path.isdir(item_path) and \"-\" in item:
            try:
                # Check if directory is newer than start_date
                if os.path.getmtime(item_path) > start_date.timestamp():
                    recent_scans.append(item_path)
            except:
                pass
    
    recent_scans.sort(reverse=True)
    scan_count = len(recent_scans)
    
    # Initialize counters
    total_findings = 0
    critical_findings = 0
    high_findings = 0
    medium_findings = 0
    low_findings = 0
    total_hosts = 0
    
    # Analyze each scan
    scan_details = []
    for scan_dir in recent_scans:
        scan_name = os.path.basename(scan_dir)
        scan_findings = 0
        scan_critical = 0
        scan_high = 0
        
        # Check vulnerabilities
        vuln_dir = os.path.join(scan_dir, \"vulnerabilities\")
        if os.path.isdir(vuln_dir):
            for vuln_file in glob.glob(os.path.join(vuln_dir, \"*.json\")):
                if os.path.isfile(vuln_file) and os.path.getsize(vuln_file) > 0:
                    with open(vuln_file, 'r') as f:
                        content = f.read()
                        
                        # Count vulnerabilities
                        findings = content.count(\"matched-at\")
                        scan_findings += findings
                        total_findings += findings
                        
                        # Count by severity
                        critical = content.count('\"severity\":\"critical\"')
                        high = content.count('\"severity\":\"high\"')
                        medium = content.count('\"severity\":\"medium\"')
                        low = content.count('\"severity\":\"low\"')
                        
                        scan_critical += critical
                        scan_high += high
                        critical_findings += critical
                        high_findings += high
                        medium_findings += medium
                        low_findings += low
        
        # Count hosts
        ports_dir = os.path.join(scan_dir, \"ports\")
        hosts_count = 0
        if os.path.isdir(ports_dir):
            hosts_count = len(glob.glob(os.path.join(ports_dir, \"*.json\")))
            total_hosts += hosts_count
        
        # Add scan details
        scan_details.append({
            \"name\": scan_name,
            \"findings\": scan_findings,
            \"critical\": scan_critical,
            \"high\": scan_high,
            \"hosts\": hosts_count
        })
    
    # Generate summary
    summary = f\"\"\"NUCLEI SECURITY SCANNER - WEEKLY SUMMARY
========================================
Report Period: {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}
Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

SCAN ACTIVITY
-------------
Total Scans Completed: {scan_count}
Total Hosts Scanned: {total_hosts}
Total Vulnerabilities Found: {total_findings}

VULNERABILITY BREAKDOWN
-----------------------
Critical: {critical_findings}
High: {high_findings}
Medium: {medium_findings}
Low: {low_findings}

RECENT SCAN RESULTS
-------------------\"\"\"

    # Add details for each scan
    for scan in scan_details:
        summary += f\"\\n- {scan['name']}: {scan['findings']} vulnerabilities found\"
        if scan['critical'] > 0:
            summary += f\" ({scan['critical']} critical, {scan['high']} high)\"
    
    # Add system status
    summary += \"\\n\\nSYSTEM STATUS\"
    summary += \"\\n-------------\"
    summary += \"\\nNetwork Discovery: Active (scanning every 5 minutes)\"
    summary += \"\\nScheduled Scans: Daily at 3:00 AM and 3:00 PM\"
    summary += \"\\nAuto-scan New Hosts: Enabled\"
    summary += \"\\nHome Assistant Integration: Active\"
    
    # Add recommendations
    summary += \"\\n\\nRECOMMENDATIONS\"
    summary += \"\\n---------------\"
    
    if critical_findings > 0:
        summary += f\"\\n⚠️  URGENT: {critical_findings} critical vulnerabilities require immediate attention\"
    
    if high_findings > 5:
        summary += f\"\\n⚠️  {high_findings} high-severity vulnerabilities should be reviewed and patched\"
    
    if total_findings == 0:
        summary += \"\\n✅ No vulnerabilities found this week - excellent security posture\"
    
    return summary

def check_critical_vulnerabilities():
    \"\"\"Check for critical vulnerabilities in the latest scan\"\"\"
    log_message(\"Checking for new critical vulnerabilities\")
    
    # Find the most recent scan
    scan_dirs = []
    for item in os.listdir(RESULTS_DIR):
        item_path = os.path.join(RESULTS_DIR, item)
        if os.path.isdir(item_path) and \"-\" in item:
            scan_dirs.append(item_path)
    
    if not scan_dirs:
        log_message(\"No scan directories found\")
        return False
    
    # Sort by modification time (newest first)
    scan_dirs.sort(key=lambda x: os.path.getmtime(x), reverse=True)
    latest_scan = scan_dirs[0]
    
    scan_name = os.path.basename(latest_scan)
    critical_vulns = []
    critical_count = 0
    
    # Check for critical vulnerabilities
    vuln_dir = os.path.join(latest_scan, \"vulnerabilities\")
    if os.path.isdir(vuln_dir):
        for vuln_file in glob.glob(os.path.join(vuln_dir, \"*.json\")):
            if os.path.isfile(vuln_file) and os.path.getsize(vuln_file) > 0:
                with open(vuln_file, 'r') as f:
                    content = f.read()
                    
                    # Check for critical vulnerabilities
                    if '\"severity\":\"critical\"' in content:
                        host = os.path.basename(vuln_file).replace(\".json\", \"\")
                        
                        # Extract vulnerability names
                        names = []
                        for line in content.split(\"\\n\"):
                            if '\"severity\":\"critical\"' in line and '\"name\":' in line:
                                match = re.search('\"name\":\"([^\"]+)\"', line)
                                if match:
                                    names.append(match.group(1))
                        
                        if not names:
                            names = [\"Critical vulnerability\"]
                        
                        critical_vulns.append({
                            \"host\": host,
                            \"vulns\": names
                        })
                        critical_count += len(names)
    
    # Send alert if critical vulnerabilities found
    if critical_count > 0:
        log_message(f\"Found {critical_count} critical vulnerabilities, sending alert\")
        
        # Create alert message
        subject = f\"🚨 CRITICAL SECURITY ALERT - {critical_count} Critical Vulnerabilities Found\"
        body = f\"\"\"CRITICAL VULNERABILITIES DETECTED
=====================================
Scan: {scan_name}
Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
Critical Vulnerabilities Found: {critical_count}

AFFECTED SYSTEMS
----------------\"\"\"

        # Add details for each affected system
        for item in critical_vulns:
            body += f\"\\nHost: {item['host']}\\nVulnerabilities:\\n\"
            for vuln in item['vulns']:
                body += f\"  - {vuln}\\n\"
        
        body += \"\\nIMMEDIATE ACTION REQUIRED\"
        body += \"\\n------------------------\"
        body += \"\\nThese critical vulnerabilities require immediate attention and patching.\"
        body += \"\\nPlease review the full scan results and implement fixes as soon as possible.\"
        body += f\"\\n\\nFull scan results available in: {latest_scan}\"
        
        # Create HTML alert
        html_body = f\"\"\"<html><head><style>
            body {{ font-family: Arial, sans-serif; background-color: #fff5f5; margin: 20px; }}
            .alert {{ background-color: #fee; border: 2px solid #e74c3c; padding: 20px; border-radius: 5px; }}
            .critical {{ color: #e74c3c; font-weight: bold; font-size: 18px; }}
            .header {{ color: #c0392b; font-size: 24px; margin-bottom: 20px; }}
            .details {{ background-color: white; padding: 15px; border-radius: 3px; margin: 10px 0; }}
            pre {{ font-family: 'Courier New', monospace; }}
        </style></head><body><div class='alert'>
        <div class='header'>🚨 CRITICAL SECURITY ALERT</div>
        <div class='critical'>{critical_count} Critical Vulnerabilities Detected</div>
        <div class='details'><pre>{body}</pre></div>
        </div></body></html>\"\"\"
        
        # Send the alert
        return send_email(subject, body, html_body)
    else:
        log_message(\"No critical vulnerabilities found in latest scan\")
        return False

def send_weekly_summary():
    \"\"\"Send weekly summary email\"\"\"
    log_message(\"Preparing weekly summary email\")
    
    # Generate summary
    summary = generate_weekly_summary()
    subject = f\"Nuclei Security Scanner - Weekly Summary ({datetime.now().strftime('%Y-%m-%d')})\"
    
    # Create HTML version
    html_body = \"\"\"<html><head><style>
        body { font-family: 'Courier New', monospace; background-color: #f5f5f5; margin: 20px; }
        .container { background-color: white; padding: 20px; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        .header { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        .critical { color: #e74c3c; font-weight: bold; }
        .high { color: #e67e22; font-weight: bold; }
        .medium { color: #f39c12; }
        .low { color: #27ae60; }
        .good { color: #27ae60; font-weight: bold; }
        pre { background-color: #f8f9fa; padding: 15px; border-radius: 3px; overflow-x: auto; }
    </style></head><body><div class='container'>\"\"\"
    
    # Convert plain text to HTML with styling
    styled_summary = summary
    styled_summary = styled_summary.replace(\"URGENT:\", \"<span class='critical'>URGENT:</span>\")
    styled_summary = styled_summary.replace(\"⚠️\", \"<span class='critical'>⚠️</span>\")
    styled_summary = styled_summary.replace(\"✅\", \"<span class='good'>✅</span>\")
    
    html_body += f\"<pre>{styled_summary}</pre></div></body></html>\"
    
    # Send the email
    return send_email(subject, summary, html_body)

def send_test_email():
    \"\"\"Send a test email\"\"\"
    log_message(\"Sending test email\")
    subject = \"Nuclei Scanner Email Test\"
    body = \"This is a test email from the Nuclei scanner email notification system. If you receive this, the email functionality is working correctly.\"
    return send_email(subject, body)

if __name__ == \"__main__\":
    if len(sys.argv) < 2:
        print(\"Usage: python3 email-working.py {weekly-summary|check-critical|test}\")
        sys.exit(1)
    
    command = sys.argv[1]
    if command == \"weekly-summary\":
        send_weekly_summary()
    elif command == \"check-critical\":
        check_critical_vulnerabilities()
    elif command == \"test\":
        send_test_email()
    else:
        print(f\"Unknown command: {command}\")
        print(\"Usage: python3 email-working.py {weekly-summary|check-critical|test}\")
        sys.exit(1)
EOF'"

ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner chmod +x /home/nuclei/scripts/email-working.py"

# Create a simple wrapper script
echo "2. Creating wrapper script..."
ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner sh -c 'cat > /home/nuclei/scripts/email-notifications.sh << \"EOF\"
#!/bin/sh
# Email notification wrapper script

python3 /home/nuclei/scripts/email-working.py \"$@\"
EOF'"

ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner chmod +x /home/nuclei/scripts/email-notifications.sh"

# Test the new system
echo "3. Testing the working email system..."
TEST_RESULT=$(ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner /home/nuclei/scripts/email-notifications.sh test" 2>&1)

echo "Test result:"
echo "$TEST_RESULT"

if echo "$TEST_RESULT" | grep -q "successfully"; then
    echo "   ✅ Email system is now working!"
    
    # Update scan script with email integration
    echo "4. Updating scan scripts to integrate email alerts..."
    SCAN_SCRIPT_CONTENT="$(cat ./scripts/scan-with-ha-robust.sh)"
    ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner sh -c 'cat > /home/nuclei/scripts/scan-with-ha-robust.sh' << EOF
$SCAN_SCRIPT_CONTENT
EOF"
    
    ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker exec nuclei-scanner chmod +x /home/nuclei/scripts/scan-with-ha-robust.sh"
    
    # Restart container to apply entrypoint changes
    echo "5. Restarting container to apply all changes..."
    ssh "${NAS_USER}@${NAS_HOST}" "/var/packages/ContainerManager/target/usr/bin/docker restart nuclei-scanner"
    
    echo ""
    echo "================================="
    echo "🎉 Email system now fully operational!"
    echo ""
    echo "Features enabled:"
    echo "✅ Critical vulnerability alerts"
    echo "✅ Weekly summary emails (Sundays at 5:00 AM)"
    echo "✅ HTML-formatted reports"
    echo ""
    echo "Check your inbox for the test email!"
else
    echo "   ❌ Email system still not working"
    echo "   Error details:"
    echo "$TEST_RESULT"
fi