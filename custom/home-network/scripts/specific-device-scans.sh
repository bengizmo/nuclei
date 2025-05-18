#!/bin/sh
# Device-specific security scans

echo "Device-Specific Security Scanner"
echo "==============================="

show_usage() {
    echo "Usage: $0 <device-type>"
    echo ""
    echo "Available device types:"
    echo "  router    - Scan Ubiquiti routers (UDM, USG)"
    echo "  ap        - Scan Ubiquiti access points"
    echo "  nas       - Scan Synology NAS"
    echo "  docker    - Scan Docker hosts"
    echo "  iot       - Scan IoT devices"
    echo "  homeassistant - Scan Home Assistant"
    exit 1
}

[ $# -eq 0 ] && show_usage

DEVICE_TYPE=$1
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/${DEVICE_TYPE}-${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

case $DEVICE_TYPE in
    router)
        echo "Scanning Ubiquiti routers..."
        TARGET="192.168.10.1"
        
        # Check UniFi specific ports
        echo "Checking UniFi services..."
        for port in 22 80 443 8080 8443 8843 8880 6789 27117; do
            if nc -zv -w 2 $TARGET $port 2>&1 | grep -q "open"; then
                echo "Port $port: OPEN"
                case $port in
                    8443) echo "  UniFi Controller (HTTPS)" ;;
                    8080) echo "  UniFi Controller (HTTP)" ;;
                    8880) echo "  UniFi Controller (HTTP redirect)" ;;
                    8843) echo "  UniFi Controller (HTTPS redirect)" ;;
                    6789) echo "  UniFi mobile speed test" ;;
                    27117) echo "  UniFi database" ;;
                esac
            fi
        done
        
        # Run UniFi specific scans
        nuclei -u "https://$TARGET" \
               -t http/exposed-panels/unifi-panel.yaml \
               -t http/vulnerabilities/other/unifi-network-log4j-rce.yaml \
               -t http/misconfiguration/installer/unifi-wizard-install.yaml \
               -j -o "$RESULTS_DIR/unifi-vulns.json"
        ;;
        
    ap)
        echo "Scanning Ubiquiti access points..."
        APS="192.168.10.156 192.168.10.50 192.168.10.7 192.168.10.130"
        
        for ap in $APS; do
            echo "Scanning AP: $ap"
            # Check standard AP ports
            for port in 22 80 443; do
                nc -zv -w 1 $ap $port 2>&1 | grep -q "open" && echo "  Port $port: OPEN"
            done
            
            # Check for management interfaces
            nuclei -u "https://$ap" \
                   -t exposed-panels/ \
                   -tags ubiquiti,unifi \
                   -j -o "$RESULTS_DIR/ap-$ap.json"
        done
        ;;
        
    nas)
        echo "Scanning Synology NAS..."
        TARGET="192.168.10.163"
        
        # Check Synology specific ports
        echo "Checking Synology services..."
        for port in 22 80 443 5000 5001 6690 7000 7001 9025 9080 9443; do
            if nc -zv -w 2 $TARGET $port 2>&1 | grep -q "open"; then
                echo "Port $port: OPEN"
                case $port in
                    5000) echo "  DSM (HTTP)" ;;
                    5001) echo "  DSM (HTTPS)" ;;
                    6690) echo "  Cloud Station" ;;
                    7000) echo "  File Station (HTTP)" ;;
                    7001) echo "  File Station (HTTPS)" ;;
                    9025) echo "  Synology Assistant" ;;
                esac
            fi
        done
        
        # Run Synology specific scans
        nuclei -u "https://$TARGET:5001" \
               -t exposed-panels/synology-panel.yaml \
               -t cves/ -tags synology \
               -j -o "$RESULTS_DIR/synology-vulns.json"
        ;;
        
    docker)
        echo "Scanning Docker hosts..."
        TARGET="${2:-192.168.10.249}"
        
        # Check Docker specific ports
        echo "Checking Docker services..."
        for port in 2375 2376 5000 9000 9443; do
            if nc -zv -w 2 $TARGET $port 2>&1 | grep -q "open"; then
                echo "Port $port: OPEN"
                case $port in
                    2375) echo "  Docker API (HTTP)" ;;
                    2376) echo "  Docker API (HTTPS)" ;;
                    5000) echo "  Docker Registry" ;;
                    9000) echo "  Portainer (HTTP)" ;;
                    9443) echo "  Portainer (HTTPS)" ;;
                esac
                
                # Test Docker API
                if [ "$port" = "2375" ]; then
                    curl -s "http://$TARGET:2375/version" > "$RESULTS_DIR/docker-version.json"
                fi
            fi
        done
        
        # Run Docker specific scans
        nuclei -u "http://$TARGET:2375" \
               -t misconfiguration/docker-daemon-exposed.yaml \
               -j -o "$RESULTS_DIR/docker-api.json"
               
        nuclei -u "http://$TARGET:9000" \
               -t exposed-panels/portainer-panel.yaml \
               -j -o "$RESULTS_DIR/portainer.json"
        ;;
        
    iot)
        echo "Scanning IoT devices on VLAN..."
        # Scan IoT VLAN
        echo "Discovering IoT devices..."
        for i in $(seq 1 254); do
            ip="192.168.14.$i"
            if nc -zv -w 1 $ip 80 2>/dev/null | grep -q "open"; then
                echo "Found IoT device: $ip"
                
                # Quick fingerprint
                nuclei -u "http://$ip" \
                       -t technologies/tech-detect.yaml \
                       -t exposed-panels/ \
                       -t default-logins/ \
                       -j -o "$RESULTS_DIR/iot-$ip.json"
            fi
        done
        ;;
        
    homeassistant)
        echo "Scanning Home Assistant..."
        TARGET="192.168.10.89"
        
        # Check Home Assistant ports
        echo "Checking Home Assistant services..."
        for port in 22 80 443 8123 1883; do
            if nc -zv -w 2 $TARGET $port 2>&1 | grep -q "open"; then
                echo "Port $port: OPEN"
                case $port in
                    8123) echo "  Home Assistant Web UI" ;;
                    1883) echo "  MQTT Broker" ;;
                esac
            fi
        done
        
        # Run Home Assistant specific scans
        nuclei -u "http://$TARGET:8123" \
               -t exposed-panels/home-assistant-panel.yaml \
               -t technologies/home-assistant-detect.yaml \
               -j -o "$RESULTS_DIR/homeassistant.json"
        ;;
        
    *)
        echo "Unknown device type: $DEVICE_TYPE"
        show_usage
        ;;
esac

# Generate device-specific report
echo ""
echo "Generating report..."
cat > "$RESULTS_DIR/report.txt" <<EOF
Device-Specific Security Scan
Device Type: $DEVICE_TYPE
Date: $SCAN_DATE

Results Summary:
EOF

# Add findings
for file in "$RESULTS_DIR"/*.json; do
    if [ -s "$file" ]; then
        name=$(basename "$file" .json)
        count=$(grep -c "matched-at" "$file" 2>/dev/null || echo 0)
        [ "$count" -gt 0 ] && echo "$name: $count findings" >> "$RESULTS_DIR/report.txt"
    fi
done

echo ""
echo "Scan complete!"
echo "Results saved to: $RESULTS_DIR"
cat "$RESULTS_DIR/report.txt"