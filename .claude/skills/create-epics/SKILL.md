---
name: create-epics
description: "将已批准的 GDD + 架构转化为 epic——每个架构模块对应一个 epic。定义范围、管辖 ADR、引擎风险以及未追踪的需求。本 skill 不负责拆分为 story——每个 epic 创建完成后运行 /create-stories [epic-slug]。"
argument-hint: "[system-name | layer: foundation|core|feature|presentation | all] [--review full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Task, AskUserQuestion

agent: technical-director
---


# 创建 Epic

Epic 是一个命名明确、边界清晰的工作单元，映射到一个架构模块。
它定义了**需要构建什么**以及**谁在架构层面负责**。它
不规定实现步骤——那是 story 的职责。

**在开发接近每一层时，对该层运行一次本 skill**。
在 Core 层接近完成之前，不要创建 Feature 层的 epic——设计
到那时已经发生变化。

**输出：** `production/epics/[epic-slug]/EPIC.md` + `production/epics/index.md`

**每个 epic 之后的下一步：** `/create-stories [epic-slug]`

**运行时机：** 在 `/create-control-manifest` 和 `/architecture-review` 通过之后。

---

## 1. 解析参数

解析 review 模式（解析一次，供本次运行中所有 gate spawn 使用）：
1. 如果传入了 `--review [full|lean|solo]` → 使用该值
2. 否则读取 `production/review-mode.txt` → 使用该值
3. 否则 → 默认使用 `lean`

完整检查模式见 `.claude/docs/director-gates.md`。

**模式：**
- `/create-epics all` — 按层顺序处理所有系统
- `/create-epics layer: foundation` — 仅 Foundation 层
- `/create-epics layer: core` — 仅 Core 层
- `/create-epics layer: feature` — 仅 Feature 层
- `/create-epics layer: presentation` — 仅 Presentation 层
- `/create-epics [system-name]` — 某个特定系统
- 无参数 — 询问："你想为哪一层或哪个系统创建 epic？"

---

## 2. 加载输入

### 步骤 2a — 摘要扫描（快速）

在完整读取任何内容之前，先 grep 所有 GDD 的 `## Summary` 部分：

```
Grep pattern="## Summary" glob="design/gdd/*.md" output_mode="content" -A 5
```

对于 `layer:` 或 `[system-name]` 模式：根据 Summary 快速参考，
只过滤出范围内的 GDD。跳过对范围外内容的完整阅读。

### 步骤 2b — 完整文档加载（仅限范围内系统）

根据步骤 2a 的 grep 结果，确定哪些系统在范围内。**仅对范围内系统**读取完整文档——不要读取范围外系统或层的 GDD 或 ADR。

为范围内系统读取：

- `design/gdd/systems-index.md` — 权威系统清单、分层、优先级
- 仅范围内 GDD（Approved 或 Designed 状态，按步骤 2a 结果过滤）
- `docs/architecture/architecture.md` — 模块归属与 API 边界
- 仅**领域覆盖范围内系统**的 Accepted ADR——阅读 "GDD Requirements Addressed"、"Decision" 和 "Engine Compatibility" 部分；跳过无关领域的 ADR
- `docs/architecture/control-manifest.md` — 从头部读取 manifest 版本日期
- `docs/architecture/tr-registry.yaml` — 用于将需求追踪到 ADR 覆盖情况
- `docs/engine-reference/[engine]/VERSION.md` — 引擎名称、版本、风险等级

报告："已加载 [N] 份 GDD、[M] 份 ADR，引擎：[名称 + 版本]。"

---

## 3. 处理顺序

按依赖安全的层顺序处理：
1. **Foundation**（无依赖）
2. **Core**（依赖 Foundation）
3. **Feature**（依赖 Core）
4. **Presentation**（依赖 Feature + Core）

每层内部，使用 `systems-index.md` 中的顺序。

---

## 4. 定义每个 Epic

对每个系统，将其映射到 `architecture.md` 中的一个架构模块。

对照 TR 注册表检查 ADR 覆盖情况：
- **已追踪需求**：有 Accepted ADR 覆盖的 TR-ID
- **未追踪需求**：没有 ADR 的 TR-ID——继续之前先警告

在写入任何内容之前向用户展示：

```
## Epic: [System Name]

**Layer**: [Foundation / Core / Feature / Presentation]
**GDD**: design/gdd/[filename].md
**Architecture Module**: [module name from architecture.md]
**Governing ADRs**: [ADR-NNNN, ADR-MMMM]
**Engine Risk**: [LOW / MEDIUM / HIGH — highest risk among governing ADRs]
**GDD Requirements Covered by ADRs**: [N / total]
**Untraced Requirements**: [list TR-IDs with no ADR, or "None"]
```

