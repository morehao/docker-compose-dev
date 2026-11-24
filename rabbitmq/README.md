# RabbitMQ 本地开发环境

RabbitMQ 4.4 单节点开发环境，带管理界面（`-management` 镜像）。
目标是「一条命令起来、能给本机服务和集成测试用」，不追求高可用与集群。

## 组件与端口

| 组件 | 容器 | 宿主端口 | 说明 |
|---|---|---|---|
| AMQP | `rabbitmq` | `127.0.0.1:5672` | AMQP 0-9-1 / AMQP 1.0 客户端连接 |
| 管理界面 / HTTP API | `rabbitmq` | `127.0.0.1:15672` | 网页控制台与 `/api/*` |
| 默认账号 | - | - | `admin` / `admin123`（来自 `.env`，可改） |

镜像固定 `rabbitmq:4.4.1-management`，可用 `RABBITMQ_VERSION` 覆盖。
版本选择说明：

- 只有 `-management` 后缀的镜像内置管理插件，裸 `rabbitmq:4.4.1` 的 15672 是空的（连不上）；
- `4.4.1` 是当前 4.4 稳定线的最新补丁版，多架构（amd64 / arm64）；
- 不用 `latest`：大版本滚动会改配置键和默认端口，本地环境静默失效比直接报错更难查。

端口只绑 `127.0.0.1`，不对局域网暴露没有 TLS 的 MQ。

## 前置

合集共用外部网络 `local_net`，只需创建一次：

```bash
docker network create local_net
```

`.env` 可选，不建则使用 compose 里的默认值：

```bash
cp .env.example .env
```

## 启动 / 停止 / 重置

```bash
docker compose up -d
docker compose ps                  # 等 STATUS 变成 healthy
docker compose logs -f rabbitmq
docker compose down                # 停止并删除容器，数据保留在 ./data
rm -rf ./data                      # 彻底重置：用户 / vhost / 队列 / 消息全部清掉
```

`RABBITMQ_DEFAULT_USER`、`RABBITMQ_DEFAULT_PASS` 只在 **`./data` 首次初始化** 时生效。
改完 `.env` 发现登录还是旧账号，就是没重置数据：`down` + `rm -rf ./data` + `up -d`。

## 就绪检查

`up -d` 返回时管理插件可能还在加载，按下面任一方式确认：

```bash
docker compose ps                                            # 看 healthy
docker exec rabbitmq rabbitmq-diagnostics -q ping            # Erlang VM 可用
docker exec rabbitmq rabbitmqctl status                      # 节点/内存/磁盘告警详情
curl -u admin:admin123 http://127.0.0.1:15672/api/overview   # HTTP API 可用
```

管理界面：<http://127.0.0.1:15672>，用 `.env` 里的账号登录。

## 客户端连接

AMQP URI（vhost 为默认 `/`，URI 里写成空路径即可）：

```
amqp://admin:admin123@127.0.0.1:5672/
```

显式写默认 vhost 时是 `amqp://admin:admin123@127.0.0.1:5672/%2F`。
AMQP 1.0 客户端连同一个 5672 端口（URI scheme 各客户端库不统一，常见仍写 `amqp://`，以库文档为准）。

