#!/bin/sh
# Email notification system for Nuclei scanner
# Handles sending weekly summaries and critical vulnerability alerts

# First source environment variables
if [ -f "/home/nuclei/scripts/load-env.sh" ]; then
    . "/home/nuclei/scripts/load-env.sh"
else
    echo "WARNING: load-env.sh not found, email may not work correctly"
fi

# Configuration from environment variables
SMTP_SERVER="${SMTP_SERVER:-smtp.gmail.com}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USE_TLS="${SMTP_USE_TLS:-True}"
SMTP_USERNAME="${SMTP_USERNAME}"
SMTP_PASSWORD="${SMTP_PASSWORD}"
EMAIL_RECIPIENT="${EMAIL_RECIPIENT}"
EMAIL_FROM="${EMAIL_FROM:-$SMTP_USERNAME}"

# Paths
RESULTS_DIR="/home/nuclei/results"
LOGS_DIR="/home/nuclei/logs"
EMAIL_LOG="$LOGS_DIR/email-notifications.log"

# Ensure logs directory exists
mkdir -p "$LOGS_DIR"

# Function to log with timestamp
log_email() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$EMAIL_LOG"
}

# Function to send email using Python (since msmtp might not be available)
send_email() {
    local subject="$1"
    local body="$2"
    local html_body="$3"
    
    log_email "Sending email: $subject"
    
    # Create Python script to send email
    python3 <<EOF
import smtplib
import ssl
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders
import os
import sys

# Email configuration
smtp_server = "$SMTP_SERVER"
port = int("$SMTP_PORT")
sender_email = "$EMAIL_FROM"
password = "$SMTP_PASSWORD"
receiver_email = "$EMAIL_RECIPIENT"

# Create message
message = MIMEMultipart("alternative")
message["Subject"] = "$subject"
message["From"] = sender_email
message["To"] = receiver_email

# Create plain text and HTML versions
text = """$body"""

html = """$html_body""" if "$html_body" else f"""
<html>
  <body>
    <pre>{text}</pre>
  </body>
</html>
"""

# Turn these into plain/html MIMEText objects
part1 = MIMEText(text, "plain")
part2 = MIMEText(html, "html")

# Add HTML/plain-text parts to MIMEMultipart message
message.attach(part1)
message.attach(part2)

# Send email
try:
    # Create secure connection with server and send email
    context = ssl.create_default_context()
    with smtplib.SMTP(smtp_server, port) as server:
        server.starttls(context=context)
        server.login(sender_email, password)
        text = message.as_string()
        server.sendmail(sender_email, receiver_email, text)
    print("Email sent successfully")
    sys.exit(0)
except Exception as e:
    print(f"Error sending email: {e}")
    sys.exit(1)
EOF

    if [ $? -eq 0 ]; then
        log_email "Email sent successfully"
        return 0
    else
        log_email "Failed to send email"
        return 1
    fi
}

