# 项目说明

通过 `docker-compose.yml` 文件构建了一个完整的 `NATS` 环境，并启用了 `JetStream`（持久化的消息队列能力），用于本地的流式消息与队列场景。

服务接入共享的 `local_net` 网络，便于与其他容器通信。

# 启动和停止

启动 `NATS`：
```
docker-compose up -d
```
停止 `NATS`：
```
docker-compose down
```

# 服务信息

- 客户端连接：`nats://localhost:4222`
- HTTP 监控：`http://localhost:8222`（含 `/healthz` 健康检查）
- 数据目录：`./data`（JetStream 持久化存储）

# 验证服务可用

通过监控端口检查健康状态：
```
curl http://localhost:8222/healthz
```

通过 `nats` CLI 发布订阅测试：
```
docker exec -it nats bash
nats sub ">"
nats pub test.subject "hello"
```
