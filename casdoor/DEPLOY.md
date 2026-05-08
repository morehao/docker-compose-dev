# Casdoor Docker Compose 部署指南

## 环境要求

- Docker 20.10+
- Docker Compose 2.0+

## 部署步骤

### 1. 启动服务

```bash
cd /root/deploy/casdoor
docker compose up -d
```

### 2. 验证服务状态

```bash
docker compose ps
```

### 3. 访问 Casdoor

- **URL**: http://localhost:8000
- **默认账号**: `built-in/admin`
- **默认密码**: `123`

> 首次登录后请立即修改密码

## 服务说明

| 服务 | 端口 | 说明 |
|------|------|------|
| casdoor | 8000 | Casdoor 应用 |
| db | 3306 | MySQL 数据库 |

## 数据持久化

MySQL 数据存储在 Docker volume 中，删除容器不会丢失数据。

## 停止服务

```bash
docker compose down
```

## 清除数据

```bash
docker compose down -v
```

> 注意：这会删除 MySQL 数据库数据
