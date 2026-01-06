# DeVine Deploy

DeVine 프로젝트의 배포 설정을 관리하는 레포지토리입니다.

## 프로젝트 구조

```
DeVine_Deploy/
├── db/                     # 데이터베이스 관련 설정
│   ├── docker-compose.yml  # PostgreSQL, Redis 컨테이너 설정
│   └── .env                # 환경 변수 예제
├── service/                # 애플리케이션 서비스 설정
│   ├── docker-compose.yml  # Backend, AI, Nginx 컨테이너 설정
│   └── .env
└── README.md
```

## 시작하기

- Docker 20.10+
- Docker Compose 2.0+

### 환경 설정

1. 환경 변수 파일 생성

```bash
s3 파일 공유하도록 함
```



### 배포 순서

#### 1단계: 데이터베이스 실행

```bash
cd db
docker-compose up -d
```

- PostgreSQL (포트 5432)
- Redis (포트 6379)

#### 2단계: 애플리케이션 서비스 실행

```bash
cd ../service
docker-compose up -d
```

- DeVine Backend (Spring Boot, 포트 8080)
- DeVine AI (FastAPI, 포트 8000)
- [적용전] Nginx (포트 80, 443)

### 서비스 확인

```bash
# 모든 컨테이너 상태 확인
docker ps

# 로그 확인
docker logs <container-name>

# 헬스체크 확인
curl http://localhost:8080/actuator/health  # Backend
curl http://localhost:8000/health           # AI

# 네트워크 확인
docker network ls
docker network inspect devine-network
```

### 서비스 중지

```bash
# 애플리케이션 서비스 중지
cd service # 프로젝트 경로
docker-compose down

# 데이터까지 모두 삭제 (주의!)
docker-compose down -v
```

## 네트워크 구조

```
devine-postgres:5432  ←─┐
                         ├─→ devine-backend:8080 ←─┐
devine-redis:6379     ←─┤                           ├─→ devine-nginx:80/443
                         └─→ devine-ai:8000      ←─┘
```
