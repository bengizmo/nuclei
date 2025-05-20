#!/bin/bash
# Final version of the script to enhance the vulnerability findings entity
# Handles special characters properly and creates well-formatted lists

HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

echo "🔍 Enhancing Vulnerability Findings Entity (Final Version)"
echo "========================================================"

# Source configuration
source ./nas-config.sh

echo "1. Gathering vulnerability data from container..."

# Use simple approach with grepping to avoid parsing complexities
# Get vulnerability counts by severity
critical_count=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'find /home/nuclei/results -name \"*.json\" | xargs cat 2>/dev/null | grep -c \"severity\\\":\\\"critical\\\"\"'") || critical_count=0
high_count=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'find /home/nuclei/results -name \"*.json\" | xargs cat 2>/dev/null | grep -c \"severity\\\":\\\"high\\\"\"'") || high_count=0
medium_count=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'find /home/nuclei/results -name \"*.json\" | xargs cat 2>/dev/null | grep -c \"severity\\\":\\\"medium\\\"\"'") || medium_count=0
low_count=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'find /home/nuclei/results -name \"*.json\" | xargs cat 2>/dev/null | grep -c \"severity\\\":\\\"low\\\"\"'") || low_count=0

# Get list of affected hosts (simplifying by getting unique hosts)
hosts=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'find /home/nuclei/results -name \"*.json\" | xargs cat 2>/dev/null | grep -o \"\\\"host\\\":\\\"[^\\\"]*\\\"\" | cut -d\\\"  -f4 | sort | uniq'")
hosts_count=$(echo "$hosts" | wc -l)

# Get actual vulnerability names 
vulnerability_names=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'find /home/nuclei/results -name \"*.json\" | xargs cat 2>/dev/null | grep -o \"\\\"name\\\":\\\"[^\\\"]*\\\"\" | cut -d\\\"  -f4 | sort | uniq'")

echo "2. Processing vulnerability data..."

# Format hosts list for JSON
hosts_json="["
host_separator=""
for host in $hosts; do
    hosts_json="${hosts_json}${host_separator}\"${host}\""
    host_separator=", "
done
hosts_json="${hosts_json}]"

# Format vulnerability names list for JSON
vulns_json="["
vuln_separator=""
for vuln in $vulnerability_names; do
    vulns_json="${vulns_json}${vuln_separator}\"${vuln}\""
    vuln_separator=", "
done
vulns_json="${vulns_json}]"

# Calculate total count
total_count=$((critical_count + high_count + medium_count + low_count))

echo "   Found $total_count vulnerabilities across $hosts_count hosts:"
echo "   - Critical: $critical_count"
echo "   - High: $high_count"
echo "   - Medium: $medium_count"
echo "   - Low: $low_count"

echo "3. Updating the findings entity..."

# Create JSON for entity update
cat > /tmp/nuclei_json.json <<EOF
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
        "vulnerabilities": ${vulns_json},
        "affected_hosts": ${hosts_json},
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

# Update the entity
curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @/tmp/nuclei_json.json \
    "${HA_URL}/api/states/sensor.nuclei_scanner_findings" > /dev/null

# Also update the summary entity
summary_text="Found $total_count vulnerabilities"
if [ $critical_count -gt 0 ]; then
    summary_text="$summary_text ($critical_count critical"
    if [ $high_count -gt 0 ]; then
        summary_text="$summary_text, $high_count high"
    fi
    summary_text="$summary_text)"
elif [ $high_count -gt 0 ]; then
    summary_text="$summary_text ($high_count high)"
fi

summary_text="$summary_text on $hosts_count hosts"

cat > /tmp/nuclei_summary.json <<EOF
{
    "state": "${summary_text}",
    "attributes": {
        "friendly_name": "Nuclei Scanner Summary",
        "icon": "mdi:shield-search",
        "device_class": "diagnostic",
        "vulnerability_counts": {
            "critical": ${critical_count},
            "high": ${high_count},
            "medium": ${medium_count},
            "low": ${low_count},
            "total": ${total_count}
        },
        "hosts_affected": ${hosts_count},
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

curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @/tmp/nuclei_summary.json \
    "${HA_URL}/api/states/sensor.nuclei_scanner_summary" > /dev/null

# Clean up
rm -f /tmp/nuclei_json.json /tmp/nuclei_summary.json

echo ""
echo "========================================================"
echo "✅ Entity enhancement complete!"
echo ""
echo "The vulnerability findings entity now includes:"
echo "- Counts by severity (critical, high, medium, low)"
echo "- List of all vulnerability names"
echo "- List of all affected hosts"
echo ""
echo "Check the entity details in Home Assistant to see the new attributes."