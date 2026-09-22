# TripStar 自托管部署

[TripStar（旅途星辰）](https://github.com/1sdv/TripStar) 是基于 HelloAgents 框架的多智能体协作文旅规划平台，
采用前后端分离架构：Vue 3 前端 + FastAPI 后端，集成 LLM、高德/Google 地图与小红书游记数据。

本目录提供从源码构建镜像并启动的一键部署方案。

## 服务架构

| 组件 | 技术栈 | 端口 | 说明 |
|------|--------|------|------|
| 前端 | Vue 3 + Vite（构建为静态资源） | - | 由后端同源托管 |
| 后端 | FastAPI + Gunicorn/Uvicorn | 7860 | API + WebSocket + 静态页面 |

单容器部署，后端同时托管前端构建产物，访问 `7860` 即可。

## 前置条件

- Docker 与 Docker Compose（v2）
- 源码仓库（构建上下文，默认 `/root/project/TripStar`）：

```bash
git clone git@github.com:1sdv/TripStar.git /root/project/TripStar
```

> 本项目暂无官方预构建镜像，需要本地从源码构建（首次构建约 30 分钟，主要耗时在 apt/pip 依赖下载）。

## 快速部署

```bash
cd tripstar

# 1. 生成配置模板
cp .env.example .env

# 2. 编辑 .env，至少填写 LLM 与高德相关 Key（见下方说明）
vim .env

# 3. 构建并启动
./deploy.sh
# 或手动执行：docker compose up -d --build
```

## 配置说明（.env）

### LLM（必填）

任意兼容 OpenAI Chat Completions 的服务均可：

| 变量 | 说明 |
|------|------|
| `LLM_API_KEY` | API Key |
| `LLM_BASE_URL` | 接口地址，需带 `/v1` |
| `LLM_MODEL_ID` | 模型 ID |
| `LLM_TIMEOUT` | 请求超时（秒），默认 600 |

例如使用 opencode 的 yygu provider：

```dotenv
LLM_API_KEY=sk-xxxxxx
LLM_BASE_URL=https://llm.yygu.cn/v1
LLM_MODEL_ID=deepseek-flash
```

### 高德地图（必填，注意 Key 类型）

高德需要**两个不同类型的 Key**，请勿混用：

| 变量 | Key 类型 | 用途 | 生效时机 |
|------|----------|------|----------|
| `VITE_AMAP_WEB_KEY` | **Web服务** | 后端地理编码、POI、天气、路线 | 运行时 |
| `VITE_AMAP_WEB_JS_KEY` | **Web端(JS API)** | 前端地图渲染 | **构建期** |
| `VITE_AMAP_SECURITY_JS_CODE` | JS API 安全密钥 | 前端 JS API 鉴权 | **构建期** |

> ⚠️ 修改 `VITE_AMAP_WEB_JS_KEY` 或 `VITE_AMAP_SECURITY_JS_CODE` 后，必须 `docker compose up -d --build` 重新构建镜像才会生效。

安全密钥会在构建时注入 `index.html` 的 `window._AMapSecurityConfig`。

### 小红书（可选）

`XHS_COOKIE`：景点推荐与图片来源于小红书真实游记。留空则相关功能降级。
在浏览器登录小红书后，复制请求头中的 Cookie 字符串填入。

### 其他可选

| 变量 | 默认 | 说明 |
|------|------|------|
| `GOOGLE_MAPS_API_KEY` | 空 | 填后优先使用 Google Maps，留空回退高德 |
| `GOOGLE_MAPS_PROXY` | 空 | 国内访问 Google 的代理 |
| `ENABLE_USER_MEMORY` | false | 用户偏好记忆模块总开关 |
| `MEMORY_USE_SQLITE` | false | true 持久化到 SQLite，false 内存模式 |

### 部署参数

| 变量 | 默认 | 说明 |
|------|------|------|
| `TRIPSTAR_SRC` | `/root/project/TripStar` | 源码目录（构建上下文） |
| `TRIPSTAR_IMAGE` | `tripstar:latest` | 镜像名与标签 |
| `TRIPSTAR_PORT` | `7860` | 对外端口 |
| `LOG_LEVEL` | `INFO` | 日志级别 |

## 访问地址

| 服务 | 地址 |
|------|------|
| Web UI | http://localhost:7860 |
| API 文档 | http://localhost:7860/docs |
| 健康检查 | http://localhost:7860/health |

## 常用命令

```bash
# 查看状态
docker compose ps

# 查看日志（跟踪）
docker compose logs -f

# 重启
docker compose restart

# 停止（保留数据）
docker compose down

# 停止并删除数据
docker compose down -v

# 修改代码后重新构建
docker compose up -d --build
```

## 数据持久化

| 数据 | 路径 | 说明 |
|------|------|------|
| 记忆/SQLite 数据 | `./data/` | 挂载到容器 `/app/backend/data` |

`./data/` 已在 `.gitignore` 中排除。

## 更新

```bash
# 1. 拉取最新源码
cd /root/project/TripStar && git pull

# 2. 重新构建并启动
cd /root/morehao/docker-compose-dev/tripstar && ./deploy.sh

# 3. 清理旧镜像（可选）
docker image prune
```

## 验证部署

```bash
# 健康检查
curl -fsS http://localhost:7860/health
# => {"status":"healthy",...}

# LLM 连通性
curl -s -X POST http://localhost:7860/api/chat/ask \
  -H "Content-Type: application/json" \
  -d '{"message":"你好","trip_plan":{},"history":[]}'
```

## 排障

| 现象 | 排查方向 |
|------|----------|
| 启动后 `/health` 不通 | `docker compose logs -f` 查看 gunicorn 是否监听 7860 |
| 地理编码/POI/天气为空 | `VITE_AMAP_WEB_KEY` 必须是**Web服务**类型 Key（不是 JS API Key） |
| 地图白屏 | `VITE_AMAP_WEB_JS_KEY` / `VITE_AMAP_SECURITY_JS_CODE` 是否正确，且已重新构建 |
| LLM 调用失败 | 核对 `LLM_BASE_URL`（是否带 `/v1`）、`LLM_MODEL_ID`、`LLM_API_KEY` |
| 小红书数据为空 | 配置有效的 `XHS_COOKIE` |
| 首次构建极慢 | apt 安装 nodejs/npm 依赖较多，属正常现象 |

## 参考链接

- [TripStar 项目主页](https://github.com/1sdv/TripStar)
- [高德开放平台](https://lbs.amap.com/)（申请 Web服务 / Web端(JS API) Key）
