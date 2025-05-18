# Home Assistant Integration Setup Guide

This guide helps you set up the Nuclei scanner integration with Home Assistant 2025.

## Prerequisites

1. Home Assistant 2025.x or later
2. Long-lived access token from Home Assistant
3. Mobile app installed on your device

## Step 1: Add Configuration

1. Copy the contents of `configuration-modern.yaml` to your Home Assistant configuration
2. Replace `mobile_app_bens_iphone_15` with your actual device entity ID
3. Add your SSH key to access the NAS from Home Assistant

## Step 2: Create Access Token

1. In Home Assistant, go to Profile > Security
2. Create a new Long-Lived Access Token
3. Save this token to your `.env` file as `HOME_ASSISTANT_API_TOKEN`

## Step 3: Add to Dashboard

Create a new card in your dashboard:

```yaml
type: vertical-stack
cards:
  - type: entity
    entity: sensor.nuclei_security_scanner
    name: Network Security Status
    icon: mdi:shield-network
  
  - type: entities
    title: Security Details
    entities:
      - entity: input_datetime.nuclei_last_scan
        name: Last Scan
        icon: mdi:clock-check
      - entity: input_number.nuclei_findings
        name: Total Findings
      - entity: input_number.nuclei_critical_count
        name: Critical Issues
      - entity: input_number.nuclei_hosts_scanned
        name: Hosts Scanned
    
  - type: horizontal-stack
    cards:
      - type: button
        name: Run Scan
        icon: mdi:shield-search
        tap_action:
          action: call-service
          service: script.nuclei_manual_scan
      - type: button
        name: Reset
        icon: mdi:restart
        tap_action:
          action: call-service
          service: script.nuclei_reset_status
```

## Features

### Editable Inputs
- All values are stored in input helpers that can be edited in the UI
- Status, findings, and scan times persist across restarts

### Mobile Notifications
- Alerts sent directly to your iPhone
- Critical findings trigger sound alerts
- Badge count shows number of issues

### Automation
- Daily scans at 3 AM
- Automatic notifications on completion
- Status updates during scanning

### Manual Controls
- Run scan button in UI
- Reset status button
- View detailed results

## Testing

1. Deploy the integration:
```bash
cd /path/to/nuclei/custom/home-network
./manage-remote.sh update
```

2. Test the integration:
```bash
./manage-remote.sh exec /home/nuclei/scripts/scan-with-ha-modern.sh
```

3. Check Home Assistant:
- Sensor should update to "scanning"
- After completion, should show results
- You should receive a notification

## Troubleshooting

- If no updates: Check the access token
- If no notifications: Check device entity ID
- If errors: Check Home Assistant logs

## Security Best Practices

1. Use a dedicated access token for Nuclei
2. Limit token permissions if possible
3. Regularly rotate the token
4. Monitor scan results for unusual activity