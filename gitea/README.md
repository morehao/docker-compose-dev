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
- **本地应急账号**: `gitea_admin` / `giteaadmin123`（`init.sh` 创建，Gitea 管理员；Ark IAM 不可用时用它进后台）
- **`admin` 用户名留给 Ark IAM SSO**：首次点击「Ark IAM」按 `preferred_username`（IAM 侧就是 `admin`）**即时建号（JIT）**，此后每次登录都命中该账号。**本地账号不要取 `admin`**——与 SSO 身份同名时 Gitea 无法直接登录，会落到「关联账号」页要求手工绑定。
- **登录方式**: 本地账号（`gitea_admin`），或点「Ark IAM」用 Ark IAM 账号登录（首次即时建号，无需手工关联）
- **一键 SSO 入口（建议收藏）**: <http://localhost:3009/user/oauth2/ark-iam> —— 直接打开即走 OIDC：浏览器里有有效中心会话（`iam_sso_session`）时**免密直进**，没有时才跳 IAM 登录页。等价于点登录页的「Ark IAM」按钮。
- **为什么不开启 Gitea 的自动跳转**: 访问 `:3009` 时 Gitea 只显示自己的登录页、不会自动跳 OIDC（标准 RP 行为，SSO 由 RP 发起）。Gitea 的自动跳转条件是 `performAutoLoginOAuth2`（`routers/web/auth/auth.go:221`）要求的「唯一 OAuth2 源 + `ENABLE_PASSWORD_SIGNIN_FORM=false` + `ENABLE_PASSKEY_AUTHENTICATION=false`」，其中**关掉密码表单会让本地应急账号无法从 Web 登录**，与上一行的应急入口冲突，故不采用。

## OIDC 接入 Ark IAM

### 前置

1. Ark IAM 以 gateway 方式运行在 `http://localhost:8100`。
2. 在 Ark IAM 控制台创建：
   - 应用 `gitea`，声明角色模板 `roleTemplate`：
     `[{"code":"gitea_admin","name":"Gitea 管理员"},{"code":"gitea_restricted","name":"Gitea 受限用户"}]`
   - OAuth 客户端 `gitea_console`：
     - redirectURIs：`["http://localhost:3009/user/oauth2/ark-iam/callback"]`
     - postLogoutRedirectURIs：`["http://localhost:3009/"]` ← **必填**。Gitea 退出登录会做 RP-Initiated Logout（`buildOIDCEndSessionURL`：`end_session?client_id=…&post_logout_redirect_uri=<AppURL>/`），IAM 按**精确匹配**校验该白名单，不填会返回 `{"error":"invalid_request","error_description":"post_logout_redirect_uri invalid"}`
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

`init.sh` 首次初始化时读取 `.env`（创建本地应急账号 + 通过 `gitea admin auth add-oauth` 创建登录源）：

| 变量 | 默认 | 说明 |
|---|---|---|
| `GITEA_ADMIN_USERNAME` | `gitea_admin` | 本地应急账号用户名（**不得与 IAM 的 `preferred_username`（`admin`）同名**） |
| `GITEA_ADMIN_PASSWORD` | - | 本地应急账号口令（建号时用；改已初始化实例的口令见下方 `change-password`） |
| `GITEA_OIDC_CLIENT_ID` | - | OIDC client_id（= `gitea_console`） |
| `GITEA_OIDC_CLIENT_SECRET` | - | client_secret（`init.sh` 写入 Gitea 登录源；IAM 侧只存哈希） |
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

已初始化后要**更换** client_secret（例如在 Ark IAM 控制台重新生成了密钥），用 `update-oauth` 就地更新，**不要**删 `.initialized` 重建——那会连同本地账号一起重建：

```bash
docker exec -u git gitea gitea admin auth list        # 取登录源 ID（通常为 1）
docker exec -u git gitea gitea admin auth update-oauth --id 1 --secret <新的 client_secret>
# 记得同步改 .env 的 GITEA_OIDC_CLIENT_SECRET，否则下次重建数据目录会退回旧密钥
```

已初始化后要**重置**本地账号口令：

```bash
# --must-change-password=false 避免下次登录被强制改密
docker exec -u git gitea gitea admin user change-password \
  --username gitea_admin --password '<新口令>' --must-change-password=false
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
curl -s -u "gitea_admin:giteaadmin123" http://localhost:3009/api/v1/user
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
3. 创建**本地管理员**账户 `${GITEA_ADMIN_USERNAME:-gitea_admin}`（口令取自 `GITEA_ADMIN_PASSWORD`；**用户名不要与 IAM 的 `preferred_username`（`admin`）同名**，否则 SSO 首次登录会落到「关联账号」页）
4. 若配置了 `GITEA_OIDC_CLIENT_ID/SECRET`，通过 `gitea admin auth add-oauth` 创建 Ark IAM 登录源
5. 标记初始化完成，后续启动跳过以上步骤

> **两个容易踩的前提**（缺一则初始化建不出可用账号/登录源）：
> - `GITEA_ADMIN_USERNAME` / `GITEA_ADMIN_PASSWORD` 必须由 compose **透传进容器**（`init.sh` 直接读这两个变量）。**不要**用 `GITEA__admin__USERNAME/PASSWORD/EMAIL`——Gitea 没有 `[admin]` 配置段，那组变量不生效，只会往 `app.ini` 里塞一个被忽略的 `[admin]` 段（compose 里已移除）。
> - `init.sh` 只在 `/data/gitea/.initialized` 不存在（全新数据目录）时执行。已初始化的实例改 `.env` 不生效，登录源要用 `gitea admin auth update-oauth` 更新、口令要用 `gitea admin user change-password` 更新。

默认数据目录 `gitea-data/` 已在 `.gitignore` 中排除；`.env` 同样被忽略，`client_secret` 不入库。
