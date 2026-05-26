#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────
# DeVine Prod - 서비스 인스턴스 초기화
# Nginx + API + Realtime + AI
# ──────────────────────────────────────

export DEBIAN_FRONTEND=noninteractive

PRIVATE_BUCKET="${PRIVATE_BUCKET_NAME}"
SERVICE_DIR="/home/ubuntu/service"

# 시스템 업데이트
apt-get update -y && apt-get upgrade -y
apt-get install -y ca-certificates curl gnupg git certbot awscli

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
mkdir -p "$SERVICE_DIR"/nginx/{conf.d,ssl,templates,log}
mkdir -p "$SERVICE_DIR"/logs/{backend,realtime,ai}

# S3에서 설정 파일 pull
aws s3 cp "s3://${PRIVATE_BUCKET}/config/service/docker-compose.yml" "$SERVICE_DIR/docker-compose.yml"
aws s3 cp "s3://${PRIVATE_BUCKET}/config/service/.env"               "$SERVICE_DIR/.env"
aws s3 sync "s3://${PRIVATE_BUCKET}/config/nginx/prod/"              "$SERVICE_DIR/nginx/"
chown -R ubuntu:ubuntu "$SERVICE_DIR"

# DNS 전파 후 실행할 스크립트 생성
cat > "$SERVICE_DIR/start.sh" << 'SCRIPT'
#!/bin/bash
set -euo pipefail

# DNS가 이 EC2의 EIP를 바라보는지 확인 후 실행
certbot certonly --standalone --non-interactive --agree-tos \
  -m admin@devine.kr -d api.devine.kr

mkdir -p /home/ubuntu/service/nginx/ssl/live/api.devine.kr
cp /etc/letsencrypt/live/api.devine.kr/fullchain.pem /home/ubuntu/service/nginx/ssl/live/api.devine.kr/
cp /etc/letsencrypt/live/api.devine.kr/privkey.pem   /home/ubuntu/service/nginx/ssl/live/api.devine.kr/

cd /home/ubuntu/service && docker compose up -d
SCRIPT
chmod +x "$SERVICE_DIR/start.sh"
chown ubuntu:ubuntu "$SERVICE_DIR/start.sh"

# keepalive cron
cat > /etc/cron.d/devine-keepalive << 'CRON'
*/5 * * * * root curl -sf http://localhost/actuator/health > /dev/null 2>&1 || true
CRON

echo "=== DeVine Prod SVC setup complete. Run ~/service/start.sh after DNS propagation. ==="
