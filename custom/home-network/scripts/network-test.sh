#!/bin/sh
# Direct network connectivity test

echo "Network connectivity test for Think Tank..."
TARGET="192.168.10.249"

echo "1. Testing SSH port 22..."
timeout 2 nc -zv $TARGET 22 2>&1 || echo "nc failed, trying telnet..."
timeout 2 telnet $TARGET 22 2>&1 | head -5 || echo "telnet failed, trying direct connection..."

echo ""
echo "2. Direct SSH banner grab..."
echo "QUIT" | timeout 5 nc $TARGET 22 2>&1 | head -3 || echo "Direct connection failed"

echo ""
echo "3. Using different scan method..."
nuclei -u tcp://$TARGET:22 -debug 2>&1 | grep -E "(SSH|22)" | head -10

echo ""
echo "4. Testing other common ports..."
for port in 22 80 443 8080 11434; do
    echo -n "Port $port: "
    (echo >/dev/tcp/$TARGET/$port) 2>/dev/null && echo "OPEN" || echo "CLOSED"
done

echo ""
echo "5. Direct nuclei SSH scan..."
nuclei -u ssh://$TARGET:22 -t network/detect-adduser.yaml -debug -stats-json -j -o ssh-test.json 2>&1

echo ""
echo "6. Alternative port scan..."
nmap -Pn -p22,80,443,11434 $TARGET 2>/dev/null || echo "nmap not available"