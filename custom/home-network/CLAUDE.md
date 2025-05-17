# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nuclei is a fast template-based vulnerability scanner written in Go. It uses simple YAML-based templates to define custom vulnerability detection scenarios. The project supports multiple protocols including HTTP, DNS, TCP, SSL, WHOIS, JavaScript, and more.

## High-Level Architecture

### Core Packages

- **`cmd/nuclei/`**: Main entry point for the CLI application
- **`internal/runner/`**: Core runner logic for executing scans
- **`pkg/`**: Main packages containing most of the application logic
  - **`protocols/`**: Different protocol implementations (http, dns, tcp, etc.)
  - **`templates/`**: Template parsing and execution engine
  - **`types/`**: Core types and options definitions
  - **`core/`**: Engine implementation and execution logic
  - **`output/`**: Result formatting and output handling
  - **`catalog/`**: Template catalog management
  - **`js/`**: JavaScript runtime for JS-based templates

### Key Design Patterns

1. **Template Engine**: YAML templates are parsed into protocol-specific executors
2. **Protocol Abstraction**: Each protocol implements a common interface for execution
3. **Workflow System**: Complex scanning workflows can be defined with conditional logic
4. **Plugin System**: Extensible through JavaScript and code-based templates

## Common Development Commands

### Build Commands
```bash
# Build nuclei binary
make build

# Build with memory profiling support  
make build-stats

# Clean build artifacts
make clean

# Build functional test binary
make build-test
```

### Development Tools
```bash
# Update all JavaScript/TypeScript bindings
make jsupdate-all

# Generate documentation
make docs

# Generate template documentation
make syntax-docs

# Generate DSL function documentation
make dsl-docs
```

### Testing
```bash
# Run unit tests
make test

# Run integration tests
make integration

# Run functional tests
make functional

# Validate templates
make template-validate
```

### Docker Commands
```bash
# Build Docker image
docker build -t nuclei .

# Run nuclei in Docker
docker run projectdiscovery/nuclei:latest -target example.com

# Scan network with Docker
docker run projectdiscovery/nuclei:latest -target 192.168.1.0/24
```

### Network Scanning
```bash
# Scan single host
./bin/nuclei -target example.com

# Scan network subnet
./bin/nuclei -target 192.168.1.0/24

# Scan with specific templates
./bin/nuclei -target example.com -t http/vulnerabilities/

# Scan with severity filter
./bin/nuclei -target example.com -severity high,critical
```

## Docker Configuration for Synology NAS

The project includes a Dockerfile that creates an Alpine-based container with:
- Nuclei binary
- Required dependencies (bind-tools, chromium, ca-certificates)
- Minimal attack surface

### Multi-VLAN Home Network Configuration

For running on a Synology NAS (192.168.10.163) to scan multiple VLANs:

```yaml
# docker-compose.yml for multi-VLAN scanning deployment
version: '3'
services:
  nuclei:
    image: projectdiscovery/nuclei:latest
    container_name: nuclei-scanner
    cap_add:
      - NET_ADMIN  # Required for multiple VLANs
    privileged: true  # May be needed for VLAN access
    volumes:
      - ./templates:/home/nuclei/nuclei-templates
      - ./results:/home/nuclei/results
      - ./config:/home/nuclei/.config/nuclei
      - ./scripts:/home/nuclei/scripts
    environment:
      - HOME_ASSISTANT_API_TOKEN=${HOME_ASSISTANT_API_TOKEN}
      - OLLAMA_API=http://192.168.10.249:11434/v1
    networks:
      vlan_default:
        ipv4_address: 192.168.10.200
      vlan_iot:
        ipv4_address: 192.168.14.200
      vlan_guest:
        ipv4_address: 192.168.5.200
      vlan_clients:
        ipv4_address: 192.168.6.200
    restart: unless-stopped
    command: /home/nuclei/scripts/multi-vlan-scan.sh

networks:
  vlan_default:
    driver: macvlan
    driver_opts:
      parent: eth0.1
    ipam:
      config:
        - subnet: 192.168.10.0/24
          gateway: 192.168.10.1
  vlan_iot:
    driver: macvlan
    driver_opts:
      parent: eth0.2
    ipam:
      config:
        - subnet: 192.168.14.0/24
          gateway: 192.168.14.1
  vlan_guest:
    driver: macvlan
    driver_opts:
      parent: eth0.3
    ipam:
      config:
        - subnet: 192.168.5.0/24
          gateway: 192.168.5.1
  vlan_clients:
    driver: macvlan
    driver_opts:
      parent: eth0.4
    ipam:
      config:
        - subnet: 192.168.6.0/24
          gateway: 192.168.6.1
```

