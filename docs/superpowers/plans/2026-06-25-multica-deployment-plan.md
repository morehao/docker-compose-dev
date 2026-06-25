# Multica 自托管部署实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `docker-compose-dev/multica/` 下创建 Multica 完整自托管部署方案，支持拉取预构建镜像一键启动

**Architecture:** 4 个容器（postgres + redis + backend + frontend）通过共享 `local_net` 通信，端口绑定 `127.0.0.1`，数据持久化使用 bind mount。遵循 docker-compose-dev 现有规范。

**Tech Stack:** Docker Compose, PostgreSQL 17 + pgvector, Redis 7, Go backend, Next.js frontend

---

## 文件结构

```
multica/
├── docker-compose.yml    # 主 compose 文件
├── .env.example          # 环境变量模板（精简核心变量）
├── README.md             # 中文部署文档
└── data/                 # 数据目录 (gitignored)
    ├── postgres/
    └── uploads/
```

---

### Task 1: 创建目录结构

**Files:**
- Create: `multica/` 目录
- Create: `multica/data/` 目录
- Create: `multica/data/.gitkeep`

- [ ] **Step 1: 创建目录和 .gitkeep**

```bash
mkdir -p /root/morehao/docker-compose-dev/multica/data/postgres /root/morehao/docker-compose-dev/multica/data/uploads
touch /root/morehao/docker-compose-dev/multica/data/.gitkeep
```

---

### Task 2: 编写 docker-compose.yml

**Files:**
- Create: `multica/docker-compose.yml`

- [ ] **Step 1: 创建 docker-compose.yml**

