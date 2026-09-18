# RustFS

兼容 S3 协议的自托管对象存储，支持通过 Ark IAM 统一登录（OIDC SSO）。

## 部署

```bash
cp .env.example .env   # 首次：填写 RUSTFS_OIDC_CLIENT_SECRET
docker compose up -d
```

首次启动后还需**供给策略**（见「策略供给」）——否则 OIDC 用户登录会被直接拒绝。

## 访问

- **控制台**: <http://localhost:9011/rustfs/console/>
- **S3 API**: <http://localhost:9010>
- **存储根凭证**: `rustfsadmin` / `rustfsadmin`（`.env` 可改；仅本地开发，不得公网暴露）
- **登录方式**: 根凭证本地登录（Ark IAM 不可用时应急），或控制台点「Ark IAM」用 Ark IAM 账号登录。
- **一键 SSO 入口（建议收藏）**: <http://localhost:9011/rustfs/admin/v3/oidc/authorize/default>
  —— 直接打开即走 OIDC：浏览器里有有效中心会话（`iam_sso_session`）时**免密直进**，没有时才跳 IAM 登录页。
  等价于点控制台登录页的「Ark IAM」按钮。

## 进入方式与会话行为

RustFS 控制台是**标准 RP，不会自动发起 OIDC**，所以「别的应用登录过」只免掉**输密码**，
不免掉**点一下**：

| 当前状态 | 打开 `/rustfs/console/` 的结果 |
|---|---|
| 只有中心会话（别的应用登录过），RustFS 无会话 | 落到 RustFS 登录页（并弹 `Your session has expired`，实为「本地无会话」的误导文案）→ 点「Ark IAM」→ **免密**进主页面 |
| RustFS 控制台会话仍有效（1 小时内登录过） | **直接进主页面**，零点击 |
| 想确保零点击 | 用上面的「一键 SSO 入口」直达链接 |

会话有效期 **1 小时**：RustFS 换取的是临时 STS 凭证（`exp − now = 3600s`），
过期后回到登录页，再点一次即可（中心会话未过期时仍免密）。

> 依据（控制台前端）：`DashboardAuthGuard` 未认证时 `router.replace("/auth/login/?unauthorized=true")`
> 而不是跳 OIDC；登录页 `useEffect` 只调 `fetchOidcProviders` 渲染按钮，
> `initiateOidcLogin` 仅挂在按钮点击回调 `onOidcLogin` 上。

## 登出行为（单点登出做到哪一步）

| 你在哪里点登出 | 结果 |
|---|---|
| **RustFS 控制台**（当初是 OIDC 登录的） | 跳 ark-iam `end_session` → **中心会话被清除** → Gitea / 其它应用下次访问都要重新登录（已实测） |
| **RustFS 控制台**（当初是根凭证登录的） | 只清本地，不跳 IdP —— 这种会话没有 `logoutToken` |
| **Gitea / ark-iam 控制台** | **RustFS 控制台会话不受影响**，最长再存活到自己的 STS 到期（1 小时） |

方向不对称的根因：

- **RP-Initiated Logout（RP → IdP）**：RustFS **支持** ✅ —— 控制台登出会带 `id_token_hint` +
  `post_logout_redirect_uri` 跳到 IdP 的 `end_session`。
- **Back-Channel Logout（IdP → RP）**：RustFS **不支持** ❌ —— 源码里没有接收 `logout_token` 的端点；
  它内部的 "logout token" 只是自己签给自己、供登出跳转用的一次性票据
  （`crates/iam/src/oidc.rs:1425/1446`），与 OIDC 背信道登出规范无关。

> 这不是 RustFS 独有的：绝大多数自托管 RP（含 Gitea）都只做前者。
> ark-iam 侧**具备**发送能力（客户端有 `backChannelLogoutURI` 字段，OP 有 `logout_worker` 真的 POST），
> 它自己的两个控制台就配了这个地址；RustFS / Gitea 缺的是**接收端**。

### 需要「别处登出 → RustFS 立即失效」时的零改动做法

RustFS 没有独立的会话存储 —— **STS 凭证本身就是会话**，删掉 STS 账号即立即失效
（`rustfs/src/admin/handlers/idp_compat.rs:195`）。所以可以用现成 admin API 从外部吊销：

