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

# 2. 从模板创建环境变量文件（.env 已在 .gitignore 中，不会提交）
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