如果存在未追踪需求：
> "⚠️ [系统名] 中有 [N] 个需求没有 ADR。epic 仍可创建，但
> 这些需求对应的 story 将被标记为 Blocked，直到 ADR 存在。
> 请先运行 `/architecture-decision`，或使用占位符继续。"

使用 `AskUserQuestion`：
- 提示："是否创建 Epic: [名称]？"
- 选项：
  - `[A] 是，创建它`
  - `[B] 跳过此 epic`
  - `[C] 暂停——我需要先写 ADR`

---

## 4b. Producer Epic 结构 Gate

**Review 模式检查**——在 spawn PR-EPIC 之前应用：
- `solo` → 跳过。备注："PR-EPIC 已跳过——Solo 模式。" 继续步骤 5（写入 epic 文件）。
- `lean` → 跳过（不是 PHASE-GATE）。备注："PR-EPIC 已跳过——Lean 模式。" 继续步骤 5（写入 epic 文件）。
- `full` → 正常 spawn。

当前层的所有 epic 定义完成后（所有范围内系统的步骤 4 已完成），且在写入任何文件之前，通过 Task 使用 gate **PR-EPIC**（`.claude/docs/director-gates.md`）spawn `producer`。

传入：完整的 epic 结构摘要（所有 epic、其范围摘要、管辖 ADR 数量）、正在处理的层、里程碑时间线和团队产能。

展示 producer 的评估结果。

如果为 UNREALISTIC：提议修改 epic 边界（拆分过大的 epic 或合并过小的 epic）。修改后重新运行 gate，然后再写入。

如果为 CONCERNS，使用 `AskUserQuestion`：
- 提示："Producer 对 epic 结构提出了顾虑。你希望如何进行？"
- 选项：
  - `[A] 按原计划继续——我接受 producer 的顾虑`
  - `[B] 修改 epic 边界——按建议拆分或合并`
  - `[C] 停止——我想重新考虑范围`

如果 [A]：继续步骤 5。
如果 [B]：从步骤 4 修改 epic 定义，并重新运行 producer gate。
如果 [C]：停止。结论：**BLOCKED**——用户想重新考虑 epic 范围。

在 producer gate 得出结果之前，不要写入 epic 文件。

---

## 5. 写入 Epic 文件

批准后询问："我可以将 epic 文件写入 `production/epics/[epic-slug]/EPIC.md` 吗？"

用户确认后，写入：

### `production/epics/[epic-slug]/EPIC.md`

```markdown
# Epic: [System Name]

> **Layer**: [Foundation / Core / Feature / Presentation]
> **GDD**: design/gdd/[filename].md
> **Architecture Module**: [module name]
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories [epic-slug]`

## Overview

[1 paragraph describing what this epic implements, derived from the GDD Overview
and the architecture module's stated responsibilities]

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-NNNN: [title] | [1-line summary] | LOW/MEDIUM/HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-[system]-001 | [requirement text from registry] | ADR-NNNN ✅ |
| TR-[system]-002 | [requirement text] | ❌ No ADR |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/[filename].md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories [epic-slug]` to break this epic into implementable stories.
```

### 更新 `production/epics/index.md`

创建或更新主索引：

```markdown
# Epics Index

Last Updated: [date]
Engine: [name + version]

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| [name] | Foundation | [system] | [file] | Not yet created | Ready |
```

---

## 6. Gate-Check 提醒

写入请求范围内的所有 epic 后：

- **Foundation + Core 完成**：这是 Pre-Production → Production gate 的必要条件。运行 `/gate-check production` 检查就绪情况。
- **提醒**：Epic 定义范围。Story 定义实现步骤。在开发人员可以接手工作之前，对每个 epic 运行 `/create-stories [epic-slug]`。

---

## 协作协议

1. **一次一个 epic**——在请求创建之前先展示每个 epic 定义
2. **对缺口发出警告**——在继续之前标记未追踪的需求
3. **写入前先询问**——写入任何文件前逐个 epic 获得批准
4. **不得虚构**——所有内容来自 GDD、ADR 和架构文档
5. **绝不创建 story**——本 skill 止步于 epic 层级

处理完所有请求的 epic 后：

- **结论：COMPLETE**——已写入 [N] 个 epic。对每个 epic 运行 `/create-stories [epic-slug]`。
- **结论：BLOCKED**——用户拒绝了所有 epic，或未找到符合条件的系统。
