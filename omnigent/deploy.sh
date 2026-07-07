#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

# --- 颜色输出 ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
step()  { echo -e "\n${CYAN}==>${NC} $*"; }

# --- 检测 .env ---
if [ ! -f .env ]; then
    warn ".env 文件不存在，正在从 .env.example 创建..."
    cp .env.example .env
    echo "请编辑 .env 文件，至少修改 POSTGRES_PASSWORD，然后重新运行 deploy.sh"
    exit 1
fi

# --- 检查共享网络 ---
step "检查共享网络"
if docker network ls --filter name=local_net --format '{{.Name}}' | grep -q local_net; then
    info "local_net 网络已存在"
else
    info "创建 local_net 网络"
    docker network create local_net
fi

# --- 检测已有 Postgres ---
step "检测数据库中间件"
EXISTING_PG=false
EXISTING_PG_NAMES=$(docker ps --filter network=local_net --format '{{.Names}}' | xargs -I{} docker inspect {} --format '{{.Name}}' 2>/dev/null | sed 's|^/||' || true)

# 通过容器名或标签检测 postgres
for name in $(docker ps --filter network=local_net --format '{{.Names}}'); do
    image=$(docker inspect "$name" --format '{{.Config.Image}}' 2>/dev/null || true)
    if echo "$image" | grep -qiE 'postgres|pgvector'; then
        info "检测到已有 Postgres 容器: $name ($image)"
        EXISTING_PG=true
        break
    fi
done

if [ "$EXISTING_PG" = true ]; then
    info "使用已有 Postgres，跳过 postgres 容器部署"
    docker compose --profile db down 2>/dev/null || true
    info "启动 omnigent 服务..."
    docker compose up -d omnigent
else
    info "未检测到已有 Postgres，启动完整服务栈（含 postgres）"
    docker compose --profile db up -d postgres

    step "等待 Postgres 就绪..."
    timeout 60 bash -c 'until docker compose exec postgres pg_isready -U omnigent -d omnigent 2>/dev/null; do sleep 2; done' 2>/dev/null || \
    timeout 60 bash -c 'until docker inspect omnigent-postgres --format "{{.State.Health.Status}}" 2>/dev/null | grep -q healthy; do sleep 2; done'

    info "Postgres 就绪，启动 omnigent 服务..."
    docker compose up -d omnigent
fi

# --- 等待 omnigent 就绪 ---
step "等待 Omnigent 就绪..."
sleep 5
for i in $(seq 1 12); do
    if curl -sf http://127.0.0.1:${OMNIGENT_PORT:-8000}/health > /dev/null 2>&1; then
        info "Omnigent 已就绪！"
        break
    fi
    if [ "$i" -eq 12 ]; then
        warn "等待超时，请检查日志: docker compose logs omnigent"
    fi
    sleep 5
done

# --- 输出信息 ---
step "部署完成"
echo ""
echo -e "  ${GREEN}Omnigent UI:${NC}  http://<服务器IP>:${OMNIGENT_PORT:-8000}"
echo -e "  ${GREEN}健康检查:${NC}   http://<服务器IP>:${OMNIGENT_PORT:-8000}/health"
echo ""
echo "  常用命令:"
echo "    查看日志:  docker compose logs -f omnigent"
echo "    重启服务:  docker compose restart omnigent"
echo "    停止服务:  docker compose down"
echo ""
