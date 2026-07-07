# Omnigent 自托管部署

[Omnigent](https://github.com/omnigent-ai/omnigent) 是一个开源 AI 代理编排框架，
支持 Claude Code、Codex、Cursor、OpenCode 等多种 AI 编码代理的编排与协作。

本部署方案使用预构建 Docker 镜像，无需本地编译，快速启动完整服务。

## 服务架构

| 服务 | 镜像 | 端口 | 说明 |
|------|------|------|------|
| postgres | postgres:16-alpine | — | 数据库（仅在内部网络） |
| omnigent | ghcr.io/omnigent-ai/omnigent-server | 8000 | FastAPI 服务器 + Web UI |

## 前置条件

- Docker 和 Docker Compose

## 快速部署

```bash
# 1. 进入目录
cd omnigent

# 2. 从模板创建环境变量文件（.env 已在 .gitignore 中，不会提交）
cp .env.example .env

# 3. 编辑 .env，至少修改 POSTGRES_PASSWORD
vim .env

# 4. 运行部署脚本（自动检测已有中间件）
bash deploy.sh
```

`deploy.sh` 会自动完成以下工作：

1. 检查 `local_net` 网络，不存在则创建
2. 检测 `local_net` 中是否已有 Postgres 容器（如 multica 已部署的 pgvector）
3. **有已有 Postgres** → 跳过数据库部署，直接启动 omnigent
4. **无已有 Postgres** → 启动内置 postgres 容器，等待就绪后启动 omnigent

## 首次使用

1. 打开 http://<服务器IP>:8000
2. 默认无认证模式（`OMNIGENT_AUTH_ENABLED=0`），所有请求以 "local" 用户身份操作
3. 如需开启认证，请参考下方进阶配置

## 常用命令

```bash
# 查看所有服务状态
docker compose ps

# 查看某个服务的日志
docker compose logs omnigent
docker compose logs -f omnigent   # 持续跟踪

# 重启某个服务
docker compose restart omnigent

# 停止所有服务
docker compose down

# 停止并删除数据卷
docker compose down -v

# 更新到最新镜像
docker compose pull
bash deploy.sh
```

## 访问地址

| 服务 | 地址 |
|------|------|
| Omnigent UI | http://<服务器IP>:8000 |
| 健康检查 | http://<服务器IP>:8000/health |

## 进阶配置

### 开启认证

默认配置为无认证单用户模式，适合个人使用。如需多用户或生产环境：

**选项 A: 内置账号**

```bash
OMNIGENT_AUTH_ENABLED=1
OMNIGENT_AUTH_PROVIDER=accounts
OMNIGENT_ACCOUNTS_COOKIE_SECRET=<openssl rand -hex 32 生成的密钥>
OMNIGENT_ACCOUNTS_BASE_URL=http://<服务器IP>:8000
```

首次启动会自动创建 admin 用户，密码打印到日志中：

```bash
docker compose logs omnigent | grep "password"
```

**选项 B: OIDC**

支持 GitHub / Google / Okta / Keycloak 等 OIDC 提供商，详见 [官方文档](https://github.com/omnigent-ai/omnigent)。

### 固定镜像版本

生产环境建议固定镜像版本，避免意外更新：

```bash
OMNIGENT_IMAGE_TAG=v0.5.0
```

### 配置 Runner

Omnigent 需要在客户端机器上运行 Runner 来执行 AI 代理。部署完成后：

1. 访问服务器 Web UI
2. 按照页面提示在需要运行 Agent 的机器上安装并启动 Runner
3. Runner 通过 WebSocket 连接到服务器

### 反向代理

如需通过域名 + HTTPS 访问，建议在前面配置反向代理：

```nginx
# Nginx 配置示例
server {
    listen 80;
    server_name omnigent.example.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

官方还提供了 Caddy 自动 HTTPS 方案，详见 `deploy/docker/docker-compose.https.yaml`。

## 数据持久化

| 数据 | 路径 | 说明 |
|------|------|------|
| PostgreSQL | `./data/postgres/` | 数据库文件 |
| Artifacts | `./data/artifacts/` | 文章存储 |

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

- [Omnigent 官方仓库](https://github.com/omnigent-ai/omnigent)
- [部署文档](https://github.com/omnigent-ai/omnigent/tree/main/deploy/docker)
- [自托管指南](https://github.com/omnigent-ai/omnigent/blob/main/SELF_HOSTING.md)
