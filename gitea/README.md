# Gitea

轻量级自托管 Git 服务，支持通过 Ark IAM 统一登录（OIDC SSO）。

## 部署

```bash
cp .env.example .env   # 首次：填写 Ark IAM client_secret 等
docker compose up -d
```

首次启动会自动完成初始化（数据库迁移、管理员创建、Ark IAM 登录源创建），无需手动安装。

## 访问

- **地址**: http://localhost:3009
- **管理员账号**: `admin` / `admin-tencent`
- **登录方式**: 本地账号，或点击「Ark IAM」用 Ark IAM 账号登录（首次自动建号）

## OIDC 接入 Ark IAM

### 前置

1. Ark IAM 以 gateway 方式运行在 `http://localhost:8100`。
2. 在 Ark IAM 控制台创建：
   - 应用 `gitea`，声明角色模板 `roleTemplate`：
     `[{"code":"gitea_admin","name":"Gitea 管理员"},{"code":"gitea_restricted","name":"Gitea 受限用户"}]`
   - OAuth 客户端 `gitea_console`：
     - redirectURIs：`["http://localhost:3009/user/oauth2/ark-iam/callback"]`
     - grantTypes：`["authorization_code"]`
     - responseTypes：`["code"]`
     - tokenEndpointAuthMethod：`client_secret_basic`
     - requirePKCE：`false`（Gitea 的 goth 客户端不支持 PKCE）
     - defaultScopes：`["openid","profile","email"]`
   - 创建密钥，把明文填入 `.env` 的 `GITEA_OIDC_CLIENT_SECRET`
3. 开通 `gitea` 应用到租户 `t_platform`，并在租户控制台把 `gitea_admin` / `gitea_restricted`
   授权给相应成员（不授权则 `groups` 为空 → 非管理员/非受限）。

### 启动

```bash
cp .env.example .env   # 填 GITEA_OIDC_CLIENT_SECRET
docker compose up -d
```

容器以 `network_mode: host` 运行，与 `rustfs` 一致：容器内 `localhost:8100` 即宿主机 gateway，
issuer 统一为 `http://localhost:8100/oidc`，可与 RustFS 共享 SSO 会话。

`init.sh` 首次初始化时通过 `gitea admin auth add-oauth` 创建登录源，读取 `.env`：

| 变量 | 默认 | 说明 |
|---|---|---|
| `GITEA_OIDC_CLIENT_ID` | - | OIDC client_id（= `gitea_console`） |
| `GITEA_OIDC_CLIENT_SECRET` | - | client_secret（仅存 `.env`，不入库） |
| `GITEA_OIDC_DISCOVERY_URL` | `http://localhost:8100/oidc/.well-known/openid-configuration` | discovery 地址 |
| `GITEA_OIDC_SCOPES` | `openid,profile,email` | 必须含 `profile`（`groups` 声明依赖） |
| `GITEA_OIDC_GROUP_CLAIM_NAME` | `groups` | 角色声明名 |
| `GITEA_OIDC_ADMIN_GROUP` | `gitea_admin` | 命中则设为 Gitea 管理员 |
| `GITEA_OIDC_RESTRICTED_GROUP` | `gitea_restricted` | 命中则设为受限用户 |

> `USERNAME=preferred_username`、`ENABLE_AUTO_REGISTRATION=true`、`OPENID_CONNECT_SCOPES` 等
> 全局项由 compose 的 `GITEA__oauth2_client__*` 环境变量经 entrypoint 写入 `app.ini`。

### 验证

```bash
# 1. discovery 可达（容器内 localhost = 宿主机）
curl -s http://localhost:8100/oidc/.well-known/openid-configuration

# 2. 登录源已创建
docker exec gitea su git -c "gitea admin auth list"

# 3. 浏览器访问 http://localhost:3009 → 登录页出现 Ark IAM 入口
```

### 已初始化环境的补建

`init.sh` 的登录源创建只在首次初始化（`/data/gitea/.initialized` 不存在）时执行。
若容器已初始化后才补 OIDC 配置，直接在运行中的容器手动创建：

```bash
docker exec gitea su git -c "gitea admin auth add-oauth \
  --name ark-iam --provider openidConnect --key gitea_console \
  --secret <client_secret> \
  --auto-discover-url http://localhost:8100/oidc/.well-known/openid-configuration \
  --scopes openid,profile,email \
  --group-claim-name groups --admin-group gitea_admin --restricted-group gitea_restricted"
```

## 验证（本地账号）

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
- 实例域名: `${GITEA_DOMAIN:-localhost}`
- 网络: `network_mode: host`（与 `rustfs` 一致，便于统一 SSO）

## 初始化原理

容器启动时通过 `init.sh` 自动执行以下步骤：

1. 预写入 `app.ini` 配置文件
2. 以 `git` 用户执行 `gitea migrate` 初始化数据库
3. 创建管理员账户 `admin`
4. 若配置了 `GITEA_OIDC_CLIENT_ID/SECRET`，通过 `gitea admin auth add-oauth` 创建 Ark IAM 登录源
5. 标记初始化完成，后续启动跳过以上步骤

默认数据目录 `gitea-data/` 已在 `.gitignore` 中排除；`.env` 同样被忽略，`client_secret` 不入库。
