#!/bin/bash
# Clear Caddy staging certs and force re-obtain from production Let's Encrypt
set -e
cd /opt/fatbattle/backend

# stop caddy
docker compose stop caddy >/dev/null 2>&1 || true

# remove any stored certs (staging or failed) for the site
docker run --rm -v backend_caddy_data:/data alpine sh -c "rm -rf /data/certificates/*" 2>/dev/null || true

# start caddy fresh -> will obtain from production CA directly
docker compose up -d caddy
echo "=== CADDY RESTARTED, waiting 45s for ACME ==="
sleep 45
docker logs fatbattle-caddy --since 2m 2>&1 | grep -E 'certificate stored|obtain.*succeeded|error|challenge' | tail -8
