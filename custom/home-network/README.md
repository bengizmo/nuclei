# Nuclei Home Network Security Scanner

Custom configuration for running Nuclei on a Synology NAS to scan a multi-VLAN home network.

## Network Configuration

- **Default VLAN 1**: 192.168.10.0/24 - Core devices, servers, management
- **IOT VLAN 2**: 192.168.14.0/24 - IoT devices  
- **Guest VLAN 3**: 192.168.5.0/24 - Guest access
- **Clients VLAN 4**: 192.168.6.0/24 - Client devices
- **ISOLATED VLAN 40**: 192.168.40.0/28 - Corporate devices (isolated)
- **VPN**: 192.168.3.0/24 - VPN clients

## Setup Instructions

1. Fork the main Nuclei repository on GitHub at https://github.com/projectdiscovery/nuclei

2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/nuclei.git
   cd nuclei
   ```

3. Set up remotes:
   ```bash
   git remote add upstream https://github.com/projectdiscovery/nuclei.git
   git remote -v  # Verify remotes
   ```

4. Create a branch for your customizations:
   ```bash
   git checkout -b home-network-setup
   ```

5. Add custom configuration:
   ```bash
   # Copy this directory to your fork
   cp -r custom/home-network /path/to/your/fork/custom/
   ```

6. Commit and push:
   ```bash
   git add custom/home-network
   git commit -m "Add home network scanning configuration"
   git push origin home-network-setup
   ```

7. Deploy to your Synology NAS (192.168.10.163)

## Deployment

```bash
# On your Synology NAS
cd /volume1/docker/nuclei
docker-compose up -d
```

## Home Assistant Integration

Add the configuration from `home-assistant-config.yaml` to your Home Assistant setup.

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

## Security Notes

- API key is included in docker-compose.yml - consider using secrets management
- Ensure proper firewall rules between VLANs
- Regularly update Nuclei templates