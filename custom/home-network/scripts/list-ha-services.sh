#!/bin/ash

# List available Home Assistant services
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"
HA_BASE_URL="http://192.168.10.89:8123"

echo "Fetching available notify services..."

RESPONSE=$(curl -s -H "Authorization: Bearer $HA_TOKEN" "$HA_BASE_URL/api/services" | grep -E "(mobile_app|notify)" | grep -A5 -B5 "ben")
echo "$RESPONSE"