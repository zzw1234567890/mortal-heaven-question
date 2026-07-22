---
name: create-architecture
description: "引导式、逐章节撰写游戏主架构文档。读取所有 GDD、系统索引、现有 ADR 和引擎参考库，在编写任何代码之前生成完整的架构蓝图。引擎版本感知：标记知识缺口，并根据固定的引擎版本验证决策。"
argument-hint: "[focus-area: full | layers | data-flow | api-boundaries | adr-audit] [--review full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Bash, AskUserQuestion, Task

agent: technical-director
---


# 创建架构（Create Architecture）

此技能生成 `docs/architecture/architecture.md` — 将所有已批准的 GDD 转化为具体技术蓝图的主架构文档。它位于设计与实现之间，且必须在冲刺规划开始之前存在。

**与 `/architecture-decision` 不同**：ADR 记录单个点决策。本技能创建的是赋予 ADR 上下文含义的全局系统蓝图。

解析 review 模式（解析一次，供本次运行中所有 gate spawn 使用）：
1. 如果传入了 `--review [full|lean|solo]` → 使用该值
2. 否则读取 `production/review-mode.txt` → 使用该值
3. 否则 → 默认使用 `lean`

完整检查模式见 `.claude/docs/director-gates.md`。

**参数模式：**
- **无参数 / `full`**：完整的引导式走查——所有章节，从头到尾
- **`layers`**：仅关注系统层图
- **`data-flow`**：仅关注模块间的数据流
- **`api-boundaries`**：仅关注 API 边界定义
- **`adr-audit`**：仅审计现有 ADR 的引擎兼容性缺口

---

## 第零阶段：加载所有上下文

在执行任何其他操作之前，按此顺序加载完整的项目上下文：

### 0a：引擎上下文（关键）

完整读取引擎参考库：

1. `docs/engine-reference/[engine]/VERSION.md`
   → 提取：引擎名称、版本、LLM 知识截止点、截止后风险等级
2. `docs/engine-reference/[engine]/breaking-changes.md`
   → 提取：所有高（HIGH）和中（MEDIUM）风险的变更
3. `docs/engine-reference/[engine]/deprecated-apis.md`
   → 提取：应避免的 API
4. `docs/engine-reference/[engine]/current-best-practices.md`
   → 提取：与训练数据不同的截止后最佳实践
5. `docs/engine-reference/[engine]/modules/` 中的所有文件
   → 提取：每个领域的当前 API 模式

如果未配置引擎，停止并提示：
> "No engine is configured. Run `/setup-engine` first. Architecture cannot be written without knowing which engine and version you are targeting."

### 0b：设计上下文 + 技术需求提取

读取所有已批准的设计文档，并从每个文档中提取技术需求：

1. `design/gdd/game-concept.md` — 游戏支柱、类型、核心循环
2. `design/gdd/systems-index.md` — 所有系统、依赖关系、优先级层级
3. `.claude/docs/technical-preferences.md` — 命名规范、性能预算、允许的库、禁止的模式
4. **`design/gdd/` 中的每份 GDD** — 为每个提取技术需求：
   - 游戏规则所隐含的数据结构
   - 明确或隐含的性能约束
   - 系统所需的引擎能力
   - 跨系统通信模式（什么与什么通信、如何通信）
   - 必须持久化的状态（存档/读档的含义）
   - 线程或计时需求

构建**技术需求基线（Technical Requirements Baseline）**——一个平坦列表，包含来自所有 GDD 的所有已提取需求，编号为 `TR-[gdd-slug]-[NNN]`。这是架构必须覆盖的完整需求集合。展示为：

```
## Technical Requirements Baseline
Extracted from [N] GDDs | [X] total requirements

| Req ID | GDD | System | Requirement | Domain |
|--------|-----|--------|-------------|--------|
| TR-combat-001 | combat.md | Combat | Hitbox detection per-frame | Physics |
| TR-combat-002 | combat.md | Combat | Combo state machine | Core |
| TR-inventory-001 | inventory.md | Inventory | Item persistence | Save/Load |
```

此基线为后续每个阶段提供输入。到本次会话结束时，每个 GDD 需求都应有相应的架构决策支持。

### 0c：现有架构决策

读取 `docs/architecture/` 中的所有文件，了解已经做出的决策。列出找到的所有 ADR 及其所属领域。

### 0d：生成知识缺口清单

在继续之前，显示结构化摘要：

