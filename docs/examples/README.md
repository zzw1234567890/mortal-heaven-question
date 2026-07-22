
# 协作会话示例

本目录包含真实、端到端的会话记录，展示游戏工作室代理架构 (Game Studio Agent Architecture) 在实践中的运作方式。每个示例都展示了**协作工作流**：代理提问、呈现选项并等待用户批准，而不是自动生成内容。

---

## 视觉参考

**刚接触本系统？从这里开始：**
[技能流程图 (Skill Flow Diagrams)](skill-flow-diagrams.md) — 全部 7 个阶段以及技能如何串联的可视化地图。

---

## 📚 **可用示例**

### 核心工作流

### [技能流程图](skill-flow-diagrams.md)
**类型：** 视觉参考
**复杂度：** 所有级别

完整流水线概览（从零到发布），以及以下内容的详细链路图：
design-system、story 生命周期、UX 流水线，以及 brownfield 项目接入。

**如果你想理解各部分如何组合在一起，从这里开始。**

---

### [会话：使用 /design-system 编写 GDD](session-design-system-skill.md)
**类型：** 设计（技能驱动）
**技能：** `/design-system`
**时长：** 约 60 分钟（14 轮）
**复杂度：** 中

**场景：**
开发者在 `/map-systems` 生成系统索引后运行 `/design-system movement`。该技能从游戏概念和依赖 GDD 加载上下文，运行技术可行性预检查，然后逐节引导完成全部 8 个 GDD 章节——每一节都经过起草、批准并写入磁盘，再进入下一节。

**关键时刻：**
- 技术可行性预检查标记了 Jolt 物理默认变更（Godot 4.6）
- 增量写入：每节批准后立即写入磁盘
- 第 5 节期间会话崩溃 → 代理从第一个空章节恢复
- 依赖信号（stamina、inventory）在 Dependencies 章节中被浮现
- 以明确交接收尾："在下一个系统之前运行 `/design-review`"

**学习要点：**
- `/design-system` 与让代理"写一个 GDD"有何不同
- 逐节循环如何防止 30k token 的上下文膨胀
- 增量文件写入如何扛过会话崩溃
- 该技能如何浮现下游依赖契约

---

### [会话：完整 Story 生命周期](session-story-lifecycle.md)
**类型：** 完整工作流
**技能：** `/story-readiness` → 实现 → `/story-done`
**时长：** 约 50 分钟（13 轮）
**复杂度：** 中

**场景：**
开发者从冲刺 (Sprint) 待办中取走一个 story。`/story-readiness` 在写任何代码之前就捕捉到一个滚动方向的歧义。实现完成后，`/story-done` 验证 9 条验收标准，识别出 2 条延后标准（inventory 尚未集成），并附注关闭该 story。

**关键时刻：**
- `/story-readiness` 在第 2 轮捕捉到规格歧义——在实现开始前解决
- ADR 状态检查：若 ADR 仍为 Proposed，story 会被 BLOCKED
- 清单版本检查：确认 story 的指引未偏离当前架构
- 当集成尚不可行时，延后的标准被跟踪（而非丢失）
- story 关闭时更新 `sprint-status.yaml`，并自动浮现下一个就绪的 story

**学习要点：**
- 为什么 `/story-readiness` 能防止实现晚期的歧义
- 延后标准如何运作（COMPLETE WITH NOTES vs. BLOCKED）
- TR-ID 引用如何防止误报偏离标志
- 从待办 → 已实现 → 已关闭的完整循环

---

### [会话：Gate Check 与阶段过渡](session-gate-check-phase-transition.md)
**类型：** 阶段闸门
**技能：** `/gate-check`
**时长：** 约 20 分钟（7 轮）
**复杂度：** 低

**场景：**
开发者完成系统设计阶段并运行 `/gate-check` 以推进。闸门发现全部 6 个 MVP GDD 完整，交叉评审通过并仅有一条低严重性关注点。闸门通过，`stage.txt` 更新，代理为技术设置阶段提供了具体的有序清单。

