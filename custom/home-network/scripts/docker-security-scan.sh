#!/bin/sh
# Docker security scan for Think Tank server

echo "Starting Docker security scan..."
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/docker-${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

TARGET="192.168.10.249"

echo "1. Checking for exposed Docker daemon..."
# Docker daemon ports
nuclei -u http://$TARGET:2375 \
       -t misconfiguration/docker-daemon-exposed.yaml \
       -j -o "$RESULTS_DIR/docker-daemon.json"

nuclei -u https://$TARGET:2376 \
       -t misconfiguration/docker-daemon-exposed.yaml \
       -j -o "$RESULTS_DIR/docker-daemon-tls.json"

echo "2. Checking Docker registry..."
nuclei -u http://$TARGET:5000 \
       -t exposed-panels/docker-registry.yaml \
       -j -o "$RESULTS_DIR/docker-registry.json"

echo "3. Checking container management panels..."
# Portainer
nuclei -u http://$TARGET:9000 \
       -t exposed-panels/portainer-panel.yaml \
       -j -o "$RESULTS_DIR/portainer.json"

nuclei -u https://$TARGET:9443 \
       -t exposed-panels/portainer-panel.yaml \
       -j -o "$RESULTS_DIR/portainer-https.json"

# Docker Swarm visualizer
nuclei -u http://$TARGET:8080 \
       -t exposed-panels/docker-visualizer.yaml \
       -j -o "$RESULTS_DIR/docker-visualizer.json"

echo "4. Testing Docker API endpoints..."
# Direct API test
curl -s http://$TARGET:2375/version > "$RESULTS_DIR/docker-version.json" 2>/dev/null
curl -s http://$TARGET:2375/info > "$RESULTS_DIR/docker-info.json" 2>/dev/null
curl -s http://$TARGET:2375/containers/json > "$RESULTS_DIR/docker-containers.json" 2>/dev/null

echo "5. Checking for exposed container services..."
# Common containerized services
nuclei -u http://$TARGET:80 \
       -t technologies/nginx-detect.yaml \
       -t technologies/apache-detect.yaml \
       -j -o "$RESULTS_DIR/web-server.json"

nuclei -u http://$TARGET:3000 \
       -t exposed-panels/grafana-panel.yaml \
       -j -o "$RESULTS_DIR/grafana.json"

nuclei -u http://$TARGET:8086 \
       -t exposed-panels/influxdb-panel.yaml \
       -j -o "$RESULTS_DIR/influxdb.json"

echo ""
echo "Docker security scan completed!"
echo "Results: $RESULTS_DIR"

# Create summary
cat > "$RESULTS_DIR/docker-summary.txt" <<EOF
Docker Security Scan Summary
Date: $SCAN_DATE
Target: $TARGET

Docker API Exposure:
$(if [ -s "$RESULTS_DIR/docker-version.json" ]; then echo "WARNING: Docker API exposed on port 2375!"; else echo "Docker API not exposed (good)"; fi)

Container Services Found:
EOF

find "$RESULTS_DIR" -name "*.json" -size +2c -exec sh -c 'echo "- $(basename "$1" .json)"' _ {} \; >> "$RESULTS_DIR/docker-summary.txt"

echo ""
cat "$RESULTS_DIR/docker-summary.txt"