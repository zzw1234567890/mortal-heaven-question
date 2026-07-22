---
name: team-release
description: "编排发布团队：协调 release-manager（发布经理）、qa-lead（QA 主管）、devops-engineer（DevOps 工程师）和 producer（制作人），执行从候选版本到部署的发布流程。"
argument-hint: "[version number or 'next'] [--review full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash, Task, AskUserQuestion, TodoWrite

---


**参数检查：** 如果未提供版本号：
1. 读取 `production/session-state/active.md` 和 `production/milestones/` 中最近的文件（如果存在）以推断目标版本。
2. 如果找到版本：报告"未提供版本参数 — 从里程碑数据推断为 [版本]。继续。"然后使用 `AskUserQuestion` 确认："即将发布 [版本]。是否正确？"
3. 如果无法发现版本：使用 `AskUserQuestion` 询问"应发布什么版本号？（例如 v1.0.0）"并在继续前等待用户输入。不要默认使用硬编码版本字符串。

当本 skill 被调用时，通过结构化管线编排发布团队。

**决策节点：** 在每个阶段过渡时，使用 `AskUserQuestion` 向用户展示子代理的提案作为可选选项。在对话中完整记录代理的分析，然后以简洁的标签记录决策。用户必须批准后才能进入下一阶段。

## 阶段 0：解析审查模式

1. 如果 `--review [mode]` 作为参数传入，使用该模式。
2. 否则读取 `production/review-mode.txt` — 使用其中写入的内容。
3. 否则默认为 `lean`。

模式：
- `full` — 按描述生成所有总监和主管关卡
- `lean` — 跳过总监关卡，除非是阶段关卡类型（CD-PHASE-GATE、TD-PHASE-GATE、PR-PHASE-GATE、AD-PHASE-GATE）
- `solo` — 完全跳过所有总监关卡生成；在没有任何代理关卡的情况下运行 skill

将解析后的模式存储起来，用于所有后续阶段。

## 团队组成
- **release-manager（发布经理）** — 发布分支、版本管理、更新日志、部署
- **qa-lead（QA 主管）** — 测试签收、回归套件、发布质量关卡
- **devops-engineer（DevOps 工程师）** — 构建管线、制品、部署自动化
- **security-engineer（安全工程师）** — 发布前安全审计（如果游戏具有在线/多人功能或玩家数据则调用）
- **analytics-engineer（分析工程师）** — 验证遥测事件正确触发且仪表板在线
- **community-manager（社区经理）** — 补丁说明、发布公告、面向玩家的消息
- **producer（制作人）** — 继续/停止决策、干系人沟通、排期

## 如何委派

使用 Task 工具将每个团队成员生成为子代理：
- `subagent_type: release-manager` — 发布分支、版本管理、更新日志、部署
- `subagent_type: qa-lead` — 测试签收、回归套件、发布质量关卡
- `subagent_type: devops-engineer` — 构建管线、制品、部署自动化
- `subagent_type: security-engineer` — 在线/多人/数据功能的安全审计
- `subagent_type: analytics-engineer` — 遥测事件验证和仪表板就绪性
- `subagent_type: community-manager` — 补丁说明和发布沟通
- `subagent_type: producer` — 继续/停止决策、干系人沟通
- `subagent_type: network-programmer` — 网络代码稳定性签收（如果游戏有多人功能则调用）

始终为每个代理提供完整的上下文（版本号、里程碑状态、已知问题）。在管线允许的情况下并行启动独立代理（例如阶段 3 的代理可以同时运行）。

## 管线

### 阶段 1：发布规划
委派给 **producer**：
- 确认所有里程碑验收标准已满足
- 识别从本次发布中推迟的任何范围项
- 设定目标发布日期并通知团队
- 输出：包含范围确认的发布授权

### 阶段 2：发布候选版本
委派给 **release-manager**：
- 从约定的提交切出发布分支
- 在所有相关文件中更新版本号
- 使用 `/release-checklist` 生成发布检查清单
- 冻结分支——不允许功能更改，仅允许缺陷修复
- 输出：发布分支名称和检查清单

### 阶段 3：质量关卡（并行）
并行委派：
- **qa-lead**：执行完整回归测试套件。测试所有关键路径。验证没有 S1/S2 缺陷。签收质量。
- **devops-engineer**：为所有目标平台构建发布制品。验证构建干净且可重现。在 CI 中运行自动化测试。
- **security-engineer** *（如果游戏具有在线功能、多人游戏或玩家数据）*：进行发布前安全审计。审查认证、反作弊、数据隐私合规性。签收安全态势。
- **network-programmer** *（如果游戏有多人功能）*：签收网络代码稳定性。验证延迟补偿、重连处理和负载下的带宽使用情况。

