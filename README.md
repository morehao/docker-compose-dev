# docker-compose-dev
基于 Docker Compose 进行环境搭建的docker-compose.yml文件合集

## 创建共享 network

创建共享 network，用于容器间通信

```bash
docker network create local_net
```
