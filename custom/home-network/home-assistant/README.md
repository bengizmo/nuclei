# Home Assistant Integration for Nuclei Scanner

This integration allows you to monitor and control your Nuclei security scanner from Home Assistant.

## Features

- Real-time scan status monitoring
- Vulnerability count tracking
- Automated daily scans
- Push notifications for security alerts
- Dashboard controls for manual scans

## Setup Instructions

1. **Configure SSH Access**:
   ```bash
   # From Home Assistant
   ssh-keygen -t rsa -b 4096
   ssh-copy-id nas@192.168.10.163
   ```

2. **Add Configuration**:
   - Copy contents of `configuration.yaml` to your HA config
   - Add webhook automation from `webhook-automation.yaml`
   - Restart Home Assistant

3. **Create Dashboard**:
   - Add the Lovelace card to your dashboard
   - Install required custom cards (mushroom, multiple-entity-row)

4. **Update Docker Compose**:
   ```yaml
   command: /home/nuclei/scripts/ha-webhook-update.sh
   ```

## How It Works

1. **Webhook Updates**: The scanner sends status updates via webhook
2. **Input Helpers**: Store current state and statistics
3. **Template Sensors**: Combine data for display
4. **Shell Commands**: Control scanner via SSH

## Troubleshooting

- **SSH Not Working**: Ensure passwordless SSH is configured
- **No Updates**: Check webhook URL in scanner script
- **Container Status Unknown**: Verify SSH command syntax

## Dashboard Preview

The dashboard shows:
- Current scan status (idle/scanning/alert)
- Last scan time
- Vulnerability counts by severity
- Manual scan button
- Container status indicator