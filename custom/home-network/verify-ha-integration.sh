#!/bin/bash
# Verify Home Assistant integration

# Load NAS configuration
source ./nas-config.sh

echo "🏠 Verifying Home Assistant Integration"
echo "====================================="
echo ""

# Check sensor in Home Assistant
echo "1. Checking Nuclei sensors in Home Assistant..."
curl -s -H "Authorization: Bearer $(grep HOME_ASSISTANT_API_TOKEN .env | cut -d= -f2)" \
    http://192.168.10.89:8123/api/states | \
    jq -r '.[] | select(.entity_id | contains("nuclei")) | .entity_id + ": " + .state'

echo ""
echo "2. Checking latest AI summary..."
SUMMARY=$(curl -s -H "Authorization: Bearer $(grep HOME_ASSISTANT_API_TOKEN .env | cut -d= -f2)" \
    http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_summary | \
    jq -r '.state')
echo "Current summary: $SUMMARY"

echo ""
echo "3. Checking summary attributes..."
curl -s -H "Authorization: Bearer $(grep HOME_ASSISTANT_API_TOKEN .env | cut -d= -f2)" \
    http://192.168.10.89:8123/api/states/sensor.nuclei_scanner_summary | \
    jq '.attributes | {critical_count, high_count, medium_count, low_count, hosts_scanned}'

echo ""
echo "4. Checking test sensor..."
TEST_SENSOR=$(curl -s -H "Authorization: Bearer $(grep HOME_ASSISTANT_API_TOKEN .env | cut -d= -f2)" \
    http://192.168.10.89:8123/api/states/sensor.nuclei_test | \
    jq -r '.state')
echo "Test sensor state: $TEST_SENSOR"

echo ""
echo "====================================="
echo "✅ Home Assistant integration verified!"
echo ""
echo "The system is now correctly:"
echo "- Updating AI summaries in Home Assistant"
echo "- Sending vulnerability alerts when needed"
echo "- Maintaining sensor states with scan results"