```bash
# parent = 该用户的 OIDC 虚拟身份（issuer+sub 的哈希），即 session token 里的 parent 声明
curl -X POST "http://127.0.0.1:9010/rustfs/admin/v3/revoke-tokens/builtin?user=<parent>&fullRevoke=true" \
     --aws-sigv4 "aws:amz:us-east-1:s3" --user "rustfsadmin:rustfsadmin"
```

实测：`{"revoked":16,...}`，调用后该 parent 名下所有 STS 凭证**当场失效**
（此前累积的 16 个会话一并删除）。

⚠ **provider 段要填 `builtin`，不是 `openid`**：实测 `openid` 返回 `revoked:0`。
原因是 OIDC 的 STS 凭证落库时没有持久化 claims，`guess_user_provider` 只能按
`classify_provider_from_claims` 回落成 `builtin`（`rustfs/src/admin/access_key_identity.rs:303`）。

这只是**能力**，ark-iam 不会自动调它。要真正自动，需要有个触发方（例如一个把
back-channel logout 通知转成上面这次调用的极薄 shim）—— 这属于新增组件，RustFS 侧仍然零改动。

## 统一登录（OIDC SSO）原理

容器以 `network_mode: host` 运行，容器内 `localhost:8100` 即宿主机上的 Ark IAM gateway，
因此：

- OIDC issuer 统一为 `http://localhost:8100/oidc`：浏览器与容器都走 loopback，不经过系统代理。
- SSO 会话 cookie（`iam_sso_session`）落在 host `localhost`，与登录页 `localhost:4000`、
  Gitea `localhost:3009` 同源 —— **登录一次即可在 Ark IAM 控制台 / Gitea / RustFS 之间免密跳转**。

权限映射链路：

```
rustfs_console 登录 → ID token 的 groups（= rustfs_local 应用的角色编码）
  → 策略名 = claim_prefix(`iam_`) + 编码（纯拼接，无映射表）
  → 逐条解析 RustFS 中的同名策略 → 建立 STS 凭证与控制台会话
```

`groups` 是**按应用裁剪**的：只包含「登录所用客户端（`rustfs_console`）所属应用
（`rustfs_local`）」下的角色，其它应用的角色不会出现。编码的定义权归应用方（应用角色模板），
租户只能授权、不能造值。

## Ark IAM 侧准备

前置：Ark IAM 以 gateway 方式运行在 `http://localhost:8100`。

1. **创建应用** `rustfs_local`，声明角色模板 `roleTemplate`：
   ```json
   [
     {"code": "console_admin", "name": "存储控制台管理员"},
     {"code": "readonly",      "name": "存储只读用户"}
   ]
   ```
2. **创建 OAuth 客户端** `rustfs_console`：
   - `redirectURIs`：`["http://localhost:9011/rustfs/admin/v3/oidc/callback/default"]`
   - `postLogoutRedirectURIs`：`["http://localhost:9011/rustfs/console/auth/login"]`
     —— **必须填控制台登录页**（不是 `http://localhost:9011/`）：RustFS 登出时把
     `{scheme}://{host}/rustfs/console/auth/login` 原样作为 `post_logout_redirect_uri` 发给
     ark-iam（`rustfs/src/admin/handlers/oidc.rs:839`，`CONSOLE_LOGIN_SUFFIX = "/auth/login"`，
     无尾部斜杠），服务端是**精确匹配**，填错就会在登出时得到
     `{"error":"invalid_request","error_description":"post_logout_redirect_uri invalid"}`。
   - `grantTypes`：`["authorization_code"]`
   - `responseTypes`：`["code"]`
   - `tokenEndpointAuthMethod`：`client_secret_basic`
   - `requirePKCE`：`disable`（RustFS 自己生成 PKCE，但客户端不必强制）
   - `defaultScopes`：`["openid","profile","email"]`（**必须含 `profile`**，`groups` 声明随 `profile` 授权产出）
3. **创建密钥**，把明文 `secret` 填入 `.env` 的 `RUSTFS_OIDC_CLIENT_SECRET`（Ark IAM 只存哈希，明文仅显示一次）。
4. **开通** `rustfs_local` 到租户 `t_platform` —— 角色模板会物化为该租户内的角色。
5. **授权**：在租户控制台把 `console_admin` / `readonly` 授权给需要访问存储的成员。

