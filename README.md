# Vibe Coding Skill

用「评分表驱动迭代」方法把项目做到生产级别的 Claude Code 自定义命令。

在任意项目输入 `/vibe`，AI 自动打分、修复、循环直到满足生产就绪阈值。

---

## 评分维度（13个，针对中型项目生产环境优化）

| 优先级 | 维度 | 说明 |
|--------|------|------|
| 1 | 安全性 | OWASP Top 10、secrets 管理、加密（子维度：认证/输入验证/加密/OWASP） |
| 2 | 依赖健康度 | CVE 扫描、License 合规、版本锁定、CI 自动扫描 |
| 3 | 合规性与数据治理 | PII 识别脱敏、数据保留策略、GDPR/CCPA/SOC2 合规项 |
| 4 | 架构成熟度 | 模块解耦、循环依赖检测、接口抽象 |
| 5 | 功能完整性 | 基于功能清单逐条验证，边缘案例覆盖 |
| 6 | 稳定性 | 超时重试、优雅关闭、panic 兜底、错误上下文 |
| 7 | 测试策略 | 单测覆盖率≥80%、集成测试、E2E、CI 自动化 |
| 8 | 代码质量 | 圈复杂度<10、命名规范、无重复逻辑、函数<50行 |
| 9 | 性能 | P99响应<500ms、N+1查询、索引、内存泄漏 |
| 10 | 可观测性 | 结构化日志、metrics、trace_id、告警规则 |
| 11 | 可运维性 | /health+/ready 端点、Runbook、备份恢复、IaC |
| 12 | 文档质量 | API 文档、README、ADR、运维文档 |
| 13 | 开发者/用户体验 | 后端评 DX checklist；前端评 UX |

## 生产就绪阈值（无需所有维度满10分）

- 安全性 = 10 分（硬性要求）
- 稳定性 + 依赖健康度 均 ≥ 8 分
- 合规性与数据治理 ≥ 7 分
- 其余维度均 ≥ 7 分，无任何维度低于 6 分

---

## 安装

### 方式一：一键脚本（推荐）

```bash
git clone https://github.com/zivcheung-bit/vibe-coding.git
cd vibe-coding
bash install.sh
```

### 方式二：curl 单行安装

```bash
mkdir -p ~/.claude/commands && curl -fsSL \
  https://raw.githubusercontent.com/zivcheung-bit/vibe-coding/main/vibe.md \
  -o ~/.claude/commands/vibe.md
```

### 方式三：手动

1. 下载 `vibe.md`
2. 放到 `~/.claude/commands/vibe.md`

---

## 使用

```
# 在任意项目目录，打开 Claude Code，输入：
/vibe
```

**第一次运行**：AI 探索代码 → 判断项目类型 → 填写功能清单 → 创建 `VIBE_SCORECARD.md`（含子维度分数） → 开始修第一个维度

**后续运行**：读取已有评分表 → 接着上次进度继续

**生产就绪**：满足阈值后自动停止，输出生产就绪报告，总结各维度得分和改进内容

---

## 避免频繁确认弹窗

```bash
claude --dangerously-skip-permissions
```

启动 Claude Code 后再输入 `/vibe`，全程无需手动确认。

---

## 文件说明

```
vibe-coding/
├── vibe.md       # Claude Code 自定义命令（安装到 ~/.claude/commands/）
├── install.sh    # 一键安装脚本
└── README.md     # 说明文档
```