```yaml
# Multica 完整自托管部署
# 使用预构建镜像从 GHCR 拉取，无需本地构建
#
# 前置条件:
#   docker network create local_net
#
# 快速开始:
#   cp .env.example .env
#   编辑 .env，至少修改 JWT_SECRET 和 POSTGRES_PASSWORD
#   docker compose up -d
#
# 访问地址:
#   Frontend: http://localhost:3000
#   Backend:  http://localhost:8080

name: multica

services:
  postgres:
    image: pgvector/pgvector:pg17
    container_name: multica-postgres
    ports:
      - "127.0.0.1:5432:5432"
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-multica}
      POSTGRES_USER: ${POSTGRES_USER:-multica}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-changeme}
    shm_size: 1g
    networks:
      - local_net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-multica} -d ${POSTGRES_DB:-multica}"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: multica-redis
    ports:
      - "127.0.0.1:6379:6379"
    volumes:
      - ./data/redis:/data
    networks:
      - local_net
    restart: unless-stopped

  backend:
    image: ${MULTICA_BACKEND_IMAGE:-ghcr.io/multica-ai/multica-backend}:${MULTICA_IMAGE_TAG:-latest}
    container_name: multica-backend
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "127.0.0.1:${BACKEND_PORT:-8080}:8080"
    volumes:
      - ./data/uploads:/app/data/uploads
    environment:
      DATABASE_URL: postgres://${POSTGRES_USER:-multica}:${POSTGRES_PASSWORD:-changeme}@postgres:5432/${POSTGRES_DB:-multica}?sslmode=disable
      REDIS_URL: redis://redis:6379/0
      PORT: "8080"
      JWT_SECRET: ${JWT_SECRET:-change-me-in-production}
      APP_ENV: ${APP_ENV:-production}
      FRONTEND_ORIGIN: ${FRONTEND_ORIGIN:-http://localhost:3000}
      CORS_ALLOWED_ORIGINS: ${CORS_ALLOWED_ORIGINS:-}
      RESEND_API_KEY: ${RESEND_API_KEY:-}
      RESEND_FROM_EMAIL: ${RESEND_FROM_EMAIL:-noreply@multica.ai}
      SMTP_HOST: ${SMTP_HOST:-}
      SMTP_PORT: ${SMTP_PORT:-25}
      SMTP_USERNAME: ${SMTP_USERNAME:-}
      SMTP_PASSWORD: ${SMTP_PASSWORD:-}
      SMTP_TLS: ${SMTP_TLS:-}
      SMTP_TLS_INSECURE: ${SMTP_TLS_INSECURE:-false}
      SMTP_EHLO_NAME: ${SMTP_EHLO_NAME:-}
      GOOGLE_CLIENT_ID: ${GOOGLE_CLIENT_ID:-}
      GOOGLE_CLIENT_SECRET: ${GOOGLE_CLIENT_SECRET:-}
      GOOGLE_REDIRECT_URI: ${GOOGLE_REDIRECT_URI:-http://localhost:3000/auth/callback}
      S3_BUCKET: ${S3_BUCKET:-}
      S3_REGION: ${S3_REGION:-us-west-2}
      AWS_ENDPOINT_URL: ${AWS_ENDPOINT_URL:-}
      AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:-}
      AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY:-}
      ATTACHMENT_DOWNLOAD_MODE: ${ATTACHMENT_DOWNLOAD_MODE:-auto}
      ATTACHMENT_DOWNLOAD_URL_TTL: ${ATTACHMENT_DOWNLOAD_URL_TTL:-30m}
      CLOUDFRONT_DOMAIN: ${CLOUDFRONT_DOMAIN:-}
      CLOUDFRONT_KEY_PAIR_ID: ${CLOUDFRONT_KEY_PAIR_ID:-}
      CLOUDFRONT_PRIVATE_KEY: ${CLOUDFRONT_PRIVATE_KEY:-}
      COOKIE_DOMAIN: ${COOKIE_DOMAIN:-}
      MULTICA_DEV_VERIFICATION_CODE: ${MULTICA_DEV_VERIFICATION_CODE:-}
      MULTICA_APP_URL: ${MULTICA_APP_URL:-http://localhost:3000}
      ALLOW_SIGNUP: ${ALLOW_SIGNUP:-true}
      ALLOWED_EMAILS: ${ALLOWED_EMAILS:-}
      ALLOWED_EMAIL_DOMAINS: ${ALLOWED_EMAIL_DOMAINS:-}
      DISABLE_WORKSPACE_CREATION: ${DISABLE_WORKSPACE_CREATION:-}
      MULTICA_PUBLIC_URL: ${MULTICA_PUBLIC_URL:-}
      MULTICA_TRUSTED_PROXIES: ${MULTICA_TRUSTED_PROXIES:-}
      MULTICA_FEATURE_FLAGS_FILE: ${MULTICA_FEATURE_FLAGS_FILE:-}
    networks:
      - local_net
    restart: unless-stopped

  frontend:
    image: ${MULTICA_WEB_IMAGE:-ghcr.io/multica-ai/multica-web}:${MULTICA_IMAGE_TAG:-latest}
    container_name: multica-frontend
    depends_on:
      - backend
    ports:
      - "127.0.0.1:${FRONTEND_PORT:-3000}:3000"
    environment:
      HOSTNAME: "0.0.0.0"
    networks:
      - local_net
    restart: unless-stopped

networks:
  local_net:
    external: true
```

- [ ] **Step 2: 验证 docker-compose.yml 语法**

```bash
docker compose -f /root/morehao/docker-compose-dev/multica/docker-compose.yml config
```

Expected: 无错误输出，显示完整的配置（不含外部网络检查）

---

### Task 3: 编写 .env.example

**Files:**
- Create: `multica/.env.example`

- [ ] **Step 1: 创建 .env.example**

