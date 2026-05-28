#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────
# DeVine Prod - 서비스 인스턴스 초기화
# Nginx + API + Realtime + AI
# ──────────────────────────────────────

export DEBIAN_FRONTEND=noninteractive

PRIVATE_BUCKET="${PRIVATE_BUCKET_NAME}"
REPO_URL="https://github.com/DeVine-2025/Devine_Deploy"
DEPLOY_DIR="/home/ubuntu/Devine_Deploy"
SERVICE_DIR="${DEPLOY_DIR}/service"

# 스왑 설정 (메모리 2배) - 컨테이너 기동 전 선행 필수
MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
SWAP_SIZE=$(( MEM_KB * 2 / 1024 / 1024 ))G
fallocate -l "${SWAP_SIZE}" /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

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

# 레포 클론
git clone "${REPO_URL}" "${DEPLOY_DIR}"
chown -R ubuntu:ubuntu "${DEPLOY_DIR}"

# 로그 디렉토리 생성
mkdir -p "${SERVICE_DIR}/logs/"{api,realtime,ai}
mkdir -p "${SERVICE_DIR}/nginx/ssl"
chmod -R 777 "${SERVICE_DIR}/logs"
chown -R ubuntu:ubuntu "${DEPLOY_DIR}"

# S3에서 .env 파일 받기
aws s3 cp "s3://${PRIVATE_BUCKET}/config/.env.prod" "${SERVICE_DIR}/.env"
chown ubuntu:ubuntu "${SERVICE_DIR}/.env"

# DNS 전파 후 실행할 스크립트 생성
cat > "${DEPLOY_DIR}/start.sh" << 'SCRIPT'
#!/bin/bash
set -euo pipefail

# DNS가 이 EC2의 EIP를 바라보는지 확인 후 실행
certbot certonly --standalone --non-interactive --agree-tos \
  -m admin@devine.kr -d api.devine.kr

mkdir -p /home/ubuntu/Devine_Deploy/service/nginx/ssl/live/api.devine.kr
cp /etc/letsencrypt/live/api.devine.kr/fullchain.pem /home/ubuntu/Devine_Deploy/service/nginx/ssl/live/api.devine.kr/
cp /etc/letsencrypt/live/api.devine.kr/privkey.pem   /home/ubuntu/Devine_Deploy/service/nginx/ssl/live/api.devine.kr/

cd /home/ubuntu/Devine_Deploy/service && docker compose up -d
SCRIPT
chmod +x "${DEPLOY_DIR}/start.sh"
chown ubuntu:ubuntu "${DEPLOY_DIR}/start.sh"

# keepalive cron
cat > /etc/cron.d/devine-keepalive << 'CRON'
*/5 * * * * root curl -sf http://localhost/actuator/health > /dev/null 2>&1 || true
CRON

echo "=== DeVine Prod SVC setup complete. Run ~/Devine_Deploy/start.sh after DNS propagation. ==="
