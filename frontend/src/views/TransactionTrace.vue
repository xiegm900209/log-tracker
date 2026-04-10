<template>
  <div class="transaction-trace">
    <el-page-header @back="$router.go(-1)" content="交易类型日志追踪"></el-page-header>

    <el-card class="query-card">
      <template #header>
        <span>查询条件</span>
      </template>

      <el-form :model="queryForm" label-width="120px" :inline="true">
        <el-form-item label="交易类型">
          <el-select 
            v-model="queryForm.transactionType" 
            placeholder="请选择交易类型"
            style="width: 300px"
            @change="onTransactionTypeChange"
          >
            <el-option
              v-for="(info, key) in transactionTypes"
              :key="key"
              :label="`${key} - ${info.name}`"
              :value="key"
            >
              <span>{{ key }} - {{ info.name }}</span>
              <el-tag 
                v-for="app in info.apps" 
                :key="app"
                size="small" 
                style="margin-left: 5px"
              >{{ app }}</el-tag>
            </el-option>
          </el-select>
        </el-form-item>

        <el-form-item label="REQ_SN">
          <el-input 
            v-model="queryForm.reqSn" 
            placeholder="请输入 REQ_SN"
            clearable
            style="width: 300px"
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

        <el-form-item>
          <el-button type="primary" @click="searchTrace" :loading="loading">开始追踪</el-button>
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
          <p>1. <strong>选择交易类型</strong>：系统会自动加载该交易类型配置的关联应用列表</p>
          <p>2. <strong>输入 REQ_SN</strong>：交易序列号，用于定位具体交易</p>
          <p>3. <strong>输入日志时间</strong>：格式为 <code>YYYYMMDDHH</code>（如：2026040809），用于定位日志文件</p>
          <p>4. <strong>追踪逻辑</strong>：从第一个应用（入口应用）开始，根据 REQ_SN 提取 TraceID，然后依次查询所有关联应用的日志</p>
        </el-alert>
      </div>
    </el-card>

    <!-- 多 TraceID 分组展示 -->
    <el-card v-if="traceResult.success && traceResult.traceGroups.length > 0" class="trace-result-card">
      <template #header>
        <div class="result-header">
          <span>交易链路追踪结果</span>
          <el-tag type="warning">{{ traceResult.traceGroups.length }} 个 TraceID 分组</el-tag>
          <el-tag type="info">{{ traceResult.totalLogs }} 条日志</el-tag>
        </div>
      </template>

      <!-- TraceID 分组折叠面板 -->
      <el-collapse v-model="activeTraceGroup" accordion class="trace-collapse">
        <el-collapse-item
          v-for="(group, groupIndex) in traceResult.traceGroups"
          :key="group.trace_id"
          :name="group.trace_id"
        >
          <template #title>
            <div class="group-title">
              <el-tag type="success" size="small">TraceID: {{ group.trace_id }}</el-tag>
              <span class="group-info">{{ group.total_logs }} 条日志 | {{ group.req_sn_count }} 次 REQ_SN 匹配</span>
              <span class="group-time">{{ group.first_timestamp }}</span>
            </div>
          </template>

          <!-- 应用链路图 -->
          <div class="app-chain">
            <el-steps :active="getActiveAppIndex(group.trace_id)" align-center finish-status="success" class="chain-steps">
              <el-step
                v-for="(app, index) in group.apps"
                :key="app"
                :title="app"
                :description="getGroupAppLogCount(group, app) + ' 条日志'"
              >
                <template #icon>
                  <el-tag :type="getGroupAppLogCount(group, app) > 0 ? 'success' : 'info'" size="small">
                    {{ index + 1 }}
                  </el-tag>
                </template>
              </el-step>
            </el-steps>
          </div>

          <!-- 应用日志详情 -->
          <el-tabs v-model="activeAppTabs[group.trace_id]" class="app-tabs">
            <el-tab-pane
              v-for="app in group.apps"
              :key="app"
              :label="app"
              :name="app"
            >
              <template #label>
                <span>
                  {{ app }}
                  <el-tag 
                    :type="getGroupAppLogCount(group, app) > 0 ? 'success' : 'info'" 
                    size="small"
                    style="margin-left: 5px"
                  >
                    {{ getGroupAppLogCount(group, app) }}
                  </el-tag>
                </span>
              </template>

              <div v-if="getGroupAppLogs(group, app).length > 0" class="app-logs">
                <el-table 
                  :data="getGroupAppLogs(group, app)" 
                  style="width: 100%" 
                  max-height="500"
                  border
                  stripe
                  :row-class-name="getRowClassName"
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
                  <el-table-column prop="level" label="级别" width="80">
                    <template #default="{ row }">
                      <el-tag :type="getLevelType(row.level)" size="small">{{ row.level }}</el-tag>
                    </template>
                  </el-table-column>
                  <el-table-column prop="traceId" label="TraceID" width="120"></el-table-column>
                  <el-table-column prop="thread" label="线程" width="200" show-overflow-tooltip></el-table-column>
                  <el-table-column prop="content" label="日志内容" show-overflow-tooltip min-width="300"></el-table-column>
                </el-table>
              </div>
              <el-empty v-else description="该应用未找到相关日志"></el-empty>
            </el-tab-pane>
          </el-tabs>
        </el-collapse-item>
      </el-collapse>
    </el-card>

    <!-- 单 TraceID 展示（向后兼容） -->
    <el-card v-else-if="traceResult.success && traceResult.traceId" class="trace-result-card">
      <template #header>
        <div class="result-header">
          <span>交易链路追踪结果</span>
          <el-tag type="success">TraceID: {{ traceResult.traceId }}</el-tag>
          <el-tag type="info">{{ traceResult.totalLogs }} 条日志</el-tag>
        </div>
      </template>

      <!-- 应用链路图 -->
      <div class="app-chain">
        <el-steps :active="activeAppIndex" align-center finish-status="success" class="chain-steps">
          <el-step
            v-for="(app, index) in currentApps"
            :key="app"
            :title="app"
            :description="getAppLogCount(app) + ' 条日志'"
            @click="activeAppIndex = index"
          >
            <template #icon>
              <el-tag :type="getAppLogCount(app) > 0 ? 'success' : 'info'" size="small">
                {{ index + 1 }}
              </el-tag>
            </template>
          </el-step>
        </el-steps>
      </div>

      <!-- 应用日志详情 -->
      <el-tabs v-model="activeAppTab" class="app-tabs" @tab-click="onAppTabClick">
        <el-tab-pane
          v-for="(app, index) in currentApps"
          :key="app"
          :label="app"
          :name="app"
        >
          <template #label>
            <span>
              {{ app }}
              <el-tag 
                :type="getAppLogCount(app) > 0 ? 'success' : 'info'" 
                size="small"
                style="margin-left: 5px"
              >
                {{ getAppLogCount(app) }}
              </el-tag>
            </span>
          </template>

          <div v-if="getAppLogs(app).length > 0" class="app-logs">
            <el-table 
              :data="getAppLogs(app)" 
              style="width: 100%" 
              max-height="500"
              border
              stripe
              :row-class-name="getRowClassName"
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
              <el-table-column prop="level" label="级别" width="80">
                <template #default="{ row }">
                  <el-tag :type="getLevelType(row.level)" size="small">{{ row.level }}</el-tag>
                </template>
              </el-table-column>
              <el-table-column prop="traceId" label="TraceID" width="120"></el-table-column>
              <el-table-column prop="thread" label="线程" width="200" show-overflow-tooltip></el-table-column>
              <el-table-column prop="content" label="日志内容" show-overflow-tooltip min-width="300"></el-table-column>
            </el-table>
          </div>
          <el-empty v-else description="该应用未找到相关日志"></el-empty>
        </el-tab-pane>
      </el-tabs>
    </el-card>

    <el-empty v-else-if="searched" description="未找到交易链路信息"></el-empty>
  </div>
