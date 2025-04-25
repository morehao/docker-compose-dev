# 项目说明
通过 `docker-compose.yml` 文件构建了一个完整的 `RocketMQ` 环境，包括核心组件（`NameServer`、`Broker`、`Proxy`）和管理工具（`Dashboard`）。
服务间通过 `rocketmq` 网络通信，便于管理和使用。

同时，使用 `Go` 语言编写了一个简单的生产者、消费者示例，用于演示 `RocketMQ` 的基本用法。

# 启动和停止

启动 `RocketMQ` 集群：
```
docker-compose up -d
```
停止 `RocketMQ` 集群：
```
docker-compose down
```

# 服务信息

- NameServer：`localhost:9876`
- Broker：`localhost:10911`
- Proxy：`localhost:8080` 或 `localhost:8081`
- Dashboard（浏览器访问控制台）：`127.0.0.1:8082`

# 创建 topic

```
docker exec -it rmqbroker /bin/bash
sh mqadmin updatetopic -t TestTopic -c DefaultCluster
```