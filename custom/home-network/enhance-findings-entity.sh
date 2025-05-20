#!/bin/bash
# Script to enhance the vulnerability findings entity with detailed information

HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

echo "🔍 Enhancing Vulnerability Findings Entity"
echo "========================================="

# Source configuration
source ./nas-config.sh

echo "1. Gathering vulnerability data from container..."

# Get vulnerability details
vulns_data=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'find /home/nuclei/results -name \"*.json\" | xargs cat 2>/dev/null | jq -r \"[{host: .host, name: .info.name, severity: .info.severity}]\" 2>/dev/null' | grep -v null")

echo "2. Processing vulnerability data..."

# Create lists by severity
critical_vulns=$(echo "$vulns_data" | grep -i "critical" | awk -F'"' '{print $4 " (" $8 ")"}' | sort | uniq)
high_vulns=$(echo "$vulns_data" | grep -i "high" | awk -F'"' '{print $4 " (" $8 ")"}' | sort | uniq)
medium_vulns=$(echo "$vulns_data" | grep -i "medium" | awk -F'"' '{print $4 " (" $8 ")"}' | sort | uniq)
low_vulns=$(echo "$vulns_data" | grep -i "low" | awk -F'"' '{print $4 " (" $8 ")"}' | sort | uniq)

# Prepare JSON arrays
critical_json=""
for vuln in $critical_vulns; do
    if [ -n "$critical_json" ]; then
        critical_json="$critical_json, \"$vuln\""
    else
        critical_json="\"$vuln\""
    fi
done

high_json=""
for vuln in $high_vulns; do
    if [ -n "$high_json" ]; then
        high_json="$high_json, \"$vuln\""
    else
        high_json="\"$vuln\""
    fi
done

medium_json=""
for vuln in $medium_vulns; do
    if [ -n "$medium_json" ]; then
        medium_json="$medium_json, \"$vuln\""
    else
        medium_json="\"$vuln\""
    fi
done

low_json=""
for vuln in $low_vulns; do
    if [ -n "$low_json" ]; then
        low_json="$low_json, \"$vuln\""
    else
        low_json="\"$vuln\""
    fi
done

# Get list of affected hosts
affected_hosts=$(echo "$vulns_data" | awk -F'"' '{print $4}' | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort | uniq)
hosts_json=""
for host in $affected_hosts; do
    if [ -n "$hosts_json" ]; then
        hosts_json="$hosts_json, \"$host\""
    else
        hosts_json="\"$host\""
    fi
done

# Count vulnerabilities by severity
critical_count=$(echo "$critical_vulns" | grep -v "^$" | wc -l)
high_count=$(echo "$high_vulns" | grep -v "^$" | wc -l)
medium_count=$(echo "$medium_vulns" | grep -v "^$" | wc -l)
low_count=$(echo "$low_vulns" | grep -v "^$" | wc -l)
total_count=$((critical_count + high_count + medium_count + low_count))
hosts_count=$(echo "$affected_hosts" | grep -v "^$" | wc -l)

echo "   Found $total_count vulnerabilities across $hosts_count hosts:"
echo "   - Critical: $critical_count"
echo "   - High: $high_count"
echo "   - Medium: $medium_count"
echo "   - Low: $low_count"

echo "3. Updating the findings entity..."

# Create JSON for entity update
json_data=$(cat <<EOF
{
    "state": "${total_count}",
    "attributes": {
        "friendly_name": "Vulnerabilities Found",
        "icon": "mdi:bug",
        "critical_count": ${critical_count},
        "high_count": ${high_count},
        "medium_count": ${medium_count},
        "low_count": ${low_count},
        "affected_hosts_count": ${hosts_count},
        "critical_vulnerabilities": [${critical_json}],
        "high_vulnerabilities": [${high_json}],
        "medium_vulnerabilities": [${medium_json}],
        "low_vulnerabilities": [${low_json}],
        "affected_hosts": [${hosts_json}],
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
    "${HA_URL}/api/states/sensor.nuclei_scanner_findings"

# Also update the summary entity with more detailed information
summary="Found ${total_count} vulnerabilities (${critical_count} critical, ${high_count} high) on ${hosts_count} hosts"

curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"${summary}\",
        \"attributes\": {
            \"friendly_name\": \"Nuclei Scanner Summary\",
            \"icon\": \"mdi:shield-search\",
            \"device_class\": \"diagnostic\",
            \"device\": {
                \"identifiers\": [\"nuclei_scanner_001\"],
                \"name\": \"Nuclei Scanner\",
                \"model\": \"Docker Container\",
                \"manufacturer\": \"ProjectDiscovery\",
                \"sw_version\": \"3.4.2\"
            }
        }
    }" \
    "${HA_URL}/api/states/sensor.nuclei_scanner_summary"

echo ""
echo "========================================="
echo "✅ Entity enhancement complete!"
echo ""
echo "The vulnerability findings entity now includes:"
echo "- Counts by severity (critical, high, medium, low)"
echo "- Lists of vulnerabilities by severity"
echo "- List of affected hosts"
echo ""
echo "Check the entity details in Home Assistant to see the new attributes."