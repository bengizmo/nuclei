#!/bin/bash
# Enhanced script to improve the vulnerability findings entity with better formatting

HA_TOKEN=$(grep "HOME_ASSISTANT_API_TOKEN=" .env | cut -d'=' -f2)
HA_URL="http://192.168.10.89:8123"

echo "🔍 Enhancing Vulnerability Findings Entity (Improved)"
echo "==================================================="

# Source configuration
source ./nas-config.sh

echo "1. Gathering detailed vulnerability data from container..."

# Get raw vulnerability JSON for processing
vuln_json=$(${NAS_SSH} "${DOCKER_BIN} exec nuclei-scanner sh -c 'find /home/nuclei/results -path \"*/vulnerabilities/*.json\" -type f | xargs cat 2>/dev/null'")

# Save to a temporary file for processing
TEMP_FILE=$(mktemp)
echo "$vuln_json" > "$TEMP_FILE"

echo "2. Processing vulnerability data..."

# Extract and format vulnerability information
VULN_LIST=""
CRITICAL_LIST=""
HIGH_LIST=""
MEDIUM_LIST=""
LOW_LIST=""
HOST_LIST=""

# Process vulnerability data with proper formatting
process_vulns() {
    local json_data="$1"
    local severity="$2"
    local list_var="$3"
    
    while read -r line; do
        if [ -n "$line" ]; then
            host=$(echo "$line" | jq -r '.host')
            name=$(echo "$line" | jq -r '.info.name')
            
            # Skip if either is null or empty
            if [ "$host" = "null" ] || [ "$name" = "null" ] || [ -z "$host" ] || [ -z "$name" ]; then
                continue
            fi
            
            # Add to the corresponding list
            if [ -n "${!list_var}" ]; then
                # Use eval to update the variable indirectly
                eval "$list_var=\"${!list_var},\\\"$name ($host)\\\"\""
            else
                eval "$list_var=\"\\\"$name ($host)\\\"\""
            fi
            
            # Add to overall list
            if [ -n "$VULN_LIST" ]; then
                VULN_LIST="$VULN_LIST,\"$severity: $name ($host)\""
            else
                VULN_LIST="\"$severity: $name ($host)\""
            fi
            
            # Add to host list if not already included
            if ! echo "$HOST_LIST" | grep -q "\"$host\""; then
                if [ -n "$HOST_LIST" ]; then
                    HOST_LIST="$HOST_LIST,\"$host\""
                else
                    HOST_LIST="\"$host\""
                fi
            fi
        fi
    done < <(echo "$json_data" | jq -c "select(.info.severity == \"$severity\")")
}

# Process vulnerabilities by severity
process_vulns "$vuln_json" "critical" "CRITICAL_LIST"
process_vulns "$vuln_json" "high" "HIGH_LIST"
process_vulns "$vuln_json" "medium" "MEDIUM_LIST"
process_vulns "$vuln_json" "low" "LOW_LIST"

# Count vulnerabilities by severity
critical_count=$(echo "$CRITICAL_LIST" | tr ',' '\n' | grep -v "^$" | wc -l)
high_count=$(echo "$HIGH_LIST" | tr ',' '\n' | grep -v "^$" | wc -l)
medium_count=$(echo "$MEDIUM_LIST" | tr ',' '\n' | grep -v "^$" | wc -l)
low_count=$(echo "$LOW_LIST" | tr ',' '\n' | grep -v "^$" | wc -l)
total_count=$((critical_count + high_count + medium_count + low_count))
hosts_count=$(echo "$HOST_LIST" | tr ',' '\n' | grep -v "^$" | wc -l)

echo "   Found $total_count vulnerabilities across $hosts_count hosts:"
echo "   - Critical: $critical_count"
echo "   - High: $high_count"
echo "   - Medium: $medium_count"
echo "   - Low: $low_count"

# Create lists with default values if empty
if [ -z "$CRITICAL_LIST" ]; then CRITICAL_LIST="\"None\""; fi
if [ -z "$HIGH_LIST" ]; then HIGH_LIST="\"None\""; fi
if [ -z "$MEDIUM_LIST" ]; then MEDIUM_LIST="\"None\""; fi
if [ -z "$LOW_LIST" ]; then LOW_LIST="\"None\""; fi
if [ -z "$HOST_LIST" ]; then HOST_LIST="\"None\""; fi
if [ -z "$VULN_LIST" ]; then VULN_LIST="\"None\""; fi

echo "3. Updating the findings entity..."

# Create JSON data for entity update
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
        "vulnerabilities": [${VULN_LIST}],
        "critical_vulnerabilities": [${CRITICAL_LIST}],
        "high_vulnerabilities": [${HIGH_LIST}],
        "medium_vulnerabilities": [${MEDIUM_LIST}],
        "low_vulnerabilities": [${LOW_LIST}],
        "affected_hosts": [${HOST_LIST}],
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

# Also update the summary entity with more detailed information
severity_text=""
if [ $critical_count -gt 0 ]; then
    severity_text="$critical_count critical"
    if [ $high_count -gt 0 ]; then
        severity_text="$severity_text, $high_count high"
    fi
elif [ $high_count -gt 0 ]; then
    severity_text="$high_count high"
fi

if [ -z "$severity_text" ] && [ $medium_count -gt 0 ]; then
    severity_text="$medium_count medium"
elif [ -n "$severity_text" ] && [ $medium_count -gt 0 ]; then
    severity_text="$severity_text, $medium_count medium"
fi

if [ -z "$severity_text" ] && [ $low_count -gt 0 ]; then
    severity_text="$low_count low"
elif [ -n "$severity_text" ] && [ $low_count -gt 0 ]; then
    severity_text="$severity_text, $low_count low"
fi

if [ -z "$severity_text" ]; then
    severity_text="0 total"
fi

summary="Found $total_count vulnerabilities ($severity_text) on $hosts_count hosts"

curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"state\": \"${summary}\",
        \"attributes\": {
            \"friendly_name\": \"Nuclei Scanner Summary\",
            \"icon\": \"mdi:shield-search\",
            \"device_class\": \"diagnostic\",
            \"vulnerability_counts\": {
                \"critical\": ${critical_count},
                \"high\": ${high_count},
                \"medium\": ${medium_count},
                \"low\": ${low_count},
                \"total\": ${total_count}
            },
            \"hosts_affected\": ${hosts_count},
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

# Clean up
rm -f "$TEMP_FILE"

echo ""
echo "==================================================="
echo "✅ Entity enhancement complete!"
echo ""
echo "The vulnerability findings entity now includes:"
echo "- Counts by severity (critical, high, medium, low)"
echo "- Lists of vulnerabilities by severity with host information"
echo "- Complete list of affected hosts"
echo "- Combined list of all vulnerabilities"
echo ""
echo "The summary entity has also been updated with detailed counts"
echo ""
echo "Check the entity details in Home Assistant to see the new attributes."