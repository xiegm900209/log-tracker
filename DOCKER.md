# Docker 部署指南

## 🐳 快速开始

### 1. 构建镜像

```bash
cd /root/sft/log-tracker

# 构建镜像
docker build -t log-tracker:v2.3.5 .
```

### 2. 启动容器

#### 方式一：使用 docker run

```bash
docker run -d \
  --name log-tracker \
  -p 8080:80 \
  -v /root/sft/testlogs:/app/logs:ro \
  -v $(pwd)/config:/app/config \
  --restart unless-stopped \
  log-tracker:v2.3.5
```

#### 方式二：使用 docker-compose（推荐）

```bash
# 编辑 docker-compose.yml，修改日志目录挂载路径
# 然后启动：
docker-compose up -d
```

### 3. 访问系统

打开浏览器访问：**http://localhost:8080**

---

## 📋 配置说明

### 挂载日志目录

⚠️ **重要**: 容器需要访问日志文件才能查询日志，必须挂载日志目录！

```yaml
volumes:
  - /root/sft/testlogs:/app/logs:ro
```

**说明**:
- `/root/sft/testlogs` - 替换为你的实际日志路径
- `/app/logs` - 容器内路径，不要修改
- `:ro` - 只读模式，安全

### 自定义配置

如需修改配置，可挂载配置文件：

```yaml
volumes:
  - ./config:/app/config
```

配置文件：
- `config/log_dirs.json` - 日志目录配置（34 个应用）
- `config/transaction_types.json` - 交易类型配置（12 个交易类型）
- `config/app_config.json` - 应用配置

### 同步配置

从运行中的实例同步配置：

```bash
# 使用同步脚本
./sync-config.sh

# 或手动同步
curl http://172.16.2.164:8083/api/transaction-types > config/transaction_types.json
curl http://172.16.2.164:8083/api/config/log-dirs > config/log_dirs.json
```

配置会自动加载到容器中（无需重启）。

---

## 🔧 常用命令

### 查看容器状态

```bash
docker ps | grep log-tracker
```

### 查看日志

```bash
# 容器日志
docker logs -f log-tracker

# Flask 后端日志
docker exec log-tracker cat /tmp/flask.log

# Nginx 访问日志
docker exec log-tracker cat /var/log/nginx/access.log
```

### 进入容器

```bash
docker exec -it log-tracker /bin/bash
```

### 重启容器

```bash
docker restart log-tracker
```

### 停止容器

```bash
docker stop log-tracker
docker rm log-tracker
```

### 使用 docker-compose

```bash
# 启动
docker-compose up -d

# 停止
docker-compose down

# 查看日志
docker-compose logs -f

# 重建容器
docker-compose up -d --build
```

---

## 📊 资源限制

默认配置：
- CPU: 0.5 - 2.0 核
- 内存：512MB - 2GB

可根据实际情况调整 `docker-compose.yml` 中的 `deploy.resources` 配置。

---

## 🔍 故障排查

### 容器无法启动

```bash
# 查看容器日志
docker logs log-tracker

# 检查端口占用
netstat -tlnp | grep 8080
```

### 无法访问日志文件

确保挂载的日志目录路径正确且有读权限：

```bash
ls -la /你的/日志/路径
```

### API 请求失败

```bash
# 检查后端服务
docker exec log-tracker curl http://127.0.0.1:5000/api/services

# 查看 Flask 日志
docker exec log-tracker cat /tmp/flask.log
```

---

## 📦 镜像信息

- **基础镜像**: python:3.9-slim + node:18-alpine (构建阶段)
- **镜像大小**: 约 500MB
- **端口**: 80
- **健康检查**: 30 秒间隔

---

## 🚀 生产环境部署

### 1. 推送镜像到仓库

```bash
# 标记镜像
docker tag log-tracker:v2.3.5 your-registry/log-tracker:v2.3.5

# 推送
docker push your-registry/log-tracker:v2.3.5
```

### 2. 在其他服务器拉取运行

```bash
# 拉取镜像
docker pull your-registry/log-tracker:v2.3.5

# 启动容器
docker run -d \
  --name log-tracker \
  -p 80:80 \
  -v /你的/日志/路径:/app/logs:ro \
  --restart unless-stopped \
  your-registry/log-tracker:v2.3.5
```

---

## 📝 版本历史

- **v2.3.5** - Docker 容器化版本
- **v2.3.4** - 查询按钮布局优化
- **v2.3.3** - 交易类型管理复制/导出功能
- **v2.3.2** - 日志时间输入框优化
- **v2.3.1** - 强制日志时间参数
- **v2.3.0** - 首发版本

---

**维护者**: xiegm900209  
**GitHub**: https://github.com/xiegm900209/log-tracker
