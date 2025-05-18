#!/bin/ash

# Test Home Assistant notification system
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"
HA_BASE_URL="http://192.168.10.89:8123"

if [ -z "$HA_TOKEN" ] || [ -z "$HA_BASE_URL" ]; then
    echo "Error: HA_TOKEN or HA_BASE_URL not set"
    exit 1
fi

echo "Testing Home Assistant notification..."

# Test connectivity first
echo "Testing connectivity to $HA_BASE_URL..."
if curl -s --connect-timeout 5 "$HA_BASE_URL" > /dev/null; then
    echo "✅ Can reach Home Assistant"
else
    echo "❌ Cannot reach Home Assistant"
    exit 1
fi

# Test data - using notify service
NOTIFICATION_DATA=$(cat <<EOF
{
  "message": "Test notification from Nuclei scanner",
  "title": "Test Alert"
}
EOF
)

# First, let's check what services are available
echo "Checking available notify services..."
SERVICES=$(curl -s -H "Authorization: Bearer $HA_TOKEN" "$HA_BASE_URL/api/services")
echo "$SERVICES" | jq '.[] | select(.domain=="notify") | .services' | head -50

# Check if the specific mobile app service exists
echo ""
echo "Checking for specific mobile app services..."
echo "$SERVICES" | jq -r '.[].services | keys[]' | grep -i mobile || echo "No mobile app services found"

# Use the correct mobile app service name
echo ""
echo "Testing notification with correct service name..."
echo "URL: $HA_BASE_URL/api/services/notify/mobile_app_ben_s_iphone_15"
echo "Token length: ${#HA_TOKEN}"
echo "Sending notification..."

RESPONSE=$(curl -s -w "\n%{http_code}" \
    --connect-timeout 5 \
    --max-time 10 \
    -X POST "$HA_BASE_URL/api/services/notify/mobile_app_ben_s_iphone_15" \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$NOTIFICATION_DATA")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

echo "HTTP Code: $HTTP_CODE"
echo "Response: $BODY"

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Notification sent successfully!"
else
    echo "❌ Failed to send notification"
fi