```
## Engine Knowledge Gap Inventory
Engine: [name + version]
LLM Training Covers: up to approximately [version]
Post-Cutoff Versions: [list]

### HIGH RISK Domains (must verify against engine reference before deciding)
- [Domain]: [Key changes]

### MEDIUM RISK Domains (verify key APIs)
- [Domain]: [Key changes]

### LOW RISK Domains (in training data, likely reliable)
- [Domain]: [no significant post-cutoff changes]

### Systems from GDD that touch HIGH/MEDIUM risk domains:
- [GDD system name] → [domain] → [risk level]
```

使用 `AskUserQuestion`：
- 提示："One or more engine domains are HIGH RISK — the LLM's knowledge may be unreliable for these areas. Architectural recommendations in these domains should be cross-referenced with the engine docs before being acted on. How would you like to proceed?"
- 选项：
  - `[A] Proceed — flag HIGH RISK domains throughout the output`
  - `[B] Let me check the engine reference first — pause here`
  - `[C] Show me which domains are HIGH RISK and why`

---

## 第一阶段：系统层映射

将 `systems-index.md` 中的每个系统映射到一个架构层。标准的游戏架构层为：

```
┌─────────────────────────────────────────────┐
│  PRESENTATION LAYER                         │  ← UI, HUD, 菜单, VFX, 音频
├─────────────────────────────────────────────┤
│  FEATURE LAYER                              │  ← 游戏系统, AI, 任务
├─────────────────────────────────────────────┤
│  CORE LAYER                                 │  ← 物理, 输入, 战斗, 移动
├─────────────────────────────────────────────┤
│  FOUNDATION LAYER                           │  ← 引擎集成, 存档/读档,
│                                             │    场景管理, 事件总线
├─────────────────────────────────────────────┤
│  PLATFORM LAYER                             │  ← 操作系统, 硬件, 引擎 API 表面
└─────────────────────────────────────────────┘
```

对于每个 GDD 系统，询问：
- 它属于哪一层？
- 它的模块边界是什么？
- 它独占拥有什么？（数据、状态、行为）

展示提议的层分配并在进入下一章节前请求批准。立即将批准的层映射写入骨架文件。

**引擎意识检查**：对于分配给 Core 和 Foundation 层的每个系统，标记它是否触及高或中风险的引擎领域。内联展示相关的引擎参考摘录。

---

## 第二阶段：模块归属映射

对于第一阶段定义的每个模块，定义归属：

- **拥有（Owns）**：此模块全权负责的数据和状态
- **暴露（Exposes）**：其他模块可以读取或调用的内容
- **消费（Consumes）**：它从其他模块读取的内容
- **使用的引擎 API（Engine APIs used）**：此模块直接调用的特定引擎类/节点/信号（注明版本和风险等级）

格式化为每层的表格，然后以 ASCII 依赖关系图呈现。

**引擎意识检查**：对于列出的每个引擎 API，对照相关模块参考文档进行验证。如果某个 API 在知识截止日期之后，标记它：

```
⚠️  [ClassName.method()] — Godot 4.6 (post-cutoff, HIGH risk)
    Verified against: docs/engine-reference/godot/modules/[domain].md
    Behaviour confirmed: [yes / NEEDS VERIFICATION]
```

在写入前获取用户对归属映射的批准。

---

## 第三阶段：数据流

定义关键游戏场景中模块之间的数据移动方式。至少覆盖：

1. **帧更新路径**：输入 → Core 系统 → 状态 → 渲染
2. **事件/信号路径**：系统如何在没有紧耦合的情况下通信
3. **存档/读档路径**：哪些状态被序列化，哪个模块拥有序列化权限
4. **初始化顺序**：哪些模块必须先于其他模块启动

在有用的情况下使用 ASCII 时序图。对于每个数据流：
- 命名正在传输的数据
- 标识生产者和消费者
- 说明这是同步调用、信号/事件，还是共享状态
- 标记任何跨越线程边界的数据流

在写入前获取用户对每个场景的批准。

---

## 第四阶段：API 边界

定义模块之间的公共契约。对于每个边界：

- 模块向系统其余部分暴露的接口是什么？
- 入口点是什么（函数/信号/属性）？
- 调用者必须遵守哪些不变量？
- 模块必须向调用者保证什么？

使用伪代码或项目的实际语言（来自 technical preferences）编写。这些成为程序员实现的契约。

**引擎意识检查**：如果任何接口使用了引擎特定类型（例如 Godot 中的 `Node`、`Resource`、`Signal`），标记版本并验证该类型在目标引擎版本中存在且签名未更改。

---

## 第五阶段：ADR 审计 + 可追溯性检查

对照第一阶段至第四阶段构建的架构以及第零阶段的技术需求基线，审查第零阶段的所有现有 ADR。

### ADR 质检