### VLAN Network Segments

- **Default VLAN 1**: 192.168.10.0/24 - Core devices, servers, management
- **IOT VLAN 2**: 192.168.14.0/24 - IoT devices
- **Guest VLAN 3**: 192.168.5.0/24 - Guest access
- **Clients VLAN 4**: 192.168.6.0/24 - Client devices  
- **ISOLATED VLAN 40**: 192.168.40.0/28 - Corporate devices (isolated)
- **VPN**: 192.168.3.0/24 - VPN clients

### Critical Infrastructure Targets

```bash
# Create target list file: critical-hosts.txt
cat > critical-hosts.txt << EOF
# Network Infrastructure
192.168.10.1    # UDM PRO (Main Router/Firewall)
192.168.10.156  # Ubiquiti AP 1
192.168.10.50   # Ubiquiti AP 2
192.168.10.7    # Ubiquiti AP 3
192.168.10.130  # Ubiquiti AP 4

# Servers
192.168.10.249  # Think Tank (Ubuntu Dev Server - Docker/Ollama)
192.168.10.251  # RBHome Ubuntu (Media Server - Plex/Sonarr/Radarr)
192.168.10.89   # Home Assistant (Raspberry Pi)
192.168.10.163  # NAS1 (Synology - Nuclei Host)
EOF
```

### Multi-VLAN Scanning Script

```bash
#!/bin/bash
# multi-vlan-scan.sh - Comprehensive multi-VLAN scanning script

SCAN_DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/home/nuclei/results/${SCAN_DATE}"
mkdir -p "$RESULTS_DIR"

# Function to update Home Assistant
update_home_assistant() {
    curl -X POST \
      -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"state\": \"$1\", \"attributes\": {\"last_scan\": \"${SCAN_DATE}\", \"status\": \"$2\", \"findings\": $3}}" \
      http://192.168.10.89:8123/api/states/sensor.nuclei_scanner
}

# Start scan notification
update_home_assistant "scanning" "Running multi-VLAN scan" 0

# Scan each VLAN
VLANS=("192.168.10.0/24:default" "192.168.14.0/24:iot" "192.168.5.0/24:guest" "192.168.6.0/24:clients")

for vlan in "${VLANS[@]}"; do
    IFS=':' read -r subnet name <<< "$vlan"
    echo "Scanning $name VLAN: $subnet"
    
    nuclei -target "$subnet" \
           -o "$RESULTS_DIR/scan-$name.json" \
           -json \
           -severity medium,high,critical \
           -tags network,cve,router,iot,exposed-panels,default-logins \
           -stats-json \
           -si 30 \
           -exclude-hosts "192.168.10.163" # Exclude self (NAS)
done

# Scan critical infrastructure with enhanced checks
nuclei -list /home/nuclei/critical-hosts.txt \
       -o "$RESULTS_DIR/critical-infrastructure.json" \
       -json \
       -severity low,medium,high,critical \
       -t network/ -t ssl/ -t exposed-panels/ -t default-logins/ \
       -stats-json

# Compile results and check for findings
FINDINGS=$(jq -s '[.[] | select(.info.severity == "critical" or .info.severity == "high")] | length' "$RESULTS_DIR"/*.json 2>/dev/null || echo 0)

if [ "$FINDINGS" -gt 0 ]; then
    update_home_assistant "alert" "Found $FINDINGS vulnerabilities" "$FINDINGS"
    # Send notification to Home Assistant
    curl -X POST \
      -H "Authorization: Bearer ${HOME_ASSISTANT_API_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"message\": \"Nuclei scan completed: $FINDINGS high/critical vulnerabilities found\", \"title\": \"Security Alert\"}" \
      http://192.168.10.89:8123/api/services/notify/notify
else
    update_home_assistant "ok" "No vulnerabilities found" 0
fi

# Generate summary report
echo "Scan completed at $SCAN_DATE" > "$RESULTS_DIR/summary.txt"
echo "Total high/critical findings: $FINDINGS" >> "$RESULTS_DIR/summary.txt"
cat "$RESULTS_DIR"/*.json | jq -r '.info.severity' | sort | uniq -c >> "$RESULTS_DIR/summary.txt"
```