```bash
cat > /root/morehao/docker-compose-dev/multica/.env.example << 'ENVEOF'
# ============================================
# Multica 自托管部署环境变量
# ============================================

# --- 数据库 ---
POSTGRES_DB=multica
POSTGRES_USER=multica
POSTGRES_PASSWORD=changeme

# --- 服务端口 ---
BACKEND_PORT=8080
FRONTEND_PORT=3000

# --- JWT 密钥（必须修改！） ---
JWT_SECRET=change-me-in-production

# --- 环境模式 ---
# production: 生产模式，无固定验证码
# development: 开发模式，可配合 MULTICA_DEV_VERIFICATION_CODE 使用固定验证码
APP_ENV=production

# --- 开发验证码（仅 APP_ENV=development 时生效） ---
# MULTICA_DEV_VERIFICATION_CODE=888888

# --- 邮件服务（二选一） ---
# 选项 A: Resend (SaaS)
# RESEND_API_KEY=re_xxxxx
# RESEND_FROM_EMAIL=noreply@multica.ai

# 选项 B: SMTP 中继（优先级高于 Resend）
# SMTP_HOST=smtp.example.com
# SMTP_PORT=25
# SMTP_USERNAME=
# SMTP_PASSWORD=
# SMTP_TLS=
# SMTP_TLS_INSECURE=false

# --- Google OAuth ---
# GOOGLE_CLIENT_ID=xxxxx.apps.googleusercontent.com
# GOOGLE_CLIENT_SECRET=xxxxx
# GOOGLE_REDIRECT_URI=http://localhost:3000/auth/callback

# --- S3 兼容存储（文件附件） ---
# S3_BUCKET=my-bucket
# S3_REGION=us-west-2
# AWS_ENDPOINT_URL=http://minio:9000
# AWS_ACCESS_KEY_ID=minioadmin
# AWS_SECRET_ACCESS_KEY=minioadmin
# ATTACHMENT_DOWNLOAD_MODE=auto

# --- 注册控制 ---
ALLOW_SIGNUP=true
# ALLOWED_EMAILS=user1@example.com,user2@example.com
# ALLOWED_EMAIL_DOMAINS=example.com
# DISABLE_WORKSPACE_CREATION=true

# --- 镜像标签（默认 latest，可固定版本如 v0.2.4） ---
# MULTICA_IMAGE_TAG=latest

# --- 高级 ---
# MULTICA_PUBLIC_URL=https://api.example.com
# MULTICA_TRUSTED_PROXIES=127.0.0.1/32
# MULTICA_FEATURE_FLAGS_FILE=
ENVEOF
```

---

### Task 4: 编写 README.md（中文部署文档）

**Files:**
- Create: `multica/README.md`

- [ ] **Step 1: 创建 README.md**

```markdown
# Multica 自托管部署

[Multica](https://github.com/multica-ai/multica) 是一个 AI 原生团队任务管理平台，
AI Agent 可作为第一类负责人被分配任务、评论和变更状态。

本部署方案使用预构建 Docker 镜像，无需本地编译，快速启动完整服务。

## 服务架构

| 服务 | 镜像 | 端口 | 说明 |
|------|------|------|------|
| postgres | pgvector/pgvector:pg17 | 5432 | 数据库（含 pgvector） |
| redis | redis:7-alpine | 6379 | 缓存与实时消息 fan-out |
| backend | ghcr.io/multica-ai/multica-backend | 8080 | Go API + WebSocket |
| frontend | ghcr.io/multica-ai/multica-web | 3000 | Next.js 前端 |

## 前置条件

- Docker 和 Docker Compose
- 共享网络 `local_net`（如未创建）：

```bash
docker network create local_net
```

## 快速部署

```bash
# 1. 进入目录
cd multica

# 2. 从模板创建环境变量文件
cp .env.example .env

# 3. 编辑 .env，至少修改以下值：
#    - JWT_SECRET: 生成随机密钥（openssl rand -hex 32）
#    - POSTGRES_PASSWORD: 修改数据库密码
vim .env

# 4. 启动所有服务
docker compose up -d

# 5. 查看启动日志
docker compose logs -f
```

## 首次登录

1. 打开 http://localhost:3000
2. 输入你的邮箱地址
3. 获取验证码的方式取决于邮件配置：
   - **有 RESEND_API_KEY**: 验证码会发送到对应邮箱
   - **无邮件配置**: 查看后端日志获取验证码：
     ```bash
     docker compose logs backend | grep "Verification code"
     ```
   - **开发模式固定码**: 设置 `APP_ENV=development` 和 `MULTICA_DEV_VERIFICATION_CODE=888888`

## 常用命令

```bash
# 查看所有服务状态
docker compose ps

