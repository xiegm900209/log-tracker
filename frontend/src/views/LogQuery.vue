<template>
  <div class="log-query">
    <el-page-header @back="$router.go(-1)" content="日志追踪查询"></el-page-header>

    <el-card class="query-card">
      <template #header>
        <span>查询条件</span>
      </template>

      <el-form :model="queryForm" label-width="120px" :inline="true">
        <el-form-item label="REQ_SN">
          <el-input 
            v-model="queryForm.reqSn" 
            placeholder="请输入 REQ_SN"
            clearable
            style="width: 300px"
          ></el-input>
        </el-form-item>

        <el-form-item label="商户号">
          <el-input 
            v-model="queryForm.merchantNo" 
            placeholder="请输入商户号"
            clearable
            style="width: 200px"
          ></el-input>
        </el-form-item>

        <el-form-item label="日志时间" required>
          <el-input 
            v-model="queryForm.logTime" 
            placeholder="格式：2026040809 (年月日时) *必填"
            clearable
            style="width: 280px"
            maxlength="10"
          >
            <template #prefix>
              <el-icon><Clock /></el-icon>
            </template>
          </el-input>
        </el-form-item>

        <el-form-item label="服务">
          <el-select 
            v-model="queryForm.service" 
            placeholder="选择服务"
            clearable
            style="width: 200px"
          >
            <el-option
              v-for="service in services"
              :key="service"
              :label="service"
              :value="service"
            ></el-option>
          </el-select>
        </el-form-item>

        <el-form-item>
          <el-button type="primary" @click="searchLogs" :loading="loading">查询</el-button>
          <el-button @click="resetForm">重置</el-button>
        </el-form-item>
      </el-form>

      <div class="form-tips">
        <el-alert
          title="使用说明"
          type="info"
          :closable="false"
          show-icon
        >
          <p>1. <strong>REQ_SN</strong>：交易序列号，用于定位具体交易</p>
          <p>2. <strong>日志时间</strong>：格式为 <code>YYYYMMDDHH</code>（如：2026040809），用于定位日志文件</p>
          <p>3. <strong>商户号</strong>：可选，用于进一步过滤结果</p>
          <p>4. 查询逻辑：先根据时间定位日志文件 → 找到包含 REQ_SN 的行 → 提取 TraceID → 显示所有包含该 TraceID 的日志</p>
        </el-alert>
      </div>
    </el-card>

    <el-card v-if="searchResults && searchResults.length > 0" class="results-card">
      <template #header>
        <div class="results-header">
          <div>
            <span>查询结果 ({{ searchResults.length }} 条)</span>
            <el-tag v-if="traceGroups.length > 0" type="warning" size="large" style="margin-left: 10px;">
              {{ traceGroups.length }} 个 TraceID 分组
            </el-tag>
          </div>
          <div class="result-actions">
            <el-button size="small" @click="exportResults">导出 CSV</el-button>
          </div>
        </div>
      </template>

      <!-- 多 TraceID 分组展示 -->
      <div v-if="traceGroups.length > 1" class="trace-groups">
        <el-collapse v-model="activeGroups" accordion>
          <el-collapse-item
            v-for="group in traceGroups"
            :key="group.trace_id"
            :name="group.trace_id"
          >
            <template #title>
              <div class="group-title">
                <el-tag type="success" size="small">TraceID: {{ group.trace_id }}</el-tag>
                <span class="group-info">{{ group.log_count }} 条日志 | {{ group.req_sn_count }} 次 REQ_SN 匹配</span>
                <span class="group-time">{{ group.first_timestamp }}</span>
              </div>
            </template>
            <el-table :data="group.logs" style="width: 100%" max-height="500" border stripe>
              <el-table-column type="expand">
                <template #default="{ row }">
                  <div class="expand-content">
                    <h4>完整日志内容:</h4>
                    <pre>{{ row.fullContent }}</pre>
                  </div>
                </template>
              </el-table-column>
              <el-table-column prop="timestamp" label="时间戳" width="180" sortable></el-table-column>
              <el-table-column prop="service" label="服务" width="150"></el-table-column>
              <el-table-column prop="level" label="级别" width="80">
                <template #default="{ row }">
                  <el-tag :type="getLevelType(row.level)" size="small">{{ row.level }}</el-tag>
                </template>
              </el-table-column>
              <el-table-column prop="traceId" label="TraceID" width="120"></el-table-column>
              <el-table-column prop="thread" label="线程" width="200" show-overflow-tooltip></el-table-column>
              <el-table-column prop="content" label="日志内容" show-overflow-tooltip min-width="300"></el-table-column>
            </el-table>
          </el-collapse-item>
        </el-collapse>
      </div>

      <!-- 单 TraceID 或合并展示 -->
      <el-table 
        v-else
        :data="searchResults" 
        style="width: 100%" 
        max-height="600"
        border
        stripe
        :row-class-name="tableRowClassName"
      >
        <el-table-column type="expand">
          <template #default="{ row }">
            <div class="expand-content">
              <h4>完整日志内容:</h4>
              <pre>{{ row.fullContent }}</pre>
            </div>
          </template>
        </el-table-column>

        <el-table-column prop="timestamp" label="时间戳" width="180" sortable></el-table-column>
        <el-table-column prop="service" label="服务" width="150"></el-table-column>
        <el-table-column prop="level" label="级别" width="80">
          <template #default="{ row }">
            <el-tag :type="getLevelType(row.level)" size="small">{{ row.level }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="traceId" label="TraceID" width="120"></el-table-column>
        <el-table-column prop="thread" label="线程" width="200" show-overflow-tooltip></el-table-column>
        <el-table-column prop="content" label="日志内容" show-overflow-tooltip min-width="300"></el-table-column>
      </el-table>
    </el-card>

    <el-empty v-else-if="searched" description="没有找到匹配的日志"></el-empty>
  </div>
</template>

<script>
import { Clock } from '@element-plus/icons-vue'
import axios from 'axios'

export default {
  name: 'LogQuery',
  components: {
    Clock
  },
  data() {
    return {
      loading: false,
      services: [],
      queryForm: {
        reqSn: '',
        merchantNo: '',
        logTime: '',
        service: ''
      },
      searchResults: [],
      searched: false,
      traceId: '',
      traceGroups: [],
      activeGroups: []
    }
  },
  mounted() {
    this.fetchServices()
  },
  methods: {
    async fetchServices() {
      try {
        const response = await axios.get('/api/services')
        if (response.data.success) {
          this.services = response.data.services
        }
      } catch (error) {
        console.error('获取服务列表失败:', error)
      }
    },

    async searchLogs() {
      if (!this.queryForm.reqSn && !this.queryForm.merchantNo) {
        this.$message.warning('请输入 REQ_SN 或商户号')
        return
      }

      // 强制要求输入日志时间
      if (!this.queryForm.logTime) {
        this.$message.error('请输入日志时间（必填），格式：2026040809')
        return
      }

      // 验证时间格式：YYYYMMDDHH (10 位数字)
      const timePattern = /^\d{10}$/
      if (!timePattern.test(this.queryForm.logTime)) {
        this.$message.error('日志时间格式不正确，应为 10 位数字（如：2026040809）')
        return
      }

      this.loading = true
      this.searched = true
      this.traceId = ''

      try {
        const params = {}
        
        if (this.queryForm.reqSn) {
          params.req_sn = this.queryForm.reqSn
        }
        
        if (this.queryForm.merchantNo) {
          params.merchant_no = this.queryForm.merchantNo
        }
        
        params.log_time = this.queryForm.logTime
        
        if (this.queryForm.service) {
          params.service = this.queryForm.service
        }

        const response = await axios.get('/api/log-query', { params })
        
        if (response.data.success) {
          this.searchResults = response.data.logs || []
          this.traceGroups = response.data.trace_groups || []
          this.traceId = response.data.trace_groups?.[0]?.trace_id || ''
          
          if (this.traceGroups.length > 0) {
            this.activeGroups = [this.traceGroups[0].trace_id]
          }
          
          if (this.searchResults.length === 0) {
            this.$message.info('未找到相关日志')
          } else if (this.traceGroups.length > 1) {
            this.$message.success(`找到 ${this.traceGroups.length} 个 TraceID 分组，共 ${this.searchResults.length} 条日志`)
          } else {
            this.$message.success(`找到 ${this.searchResults.length} 条日志记录`)
          }
        } else {
          this.$message.warning(response.data.message || '未找到相关日志')
          this.searchResults = []
          this.traceGroups = []
        }
      } catch (error) {
        console.error('查询失败:', error)
        this.$message.error('查询失败：' + (error.response?.data?.message || error.message))
        this.searchResults = []
      } finally {
        this.loading = false
      }
    },

    resetForm() {
      this.queryForm = {
        reqSn: '',
        merchantNo: '',
        logTime: '',
        service: ''
      }
      this.searchResults = []
      this.searched = false
      this.traceId = ''
    },

    getLevelType(level) {
      const typeMap = {
        'ERROR': 'danger',
        'WARN': 'warning',
        'INFO': 'success',
        'DEBUG': 'info'
      }
      return typeMap[level] || 'info'
    },

    tableRowClassName({ row }) {
      // 高亮显示包含 REQ_SN 的那一行
      if (row.isReqSnMatch) {
        return 'reqsn-highlight-row'
      }
      return ''
    },

    exportResults() {
      if (this.searchResults.length === 0) {
        this.$message.warning('没有可导出的数据')
        return
      }

      const headers = ['时间戳', '服务', '级别', 'TraceID', '线程', '日志内容']
      const rows = this.searchResults.map(row => [
        row.timestamp,
        row.service,
        row.level,
        row.traceId || '',
        row.thread || '',
        row.content
      ])

      const csvContent = [
        headers.join(','),
        ...rows.map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(','))
      ].join('\n')

      const blob = new Blob(['\ufeff' + csvContent], { type: 'text/csv;charset=utf-8' })
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.download = `log_query_${new Date().getTime()}.csv`
      link.click()
      
      this.$message.success('导出成功')
    }
  }
}
</script>