对于每个 ADR：
- [ ] 它是否包含引擎兼容性（Engine Compatibility）部分？
- [ ] 是否记录了引擎版本？
- [ ] 是否标记了截止后 API？
- [ ] 是否包含"GDD 需求覆盖（GDD Requirements Addressed）"部分？
- [ ] 是否与本次会话中做出的层/归属决策相冲突？
- [ ] 对于固定的引擎版本是否仍然有效？

| ADR | 引擎兼容性 | 版本 | GDD 关联 | 冲突 | 有效 |
|-----|--------------|---------|-------------|-----------|-------|
| ADR-0001: [标题] | ✅/❌ | ✅/❌ | ✅/❌ | 无/[冲突] | ✅/⚠️ |

### 可追溯性覆盖检查

将技术需求基线中的每个需求映射到现有 ADR。对于每个需求，检查是否有任何 ADR 的"GDD 需求覆盖"部分或决策文本覆盖了它：

| 需求 ID | 需求 | ADR 覆盖 | 状态 |
|--------|-------------|--------------|--------|
| TR-combat-001 | 逐帧命中框检测 | ADR-0003 | ✅ |
| TR-combat-002 | 连击状态机 | — | ❌ 缺口 |

计数：X 覆盖，Y 缺口。每个缺口成为一个**必需的新 ADR**。

### 必需的新 ADR

列出本次架构会话期间（第一阶段至第四阶段）做出的所有尚未有对应 ADR 的决策，加上所有未覆盖的技术需求。按层分组——Foundation 优先：

**Foundation 层（编码前必须创建）：**
- `/architecture-decision [title]` → 覆盖：TR-[id]，TR-[id]

**Core 层：**
- `/architecture-decision [title]` → 覆盖：TR-[id]

---

## 第六阶段：缺失 ADR 列表

基于完整架构，生成应该存在但尚未存在的 ADR 的完整列表。按优先级分组：

**编码开始前必须拥有（Foundation 和 Core 决策）：**
- [例如"场景管理和场景加载策略"]
- [例如"事件总线与直接信号架构"]

**在相关系统构建前应拥有：**
- [例如"背包序列化格式"]

**可推迟到实现阶段：**
- [例如"水的具体着色器技术"]

---

## 第七阶段：写入主架构文档

当所有章节获得批准后，将完整文档写入 `docs/architecture/architecture.md`。

展示文档将包含内容的一段摘要（层、模块、数据流、ADR 缺口）。然后使用 `AskUserQuestion`：
- "All sections approved. May I write the master architecture document?"
  - [A] Yes — write to `docs/architecture/architecture.md` now
  - [B] Show me the full draft inline first, then ask again
  - [C] Not yet — I have more changes to discuss

文档结构：

```markdown
# [Game Name] — Master Architecture

## Document Status
- Version: [N]
- Last Updated: [date]
- Engine: [name + version]
- GDDs Covered: [list]
- ADRs Referenced: [list]

## Engine Knowledge Gap Summary
[Condensed from Phase 0d inventory — HIGH/MEDIUM risk domains and their implications]

## System Layer Map
[From Phase 1]

## Module Ownership
[From Phase 2]

## Data Flow
[From Phase 3]

## API Boundaries
[From Phase 4]

## ADR Audit
[From Phase 5]

## Required ADRs
[From Phase 6]

## Architecture Principles
[3-5 key principles that govern all technical decisions for this project,
derived from the game concept, GDDs, and technical preferences]

## Open Questions
[Decisions deferred — must be resolved before the relevant layer is built]
```

---

## 第七阶段 b：技术总监签署 + 主程序员可行性审查

在写入主架构文档后，在交接前执行明确的签署流程。

**步骤 1 — 技术总监自审**（本技能作为 technical-director 运行）：

应用门禁 **TD-ARCHITECTURE**（`.claude/docs/director-gates.md`）作为自审。对照该门禁定义中的所有四个标准检查已完成的文档。

**Review 模式检查** — 在生成 LP-FEASIBILITY 之前应用：
- `solo` → 跳过。备注："LP-FEASIBILITY skipped — Solo mode." 继续至第八阶段交接。
- `lean` → 跳过（非阶段门禁）。备注："LP-FEASIBILITY skipped — Lean mode." 继续至第八阶段交接。
- `full` → 正常生成。

**步骤 2 — 通过 Task 使用门禁 LP-FEASIBILITY（`.claude/docs/director-gates.md`）生成 `lead-programmer`：**

传递：架构文档路径、技术需求基线摘要、ADR 列表。

**步骤 3 — 向用户并列展示两个评估结果：**

并排展示技术总监评估和主程序员结论。

