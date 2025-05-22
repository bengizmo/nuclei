# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nuclei is a fast template-based vulnerability scanner written in Go. It uses simple YAML-based templates to define custom vulnerability detection scenarios. The project supports multiple protocols including HTTP, DNS, TCP, SSL, WHOIS, JavaScript, and more.

This custom implementation adds Home Assistant integration and continuous network discovery capabilities.

## High-Level Architecture

### Core Components

1. **Docker Container**: Self-contained scanning environment
2. **Network Discovery Service**: Continuously monitors all VLANs for new devices
3. **Vulnerability Scanner**: Performs targeted and scheduled security scans
4. **Home Assistant Integration**: Real-time status updates and notifications
5. **Monitoring Service**: Ensures continuous operation of all services

### Key Scripts

- **`entrypoint.sh`**: Container initialization and service orchestration
- **`simple-discovery-enhanced.sh`**: Network discovery with vulnerability tracking
- **`profile-new-host-enhanced.sh`**: Automatic device fingerprinting and scanning
- **`scan-with-ha-modern.sh`**: Modern HA integration with AI summaries
- **`monitor-discovery.sh`**: Service monitoring and self-healing

## Common Commands

### Container Management
```bash
# Start the container
docker-compose up -d

# Restart the container
docker restart nuclei-scanner

# Check container logs
docker logs nuclei-scanner

# View discovery status
cat /volume2/docker/nuclei/discovery/status.json
```

### Manual Scanning
```bash
# Run a full scan with Home Assistant updates
docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-modern.sh

# Scan a specific host
docker exec nuclei-scanner /home/nuclei/scripts/profile-new-host-enhanced.sh 192.168.10.100 default

# Force discovery scan
docker exec nuclei-scanner pkill -USR1 -f simple-discovery
```

### Service Management
```bash
# Enable systemd services
systemctl enable nuclei-scan.service monitor.service

# Start monitoring service
systemctl start monitor.service

# Check service status
systemctl status nuclei-scan.service
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| NETWORK_DISCOVERY_ENABLED | Enable/disable network discovery | true |
| DAILY_SCAN_ENABLED | Enable/disable daily scans | true |
| DISCOVERY_INTERVAL | Interval between discovery scans (seconds) | 300 |
| HOME_ASSISTANT_API_TOKEN | Token for Home Assistant integration | required |
| PDCP_API_KEY | ProjectDiscovery API key for AI templates | optional |
| OLLAMA_API | URL for local LLM integration | optional |

## Docker Configuration

The enhanced system uses a simpler host networking configuration instead of custom VLANs to simplify deployment:

```yaml
# docker-compose.yml for network discovery
version: '3.8'

services:
  nuclei:
    build: .
    container_name: nuclei-scanner
    volumes:
      - ./results:/home/nuclei/results
      - ./scripts:/home/nuclei/scripts
      - ./entrypoint.sh:/home/nuclei/entrypoint.sh:ro
      - ./logs:/home/nuclei/logs
      - ./discovery:/home/nuclei/discovery
    environment:
      - HOME_ASSISTANT_API_TOKEN=${HOME_ASSISTANT_API_TOKEN}
      - PDCP_API_KEY=${PDCP_API_KEY}
      - OLLAMA_API=http://192.168.10.249:11434/v1
      - NETWORK_DISCOVERY_ENABLED=true
      - DAILY_SCAN_ENABLED=true
      - DISCOVERY_INTERVAL=300
    network_mode: host
    cap_add:
      - NET_ADMIN  # Required for network operations
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "sh", "-c", "pgrep -f network-discovery || exit 1"]
      interval: 5m
      timeout: 30s
      retries: 3
      start_period: 60s
    command: sh /home/nuclei/entrypoint.sh
```

## VLAN Network Segments

The discovery system scans these network segments:

- **Default VLAN 1**: 192.168.10.0/24 - Core devices, servers, management
- **IOT VLAN 2**: 192.168.14.0/24 - IoT devices
- **Guest VLAN 3**: 192.168.5.0/24 - Guest access
- **Clients VLAN 4**: 192.168.6.0/24 - Client devices

## Home Assistant Integration

The system creates the following entities:

| Entity | Description |
|--------|-------------|
| sensor.nuclei_scanner | Main scanner status and findings |
| sensor.nuclei_discovery | Network discovery status and device counts |
| sensor.nuclei_vulnerabilities | Security vulnerability tracking |
| sensor.nuclei_scanner_system | Container and system status |
| sensor.nuclei_new_device_[IP] | Created for each new device found |

## Important Files and Directories

**Note**: The docker directory on the Synology NAS is located at `/volume2/docker/` (not `/volume1/docker/`)

- **Scripts**: `/volume2/docker/nuclei/scripts/`
- **Logs**: `/volume2/docker/nuclei/logs/`
- **Discovery Database**: `/volume2/docker/nuclei/discovery/discovery.db`
- **Status File**: `/volume2/docker/nuclei/discovery/status.json`
- **Vulnerability File**: `/volume2/docker/nuclei/discovery/vulnerabilities.json`
- **Scan Results**: `/volume2/docker/nuclei/results/[date-timestamp]/`

## Diagnostics

For diagnosing issues, check:

1. **Container logs**:
   ```bash
   docker logs nuclei-scanner
   ```

2. **Service status**:
   ```bash
   systemctl status monitor.service
   ```

3. **Discovery logs**:
   ```bash
   cat /volume2/docker/nuclei/logs/discovery.log
   ```

4. **Home Assistant entities**:
   - Check `sensor.nuclei_discovery` in Home Assistant
   - Verify `sensor.nuclei_vulnerabilities` has data

## Maintenance Tasks

1. **Template Updates**:
   - Update templates regularly: `nuclei -ut`
   - Monitor for new CVEs relevant to your devices

2. **Vulnerability Management**:
   - Review `/volume2/docker/nuclei/discovery/vulnerabilities.json`
   - Address critical and high severity issues promptly
   - Track remediation progress

3. **Database Cleanup**:
   - Check `/volume2/docker/nuclei/discovery/discovery.db` for size
   - Archive old scan results periodically
   - Maintain a historical record of network changes

## Verification Commands

Run these commands to validate system operation:

```bash
# 1. Check if discovery is running
docker exec nuclei-scanner ps -ef | grep discovery

# 2. Check hosts discovered
docker exec nuclei-scanner wc -l /home/nuclei/discovery/discovery.db

# 3. Check Home Assistant status
curl -s -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
     http://192.168.10.89:8123/api/states/sensor.nuclei_discovery | jq

# 4. Review vulnerability statistics
cat /volume2/docker/nuclei/discovery/vulnerabilities.json
```