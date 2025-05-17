# Development Guide

## Local Testing

Since the development machine doesn't have access to all VLANs, we use a separate configuration for local testing.

### Prerequisites

1. Docker and Docker Compose installed
2. `.env` file configured with API keys
3. Access to at least some network targets

### Local Testing Workflow

1. **Basic Test**:
   ```bash
   make test
   ```
   This runs a minimal scan on localhost to verify the setup.

2. **Interactive Testing**:
   ```bash
   make shell
   ```
   Opens a shell in the container for manual testing.

3. **Custom Targets**:
   Edit `test-hosts.txt` to add accessible targets from your current network location.

### Differences from Production

- **Network Mode**: Uses `host` networking instead of macvlan
- **Targets**: Limited to accessible hosts from current network
- **Scripts**: Uses `local-test-scan.sh` instead of `multi-vlan-scan.sh`
- **Results**: Stored in `results/local-test-*` directories

### Testing Checklist

- [ ] Nuclei binary works
- [ ] Templates load correctly
- [ ] API key authentication works (if configured)
- [ ] AI template generation works (if API key present)
- [ ] Results are saved in JSON format
- [ ] Scripts execute without errors

### Debugging

1. **Check Container Logs**:
   ```bash
   docker-compose -f docker-compose.local.yml logs
   ```

2. **Inspect Container**:
   ```bash
   docker-compose -f docker-compose.local.yml run --rm nuclei-local /bin/sh
   ```

3. **Test Individual Commands**:
   ```bash
   docker run --rm -it projectdiscovery/nuclei:latest nuclei -version
   ```

### Simulating Production Environment

To better simulate the production environment without VLANs:

1. Create mock responses for Home Assistant API
2. Use Docker networks to simulate network isolation
3. Test with subset of templates relevant to accessible targets

### Deployment Testing

Before deploying to production:

1. Validate all configuration files
2. Test scripts with dry-run options
3. Verify environment variables are set correctly
4. Check file permissions on scripts