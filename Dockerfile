# 交易日志链路追踪系统 - Docker 镜像
# 版本：v2.3.5
# 基于 Python 3.9 + Nginx

# ============================================
# 阶段 1: 构建前端
# ============================================
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend

# 复制前端源码
COPY frontend/package*.json ./
RUN npm install

COPY frontend/ ./
RUN npm run build

# ============================================
# 阶段 2: 生产环境
# ============================================
FROM python:3.9-slim

LABEL maintainer="xiegm900209"
LABEL version="2.3.5"
LABEL description="交易日志链路追踪系统 - Log Tracker"

# 设置环境变量
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_ENV=production \
    FLASK_APP=app_main.py

# 安装 Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    && rm -rf /var/lib/apt/lists/*

# 创建工作目录
WORKDIR /app

# 安装 Python 依赖
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# 复制后端代码
COPY backend/ ./backend/

# 复制配置文件目录
COPY config/ ./config/

# 从构建阶段复制前端构建产物
COPY --from=frontend-builder /app/frontend/dist /var/www/log-tracker

# 复制 Nginx 配置
COPY nginx-docker.conf /etc/nginx/conf.d/default.conf

# 创建日志目录并删除默认配置
RUN mkdir -p /var/log/nginx \
    && rm -f /etc/nginx/sites-enabled/default

# 暴露端口
EXPOSE 80

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/api/services || exit 1

# 启动脚本
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

# 启动命令
CMD ["/docker-entrypoint.sh"]
