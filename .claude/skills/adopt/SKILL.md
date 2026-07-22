---
name: adopt
description: "棕地项目（Brownfield）接入 —— 审计现有项目工件是否符合模板格式规范（不仅是存在性检查），按影响程度分类差距，并生成编号迁移计划。在加入进行中的项目或从旧模板版本升级时运行。与 /project-stage-detect（检查存在哪些内容）不同——本技能检查现有内容是否能够与模板技能正常工作。"
argument-hint: "[focus: full | gdds | adrs | stories | infra]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, AskUserQuestion

agent: technical-director
---

# Adopt — 棕地项目模板接入


本技能审计现有项目工件是否符合模板技能管线的**格式规范**，然后生成优先级排序的迁移计划。

**这不是 `/project-stage-detect`。**
`/project-stage-detect` 回答：*存在什么？*
`/adopt` 回答：*现有的内容能否与模板技能正常工作？*

一个项目可以拥有 GDD、ADR 和故事——但如果这些工件的内部格式错误，所有对格式敏感的技能仍会静默失败或产生错误结果。

**输出：** `docs/adoption-plan-[date].md` —— 一份持久、可检查的迁移计划。

**参数模式：**

**审计模式：** `$ARGUMENTS[0]`（空白 = `full`）

- **无参数 / `full`**：完整审计——所有工件类型
- **`gdds`**：仅 GDD 格式合规性
- **`adrs`**：仅 ADR 格式合规性
- **`stories`**：仅故事格式合规性
- **`infra`**：仅基础设施工件缺口（注册表、清单、冲刺状态、stage.txt）

---

## 阶段 1：检测项目状态

在读取之前输出一行：`"正在扫描项目工件..."` —— 这确认技能在静默读取阶段正在运行。

然后静默读取，在呈现任何内容之前完成。

### 存在性检查
- `production/stage.txt` —— 如果存在，读取它（权威阶段）
- `design/gdd/game-concept.md` —— 概念是否存在？
- `design/gdd/systems-index.md` —— 系统索引是否存在？
- 统计 GDD 文件数量：`design/gdd/*.md`（排除 game-concept.md 和 systems-index.md）
- 统计 ADR 文件数量：`docs/architecture/adr-*.md`
- 统计故事文件数量：`production/epics/**/*.md`（排除 EPIC.md）
- `.claude/docs/technical-preferences.md` —— 引擎是否已配置？
- `docs/engine-reference/` —— 引擎参考文档是否存在？
- Glob `docs/adoption-plan-*.md` —— 如果存在先前的计划，记录最新文件的名称

### 推断阶段（如果没有 stage.txt）
使用与 `/project-stage-detect` 相同的启发式规则：
- `src/` 中有 10+ 个源文件 → 生产（Production）阶段
- `production/epics/` 中存在故事 → 预生产（Pre-Production）阶段
- ADR 存在 → 技术设置（Technical Setup）阶段
- systems-index.md 存在 → 系统设计（Systems Design）阶段
- game-concept.md 存在 → 概念（Concept）阶段
- 无内容 → 全新项目（不是棕地项目——建议使用 `/start`）

如果项目看起来是全新的（完全没有工件），使用 `AskUserQuestion`：
- "这看起来是一个全新项目——未发现现有工件。`/adopt` 适用于有需要迁移的工作的项目。你想做什么？"
  - "运行 `/start` —— 开始引导式首次入门"
  - "我的工件在非标准位置——帮我找到它们"
  - "取消"

然后停止——无论用户选择哪个选项，都不要继续进行审计（每个选项指向不同的技能或手动调查）。

报告："检测到的阶段：[阶段]。发现：[N] 个 GDD、[M] 个 ADR、[P] 个故事。"

---

## 阶段 2：格式审计

对于范围内的每种工件类型（基于参数模式），不仅检查文件是否存在，还检查是否包含模板所需的内部结构。

### 2a：GDD 格式审计

对于找到的每个 GDD 文件，通过扫描标题检查 8 个必需部分：

