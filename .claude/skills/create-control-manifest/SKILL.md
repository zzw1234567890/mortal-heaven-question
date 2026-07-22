---
name: create-control-manifest
description: "架构完成后，为程序员生成一个扁平、可执行的规则表——每个系统和每层中必须做什么、绝不能做什么。从所有已接受的 ADR、技术偏好和引擎参考文档中提取。比 ADR（解释原因）更直接可用。"
argument-hint: "[update — regenerate from current ADRs]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Task

agent: technical-director
---


# 创建控制清单（Create Control Manifest）

控制清单（Control Manifest）是一个扁平、可执行的程序员规则表。它回答"我该做什么？"和"我绝不能做什么？"——按架构层组织，从所有已接受的 ADR、技术偏好和引擎参考文档中提取。ADR 解释*为什么*，清单告诉您*是什么*。

**输出：** `docs/architecture/control-manifest.md`

**运行时机：** 在 `/architecture-review` 通过且 ADR 处于已接受（Accepted）状态后运行。每当有新 ADR 被接受或现有 ADR 被修订时重新运行。

---

## 1. 加载所有输入

### ADR
- Glob `docs/architecture/adr-*.md` 并读取每个文件
- 仅过滤出已接受（Accepted）的 ADR（状态：Accepted）——跳过 Proposed、Deprecated、Superseded
- 记录每条规则的来源 ADR 编号和标题

### 技术偏好
- 读取 `.claude/docs/technical-preferences.md`
- 提取：命名规范、性能预算、已批准的库/插件、禁止的模式

### 引擎参考
- 读取 `docs/engine-reference/[engine]/VERSION.md` 获取引擎名称和版本
- 读取 `docs/engine-reference/[engine]/deprecated-apis.md`——这些成为禁止 API 条目
- 读取 `docs/engine-reference/[engine]/current-best-practices.md`（如果存在）

报告："Loaded [N] Accepted ADRs, engine: [name + version]."

---

## 2. 从每个 ADR 提取规则

对于每个已接受的 ADR，提取：

### 必需模式（来自"Implementation Guidelines"部分）
- 每个"must"、"should"、"required to"、"always"语句
- 每个被强制要求的特定模式或方法

### 禁止方法（来自"Alternatives Considered"部分）
- 每个被明确拒绝的备选方案——*为什么*它被拒绝即成为规则（"绝不使用 X，因为 Y"）
- 任何被明确指出的反模式

### 性能护栏（来自"Performance Implications"部分）
- 预算约束："此系统每帧最多 N 毫秒"
- 内存限制："此系统不得超过 N MB"

### 引擎 API 约束（来自"Engine Compatibility"部分）
- 需要验证的知识截止后 API
- 经过验证的、与默认 LLM 假设不同的行为
- 在固定引擎版本中行为不同的 API 字段或方法

### 层分类
按其所管辖系统的架构层对每条规则进行分类：
- **Foundation**：场景管理、事件架构、存档/读档、引擎初始化
- **Core**：核心游戏循环、主要玩家系统、物理/碰撞
- **Feature**：次级系统、次级机制、AI
- **Presentation**：渲染、音频、UI、VFX、着色器

如果某个 ADR 跨越多个层，将规则复制到每个相关层中。

---

## 3. 添加全局规则

合并适用于所有层的规则：

### 来自 technical-preferences.md：
- 命名规范（类、变量、信号/事件、文件、常量）
- 性能预算（目标帧率、帧预算、绘制调用限制、内存上限）

### 来自 deprecated-apis.md：
- 所有已弃用的 API → 禁止 API 条目

### 来自 current-best-practices.md（如果可用）：
- 引擎推荐的模式 → 必需条目

### 来自 technical-preferences.md 的禁止模式：
- 直接复制任何"禁止模式（Forbidden Patterns）"条目

---

## 4. 在写入前展示规则摘要

在写入清单之前，向用户展示摘要：

```
## Control Manifest Preview
Engine: [name + version]
ADRs covered: [list ADR numbers]
Total rules extracted:
  - Foundation layer: [N] required, [M] forbidden, [P] guardrails
  - Core layer: [N] required, [M] forbidden, [P] guardrails
  - Feature layer: ...
  - Presentation layer: ...
  - Global: [N] naming conventions, [M] forbidden APIs, [P] approved libraries
```

使用 `AskUserQuestion`：
- 提示："Does this rule summary look complete?"
- 选项：
  - `[A] Yes — looks good, run the director review and write the manifest`
  - `[B] Add rules — I have additional rules to include before writing`
  - `[C] Remove rules — some extracted rules should be dropped`
  - `[D] Stop here — I need to review the ADRs first`

---

## 4b. 主管门禁 — 技术审查

