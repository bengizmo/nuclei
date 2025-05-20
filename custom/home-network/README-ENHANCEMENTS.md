# Home Network Scanner Enhancements

## Overview

This document details the recent enhancements made to the Nuclei Home Network Scanner system, focusing on improved reliability, discovery capabilities, and vulnerability tracking.

## Key Enhancements

### 1. Robust Container Management

- **Entrypoint Script**: Added a comprehensive entrypoint script that properly initializes services, handles signals, and ensures continuous operation
- **Health Checks**: Implemented Docker health checks to monitor service status
- **Error Recovery**: Added self-healing capabilities through watchdog processes
- **Volume Management**: Improved persistent storage configuration for logs, discovery data, and results

### 2. Enhanced Network Discovery

- **Continuous Operation**: Modified discovery service to run reliably with proper error handling
- **Multi-VLAN Support**: Confirmed scanning across all configured VLANs (Default, IoT, Guest, Clients)
- **Status Tracking**: Added detailed status reporting with timestamp tracking
- **Quick Checks**: Implemented efficient host monitoring between full scans to reduce network load
- **Offline Tracking**: Added proper tracking of hosts that appear offline

### 3. Vulnerability Tracking and Reporting

- **Vulnerability Database**: Added dedicated storage of vulnerability data
- **Detailed Metrics**: Track vulnerable hosts, total vulnerabilities, and severity breakdowns
- **Real-time Updates**: Push vulnerability status to Home Assistant entities
- **Per-Host Details**: Added tracking of vulnerabilities by host with descriptions

### 4. Home Assistant Integration

- **Enhanced Entities**:
  - `sensor.nuclei_discovery`: Network discovery status and metrics
  - `sensor.nuclei_vulnerabilities`: Dedicated vulnerability tracking
  - `sensor.nuclei_scanner_system`: Container and system status
- **Rich Attributes**: Added detailed attributes for dashboard customization
- **Multiple Notification Types**: Support for different notification categories

### 5. Systemd Service Integration

- **Reliable Scheduling**: Improved systemd timer service for daily scans
- **Health Verification**: Added pre-start checks to verify container health
- **Monitoring Service**: Added a dedicated service to monitor the discovery process

## Configuration Options

The system now supports the following environment variables for configuration:

| Variable | Description | Default |
|----------|-------------|---------|
| NETWORK_DISCOVERY_ENABLED | Enable/disable network discovery | true |
| DAILY_SCAN_ENABLED | Enable/disable daily scans | true |
| DISCOVERY_INTERVAL | Interval between discovery scans (seconds) | 300 |
| HOME_ASSISTANT_API_TOKEN | Token for Home Assistant integration | required |
| PDCP_API_KEY | ProjectDiscovery API key for AI templates | optional |
| OLLAMA_API | URL for local LLM integration | optional |

## New Features

### Vulnerability Summary

The system now provides a comprehensive vulnerability summary that includes:

- **Total vulnerable hosts**: Number of hosts with at least one vulnerability
- **Vulnerability counts**: Total vulnerabilities found in your network
- **Severity breakdown**: Critical, high, medium, and low severity counts
- **Top vulnerabilities**: List of most significant vulnerabilities with hosts and severity

This information is available in:
- Status file: `/home/nuclei/discovery/status.json`
- Vulnerability file: `/home/nuclei/discovery/vulnerabilities.json`
- Home Assistant: `sensor.nuclei_vulnerabilities`

### Enhanced Discovery Database

The discovery database now maintains more reliable information about hosts:
- IP address
- MAC address
- First seen timestamp
- Last seen timestamp
- Hostname
- Operating system
- Open services
- Profile status and device type

### Real-Time Status Updates

The system now updates Home Assistant in real-time with:
- Current discovery status
- Total hosts found
- New hosts discovered
- Hosts with vulnerabilities
- Vulnerability counts by severity

## Technical Implementation

### Key Script Improvements

1. **Entrypoint Script**: Manages the lifecycle of services within the container
2. **Discovery Script**: Continuously scans network and updates status
3. **Monitoring Script**: Ensures the discovery service remains operational
4. **Systemd Services**: Coordinate scheduled scans and monitoring

### Directory Structure

```
/home/nuclei/
  ├── scripts/
  │   ├── simple-discovery-enhanced.sh
  │   ├── profile-new-host-enhanced.sh
  │   ├── scan-with-ha-modern.sh
  │   └── monitor-discovery.sh
  ├── discovery/
  │   ├── discovery.db
  │   ├── status.json
  │   ├── vulnerabilities.json
  │   └── new_hosts.txt
  ├── logs/
  │   ├── discovery.log
  │   ├── monitor.log
  │   └── container.log
  └── results/
      └── [date-timestamp]/
```

## Usage Examples

### Check Discovery Status

```bash
cat /volume2/docker/nuclei/discovery/status.json
```

### View Vulnerability Summary

```bash
cat /volume2/docker/nuclei/discovery/vulnerabilities.json
```

### Check Latest Logs

```bash
tail -50 /volume2/docker/nuclei/logs/discovery.log
```

### Manually Trigger a Scan

```bash
docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha-modern.sh
```

## Troubleshooting

If you encounter issues:

1. Check container logs:
   ```bash
   docker logs nuclei-scanner
   ```

2. Verify discovery service is running:
   ```bash
   docker exec nuclei-scanner ps -ef | grep discovery
   ```

3. Restart the container:
   ```bash
   docker restart nuclei-scanner
   ```

4. Check service status:
   ```bash
   systemctl status monitor.service
   ```