#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────
# DeVine Dev - DB 인스턴스 초기화 (ARM64)
# PostgreSQL (pgvector) + Valkey
# ──────────────────────────────────────

export DEBIAN_FRONTEND=noninteractive

# 시스템 업데이트
apt-get update -y
apt-get upgrade -y

# Docker 설치
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ubuntu 사용자를 docker 그룹에 추가
usermod -aG docker ubuntu

# Docker 서비스 시작
systemctl enable docker
systemctl start docker

# 작업 디렉토리 준비
mkdir -p /home/ubuntu/db
chown -R ubuntu:ubuntu /home/ubuntu/db

# 유휴 자원 회수 방지용 cron
cat > /etc/cron.d/devine-keepalive << 'CRON'
*/5 * * * * root docker exec devine-postgres pg_isready -U postgres > /dev/null 2>&1 || true
CRON

echo "=== DeVine Dev DB setup complete ==="
