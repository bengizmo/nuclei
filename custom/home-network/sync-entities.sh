#!/bin/bash
# Script to sync the main scanner entity with the findings entity

HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

echo "🔄 Synchronizing Nuclei Entities"
echo "==============================="

echo "1. Getting current findings data..."
findings_data=$(curl -s -H "Authorization: Bearer $HA_TOKEN" "$HA_URL/api/states/sensor.nuclei_scanner_findings")

# Extract values
findings_count=$(echo "$findings_data" | jq -r '.state')
affected_hosts_count=$(echo "$findings_data" | jq -r '.attributes.affected_hosts_count')
critical_count=$(echo "$findings_data" | jq -r '.attributes.critical_count')
high_count=$(echo "$findings_data" | jq -r '.attributes.high_count')
medium_count=$(echo "$findings_data" | jq -r '.attributes.medium_count')
low_count=$(echo "$findings_data" | jq -r '.attributes.low_count')

echo "2. Getting current timestamp..."
last_scan=$(curl -s -H "Authorization: Bearer $HA_TOKEN" "$HA_URL/api/states/sensor.nuclei_scanner_last_scan" | jq -r '.state')

echo "3. Synchronizing main scanner entity..."
# Determine status based on findings
if [ "$findings_count" -gt 0 ]; then
    status="alert"
else
    status="idle"
fi

# Update the main entity with the latest findings
curl -s -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"$status\",
        \"attributes\": {
            \"friendly_name\": \"Nuclei Scanner\",
            \"icon\": \"mdi:shield-search\",
            \"status\": \"$status\",
            \"findings\": $findings_count,
            \"hosts_scanned\": $affected_hosts_count,
            \"critical\": $critical_count,
            \"high\": $high_count, 
            \"medium\": $medium_count,
            \"low\": $low_count,
            \"last_scan\": \"$last_scan\",
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\",
                \"model\": \"Network Vulnerability Scanner\",
                \"manufacturer\": \"ProjectDiscovery\",
                \"sw_version\": \"3.4.2\",
                \"configuration_url\": \"http://192.168.10.163:9090\"
            }
        }
    }" \
    "$HA_URL/api/states/sensor.nuclei_scanner" > /dev/null

# Update the hosts entity for consistency
curl -s -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"$affected_hosts_count\",
        \"attributes\": {
            \"friendly_name\": \"Hosts Scanned\",
            \"icon\": \"mdi:server-network\",
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\",
                \"model\": \"Network Vulnerability Scanner\",
                \"manufacturer\": \"ProjectDiscovery\",
                \"sw_version\": \"3.4.2\"
            }
        }
    }" \
    "$HA_URL/api/states/sensor.nuclei_scanner_hosts" > /dev/null

echo ""
echo "==============================="
echo "✅ Entities synchronized!"
echo ""
echo "Main scanner entity now shows:"
echo "- Status: $status"
echo "- Findings: $findings_count"
echo "- Hosts scanned: $affected_hosts_count"
echo "- Vulnerabilities by severity: $critical_count critical, $high_count high, $medium_count medium, $low_count low"
echo "- Last scan: $last_scan"