# Mihomo 使用说明

## 部署步骤

### 1. 配置代理节点

下载订阅并提取 proxies 部分：

```bash
curl -s "你的订阅地址" -o /tmp/proxies.yaml
python3 << 'EOF'
import yaml
with open('/tmp/proxies.yaml', 'r') as f:
    data = yaml.safe_load(f)
output = {
    'proxies': data.get('proxies', []),
    'proxy-groups': data.get('proxy-groups', [])
}
with open('config/proxies.yaml', 'w') as f:
    yaml.dump(output, f, allow_unicode=True, default_flow_style=False)
EOF
```

### 2. 启动服务

```bash
cd mihomo
docker compose up -d
```

### 3. 验证部署

```bash
# 检查容器状态
docker compose ps

# 检查端口
ss -tlnp | grep 7890

# 测试代理
curl -x http://127.0.0.1:7890 -s https://api.ip.sb/ip
```

## 端口说明

| 端口 | 说明 |
|------|------|
| 7890 | HTTP/SOCKS5 混合代理端口 |
| 9093 | RESTful API 端口 |

## 常用命令

```bash
# 查看日志
docker compose logs -f

# 重启服务（重载配置）
docker compose restart

# 重新加载配置（不重启）
docker compose exec mihomo kill -HUP 1

# 停止服务
docker compose down
```

## 故障排查

### 容器启动失败

```bash
docker compose logs mihomo
docker compose exec mihomo /mihomo -t -f /root/.config/mihomo/config.yaml
```

### 代理节点连接超时

```bash
# 检查订阅是否可访问
curl -s "你的订阅地址" | head

# 查看节点健康状态
curl http://127.0.0.1:9093/proxies/PROXY | python3 -c "import sys,json; d=json.load(sys.stdin); print('当前:', d['now'])"
```