**Review 模式检查** — 在生成 TD-MANIFEST 之前应用：
- `solo` → 跳过。备注："TD-MANIFEST skipped — Solo mode." 继续至第五阶段。
- `lean` → 跳过。备注："TD-MANIFEST skipped — Lean mode." 继续至第五阶段。
- `full` → 正常生成。

通过 Task 使用门禁 **TD-MANIFEST**（`.claude/docs/director-gates.md`）生成 `technical-director`。

传递：第四阶段的控制清单预览（每层规则计数、完整提取的规则列表）、已覆盖的 ADR 列表、引擎版本，以及任何源自 technical-preferences.md 或引擎参考文档的规则。

技术总监审查以下内容：
- 所有强制性的 ADR 模式是否被捕获并准确陈述
- 禁止的方法是否完整且正确归因
- 没有添加缺乏来源 ADR 或偏好文档的规则
- 性能护栏是否与 ADR 约束一致

应用结论：
- **批准（APPROVE）** → 继续至第五阶段
- **顾虑（CONCERNS）** → 通过 `AskUserQuestion` 呈现，选项：`Revise flagged rules` / `Accept and proceed` / `Discuss further`
- **拒绝（REJECT）** → 不写入清单；修复标记的规则并重新展示摘要

---

## 5. 写入控制清单

使用 `AskUserQuestion`：
- 提示："May I write the Control Manifest?"
- 选项：
  - `[A] Yes — write to docs/architecture/control-manifest.md`
  - `[B] Show me the full draft first, then ask again`
  - `[C] Not yet — I want to make more changes`

格式：

```markdown
# Control Manifest

> **Engine**: [name + version]
> **Last Updated**: [date]
> **Manifest Version**: [date]
> **ADRs Covered**: [ADR-NNNN, ADR-MMMM, ...]
> **Status**: [Active — regenerate with `/create-control-manifest update` when ADRs change]

`Manifest Version` is the date this manifest was generated. Story files embed
this date when created. `/story-readiness` compares a story's embedded version
to this field to detect stories written against stale rules. Always matches
`Last Updated` — they are the same date, serving different consumers.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
technical preferences, and engine reference docs. For the reasoning behind each
rule, see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: scene management, event architecture, save/load, engine initialisation*

### Required Patterns
- **[rule]** — source: [ADR-NNNN]
- **[rule]** — source: [ADR-NNNN]

### Forbidden Approaches
- **Never [anti-pattern]** — [brief reason] — source: [ADR-NNNN]

### Performance Guardrails
- **[system]**: max [N]ms/frame — source: [ADR-NNNN]

---

## Core Layer Rules

*Applies to: core gameplay loop, main player systems, physics, collision*

### Required Patterns
...

### Forbidden Approaches
...

### Performance Guardrails
...

---

## Feature Layer Rules

*Applies to: secondary mechanics, AI systems, secondary features*

### Required Patterns
...

### Forbidden Approaches
...

---

## Presentation Layer Rules

*Applies to: rendering, audio, UI, VFX, shaders, animations*

### Required Patterns
...

### Forbidden Approaches
...

---

## Global Rules (All Layers)

### Naming Conventions
| Element | Convention | Example |
|---------|-----------|---------|
| Classes | [from technical-preferences] | [example] |
| Variables | [from technical-preferences] | [example] |
| Signals/Events | [from technical-preferences] | [example] |
| Files | [from technical-preferences] | [example] |
| Constants | [from technical-preferences] | [example] |

### Performance Budgets
| Target | Value |
|--------|-------|
| Framerate | [from technical-preferences] |
| Frame budget | [from technical-preferences] |
| Draw calls | [from technical-preferences] |
| Memory ceiling | [from technical-preferences] |

### Approved Libraries / Addons
- [library] — approved for [purpose]

### Forbidden APIs ([engine version])
These APIs are deprecated or unverified for [engine + version]:
- `[api name]` — deprecated since [version] / unverified post-cutoff
- Source: `docs/engine-reference/[engine]/deprecated-apis.md`

### Cross-Cutting Constraints
- [constraint that applies everywhere, regardless of layer]
```

---

## 6. 建议后续步骤

写入清单后：

- 如果 epic/story 尚不存在："Run `/create-epics layer: foundation` then `/create-stories [epic-slug]` — programmers can now use this manifest when writing story implementation notes."
- 如果这是重新生成（清单已存在）："Updated. Recommend notifying the team of changed rules — especially any new Forbidden entries."

---

## 协作协议

1. **静默加载** — 在展示任何内容之前读取所有输入
2. **先展示摘要** — 让用户在写入前看到范围
3. **写入前征询** — 在创建或覆盖清单之前始终确认。写入时：结论：**COMPLETE** — control manifest written。拒绝时：结论：**BLOCKED** — user declined write。
4. **每条规则标明来源** — 绝不添加无法追溯到 ADR、技术偏好或引擎参考文档的规则
5. **不加解释** — 按 ADR 中陈述的方式提取规则；不以改变含义的方式转述