<style scoped>
.log-query {
  padding: 20px;
}

.query-card {
  margin-bottom: 20px;
}

.form-tips {
  margin-top: 15px;
}

.form-tips p {
  margin: 5px 0;
  font-size: 13px;
  line-height: 1.6;
}

.form-tips code {
  background-color: #f4f4f5;
  padding: 2px 6px;
  border-radius: 3px;
  font-family: 'Courier New', monospace;
  color: #d93025;
}

.trace-groups {
  margin-bottom: 20px;
}

.group-title {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
}

.group-info {
  font-size: 13px;
  color: #606266;
}

.group-time {
  font-size: 12px;
  color: #909399;
  margin-left: auto;
}

.results-card {
  margin-top: 20px;
}

.results-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 15px;
}

.result-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}

.expand-content {
  padding: 10px 20px;
  background-color: #f5f7fa;
}

.expand-content h4 {
  margin: 0 0 10px 0;
  color: #606266;
}

.expand-content pre {
  margin: 0;
  padding: 10px;
  background-color: #fff;
  border: 1px solid #e4e7ed;
  border-radius: 4px;
  white-space: pre-wrap;
  word-wrap: break-word;
  font-family: 'Courier New', monospace;
  font-size: 12px;
  max-height: 400px;
  overflow-y: auto;
}

:deep(.reqsn-highlight-row) {
  background-color: #f0f9ff !important;
}

:deep(.reqsn-highlight-row:hover) {
  background-color: #e0f2fe !important;
}
</style>