</template>

<script>
import { Clock } from '@element-plus/icons-vue'
import axios from 'axios'

export default {
  name: 'TransactionTrace',
  components: {
    Clock
  },
  data() {
    return {
      loading: false,
      transactionTypes: {},
      queryForm: {
        transactionType: '',
        reqSn: '',
        logTime: ''
      },
      currentApps: [],
      traceResult: {
        success: false,
        traceGroups: [],
        totalLogs: 0
      },
      searched: false,
      activeAppIndex: 0,
      activeAppTab: '',
      activeTraceGroup: '',
      activeAppTabs: {}
    }
  },
  mounted() {
    this.loadTransactionTypes()
  },
  methods: {
    async loadTransactionTypes() {
      try {
        const response = await axios.get('/api/transaction-types')
        if (response.data.success) {
          this.transactionTypes = response.data.transaction_types
        }
      } catch (error) {
        console.error('加载交易类型失败:', error)
        this.$message.error('加载交易类型失败')
      }
    },

    onTransactionTypeChange() {
      const typeInfo = this.transactionTypes[this.queryForm.transactionType]
      if (typeInfo) {
        this.currentApps = typeInfo.apps || []
      } else {
        this.currentApps = []
      }
    },

    async searchTrace() {
      if (!this.queryForm.transactionType) {
        this.$message.warning('请选择交易类型')
        return
      }

      if (!this.queryForm.reqSn) {
        this.$message.warning('请输入 REQ_SN')
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

      try {
        const params = {
          transaction_type: this.queryForm.transactionType,
          req_sn: this.queryForm.reqSn,
          log_time: this.queryForm.logTime
        }

        const response = await axios.get('/api/transaction-trace', { params })
        
        if (response.data.success) {
          this.traceResult = {
            success: true,
            traceGroups: response.data.trace_groups || [],
            totalLogs: response.data.total_logs
          }
          
          if (this.traceResult.traceGroups.length > 0) {
            // 默认展开第一个 TraceID 分组
            this.activeTraceGroup = this.traceResult.traceGroups[0].trace_id
            
            // 初始化每个分组的 activeAppTabs
            this.traceResult.traceGroups.forEach(group => {
              if (group.apps && group.apps.length > 0) {
                this.activeAppTabs[group.trace_id] = group.apps[0]
              }
            })
          }
          
          if (this.traceResult.totalLogs === 0) {
            this.$message.info('未找到相关日志')
          } else if (this.traceResult.traceGroups.length > 1) {
            this.$message.success(`找到 ${this.traceResult.traceGroups.length} 个 TraceID 分组，共 ${this.traceResult.totalLogs} 条日志`)
          } else {
            this.$message.success(`找到 ${this.traceResult.totalLogs} 条日志记录`)
          }
        } else {
          this.$message.warning(response.data.message || '未找到相关日志')
          this.traceResult = { success: false }
        }
      } catch (error) {
        console.error('追踪失败:', error)
        this.$message.error('追踪失败：' + (error.response?.data?.message || error.message))
        this.traceResult = { success: false }
      } finally {
        this.loading = false
      }
    },

    resetForm() {
      this.queryForm = {
        transactionType: '',
        reqSn: '',
        logTime: ''
      }
      this.currentApps = []
      this.traceResult = { success: false }
      this.searched = false
      this.activeAppIndex = 0
      this.activeAppTab = ''
    },

    // 多 TraceID 分组相关方法
    getGroupAppLogs(group, app) {
      return (group.app_logs && group.app_logs[app]) || []
    },

    getGroupAppLogCount(group, app) {
      return this.getGroupAppLogs(group, app).length
    },

    getActiveAppIndex(traceId) {
      const group = this.traceResult.traceGroups.find(g => g.trace_id === traceId)
      if (!group || !group.apps) return 0
      const activeApp = this.activeAppTabs[traceId]
      return group.apps.indexOf(activeApp)
    },

    // 单 TraceID 相关方法（向后兼容）
    getAppLogs(app) {
      return this.traceResult.appLogs[app] || []
    },

    getAppLogCount(app) {
      return this.getAppLogs(app).length
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

    getRowClassName({ row }) {
      if (row.isReqSnMatch) {
        return 'reqsn-highlight-row'
      }
      return ''
    },

    onAppTabClick(tab) {
      const index = this.currentApps.indexOf(tab.props.name)
      if (index >= 0) {
        this.activeAppIndex = index
      }
    }
  }
}
</script>

<style scoped>
.transaction-trace {
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

.trace-collapse {
  margin-top: 20px;
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

.trace-result-card {
  margin-top: 20px;
}

.result-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 15px;
}

.app-chain {
  margin-bottom: 30px;
  padding: 20px 0;
  background-color: #f5f7fa;
  border-radius: 4px;
}

.chain-steps {
  max-width: 100%;
}

.chain-steps :deep(.el-step__title) {
  font-size: 13px;
  font-weight: 500;
}

.chain-steps :deep(.el-step__description) {
  font-size: 12px;
  margin-top: 5px;
}

.chain-steps :deep(.el-step__head) {
  cursor: pointer;
}

.app-tabs {
  margin-top: 20px;
}

.app-logs {
  min-height: 200px;
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
