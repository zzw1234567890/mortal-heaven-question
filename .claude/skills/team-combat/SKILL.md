---
name: team-combat
description: "编排战斗团队：协调游戏设计师、玩法程序员、AI程序员、技术美术、音效设计师和QA测试员，端到端地设计、实现和验证战斗功能。"
argument-hint: "[combat feature description] [--review full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash, Task, AskUserQuestion, TodoWrite

---


**参数检查：** 如果未提供战斗功能描述，输出：
> "用法：`/team-combat [combat feature description]` — 提供要设计和实现的战斗功能描述（例如 `melee parry system`、`ranged weapon spread`）。"
然后立即停止，不派生任何子 agent，也不读取任何文件。

当此技能以有效参数调用时，通过结构化管线编排战斗团队。

**决策点：** 在每个阶段转换时，使用 `AskUserQuestion` 将子 agent 的
提案作为可选选项呈现给用户。在对话中写出 agent 的完整分析，然后以简洁的
标签捕获决策。用户必须批准后才能进入下一阶段。

## 阶段 0：解析评审模式

1. 如果参数中传入了 `--review [mode]`，使用该模式。
2. 否则读取 `production/review-mode.txt` — 使用其中所写内容。
3. 否则默认为 `lean`。

模式：
- `full` — 按描述派生所有 director 和 lead 关卡
- `lean` — 跳过 director 关卡，除非是 PHASE-GATE 类型（CD-PHASE-GATE、TD-PHASE-GATE、PR-PHASE-GATE、AD-PHASE-GATE）
- `solo` — 完全跳过所有 director 关卡的派生；运行技能时不带任何 agent 关卡

保存解析出的模式，供所有后续阶段使用。

## 团队构成
- **game-designer** — 设计机制，定义公式和边缘情况
- **gameplay-programmer** — 实现核心玩法代码
- **ai-programmer** — 实现该功能的 NPC/敌人 AI 行为
- **technical-artist** — 创建 VFX、着色器特效和视觉反馈
- **sound-designer** — 定义音频事件、打击音效和环境战斗音频
- **engine specialist（primary）** — 验证架构和实现模式是否符合引擎惯用法（从 `.claude/docs/technical-preferences.md` 的 Engine Specialists 部分读取）
- **qa-tester** — 编写测试用例并验证实现

## 如何委派

使用 Task 工具将每位团队成员派生为子 agent：
- `subagent_type: game-designer` — 设计机制，定义公式和边缘情况
- `subagent_type: gameplay-programmer` — 实现核心玩法代码
- `subagent_type: ai-programmer` — 实现 NPC/敌人 AI 行为
- `subagent_type: technical-artist` — 创建 VFX、着色器特效、视觉反馈
- `subagent_type: sound-designer` — 定义音频事件、打击音效、环境音频
- `subagent_type: [primary engine specialist]` — 架构和实现的引擎惯用法验证
- `subagent_type: qa-tester` — 编写测试用例并验证实现

始终在每个 agent 的提示中提供完整上下文（设计文档路径、相关代码文件、约束条件）。在管线允许的情况下并行启动独立 agent（例如阶段 3 的 agent 可以同时运行）。

## 管线

### 阶段 1：设计
委派给 **game-designer**：
- 在 `design/gdd/` 中创建或更新设计文档，涵盖：机制概述、玩家幻想、详细规则、带变量定义的公式、边缘情况、依赖关系、带安全范围的调优旋钮以及验收标准
- 输出：完成的设计文档

### 阶段 2：架构
委派给 **gameplay-programmer**（如果涉及 AI 则同时委派给 **ai-programmer**）：
- 审查设计文档
- 设计代码架构：类结构、接口、数据流
- 识别与现有系统的集成点
- 输出：包含文件列表和接口定义的架构草图

然后派生 **primary engine specialist** 以验证提议的架构：
- 类/节点/组件结构是否符合锁定引擎的惯用法？（例如 Godot 节点层次结构、Unity MonoBehaviour vs DOTS、Unreal Actor/Component 设计）
- 是否有应使用的引擎原生系统替代自定义实现？
- 锁定引擎版本中是否有任何提议的 API 已被弃用或更改？
- 输出：引擎架构说明 — 在阶段 3 开始前合并到架构中

使用 `AskUserQuestion`：
- 提示："架构草图已完成。批准进入并行实现阶段。"
- 选项：
  - `[A] 继续 — 派生实现 agent（gameplay-programmer、ai-programmer、technical-artist、sound-designer）`
  - `[B] 先修改架构 — 我将描述需要更改的内容`
  - `[C] 在此停止 — 我稍后继续`

仅在用户选择 [A] 时派生实现 agent。

### 阶段 3：实现（尽可能并行）
并行委派：
- **gameplay-programmer**：实现核心战斗机制代码
- **ai-programmer**：实现 AI 行为（如果功能涉及 NPC 反应）
- **technical-artist**：创建 VFX 和着色器特效
- **sound-designer**：定义音频事件列表和混音说明

### 阶段 4：集成
- 连接玩法代码、AI、VFX 和音频
- 确保所有调优旋钮已暴露并数据驱动
- 验证功能与现有战斗系统的兼容性

### 阶段 5：验证
委派给 **qa-tester**：
- 根据验收标准编写测试用例
- 测试文档中记录的所有边缘情况
- 验证性能影响在预算范围内
- 为发现的任何问题提交错误报告

### 阶段 6：签收
- 收集所有团队成员的结果
- 报告功能状态：COMPLETE / NEEDS WORK / BLOCKED
- 列出所有未解决的问题及其指定的负责人

## 错误恢复协议

如果任何派生的 agent（通过 Task）返回 BLOCKED、出错或无法完成：

1. **立即暴露**：在继续依赖阶段之前向用户报告 "[AgentName]: BLOCKED — [原因]"
2. **评估依赖**：检查受阻 agent 的输出是否为后续阶段所需。如果是，在没有用户输入的情况下不要越过该依赖点。
3. **通过 AskUserQuestion 提供选项**：
   - 跳过此 agent 并在最终报告中记录缺口
   - 缩小范围后重试
   - 就此停止，先解决阻塞问题
4. **始终产出部分报告** — 输出已完成的内容。永远不要因一个 agent 受阻而丢弃工作成果。

常见阻塞原因：
- 输入文件缺失（story 未找到、GDD 不存在）→ 重定向到创建它的 skill
- ADR 状态为 Proposed → 不要实现；先运行 `/architecture-decision`
- 范围过大 → 通过 `/create-stories` 拆分为两个 story
- ADR 与 story 之间存在指令冲突 → 暴露冲突，不要猜测

## 文件写入协议

所有文件写入（设计文档、实现文件、测试用例）均委派给
通过 Task 派生的子 agent。每个子 agent 执行
"May I write to [path]?" 协议。本编排器不直接写文件。

## 输出

总结报告，包括：设计完成状态、每位团队成员的实现状态、测试结果以及任何未解决的问题。

判定：**COMPLETE** — 战斗功能已设计、实现并验证。
判定：**BLOCKED** — 一个或多个阶段无法完成；已产出部分报告，列出未解决项。

## 后续步骤

- 在关闭 story 之前，在已实现的战斗代码上运行 `/code-review`。
- 运行 `/balance-check` 验证战斗公式和调优值。
- 如果需要 VFX、音频或性能打磨，运行 `/team-polish`。
