#!/bin/bash
# Enhanced scan script that updates all 6 Home Assistant entities

echo "🔍 Running Nuclei scan with multi-entity Home Assistant integration"
echo "=================================================================="

# Configuration
export RESULTS_DIR="/home/nuclei/results/$(date +'%Y%m%d-%H%M%S')"
CRITICAL_HOSTS_FILE="/home/nuclei/critical-hosts.txt"
HA_BASE_URL="http://192.168.10.89:8123"
HA_TOKEN="${HOME_ASSISTANT_API_TOKEN}"

# Create results directory
mkdir -p "${RESULTS_DIR}"

# Update HA to show we're scanning
/home/nuclei/scripts/ha-sensor-update.sh "scanning" "0" "0" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"

echo "Scanning hosts from: ${CRITICAL_HOSTS_FILE}"
echo "Results will be saved to: ${RESULTS_DIR}"

# Count hosts for progress tracking
HOST_COUNT=$(grep -v "^#" "${CRITICAL_HOSTS_FILE}" | wc -l)
echo "Found ${HOST_COUNT} hosts to scan..."

# Initialize counters
FINDINGS_COUNT=0
HOSTS_SCANNED=0

# Scan each host
while read -r target; do
    # Skip comments and empty lines
    if [[ "$target" == \#* ]] || [[ -z "$target" ]]; then
        continue
    fi
    
    # Extract hostname/IP and description if available
    host_info=(${target//,/ })
    host="${host_info[0]}"
    
    echo "Scanning host: ${host}"
    nuclei -u "${host}" -o "${RESULTS_DIR}/${host}.txt" -j "${RESULTS_DIR}/${host}.json" -silent
    
    # Count vulnerabilities
    if [ -f "${RESULTS_DIR}/${host}.json" ]; then
        vuln_count=$(cat "${RESULTS_DIR}/${host}.json" | wc -l)
        FINDINGS_COUNT=$((FINDINGS_COUNT + vuln_count))
    fi
    
    HOSTS_SCANNED=$((HOSTS_SCANNED + 1))
    
    # Update Home Assistant with progress
    /home/nuclei/scripts/ha-sensor-update.sh "scanning" "${FINDINGS_COUNT}" "${HOSTS_SCANNED}" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"
done < "${CRITICAL_HOSTS_FILE}"

# Create symlink to latest results
ln -sfn "${RESULTS_DIR}" /home/nuclei/results/latest

# Generate AI summary if helper script exists
if [ -x "/home/nuclei/scripts/generate-ai-summary.sh" ]; then
    /home/nuclei/scripts/generate-ai-summary.sh "${RESULTS_DIR}"
fi

# Set final status based on findings
if [ "${FINDINGS_COUNT}" -gt 0 ]; then
    STATUS="alert"
else
    STATUS="idle"
fi

# Update Home Assistant with final results
/home/nuclei/scripts/ha-sensor-update.sh "${STATUS}" "${FINDINGS_COUNT}" "${HOSTS_SCANNED}" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"

echo "Scan complete!"
echo "Scanned ${HOSTS_SCANNED} hosts and found ${FINDINGS_COUNT} vulnerabilities."
echo "Results saved to: ${RESULTS_DIR}"
echo "Home Assistant entities updated with scanner state: ${STATUS}"
