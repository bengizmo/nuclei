# Nuclei Scanner Home Assistant Integration Setup

## Current Status
The Nuclei scanner is successfully integrated with Home Assistant and updating the following entities:
- `input_text.nuclei_status` - Current scanner status (scanning/alert/ok)
- `input_number.nuclei_findings` - Number of vulnerabilities found
- `input_number.nuclei_hosts_scanned` - Number of hosts scanned
- `input_datetime.nuclei_last_scan` - Timestamp of last scan

## Setup Instructions

### 1. Ensure Input Helpers Exist
First, make sure these input helpers are created in Home Assistant:

```yaml
# configuration.yaml
input_text:
  nuclei_status:
    name: Nuclei Status
    initial: idle
    max: 255

input_number:
  nuclei_findings:
    name: Nuclei Findings
    min: 0
    max: 9999
    step: 1
    
  nuclei_hosts_scanned:
    name: Nuclei Hosts Scanned
    min: 0
    max: 9999
    step: 1

input_datetime:
  nuclei_last_scan:
    name: Last Nuclei Scan
    has_date: true
    has_time: true
```

### 2. Add Template Sensor
Add the template sensor from `nuclei-dashboard.yaml` to create a unified sensor entity.

### 3. Create Dashboard Card
Use the Lovelace card configuration from `nuclei-dashboard.yaml` to display the scanner status.

### 4. Set Up Automations
Add the automations from `nuclei-dashboard.yaml` for:
- Daily scans at 3 AM
- Alert notifications when vulnerabilities are found
- Scan completion notifications

## Running Scans

### Manual Scan
```bash
ssh ben@192.168.10.163 '/usr/local/bin/docker exec nuclei-scanner sh /home/nuclei/scripts/quick-ha-scan.sh'
```

### Full VLAN Scan
```bash
ssh ben@192.168.10.163 '/usr/local/bin/docker exec nuclei-scanner sh /home/nuclei/scripts/full-vlan-scan.sh'
```

## Viewing Results

### Check Current Status
```bash
ssh ben@192.168.10.163 '/usr/local/bin/docker exec nuclei-scanner sh /home/nuclei/scripts/check-ha-entities.sh'
```

### View Container Logs
```bash
ssh ben@192.168.10.163 '/usr/local/bin/docker logs --tail 50 nuclei-scanner'
```

## Troubleshooting

### If entities are not updating:
1. Check the container has the correct environment variables:
   ```bash
   ssh ben@192.168.10.163 '/usr/local/bin/docker exec nuclei-scanner env | grep -E "HOME_ASSISTANT_API_TOKEN|PDCP_API_KEY"'
   ```

2. Test Home Assistant connectivity:
   ```bash
   ssh ben@192.168.10.163 '/usr/local/bin/docker exec nuclei-scanner sh /home/nuclei/scripts/test-ha-notifications.sh'
   ```

3. Run a quick scan to generate data:
   ```bash
   ssh ben@192.168.10.163 '/usr/local/bin/docker exec nuclei-scanner sh /home/nuclei/scripts/quick-ha-scan.sh'
   ```

## Next Steps
1. Configure the dashboard in Home Assistant
2. Set up scheduled scans via cron or Home Assistant automations
3. Monitor for security alerts
4. Review scan results regularly