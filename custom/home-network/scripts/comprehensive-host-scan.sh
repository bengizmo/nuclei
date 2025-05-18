#!/bin/sh
# Comprehensive host scanning with improved port detection

echo "Comprehensive host security scanner"
echo "=================================="

# Check if target is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <target-ip> [host-name]"
    exit 1
fi

TARGET=$1
NAME=${2:-"target"}
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/host-${NAME}-${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

echo "Scanning: $NAME ($TARGET)"
echo "Results: $RESULTS_DIR"
echo ""

# Phase 1: Port Discovery
echo "Phase 1: Port Discovery"
echo "======================"
ALL_PORTS="21 22 23 25 53 80 110 111 135 139 143 161 443 445 993 995 1433 1521 1723 3306 3389 5432 5900 5985 6379 6789 8080 8443 8883 9000 9443 10001 11211 11434 27017"

echo "Scanning ports..."
open_ports=""
for port in $ALL_PORTS; do
    if nc -zv -w 2 $TARGET $port 2>&1 | grep -q "open\|succeeded"; then
        echo "Port $port: OPEN"
        open_ports="$open_ports $port"
        
        # Get banner/service info
        case $port in
            21) echo "  Service: FTP" ;;
            22) echo "  Service: SSH - $(echo 'QUIT' | nc -w 2 $TARGET 22 | head -1)" ;;
            23) echo "  Service: Telnet" ;;
            25) echo "  Service: SMTP" ;;
            53) echo "  Service: DNS" ;;
            80) echo "  Service: HTTP - $(curl -s -I http://$TARGET | head -1)" ;;
            110) echo "  Service: POP3" ;;
            135) echo "  Service: RPC" ;;
            139|445) echo "  Service: SMB/NetBIOS" ;;
            143) echo "  Service: IMAP" ;;
            443) echo "  Service: HTTPS - $(curl -s -I -k https://$TARGET | head -1)" ;;
            1433) echo "  Service: MSSQL" ;;
            1521) echo "  Service: Oracle" ;;
            3306) echo "  Service: MySQL" ;;
            3389) echo "  Service: RDP" ;;
            5432) echo "  Service: PostgreSQL" ;;
            5900) echo "  Service: VNC" ;;
            6379) echo "  Service: Redis" ;;
            8080) echo "  Service: HTTP-Alt" ;;
            8443) echo "  Service: HTTPS-Alt" ;;
            11211) echo "  Service: Memcached" ;;
            11434) echo "  Service: Ollama - $(curl -s http://$TARGET:11434/ | head -c 50)" ;;
            27017) echo "  Service: MongoDB" ;;
            *) echo "  Service: Unknown" ;;
        esac
    fi
done

# Save port scan results
echo "Open Ports on $NAME ($TARGET):" > "$RESULTS_DIR/ports.txt"
echo "$open_ports" >> "$RESULTS_DIR/ports.txt"

echo ""
echo "Phase 2: Service Detection"
echo "========================="

# Web services
if echo "$open_ports" | grep -q "80\|443\|8080\|8443"; then
    echo "Web services detected, running detailed scans..."
    
    for port in 80 443 8080 8443; do
        if echo "$open_ports" | grep -q "$port"; then
            proto="http"
            [ "$port" = "443" ] || [ "$port" = "8443" ] && proto="https"
            
            echo "Scanning $proto://$TARGET:$port"
            nuclei -u "$proto://$TARGET:$port" \
                   -t technologies/tech-detect.yaml \
                   -j -o "$RESULTS_DIR/tech-$port.json"
        fi
    done
fi

# SSH service
if echo "$open_ports" | grep -q "22"; then
    echo "SSH service detected, checking security..."
    ssh_banner=$(echo "QUIT" | nc -w 2 $TARGET 22 | head -1)
    echo "SSH Banner: $ssh_banner" > "$RESULTS_DIR/ssh.txt"
    
    # Check for weak algorithms
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        -o KexAlgorithms=diffie-hellman-group1-sha1 \
        $TARGET exit 2>&1 | grep -q "no matching" && \
        echo "Weak kex algorithms: DISABLED" >> "$RESULTS_DIR/ssh.txt" || \
        echo "Weak kex algorithms: POSSIBLY ENABLED" >> "$RESULTS_DIR/ssh.txt"
