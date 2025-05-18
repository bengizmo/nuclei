# Network Discovery and Auto-Profiling System

## Overview
This system provides continuous network monitoring that:
- Scans all VLANs every 5 minutes for new devices
- Automatically profiles new devices with detailed NMAP scans
- Runs targeted Nuclei vulnerability scans based on device type
- Sends mobile notifications for new device detection
- Updates Home Assistant entities with device counts

## Features

### 1. Continuous Discovery
- NMAP-based host discovery across all VLANs
- Tracks device online/offline status
- Maintains persistent database of all discovered devices
- Sends notifications for new device detection

### 2. Automatic Device Profiling
When a new device is detected:
- Performs comprehensive NMAP OS and service detection
- Classifies device type (server, camera, router, etc.)
- Runs targeted vulnerability scans with appropriate Nuclei templates
- Generates AI summary of security posture

### 3. Device Type Detection
Automatically identifies:
- Linux servers
- Windows hosts
- IP cameras
- Network equipment (routers, switches)
- Apple devices
- IoT devices
- Printers
- VNC servers

### 4. Targeted Vulnerability Scanning
Each device type triggers specific Nuclei templates:
- **Linux servers**: SSH, web panels, common CVEs
- **Windows hosts**: SMB, RDP, Windows-specific vulnerabilities
- **Cameras**: RTSP, default credentials, IoT vulnerabilities
- **Network devices**: Admin panels, router exploits
- **IoT devices**: Common IoT vulnerabilities

## Deployment

### Using the Discovery-Enabled Container
```bash
# Deploy with discovery features
cd /Users/ben/dev/nuclei/custom/home-network
scp docker-compose-discovery.yml ben@192.168.10.163:/volume2/docker/nuclei/docker-compose.yml
ssh ben@192.168.10.163 'cd /volume2/docker/nuclei && /usr/local/bin/docker-compose up -d'
```

### Initialize the Discovery Database
```bash
ssh ben@192.168.10.163 '/usr/local/bin/docker exec nuclei-scanner sh /home/nuclei/scripts/initialize-discovery-db.sh'
```

## Home Assistant Integration

### Entities
- `sensor.nuclei_devices_found` - Total number of devices discovered on the network
- `sensor.nuclei_new_devices` - Number of new devices found (when applicable)

### Notifications
The system automatically sends mobile notifications to your phone when:
- New devices are discovered on the network
- Vulnerabilities are found on newly profiled devices

## Network Map Visualization
The system generates a network topology map showing:
- All discovered devices
- VLAN assignments
- Device types and icons
- Connection relationships

## Script Reference

### Core Scripts
- `network-discovery.sh` - Main discovery loop (runs continuously)
- `profile-new-host.sh` - Profiles newly discovered devices
- `update-discovery-entities.sh` - Updates Home Assistant sensors

### Usage Examples

#### Force immediate discovery scan:
```bash
ssh ben@192.168.10.163 '/usr/local/bin/docker exec nuclei-scanner pkill -USR1 network-discovery.sh'
```

#### Profile a specific device:
```bash
ssh ben@192.168.10.163 '/usr/local/bin/docker exec nuclei-scanner sh /home/nuclei/scripts/profile-new-host.sh 192.168.10.100 default'
```

#### Generate network map:
```bash
ssh ben@192.168.10.163 '/usr/local/bin/docker exec nuclei-scanner sh /home/nuclei/scripts/network-map-generator.sh'
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

## Security Considerations
- New devices trigger immediate security scans
- Unknown devices generate alerts
- AI summaries provide actionable security recommendations
- Continuous monitoring for unauthorized devices
- VLAN isolation verification

## Monitoring and Alerts
The system provides:
- Mobile notifications for new devices
- Security alerts for vulnerable devices
- Dashboard visualization of network status
- Historical tracking of device presence
- AI-powered security assessments