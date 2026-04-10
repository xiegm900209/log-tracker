#!/bin/bash
# 交易日志链路追踪系统 - Docker 快速启动脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 交易日志链路追踪系统 - Docker 启动脚本"
echo "=========================================="

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

# 检查镜像是否存在
if ! docker images log-tracker | grep -q v2.3.6; then
    echo "📦 镜像不存在，开始构建..."
    docker build -t log-tracker:v2.3.6 .
fi

# 停止并删除旧容器
echo "🧹 清理旧容器..."
docker rm -f log-tracker 2>/dev/null || true

# 启动容器
echo "🚀 启动容器..."
docker run -d \
  --name log-tracker \
  -p 8089:80 \
  -v /root/sft/testlogs:/app/logs:ro \
  -v "$SCRIPT_DIR/config:/app/config" \
  --restart unless-stopped \
  log-tracker:v2.3.6

# 等待容器启动
echo "⏳ 等待服务启动..."
sleep 5

# 检查容器状态
if docker ps | grep -q log-tracker; then
    echo "✅ 容器启动成功！"
    echo ""
    echo "🌐 访问地址：http://localhost:8089"
    echo "📋 容器名称：log-tracker"
    echo "📦 镜像版本：v2.3.5"
    echo ""
    echo "常用命令:"
    echo "  查看日志：docker logs -f log-tracker"
    echo "  停止容器：docker stop log-tracker"
    echo "  重启容器：docker restart log-tracker"
    echo "  进入容器：docker exec -it log-tracker /bin/bash"
else
    echo "❌ 容器启动失败，请查看日志:"
    docker logs log-tracker
    exit 1
fi
