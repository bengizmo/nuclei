#!/bin/bash
# Simplified script for enhancing findings with hostname resolution
# Compatible with basic shell implementations

HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

echo "🔍 Enhancing Vulnerability Findings with Hostnames (Compatible)"
echo "============================================================="

# Source configuration
source ./nas-config.sh

echo "1. Gathering vulnerability data from container..."

# Simplify approach: get the JSON data and parse locally
vuln_data=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner find /home/nuclei/results -name \"*.json\" | xargs cat 2>/dev/null")

# Write to temp file for processing
echo "$vuln_data" > /tmp/vuln_data.json

# Get host resolution data
host_data=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner cat /home/nuclei/discovery/discovery.db 2>/dev/null | grep -v '^#'")
echo "$host_data" > /tmp/host_data.txt

echo "2. Processing data locally..."

# Process vulnerability data with simple text processing
# Extract hosts and vulnerability names
hosts=$(cat /tmp/vuln_data.json | grep -o '"host":"[^"]*"' | cut -d'"' -f4 | sort | uniq)
vuln_names=$(cat /tmp/vuln_data.json | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | sort | uniq)

# Count vulnerabilities by severity
critical_count=$(cat /tmp/vuln_data.json | grep -c '"severity":"critical"')
high_count=$(cat /tmp/vuln_data.json | grep -c '"severity":"high"')
medium_count=$(cat /tmp/vuln_data.json | grep -c '"severity":"medium"')
low_count=$(cat /tmp/vuln_data.json | grep -c '"severity":"low"')
total_count=$((critical_count + high_count + medium_count + low_count))

# Count unique hosts
host_count=$(echo "$hosts" | wc -l)

echo "   Found $total_count vulnerabilities across $host_count hosts:"
echo "   - Critical: $critical_count"
echo "   - High: $high_count"
echo "   - Medium: $medium_count"
echo "   - Low: $low_count"

# Format the list using simple processing
formatted_list=""

for host in $hosts; do
    # Extract base host (remove port if present)
    base_host=$(echo "$host" | cut -d':' -f1)
    
    # Try to find hostname from discovery data
    hostname=$(grep "^$base_host|" /tmp/host_data.txt | cut -d'|' -f5)
    
    # If hostname is empty, use a simple identifier
    if [ -z "$hostname" ]; then
        last_octet=$(echo "$base_host" | awk -F. '{print $4}')
        hostname="device-$last_octet"
    fi
    
    # Get vulnerabilities for this host
    host_vulns=""
    for vuln_line in $(cat /tmp/vuln_data.json | grep -F "\"host\":\"$host\""); do
        vuln_name=$(echo "$vuln_line" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$vuln_name" ]; then
            if [ -z "$host_vulns" ]; then
                host_vulns="$vuln_name"
            else
                # Check if this vulnerability is already in the list
                if ! echo "$host_vulns" | grep -q "$vuln_name"; then
                    host_vulns="$host_vulns,$vuln_name"
                fi
            fi
        fi
    done
    
    # Add to formatted list
    if [ -n "$host_vulns" ]; then
        if [ -n "$formatted_list" ]; then
            formatted_list="$formatted_list;$hostname:$host_vulns"
        else
            formatted_list="$hostname:$host_vulns"
        fi
    fi
done

echo "3. Updating the findings entity..."

# Prepare JSON data
cat > /tmp/findings_data.json <<EOF
{
    "state": "${total_count}",
    "attributes": {
        "friendly_name": "Vulnerabilities Found",
        "icon": "mdi:bug",
        "critical_count": ${critical_count},
        "high_count": ${high_count},
        "medium_count": ${medium_count},
        "low_count": ${low_count},
        "affected_hosts_count": ${host_count},
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

# Update the entity
curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @/tmp/findings_data.json \
    "${HA_URL}/api/states/sensor.nuclei_scanner_findings" > /dev/null

# Create a better summary
summary_text="Found ${total_count} vulnerabilities"
if [ $critical_count -gt 0 ]; then
    summary_text="${summary_text} (${critical_count} critical"
    if [ $high_count -gt 0 ]; then
        summary_text="${summary_text}, ${high_count} high"
    fi
    summary_text="${summary_text})"
elif [ $high_count -gt 0 ]; then
    summary_text="${summary_text} (${high_count} high)"
fi
summary_text="${summary_text} on ${host_count} hosts"

# Update the summary entity
cat > /tmp/summary_data.json <<EOF
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
        "hosts_affected": ${host_count},
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
    -d @/tmp/summary_data.json \
    "${HA_URL}/api/states/sensor.nuclei_scanner_summary" > /dev/null

# Clean up temporary files
rm -f /tmp/vuln_data.json /tmp/host_data.txt /tmp/findings_data.json /tmp/summary_data.json

echo ""
echo "============================================================="
echo "✅ Entity enhancement complete!"
echo ""
echo "The vulnerability findings entity now includes:"
echo "- Counts by severity (critical, high, medium, low)"
echo "- Formatted list with hostname:[vuln1],[vuln2];hostname2:[vuln3]"
echo ""
echo "Check the entity details in Home Assistant to see the new attributes."