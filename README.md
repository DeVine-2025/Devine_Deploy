# DeVine Deploy

DeVine 프로젝트의 인프라 및 배포 설정을 관리하는 레포지토리입니다.

## 아키텍처

```
[Client]
   │
   ▼
[Nginx :80/443]  ← SSL 종단, 보안 헤더, Rate Limiting
   │
   ├──▶ [Backend (Spring Boot) :8080]
   │         │
   └──▶ [AI (FastAPI) :8000]
              │
              ▼
         [PostgreSQL :5432]  [Valkey :6379]
         (pgvector/pg17)     (Redis 호환)
```

| 서버 | 위치 | 역할 |
|------|------|------|
| DB 서버 | EC2 프라이빗 서브넷 | PostgreSQL + Valkey |
| Service 서버 | EC2 퍼블릭 서브넷 | Nginx + Backend + AI |

- 도메인: `api.devine.kr` (Let's Encrypt SSL)
- 배포 방식: Blue/Green 무중단 배포 (GitHub Actions CD → EC2)

## 프로젝트 구조

```
DeVine_Deploy/
├── db/
│   ├── docker-compose.yml       # PostgreSQL(pgvector/pg17), Valkey
│   └── .env                     # DB 환경변수 (Git 제외, S3 공유)
├── service/
│   ├── docker-compose.yml       # Nginx, Backend Blue/Green, AI Blue/Green
│   ├── deploy.sh                # Blue/Green 배포 스크립트
│   ├── .env                     # 서비스 환경변수 (Git 제외, S3 공유)
│   ├── .active-slot-backend     # 현재 활성 Backend 슬롯 (Git 제외, 서버 로컬)
│   ├── .active-slot-ai          # 현재 활성 AI 슬롯 (Git 제외, 서버 로컬)
│   └── nginx/
│       ├── conf.d/
│       │   ├── api.devine.kr.conf  # 서버 블록 (보안 헤더, Rate Limiting, 라우팅)
│       │   ├── ssl.conf            # SSL 공통 설정 (TLS 버전, 암호화)
│       │   └── upstream.conf       # upstream 정의 (deploy.sh가 배포 시 자동 재생성)
│       └── ssl/                    # Let's Encrypt 인증서 (Git 제외)
├── log/                         # 리뷰 및 분석 로그
└── README.md
```

## Blue/Green 배포

### 개요

서비스 중단 없이 새 버전을 배포하는 전략. Backend와 AI 각각 blue/green 두 슬롯을 운영하며, 배포 시 비활성 슬롯에 새 버전을 띄운 뒤 Nginx upstream을 전환한다.

```
[배포 전]  Nginx → backend-blue (active)   backend-green (중지)
[배포 후]  Nginx → backend-green (active)  backend-blue (중지)
```

### 배포 흐름 (`deploy.sh`)

```
1. 현재 슬롯 확인      .active-slot-{service} 파일 읽기 (없으면 none → blue 시작)
2. 이미지 Pull         비활성 슬롯에 새 이미지 pull
3. 컨테이너 시작       비활성 슬롯 컨테이너 기동
4. 헬스체크 대기       최대 180초 대기, 실패 시 새 컨테이너 종료 후 exit
5. Nginx 전환          upstream.conf 원자적 교체 (tmp → mv), nginx -t → nginx -s reload
6. 슬롯 기록           .active-slot-{service}에 새 슬롯 기록
7. 구 컨테이너 종료    10초 대기(in-flight 처리) 후 구 슬롯 컨테이너 종료
8. 이미지 정리         dangling 이미지 prune
```

### 사용법

```bash
cd service
./deploy.sh backend <image_tag>   # Backend 배포
./deploy.sh ai <image_tag>        # AI 배포
```

> 일반적으로 직접 실행하지 않습니다. GitHub Actions CD가 자동 호출합니다.

## 최초 서버 세팅 순서

> EC2에 처음 설정하는 경우에만 수행합니다.

### 1단계: DB 서버

```bash
cd db
# S3에서 .env 다운로드
aws s3 cp s3://<bucket>/config/db.env .env
docker compose up -d
```

| 서비스 | 이미지 | 포트 |
|--------|--------|------|
| PostgreSQL | pgvector/pgvector:pg17 | 5432 |
| Valkey | valkey/valkey:9.0-alpine | 6379 |

### 2단계: Service 서버 — Nginx 먼저

```bash
cd service
# S3에서 .env 다운로드
aws s3 cp s3://<bucket>/config/.env .env
# Nginx만 먼저 기동 (Backend/AI는 CD가 Blue/Green으로 배포)
docker compose up -d nginx
```

> Backend, AI 컨테이너는 CD가 `deploy.sh`를 통해 자동 배포합니다.
> Nginx는 변수 기반 proxy_pass를 사용하므로 Backend/AI가 아직 없어도 정상 기동됩니다.
> 단, 해당 서비스로의 요청은 컨테이너가 배포되기 전까지 502를 반환합니다.

### 3단계: 첫 배포

GitHub Actions CD가 main 브랜치 머지 시 자동 실행됩니다.
수동으로 트리거하려면 GitHub Actions 페이지에서 workflow를 재실행합니다.

## Nginx 설정

### Rate Limiting

| 경로 | 제한 | 비고 |
|------|------|------|
| `/api/v1/auth/` | 5r/m, burst=3 | 브루트포스 방지 |
| `/` (일반 API) | 10r/s, burst=20 | 일반 요청 제한 |
| `/sse/` | 제한 없음 | SSE 장시간 연결 |
| `/api/v1/reports/sync` | 제한 없음 | 장시간 요청 (3분 타임아웃) |

### 보안 헤더

`X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security`, `X-XSS-Protection`, `Referrer-Policy`

### SSL

- TLSv1.2 / TLSv1.3, Let's Encrypt, HTTP → HTTPS 자동 리다이렉트

## 환경변수

`.env` 파일은 Git에서 제외됩니다. S3를 통해 팀 내 공유합니다.

| 변수 | 설명 |
|------|------|
| `POSTGRES_HOST` | DB 서버 프라이빗 IP |
| `POSTGRES_PORT` | PostgreSQL 포트 (5432) |
| `POSTGRES_DATABASE` | 데이터베이스명 |
| `POSTGRES_USER` | DB 사용자 |
| `POSTGRES_PASSWORD` | DB 비밀번호 |
| `REDIS_HOST` | Valkey 서버 프라이빗 IP |
| `REDIS_PORT` | Valkey 포트 (6379) |
| `REDIS_PASSWORD` | Valkey 비밀번호 |
| `SPRING_PORT` | Backend 포트 (8080) |
| `FAST_PORT` | AI 서비스 포트 (8000) |
| `DOCKER_USERNAME` | Docker Hub 사용자명 |
