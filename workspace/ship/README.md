# Self-Contained Deployment Package

This package contains everything needed to deploy to any Type-5 environment.

## Usage

### Local Ship Environment (testing)
```bash
./start-ship.sh
```

### Stage Environment (IONOS staging)
```bash
./start-stage.sh
```

### Pre-production Environment
```bash
./start-preprod.sh
```

### Production Environment
```bash
./start-prod.sh
```

## What's Included

- Runtime configurations (nginx.conf, conf.d/*)
- SSL certificates
- Info pages
- Environment-specific deployment scripts
- Zero-entropy deterministic deployment

## Adding New Services

1. Add service configuration to `conf.d/servicename.conf`
2. Add SSL certificates to `certs/domain.com/`
3. Add info pages to `info_pages/domain.com/`
4. Deployment scripts automatically discover and configure new services

No script modifications needed!
