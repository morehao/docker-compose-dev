# Casdoor 使用说明

## 访问地址

- **Casdoor**: http://localhost:8000

## 默认账号

| 项目 | 值 |
|------|-----|
| 用户名 | `built-in/admin` |
| 密码 | `123` |

> 生产环境请立即修改默认密码

## 数据库配置

| 配置项 | 值 |
|--------|-----|
| 数据库类型 | MySQL |
| 端口 | 3306 |
| 用户名 | root |
| 密码 | 123456 |
| 数据库名 | casdoor |

## 常用命令

### 查看日志

```bash
docker compose logs -f
```

### 查看 Casdoor 日志

```bash
docker compose logs -f casdoor
```

### 重启服务

```bash
docker compose restart
```

### 进入 MySQL

```bash
docker compose exec db mysql -u root -p123456 casdoor
```

### 重建服务

```bash
docker compose down && docker compose up -d --build
```
