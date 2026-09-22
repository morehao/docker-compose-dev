#!/usr/bin/env bash
# 构建并启动 TripStar 服务
set -euo pipefail

cd "$(dirname "$0")"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "⚠️  已生成 .env，请填写 LLM / 高德等 Key 后重新执行 ./deploy.sh" >&2
  exit 1
fi

PORT=$(grep -E '^TRIPSTAR_PORT=' .env | cut -d= -f2 | tr -d '[:space:]' || true)
PORT=${PORT:-7860}

echo "🚀 构建并启动 TripStar ..."
docker compose up -d --build

echo
docker compose ps
echo
echo "访问地址: http://localhost:${PORT}"
echo "健康检查: curl -fsS http://localhost:${PORT}/health"
echo "查看日志: docker compose logs -f"
