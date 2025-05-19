#!/bin/bash
# Test AI integration on NAS

# Load NAS configuration
source ./nas-config.sh

echo "🤖 Testing AI Integration..."
echo ""

# Test AI template generation
echo "1. Testing AI template generation:"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner nuclei -ai 'detect exposed home automation systems' -silent"
RESULT=$?

if [ $RESULT -eq 0 ]; then
    echo "   ✅ AI template generation is working"
else
    echo "   ❌ AI template generation failed"
fi

# Test with a specific target
echo ""
echo "2. Testing AI scan on Home Assistant device:"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner mkdir -p /home/nuclei/results/ai-test"
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner nuclei -ai 'find vulnerabilities in home assistant system at 192.168.10.89' -target 192.168.10.89 -o /home/nuclei/results/ai-test/ha-scan.json -json -silent"

# Check if results were generated
echo ""
echo "3. Checking AI scan results:"
RESULTS=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner cat /home/nuclei/results/ai-test/ha-scan.json 2>/dev/null | wc -l")
if [ "$RESULTS" -gt 0 ]; then
    echo "   ✅ AI scan generated results"
    echo "   Lines in result file: $RESULTS"
else
    echo "   ℹ️  No vulnerabilities found (which is good!)"
fi

echo ""
echo "✨ AI integration test complete"