## AI Template Generation with Nuclei

Nuclei includes AI-powered template generation using the ProjectDiscovery Cloud Platform API:

```bash
# Generate and run a template using AI
nuclei -ai "detect exposed Synology NAS admin panels" -target 192.168.10.0/24

# Generate template without running (no targets)
nuclei -ai "find default credentials in IoT devices"

# Examples of AI prompts for home network security
nuclei -ai "detect exposed home automation systems" -target 192.168.14.0/24
nuclei -ai "find misconfigured routers with default credentials" -target 192.168.10.1
nuclei -ai "identify vulnerable media servers" -target 192.168.10.251
```

### Important Notes:
- Requires PDCP (ProjectDiscovery Cloud Platform) API key
- Configure with: `nuclei -auth` or set `PDCP_API_KEY` environment variable
- Free tier available at https://cloud.projectdiscovery.io/
- Generated templates are saved to `~/nuclei-templates/pdcp/`
- View templates online at `https://cloud.projectdiscovery.io/templates/{template_id}`

### Local LLM Integration (Future Enhancement)
While Nuclei doesn't currently support local LLM integration, you could potentially:
1. Create a local API proxy that mimics the PDCP API endpoint
2. Route requests to your Ollama instance on Think Tank (192.168.10.249)
3. Generate templates locally without cloud dependency

## Home Assistant Integration

Create sensors and automations in Home Assistant to monitor Nuclei scans:

```yaml
# configuration.yaml
sensor:
  - platform: template
    sensors:
      nuclei_scanner:
        friendly_name: "Nuclei Security Scanner"
        value_template: "{{ states('input_text.nuclei_status') }}"
        attribute_templates:
          last_scan: "{{ states('input_datetime.nuclei_last_scan') }}"
          findings_count: "{{ states('input_number.nuclei_findings') | int }}"
          critical_count: "{{ states('input_number.nuclei_critical') | int }}"
          high_count: "{{ states('input_number.nuclei_high') | int }}"

input_text:
  nuclei_status:
    name: Nuclei Status
    initial: idle

input_datetime:
  nuclei_last_scan:
    name: Last Nuclei Scan
    has_date: true
    has_time: true

input_number:
  nuclei_findings:
    name: Nuclei Findings
    min: 0
    max: 999
    step: 1
  nuclei_critical:
    name: Critical Findings
    min: 0
    max: 999
    step: 1
  nuclei_high:
    name: High Findings
    min: 0
    max: 999
    step: 1

automation:
  - alias: "Nuclei Daily Scan"
    trigger:
      - platform: time
        at: "03:00:00"
    action:
      - service: shell_command.run_nuclei_scan
      
  - alias: "Nuclei Alert Notification"
    trigger:
      - platform: state
        entity_id: sensor.nuclei_scanner
        to: "alert"
    action:
      - service: notify.notify
        data:
          title: "Security Alert"
          message: "Nuclei found {{ state_attr('sensor.nuclei_scanner', 'findings_count') }} vulnerabilities!"

shell_command:
  run_nuclei_scan: 'docker exec nuclei-scanner /home/nuclei/scripts/multi-vlan-scan.sh'
```

