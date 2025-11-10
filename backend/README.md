# ZiTok-VideoHub API

API文档: https://s.apifox.cn/e938def1-534a-419b-b74a-75a18b662375n

## 服务接口列表

### 1. 用户服务 (UserService)
- Register
- Login
- GetUserInfo
- UploadAvatar
- RefreshToken

### 2. 视频服务 (VideoService)
- Publish
- List
- Detail
- GetHotVideos
- Delete
- IncrementVisitCount
- IncrementLikeCount
- Search
- SemanticSearch

### 3. 互动服务 (InteractionService)
- Like
- GetLikes
- Comment
- GetComments
- DeleteComment
- LikeComment

### 4. 社交服务 (SocialService)
- PrivateChat
- RoomChat
- CreateChatRoom

## 技术栈

### 后端
- **语言与框架**: Go 1.21, Kitex(RPC), Hertz(HTTP), Thrift(IDL)
- **数据存储**: MySQL(GORM), Redis, Elasticsearch
- **中间件**: Kafka, etcd, JWT
- **AI与搜索**: OpenAI API, 向量检索
- **监控**: OpenTelemetry
- **部署**: Docker, Docker Compose

### 前端
- **框架**: Vue 3
- **构建工具**: Vite
- **UI组件库**: Element Plus
- **状态管理**: Pinia
- **路由**: Vue Router
- **HTTP客户端**: Axios
- **样式**: SCSS
- **包管理器**: npm

## 系统架构

基于微服务架构，划分为用户、视频、互动和社交四个核心服务，通过Gateway统一入口处理请求。服务间通过Kitex RPC框架通信，使用etcd进行服务发现。

## 核心实现

### 视频服务
- 基于OpenAI的语义搜索功能
- 视频元数据提取和标签管理
- 热门视频排行榜（访问量、点赞数）

### 缓存策略
- 热门视频使用Redis缓存
- 用户令牌缓存
- 点赞、访问量等计数器使用Redis实现
- 热门排行榜使用Redis Sorted Set
- 分服务的Redis DB隔离（用户服务DB0、视频服务DB1、社交服务DB2）

### 异步处理
- 视频上传后通过Kafka消息队列异步处理
- 视频封面生成、元数据提取(时长、分辨率)
- 异步数据写入与统计更新
- 异步更新Elasticsearch索引和向量数据库

### 社交功能
- 基于WebSocket的实时聊天
- 支持私聊消息和聊天室
- 聊天记录持久化存储

### 搜索功能
- 基于Elasticsearch的全文搜索
- 集成OpenAI API的语义搜索
- 支持多字段复合查询
- 搜索结果缓存优化

### 安全性
- JWT用户认证
- API访问频率限制
- 视频内容安全检查
- 敏感信息加密存储

## 开发与部署

项目使用Makefile自动化构建，支持单独编译和部署各个服务。环境依赖通过Docker Compose管理，包括MySQL、Redis、etcd、Elasticsearch和Kafka等。

### 环境要求
- Docker 20.10+
- Docker Compose v2.0+
- Go 1.21+
- Make

### 快速开始

注意事项：嵌入式向量数据库没有持久化功能，使用词意搜索前请至少上传五个视频（服务启动后）

1. 克隆项目
```bash
git clone https://github.com/yxrxy/videoHub.git
cd videoHub
```

2. 配置环境变量
```bash
cp config/config.yaml.example config/config.yaml
mkdir -p docker/data/elasticsearch && sudo chown -R 1000:1000 docker/data/elasticsearch
# 修改配置，包括：
# - openai keys, upyun keys
```

3. 启动基础服务
```bash
make env-up 
# 启动 MySQL、Redis、Elasticsearch、Kafka、etcd
```

4. 编译并启动服务
```
make user        # 启动用户服务
make video       # 启动视频服务
make interaction #启动评论，点赞(视频交互)服务
make social      # 启动社交服务
make gateway     # 启动网关服务

make frontend-build #docker构建前端
make frontend #启动前端服务
（或直接在web目录下运行npm run dev，访问http://localhost:3000）
```

5. 访问前端页面

```
http://localhost:80
```

## Kubernetes 部署指南

### 环境要求
- Kubernetes 1.24+
- kubectl 已配置好集群访问权限
- 推荐节点系统 Ubuntu 20.04/22.04 LTS
- 节点需开放 80/443/30000+ 端口（NodePort/Ingress）
- 持久化目录需有正确权限（如 MySQL/ES/Kafka/Redis 数据目录）

### 前置部署

- **kube-flannel.yml（Flannel 网络插件）**
  - 作用：为 Kubernetes 集群提供 Pod 网络互通能力，是最常用的 CNI 插件之一。
  - 部署顺序：必须在所有有状态服务和微服务启动前部署，否则 Pod 之间无法通信。
  - 部署命令：
    ```bash
    kubectl apply -f k8s/kube-flannel.yml
    ```
  - 注意事项：所有节点需开启必要的端口（如 UDP 8472），否则跨主机 Pod 网络不通。