> ⚠ **顺序是硬要求：策略 → 模板 → 授权**。
> RustFS 对策略解析是**硬校验**：选中集合为空、或其中任一条策略名在 RustFS 里不存在，登录都会直接
> 以 `InvalidRequest` 被拒（`rustfs/src/admin/service/federated_identity.rs:278`），**不是**忽略认不出的值、
> 也不是静默降权。所以**先把策略供给到位，再声明模板、再给用户授权**；反过来会让该应用的所有已授权用户当场登录失败。

## 策略供给

OIDC 用户的策略名 = `RUSTFS_IDENTITY_OPENID_CLAIM_PREFIX`（`iam_`）+ `groups` 里的角色编码，
**逐字拼接、无映射表**（`crates/iam/src/oidc.rs:1508`）。因此模板里声明了几个 code，
RustFS 里就必须有对应的 `iam_<code>` 策略。

本目录提供零依赖运维脚本（`mc` 已停止分发）：

```bash
python3 rustfs_policy.py list                        # 列出全部策略（→ 标记 = ark-iam 契约命名空间）
python3 rustfs_policy.py show iam_readonly           # 查看某条策略
python3 rustfs_policy.py add iam_readonly policies/iam_readonly.json
python3 rustfs_policy.py remove iam_readonly
```

首次部署需供给两条（与 `rustfs_local` 的角色模板一一对应）：

```bash
python3 rustfs_policy.py add iam_console_admin policies/iam_console_admin.json
python3 rustfs_policy.py add iam_readonly      policies/iam_readonly.json
```

| 策略 | 对应角色编码 | 权限 |
|---|---|---|
| `iam_console_admin` | `console_admin` | `admin:*` / `kms:*` / `s3:*`（控制台管理员） |
| `iam_readonly` | `readonly` | 列桶 + 读对象。比 RustFS 内置 `readonly` 多了 `ListAllMyBuckets`/`ListBucket`/`ListBucketMultipartUploads` —— 内置那条只有 `GetBucketLocation`/`GetObject`/`GetBucketQuota`，控制台里连桶和对象列表都看不到 |

> 策略是**全局命名实体**（一条策略全租户共用），所以不要按租户各建一片。
> `iam_` 前缀是**跨产品**命名空间隔离，避免下游其它产品造出同名策略借权。

## 启动

```bash
cp .env.example .env          # 填 RUSTFS_OIDC_CLIENT_SECRET
docker compose up -d
python3 rustfs_policy.py add iam_console_admin policies/iam_console_admin.json
python3 rustfs_policy.py add iam_readonly      policies/iam_readonly.json
```

> **清库重来**：删掉 `./data/` 后 `docker compose up -d` 即为全新实例
> （策略随数据一起清空，需重新执行上面的 `add`）。`data/` 已被 `.gitignore` 忽略。

## 变量

`.env`（已 gitignore）由 compose 读取；完整清单见 `.env.example`。

| 变量 | 默认 | 说明 |
|---|---|---|
| `RUSTFS_ACCESS_KEY` | `rustfsadmin` | 存储根凭证（控制台 / S3 / 策略脚本共用） |
| `RUSTFS_SECRET_KEY` | `rustfsadmin` | 存储根凭证 |
| `ARK_IAM_ORIGIN` | `http://localhost:8100` | Ark IAM gateway 的 origin（不带路径）；discovery 地址与出站白名单都由它派生 |
| `RUSTFS_OIDC_CLIENT_SECRET` | - | `rustfs_console` 的 client_secret 明文；**未设置时 compose 直接报错**（fail-fast） |

compose 里固定的 OIDC 参数（一般不必改）：

| 参数 | 值 | 说明 |
|---|---|---|
| `RUSTFS_IDENTITY_OPENID_CONFIG_URL` | `${ARK_IAM_ORIGIN}/oidc/.well-known/openid-configuration` | discovery；**为空时整组 OIDC env 会被丢弃**（`crates/iam/src/oidc.rs:1815`） |
| `RUSTFS_IDENTITY_OPENID_CLIENT_ID` | `rustfs_console` | 必须与 Ark IAM 客户端编码一致 |
| `RUSTFS_IDENTITY_OPENID_REDIRECT_URI` | `http://localhost:9011/rustfs/admin/v3/oidc/callback/default` | 必须与客户端白名单逐字一致 |
| `RUSTFS_IDENTITY_OPENID_REDIRECT_URI_DYNAMIC` | `off` | **该键为空时默认是「开」**（`crates/iam/src/oidc.rs:1836`），必须显式关掉 |
| `RUSTFS_IDENTITY_OPENID_CLAIM_PREFIX` | `iam_` | 策略名前缀，勿与其它下游产品共用 |
| `RUSTFS_IDENTITY_OPENID_GROUPS_CLAIM` | `groups` | 角色声明名 |
| `RUSTFS_IDENTITY_OPENID_USERNAME_CLAIM` | `preferred_username` | 会话用户名来源 |

