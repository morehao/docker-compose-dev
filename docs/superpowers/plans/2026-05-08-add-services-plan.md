# 添加 Casdoor、Logto、Mihomo 服务实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `/root/deploy` 中的 casdoor、logto 服务和 mihomo-deploy.md 配置适配到 `docker-compose-dev` 项目中，保持与现有服务（如 redis、mysql）一致的结构规范。

**Architecture:** 每个服务独立目录，包含 docker-compose.yml、config/、data/ 子目录（按需），并保留部署和使用文档。使用共享网络 `local_net` 实现容器间通信。

**Tech Stack:** Docker Compose, MySQL, PostgreSQL, Mihomo (Clash.Meta)

---

## 文件结构总览

```
docker-compose-dev/
├── casdoor/
│   ├── docker-compose.yml
│   ├── config/              # casdoor conf 目录
│   └── data/                # MySQL 数据持久化
├── logto/
│   ├── docker-compose.yml
│   └── data/                # PostgreSQL 数据持久化
├── mihomo/
│   ├── docker-compose.yml
│   ├── config/
│   │   ├── config.yaml
│   │   └── proxies.yaml
│   └── data/
│       └── .gitkeep
└── ... (现有服务)
```

---

## Task 1: 创建 casdoor 服务

**Files:**
- Create: `casdoor/docker-compose.yml`
- Create: `casdoor/data/` (空目录)
- Copy: `casdoor/DEPLOY.md`, `casdoor/USAGE.md` (保留原有内容)

- [ ] **Step 1: 创建 casdoor 目录**

```bash
mkdir -p /root/morehao/docker-compose-dev/casdoor/data
```

- [ ] **Step 2: 创建 casdoor/docker-compose.yml**

```yaml
version: '3.8'

services:
  casdoor:
    container_name: casdoor
    build:
      context: /root/project/casdoor
      dockerfile: /root/project/casdoor/Dockerfile
      target: STANDARD
    entrypoint: /bin/sh -c './server --createDatabase=true'
    ports:
      - "127.0.0.1:8000:8000"
    depends_on:
      - db
    environment:
      RUNNING_IN_DOCKER: "true"
    volumes:
      - ./config:/conf/
    networks:
      - local_net
    restart: unless-stopped
  db:
    container_name: casdoor-db
    image: mysql:8.0.25
    platform: linux/amd64
    ports:
      - "127.0.0.1:3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: "123456"
    volumes:
      - ./data:/var/lib/mysql
    networks:
      - local_net
    restart: unless-stopped

networks:
  local_net:
    external: true

volumes:
  casdoor_data:
```

- [ ] **Step 3: 复制 casdoor 文档**

从 `/root/deploy/casdoor/` 复制 `DEPLOY.md` 和 `USAGE.md` 到 `casdoor/` 目录。

注意：原文档中的 `docker compose` 命令保持不变，因为用户实际使用时会在 casdoor 目录下执行。

- [ ] **Step 4: 提交**

```bash
git add casdoor/
git commit -m "feat: add casdoor service"
```

---

## Task 2: 创建 logto 服务

**Files:**
- Create: `logto/docker-compose.yml`
- Create: `logto/data/` (空目录)
- Copy: `logto/DEPLOY.md`, `logto/USAGE.md` (保留原有内容)

- [ ] **Step 1: 创建 logto 目录**

```bash
mkdir -p /root/morehao/docker-compose-dev/logto/data
```

- [ ] **Step 2: 创建 logto/docker-compose.yml**

```yaml
version: '3.8'

services:
  app:
    container_name: logto
    depends_on:
      postgres:
        condition: service_healthy
    image: svhd/logto:${TAG-latest}
    entrypoint: ["sh", "-c", "npm run cli db seed -- --swe && npm start"]
    ports:
      - "127.0.0.1:3001:3001"
      - "127.0.0.1:3002:3002"
    environment:
      - TRUST_PROXY_HEADER=1
      - DB_URL=postgres://postgres:p0stgr3s@logto-db:5432/logto
      - PRIVATE_KEY_ROTATION_GRACE_PERIOD
      - ENDPOINT=https://49.232.218.218
      - ADMIN_ENDPOINT=https://49.232.218.218
    networks:
      - local_net
    restart: unless-stopped
  postgres:
    container_name: logto-db
    image: postgres:17-alpine
    user: postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: p0stgr3s
    volumes:
      - ./data:/var/lib/postgresql/data
    networks:
      - local_net
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready"]
      interval: 5s
      timeout: 5s
      retries: 5

networks:
  local_net:
    external: true
```

关键改动：
- 容器名改为 `logto` 和 `logto-db`
- DB_URL 中 host 改为 `logto-db` (与 postgres 容器名一致)
- 添加 `networks: local_net`
- 添加 `restart: unless-stopped`
- PostgreSQL 数据持久化改为本地 volume `./data`

- [ ] **Step 3: 复制 logto 文档**

从 `/root/deploy/logto/` 复制 `DEPLOY.md` 和 `USAGE.md` 到 `logto/` 目录。

注意：原 DEPLOY.md 包含 Nginx 配置部分，这是部署的一部分，应完整保留。

- [ ] **Step 4: 提交**

```bash
git add logto/
git commit -m "feat: add logto service"
```

---

## Task 3: 创建 mihomo 服务

