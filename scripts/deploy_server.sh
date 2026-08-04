#!/bin/bash
# Generate strong secrets .env and build/start the backend stack
set -e
cd /opt/fatbattle/backend

cat > .env <<EOF
JWT_SECRET=*** rand -hex 32`
ADMIN_JWT_SECRET=*** rand -hex 32`
ADMIN_USER=admin
ADMIN_PASS=`openssl rand -base64 18 | tr -d '/+=' | cut -c1-20`
ZHIPU_API_KEY=
BAIDU_API_KEY=
BAIDU_SECRET_KEY=
EOF
chmod 600 .env

echo "=== ENV GENERATED ==="
grep -E 'ADMIN_USER|ADMIN_PASS' .env
echo "=== BUILD START ==="
docker compose up -d --build 2>&1 | tail -8
echo "=== COMPOSE PS ==="
docker compose ps
