# Backend Services Architecture

## Problem Statement

As the reverse proxy pipeline manages more applications with backend services (like Vaultwarden), having these services only available in one environment (e.g., ship) creates testing bottlenecks:

- Cannot test backend-dependent apps in WIP
- Cannot validate backend connections in prep
- Each new backend service compounds the problem

## Proposed Solution: Pipeline-Aware Backend Services

Backend services should follow the same pipeline stages as the nginx proxy itself:

```
Backend Service Pipeline:
seed → wip → prep → ship
```

## Implementation Pattern

### 1. Per-Stage Backend Containers

Each pipeline stage should have its own backend service instances:

```yaml
# Stage-specific backend containers
vaultwarden-wip    # For WIP testing
vaultwarden-prep   # For prep validation  
vaultwarden-ship   # For ship verification
vaultwarden-prod   # Production instance
```

### 2. Network Architecture

Each stage maintains its own network with consistent service discovery:

```
nginx-rp-network-wip:
  - nginx-rp-wip
  - vaultwarden-wip
  - other-backend-wip

nginx-rp-network-prep:
  - nginx-rp-prep
  - vaultwarden-prep
  - other-backend-prep
```

### 3. Configuration Consistency

Backend services use the same hostname across stages, with network isolation providing the correct routing:

```nginx
# Same config works in all stages
location / {
    proxy_pass http://vaultwarden:80;  # Resolves to stage-specific container
}
```

### 4. Data Management

Each stage maintains separate data volumes:

```bash
/data/vaultwarden-wip/    # WIP test data
/data/vaultwarden-prep/   # Prep validation data
/data/vaultwarden-ship/   # Ship verification data
/data/vaultwarden-prod/   # Production data (backed up)
```

## Benefits

1. **Complete Testing**: Every stage can fully test all applications
2. **Isolation**: Changes in one stage don't affect others
3. **Consistency**: Same configuration works across all stages
4. **Safety**: Production data never touched by test stages

## Migration Path

### Phase 1: Current State (Temporary)
- Single backend instance (vaultwarden-ship)
- Connected to multiple networks for testing
- Manual network management

### Phase 2: Stage-Specific Services
- Deploy backend services per stage
- Update start scripts to launch stage backends
- Maintain consistent service names

### Phase 3: Full Pipeline Integration
- Backend services included in build process
- Automated data migration between stages
- Health checks for all services

## Example Implementation

### Start Scripts Enhancement

```bash
# scripts/lib/environment_ops.sh
start_stage_backends() {
    local stage="$1"
    
    # Start vaultwarden for this stage
    docker run -d \
        --name "vaultwarden-${stage}" \
        --network "nginx-rp-network-${stage}" \
        --hostname "vaultwarden" \
        -v "${DATA_ROOT}/vaultwarden-${stage}:/data" \
        vaultwarden/server:latest
        
    # Start other backends...
}
```

### Configuration Template

```nginx
# conf.d/vaultwarden.conf - works in all stages
server {
    listen 443 ssl;
    server_name VW.example.com;
    
    location / {
        # Always resolves to stage-specific backend
        proxy_pass http://vaultwarden:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Best Practices

1. **Service Naming**: Use consistent names without stage suffixes in configs
2. **Data Isolation**: Never share data volumes between stages
3. **Network Isolation**: Each stage has its own network
4. **Health Checks**: Verify backends before starting nginx
5. **Cleanup**: Stop stage backends when stopping nginx

## Future Enhancements

1. **Service Discovery**: Automatic backend detection and configuration
2. **Data Sync**: Optional data sync from prod → seed for testing
3. **Multi-Version Testing**: Run multiple backend versions in parallel
4. **Orchestration**: Docker Compose or Kubernetes for complex setups