**Files:**
- Create: `mihomo/docker-compose.yml`
- Create: `mihomo/config/config.yaml`
- Create: `mihomo/config/proxies.yaml`
- Create: `mihomo/data/.gitkeep`
- Create: `mihomo/USAGE.md` (精简自 mihomo-deploy.md)

- [ ] **Step 1: 创建 mihomo 目录结构**

```bash
mkdir -p /root/morehao/docker-compose-dev/mihomo/config
mkdir -p /root/morehao/docker-compose-dev/mihomo/data
touch /root/morehao/docker-compose-dev/mihomo/data/.gitkeep
```

- [ ] **Step 2: 创建 mihomo/config/config.yaml**

```yaml
mixed-port: 7890
allow-lan: false
bind-address: "127.0.0.1"
mode: rule
log-level: info
ipv6: true
external-controller: 127.0.0.1:9093

proxy-providers:
  mySub:
    type: file
    path: ./proxies.yaml
    health-check:
      enable: true
      interval: 600
      url: http://www.gstatic.com/generate_204

proxy-groups:
  - name: PROXY
    type: select
    use:
      - mySub

rules:
  - MATCH,PROXY
```

- [ ] **Step 3: 创建 mihomo/config/proxies.yaml**

初始为空文件（用户需自行填充代理节点）：

```yaml
# 代理节点配置
# 请从订阅地址获取并提取 proxies 和 proxy-groups 部分
# 订阅提取示例：见 USAGE.md

proxies: []
proxy-groups: []
```

- [ ] **Step 4: 创建 mihomo/docker-compose.yml**

```yaml
version: '3.8'

services:
  mihomo:
    container_name: mihomo
    image: metacubex/mihomo:latest
    restart: unless-stopped
    volumes:
      - ./config/config.yaml:/root/.config/mihomo/config.yaml:ro
      - ./data:/root/.config/mihomo
    devices:
      - /dev/net/tun:/dev/net/tun
    cap_add:
      - NET_ADMIN
    network_mode: host
    environment:
      - TZ=Asia/Shanghai
```

关键说明：
- 使用 `network_mode: host` 是因为 Mihomo 需要 TUN 设备，host 模式最稳定
- 配置以只读方式挂载，用户修改配置后需重启容器生效

- [ ] **Step 5: 创建 mihomo/USAGE.md**

精简自 `/root/deploy/mihomo-deploy.md`，提取关键使用信息：

```markdown
# Mihomo 使用说明

## 部署步骤

### 1. 配置代理节点

下载订阅并提取 proxies 部分：

```bash
curl -s "你的订阅地址" -o /tmp/proxies.yaml
python3 << 'EOF'
import yaml
with open('/tmp/proxies.yaml', 'r') as f:
    data = yaml.safe_load(f)
output = {
    'proxies': data.get('proxies', []),
    'proxy-groups': data.get('proxy-groups', [])
}
with open('config/proxies.yaml', 'w') as f:
    yaml.dump(output, f, allow_unicode=True, default_flow_style=False)
EOF
```

### 2. 启动服务

```bash
cd mihomo
docker compose up -d
```

### 3. 验证部署

```bash
# 检查容器状态
docker compose ps

# 检查端口
ss -tlnp | grep 7890

# 测试代理
curl -x http://127.0.0.1:7890 -s https://api.ip.sb/ip
```

## 端口说明

| 端口 | 说明 |
|------|------|
| 7890 | HTTP/SOCKS5 混合代理端口 |
| 9093 | RESTful API 端口 |

## 常用命令

```bash
# 查看日志
docker compose logs -f

# 重启服务（重载配置）
docker compose restart

# 重新加载配置（不重启）
docker compose exec mihomo kill -HUP 1

# 停止服务
docker compose down
```

## 故障排查

### 容器启动失败

```bash
docker compose logs mihomo
docker compose exec mihomo /mihomo -t -f /root/.config/mihomo/config.yaml
```

### 代理节点连接超时

```bash
# 检查订阅是否可访问
curl -s "你的订阅地址" | head

# 查看节点健康状态
curl http://127.0.0.1:9093/proxies/PROXY | python3 -c "import sys,json; d=json.load(sys.stdin); print('当前:', d['now'])"
```
```

- [ ] **Step 6: 提交**

```bash
git add mihomo/
git commit -m "feat: add mihomo service"
```

---

## 验证步骤

所有服务创建完成后，执行以下验证：

- [ ] **验证 1: 检查目录结构**

```bash
ls -la casdoor/ logto/ mihomo/
```

预期输出：每个目录都包含 docker-compose.yml 和相应的子目录。

- [ ] **验证 2: 验证 docker-compose 配置语法**

```bash
cd /root/morehao/docker-compose-dev/casdoor && docker compose config --quiet && echo "casdoor: OK"
cd /root/morehao/docker-compose-dev/logto && docker compose config --quiet && echo "logto: OK"
cd /root/morehao/docker-compose-dev/mihomo && docker compose config --quiet && echo "mihomo: OK"
```

- [ ] **验证 3: 提交所有更改**

```bash
git status
git log --oneline -3
```

---

## 实施检查清单

- [ ] Task 1: casdoor 服务创建完成
- [ ] Task 2: logto 服务创建完成
- [ ] Task 3: mihomo 服务创建完成
- [ ] 所有 docker-compose.yml 配置语法验证通过
- [ ] 所有更改已提交