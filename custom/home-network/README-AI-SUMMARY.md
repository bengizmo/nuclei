# Nuclei Scanner with AI Summary Integration

## Overview
This project provides a comprehensive network vulnerability scanner using Nuclei, integrated with Home Assistant for real-time monitoring and AI-powered summaries using Ollama.

## Features
- Multi-VLAN network scanning across 4 VLANs
- Real-time Home Assistant sensor integration
- AI-generated security summaries using Ollama
- Automated notifications for security alerts
- Docker container deployment on Synology NAS

## Home Assistant Sensors
All sensors are grouped under the "Nuclei Scanner" device:

1. **`sensor.nuclei_scanner`** - Main device sensor with all attributes
2. **`sensor.nuclei_scanner_status`** - Current scan status (ok/alert/scanning)
3. **`sensor.nuclei_scanner_findings`** - Number of vulnerabilities found
4. **`sensor.nuclei_scanner_hosts`** - Number of hosts scanned
5. **`sensor.nuclei_scanner_last_scan`** - Timestamp of last scan
6. **`sensor.nuclei_scanner_summary`** - AI-generated summary from Ollama

## AI Summary Integration
The AI summary uses Ollama (running on 192.168.10.249) with the `qwen3:latest` model to:
- Analyze scan results
- Generate concise 1-2 sentence summaries
- Provide actionable security recommendations
- Store summaries as sensor attributes in Home Assistant

## Usage

### Run a scan with AI summary:
```bash
ssh ben@192.168.10.163 '/usr/local/bin/docker exec nuclei-scanner sh /home/nuclei/scripts/scan-with-ai-summary.sh'
```

### Check all sensors:
```bash
ssh ben@192.168.10.163 '/usr/local/bin/docker exec nuclei-scanner sh /home/nuclei/scripts/check-all-sensors.sh'
```

### Regenerate AI summary for existing results:
```bash
ssh ben@192.168.10.163 '/usr/local/bin/docker exec nuclei-scanner sh /home/nuclei/scripts/generate-ai-summary.sh'
```

## Home Assistant Dashboard
Use the configuration from `home-assistant/complete-dashboard.yaml` to create a comprehensive dashboard showing:
- Current security status
- AI-generated summary
- Vulnerability counts by severity
- Action buttons for scanning
- Automated alerts and notifications

## Architecture
- **Nuclei Scanner**: Runs in Docker container on Synology NAS
- **Ollama LLM**: Provides AI summaries (192.168.10.249)
- **Home Assistant**: Displays results and sends notifications (192.168.10.89)
- **VLANs**: Scans Default, IOT, Guest, and Clients networks

## Security
- API keys stored in environment variables
- Sensitive data removed from git history
- Network isolation through VLANs
- Regular automated security scans