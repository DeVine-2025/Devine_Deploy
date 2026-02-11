# DeVine Deploy

DeVine 프로젝트의 배포 설정을 관리하는 레포지토리입니다.

## 아키텍처

```
[Client] → [Nginx :80/443] → [Backend :8080 (Spring Boot)]
                             → [AI :8000 (FastAPI)]

[Backend/AI] → [PostgreSQL :5432 (pgvector/pg17)]
             → [Valkey :6379 (Redis 호환)]
```

| 구성 | 설명 |
|------|------|
| **DB 서버** | EC2 (프라이빗 서브넷) - PostgreSQL + Valkey |
| **Service 서버** | EC2 (퍼블릭 서브넷) - Nginx + Backend + AI |
| **도메인** | api.devine.kr (Let's Encrypt SSL) |

## 프로젝트 구조

```
DeVine_Deploy/
├── db/
│   ├── docker-compose.yml    # PostgreSQL(pgvector), Valkey 컨테이너
│   └── .env                  # DB 환경 변수 (Git 제외)
├── service/
│   ├── docker-compose.yml    # Backend, AI, Nginx 컨테이너
│   ├── .env                  # 서비스 환경 변수 (Git 제외)
│   └── nginx/
│       ├── conf.d/
│       │   ├── api.devine.kr.conf  # 서버 설정 (보안 헤더, Rate Limiting)
│       │   ├── ssl.conf            # SSL 공통 설정
│       │   └── upstream.conf       # 업스트림 정의
│       └── ssl/                    # SSL 인증서 (Git 제외)
└── README.md
```

## 시작하기

### 요구사항

- Docker 20.10+
- Docker Compose V2

### 환경 설정

환경 변수 파일(`.env`)은 S3를 통해 공유합니다.

### 배포 순서

#### 1단계: 데이터베이스 (DB 서버)

```bash
cd db
docker compose up -d
```

| 서비스 | 이미지 | 포트 |
|--------|--------|------|
| PostgreSQL | pgvector/pgvector:pg17 | 5432 |
| Valkey | valkey/valkey:9.0-alpine | 6379 |

#### 2단계: 애플리케이션 (Service 서버)

```bash
cd service
docker compose up -d
```

| 서비스 | 설명 | 포트 |
|--------|------|------|
| Nginx | 리버스 프록시, SSL 종단, 보안 헤더 | 80, 443 |
| Backend | Spring Boot API | 8080 (internal) |
| AI | FastAPI 서비스 | 8000 (internal) |

### 서비스 확인

```bash
# 컨테이너 상태
docker ps

# 로그 확인
docker logs <container-name>

# 헬스체크
curl http://localhost:8080/actuator/health  # Backend
curl http://localhost:8000/health           # AI
```

### 서비스 중지

```bash
docker compose down

# 데이터까지 모두 삭제 (주의!)
docker compose down -v
```

## Nginx 보안 설정

### 보안 헤더

| 헤더 | 값 |
|------|-----|
| X-Content-Type-Options | nosniff |
| X-Frame-Options | DENY |
| Strict-Transport-Security | max-age=31536000; includeSubDomains |
| X-XSS-Protection | 1; mode=block |
| Referrer-Policy | strict-origin-when-cross-origin |

### Rate Limiting

| 경로 | 제한 | 비고 |
|------|------|------|
| `/api/v1/auth/` | 5r/m, burst=3 | 브루트포스 방지 |
| `/` (일반 API) | 10r/s, burst=20 | 일반 요청 제한 |
| `/sse/` | 제한 없음 | SSE 장시간 연결 |
| `/api/v1/reports/sync` | 제한 없음 | 장시간 요청 (3분 타임아웃) |

### SSL

- TLSv1.2 / TLSv1.3
- Let's Encrypt 인증서
- HTTP → HTTPS 자동 리다이렉트

## 네트워크 구조

```
[프라이빗 서브넷]                    [퍼블릭 서브넷]
devine-postgres:5432  ←─┐
                         ├─→ devine-backend:8080 ←─┐
devine-valkey:6379    ←─┤                           ├─→ devine-nginx:80/443
                         └─→ devine-ai:8000      ←─┘
```

## 환경 변수

> `.env` 파일은 `.gitignore`로 Git에서 제외됩니다. S3를 통해 팀 내 공유합니다.

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
| `DOCKER_IMAGE_TAG` | 이미지 태그 (기본: latest) |
