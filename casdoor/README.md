# Casdoor Docker Compose 部署指南

## 环境要求

- Docker 20.10+
- Docker Compose 2.0+

## 快速启动

```bash
cd /root/morehao/docker-compose-dev/casdoor
docker compose up -d
```

## 目录结构

```
casdoor/
├── config/          # Casdoor 配置文件（挂载到容器内 /conf/）
├── data/            # MySQL 数据持久化目录
├── docker-compose.yml
└── README.md
```

## 验证部署

```bash
# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f
```

## 访问服务

| 服务 | 地址 | 说明 |
|------|------|------|
| Casdoor | http://localhost:8000 | Web 管理界面 |
| MySQL | localhost:3306 | 数据库（可选） |

### 默认账号

| 项目 | 值 |
|------|-----|
| 组织 | `built-in` |
| 用户名 | `admin` |
| 密码 | `123` |

> 首次登录后请立即修改默认密码

## 配置文件

Casdoor 配置文件位于 `./config/app.conf`，挂载到容器内的 `/conf/app.conf`。

主要配置项：

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| httpport | 8000 | HTTP 端口 |
| driverName | mysql | 数据库驱动 |
| dataSourceName | root:123456@tcp(localhost:3306)/ | 数据库连接字符串 |
| dbName | casdoor | 数据库名 |

修改配置后需重启服务：

```bash
docker compose restart casdoor
```

## 常用命令

### 查看日志

```bash
# 查看所有服务日志
docker compose logs -f

# 仅查看 Casdoor 日志
docker compose logs -f casdoor

# 仅查看数据库日志
docker compose logs -f db
```

### 重启服务

```bash
docker compose restart
```

### 停止服务

```bash
docker compose down
```

### 清除数据（重置）

```bash
docker compose down -v
```

> 注意：这会删除 MySQL 数据库所有数据

### 重建服务（代码更新后）

```bash
docker compose down && docker compose up -d --build
```

## 数据库连接

如需从主机连接 MySQL：

```bash
mysql -h localhost -P 3306 -u root -p123456 casdoor
```

## 健康检查

服务启动后会自动进行健康检查，确保依赖服务就绪后再启动 Casdoor：

- MySQL：等待 MySQL 可响应 `mysqladmin ping`
- Casdoor：等待 OIDC 配置端点可访问

## 故障排查

### 端口冲突

如果 8000 或 3306 端口已被占用：

```bash
# 查看端口占用
lsof -i :8000
lsof -i :3306

# 修改 docker-compose.yml 中的端口映射
```

### 查看容器内部状态

```bash
# 进入 Casdoor 容器
docker compose exec casdoor sh

# 进入 MySQL 容器
docker compose exec db mysql -u root -p123456 casdoor
```

### 查看网络

```bash
docker network ls
docker network inspect local_net
```

## 技术栈

- **Casdoor**: Go + Beego Web 框架
- **前端**: Node.js 构建
- **数据库**: MySQL 8.0.25