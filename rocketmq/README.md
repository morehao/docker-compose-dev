# RocketMQ 本地开发环境

RocketMQ 5.x 单机开发环境：NameServer + Broker（gRPC Proxy 可选）+ Dashboard。
目标是「一条命令起来、能给本机 Go 服务和集成测试用」，不追求高可用与多副本。

## 组件与端口

| 组件 | 容器 | 宿主端口 | 说明 |
|---|---|---|---|
| NameServer | `rmqnamesrv` | `127.0.0.1:9876` | 路由注册 |
| Broker | `rmqbroker` | `127.0.0.1:10911` / `10909` | 10911 主通道（remoting），10909 VIP 通道 |
| Proxy（可选） | `rmqproxy` | `127.0.0.1:8080` / `8081` | 仅 RocketMQ 5.x gRPC 客户端需要 |
| Dashboard | `rocketmq-dashboard` | `127.0.0.1:8082` | Web 控制台 |

版本由 compose 里的变量控制，默认 `apache/rocketmq:5.5.0`、`apacherocketmq/rocketmq-dashboard:2.1.0`：

- RocketMQ 最新 GA 是 5.5.1，但 Docker Hub 上最新镜像只到 **5.5.0**（`latest` 也停在 5.5.0），
  想用 5.5.1 得自己基于官方 dist 构建镜像，本地开发没必要。
- 控制台必须锁版本：2.1.0 把容器内端口从 8080 改成了 **8082**。
  之前这里用 `latest` + `8082:8080`，上游一发版就静默失效（容器是 Up 的，页面打不开）。

## 前置

合集共用外部网络 `local_net`，只需创建一次：

```bash
docker network create local_net
```

## 启动 / 停止 / 重置

```bash
docker compose up -d                      # namesrv + broker + dashboard
docker compose --profile proxy up -d      # 额外启动 gRPC proxy
docker compose down                       # 停止并删除容器，数据保留在 ./data
rm -rf ./data                             # 彻底重置：topic / 消息 / 消费位点一并清掉
```

数据与日志落在 `./data/`（`namesrv/logs`、`broker/store`、`broker/logs`、`proxy/logs`），
已被根 `.gitignore` 的 `**/data/` 规则忽略。

## 就绪检查

`up -d` 返回时 broker 还在启动中，用下面任一方式确认：

```bash
docker compose ps                                  # 看 healthy
docker exec rmqbroker sh mqadmin clusterList -n rmqnamesrv:9876
docker compose logs -f broker
```

## 用 Go 客户端连（golib/mqaccess/rocketmq）

`mqaccess/rocketmq` 用的是 `rocketmq-client-go/v2`（remoting 协议），
直接连 NameServer（9876）→ Broker（10911），**不经过 proxy**。
在 `golib` 仓库根目录执行：

```bash
export ROCKETMQ_NAMESERVER=127.0.0.1:9876
export ROCKETMQ_GROUP_NAME=golib-mqaccess-test
export ROCKETMQ_TOPIC=golib-mqaccess-test-topic
go test ./mqaccess/rocketmq/...
```

`golib` 侧的默认值就是 `127.0.0.1:9876`（见 `gtest/gtest/dsn.go`），所以不设 `ROCKETMQ_NAMESERVER` 也能跑。
测试不依赖预建 topic：broker 默认 `autoCreateTopicEnable = true`，由生产端发 warmup 消息自动建 topic。

## 创建 topic（可选）

想显式建 topic 时：

```bash
docker exec rmqbroker sh mqadmin updateTopic -n rmqnamesrv:9876 -c DefaultCluster -t TestTopic
```

## 常见问题

### 宿主机上的客户端连不上 broker（Docker Desktop / Colima）

broker 注册到 NameServer 的地址是 `brokerIP1`，默认取**容器内网 IP**。宿主机上的客户端拿到这个 IP 后要能连上：

- **OrbStack**（当前默认引擎）：宿主机可以直连容器 IP，默认配置即可；
- **Docker Desktop / Colima**：宿主机路由不到容器网段，会卡在连 broker 超时。
  把 `conf/broker.conf` 里的 `brokerIP1` 改成宿主机 LAN IP（注释里有示例）。

不要填 `127.0.0.1`：同网络里的 proxy / dashboard 也按这个地址连 broker，会连到它们自己。

### 控制台打不开

容器内端口是 **8082**，映射为 `127.0.0.1:8082:8082`。
`ROCKETMQ_CONSOLE_PORT` 这个环境变量新版不认（那是老 rocketmq-console 的），改端口用
`JAVA_OPTS: -Dserver.port=xxxx`。

### 内存占用太高

镜像启动脚本默认 NameServer/Proxy `-Xms1g`、Broker `-Xms2g`，compose 里已用 `HEAP_OPTS`
分别压到 512m / 1g。机器更紧张时可以继续下调。
