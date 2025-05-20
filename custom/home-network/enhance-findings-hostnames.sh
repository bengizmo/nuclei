#!/bin/bash
# Enhanced script for vulnerability findings with hostname resolution and better formatting

HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

echo "🔍 Enhancing Vulnerability Findings with Hostnames and Grouping"
echo "=============================================================="

# Source configuration
source ./nas-config.sh

echo "1. Gathering vulnerability data from container..."

# Create a temporary file to store the raw vulnerability data
TMP_VULNS=$(mktemp)

# Extract vulnerability data in a processable format
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'find /home/nuclei/results -name \"*.json\" | xargs cat 2>/dev/null | jq -c \"{host: .host, name: .info.name, severity: .info.severity}\"'" > "$TMP_VULNS"

echo "2. Collecting hostname information..."

# Create temporary files for host processing
TMP_HOSTS=$(mktemp)
TMP_RESOLVED=$(mktemp)

# Extract all unique hosts from vulnerability data
cat "$TMP_VULNS" | grep -o '"host":"[^"]*"' | cut -d'"' -f4 | sort | uniq > "$TMP_HOSTS"

# Create a lookup table for hostname resolution
echo "   Resolving hostnames from discovery database..."
${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner grep -v '^#' /home/nuclei/discovery/discovery.db" > "$TMP_RESOLVED"

echo "3. Processing vulnerability data..."

# Initialize count variables
critical_count=0
high_count=0
medium_count=0
low_count=0
total_hosts=0

# Map IP to hostname using discovery database
declare -A HOST_MAP
while IFS='|' read -r ip mac first_seen last_seen hostname os services status; do
    # If hostname is empty, use a generic name with the last octet of IP
    if [ -z "$hostname" ]; then
        last_octet=$(echo "$ip" | awk -F'.' '{print $4}')
        hostname="device-$last_octet"
    fi
    # Store in associative array
    HOST_MAP["$ip"]="$hostname"
done < "$TMP_RESOLVED"

# Process vulnerability data and group by host and severity
declare -A HOST_VULNS
declare -A SEVERITY_COUNTS

# Process each vulnerability
while read -r vuln_json; do
    if [ -n "$vuln_json" ]; then
        host=$(echo "$vuln_json" | grep -o '"host":"[^"]*"' | cut -d'"' -f4)
        name=$(echo "$vuln_json" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
        severity=$(echo "$vuln_json" | grep -o '"severity":"[^"]*"' | cut -d'"' -f4)
        
        # Skip if any value is empty
        if [ -z "$host" ] || [ -z "$name" ] || [ -z "$severity" ]; then
            continue
        fi
        
        # Strip port if present
        base_host=$(echo "$host" | cut -d':' -f1)
        
        # Get hostname from map, or use IP if not found
        if [ -n "${HOST_MAP[$base_host]}" ]; then
            hostname="${HOST_MAP[$base_host]}"
        else
            hostname="$base_host"
        fi
        
        # Add to host vulnerabilities map
        if [ -n "${HOST_VULNS[$hostname]}" ]; then
            # Check if this vulnerability is already listed for this host
            if ! echo "${HOST_VULNS[$hostname]}" | grep -q "$name"; then
                HOST_VULNS[$hostname]="${HOST_VULNS[$hostname]},$name"
            fi
        else
            HOST_VULNS[$hostname]="$name"
            total_hosts=$((total_hosts + 1))
        fi
        
        # Count by severity
        case "$severity" in
            critical) critical_count=$((critical_count + 1)) ;;
            high)     high_count=$((high_count + 1)) ;;
            medium)   medium_count=$((medium_count + 1)) ;;
            low)      low_count=$((low_count + 1)) ;;
        esac
    fi
done < "$TMP_VULNS"

# Calculate total
total_vulns=$((critical_count + high_count + medium_count + low_count))

echo "   Found $total_vulns vulnerabilities across $total_hosts hosts:"
echo "   - Critical: $critical_count"
echo "   - High: $high_count"
echo "   - Medium: $medium_count"
echo "   - Low: $low_count"

# Format the grouped vulnerability list
formatted_list=""
separator=""
for hostname in "${!HOST_VULNS[@]}"; do
    vulns="${HOST_VULNS[$hostname]}"
    formatted_list="${formatted_list}${separator}${hostname}:${vulns}"
    separator=";"
done

echo "4. Updating the findings entity..."

# Create JSON data with the formatted list
json_data=$(cat <<EOF
{
    "state": "${total_vulns}",
    "attributes": {
        "friendly_name": "Vulnerabilities Found",
        "icon": "mdi:bug",
        "critical_count": ${critical_count},
        "high_count": ${high_count},
        "medium_count": ${medium_count},
        "low_count": ${low_count},
        "affected_hosts_count": ${total_hosts},
        "vulnerability_list": "${formatted_list}",
        "device": {
            "identifiers": ["nuclei_scanner_001"],
            "name": "Nuclei Scanner",
            "model": "Docker Container",
            "manufacturer": "ProjectDiscovery",
            "sw_version": "3.4.2"
        }
    }
}
EOF
)

# Update the entity
curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${json_data}" \
    "${HA_URL}/api/states/sensor.nuclei_scanner_findings" > /dev/null

# Create a better summary with hostname information
summary_text="Found ${total_vulns} vulnerabilities"
if [ $critical_count -gt 0 ]; then
    summary_text="${summary_text} (${critical_count} critical"
    if [ $high_count -gt 0 ]; then
        summary_text="${summary_text}, ${high_count} high"
    fi
    summary_text="${summary_text})"
elif [ $high_count -gt 0 ]; then
    summary_text="${summary_text} (${high_count} high)"
fi
summary_text="${summary_text} on ${total_hosts} hosts"

# Update the summary entity
curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"${summary_text}\",
        \"attributes\": {
            \"friendly_name\": \"Nuclei Scanner Summary\",
            \"icon\": \"mdi:shield-search\",
            \"device_class\": \"diagnostic\",
            \"vulnerability_counts\": {
                \"critical\": ${critical_count},
                \"high\": ${high_count},
                \"medium\": ${medium_count},
                \"low\": ${low_count},
                \"total\": ${total_vulns}
            },
            \"hosts_affected\": ${total_hosts},
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\",
                \"model\": \"Docker Container\",
                \"manufacturer\": \"ProjectDiscovery\",
                \"sw_version\": \"3.4.2\"
            }
        }
    }" \
    "${HA_URL}/api/states/sensor.nuclei_scanner_summary" > /dev/null

# Also update the main scanner entity for consistency
curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"alert\",
        \"attributes\": {
            \"friendly_name\": \"Nuclei Scanner\",
            \"icon\": \"mdi:shield-search\",
            \"status\": \"alert\",
            \"findings\": ${total_vulns},
            \"hosts_scanned\": ${total_hosts},
            \"critical\": ${critical_count},
            \"high\": ${high_count}, 
            \"medium\": ${medium_count},
            \"low\": ${low_count},
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
    "${HA_URL}/api/states/sensor.nuclei_scanner" > /dev/null

# Clean up temporary files
rm -f "$TMP_VULNS" "$TMP_HOSTS" "$TMP_RESOLVED"

echo ""
echo "=============================================================="
echo "✅ Entity enhancement complete!"
echo ""
echo "The vulnerability findings entity now includes:"
echo "- Counts by severity (critical, high, medium, low)"
echo "- Formatted list with hostname:[vuln1],[vuln2];hostname2:[vuln3]"
echo ""
echo "Check the entity details in Home Assistant to see the new attributes."