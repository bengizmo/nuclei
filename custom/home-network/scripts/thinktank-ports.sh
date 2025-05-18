#!/bin/sh
# Comprehensive port scan for Think Tank

echo "Port scan for Think Tank (192.168.10.249)..."
TARGET="192.168.10.249"
RESULTS_DIR="/home/nuclei/results/ports-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "Testing common ports..."
PORTS="22 80 443 3000 5000 8080 8443 9000 9443 11434 2375 2376"

for port in $PORTS; do
    echo -n "Port $port: "
    nc -zv -w 2 $TARGET $port 2>&1 | grep -o "open\|succeeded" && echo "" || echo "closed/filtered"
done

echo ""
echo "Detected services:"
echo "=================="

# SSH on 22
if nc -zv -w 1 $TARGET 22 2>&1 | grep -q "open"; then
    echo "SSH (22): $(echo 'QUIT' | nc -w 2 $TARGET 22 | head -1)"
fi

# HTTP on 80
if nc -zv -w 1 $TARGET 80 2>&1 | grep -q "open"; then
    echo "HTTP (80): $(curl -s -I http://$TARGET | head -1)"
fi

# HTTPS on 443
if nc -zv -w 1 $TARGET 443 2>&1 | grep -q "open"; then
    echo "HTTPS (443): $(curl -s -I -k https://$TARGET | head -1)"
fi

# Ollama on 11434
if nc -zv -w 1 $TARGET 11434 2>&1 | grep -q "open"; then
    echo "Ollama (11434): $(curl -s http://$TARGET:11434/ | head -c 50)"
fi

echo ""
echo "Full results saved to: $RESULTS_DIR/port-scan.txt"