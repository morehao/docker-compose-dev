# Logto 使用说明

## 访问地址

- **Admin Console**: http://localhost:3002
- **API Endpoint**: http://localhost:3001

## 初始化账号

首次访问 http://localhost:3002 会引导创建管理员账号。

## 默认配置

| 配置项 | 值 |
|--------|-----|
| 数据库用户 | postgres |
| 数据库密码 | p0stgr3s |
| 数据库名 | logto |
| PostgreSQL 端口 | 5432 |

## 常用命令

### 查看日志

```bash
docker compose logs -f app
```

### 重启服务

```bash
docker compose restart app
```

### 进入数据库

```bash
docker compose exec postgres psql -U postgres -d logto
```

## 端口说明

- **3001**: OIDC Provider 和 Management API
- **3002**: Admin Console (管理后台)