| 必需部分 | 要查找的标题模式 |
|---|---|
| 概述（Overview） | `## Overview` |
| 玩家幻想（Player Fantasy） | `## Player Fantasy` |
| 详细规则/设计（Detailed Rules / Design） | `## Detailed` 或 `## Core Rules` 或 `## Detailed Design` |
| 公式（Formulas） | `## Formulas` 或 `## Formula` |
| 边缘情况（Edge Cases） | `## Edge Cases` |
| 依赖关系（Dependencies） | `## Dependencies` 或 `## Depends` |
| 调优旋钮（Tuning Knobs） | `## Tuning` |
| 验收标准（Acceptance Criteria） | `## Acceptance` |

对于每个 GDD，记录：
- 哪些部分存在
- 哪些部分缺失
- 现有部分中是否有实际内容，还是仅为占位文本（`[To be designed]` 或类似内容）

同时检查：每个 GDD 的标题块中是否有 `**Status**:` 字段？
有效值：`In Design`、`Designed`、`In Review`、`Approved`、`Needs Revision`。

### 2b：ADR 格式审计

对于找到的每个 ADR 文件，检查这些关键部分：

| 部分 | 缺失的影响 |
|---|---|
| `## Status` | **阻塞（BLOCKING）** —— `/story-readiness` 的 ADR 状态检查会静默通过所有内容 |
| `## ADR Dependencies` | 高（HIGH）—— `/architecture-review` 中的依赖排序会中断 |
| `## Engine Compatibility` | 高（HIGH）—— 训练数据截止后的 API 风险未知 |
| `## GDD Requirements Addressed` | 中（MEDIUM）—— 可追溯性矩阵失去覆盖 |
| `## Performance Implications` | 低（LOW）—— 非管线关键项 |

对于每个 ADR，记录：哪些部分存在，哪些部分缺失，如果存在 Status 部分，记录当前 Status 值。

### 2c：systems-index.md 格式审计

如果 `design/gdd/systems-index.md` 存在：

1. **括号中的状态值** —— 搜索任何包含括号的 Status 单元格：`"Needs Revision ("`、`"In Progress ("` 等。
   这些会破坏 `/gate-check`、`/create-stories` 和 `/architecture-review` 中的精确字符串匹配。**阻塞（BLOCKING）。**

2. **有效状态值** —— 检查 Status 列的值是否仅限于：
   `Not Started`、`In Progress`、`In Review`、`Designed`、`Approved`、`Needs Revision`
   标记任何无法识别的值。

3. **列结构** —— 检查表格至少包含：系统名称、层级、优先级、状态列。缺失列会降低技能功能。

### 2d：故事格式审计

对于找到的每个故事文件：

- **`Manifest Version:` 字段** —— 故事标题中是否存在？（低（LOW）—— 如果缺失则自动通过）
- **TR-ID 引用** —— 故事是否包含 `TR-[a-z]+-[0-9]+` 模式？（中（MEDIUM）—— 无法跟踪过时）
- **ADR 引用** —— 故事是否引用了至少一个 ADR？（检查 `ADR-` 模式）
- **状态字段** —— 存在且可读？
- **验收标准** —— 故事是否有复选框列表（`- [ ]`）？

### 2e：基础设施审计

| 工件 | 路径 | 缺失的影响 |
|---|---|---|
| TR 注册表 | `docs/architecture/tr-registry.yaml` | 高（HIGH）—— 无稳定需求 ID |
| 控制清单 | `docs/architecture/control-manifest.md` | 高（HIGH）—— 故事无层级规则 |
| 清单版本戳 | 在清单标题中：`Manifest Version:` | 中（MEDIUM）—— 过时检查盲目 |
| 冲刺状态 | `production/sprint-status.yaml` | 中（MEDIUM）—— `/sprint-status` 回退到 markdown |
| 阶段文件 | `production/stage.txt` | 中（MEDIUM）—— 阶段自动检测不可靠 |
| 引擎参考 | `docs/engine-reference/[engine]/VERSION.md` | 高（HIGH）—— ADR 引擎检查盲目 |
| 架构可追溯性 | `docs/architecture/architecture-traceability.md` | 中（MEDIUM）—— 无持久化矩阵 |