fi

echo ""
echo "Phase 3: Vulnerability Assessment"
echo "================================"

# Run targeted scans based on open ports
for port in $open_ports; do
    case $port in
        22)
            echo "Scanning SSH vulnerabilities..."
            nuclei -u $TARGET \
                   -t network/enumeration/ssh-auth-methods.yaml \
                   -t network/openssh-detect.yaml \
                   -j -o "$RESULTS_DIR/vuln-ssh.json"
            ;;
        80|443|8080|8443)
            proto="http"
            [ "$port" = "443" ] || [ "$port" = "8443" ] && proto="https"
            echo "Scanning web vulnerabilities on port $port..."
            nuclei -u "$proto://$TARGET:$port" \
                   -t vulnerabilities/ \
                   -t cves/ \
                   -t exposures/ \
                   -t misconfiguration/ \
                   -s medium,high,critical \
                   -j -o "$RESULTS_DIR/vuln-web-$port.json"
            ;;
        3306)
            echo "Scanning MySQL vulnerabilities..."
            nuclei -u $TARGET \
                   -t exposed-panels/mysql-panel.yaml \
                   -t network/exposed-mysql.yaml \
                   -j -o "$RESULTS_DIR/vuln-mysql.json"
            ;;
        5432)
            echo "Scanning PostgreSQL vulnerabilities..."
            nuclei -u $TARGET \
                   -t exposed-panels/postgresql-panel.yaml \
                   -t network/exposed-postgres.yaml \
                   -j -o "$RESULTS_DIR/vuln-postgres.json"
            ;;
        6379)
            echo "Scanning Redis vulnerabilities..."
            nuclei -u $TARGET \
                   -t network/exposed-redis.yaml \
                   -j -o "$RESULTS_DIR/vuln-redis.json"
            ;;
        27017)
            echo "Scanning MongoDB vulnerabilities..."
            nuclei -u $TARGET \
                   -t network/exposed-mongodb.yaml \
                   -j -o "$RESULTS_DIR/vuln-mongodb.json"
            ;;
    esac
done

echo ""
echo "Phase 4: Report Generation"
echo "========================="

# Generate comprehensive report
cat > "$RESULTS_DIR/report.txt" <<EOF
Security Assessment Report
Target: $NAME ($TARGET)
Date: $SCAN_DATE

=== OPEN PORTS ===
$open_ports

=== SERVICE DETAILS ===
EOF

# Add service details
if [ -f "$RESULTS_DIR/ssh.txt" ]; then
    echo "" >> "$RESULTS_DIR/report.txt"
    echo "SSH Service:" >> "$RESULTS_DIR/report.txt"
    cat "$RESULTS_DIR/ssh.txt" >> "$RESULTS_DIR/report.txt"
fi

# Add vulnerability findings
echo "" >> "$RESULTS_DIR/report.txt"
echo "=== VULNERABILITIES ===" >> "$RESULTS_DIR/report.txt"

for file in "$RESULTS_DIR"/vuln-*.json; do
    if [ -s "$file" ]; then
        service=$(basename "$file" .json | sed 's/vuln-//')
        count=$(grep -c "matched-at" "$file" 2>/dev/null || echo 0)
        echo "$service: $count vulnerabilities found" >> "$RESULTS_DIR/report.txt"
    fi
done

# Add technology detections
echo "" >> "$RESULTS_DIR/report.txt"
echo "=== TECHNOLOGIES ===" >> "$RESULTS_DIR/report.txt"

for file in "$RESULTS_DIR"/tech-*.json; do
    if [ -s "$file" ]; then
        port=$(basename "$file" .json | sed 's/tech-//')
        techs=$(jq -r '.["matcher-name"] // empty' "$file" 2>/dev/null | tr '\n' ', ')
        [ -n "$techs" ] && echo "Port $port: $techs" >> "$RESULTS_DIR/report.txt"
    fi
done

echo ""
echo "Scan complete!"
echo "=============="
echo ""
cat "$RESULTS_DIR/report.txt"
echo ""
echo "Full results saved to: $RESULTS_DIR"