不写 `RUSTFS_IDENTITY_OPENID_ENABLE`：该键为空时**默认启用**，字面量写错反而会被解析成停用。
不写 `RUSTFS_IDENTITY_OPENID_ROLE_POLICY`：它与 claim 映射**互斥**，一旦设置，`groups` 只会作为
「组上下文」而不再映射成策略名（`crates/iam/src/oidc.rs:1489-1492`）。

## 验证

```bash
# 1. 容器与健康检查
docker ps --filter name=rustfs

# 2. Ark IAM discovery 可达
curl -s http://localhost:8100/oidc/.well-known/openid-configuration | head -c 200

# 3. RustFS 已加载 Ark IAM 提供方（display_name = Ark IAM）
curl -s http://127.0.0.1:9011/rustfs/admin/v3/oidc/providers

# 4. 策略在位（应能看到两条 iam_ 前缀）
python3 rustfs_policy.py list

# 5. 浏览器：打开 http://localhost:9011/rustfs/console/ → 点「Ark IAM」
#    或直接访问一键入口 http://localhost:9011/rustfs/admin/v3/oidc/authorize/default
```

登录成功后，RustFS 控制台会话 token 里应能看到映射结果（`policy` = 前缀 + groups）：

```json
{"preferred_username": "admin", "groups": ["console_admin", "readonly"],
 "policy": "iam_console_admin,iam_readonly", "oidc_provider": "default"}
```

## 排障

| 现象 | 原因 | 处理 |
|---|---|---|
| 浏览器打开 `:9010` 或 `:9011` **根路径**得到 `<Error><Code>AccessDenied</Code><Message>Access Denied</Message></Error>` | 那两个是服务根路径、不是控制台：9010 根 = S3 API 的 `ListBuckets`（必须带 SigV4 签名），9011 根不是控制台入口。**这不是登录或权限问题** | 控制台是 <http://localhost:9011/rustfs/console/>（带 `/rustfs/console/` 前缀）；S3 API 用 CLI/SDK 签名访问，不要在浏览器里裸开 |
| 登录页报 `<Code>InvalidRequest</Code>`<br>`OIDC policy mapping did not resolve to current policies` | 该用户的 `groups` 为空（未授权），或其中某个编码在 RustFS 里没有 `iam_<code>` 策略 | `python3 rustfs_policy.py list` 核对策略；在租户控制台核对角色授权 |
| 授权后 `groups` 仍为空 | 未开通应用到租户，或角色未物化，或登录客户端不属于该应用 | 核对 `rustfs_local` → `t_platform` 订阅与 `rustfs_console` 的 `appID` |
| `invalid_client` | `.env` 里的 secret 与 Ark IAM 记录不符（例如重建过客户端） | 重新创建密钥并更新 `.env`，再 `docker compose up -d --force-recreate` |
| 回调重定向地址不匹配 | `redirectURIs` 与 `RUSTFS_IDENTITY_OPENID_REDIRECT_URI` 不完全一致 | 两者逐字核对（含尾部 `/default`） |
| discovery 失败 / 出站被拒 | `RUSTFS_OUTBOUND_ALLOW_ORIGINS` 未含 Ark IAM origin | 该值须为精确 origin（`scheme://host:port`，不带路径），改后需重建容器 |
| 容器启动即失败，提示未设置 `RUSTFS_OIDC_CLIENT_SECRET` | 缺 `.env` | `cp .env.example .env` 并填入 client_secret |

## 配置说明

- 单节点单盘 `RUSTFS_VOLUMES=/data/rustfs0`，数据落 `./data/`（`**/data/` 已 gitignore）。
- 网络：`network_mode: host`（与 `gitea/` 一致，便于统一 SSO）；S3 API 监听宿主 9010，
  控制台监听宿主 9011，**不再加入 `local_net`**，其它容器不能按服务名 `rustfs` 访问。
- 控制台基路径为 `/rustfs/console/`；admin API 为 `/rustfs/admin/v3/*`。
- metadata 与策略随 `./data/` 持久化；`docker compose down -v` 不会删除绑定挂载，需手工删 `./data/`。