### 2f：技术偏好审计

读取 `.claude/docs/technical-preferences.md`。检查每个字段是否为 `[TO BE CONFIGURED]`：
- 引擎、语言、渲染、物理 → 高（HIGH）如果未配置（ADR 技能会失败）
- 命名约定 → 中（MEDIUM）
- 性能预算 → 中（MEDIUM）
- 禁止模式、允许的库 → 低（LOW）（按设计初始为空）

---

## 阶段 3：分类和优先级排序差距

将所有审计中发现的每个差距组织到四个严重级别：

**阻塞（BLOCKING）** —— 会导致模板技能*立即*静默产生错误结果。
示例：ADR 缺少 Status 字段、systems-index 出现括号状态值、引擎未配置但 ADR 已存在。

**高（HIGH）** —— 会导致生成的故事缺少安全检查，或基础设施引导失败。
示例：ADR 缺少 Engine Compatibility、GDD 缺少 Acceptance Criteria（无法从中生成故事）、tr-registry.yaml 缺失。

**中（MEDIUM）** —— 降低质量和管线跟踪，但不会破坏功能。
示例：GDD 缺少 Tuning Knobs 或 Formulas 部分、故事缺少 TR-ID、sprint-status.yaml 缺失。

**低（LOW）** —— 追溯性的改进，有则更好但不紧急。
示例：故事缺少 Manifest Version 戳、GDD 缺少 Open Questions 部分。

按级别统计总数。如果零阻塞和零高级差距：报告项目与模板兼容，仅剩建议性改进。

---

## 阶段 4：构建迁移计划

编写一个编号的、有序的行动计划。排序规则：
1. 阻塞差距优先（必须修复，否则任何管线技能都无法可靠运行）
2. 高级差距其次，基础设施先于 GDD/ADR 内容（引导需要正确的格式）
3. 中级差距排序：GDD 差距先于 ADR 差距先于故事差距（故事依赖 GDD 和 ADR）
4. 低级差距最后

对于每个差距，生成一个计划条目，包含：
- 清晰的问题陈述（一句话，无行话）
- 如果技能有处理方式，给出确切的修复命令
- 如果需要直接编辑，给出手动步骤
- 时间估计（粗略：5 分钟 / 30 分钟 / 1 个 session）
- 一个复选框 `- [ ]` 用于跟踪

**特殊情况——systems-index 括号状态值：**
如果存在，始终是第一个项目。显示需要更改的确切值以及确切的替换文本。在编写计划之前提供立即修复的选项。

**特殊情况——ADR 缺少 Status 字段：**
对于每个受影响的 ADR，修复方法为：
`/architecture-decision retrofit docs/architecture/adr-[NNNN]-[slug].md`
将每个 ADR 列为单独的可勾选项。

**特殊情况——GDD 缺少部分：**
对于每个受影响的 GDD，列出缺失的部分及其修复方法：
`/design-system retrofit design/gdd/[filename].md`

**基础设施引导顺序** —— 始终按照此顺序呈现：
1. 首先修复 ADR 格式（注册表依赖于读取 ADR Status 字段）
2. 运行 `/architecture-review` → 引导生成 `tr-registry.yaml`
3. 运行 `/create-control-manifest` → 创建包含版本戳的清单
4. 运行 `/sprint-plan update` → 创建 `sprint-status.yaml`
5. 运行 `/gate-check [current-phase]` → 权威写入 `stage.txt`

**现有故事** —— 明确说明：
> "现有故事继续与所有模板技能一起工作——当字段不存在时，所有新的格式检查会自动通过。在重新生成之前，它们不会受益于 TR-ID 过时跟踪或清单版本检查。这是有意为之：不要重新生成已经在进行中的故事。"

