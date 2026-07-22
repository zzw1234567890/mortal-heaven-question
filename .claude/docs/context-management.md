# 上下文管理 (Context Management)


上下文是 Claude Code 会话中最关键的资源。请主动管理它。

## 文件备份状态 (File-Backed State) —— 主要策略

**文件即记忆，而非对话本身。** 对话是短暂的，可能被压缩或丢失。而磁盘上的文件能够在压缩和会话崩溃后持续存在。

### 会话状态文件 (Session State File)

维护 `production/session-state/active.md` 作为一个实时检查点。在每个重要里程碑完成后更新它：

- 设计部分获得批准并写入文件
- 架构决策已做出
- 实现里程碑已达成
- 测试结果已获取

状态文件应包含：当前任务、进度检查清单、已做出的关键决策、正在处理的文件以及待解决的问题。

### 状态栏区块 (Status Line Block) —— 仅 Production+ 阶段

当项目处于 Production（生产）、Polish（打磨）或 Release（发布）阶段时，在 `active.md` 中包含一个可被状态栏脚本解析的结构化状态区块：

```markdown
<!-- STATUS -->
Epic: Combat System
Feature: Melee Combat
Task: Implement hitbox detection
<!-- /STATUS -->
```

- 所有三个字段（Epic、Feature、Task）均为可选 —— 仅包含适用的内容
- 切换关注领域时更新此区块
- 状态栏将其显示为面包屑导航：`Combat System > Melee Combat > Hitboxes`
- 当没有活跃的工作重点时，移除或清空此区块

在任何中断（压缩、崩溃、`/clear`）之后，首先读取状态文件。

### 增量文件写入 (Incremental File Writing)

当创建多章节文档（设计文档、架构文档、世界观条目）时：

1. 立即使用骨架创建文件（所有章节标题、空内容体）
2. 在对话中逐一讨论和起草每个章节
3. 每个章节获得批准后立即写入文件
4. 在每个章节之后更新会话状态文件
5. 写入一个章节后，之前关于该章节的讨论可以安全压缩 —— 决策已保存在文件中

这使上下文窗口仅包含*当前*章节的讨论（约 3-5k tokens），而不是整个文档的对话历史（约 30-50k tokens）。

## 主动压缩 (Proactive Compaction)

- **在上下文使用率达到约 60-70% 时主动压缩**，而非被动等到极限
- **在不相关任务之间使用 `/clear`**，或在 2 次以上失败的修正尝试后使用
- **自然的压缩时机：** 将章节写入文件后、提交后、完成任务后、开始新主题之前
- **聚焦压缩：** `/compact Focus on [current task] — sections 1-3 are written to file, working on section 4`

## 按任务类型的上下文预算 (Context Budgets by Task Type)

- 轻量（阅读/审查）：约 3k tokens 启动
- 中等（实现功能）：约 8k tokens
- 重量级（多系统重构）：约 15k tokens

## 子代理委派 (Subagent Delegation)

使用子代理进行研究和探索，以保持主会话的整洁。子代理在自己的上下文窗口中运行，并仅返回摘要：

- **使用子代理** 当需要跨多个文件进行调查、探索不熟悉的代码，或进行研究工作预计会消耗超过 5k tokens 的文件读取时
- **使用直接读取** 当确切知道需要检查哪 1-2 个文件时
- 子代理不会继承对话历史 —— 在提示中提供完整的上下文

## 压缩指令 (Compaction Instructions)

当上下文被压缩时，在摘要中保留以下内容：

- 引用 `production/session-state/active.md`（读取它以恢复状态）
- 本次会话中修改的文件列表及其用途
- 任何已做出的架构决策及其理由
- 活跃的冲刺（sprint）任务及其当前状态
- 代理调用及其结果（成功/失败/阻塞）
- 测试结果（通过/失败计数，具体失败项）
- 未解决的阻塞项或等待用户输入的问题
- 当前任务及我们处于哪一步
- 当前文档的哪些章节已写入文件，哪些仍在进行中

**压缩后：** 读取 `production/session-state/active.md` 以及任何正在积极处理的文件以恢复完整上下文。文件包含决策；对话历史是次要的。

## 会话崩溃后恢复 (Recovery After Session Crash)

如果会话终止（"提示过长"）或您启动新会话以继续工作：

1. `session-start.sh` 钩子会自动检测并预览 `active.md`
2. 读取完整的状态文件以获取上下文
3. 读取状态中列出的部分完成的文件
4. 从下一个未完成的章节或任务继续