### Lovelace Dashboard Card

```yaml
type: custom:vertical-stack-in-card
title: Network Security Scanner
cards:
  - type: custom:button-card
    entity: sensor.nuclei_scanner
    show_state: true
    show_icon: true
    icon: mdi:shield-search
    size: 40px
    state:
      - value: "scanning"
        color: blue
        icon: mdi:shield-sync
      - value: "alert"
        color: red
        icon: mdi:shield-alert
      - value: "ok"
        color: green
        icon: mdi:shield-check
  - type: entities
    entities:
      - entity: sensor.nuclei_scanner
        type: attribute
        attribute: last_scan
        name: Last Scan
      - entity: sensor.nuclei_scanner
        type: attribute
        attribute: findings_count
        name: Total Findings
      - entity: sensor.nuclei_scanner
        type: attribute
        attribute: critical_count
        name: Critical
      - entity: sensor.nuclei_scanner
        type: attribute
        attribute: high_count
        name: High
  - type: button
    tap_action:
      action: call-service
      service: shell_command.run_nuclei_scan
    name: Run Scan Now
    icon: mdi:play
```

## Key Environment Variables

- `NUCLEI_SIGNATURE_PRIVATE_KEY`: For signing templates
- `NUCLEI_CONFIG_DIR`: Configuration directory path
- `NUCLEI_TEMPLATES_DIR`: Templates directory path

## Template Structure

Templates follow this basic structure:
```yaml
id: template-id
info:
  name: Template Name
  author: author
  severity: high
  tags: cve,apache

requests:
  - method: GET
    path:
      - "{{BaseURL}}/vulnerable-path"
    matchers:
      - type: word
        words:
          - "vulnerable string"
```

## Binary Locations

- Main binary: `./bin/nuclei`
- Development tools: `./bin/` (bindgen, tsgen, docgen, etc.)
- Template signer: `./bin/template-signer`

## Important Files

- Configuration: `~/.config/nuclei/config.yaml`
- Templates: `~/nuclei-templates/`
- Issue tracker config: `cmd/nuclei/issue-tracker-config.yaml`
- CLI flags: See `nuclei -h` for full list

## Recommended Templates for Home Network Security

### Critical Infrastructure Scanning
```bash
# Scan Ubiquiti devices
nuclei -t exposed-panels/unifi/ -t default-logins/unifi/ -target 192.168.10.1,192.168.10.156,192.168.10.50,192.168.10.7,192.168.10.130

# Scan Synology NAS
nuclei -t exposed-panels/synology/ -t cves/synology/ -target 192.168.10.163

# Scan media servers
nuclei -t exposed-panels/plex/ -t exposed-panels/jellyfin/ -target 192.168.10.251

# Scan IoT devices
nuclei -t iot/ -t default-logins/ -target 192.168.14.0/24
```

### Security Best Practices

1. **Regular Scanning Schedule**:
   - Critical infrastructure: Daily
   - IoT VLAN: Weekly
   - Guest VLAN: After each new device connects
   - Full network: Monthly

2. **Template Updates**:
   - Update templates regularly: `nuclei -ut`
   - Monitor for new CVEs relevant to your devices

3. **Results Management**:
   - Store results in structured format (JSON)
   - Archive historical data for trend analysis
   - Integrate with SIEM or logging system

4. **VLAN Security**:
   - Ensure proper firewall rules between VLANs
   - Monitor for cross-VLAN communication attempts
   - Regularly audit VLAN configurations

5. **Custom Templates**:
   - Create custom templates for your specific devices
   - Focus on configuration misconfigurations
   - Check for exposed internal services