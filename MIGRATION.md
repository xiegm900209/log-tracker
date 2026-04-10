# 镜像迁移指南

## 📦 已导出镜像

| 项目 | 详情 |
|------|------|
| **文件位置** | `/root/sft/log-tracker/log-tracker-v2.3.8.tar` |
| **文件大小** | 53MB |
| **镜像版本** | v2.3.8 |
| **镜像 ID** | fc09479ee35c |

---

## 🚀 在其他机器上运行

### 步骤 1：传输镜像文件

**方式一：scp 传输**
```bash
scp /root/sft/log-tracker/log-tracker-v2.3.8.tar user@target-server:/tmp/
```

**方式二：使用 U 盘或网络存储**
```bash
# 复制文件到 U 盘
cp /root/sft/log-tracker/log-tracker-v2.3.8.tar /mnt/usb/

# 在目标机器从 U 盘复制
cp /mnt/usb/log-tracker-v2.3.8.tar /tmp/
```

---

### 步骤 2：导入镜像

在目标机器上执行：

```bash
# 导入镜像
docker load -i /tmp/log-tracker-v2.3.8.tar

# 验证导入成功
docker images log-tracker
```

预期输出：
```
REPOSITORY    TAG       SIZE      IMAGE ID
log-tracker   v2.3.8    218MB     fc09479ee35c
```

---

### 步骤 3：准备配置文件

**创建配置目录：**
```bash
mkdir -p /opt/log-tracker/config
```

**同步配置（可选）：**
```bash
# 如果目标机器可以访问源机器
curl http://172.16.2.164:8083/api/transaction-types | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('transaction_types', {}), indent=2, ensure_ascii=False))" \
  > /opt/log-tracker/config/transaction_types.json

curl http://172.16.2.164:8083/api/config/log-dirs | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d, indent=2, ensure_ascii=False))" \
  > /opt/log-tracker/config/log_dirs.json
```

**或手动创建配置：**
```bash
# 编辑配置文件
vi /opt/log-tracker/config/transaction_types.json
vi /opt/log-tracker/config/log_dirs.json
```

---

### 步骤 4：启动容器

```bash
docker run -d \
  --name log-tracker \
  -p 8089:80 \
  -v /目标/日志/路径:/app/logs:ro \
  -v /opt/log-tracker/config:/app/config \
  --restart unless-stopped \
  log-tracker:v2.3.8
```

**参数说明：**
- `-p 8089:80` - 端口映射，根据实际调整
- `-v /目标/日志/路径:/app/logs:ro` - 替换为实际日志路径
- `-v /opt/log-tracker/config:/app/config` - 配置目录挂载
- `--restart unless-stopped` - 自动重启

---

### 步骤 5：验证运行

```bash
# 查看容器状态
docker ps | grep log-tracker

# 查看日志
docker logs -f log-tracker

# 测试 API
curl http://localhost:8089/api/services

# 测试日志查询
curl "http://localhost:8089/api/log-query?req_sn=xxx&service=sft-aipg&log_time=2026040809"
```

---

## 📋 快速启动脚本

在目标机器创建启动脚本：

```bash
#!/bin/bash
# /opt/log-tracker/start.sh

set -e

echo "🚀 启动交易日志链路追踪系统..."

# 检查镜像
if ! docker images log-tracker | grep -q v2.3.8; then
    echo "❌ 镜像未导入，请先执行：docker load -i log-tracker-v2.3.8.tar"
    exit 1
fi

# 停止旧容器
docker rm -f log-tracker 2>/dev/null || true

# 启动容器
docker run -d \
  --name log-tracker \
  -p 8089:80 \
  -v /root/sft/testlogs:/app/logs:ro \
  -v /opt/log-tracker/config:/app/config \
  --restart unless-stopped \
  log-tracker:v2.3.8

# 等待启动
sleep 5

# 验证
if docker ps | grep -q log-tracker; then
    echo "✅ 容器启动成功！"
    echo "🌐 访问地址：http://localhost:8089"
else
    echo "❌ 容器启动失败"
    docker logs log-tracker
    exit 1
fi
```

**使用：**
```bash
chmod +x /opt/log-tracker/start.sh
/opt/log-tracker/start.sh
```

---

## 🔧 常见问题

### 1. 端口被占用

```bash
# 检查端口占用
netstat -tlnp | grep 8089

# 改用其他端口
docker run -d \
  --name log-tracker \
  -p 8088:80 \
  ...
```

### 2. 日志目录权限

```bash
# 确保日志目录可读
ls -la /你的/日志/路径

# 添加读权限
chmod -R a+r /你的/日志/路径
```

### 3. 容器无法启动

```bash
# 查看详细日志
docker logs log-tracker

# 进入容器调试
docker run -it --rm log-tracker:v2.3.8 /bin/bash
```

---

## 📊 配置检查清单

| 项目 | 检查内容 | 状态 |
|------|---------|------|
| Docker 环境 | `docker --version` | ⬜ |
| 镜像导入 | `docker images log-tracker` | ⬜ |
| 日志目录 | 路径存在且有读权限 | ⬜ |
| 配置文件 | transaction_types.json | ⬜ |
| 配置文件 | log_dirs.json | ⬜ |
| 端口 | 8089 未被占用 | ⬜ |
| 容器启动 | `docker ps | grep log-tracker` | ⬜ |
| 功能测试 | API 访问正常 | ⬜ |

---

## 📞 技术支持

- **GitHub**: https://github.com/xiegm900209/log-tracker
- **文档**: /root/sft/log-tracker/DOCKER.md

---

**最后更新**: 2026-04-10 13:06  
**镜像版本**: v2.3.8
