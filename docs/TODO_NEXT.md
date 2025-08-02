# Nginx RP Pipeline – Roadmap items

## Retention / pruning
* Keep last N prod dirs or those < X days old; configurable via deploy.conf

## Unit test harness
* BATS tests for core.sh, docker_ops.sh, release_ops.sh

## CI pipeline
* GitHub Actions: ShellCheck + BATS in DinD job

## Custom image option
* docker/nginx-rp.Dockerfile + `safe-rp-ctl build-image`

## Security scanning
* Trivy scan on final image; fail build on HIGH/CRITICAL
