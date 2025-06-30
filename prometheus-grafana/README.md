# 服务信息
`Grafana`: `127.0.0.1:3000`
`Prometheus`: `127.0.0.1:9090`
`pushgateway`: `127.0.0.1:9091`
`Consul`: `127.0.0.1:8500`

# 操作
## 注册服务示例
``` bash
curl --request PUT --data @- http://localhost:8500/v1/agent/service/register <<EOF
{
  "ID": "order-service-1",
  "Name": "order-service",
  "Tags": ["primary", "v1"],
  "Address": "10.0.0.1",
  "Port": 8080,
  "Check": {
    "HTTP": "http://10.0.0.1:8080/health",
    "Interval": "10s",
    "Timeout": "2s",
    "DeregisterCriticalServiceAfter": "1m"
  }
}
EOF
```

注册后访问`127.0.0.1:8500`查看服务列表，发现新增了一个`order-service`服务。

## 删除服务示例

``` bash
curl --request PUT \
  http://localhost:8500/v1/agent/service/deregister/order-service-1
```

## push 数据示例

``` bash
curl -X POST \
  --data-binary @- \
  http://localhost:9091/metrics/job/my_batch_job/instance/myhost <<EOF
# TYPE my_job_duration_seconds gauge
my_job_duration_seconds 3.14
EOF
```

验证 `push` 的数据，访问 `127.0.0.1:9091/metrics`，发现新增了一个 `my_job_duration_seconds` 的 `gauge` 数据。