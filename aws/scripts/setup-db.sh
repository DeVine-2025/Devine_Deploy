#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────
# DeVine Prod - DB 인스턴스 초기화 (Private Subnet)
# PostgreSQL (pgvector) + Valkey
# ──────────────────────────────────────

export DEBIAN_FRONTEND=noninteractive

PRIVATE_BUCKET="${PRIVATE_BUCKET_NAME}"
DB_DIR="/home/ubuntu/db"

# 시스템 업데이트
apt-get update -y && apt-get upgrade -y
apt-get install -y ca-certificates curl gnupg awscli

# Docker 설치
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

usermod -aG docker ubuntu
systemctl enable docker && systemctl start docker

# 작업 디렉토리 준비
mkdir -p "$DB_DIR"

# S3에서 설정 파일 pull
aws s3 cp "s3://${PRIVATE_BUCKET}/config/db/docker-compose.yml" "$DB_DIR/docker-compose.yml"
aws s3 cp "s3://${PRIVATE_BUCKET}/config/db/.env"               "$DB_DIR/.env"
chown -R ubuntu:ubuntu "$DB_DIR"

cd "$DB_DIR" && docker compose up -d

# keepalive cron
cat > /etc/cron.d/devine-keepalive << 'CRON'
*/5 * * * * root docker exec devine-postgres pg_isready -U postgres > /dev/null 2>&1 || true
CRON

echo "=== DeVine Private DB setup complete ==="