**关键时刻：**
- 闸门验证工件存在性以及内部完整性（每个 GDD 8 个章节）
- CONCERNS ≠ FAIL：低严重性交叉评审备注可通过闸门
- stage.txt 更新改变了后续 `/help`、`/sprint-status` 以及所有技能所见的内容
- 代理将交叉评审关注点转化为一条具体的"接下来要写的 ADR"
- 下一阶段清单是具体且有序的，而非泛泛而谈

**学习要点：**
- 闸门检查实际验证了什么（不只是"文件存在吗？"）
- PASS/CONCERNS/FAIL 判定如何运作
- 为什么 stage.txt 是阶段追踪的权威
- 阶段过渡之后会发生什么变化

---

### [会话：UX 流水线 — /ux-design → /ux-review → /team-ui](session-ux-pipeline.md)
**类型：** UX 设计流水线
**技能：** `/ux-design`, `/ux-review`, `/team-ui`
**时长：** 约 90 分钟（16 轮）
**复杂度：** 中高

**场景：**
开发者设计 HUD 和 inventory 界面。`/ux-design` 读取玩家旅程和 GDD，将决策建立在玩家情绪状态之上。`/ux-review` 捕捉到一个阻塞性的可访问性缺口（拖拽没有键盘替代方案）和一个建议性的色盲问题。修复后，`/team-ui` 接受交接。

**关键时刻：**
- HUD 哲学选择（diegetic vs. persistent vs. tactical）建立在生存游戏类型惯例之上
- `/ux-review` 区分 BLOCKING（阻止交接）与 ADVISORY（可在视觉阶段修复）
- 可访问性问题在实现前、而非 QA 期间被捕捉
- 键盘替代方案在一轮内添加；复审重跑并通过
- `/team-ui` 在开始视觉设计前检查是否有通过的 `/ux-review`

**学习要点：**
- `/ux-design` 如何用玩家旅程上下文来支撑 UI 决策
- `/ux-review` 实际检查了什么（不只是"规格存在吗？"）
- HUD 文档 (`design/ux/hud.md`) 与逐屏规格的区别
- 可访问性问题在设计阶段 vs. 实现阶段如何处理

---

### [会话：使用 /adopt 接入 Brownfield 项目](session-adopt-brownfield.md)
**类型：** Brownfield 接入
**技能：** `/adopt`
**时长：** 约 30 分钟（8 轮）
**复杂度：** 中低

**场景：**
开发者有 3 个月的现有代码和粗略设计笔记，但没有任何内容符合正确格式。`/adopt` 审计格式合规性（不只是文件存在性），按严重性分类 4 个缺口，构建有序的 7 步迁移计划，并通过从代码库推断立即修复 BLOCKING 缺口（缺失的系统索引）。

**关键时刻：**
- FORMAT 审计区分"文件存在"与"文件具有所需内部结构"
- 识别出 BLOCKING 缺口：缺失的系统索引阻止 4+ 个技能运行
- 迁移计划有序：先 blocking 缺口，再 high，再 medium
- 系统索引从代码结构引导生成——brownfield 代码中已包含答案
- Retrofit 模式 vs. 全新编写：`/design-system retrofit` 填补缺口而不覆盖

**学习要点：**
- `/adopt` 与 `/project-stage-detect` 的区别
- 格式合规性如何检查（章节检测，不只是文件存在性）
- Brownfield 项目如何在不丢失现有工作的情况下接入
- 何时使用 retrofit 模式 vs. 完整编写

---

### 基础示例

### [会话：设计制造系统 (Crafting System)](session-design-crafting-system.md)
**类型：** 设计
**代理：** game-designer
**时长：** 约 45 分钟（12 轮）
**复杂度：** 中

