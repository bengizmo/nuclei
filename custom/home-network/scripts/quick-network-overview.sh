#!/bin/sh
# Quick network overview scan for all critical infrastructure

echo "Quick Network Security Overview"
echo "==============================="
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/overview-${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

# Critical infrastructure
HOSTS="
192.168.10.1:UDM-PRO
192.168.10.249:Think-Tank
192.168.10.251:RBHome
192.168.10.89:Home-Assistant
192.168.10.163:NAS
192.168.10.156:AP-1
192.168.10.50:AP-2
192.168.10.7:AP-3
192.168.10.130:AP-4
"

echo "Scanning critical infrastructure..."
echo ""

for host_info in $HOSTS; do
    ip=$(echo $host_info | cut -d: -f1)
    name=$(echo $host_info | cut -d: -f2)
    
    echo "=== $name ($ip) ==="
    
    # Quick port check on common ports
    common_ports="22 80 443 8080 8443"
    open_ports=""
    
    for port in $common_ports; do
        if nc -zv -w 1 $ip $port 2>&1 | grep -q "open\|succeeded"; then
            open_ports="$open_ports $port"
        fi
    done
    
    if [ -n "$open_ports" ]; then
        echo "Open ports:$open_ports"
        
        # Get basic service info
        for port in $open_ports; do
            case $port in
                22)  echo "  SSH: $(echo 'QUIT' | nc -w 1 $ip 22 | head -1)" ;;
                80)  echo "  HTTP: $(curl -s -I http://$ip -m 2 | head -1)" ;;
                443) echo "  HTTPS: $(curl -s -I -k https://$ip -m 2 | head -1)" ;;
            esac
        done
    else
        echo "No common ports detected (may be filtered)"
    fi
    
    echo ""
done

# Check for vulnerable services
echo "Checking for common vulnerabilities..."
echo "===================================="

# Quick vulnerability checks
for host_info in $HOSTS; do
    ip=$(echo $host_info | cut -d: -f1)
    name=$(echo $host_info | cut -d: -f2)
    
    # Check for exposed sensitive services
    sensitive_ports="2375 3306 5432 6379 11211 27017"
    exposed=""
    
    for port in $sensitive_ports; do
        if nc -zv -w 1 $ip $port 2>&1 | grep -q "open\|succeeded"; then
            case $port in
                2375) exposed="$exposed Docker-API" ;;
                3306) exposed="$exposed MySQL" ;;
                5432) exposed="$exposed PostgreSQL" ;;
                6379) exposed="$exposed Redis" ;;
                11211) exposed="$exposed Memcached" ;;
                27017) exposed="$exposed MongoDB" ;;
            esac
        fi
    done
    
    if [ -n "$exposed" ]; then
        echo "⚠️  $name ($ip) - Exposed services:$exposed"
    fi
done

# Summary
cat > "$RESULTS_DIR/overview.txt" <<EOF
Network Security Overview
Date: $SCAN_DATE

Hosts Scanned:
$(echo "$HOSTS" | tr ' ' '\n' | grep -v '^$')

Quick Assessment:
- Check full report for detailed findings
- Run comprehensive scans on hosts with exposed services
- Prioritize hosts with sensitive services exposed
EOF

echo ""
echo "Overview complete!"
echo "Results saved to: $RESULTS_DIR/overview.txt"
echo ""
echo "For detailed scans, run:"
echo "  ./comprehensive-host-scan.sh <ip> <name>"