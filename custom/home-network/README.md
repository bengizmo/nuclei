# Nuclei Home Network Security Scanner

A comprehensive network security scanning system for home networks using Nuclei, with automatic device discovery, profiling, and AI-powered analysis.

## Features

### 🔍 Network Discovery
- Continuous NMAP-based discovery across all VLANs
- Automatic device profiling with OS/service detection
- Targeted vulnerability scanning based on device type
- Mobile notifications for new device detection

### 🛡️ Vulnerability Scanning
- Nuclei-based security scanning
- Custom templates for different device types
- AI-powered scan summaries via Ollama
- Multi-VLAN support (Default, IoT, Guest, Clients)

### 📊 Home Assistant Integration
- Real-time sensor entities
- Device count tracking
- Security status monitoring
- Mobile notifications via Home Assistant

### 🤖 AI Analysis
- Ollama-powered security summaries
- Actionable security recommendations
- Device risk assessment
- Automated insight generation

## Network Configuration

- **Default VLAN 1**: 192.168.10.0/24 - Core devices, servers, management
- **IOT VLAN 2**: 192.168.14.0/24 - IoT devices  
- **Guest VLAN 3**: 192.168.5.0/24 - Guest access
- **Clients VLAN 4**: 192.168.6.0/24 - Client devices
- **ISOLATED VLAN 40**: 192.168.40.0/28 - Corporate devices (isolated)
- **VPN**: 192.168.3.0/24 - VPN clients

## Quick Start

### Deploy to Synology NAS
```bash
# Deploy the container
cd /Users/ben/dev/nuclei/custom/home-network
./deploy-remote.sh

# Initialize discovery system
ssh ben@192.168.10.163 '/usr/local/bin/docker exec nuclei-scanner sh /home/nuclei/scripts/initialize-discovery-db.sh'
```

## Home Assistant Entities

The system creates these sensor entities:
- `sensor.nuclei_scanner` - Main scanner status
- `sensor.nuclei_scanner_findings` - Vulnerability count
- `sensor.nuclei_scanner_summary` - AI security summary
- `sensor.nuclei_devices_found` - Total devices discovered
- `sensor.nuclei_new_devices` - New devices found

## Documentation

- [Network Discovery System](README-NETWORK-DISCOVERY.md)
- [AI Summary Integration](README-AI-SUMMARY.md)

## Key Scripts

- `network-discovery.sh` - Continuous device discovery
- `profile-new-host.sh` - Device profiling
- `scan-with-ai-summary.sh` - Security scan with AI analysis
- `update-discovery-entities.sh` - Update HA entities

## Security Features

- Automatic detection of new devices
- Device type classification
- Targeted vulnerability scanning
- AI-powered risk assessment
- Mobile notifications for security events

## Updating Nuclei

To keep your fork up-to-date with the original Nuclei:

```bash
# Fetch updates from upstream
git fetch upstream

# Merge updates into your main branch
git checkout main
git merge upstream/main

# Push to your fork
git push myfork main

# Merge into your custom branch
git checkout home-network-setup
git merge main
```

## Requirements

- Synology NAS with Docker
- Home Assistant for notifications
- Ollama for AI summaries (192.168.10.249)
- Network with VLAN support

## License

This project is an extension of [Nuclei](https://github.com/projectdiscovery/nuclei) by ProjectDiscovery.