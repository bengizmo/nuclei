# Network Discovery and Monitoring System

## System Overview

This system provides comprehensive network security monitoring that:
- Scans all VLANs every 5 minutes for new devices
- Automatically profiles new devices with detailed NMAP scans
- Runs targeted Nuclei vulnerability scans based on device type
- Performs full network vulnerability scans daily at 3 AM
- Sends mobile notifications for new device detection and vulnerabilities
- Integrates with Home Assistant for real-time status updates

## Key Components

1. **Docker Container**: Self-contained environment with network discovery and scanning capabilities
2. **Discovery Service**: Continuously monitors all VLANs for new devices
3. **Profiling System**: Automatically fingerprints and scans new devices 
4. **Monitoring Service**: Ensures the discovery service is always running
5. **Scheduled Scans**: Daily vulnerability scans at 3 AM
6. **Home Assistant Integration**: Real-time status updates and mobile notifications

## Key Features

### 1. Continuous Network Discovery
- NMAP-based host discovery across all VLANs (Default, IoT, Guest, Clients)
- Tracks device online/offline status with 15-minute timeout
- Maintains persistent database of all discovered devices
- Quick ping checks between full scans to reduce network load
- Self-healing with automatic recovery from failures

### 2. Automatic Device Profiling
When a new device is detected:
- Performs comprehensive NMAP OS and service detection
- Classifies device type (server, camera, router, etc.)
- Runs targeted vulnerability scans with appropriate Nuclei templates
- Optionally generates AI templates through PDCP API
- Creates device summary with security recommendations

### 3. Device Type Detection
Automatically identifies:
- Linux servers
- Windows hosts
- IP cameras
- Network equipment (routers, switches)
- Media servers
- Home automation systems
- IoT devices
- Synology NAS devices
- Ubiquiti equipment

### 4. Targeted Vulnerability Scanning
Each device type triggers specific Nuclei templates:
- **Linux servers**: SSH, web panels, common CVEs
- **Windows hosts**: SMB, RDP, Windows-specific vulnerabilities
- **Cameras**: RTSP, default credentials, IoT vulnerabilities
- **Network devices**: Admin panels, router exploits
- **Media servers**: Plex, Jellyfin, Emby vulnerabilities
- **NAS devices**: Synology-specific templates
- **Home automation**: Home Assistant and IoT vulnerabilities

## Deployment and Configuration

### Environment Variables
The following environment variables control the system behavior:
- `NETWORK_DISCOVERY_ENABLED`: Enable/disable network discovery (default: true)
- `DAILY_SCAN_ENABLED`: Enable/disable daily scans (default: true)
- `DISCOVERY_INTERVAL`: Interval between discovery scans in seconds (default: 300)
- `HOME_ASSISTANT_API_TOKEN`: Token for Home Assistant integration
- `PDCP_API_KEY`: ProjectDiscovery API key for AI templates (optional)
- `OLLAMA_API`: URL for local LLM integration (optional)

### Deployment Process
```bash
# 1. Update docker-compose.yml with your environment variables
# 2. Deploy the configuration to your NAS or server
./update-services.sh

# 3. Verify services are running
ssh ben@192.168.10.163 'sudo systemctl status monitor.service'
ssh ben@192.168.10.163 'docker logs nuclei-scanner'
```

## Home Assistant Integration

### Entities Created
- `sensor.nuclei_scanner`: Main scanner status and findings
- `sensor.nuclei_discovery`: Network discovery status and device counts
- `sensor.nuclei_monitor`: Monitoring service status
- `sensor.nuclei_scanner_system`: Container and system status
- `sensor.nuclei_new_device_[IP]`: Created for each new device found

### Notifications
The system automatically sends mobile notifications to your phone when:
- New devices are discovered on the network
- Vulnerabilities are found on newly profiled devices
- Critical or high vulnerabilities are detected during daily scans
- The discovery service needs attention

## System Maintenance

### Viewing Logs
```bash
# View discovery logs
ssh ben@192.168.10.163 'cat /volume2/docker/nuclei/logs/discovery.log'

# View monitoring logs
ssh ben@192.168.10.163 'cat /volume2/docker/nuclei/logs/monitor.log'

# View container logs
ssh ben@192.168.10.163 'docker logs nuclei-scanner'
```

### Manual Commands

#### Force immediate full scan:
```bash
ssh ben@192.168.10.163 'sudo systemctl start nuclei-scan.service'
```

#### Profile a specific device:
```bash
ssh ben@192.168.10.163 '/usr/local/bin/docker exec nuclei-scanner sh /home/nuclei/scripts/profile-new-host-enhanced.sh 192.168.10.100 default'
```

#### Check discovery status:
```bash
ssh ben@192.168.10.163 '/usr/local/bin/docker exec nuclei-scanner cat /home/nuclei/discovery/status.json'
```

#### View discovery database:
```bash
ssh ben@192.168.10.163 '/usr/local/bin/docker exec nuclei-scanner cat /home/nuclei/discovery/discovery.db'
```

## Database Structure
The discovery database (`/home/nuclei/discovery/discovery.db`) contains:
- IP address
- MAC address
- First seen timestamp
- Last seen timestamp
- Hostname
- Operating system
- Open services
- Profile status and device type

## Security Monitoring Features
- New devices trigger immediate security scans
- Unknown devices generate alerts
- Daily vulnerability scans across all network segments
- Continuous monitoring for unauthorized devices
- VLAN isolation verification
- AI-powered security assessments (with PDCP or Ollama)
- Immediate notification for critical vulnerabilities

## Troubleshooting Tips

1. **Discovery not finding all devices**:
   - Check if all VLAN interfaces are properly configured
   - Verify Docker has host networking permissions
   - Check discovery logs for errors
   - Restart the container with `docker restart nuclei-scanner`

2. **Home Assistant integration not working**:
   - Verify the `HOME_ASSISTANT_API_TOKEN` is correct
   - Check if Home Assistant is reachable from the container
   - Look for curl errors in the discovery logs

3. **Daily scans not running**:
   - Check systemd timer status with `systemctl status nuclei-scan.timer`
   - Verify the service file is correctly installed
   - Check service logs for errors

4. **Monitor service issues**:
   - Check monitor logs for error messages
   - Verify the monitor service is running with `systemctl status monitor.service`

## Recovery Procedures

If the system is not working properly:

1. Restart the container:
   ```bash
   ssh ben@192.168.10.163 'docker restart nuclei-scanner'
   ```

2. Restart the monitoring service:
   ```bash
   ssh ben@192.168.10.163 'sudo systemctl restart monitor.service'
   ```

3. Redeploy the full configuration:
   ```bash
   ./update-services.sh
   ```