### 阶段 4：本地化、性能和分析
委派（如果资源允许，可与阶段 3 并行运行）：
- 验证所有字符串已翻译（如果可用，委派给 **localization-lead**）
- 对照目标运行性能基准测试（如果可用，委派给 **performance-analyst**）
- **analytics-engineer**：验证所有遥测事件在发布构建中正确触发。确认仪表板正在接收数据。检查关键漏斗（新手引导、进度推进、变现如适用）已实现检测。
- 输出：本地化、性能和分析签收

### 阶段 5：继续/停止
委派给 **producer**：
- 收集来自以下各方的签收：qa-lead、release-manager、devops-engineer、security-engineer（如在阶段 3 中生成）、network-programmer（如在阶段 3 中生成）和 technical-director
- 评估任何未解决的问题——它们是阻塞性的还是可以随版本发布？
- 做出继续/停止决策
- 输出：包含理由的发布决策

**如果 producer 宣布 NO-GO：**
- 立即上报决策："PRODUCER：NO-GO — [理由，例如阶段 3 中发现 S1 缺陷]。"
- 使用 `AskUserQuestion` 提供选项：
  - 修复阻塞因素并重新运行受影响的阶段
  - 将发布推迟到以后日期
  - 使用文档记录的理由覆盖 NO-GO（用户必须提供书面理由）
- **完全跳过阶段 6** — 不打标签、不部署到预发布环境、不部署到生产环境、也不生成 community-manager。
- 生成部分报告，总结阶段 1-5 以及跳过的内容（阶段 6）及其原因。
- 裁决：**BLOCKED** — 发布未部署。

在用户选择"使用文档记录的理由覆盖 NO-GO"之后：
- 询问（纯文本，非小部件）："请描述覆盖 NO-GO 裁决的理由。这将嵌入到发布记录中。"
- 等待用户的书面理由。
- 在阶段 6 之前将理由文本嵌入到部分批准记录中：追加一个"⚠️ 覆盖理由：[用户文本]"字段。
- 然后才进入阶段 6。

### 阶段 6：部署（如果 GO）
委派给 **release-manager** + **devops-engineer**：
- 在版本控制中标记发布
- 使用 `/changelog` 生成更新日志
- 部署到预发布环境进行最终冒烟测试
- 部署到生产环境
- 人工团队行动：在发布后 48 小时内监控仪表板和错误率。在 48 小时节点使用 `/retrospective` 安排后续回顾会议。

委派给 **community-manager**（与部署并行）：
- 使用 `/patch-notes [version]` 最终确定补丁说明
- 准备发布公告（商店页面更新、社交媒体、社区帖子）
- 如果发布了任何 S3+ 问题，草拟已知问题帖子
- 输出：所有面向玩家的发布沟通材料，准备在部署确认后发布

### 阶段 7：发布后
- **release-manager**：生成发布报告（发布内容、推迟内容、指标）
- **producer**：更新里程碑跟踪，与干系人沟通
- **qa-lead**：监控传入的缺陷报告以发现回归问题
- **community-manager**：发布所有面向玩家的沟通材料，监控社区情绪
- **analytics-engineer**：确认在线仪表板健康；如果缺少任何关键事件则发出警报
- 如果出现问题，安排发布后回顾会议

## 错误恢复协议

如果任何生成的代理（通过 Task）返回 BLOCKED、出错或无法完成：

1. **立即上报**：在继续依赖阶段之前向用户报告"[代理名称]：BLOCKED — [原因]"
2. **评估依赖关系**：检查被阻塞代理的输出是否为后续阶段所需。如果是，在没有用户输入的情况下不要越过该依赖点继续。
3. **通过 AskUserQuestion 提供选项**，包含以下选择：
   - 跳过此代理并在最终报告中记录缺口
   - 以更窄的范围重试
   - 在此停止，先解决阻塞因素
4. **始终生成部分报告** — 输出已完成的内容。绝不要因为一个代理阻塞而丢弃已完成的工作。

常见阻塞因素：
- 输入文件缺失（story 未找到，GDD 不存在）→ 重定向到创建该文件的 skill
- ADR 状态为 Proposed → 不实施；先运行 `/architecture-decision`
- 范围过大 → 通过 `/create-stories` 拆分为两个 story
- ADR 与 story 之间的指令冲突 → 上报冲突，不要猜测

## 文件写入协议

所有文件写入（发布检查清单、更新日志、补丁说明、部署脚本）都委派给子代理和子 skill。每个子代理执行"May I write to [path]?"协议。此编排器不直接写入文件。

## 输出

一份总结报告，涵盖：发布版本、范围、质量关卡结果、继续/停止决策、部署状态和监控计划。

裁决：**COMPLETE** — 发布已执行并部署。
裁决：**BLOCKED** — 发布已停止；继续/停止为 NO 或存在未解决的硬阻塞因素。

## 后续步骤

- 在发布后监控仪表板 48 小时。
- 如果在发布期间出现重大问题，运行 `/retrospective`。
- 在成功部署后，将 `production/stage.txt` 更新为 `Live`。
