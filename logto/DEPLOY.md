# Logto Docker Compose 部署指南

## 环境要求

- Docker 20.10+
- Docker Compose 2.0+
- Nginx
- OpenSSL (用于生成自签名证书)

## 部署步骤

### 1. 下载 docker-compose.yml

```bash
curl -fsSL https://raw.githubusercontent.com/logto-io/logto/HEAD/docker-compose.yml -o docker-compose.yml
```

### 2. 修改 docker-compose.yml

生产环境需要配置 HTTPS endpoint 并仅绑定本地端口：

```yaml
services:
  app:
    ports:
      - 127.0.0.1:3001:3001
      - 127.0.0.1:3002:3002
    environment:
      - TRUST_PROXY_HEADER=1
      - DB_URL=postgres://postgres:p0stgr3s@postgres:5432/logto
      - ENDPOINT=https://<公网IP>
      - ADMIN_ENDPOINT=https://<公网IP>
```

### 3. 配置 Nginx HTTPS 反向代理

生成自签名证书（或使用 Let's Encrypt）：

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/logto.key \
  -out /etc/ssl/certs/logto.crt \
  -subj "/CN=<公网IP>"
```

创建 Nginx 配置 `/etc/nginx/sites-available/logto`：

```nginx
server {
    listen 80;
    server_name <公网IP>;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name <公网IP>;

    ssl_certificate /etc/ssl/certs/logto.crt;
    ssl_certificate_key /etc/ssl/private/logto.key;

    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:3002;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api {
        proxy_pass http://127.0.0.1:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

启用配置：

```bash
ln -sf /etc/nginx/sites-available/logto /etc/nginx/sites-enabled/logto
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
```

### 4. 启动服务

```bash
docker compose up -d
```

### 5. 验证服务状态

```bash
docker compose ps
```

### 6. 访问 Logto

- **HTTPS**: https://<公网IP>
- Admin Console: https://<公网IP>/console

## 服务说明

| 服务 | 端口 | 说明 |
|------|------|------|
| app | 3001, 3002 | Logto 应用 (仅本地监听) |
| postgres | 5432 | PostgreSQL 数据库 |
| nginx | 80, 443 | HTTPS 反向代理 |

## 环境变量

| 变量 | 说明 |
|------|------|
| DB_URL | 数据库连接 |
| TRUST_PROXY_HEADER | 信任代理头 |
| ENDPOINT | 外部访问地址 (HTTPS) |
| ADMIN_ENDPOINT | 管理后台外部访问地址 (HTTPS) |

## 停止服务

```bash
docker compose down
```

## 清除数据

```bash
docker compose down -v
```