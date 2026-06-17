# Gitea

轻量级自托管 Git 服务。

## 部署

```bash
docker compose up -d
```

首次启动会自动完成初始化（数据库迁移、管理员创建），无需手动安装。

## 访问

- **地址**: http://\<your-server-ip\>:3009
- **管理员账号**: `admin` / `admin-tencent`

## 验证

```bash
# 1. 检查容器状态
docker ps --filter name=gitea

# 2. 检查 HTTP 响应
curl -s -o /dev/null -w "%{http_code}" http://localhost:3009

# 3. 检查 API 版本
curl -s http://localhost:3009/api/v1/version

# 4. 检查管理员登录
curl -s -u "admin:admin-tencent" http://localhost:3009/api/v1/user
```

## 配置说明

- 数据库: SQLite3（无需额外数据库服务）
- SSH: 已禁用
- 安装锁: 已启用（跳过安装引导页，首次启动自动初始化）
- 实例域名: `<your-server-ip>`
- 网络: `local_net`（共享网络）

## 初始化原理

容器启动时通过 `init.sh` 自动执行以下步骤：

1. 预写入 `app.ini` 配置文件
2. 以 `git` 用户执行 `gitea migrate` 初始化数据库
3. 创建管理员账户 `admin`
4. 标记初始化完成，后续启动跳过以上步骤

默认数据目录 `gitea-data/` 已在 `.gitignore` 中排除。
