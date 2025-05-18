#!/bin/sh
# Comprehensive scan for Think Tank server (192.168.10.249)
# Ubuntu server running Docker containers and Ollama

echo "Starting comprehensive Think Tank server scan..."
SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/thinktank-${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

TARGET="192.168.10.249"

echo "Phase 1: Port discovery..."
# Common ports for Docker, Ollama, SSH, web services
PORTS="22 80 443 2375 2376 8080 8443 9443 3000 5000 11434"
for port in $PORTS; do
    echo "Checking port $port..."
    timeout 2 nc -zv $TARGET $port 2>&1 | grep -q "succeeded" && echo "Port $port is open" >> "$RESULTS_DIR/open-ports.txt"
done

echo "Phase 2: Technology detection..."
nuclei -u http://$TARGET \
       -t technologies/ \
       -s info,low,medium,high,critical \
       -j -o "$RESULTS_DIR/tech-detect-http.json"

nuclei -u https://$TARGET \
       -t technologies/ \
       -s info,low,medium,high,critical \
       -j -o "$RESULTS_DIR/tech-detect-https.json"

echo "Phase 3: Docker service scan..."
# Check for exposed Docker API
nuclei -u http://$TARGET:2375 \
       -t exposed-panels/docker-api.yaml \
       -t misconfiguration/docker-daemon-exposed.yaml \
       -s info,low,medium,high,critical \
       -j -o "$RESULTS_DIR/docker-api.json"

echo "Phase 4: Ollama API scan..."
# Check Ollama default port
nuclei -u http://$TARGET:11434 \
       -t technologies/ \
       -t exposed-panels/ \
       -t misconfiguration/ \
       -s info,low,medium,high,critical \
       -j -o "$RESULTS_DIR/ollama.json"

# Test Ollama API endpoint
curl -s http://$TARGET:11434/api/tags > "$RESULTS_DIR/ollama-models.json" 2>/dev/null

echo "Phase 5: SSH security check..."
nuclei -u ssh://$TARGET:22 \
       -t network/ssh-auth.yaml \
       -t network/ssh-fingerprint.yaml \
       -t network/ssh-weakkey-exchange-algo.yaml \
       -s info,low,medium,high,critical \
       -j -o "$RESULTS_DIR/ssh-security.json"

echo "Phase 6: Web services scan..."
# Check common web ports
for port in 80 443 8080 8443 3000 5000; do
    echo "Scanning web service on port $port..."
    nuclei -u http://$TARGET:$port \
           -t exposed-panels/ \
           -t technologies/ \
           -t vulnerabilities/ \
           -s info,low,medium,high,critical \
           -timeout 10 \
           -j -o "$RESULTS_DIR/web-$port.json"
done

echo "Phase 7: Container registry scan..."
# Check for exposed container registries
nuclei -u http://$TARGET:5000 \
       -t exposed-panels/docker-registry.yaml \
       -t misconfiguration/docker-registry-exposed.yaml \
       -s info,low,medium,high,critical \
       -j -o "$RESULTS_DIR/registry.json"

echo "Phase 8: Database exposure check..."
# Check for exposed databases commonly used with Docker
DATABASES="3306:mysql 5432:postgres 6379:redis 27017:mongodb"
for db in $DATABASES; do
    port=$(echo $db | cut -d: -f1)
    name=$(echo $db | cut -d: -f2)
    echo "Checking $name on port $port..."
    nuclei -u $TARGET:$port \
           -t network/exposed-$name.yaml \
           -t exposed-panels/$name-panel.yaml \
           -s info,low,medium,high,critical \
           -timeout 10 \
           -j -o "$RESULTS_DIR/db-$name.json" 2>/dev/null
done

echo "Phase 9: Vulnerability scan..."
nuclei -u http://$TARGET \
       -t cves/ \
       -t vulnerabilities/ \
       -t misconfiguration/ \
       -s medium,high,critical \
       -j -o "$RESULTS_DIR/vulnerabilities.json"

echo "Phase 10: Security headers check..."
nuclei -u http://$TARGET \
       -t miscellaneous/security-headers.yaml \
       -t misconfiguration/http-missing-security-headers.yaml \
       -s info,low,medium,high,critical \
       -j -o "$RESULTS_DIR/security-headers.json"

echo ""
echo "Scan completed!"
echo "Results saved to: $RESULTS_DIR"
echo ""

# Create summary report
cat > "$RESULTS_DIR/summary.txt" <<EOF
Think Tank Server Security Scan
Date: $SCAN_DATE
Target: $TARGET
Description: Ubuntu server with Docker and Ollama

Open Ports:
$(cat "$RESULTS_DIR/open-ports.txt" 2>/dev/null || echo "No port scan results")

Findings:
EOF

# Analyze results
for file in "$RESULTS_DIR"/*.json; do
    if [ -s "$file" ]; then
        echo "" >> "$RESULTS_DIR/summary.txt"
        echo "=== $(basename $file .json) ===" >> "$RESULTS_DIR/summary.txt"
        matches=$(grep -c '"matched-at"' "$file" 2>/dev/null || echo 0)
        echo "Matches: $matches" >> "$RESULTS_DIR/summary.txt"
        if [ "$matches" -gt 0 ]; then
            echo "Details:" >> "$RESULTS_DIR/summary.txt"
            jq -r '.["matcher-name"] // .template' "$file" | head -5 >> "$RESULTS_DIR/summary.txt"
        fi
    fi
done

echo ""
echo "Summary report: $RESULTS_DIR/summary.txt"
cat "$RESULTS_DIR/summary.txt"

# Link to latest
ln -sf "$RESULTS_DIR" "/home/nuclei/results/latest-thinktank"