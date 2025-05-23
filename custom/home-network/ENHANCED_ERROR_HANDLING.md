# Enhanced Error Handling and Recovery

## Overview

The current deployment has basic error handling but lacks comprehensive recovery mechanisms. This document outlines the improvements needed and provides enhanced scripts.

## Current State Analysis

### ✅ What Works Well
- Basic process monitoring with auto-restart
- Signal handling for graceful shutdown
- Logging to multiple files
- HA status updates
- Some timeout handling in specific scripts

### ❌ Critical Gaps
1. **No Circuit Breakers**: Failed operations retry indefinitely
2. **No Resource Monitoring**: Can run out of disk/memory
3. **No Rate Limiting**: Can enter rapid restart loops
4. **No Network Resilience**: API calls have no retry logic
5. **No Graceful Degradation**: Complete failure instead of partial service
6. **No Log Rotation**: Logs can fill disk
7. **No Health Metrics**: No way to monitor system health
8. **No Timeout Handling**: Commands can hang forever

## Enhanced Components

### 1. Enhanced Monitor Script (`enhanced-monitor.sh`)
**Features:**
- Resource monitoring (disk, memory)
- Network connectivity checks
- Exponential backoff for restarts
- Rate limiting with cooldown periods
- Health status reporting to HA
- Automatic log rotation
- Circuit breaker pattern

**Key Improvements:**
```bash
# Resource checks
check_disk_space()   # Monitors disk usage, auto-rotates logs
check_memory()       # Monitors memory usage
check_network()      # Validates connectivity before operations

# Smart restart logic
- Maximum restart attempts
- Cooldown periods
- Exponential backoff
- HA notifications for manual intervention
```

### 2. Resilient Network Discovery (`network-discovery-resilient.sh`)
**Features:**
- Circuit breaker for repeated failures
- Network reachability checks
- Timeout handling for all operations
- Retry logic with exponential backoff
- Comprehensive error logging
- Graceful degradation
- Automatic log rotation
- Detailed status reporting

**Key Improvements:**
```bash
# Circuit breaker
- Tracks error count
- Opens circuit after threshold
- Auto-resets after cooldown

# Network resilience
- Pre-flight network checks
- Timeout on all operations
- Skip unreachable networks

# Better logging
- Separate error log
- Automatic rotation
- Structured status updates
```

## Implementation Guide

### Quick Start
1. Deploy enhanced scripts:
```bash
chmod +x scripts/enhanced-monitor.sh scripts/network-discovery-resilient.sh
scp scripts/*.sh ben@192.168.10.163:/volume2/docker/nuclei/scripts/
```

2. Update entrypoint to use resilient scripts:
```bash
# Replace in entrypoint.sh:
sh /home/nuclei/scripts/network-discovery-fixed-final.sh
# With:
sh /home/nuclei/scripts/network-discovery-resilient.sh
```

3. Add enhanced monitor to entrypoint:
```bash
# Add to entrypoint.sh after discovery launch:
(sh /home/nuclei/scripts/enhanced-monitor.sh &)
```

### Docker Compose Health Check
Update docker-compose.yml:
```yaml
healthcheck:
  test: ["CMD", "sh", "-c", "[ -f /home/nuclei/discovery/status.json ] && [ $(jq -r .circuit_breaker /home/nuclei/discovery/status.json) != 'open' ]"]
  interval: 2m
  timeout: 30s
  retries: 3
  start_period: 60s
```

## Monitoring and Alerts

### New HA Sensors
The enhanced system creates these sensors:
- `sensor.nuclei_system_health` - Overall system health
- `sensor.nuclei_discovery.circuit_breaker` - Circuit breaker status
- `sensor.nuclei_discovery.error_count` - Current error count

### Alert Automations
Create HA automations for:
1. Circuit breaker open → Critical alert
2. High resource usage → Warning notification
3. Too many restarts → Manual intervention needed
4. Discovery stuck → Service degradation alert

## Benefits

1. **Resilience**: System continues operating under adverse conditions
2. **Observability**: Better visibility into system health
3. **Self-Healing**: Automatic recovery from transient failures
4. **Resource Protection**: Prevents resource exhaustion
5. **Graceful Degradation**: Partial service better than no service
6. **Manual Intervention Alerts**: Know when human help is needed

## Testing

### Failure Scenarios
Test these scenarios:
1. **Network Outage**: Disconnect network, verify graceful handling
2. **Disk Full**: Fill disk to 95%, verify log rotation
3. **Process Crash**: Kill discovery process, verify restart
4. **API Failures**: Block HA API, verify retry logic
5. **Resource Exhaustion**: Simulate high memory, verify alerts

### Monitoring
Watch these metrics:
- Error counts in status.json
- Circuit breaker state
- Restart attempts
- Resource usage
- Log file sizes

## Future Enhancements

1. **Metrics Collection**: Add Prometheus/Grafana
2. **Distributed Tracing**: Track operations across services
3. **A/B Deployment**: Test changes safely
4. **Backup Scanner**: Secondary scanner for failover
5. **Configuration Management**: Dynamic config updates
6. **Performance Profiling**: Identify bottlenecks