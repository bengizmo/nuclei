#!/bin/bash
# Test Home Assistant connection directly

echo "🏠 Testing Home Assistant Connection"
echo "================================="

# Read token from .env
HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
echo "Token loaded: ${HA_TOKEN:0:20}..."

# Test direct connection from local machine
echo ""
echo "Test 1: Direct connection from local machine"
RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $HA_TOKEN" \
  http://192.168.10.89:8123/api/)
echo "HTTP Response Code: $RESULT"

if [ "$RESULT" = "200" ]; then
    echo "✅ Direct connection successful"
    # Get some data
    curl -s -H "Authorization: Bearer $HA_TOKEN" \
      http://192.168.10.89:8123/api/states | jq '.[0:2] | .[] | .entity_id'
else
    echo "❌ Direct connection failed"
fi

# Test from NAS
echo ""
echo "Test 2: Connection from NAS"
./ssh-wrapper.sh "curl -s -o /dev/null -w '%{http_code}' \
  -H 'Authorization: Bearer $HA_TOKEN' \
  http://192.168.10.89:8123/api/"