Go 侧用社区库 [`github.com/rabbitmq/amqp091-go`](https://github.com/rabbitmq/amqp091-go) 即可，
`golib` 目前没有 RabbitMQ 封装，直接用上游库：

```go
conn, err := amqp.Dial("amqp://admin:admin123@127.0.0.1:5672/")
if err != nil {
    log.Fatal(err)
}
defer conn.Close()
```

## 常用操作

容器里自带 `rabbitmqadmin`（v2，封装 HTTP API）和 `rabbitmqctl`，账号密码同 `.env`。
注意 `rabbitmqadmin` v2 的语法和旧版 v1 不同：`list queues` 不再接列名、声明队列要用
`declare queue --name ...`，网上大量 v1 示例直接抄会报错。

```bash
# 看队列（名称、消息积压、消费者数等）
docker exec rabbitmq rabbitmqadmin -u admin -p admin123 list queues

# 声明持久化队列
docker exec rabbitmq rabbitmqadmin -u admin -p admin123 declare queue --name demo --durable true

# 往默认 exchange 发消息
docker exec rabbitmq rabbitmqadmin -u admin -p admin123 publish message -k demo -m hello

# 拉一条消息查看（ack_requeue_true 表示看完放回队列）
docker exec rabbitmq rabbitmqadmin -u admin -p admin123 get messages -q demo -a ack_requeue_true
```

脚本里更推荐直接走 HTTP API（不依赖容器内 CLI）：

```bash
# 声明持久化队列，成功返回 201
curl -u admin:admin123 -X PUT -H 'content-type: application/json' \
  -d '{"durable":true,"arguments":{}}' \
  http://127.0.0.1:15672/api/queues/%2F/demo

# 往默认 exchange 发一条消息，返回 {"routed":true} 表示进了队列
curl -u admin:admin123 -X POST -H 'content-type: application/json' \
  -d '{"properties":{},"routing_key":"demo","payload":"hello","payload_encoding":"string"}' \
  http://127.0.0.1:15672/api/exchanges/%2F/amq.default/publish
```

`rabbitmqctl` 也自带，适合临时看节点状态：
`docker exec rabbitmq rabbitmqctl list_queues name messages consumers`。

## 数据与日志

- `./data/mnesia`：队列、消息、用户、vhost 等元数据；
- `./data/.erlang.cookie`：节点 cookie，跟着数据目录持久化；
- 日志输出到容器 stdout，用 `docker compose logs` 看（镜像默认不写日志文件）。

`./data/` 已被根 `.gitignore` 的 `**/data/` 规则忽略，`.env` 也被忽略。

## 常见问题

### 管理界面打不开 / 15672 无响应

确认用的是 `-management` 镜像，且容器已经 healthy。刚 `up` 完的几秒内插件还没加载完，
`docker compose logs -f rabbitmq` 里出现
`Management plugin: HTTP (non-TLS) listener started on port 15672` 才算就绪。

### 发布变慢、日志出现 memory resource limit alarm

达到内存告警阈值后 RabbitMQ 会阻塞 publisher（消费端不受影响）。用
`docker exec rabbitmq rabbitmqctl status` 看当前用量，然后下调
`conf/rabbitmq.conf` 里的 `vm_memory_high_watermark.relative`（默认 0.6），改完
`docker compose up -d` 重建容器生效：

```bash
# conf/rabbitmq.conf
vm_memory_high_watermark.relative = 0.4
```

4.4 起 `RABBITMQ_VM_MEMORY_HIGH_WATERMARK` 这类环境变量已被官方废弃，设置后容器直接
报 `deprecated environment variables detected` 并拒绝启动，所以阈值只能写配置文件。
应急（不改文件）也可以执行
`docker exec rabbitmq rabbitmqctl set_vm_memory_high_watermark 0.4`，但容器重启后失效。

### 数据“丢了” / 重建容器后队列不见了

检查 compose 里的 `hostname` 是否还是 `rabbitmq`。RabbitMQ 的数据目录名带节点 hostname，
改了就认不到旧数据。另外不要把 `./data` 挂到别的路径。

### 端口冲突

本机已装 RabbitMQ（brew 等）会占用 5672 / 15672，改 `.env` 里的
`RABBITMQ_AMQP_PORT` / `RABBITMQ_MANAGEMENT_PORT`，或先停掉本机服务。

### guest 用户连不上

`guest` 默认只允许 localhost 登录，容器里访问才通。本模板默认用 `admin`，不受这个限制；
如果手动建了 guest 并要从宿主机连，需要 `loopback_users.guest = false`（不建议，本地也够用）。

### 集群 / 多节点

不在本模板范围内。需要镜像队列与多节点时另建 compose，节点名、cookie、网络都要显式配置。
