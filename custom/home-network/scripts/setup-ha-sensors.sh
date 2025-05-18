#!/bin/sh
# Setup proper sensor entities in Home Assistant for Nuclei Scanner

HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"

echo "Setting up Nuclei Scanner sensors in Home Assistant..."

# Create the Nuclei Scanner device and sensors using the webhook approach
# This creates a device with associated sensors

WEBHOOK_ID="nuclei_scanner_webhook"
DEVICE_ID="nuclei_scanner_001"

# Register the webhook
echo "Creating webhook..."
curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"webhook_id\": \"${WEBHOOK_ID}\",
        \"name\": \"Nuclei Scanner\",
        \"icon\": \"mdi:shield-search\",
        \"device\": {
            \"identifiers\": [\"${DEVICE_ID}\"],
            \"name\": \"Nuclei Scanner\",
            \"model\": \"Docker Container\",
            \"manufacturer\": \"ProjectDiscovery\",
            \"sw_version\": \"3.4.2\"
        }
    }" \
    "${HA_BASE_URL}/api/webhook/${WEBHOOK_ID}"

echo "Webhook created. You can now update sensors using the webhook."
echo "Webhook URL: ${HA_BASE_URL}/api/webhook/${WEBHOOK_ID}"