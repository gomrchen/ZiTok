# ZiTok

知识向短视频社交平台

## 项目简介

ZiTok 是一个面向知识分享的短视频社交平台，结合了短视频与笔记功能，帮助用户在观看视频的同时记录和分享知识。

## 功能特性

- **视频浏览与发现**：推荐、精选、关注三种浏览模式
- **视频播放**：全屏播放、进度控制、网络感知预加载
- **笔记系统**：支持 Markdown 笔记创作，关联视频内容
- **社交互动**：点赞、评论、私信聊天、群聊
- **用户中心**：个人资料管理、作品管理、收藏夹
- **智能搜索**：基于 Elasticsearch 的全文搜索和语义搜索

## 技术栈

### 前端 (Flutter)
- **框架**: Flutter 3.x (Dart)
- **状态管理**: Provider
- **路由**: GoRouter
- **网络**: Dio
- **本地存储**: Hive + SharedPreferences
- **视频播放**: video_player + chewie

### 后端 (Go)
- **语言与框架**: Go 1.21, Kitex(RPC), Hertz(HTTP)
- **数据存储**: MySQL(GORM), Redis, Elasticsearch
- **消息队列**: Kafka
- **服务发现**: etcd
- **AI搜索**: OpenAI API 语义检索
- **部署**: Docker, Kubernetes

## 项目结构

```
ZiTok/
├── frontend/          # Flutter 移动端应用
│   ├── lib/
│   │   ├── models/        # 数据模型
│   │   ├── providers/     # 状态管理
│   │   ├── services/      # API 服务层
│   │   ├── repositories/  # 数据仓库层
│   │   ├── views/         # 页面视图
│   │   ├── widgets/       # 通用组件
│   │   ├── routes/        # 路由配置
│   │   ├── theme/         # 主题配置
│   │   └── utils/         # 工具函数
│   └── docs/          # 前端文档
├── backend/           # Go 微服务后端
│   ├── app/               # 业务服务
│   │   ├── gateway/       # API 网关
│   │   ├── user/          # 用户服务
│   │   ├── video/         # 视频服务
│   │   ├── interaction/   # 互动服务
│   │   └── social/        # 社交服务
│   ├── cmd/               # 服务入口
│   ├── config/            # 配置文件
│   ├── idl/               # Thrift 接口定义
│   ├── pkg/               # 公共库
│   └── k8s/               # Kubernetes 部署配置
└── docs/              # 项目文档
```

## 快速开始

### 前端开发

```bash
cd frontend

# 安装依赖
flutter pub get

# 运行应用（开发模式）
flutter run

# 构建发布版本
flutter build apk --release   # Android
flutter build ios --release   # iOS
flutter build windows         # Windows
```

### 后端部署

```bash
cd backend

# 启动基础服务
make env-up

# 启动微服务
make user        # 用户服务
make video       # 视频服务
make interaction # 互动服务
make social      # 社交服务
make gateway     # API 网关
```

详细部署指南请参考 [backend/README.md](./backend/README.md)

## 文档

- [前端组件说明](./frontend/docs/components.md)
- [后端 API 文档](https://2pr5l6um26.apifox.cn)
- [系统设计说明书](./docs/知音_系统设计说明书.pdf)
- [数据库设计说明书](./docs/知音_数据库设计说明书.pdf)

## 开发规范

- [分支规范](./docs/分支规范.md)

## License

MIT License