# RustFS 本地开发部署设计

日期：2026-09-17

> **⚠ 部分被取代（2026-09-18）**：本文的 `local_net` + `ports` 端口映射方案已被
> [2026-09-18-rustfs-ark-iam-sso-design.md](2026-09-18-rustfs-ark-iam-sso-design.md) 取代 ——
> RustFS 现以 `network_mode: host` 运行以接入 Ark IAM OIDC 统一登录，不再加入 `local_net`，
> 端口改由 `RUSTFS_ADDRESS` / `RUSTFS_CONSOLE_ADDRESS` 直接指定，并新增 OIDC 提供方与策略供给配置。
> 下文保留为初始部署的决策记录（镜像、存储布局、凭证、健康检查、重启策略等选择仍然有效）；
> 涉及「网络 / 端口 / `.env` 变量」的段落请以新文档和 `rustfs/README.md` 为准。

## 背景

`docker-compose-dev` 是各类中间件的 Docker Compose 合集，每个服务一个子目录，通过共享的
外部网络 `local_net` 互联。RustFS 是兼容 S3 协议的对象存储，需要以本地开发为目的加入该合集，
与现有 `minio/` 目录并列。

官方 `https://rustfs.com/docker-compose.yml` 面向项目自身开发，包含 `build` 段、`dev`、
`observability`、`proxy` 三类 profile 以及自建网络，体量与定位均不适合直接放入本合集。

## 目标

- 在 `rustfs/` 子目录下提供可直接 `docker compose up -d` 启动的单节点 RustFS。
- 与项目既有约定保持一致：外部网络 `local_net`、`${VAR:-default}` 环境变量、根 README 服务清单。
- 与 `minio/` 可同时运行，互不抢占端口。

## 非目标

- 不包含 observability 监控栈（prometheus / grafana / tempo / loki / jaeger / otel-collector）。
- 不包含 `dev` 源码开发容器。
- 不包含 nginx 反向代理与 TLS 配置。
- 不使用本地源码构建（不保留 `build` 段，仅用预构建镜像）。
- 不配置分布式 / 多节点纠删码集群。

## 决策

| 项 | 决策 | 理由 |
|----|------|------|
| 镜像 | `rustfs/rustfs:latest` | 与官方及项目其它服务（minio:latest）一致，无需本地构建 |
| 端口 | API `${RUSTFS_API_PORT:-9010}:9000`，Console `${RUSTFS_CONSOLE_PORT:-9011}:9001` | 避开 minio 占用的 9000/9001，两者可同时运行 |
| 存储 | 单盘单卷 `RUSTFS_VOLUMES=/data/rustfs0`，绑定 `./data:/data` | 本地开发最简；数据落在 `./data/rustfs0/` |
| 网络 | 外部网络 `local_net` | 与合集多数服务一致，可被其它容器按服务名 `rustfs` 访问 |
| 凭证 | `RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY`，默认 `rustfsadmin` | 官方默认值，仅本地开发；通过 `.env` 覆盖 |
| 数据持久化 | `.gitignore` 既有规则 `**/data/` 已覆盖，无需改动 | 数据不入库 |
| 健康检查 | `curl -fsS http://127.0.0.1:9000/health`，30s 间隔 / 10s 超时 / 3 次重试 / 40s 启动期 | 官方 healthcheck 亦使用镜像内 curl，此处精简为明文 HTTP |
| 重启策略 | `restart: unless-stopped` | 与项目其它服务一致 |

## 变更清单

### 新增 `rustfs/docker-compose.yml`

```yaml
services:
  rustfs:
    image: rustfs/rustfs:latest
    container_name: rustfs
    ports:
      - "${RUSTFS_API_PORT:-9010}:9000"       # S3 API
      - "${RUSTFS_CONSOLE_PORT:-9011}:9001"   # Console
    volumes:
      - ./data:/data
    environment:
      RUSTFS_VOLUMES: /data/rustfs0
      RUSTFS_ADDRESS: 0.0.0.0:9000
      RUSTFS_CONSOLE_ADDRESS: 0.0.0.0:9001
      RUSTFS_CONSOLE_ENABLE: "true"
      RUSTFS_ACCESS_KEY: ${RUSTFS_ACCESS_KEY:-rustfsadmin}
      RUSTFS_SECRET_KEY: ${RUSTFS_SECRET_KEY:-rustfsadmin}
      RUSTFS_OBS_LOGGER_LEVEL: info
    networks:
      - local_net
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://127.0.0.1:9000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    restart: unless-stopped

networks:
  local_net:
    external: true
```

### 新增 `rustfs/.env.example`

```
RUSTFS_ACCESS_KEY=rustfsadmin
RUSTFS_SECRET_KEY=rustfsadmin
RUSTFS_API_PORT=9010
RUSTFS_CONSOLE_PORT=9011
```

### 更新根 `README.md`

服务目录表新增一行（按字母序位于 `rocketmq/` 之后、`whodb/` 之前）：

```
| `rustfs/` | RustFS | 对象存储 |
```

## 风险与注意事项

- **挂载目录权限**：RustFS 运行时用户为 `10001:10001`，宿主 `./data` 需对该用户可写，
  否则容器启动失败。若出现权限错误，需调整宿主目录属主/权限。
- **默认凭证为公开值**：`rustfsadmin` 为官方公开默认值，仅用于本地开发；不得用于公网暴露。
- **`latest` 标签漂移**：镜像行为可能随上游更新变化；如遇不兼容可改钉具体版本。

## 验收标准

1. 在 `local_net` 已存在（`docker network create local_net`）时，
   `cd rustfs && docker compose up -d` 成功启动。
2. 容器状态为 `running` 且 `docker compose ps` 显示健康（healthcheck 通过）。
3. 宿主 `http://localhost:9011` 可打开 RustFS Console 并使用默认凭证登录。
4. S3 API 在 `http://localhost:9010` 可访问。
5. `./data/rustfs0/` 下产生持久化数据。
6. `minio` 与 `rustfs` 可同时运行，端口无冲突。
7. 根 `README.md` 服务表包含 `rustfs/` 行。
8. 未引入 `build` 段、observability、dev、proxy 相关配置。
