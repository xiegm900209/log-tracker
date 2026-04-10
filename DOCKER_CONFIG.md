# Docker 容器部署配置说明

## ✅ 当前状态

容器已正常运行，所有功能测试通过！

### 访问地址
- **主站**: http://172.16.2.164:8089
- **原站点**: http://172.16.2.164:8083

### 测试结果
| 功能 | 状态 | 说明 |
|------|------|------|
| 日志查询 | ✅ 成功 | 查询到 21 条日志 |
| 交易类型追踪 | ✅ 成功 | 追踪到 21 条日志，1 个 TraceID 分组 |
| 服务列表 | ✅ 正常 | 34 个应用 |
| 交易类型列表 | ✅ 正常 | 12 个交易类型 |

---

## 🔧 关键配置修复

### 1. 日志目录路径

**问题**: 配置文件使用宿主机路径 `/root/sft/testlogs`

**解决**: 修改为容器内路径 `/app/logs`

```json
{
  "sft-aipg": "/app/logs/sft-aipg",
  "sft-trxqry": "/app/logs/sft-trxqry",
  ...
}
```

### 2. 交易类型配置格式

**问题**: API 返回格式包含外层包装 `{"success": true, "transaction_types": {...}}`

**解决**: 直接使用内部数据格式 `{...}`

```json
{
  "100001": {
    "name": "代收",
    "apps": ["sft-aipg", "sft-batchapi", ...]
  },
  ...
}
```

### 3. 后端代码路径

**问题**: 硬编码宿主机路径 `/root/sft/log-tracker/config`

**解决**: 修改为容器内路径 `/app/config`

修改位置：
- `/app/backend/app_main.py`
  - Line 15: `config_dir='/app/config'`
  - Line 15: `log_dir='/app/logs'`

---

## 📋 配置文件说明

### 容器挂载

```yaml
volumes:
  - /root/sft/testlogs:/app/logs:ro          # 日志目录（只读）
  - /root/sft/log-tracker/config:/app/config  # 配置文件
```

### 配置文件位置

| 文件 | 宿主机路径 | 容器内路径 |
|------|-----------|-----------|
| 交易类型 | `/root/sft/log-tracker/config/transaction_types.json` | `/app/config/transaction_types.json` |
| 日志目录 | `/root/sft/log-tracker/config/log_dirs.json` | `/app/config/log_dirs.json` |
| 应用配置 | `/root/sft/log-tracker/config/app_config.json` | `/app/config/app_config.json` |

---

## 🔄 配置同步

### 方式一：使用同步脚本

```bash
cd /root/sft/log-tracker
./sync-config.sh
```

### 方式二：手动同步

```bash
# 同步交易类型
curl http://172.16.2.164:8083/api/transaction-types | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('transaction_types', {}), indent=2, ensure_ascii=False))" \
  > config/transaction_types.json

# 同步日志目录
curl http://172.16.2.164:8083/api/config/log-dirs | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d, indent=2, ensure_ascii=False))" \
  > config/log_dirs.json
```

### 方式三：直接编辑

配置文件挂载后，直接编辑宿主机上的文件，容器会自动生效（无需重启）。

---

## 🐳 重新构建镜像（如需要）

```bash
cd /root/sft/log-tracker
docker build -t log-tracker:v2.3.7 .
docker rm -f log-tracker
docker run -d \
  --name log-tracker \
  -p 8089:80 \
  -v /root/sft/testlogs:/app/logs:ro \
  -v ./config:/app/config \
  log-tracker:v2.3.7
```

---

## 📊 当前配置统计

| 项目 | 数量 |
|------|------|
| 交易类型 | 12 个 |
| 应用日志目录 | 34 个 |
| 日志文件（2026040809） | 多个（压缩） |

---

## ⚠️ 注意事项

1. **日志目录必须挂载**: 否则无法查询日志
2. **配置文件格式**: 必须是纯 JSON 对象，不能有外层包装
3. **路径使用容器内路径**: `/app/logs` 和 `/app/config`
4. **配置自动加载**: 修改配置文件后无需重启容器

---

**最后更新**: 2026-04-10 12:00  
**版本**: v2.3.7