- **nginx-ingress.yaml（Nginx Ingress Controller）**
  - 作用：为集群内服务提供 HTTP/HTTPS 统一入口，实现域名路由、SSL 终端等功能。
  - 部署顺序：建议在微服务和前端服务部署前就部署好，方便后续通过 Ingress 访问服务。
  - 部署命令：
    ```bash
    kubectl apply -f k8s/nginx-ingress.yaml
    ```
  - 注意事项：
    - 需结合 Service 和 Ingress 资源一起使用。
    - 如需公网访问，需开放 NodePort 或配置云厂商负载均衡。

### 关键注意事项
- **目录权限**：所有有状态服务（MySQL、Redis、Elasticsearch、Kafka、Zookeeper）需用 initContainer 或 securityContext 保证数据目录属主属组正确，否则容器会启动失败。
- **etcd 配置**：所有微服务配置均通过 etcd /config 路径下的 yaml 文件集中管理，需用 etcdctl 手动同步。
- **Kafka 配置**：如需禁用 SASL，需确保 k8s/config_k8supdate.yaml 及 etcd 配置中无 user/password 字段，且 Kafka deployment 环境变量无 SASL 相关项。
- **MySQL 初始化**：如数据库无表，需用 Job 或手动 kubectl cp+mysql 导入 config/sql 下所有 SQL 文件。

### 部署步骤
1. **准备基础设施**
   ```bash
   kubectl apply -f k8s/infrastructure.yaml
   # 包含 MySQL、Redis、Kafka、Zookeeper、Elasticsearch、etcd、Prometheus、Grafana 等
   ```
2. **初始化数据库表结构**
   - 推荐用 root 用户手动导入：
   ```bash
   kubectl cp config/sql/user.sql videohub/mysql-5796fb4744-bdqrz:/tmp/user.sql -n videohub && kubectl cp config/sql/video.sql videohub/mysql-5796fb4744-bdqrz:/tmp/video.sql -n videohub && kubectl cp config/sql/social.sql videohub/mysql-5796fb4744-bdqrz:/tmp/social.sql -n videohub && kubectl cp config/sql/interaction.sql videohub/mysql-5796fb4744-bdqrz:/tmp/interaction.sql -n videohub
   
   kubectl exec -n videohub mysql-5796fb4744-bdqrz（e.g.） -- mysql -uroot -p123456 -D videohub -e 'source /tmp/user.sql; source /tmp/video.sql; source /tmp/social.sql; source /tmp/interaction.sql;'
   ```
3. **同步微服务配置到 etcd**
   ```bash
   kubectl exec -n videohub etcd-xxx -- etcdctl --endpoints=http://127.0.0.1:2380 put /config "$(cat k8s/config_k8supdate.yaml)"
   ```
4. **启动微服务**
   ```bash
   kubectl apply -f k8s/microservices.yaml
   # 或分别 apply 各服务的 yaml
   ```
5. **重启服务使配置生效**
   ```bash
   kubectl rollout restart deployment video -n videohub
   # 依次重启 user、social、interaction、gateway
   ```
6. **前端部署**
   ```bash
   kubectl apply -f k8s/frontend.yaml
   # 或用 NodePort/Ingress 方式暴露 80 端口
   ```

### 常见问题与排查
- **CrashLoopBackOff**：多为目录权限、配置缺失、环境变量未注入等问题。
- **Kafka 认证失败**：检查 etcd/k8s 配置、Kafka deployment 环境变量，彻底禁用或统一 SASL。
- **MySQL 无表**：需手动导入 SQL，Job 只在新库初始化时自动执行。
- **etcd 配置未生效**：同步后需重启相关服务。

