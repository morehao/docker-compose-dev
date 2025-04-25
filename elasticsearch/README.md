# 项目说明
通过 `docker-compose.yml` 文件构建了一个完整的 `Elastic` 环境，包括核心组件（`Elasticsearch`）和管理工具（`Kibana`）。

同时，使用 `Go` 语言编写了一个简单的调用示例，用于演示 `Elasticsearch` 的基本用法。

# 启动和停止

启动 `Elastic` ：
```
docker-compose up -d
```
停止 `Elastic` ：
```
docker-compose down
```

# 服务信息
- `Elasticsearch`：`127.0.0.1:9200`
- `Kibana`（浏览器访问控制台）：`127.0.0.1:5601`

# 数据导入
使用 `Bulk API` 将 `accounts.json` 批量导入到 `Elasticsearch` 的 `accounts` 索引中
```bash
curl -H "Content-Type: application/x-ndjson" -XPOST http://localhost:9200/accounts/_bulk --data-binary @accounts.json
```
# 安装分词器
1. 在容器内安装分词器
    ```shell
    docker exec -it elasticsearch /bin/bash
    bin/elasticsearch-plugin install https://get.infini.cloud/elasticsearch/analysis-ik/8.16.6
    rm -rf analysis-ik-Latest.zip
    ```
2. 重启容器并验证
    ```shell
    docker restart elasticsearch
    curl -X GET "http://localhost:9200/_cat/plugins?v"
    ```
   输出结果如下：
   ```shell
   name         component   version
   0a6109ae18ba analysis-ik 8.16.6
   ```
3. 使用分词器
   ```bash
   curl -X POST "http://localhost:9200/accounts/_analyze" -H "Content-Type: application/json" -d '{"analyzer":"ik_max_word","text":"你好明天"}'
   # 输出如下   
   {"tokens":[{"token":"你好","start_offset":0,"end_offset":2,"type":"CN_WORD","position":0},{"token":"明天","start_offset":2,"end_offset":4,"type":"CN_WORD","position":1}]}
   ```
   