# Function to generate weekly summary
generate_weekly_summary() {
    local start_date=$(date -d '7 days ago' '+%Y-%m-%d')
    local end_date=$(date '+%Y-%m-%d')
    local summary_file="/tmp/weekly_summary.txt"
    
    log_email "Generating weekly summary from $start_date to $end_date"
    
    # Find scans from the last week
    local recent_scans=$(find "$RESULTS_DIR" -maxdepth 1 -type d -name "*-*" -newermt "$start_date" | sort)
    local scan_count=$(echo "$recent_scans" | wc -l)
    
    # Initialize counters
    local total_findings=0
    local critical_findings=0
    local high_findings=0
    local medium_findings=0
    local low_findings=0
    local total_hosts=0
    
    # Analyze each scan
    for scan_dir in $recent_scans; do
        if [ -d "$scan_dir" ]; then
            # Count vulnerabilities
            if [ -d "$scan_dir/vulnerabilities" ]; then
                for vuln_file in "$scan_dir/vulnerabilities"/*.json; do
                    if [ -f "$vuln_file" ] && [ -s "$vuln_file" ]; then
                        local file_findings=$(grep -c "matched-at" "$vuln_file" 2>/dev/null || echo 0)
                        total_findings=$((total_findings + file_findings))
                        
                        # Count by severity
                        critical_findings=$((critical_findings + $(grep -c '"severity":"critical"' "$vuln_file" 2>/dev/null || echo 0)))
                        high_findings=$((high_findings + $(grep -c '"severity":"high"' "$vuln_file" 2>/dev/null || echo 0)))
                        medium_findings=$((medium_findings + $(grep -c '"severity":"medium"' "$vuln_file" 2>/dev/null || echo 0)))
                        low_findings=$((low_findings + $(grep -c '"severity":"low"' "$vuln_file" 2>/dev/null || echo 0)))
                    fi
                done
            fi
            
            # Count hosts scanned
            if [ -d "$scan_dir/ports" ]; then
                local scan_hosts=$(find "$scan_dir/ports" -name "*.json" -type f | wc -l)
                total_hosts=$((total_hosts + scan_hosts))
            fi
        fi
    done
    
    # Generate summary report
    cat > "$summary_file" << EOF
NUCLEI SECURITY SCANNER - WEEKLY SUMMARY
========================================
Report Period: $start_date to $end_date
Generated: $(date '+%Y-%m-%d %H:%M:%S')

SCAN ACTIVITY
-------------
Total Scans Completed: $scan_count
Total Hosts Scanned: $total_hosts
Total Vulnerabilities Found: $total_findings

VULNERABILITY BREAKDOWN
-----------------------
Critical: $critical_findings
High: $high_findings  
Medium: $medium_findings
Low: $low_findings

RECENT SCAN RESULTS
-------------------
EOF

    # Add details for each recent scan
    for scan_dir in $recent_scans; do
        if [ -d "$scan_dir" ]; then
            local scan_name=$(basename "$scan_dir")
            local scan_findings=0
            
            if [ -d "$scan_dir/vulnerabilities" ]; then
                for vuln_file in "$scan_dir/vulnerabilities"/*.json; do
                    if [ -f "$vuln_file" ] && [ -s "$vuln_file" ]; then
                        local file_findings=$(grep -c "matched-at" "$vuln_file" 2>/dev/null || echo 0)
                        scan_findings=$((scan_findings + file_findings))
                    fi
                done
            fi
            
            echo "- $scan_name: $scan_findings vulnerabilities found" >> "$summary_file"
        fi
    done
    
    # Add system status
    cat >> "$summary_file" << EOF

SYSTEM STATUS
-------------
Network Discovery: Active (scanning every 5 minutes)
Scheduled Scans: Daily at 3:00 AM and 3:00 PM
Auto-scan New Hosts: Enabled
Home Assistant Integration: Active

RECOMMENDATIONS
---------------
EOF

    # Add recommendations based on findings
    if [ $critical_findings -gt 0 ]; then
        echo "⚠️  URGENT: $critical_findings critical vulnerabilities require immediate attention" >> "$summary_file"
    fi
    
    if [ $high_findings -gt 5 ]; then
        echo "⚠️  $high_findings high-severity vulnerabilities should be reviewed and patched" >> "$summary_file"
    fi
    
    if [ $total_findings -eq 0 ]; then
        echo "✅ No vulnerabilities found this week - excellent security posture" >> "$summary_file"
    fi
    
    echo "$summary_file"
}

# Function to send weekly summary email
send_weekly_summary() {
    log_email "Preparing weekly summary email"
    
    local summary_file=$(generate_weekly_summary)
    local subject="Nuclei Security Scanner - Weekly Summary ($(date '+%Y-%m-%d'))"
    local body=$(cat "$summary_file")
    
    # Create HTML version
    local html_body="<html><head><style>
        body { font-family: 'Courier New', monospace; background-color: #f5f5f5; margin: 20px; }
        .container { background-color: white; padding: 20px; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        .header { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        .critical { color: #e74c3c; font-weight: bold; }
        .high { color: #e67e22; font-weight: bold; }
        .medium { color: #f39c12; }
        .low { color: #27ae60; }
        .good { color: #27ae60; font-weight: bold; }
        pre { background-color: #f8f9fa; padding: 15px; border-radius: 3px; overflow-x: auto; }
    </style></head><body><div class='container'>"
    
    # Convert plain text to HTML with styling
    html_body+="<pre>$(echo "$body" | sed 's/URGENT:/\<span class=\"critical\"\>URGENT:\<\/span\>/g' | sed 's/⚠️/\<span class=\"critical\"\>⚠️\<\/span\>/g' | sed 's/✅/\<span class=\"good\"\>✅\<\/span\>/g')</pre>"
    html_body+="</div></body></html>"
    
    send_email "$subject" "$body" "$html_body"
    
    # Clean up
    rm -f "$summary_file"
}

# Function to check for critical vulnerabilities and send alerts
check_critical_vulnerabilities() {
    log_email "Checking for new critical vulnerabilities"
    
    # Find the most recent scan
    local latest_scan=$(find "$RESULTS_DIR" -maxdepth 1 -type d -name "*-*" | sort -r | head -1)
    
    if [ -z "$latest_scan" ]; then
        log_email "No recent scans found"
        return
    fi
    
    local scan_name=$(basename "$latest_scan")
    local critical_vulns=""
    local critical_count=0
    
    # Check for critical vulnerabilities in the latest scan
    if [ -d "$latest_scan/vulnerabilities" ]; then
        for vuln_file in "$latest_scan/vulnerabilities"/*.json; do
            if [ -f "$vuln_file" ] && [ -s "$vuln_file" ]; then
                # Extract critical vulnerabilities
                local file_criticals=$(grep -l '"severity":"critical"' "$vuln_file" 2>/dev/null)
                if [ -n "$file_criticals" ]; then
                    local host=$(basename "$vuln_file" .json)
                    local vulns=$(grep '"severity":"critical"' "$vuln_file" | jq -r '.info.name' 2>/dev/null || echo "Critical vulnerability")
                    
                    critical_vulns+="Host: $host\n"
                    critical_vulns+="Vulnerabilities:\n$(echo "$vulns" | sed 's/^/  - /')\n\n"
                    critical_count=$((critical_count + $(echo "$vulns" | wc -l)))
                fi
            fi
        done
    fi
    
    # Send alert if critical vulnerabilities found
    if [ $critical_count -gt 0 ]; then
        log_email "Found $critical_count critical vulnerabilities, sending alert"
        
        local subject="🚨 CRITICAL SECURITY ALERT - $critical_count Critical Vulnerabilities Found"
        local body="CRITICAL VULNERABILITIES DETECTED
=====================================
Scan: $scan_name
Time: $(date '+%Y-%m-%d %H:%M:%S')
Critical Vulnerabilities Found: $critical_count

AFFECTED SYSTEMS
----------------
$critical_vulns

IMMEDIATE ACTION REQUIRED
------------------------
These critical vulnerabilities require immediate attention and patching.
Please review the full scan results and implement fixes as soon as possible.

Full scan results available in: $latest_scan"

        # Create HTML alert
        local html_body="<html><head><style>
            body { font-family: Arial, sans-serif; background-color: #fff5f5; margin: 20px; }
            .alert { background-color: #fee; border: 2px solid #e74c3c; padding: 20px; border-radius: 5px; }
            .critical { color: #e74c3c; font-weight: bold; font-size: 18px; }
            .header { color: #c0392b; font-size: 24px; margin-bottom: 20px; }
            .details { background-color: white; padding: 15px; border-radius: 3px; margin: 10px 0; }
            pre { font-family: 'Courier New', monospace; }
        </style></head><body><div class='alert'>
        <div class='header'>🚨 CRITICAL SECURITY ALERT</div>
        <div class='critical'>$critical_count Critical Vulnerabilities Detected</div>
        <div class='details'><pre>$(echo -e "$body")</pre></div>
        </div></body></html>"
        
        send_email "$subject" "$body" "$html_body"
    else
        log_email "No critical vulnerabilities found in latest scan"
    fi
}

# Main function
main() {
    case "$1" in
        "weekly-summary")
            send_weekly_summary
            ;;
        "check-critical")
            check_critical_vulnerabilities
            ;;
        "test")
            log_email "Testing email functionality"
            send_email "Nuclei Scanner Email Test" "This is a test email from the Nuclei scanner email notification system. If you receive this, the email functionality is working correctly." ""
            ;;
        *)
            echo "Usage: $0 {weekly-summary|check-critical|test}"
            echo "  weekly-summary  - Send weekly summary report"
            echo "  check-critical  - Check for and alert on critical vulnerabilities"
            echo "  test           - Send test email"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"