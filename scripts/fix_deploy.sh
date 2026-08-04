#!/bin/bash
# Fix: configure CN docker mirrors + regenerate secrets with base64 form
set -e

# 1. Docker registry mirrors
cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://docker.m.daocloud.io"
  ]
}
EOF
systemctl restart docker
sleep 2
echo "=== DOCKER INFO MIRRORS ==="
docker info 2>/dev/null | grep -A3 "Registry Mirrors" || true

# 2. Regenerate .env (build values via intermediate vars)
cd /opt/fatbattle/backend
VA=`openssl rand -base64 48 | tr -d '/+=' | cut -c1-48`
VB=`openssl rand -base64 48 | tr -d '/+=' | cut -c1-48`
VC=`openssl rand -base64 18 | tr -d '/+=' | cut -c1-20`
printf 'JWT_SECRET=%s\nADMIN_JWT_SECRET=%s\nADMIN_USER=admin\nADMIN_PASS=%s\nZHIPU_API_KEY=\nBAIDU_API_KEY=\nBAIDU_SECRET_KEY=\n' "$VA" "$VB" "$VC" > .env
chmod 600 .env

echo "=== ENV CHECK (lengths) ==="
while IFS= read -r line; do
  key=`echo "$line" | cut -d= -f1`
  val=`echo "$line" | cut -d= -f2`
  echo "$key len=`echo -n "$val" | wc -c`"
done < .env

echo "=== BUILD START ==="
docker compose up -d --build 2>&1 | tail -6
echo "=== COMPOSE PS ==="
docker compose ps
