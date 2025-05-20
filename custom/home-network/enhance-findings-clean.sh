#!/bin/bash
# Clean script for enhancing findings with better formatting

HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

echo "🔍 Enhancing Vulnerability Findings with Clean Formatting"
echo "======================================================="

# Source configuration
source ./nas-config.sh

echo "1. Collecting vulnerability data..."
# Get total vulnerability counts
critical=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'find /home/nuclei/results -name \"*.json\" | xargs cat 2>/dev/null | grep -c \"\\\"severity\\\":\\\"critical\\\"\"'") || critical=0
high=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'find /home/nuclei/results -name \"*.json\" | xargs cat 2>/dev/null | grep -c \"\\\"severity\\\":\\\"high\\\"\"'") || high=0
medium=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'find /home/nuclei/results -name \"*.json\" | xargs cat 2>/dev/null | grep -c \"\\\"severity\\\":\\\"medium\\\"\"'") || medium=0
low=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'find /home/nuclei/results -name \"*.json\" | xargs cat 2>/dev/null | grep -c \"\\\"severity\\\":\\\"low\\\"\"'") || low=0

# Get unique hostnames and vulnerabilities
vuln_list=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'find /home/nuclei/results -name \"*.json\" | xargs cat 2>/dev/null | jq -r \"\\(.host):\\(.info.name)\" | sort | uniq'")

# Use discovery DB to resolve IP addresses to hostnames
hosts_db=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner cat /home/nuclei/discovery/discovery.db | grep -v '^#'")

echo "2. Processing vulnerability data..."
# Create a temporary file for hostname mappings
echo "$hosts_db" > /tmp/hosts.txt

# Process vulnerability list using IP to hostname mapping
formatted_list=""
current_host=""
host_vulns=""
hosts_count=0

while read -r line; do
    if [ -z "$line" ]; then
        continue
    fi
    
    ip=$(echo "$line" | cut -d':' -f1)
    vuln=$(echo "$line" | cut -d':' -f2-)
    
    # Extract base IP (remove port if present)
    base_ip=$(echo "$ip" | cut -d':' -f1)
    
    # Try to resolve hostname using the discovery database
    hostname=$(grep "^$base_ip|" /tmp/hosts.txt | cut -d'|' -f5)
    
    # If empty, use the device-IP format
    if [ -z "$hostname" ]; then
        last_octet=$(echo "$base_ip" | awk -F'.' '{print $4}')
        hostname="device-$last_octet"
    fi
    
    # If this is a new host, finish the previous host entry
    if [ "$hostname" != "$current_host" ]; then
        if [ -n "$current_host" ] && [ -n "$host_vulns" ]; then
            if [ -n "$formatted_list" ]; then
                formatted_list="$formatted_list;$current_host:$host_vulns"
            else
                formatted_list="$current_host:$host_vulns"
            fi
        fi
        
        # Reset for new host
        current_host="$hostname"
        host_vulns=""
        hosts_count=$((hosts_count + 1))
    fi
    
    # Add vulnerability to current host's list
    if [ -n "$host_vulns" ]; then
        host_vulns="$host_vulns,$vuln"
    else
        host_vulns="$vuln"
    fi
done <<< "$vuln_list"

# Add the last host if there is one
if [ -n "$current_host" ] && [ -n "$host_vulns" ]; then
    if [ -n "$formatted_list" ]; then
        formatted_list="$formatted_list;$current_host:$host_vulns"
    else
        formatted_list="$current_host:$host_vulns"
    fi
fi

# Calculate total
total=$((critical + high + medium + low))

echo "   Found $total vulnerabilities across $hosts_count hosts:"
echo "   - Critical: $critical"
echo "   - High: $high"
echo "   - Medium: $medium"
echo "   - Low: $low"

echo "3. Updating the findings entity..."

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
            \"vulnerability_list\": \"$formatted_list\",
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

# Create a better summary
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

# Update the summary entity
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

# Clean up temporary files
rm -f /tmp/hosts.txt

echo ""
echo "======================================================="
echo "✅ Entity enhancement complete!"
echo ""
echo "The vulnerability findings entity now includes:"
echo "- Numeric counts by severity (critical, high, medium, low)"
echo "- Formatted list: hostname1:vuln1,vuln2;hostname2:vuln3,vuln4"
echo ""
echo "Check the entity details in Home Assistant to see the new attributes."