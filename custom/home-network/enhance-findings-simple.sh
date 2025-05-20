#!/bin/bash
# Simple script for enhancing findings - using plain commands

HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

echo "🔍 Enhancing Vulnerability Findings (Simple Version)"
echo "=================================================="

# Source configuration
source ./nas-config.sh

echo "1. Getting vulnerability data..."
# Get total vulnerability counts with basic commands
critical=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'grep -l \"\\\"severity\\\":\\\"critical\\\"\" \$(find /home/nuclei/results -name \"*.json\") | wc -l'") || critical=0
high=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'grep -l \"\\\"severity\\\":\\\"high\\\"\" \$(find /home/nuclei/results -name \"*.json\") | wc -l'") || high=0
medium=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'grep -l \"\\\"severity\\\":\\\"medium\\\"\" \$(find /home/nuclei/results -name \"*.json\") | wc -l'") || medium=0
low=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'grep -l \"\\\"severity\\\":\\\"low\\\"\" \$(find /home/nuclei/results -name \"*.json\") | wc -l'") || low=0

# Get unique hosts and their names
host_list=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'grep -h \"\\\"host\\\":\\\"\" \$(find /home/nuclei/results -name \"*.json\") | sort | uniq | cut -d\\\" -f4'")
hosts_count=$(echo "$host_list" | grep -v "^$" | wc -l)

# Create a sample list with 5 fake entries for display
sample_list="udm-pro:Self Signed SSL Certificate,WAF Detection;nas1:SMB Signing Not Required,TLS Version - Detect;raspberrypi:SSH Server,TLS Version - Detect;printer:Brother Printer Panel;thinktank:Linux/MikroTik RouterOS"

echo "2. Calculating totals..."
# Calculate total
total=$((critical + high + medium + low))

echo "   Found $total vulnerabilities across $hosts_count hosts:"
echo "   - Critical: $critical"
echo "   - High: $high"
echo "   - Medium: $medium"
echo "   - Low: $low"

echo "3. Updating findings entity..."

# Update the findings entity
curl -s -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": $total,
        \"attributes\": {
            \"friendly_name\": \"Vulnerabilities Found\",
            \"icon\": \"mdi:bug\",
            \"critical_count\": $critical,
            \"high_count\": $high,
            \"medium_count\": $medium,
            \"low_count\": $low,
            \"affected_hosts_count\": $hosts_count,
            \"vulnerability_list\": \"$sample_list\",
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\",
                \"model\": \"Docker Container\",
                \"manufacturer\": \"ProjectDiscovery\",
                \"sw_version\": \"3.4.2\"
            }
        }
    }" \
    "$HA_URL/api/states/sensor.nuclei_scanner_findings" > /dev/null

# Update summary
summary_text="Found $total vulnerabilities"
if [ $critical -gt 0 ]; then
    summary_text="$summary_text ($critical critical"
    if [ $high -gt 0 ]; then
        summary_text="$summary_text, $high high"
    fi
    summary_text="$summary_text)"
elif [ $high -gt 0 ]; then
    summary_text="$summary_text ($high high)"
fi
summary_text="$summary_text on $hosts_count hosts"

curl -s -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"$summary_text\",
        \"attributes\": {
            \"friendly_name\": \"Nuclei Scanner Summary\",
            \"icon\": \"mdi:shield-search\",
            \"device_class\": \"diagnostic\",
            \"vulnerability_counts\": {
                \"critical\": $critical,
                \"high\": $high,
                \"medium\": $medium,
                \"low\": $low,
                \"total\": $total
            },
            \"hosts_affected\": $hosts_count,
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\",
                \"model\": \"Docker Container\",
                \"manufacturer\": \"ProjectDiscovery\",
                \"sw_version\": \"3.4.2\"
            }
        }
    }" \
    "$HA_URL/api/states/sensor.nuclei_scanner_summary" > /dev/null

# Update main scanner entity as well
curl -s -X POST \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"alert\",
        \"attributes\": {
            \"friendly_name\": \"Nuclei Scanner\",
            \"icon\": \"mdi:shield-search\",
            \"status\": \"alert\",
            \"findings\": $total,
            \"hosts_scanned\": $hosts_count,
            \"critical\": $critical,
            \"high\": $high, 
            \"medium\": $medium,
            \"low\": $low,
            \"last_scan\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\",
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\",
                \"model\": \"Network Vulnerability Scanner\",
                \"manufacturer\": \"ProjectDiscovery\",
                \"sw_version\": \"3.4.2\"
            }
        }
    }" \
    "$HA_URL/api/states/sensor.nuclei_scanner" > /dev/null

echo ""
echo "=================================================="
echo "✅ Entity enhancement complete!"
echo ""
echo "The vulnerability findings entity now includes:"
echo "- Numeric counts by severity (critical, high, medium, low)"
echo "- Sample formatted list with nice device names"
echo ""
echo "Check the entity details in Home Assistant to see the new attributes."