使用 `AskUserQuestion` — "Technical Director and Lead Programmer have reviewed the architecture. How would you like to proceed?"
选项：`Accept — proceed to handoff` / `Revise flagged items first` / `Discuss specific concerns`

**步骤 4 — 在架构文档中记录签署结果：**

更新文档状态部分：
```
- Technical Director Sign-Off: [date] — APPROVED / APPROVED WITH CONDITIONS
- Lead Programmer Feasibility: FEASIBLE / CONCERNS ACCEPTED / REVISED
```

内联展示提议的文档状态块，然后使用 `AskUserQuestion`：
- "May I update the Document Status section with the sign-off results?"
  - [A] Yes — apply to `docs/architecture/architecture.md`
  - [B] Not yet — I want to revisit the concerns first

---

## 第八阶段：交接

**步骤 1 — 更新会话状态**：将摘要写入 `production/session-state/active.md`，包含：写入的制品、TD/LP 签署结论、任何阻塞项、剩余的必需 ADR，以及下一步。

**步骤 2 — 使用此确切模板输出交接**（无自由格式散文，不重新措辞章节标题）：

---

## Architecture Complete

`docs/architecture/architecture.md` v1.0 — [TD verdict: APPROVED / APPROVED WITH CONCERNS / CONCERNS]. [One sentence on what the architecture covers.]

---

## Run These ADRs Next

**1. `/architecture-decision "[Title]"` → ADR-[XXXX]**
[One sentence: what it defines and what it unblocks.]

**2. `/architecture-decision "[Title]"` → ADR-[XXXX]**
[One sentence.]

**3. `/architecture-decision "[Title]"` → ADR-[XXXX]**
[One sentence.]

List top 3 from Phase 6 in priority order. If fewer than 3 remain, list only what's outstanding.

---

## Gate-Check Readiness

> **Required before `/gate-check [stage]`:**
> - [ ] Accept ADRs: [list Proposed ADR IDs that must be Accepted]
> - [ ] Write ADRs: [list ADR IDs that must still be written]
> - [ ] Run `/test-setup` — scaffolds `tests/unit/`, `tests/integration/`, CI workflow, and an example test file
> - [ ] Run `/ux-design` — creates `design/ux/interaction-patterns.md` and `design/accessibility-requirements.md`
>
> Run `/gate-check [stage]` when all boxes are checked.

If nothing is blocking, write instead:
> No blockers — run `/gate-check [stage]` now.

---

## Open Questions to Watch

| ID | Summary | Priority | Resolution Path |
|----|---------|----------|-----------------|
| QQ-XX | [short description] | High / Medium / Low | [ADR or system that resolves it] |

Omit this section entirely if there are no open QQs.

---

(End of handoff. Do not add trailing commentary after the closing rule.)

---

## 协作协议

本技能在每个阶段遵循协作设计原则：

1. **静默加载上下文** — 不要叙述文件读取过程
2. **展示发现** — 显示知识缺口清单和层提案
3. **决策前征询** — 为每个架构选择提供选项
4. **审批前草稿** — 在请求写入之前内联展示内容。
   切勿对用户尚未看到的章节请求批准。
5. **使用 `AskUserQuestion` 获取写入批准** — 纯文本的"可以吗？"是不够的。使用带标签选项 [A]/[B]/[C]（立即写入/先显示完整草稿/稍后）的结构化工具。对于多文件变更集，列出每个文件及其变更，然后一次性询问——而不是每个文件分别用纯文本询问。
6. **增量写入** — 每个章节批准后立即写入；不要累积所有内容到最后才写入。这样能在会话崩溃时存活。

未经用户输入，绝不做出具有约束力的架构决策。如果用户不确定，在要求他们决定之前提供 2-4 个选项并附上利弊。

---

## 推荐后续步骤

- 为第六阶段列出的每个必需 ADR 运行 `/architecture-decision [title]` — Foundation 层 ADR 优先
- 运行 `/architecture-review` — 从刚写入的 ADR 引导生成需求可追溯性矩阵和 TR 注册表。在 Pre-Production 门禁之前必需。
- 运行 `/test-setup` 搭建 `tests/unit/`、`tests/integration/`、CI 工作流和测试示例（门禁检查必需）
- 运行 `/ux-design` 初始化 `design/ux/interaction-patterns.md` 和 `design/accessibility-requirements.md`（门禁检查必需）
- 一旦必需的 ADR 写入完成，运行 `/create-control-manifest` 生成层规则清单
- 当所有必需 ADR、`/test-setup` 和 `/ux-design` 完成时，运行 `/gate-check pre-production`