---

## 阶段 5：呈现摘要并询问是否写入

在写入之前呈现一个紧凑的摘要：

```
## 接入审计摘要
检测到的阶段：[阶段]
引擎：[已配置 / 未配置]
审计的 GDD：[N] 个（[X] 完全合规，[Y] 有差距）
审计的 ADR：[N] 个（[X] 完全合规，[Y] 有差距）
审计的故事：[N] 个

差距计数：
  阻塞（BLOCKING）：[N] —— 不修复这些，模板技能将故障
  高（HIGH）：    [N] —— 运行 /create-stories 或 /story-readiness 不安全
  中（MEDIUM）：  [N] —— 质量降低
  低（LOW）：     [N] —— 可选改进

预计修复时间：[X 个阻塞项 × 每个约 Y 分钟 = 大约 Z 小时]
```

在询问是否写入之前，显示一个**差距预览**：
- 将每个阻塞差距列为一个单行项目符号，描述实际问题
  （例如 `systems-index.md：3 行有括号状态值`、`adr-0002.md：缺少 ## Status 部分`）。不要只计数——显示实际项目。
- 显示高/中/低级差距仅作为计数（例如 `高：4、中：2、低：1`）。

这给用户足够的上下文来判断范围，然后才承诺写入文件。

如果在阶段 1 中检测到先前的接入计划，添加一个提示：
> "存在先前的计划 `docs/adoption-plan-[prior-date].md`。新计划将反映当前项目状态——它不会与先前运行进行差异比较。"

使用 `AskUserQuestion`：
- "准备好写入迁移计划了吗？"
  - "是——写入 `docs/adoption-plan-[date].md`"
  - "先显示完整的计划预览（暂不写入）"
  - "取消——我会手动处理迁移"

如果用户选择"显示完整的计划预览"，将完整计划作为围栏 markdown 块输出。然后再次询问相同的三个选项。

---

## 阶段 6：写入接入计划

如果获得批准，写入 `docs/adoption-plan-[date].md`，结构如下：

```markdown
# 接入计划

> **生成日期**：[date]
> **项目阶段**：[phase]
> **引擎**：[name + version，或"未配置"]
> **模板版本**：v1.0+

按顺序完成这些步骤。每完成一项就勾选它。随时重新运行 `/adopt` 检查剩余的差距。

---

## 步骤 1：修复阻塞差距

[每个阻塞差距一个子部分，包含问题、修复命令、时间估计、复选框]

---

## 步骤 2：修复高优先级差距

[每个高级差距一个子部分]

---

## 步骤 3：引导基础设施

### 3a. 注册现有需求（创建 tr-registry.yaml）
运行 `/architecture-review` —— 即使 ADR 已经存在，这次运行也会从现有的 GDD 和 ADR 引导 TR 注册表。
**时间**：1 个 session（大型代码库的审查可能较长）
- [ ] tr-registry.yaml 已创建

### 3b. 创建控制清单
运行 `/create-control-manifest`
**时间**：30 分钟
- [ ] docs/architecture/control-manifest.md 已创建

### 3c. 创建冲刺跟踪文件
运行 `/sprint-plan update`
**时间**：5 分钟（如果冲刺计划已作为 markdown 存在）
- [ ] production/sprint-status.yaml 已创建

### 3d. 设置权威项目阶段
运行 `/gate-check [current-phase]`
**时间**：5 分钟
- [ ] production/stage.txt 已写入

---

## 步骤 4：中级优先差距

[每个中级差距一个子部分]

---

## 步骤 5：可选改进

[每个低级差距一个子部分]

---

## 对现有故事的预期

现有故事继续与所有模板技能一起工作。当字段不存在时，新的格式检查（TR-ID 验证、清单版本过时检查）会自动通过——所以不会破坏任何内容。但在重新生成之前，它们不会受益于过时跟踪。不要重新生成正在进行或已完成的故事。

---

## 重新运行

完成步骤 3 后再次运行 `/adopt`，以验证所有阻塞和高级差距是否已解决。新的运行将反映项目的当前状态。
```

