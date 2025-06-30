# 服务信息
`Grafana`: `127.0.0.1:3000`
`Prometheus`: `127.0.0.1:9090`
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
    "Interval": "10s"
  }
}
EOF
```

注册后访问`127.0.0.1:8500`查看服务列表，发现新增了一个`order-service`服务。