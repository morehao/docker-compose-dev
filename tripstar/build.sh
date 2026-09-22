#!/usr/bin/env bash
# 构建 TripStar 镜像（不启动容器）
set -euo pipefail

cd "$(dirname "$0")"

if [[ ! -f .env ]]; then
  echo "❌ 缺少 .env，请先执行：cp .env.example .env 并填写配置" >&2
  exit 1
fi

echo "🔨 开始构建镜像（源码目录见 .env 中 TRIPSTAR_SRC）..."
docker compose build

echo "✅ 构建完成"
docker images | grep -E "REPOSITORY|$(grep -E '^TRIPSTAR_IMAGE=' .env | cut -d= -f2 | cut -d: -f1 || echo tripstar)" || true