**场景：**
独立开发者需要设计一个服务于支柱 2（"通过实验涌现发现"）的制造系统。代理通过问答引导，呈现 3 个带有游戏理论分析的设计选项，纳入用户修改，并迭代起草 GDD，每一步都获得批准。

**关键协作时刻：**
- 代理前置提出 5 个澄清问题
- 呈现 3 个不同选项，附优缺点 + MDA 对齐
- 用户修改推荐选项，代理立即纳入
- 主动标记边界情况（"非配方组合怎么办？"）
- 每个 GDD 章节在进入下一节前都展示给用户批准
- 创建文件前明确询问"May I write to [file]?"

**学习要点：**
- 设计代理如何询问目标、约束、参考
- 如何用游戏设计理论（MDA、SDT、Bartle）呈现选项
- 如何逐节迭代草稿
- 何时委托给专家（systems-designer、economy-designer）

---

### [会话：实现战斗伤害计算](session-implement-combat-damage.md)
**类型：** 实现
**代理：** gameplay-programmer
**时长：** 约 30 分钟（10 轮）
**复杂度：** 中低

**场景：**
用户有完整设计文档，希望实现伤害计算。代理读取规格，识别 7 处歧义/缺口，提出澄清问题，提议架构待批准，带规则强制实现，并主动编写测试。

**关键协作时刻：**
- 代理先读设计文档，识别 7 处规格歧义
- 在实现前用代码样例提议架构
- 用户要求类型安全，代理优化后重新提议
- 规则捕捉问题（硬编码值），代理透明修复
- 按验证驱动开发主动编写测试
- 代理提供后续步骤选项，而非擅自假设

**学习要点：**
- 实现代理如何在编码前澄清规格
- 如何用代码样例提议架构以供批准
- 规则如何自动强制标准
- 如何处理规格缺口（询问，不假设）
- 验证驱动开发（测试证明其有效）

---

### [会话：范围危机 — 战略决策制定](session-scope-crisis-decision.md)
**类型：** 战略决策
**代理：** creative-director
**时长：** 约 25 分钟（8 轮）
**复杂度：** 高

**场景：**
独立开发者面临危机：Alpha 里程碑还有 2 周，制造系统需要 3 周，投资人演示是成败关键。创意总监 (Creative Director) 收集上下文，框定决策，呈现 3 个带诚实权衡分析的战略选项，给出建议但尊重用户决定，随后用 ADR 和演示脚本记录决策。

**关键协作时刻：**
- 代理在提议方案前先读上下文文档
- 提出 5 个问题以理解决策约束
- 正确框定决策（利害所在、评估标准）
- 呈现 3 个带风险分析和历史先例的选项
- 给出强建议但明确表示："这是你的决定"
- 记录决策 + 提供演示脚本支持用户

**学习要点：**
- 领导层代理如何框定战略决策
- 如何用权衡分析呈现选项
- 如何在建议中使用游戏开发先例和理论
- 如何记录决策（ADR）
- 如何将决策级联到受影响部门

---

### [逆向文档工作流 (Reverse Documentation Workflow)](reverse-document-workflow-example.md)
**类型：** Brownfield 文档
**代理：** game-designer
**时长：** 约 20 分钟
**复杂度：** 低

**场景：**
开发者构建了一个技能树系统但从未写过设计文档。代理读取代码、推断设计意图、就模糊决策提出澄清问题，并产出一份回溯性 GDD。

---

## 🎯 **这些示例展示的内容**

所有示例都遵循**协作工作流模式：**

```
Question → Options → Decision → Draft → Approval
```

> **注意：** 这些示例以对话文本展示协作模式。
> 在实践中，代理现在会在决策点使用 `AskUserQuestion` 工具
> 呈现结构化选项选择器（带标签、描述和多选）。
> 模式是**Explain → Capture**：代理先在对话中解释其分析，
> 然后呈现结构化 UI 选择器供用户决策。

### ✅ **展示的协作行为：**