---

## 阶段 6b：设置审查模式

在写入接入计划后（或者如果用户取消了写入），检查 `production/review-mode.txt` 是否存在。

**如果存在**：读取它并记录当前模式——"审查模式已设置为 `[current]`。" —— 跳过提示。

**如果不存在**：使用 `AskUserQuestion`：

- **提示**："还有一个设置步骤：在完成工作流程时，你希望有多详细的设计审查？"
- **选项**：
  - `Full` —— 在每个关键工作流程步骤由主管专家审查。最适合团队、学习工作流程，或当你希望在每个决策上获得透彻反馈时。
  - `Lean（推荐）` —— 仅在阶段门转换（/gate-check）时由主管审查。跳过每个技能的审查。适合独立开发者和小团队。
  - `Solo` —— 完全没有主管审查。最大速度。最适合游戏 jam、原型，或当审查感觉像负担时。

选择后立即将选择写入 `production/review-mode.txt` —— 不需要单独的"我可以写吗？"询问：
- `Full` → 写入 `full`
- `Lean（推荐）` → 写入 `lean`
- `Solo` → 写入 `solo`

如果 `production/` 目录不存在，创建它。

---

## 阶段 7：提供首个行动

在写入计划后，不要就此停止。选择单个最高优先级的差距，并使用 `AskUserQuestion` 立即提供处理。选择第一个适用的分支：

**如果 systems-index.md 中存在括号状态值：**
使用 `AskUserQuestion`：
- "最紧急的修复是 `systems-index.md` —— [N] 行有括号状态值（例如 `Needs Revision (see notes)`），这立即使 /gate-check、/create-stories 和 /architecture-review 中断。我可以在原地修复这些问题。"
  - "立即修复——编辑 systems-index.md"
  - "我会自己修复"
  - "完成——把计划留给我"

**如果 ADR 缺少 `## Status`（且没有括号问题）：**
使用 `AskUserQuestion`：
- "最紧急的修复是为 [N] 个 ADR 添加 `## Status`：[列出文件名]。没有它，/story-readiness 会静默通过所有 ADR 检查。从 [第一个受影响文件名] 开始？"
  - "是——立即改造 [第一个受影响文件名]"
  - "逐个改造所有 [N] 个 ADR"
  - "我会自己处理 ADR"

**如果 GDD 缺少验收标准（且没有上述阻塞问题）：**
使用 `AskUserQuestion`：
- "最紧急的差距是 [N] 个 GDD 缺少验收标准：[列出文件名]。没有它们，/create-stories 无法生成故事。从 [最高优先级 GDD 文件名] 开始？"
  - "是——立即向 [GDD 文件名] 添加验收标准"
  - "逐个处理所有 [N] 个 GDD"
  - "我会自己处理 GDD"

**如果不存在阻塞或高级差距：**
使用 `AskUserQuestion`：
- "没有阻塞差距——该项目与模板兼容。接下来做什么？"
  - "带我浏览中级优先级的改进"
  - "运行 /project-stage-detect 进行更广泛的健康检查"
  - "完成——我会按照自己的节奏处理计划"

> **接入计划已保存到 `docs/adoption-plan-[date].md`。** 随时重新运行 `/adopt` 以重新检查剩余的差距。

---

## 协作协议

1. **静默读取** —— 在呈现任何内容之前完成完整审计
2. **首先显示摘要** —— 让用户在询问写入之前看到范围
3. **先询问再写入** —— 在创建接入计划文件之前始终确认
4. **提供，不要强迫** —— 计划是建议性的；用户决定修复什么以及何时修复
5. **一次一个行动** —— 在交计划后，提供一个具体的下一步，而不是六个同时要做的事情的列表
6. **永远不要重新生成现有工件** —— 只填充现有内容的差距；不要重写已经有内容的 GDD、ADR 或故事