# 查看某个服务的日志
docker compose logs backend
docker compose logs -f backend   # 持续跟踪

# 重启某个服务
docker compose restart backend

# 停止所有服务
docker compose down

# 停止并删除数据卷
docker compose down -v

# 更新到最新镜像
docker compose pull
docker compose up -d
```

## 访问地址

| 服务 | 地址 |
|------|------|
| 前端 UI | http://localhost:3000 |
| 后端 API | http://localhost:8080 |
| 健康检查 | http://localhost:8080/health |

所有端口仅绑定到 `127.0.0.1`（本地回环），如需公网访问，
请在前面配置反向代理（Caddy / nginx / Cloudflare Tunnel）。

## 进阶配置

### 邮件服务

生产环境建议配置邮件服务，否则每次登录需从后端日志获取验证码。

**Resend（推荐）:**
```bash
RESEND_API_KEY=re_xxxxxxxxxxxx
RESEND_FROM_EMAIL=noreply@yourdomain.com
```

**SMTP:**
```bash
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=your-username
SMTP_PASSWORD=your-password
SMTP_TLS=starttls
```

### Google OAuth

在 Google Cloud Console 创建 OAuth 应用，配置：
```bash
GOOGLE_CLIENT_ID=xxxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=xxxxx
GOOGLE_REDIRECT_URI=http://localhost:3000/auth/callback
```

### S3 文件存储

默认文件存储在本地 `./data/uploads`。如需使用 S3 兼容存储（如 MinIO）：
```bash
S3_BUCKET=my-bucket
S3_REGION=us-west-2
AWS_ENDPOINT_URL=http://minio:9000
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=minioadmin
```

### 反向代理

由于所有端口仅绑定到 127.0.0.1，外网访问需配置反向代理：

```nginx
# Nginx 配置示例
server {
    listen 80;
    server_name multica.example.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8080;
    }

    location /ws {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## 数据持久化

| 数据 | 路径 | 说明 |
|------|------|------|
| PostgreSQL | `./data/postgres/` | 数据库文件 |
| Redis | `./data/redis/` | 缓存数据 |
| 上传文件 | `./data/uploads/` | 附件存储 |

这些目录已在 `.gitignore` 中排除，不会提交到版本控制。

## 更新

```bash
# 拉取最新镜像
docker compose pull

# 重新创建容器（使用新镜像）
docker compose up -d

# 清理旧镜像
docker image prune
```

## 参考链接

- [Multica 官方文档](https://github.com/multica-ai/multica)
- [自托管指南](https://github.com/multica-ai/multica/blob/main/SELF_HOSTING.md)
- [高级配置](https://github.com/multica-ai/multica/blob/main/SELF_HOSTING_ADVANCED.md)
```

---

### Task 5: 验证完整性

**Files:**
- Review: 所有已创建文件

- [ ] **Step 1: 验证文件结构**

```bash
ls -la /root/morehao/docker-compose-dev/multica/
ls -la /root/morehao/docker-compose-dev/multica/data/
```

Expected: 显示 `docker-compose.yml`, `.env.example`, `README.md`, `data/` 目录

- [ ] **Step 2: 验证 docker-compose 配置**

```bash
docker compose -f /root/morehao/docker-compose-dev/multica/docker-compose.yml config 2>&1
```

Expected: 输出完整的服务配置（网络 `local_net` 未创建时会报外部网络 warning，但不影响启动）

- [ ] **Step 3: 检查 .env.example 关键变量**

确认包含: POSTGRES_PASSWORD, JWT_SECRET, APP_ENV, BACKEND_PORT, FRONTEND_PORT

- [ ] **Step 4: 提交到 git**

```bash
cd /root/morehao/docker-compose-dev
git add multica/
git commit -m "feat(multica): add full self-hosted deployment with Docker Compose"
```