1. **代理先问再假设**
   - 设计代理询问目标、约束、参考
   - 实现代理澄清规格歧义
   - 领导层代理在建议前收集完整上下文

2. **代理呈现选项，而非命令**
   - 2-4 个带优缺点的选项
   - 推理基于理论、先例、项目支柱
   - 给出建议，但由用户决定

3. **代理在定稿前展示工作**
   - 设计草稿逐节展示
   - 架构提案在实现前展示
   - 战略分析在决策前呈现

4. **代理在写文件前获得批准**
   - 使用 Write/Edit 工具前明确询问"May I write to [file]?"
   - 多文件变更先列出所有受影响文件
   - 用户说"Yes"后才创建任何文件

5. **代理基于反馈迭代**
   - 用户修改立即纳入
   - 用户更改建议时不抱防御态度
   - 当用户改进了代理的建议时予以庆祝

---

## 📖 **如何使用这些示例**

### 面向新用户：
在首次会话之前阅读这些示例。它们展示了代理如何工作的现实预期：
- 代理是顾问，不是自主执行者
- 你做所有创意/战略决策
- 代理提供专家指引和选项

### 面向理解特定工作流：
- **刚接触本系统？** → 先读 skill-flow-diagrams.md
- **第一次运行 /design-system？** → 读 session-design-system-skill.md
- **准备取走一个 story？** → 读 session-story-lifecycle.md
- **正在收尾一个阶段？** → 读 session-gate-check-phase-transition.md
- **开始 UI 工作？** → 读 session-ux-pipeline.md
- **已有现有项目？** → 读 session-adopt-brownfield.md
- **设计一个系统（代理驱动）？** → 读 session-design-crafting-system.md
- **实现代码？** → 读 session-implement-combat-damage.md
- **做战略决策？** → 读 session-scope-crisis-decision.md

### 面向培训：
如果你在教别人使用本系统，逐轮走一个示例来展示：
- 好的问题长什么样
- 如何评估呈现的选项
- 何时批准 vs. 请求修改
- 如何在利用 AI 专长的同时保持创意掌控

---

## 🔍 **所有示例中的共同模式**

### 第 1-2 轮：**先理解再行动**
- 代理读取上下文（设计文档、规格、约束）
- 代理提出澄清问题
- 没有假设或猜测

### 第 3-5 轮：**带推理呈现选项**
- 2-4 种不同方法
- 每种的优缺点
- 支撑分析的理论/先例
- 给出建议，决策交由用户

### 第 6-8 轮：**迭代草稿**
- 增量展示工作
- 立即纳入反馈
- 主动标记边界情况或歧义

### 第 9-10 轮：**批准与完成**
- "May I write to [file]?"
- 用户："Yes"
- 代理写文件
- 代理提供后续步骤（测试、评审、集成）

---

## 🚀 **自己试试**

阅读这些示例后，尝试以下练习：

1. 选你游戏中的一个系统（战斗、inventory、进度等）
2. 让相关代理设计或实现它
3. 注意代理是否：
   - ✅ 前置提出澄清问题
   - ✅ 呈现带推理的选项
   - ✅ 定稿前展示草稿
   - ✅ 写文件前请求批准

如果代理跳过其中任何一项，提醒它：
> "Please follow the collaborative protocol from docs/COLLABORATIVE-DESIGN-PRINCIPLE.md"

---

## 📝 **其他资源**

- **完整原则文档：** [docs/COLLABORATIVE-DESIGN-PRINCIPLE.md](../COLLABORATIVE-DESIGN-PRINCIPLE.md)
- **工作流指南：** [docs/WORKFLOW-GUIDE.md](../WORKFLOW-GUIDE.md)
- **代理名册：** [.claude/docs/agent-roster.md](../../.claude/docs/agent-roster.md)
- **CLAUDE.md（协作协议）：** [CLAUDE.md](../../CLAUDE.md#collaboration-protocol)
