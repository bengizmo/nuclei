# Nuclei Scanner Fix Summary

## Issues Found

1. **IP Address Extraction Problem**: The network discovery script was extracting timestamps instead of IP addresses from nmap output
   - Root cause: The `log` function output was being captured as part of the scan results
   - The awk command was extracting hostnames instead of IP addresses for hosts with DNS names

2. **Incorrect Volume Path**: Scripts were referencing `/volume1/docker/nuclei` instead of `/volume2/docker/nuclei`

3. **JSON Flag Error**: Scripts were using `-json` flag with nuclei, but it should be `-j`

4. **No Recent Scans**: Last scan results were from May 18th, indicating the scanner hasn't been running properly

## Fixes Applied

1. **Created Fixed Discovery Script** (`network-discovery-fixed-final.sh`):
   - Modified `log` function to write only to log file, not stdout
   - Fixed IP extraction to properly parse both hostname and IP-only entries
   - Added validation to ensure only valid IP addresses are processed
   - Added check to skip empty lines

2. **Updated Entrypoint Script**:
   - Changed to use the fixed discovery script
   - Updated sed command to modify the correct script name

3. **Updated Project Memory** (CLAUDE.md):
   - Added note that docker directory is at `/volume2/docker/` on the NAS

4. **Cleared Corrupted Data**:
   - Removed corrupted discovery database
   - Cleared old log entries

## Verification

After applying fixes:
- Network discovery is now correctly identifying IP addresses
- Discovery database contains valid IP addresses (e.g., 192.168.10.1, 192.168.10.2)
- Container is running and healthy
- Discovery service is scanning all VLANs every 5 minutes

## Next Steps

To trigger a manual scan:
```bash
./trigger-scan-direct.sh
```

To check discovery status:
```bash
ssh ben@192.168.10.163 "/usr/local/bin/docker exec nuclei-scanner cat /home/nuclei/discovery/status.json"
```

To view discovered hosts:
```bash
ssh ben@192.168.10.163 "/usr/local/bin/docker exec nuclei-scanner cat /home/nuclei/discovery/discovery.db | sort -V | uniq"
```

To check recent logs:
```bash
ssh ben@192.168.10.163 "/usr/local/bin/docker exec nuclei-scanner tail -50 /home/nuclei/logs/network-discovery.log"
```