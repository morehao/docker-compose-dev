# docker-compose-dev
基于 Docker Compose 进行环境搭建的docker-compose.yml文件合集

## 创建共享 network

创建共享 network，用于容器间通信

```bash
docker network create local_net
```

## 服务目录

| 目录 | 服务 | 说明 |
|------|------|------|
| `casdoor/` | Casdoor | 身份认证平台 |
| `docker-shell/` | Docker Shell | Docker 操作脚本 |
| `elasticsearch/` | Elasticsearch | 全文检索引擎 |
| `gitea/` | Gitea | 轻量 Git 服务 |
| `logto/` | Logto | 身份认证平台 |
| `mihomo/` | Mihomo | 代理工具 |
| `minio/` | MinIO | 对象存储 |
| `mysql/` | MySQL | 关系数据库 |
| `nats/` | NATS JetStream | 消息队列 |
| `new-api/` | New API | 统一 AI API 网关与资产管理 |
| `nsq/` | NSQ | 消息队列 |
| `pgvector/` | pgvector | 向量数据库 |
| `postgresql/` | PostgreSQL | 关系数据库 |
| `prometheus-grafana/` | Prometheus + Grafana | 监控与可视化 |
| `redis/` | Redis | 缓存/存储 |
| `rocketmq/` | RocketMQ | 消息队列 |
| `whodb/` | WhoDB | 数据库管理工具 |

各服务在子目录内使用，进入对应目录后执行 `docker-compose up -d` 启动。
