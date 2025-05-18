#!/bin/sh
# Simple direct scan for Think Tank server

echo "Starting simple Think Tank scan..."
RESULTS_DIR="/home/nuclei/results/thinktank-simple-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

TARGET="192.168.10.249"

echo "1. Web server on port 80..."
nuclei -u http://$TARGET -t technologies/tech-detect.yaml -j -o "$RESULTS_DIR/web-80.json"

echo "2. Ollama service..."
nuclei -u http://$TARGET:11434 -tags api,tech -s info -j -o "$RESULTS_DIR/ollama.json"
curl -s http://$TARGET:11434/api/tags > "$RESULTS_DIR/ollama-models.json"

echo "3. SSH service..."
nuclei -u ssh://$TARGET -t network/ssh-fingerprint.yaml -j -o "$RESULTS_DIR/ssh.json"

echo "4. Common Docker ports..."
for port in 2375 5000 9000 9443; do
    echo "Checking port $port..."
    timeout 2 curl -s http://$TARGET:$port > "$RESULTS_DIR/port-$port.html" 2>/dev/null || true
done

echo "5. Security headers..."
nuclei -u http://$TARGET -t miscellaneous/security-headers.yaml -j -o "$RESULTS_DIR/headers.json"

echo ""
echo "Results:"
ls -la "$RESULTS_DIR/"

# Analyze Ollama
if [ -s "$RESULTS_DIR/ollama-models.json" ]; then
    echo ""
    echo "Ollama Models:"
    jq -r '.models[]?.name' "$RESULTS_DIR/ollama-models.json"
fi