### 目录结构
```
.
├── app
│   ├── gateway
│   │   ├── handler
│   │   ├── model
│   │   ├── mw
│   │   ├── pack
│   │   ├── router
│   │   ├── rpc
│   │   └── ws
│   ├── interaction
│   │   ├── controllers
│   │   ├── domain
│   │   ├── infrastructure
│   │   ├── inject.go
│   │   └── usecase
│   ├── social
│   │   ├── controllers
│   │   ├── domain
│   │   ├── infrastructure
│   │   ├── inject.go
│   │   └── usecase
│   ├── user
│   │   ├── controllers
│   │   ├── domain
│   │   ├── infrastructure
│   │   ├── inject.go
│   │   └── usecase
│   └── video
│       ├── controllers
│       ├── domain
│       ├── infrastructure
│       ├── inject.go
│       └── usecase
├── cmd
│   ├── gateway
│   │   └── main.go
│   ├── interaction
│   │   └── main.go
│   ├── social
│   │   └── main.go
│   ├── user
│   │   └── main.go
│   └── video
│       └── main.go
├── config
│   ├── config.go
│   ├── config.yaml.example
│   ├── elasticsearch
│   │   ├── config
│   │   └── plugins
│   ├── kibana
│   │   ├── kibana.yml
│   │   └── node.options
│   ├── otel-collector
│   │   └── otel-collector-config.yaml
│   └── sql
│       ├── interaction.sql
│       ├── social.sql
│       ├── user.sql
│       └── video.sql
├── docker
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── env
│   │   ├── es.env
│   │   ├── etcd.env
│   │   ├── kafka.env
│   │   ├── kibana.env
│   │   ├── mysql.env
│   │   └── redis.env
│   └── script
│       ├── build.sh
│       ├── entrypoint.sh
│       └── etcd-monitor.sh
├── go.mod
├── go.sum
├── idl
│   ├── api
│   │   ├── interaction.thrift
│   │   ├── social.thrift
│   │   ├── user.thrift
│   │   └── video.thrift
│   ├── interaction.thrift
│   ├── model.thrift
│   ├── social.thrift
│   ├── user.thrift
│   └── video.thrift
├── k8s
│   ├── config_k8supdate.yaml        # 统一微服务配置（同步到etcd）
│   ├── mysql-init.yaml              # MySQL初始化Job（可选）
│   ├── infrastructure.yaml          # 基础设施服务（MySQL、Redis、Kafka、ES、etcd等）
│   ├── configmap.yaml               # 配置中心ConfigMap示例
│   ├── microservices.yaml           # 微服务部署（user、video、social、interaction、gateway等）
│   ├── kube-flannel.yml             # Flannel网络插件
│   ├── coredns.yaml                 # CoreDNS配置
│   ├── nginx-ingress.yaml           # Nginx Ingress Controller
├── kitex_gen
│   ├── interaction
│   │   ├── interaction.go
│   │   ├── interactionservice
│   │   ├── k-consts.go
│   │   └── k-interaction.go
│   ├── model
│   │   ├── k-consts.go
│   │   ├── k-model.go
│   │   └── model.go
│   ├── social
│   │   ├── k-consts.go
│   │   ├── k-social.go
│   │   ├── social.go
│   │   └── socialservice
│   ├── user
│   │   ├── k-consts.go
│   │   ├── k-user.go
│   │   ├── user.go
│   │   └── userservice
│   └── video
│       ├── k-consts.go
│       ├── k-video.go
│       ├── video.go
│       └── videoservice
├── Makefile
├── pkg
│   ├── base
│   │   ├── client
│   │   ├── context
│   │   ├── pack.go
│   │   └── telemetry.go
│   ├── constants
│   │   └── constants.go
│   ├── errno
│   │   ├── code.go
│   │   ├── code_service.go
│   │   ├── default.go
│   │   └── errno.go
│   ├── jwt
│   │   └── jwt.go
│   ├── kafka
│   │   └── kafka.go
│   ├── middleware
│   │   ├── log.go
│   │   └── respond.go
│   ├── storage
│   │   └── storage.go
│   ├── upyun
│   │   └── upyun.go
│   └── utils
│       └── time.go
└── README.md
```

测试用例请参考Apifox链接。

## 云部署指南

### 云服务器要求
- Ubuntu 20.04/22.04 LTS
- 80/443端口开放（用于HTTP/HTTPS服务）

### 云服务商选择
推荐使用以下云服务商：
- 阿里云 ECS
- 腾讯云 CVM
- 华为云 ECS
- AWS EC2

### 部署步骤

1. 服务器初始化
```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装必要工具
sudo apt install -y git make docker.io

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 启动 Docker 服务
sudo systemctl start docker
sudo systemctl enable docker
```

2. 配置HTTPS证书
```bash
# 安装 Certbot
sudo apt install -y certbot

# 获取证书（替换为你的域名）
sudo certbot certonly --standalone -d 「your-domain.com」
```

3. 修改配置文件
```bash
# 修改 config/config.yaml 中的配置
vim config/config.yaml

# 主要修改以下配置：
# - 数据库连接信息
# - Redis连接信息
# - OpenAI API Key
# - 又拍云配置
```

4. 使用 Docker Compose 部署
```bash
# 启动基础设施服务（MySQL、Redis、Elasticsearch、Kafka、etcd）
make env-up

# 分别启动各个微服务
make user        # 启动用户服务
make video       # 启动视频服务
make interaction # 启动评论，点赞(视频交互)服务
make social      # 启动社交服务
make gateway     # 启动网关服务

make frontend-build #docker构建前端
make frontend #启动前端服务

# 查看服务状态
docker-compose ps
```

### 常见问题

1. 服务无法访问
- 检查安全组端口是否开放
- 检查 Docker 容器状态
- 查看服务日志：`docker-compose logs [service_name]`

### 运维命令

```bash
# 查看所有服务状态
docker-compose ps

# 重启特定服务
docker-compose restart [service_name]

# 查看服务日志
docker-compose logs -f [service_name]

# 进入容器
docker-compose exec [service_name] bash

# 更新服务
git pull
然后重新启动

# 清理日志和临时文件
docker system prune
```