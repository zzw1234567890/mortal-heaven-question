---
name: create-stories
description: "将单个 epic 分解为可实现的 story 文件。读取 epic、其 GDD、管辖 ADR 和控制清单。每个 story 嵌入其 GDD 需求 TR-ID、ADR 指导、验收标准、story 类型和测试证据路径。在 /create-epics 为每个 epic 运行后执行。"
argument-hint: "[epic-slug | epic-path] [--review full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Task, AskUserQuestion

agent: lead-programmer
---


# 创建 Story（Create Stories）

一个 story 是一个单一的可实现行为——小到可以在一个专注的会话中完成、自包含、且完全可追溯到 GDD 需求和 ADR 决策。Story 是开发人员接手的工作单元。Epic 是架构师定义的工作单元。

**按 epic 运行此 skill**，而不是按层。先为 Foundation epic 运行，然后是 Core，依此类推——遵循依赖顺序。

**输出：** `production/epics/[epic-slug]/story-NNN-[slug].md` 文件

**上一步：** `/create-epics [system]`
**有 story 后的下一步：** `/story-readiness [story-path]` 然后 `/dev-story [story-path]`

---

## 1. 解析参数

如果存在 `--review [full|lean|solo]`，提取并存储作为本次运行的 review 模式覆盖值。如果未提供，读取 `production/review-mode.txt`（如果缺失则默认 `lean`）。此解析后的模式适用于本 skill 中的所有 gate spawn——在每次 gate 调用前应用 `.claude/docs/director-gates.md` 中的检查模式。

- `/create-stories [epic-slug]` — 例如 `/create-stories combat`
- `/create-stories production/epics/combat/EPIC.md` — 完整路径也可接受
- 无参数 — 询问："Which epic would you like to break into stories?"
  Glob `production/epics/*/EPIC.md` 并列出可用的 epic 及其状态。

---

## 2. 加载此 Epic 的所有内容

完整读取：

- `production/epics/[epic-slug]/EPIC.md` — epic 概述、管辖 ADR、GDD 需求表
- 该 epic 的 GDD（`design/gdd/[filename].md`）— 读取所有 8 个章节，特别是验收标准（Acceptance Criteria）、公式（Formulas）和边缘情况（Edge Cases）
- epic 列出的所有管辖 ADR — 读取决策（Decision）、实施指南（Implementation Guidelines）、引擎兼容性（Engine Compatibility）和引擎说明（Engine Notes）部分
- `docs/architecture/control-manifest.md` — 提取此 epic 层的规则；注意头部的 Manifest Version 日期
- `docs/architecture/tr-registry.yaml` — 加载此系统的所有 TR-ID

**ADR 存在性验证**：在读取 epic 中的管辖 ADR 列表后，确认每个 ADR 文件在磁盘上存在。如果找不到任何 ADR 文件，**在分解任何 story 之前立即停止**：

> "Epic references [ADR-NNNN: title] but `docs/architecture/[adr-file].md` was not found.
> Check the filename in the epic's Governing ADRs list, or run `/architecture-decision`
> to create it. Cannot create stories until all referenced ADR files are present."

在所有引用的 ADR 文件确认存在之前，不要继续到第 3 步。

报告："Loaded epic [name], GDD [filename], [N] governing ADRs (all confirmed present), control manifest v[date]."

---

## 3. 按类型对 Story 进行分类

**Story 类型分类** — 根据其验收标准为每个 story 分配类型：

| Story 类型 | 当标准涉及...时分配 |
|---|---|
| **逻辑型（Logic）** | 公式、数值阈值、状态转换、AI 决策、计算 |
| **集成型（Integration）** | 两个或多个系统交互、跨边界信号、存档/读档往返 |
| **视觉感受型（Visual/Feel）** | 动画行为、VFX、"感觉响应迅速"、时机、屏幕震动、音频同步 |
| **UI 型** | 菜单、HUD 元素、按钮、屏幕、对话框、工具提示 |
| **配置/数据型（Config/Data）** | 平衡调优数值、仅数据文件变更——无新代码逻辑 |

混合型 story：分配实现风险最高的类型。该类型决定 `/story-done` 关闭 story 前需要哪种测试证据。

---

## 4. 将 GDD 分解为 Story

对于每个 GDD 验收标准：

1. 将需要相同核心实现的相关标准分组
2. 每个分组 = 一个 story
3. Story 排序：基础行为优先，边缘情况最后，UI 最后

**Story 规模规则：** 一个 story = 一个专注的会话（约 2-4 小时）。如果一组标准需要更长时间，拆分为两个 story。

对于每个 story，确定：
- **GDD 需求**：这满足了哪些验收标准？
- **TR-ID**：在 `tr-registry.yaml` 中查找。使用稳定的 ID。如果没有匹配项，使用 `TR-[system]-???` 并发出警告。
- **管辖 ADR**：哪个 ADR 管辖如何实现此内容？
  - `Status: Accepted` → 正常嵌入
  - `Status: Proposed` → 设置 story `Status: Blocked` 并附注："BLOCKED: ADR-NNNN is Proposed — run `/architecture-decision` to advance it"
  - **多个 ADR 适用**：在 story 的 `Governing ADRs:` 字段中列出所有管辖 ADR。将最直接控制实现模式的那个指定为主要（列表中的第一个）。其他列为次要参考。
  - **没有任何 ADR 适用**：在 story 的 ADR 字段中写 `ADR: N/A — [brief reason, e.g. "pure data configuration, no architectural pattern required"]`。**不要**将该字段留空——空的 ADR 字段意味着"未检查"，而不是"不适用"。
- **Story 类型**：来自第 3 步的分类
- **引擎风险**：来自 ADR 的知识风险（Knowledge Risk）字段

---

## 4b. QA 主导的 Story 就绪性 Gate

**Review 模式检查** — 在生成 QL-STORY-READY 之前应用：
- `solo` → 跳过。备注："QL-STORY-READY skipped — Solo mode." 继续至步骤 5（展示 story 供审查）。
- `lean` → 跳过（非阶段门禁）。备注："QL-STORY-READY skipped — Lean mode." 继续至步骤 5（展示 story 供审查）。
- `full` → 正常生成。

在分解完所有 story（第 4 步完成）后但在展示它们以供写入批准之前，通过 Task 使用门禁 **QL-STORY-READY**（`.claude/docs/director-gates.md`）生成 `qa-lead`。

传递：完整的 story 列表（含验收标准、story 类型和 TR-ID）；该 epic 的 GDD 验收标准以供参考。

展示 QA 主导的评估。对于每个被标记为 GAPS 或 INADEQUATE 的 story，在继续之前修订验收标准——具有不可测试标准的 story 无法正确实现。一旦所有 story 达到 ADEQUATE，继续。

**在生成测试规格之前**：Glob `production/qa/qa-plan-*.md` 查找最近修改的文件。如果找到，读取它并检查它是否包含此 epic 中 story 的测试用例规格（在计划的 Automated Tests Required 部分中查找 story 标题或 slug）。如果存在匹配的规格：
- 使用 `AskUserQuestion`：
  - 提示："A QA plan exists at [path] with test specs for some of these stories. How do you want to proceed?"
  - 选项：
    - `Use existing specs from the QA plan — embed them into the story files (Recommended)`
    - `Ask qa-lead to generate fresh specs — override the QA plan`
    - `Skip test spec generation — I'll fill in ## QA Test Cases manually`
- 如果选择"Use existing specs"：从 QA 计划中提取每个匹配 story 的测试用例规格，并直接嵌入到 `## QA Test Cases` 部分。这些 story 不需要 qa-lead 生成。仅对 QA 计划中未覆盖的 story 生成 qa-lead。
- 如果选择"Generate fresh"：继续正常进行下面的 qa-lead 生成。
- 如果选择"Skip"：将 `## QA Test Cases` 保留为占位符：`*Test cases not yet defined — run /qa-plan to generate them.*`

**在达到 ADEQUATE 后**（或导入 QA 计划后）：对于每个逻辑型和集成型 story，要求 qa-lead 生成具体的测试用例规格——每个验收标准一个——格式如下：

```
Test: [criterion text]
  Given: [precondition]
  When: [action]
  Then: [expected result / assertion]
  Edge cases: [boundary values or failure states to test]
```

对于视觉感受型和 UI 型 story，改为生成手动验证步骤：
```
Manual check: [criterion text]
  Setup: [how to reach the state]
  Verify: [what to look for]
  Pass condition: [unambiguous pass description]
```

这些测试用例规格直接嵌入到每个 story 的 `## QA Test Cases` 部分。开发者针对这些用例进行实现。程序员不必从头编写测试——QA 已经定义了"完成"的标准。

---

## 5. 展示 Story 供审查

在写入任何文件之前，展示完整的 story 列表：

```
## Stories for Epic: [name]

Story 001: [title] — Logic — ADR-NNNN
  Covers: TR-[system]-001 ([1-line summary of requirement])
  Test required: tests/unit/[system]/[slug]_test.[ext]

Story 002: [title] — Integration — ADR-MMMM
  Covers: TR-[system]-002, TR-[system]-003
  Test required: tests/integration/[system]/[slug]_test.[ext]

Story 003: [title] — Visual/Feel — ADR-NNNN
  Covers: TR-[system]-004
  Evidence required: production/qa/evidence/[slug]-evidence.md

[N stories total: N Logic, N Integration, N Visual/Feel, N UI, N Config/Data]
```

使用 `AskUserQuestion`：
- 提示："May I write these [N] stories to `production/epics/[epic-slug]/`?"
- 选项：`[A] Yes — write all [N] stories` / `[B] Not yet — I want to review or adjust first`

---

## 6. 写入 Story 文件

为每个 story 写入 `production/epics/[epic-slug]/story-[NNN]-[slug].md`：

```markdown
# Story [NNN]: [title]

> **Epic**: [epic name]
> **Status**: Ready
> **Layer**: [Foundation / Core / Feature / Presentation]
> **Type**: [Logic | Integration | Visual/Feel | UI | Config/Data]
> **Estimate**: [hours or t-shirt size — fill before sprint planning]
> **Manifest Version**: [date from control-manifest.md header]
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/[filename].md`
**Requirement**: `TR-[system]-NNN`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: [ADR-NNNN: title]
**ADR Decision Summary**: [1-2 sentence summary of what the ADR decided]

**Engine**: [name + version] | **Risk**: [LOW / MEDIUM / HIGH]
**Engine Notes**: [from ADR Engine Compatibility section — post-cutoff APIs, verification required]

**Control Manifest Rules (this layer)**:
- Required: [relevant required pattern]
- Forbidden: [relevant forbidden pattern]
- Guardrail: [relevant performance guardrail]

---

## Acceptance Criteria

*From GDD `design/gdd/[filename].md`, scoped to this story:*

- [ ] [criterion 1 — directly from GDD]
- [ ] [criterion 2]
- [ ] [performance criterion if applicable]

---

## Implementation Notes

*Derived from ADR-NNNN Implementation Guidelines:*

[Specific, actionable guidance from the ADR. Do not paraphrase in ways that
change meaning. This is what the programmer reads instead of the ADR.]

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story NNN+1]: [what it handles]

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[For Logic / Integration stories — automated test specs]:**

- **AC-1**: [criterion text]
  - Given: [precondition]
  - When: [action]
  - Then: [assertion]
  - Edge cases: [boundary values / failure states]

**[For Visual/Feel / UI stories — manual verification steps]:**

- **AC-1**: [criterion text]
  - Setup: [how to reach the state]
  - Verify: [what to look for]
  - Pass condition: [unambiguous pass description]

---

## Test Evidence

**Story Type**: [type]
**Required evidence**:
- Logic: `tests/unit/[system]/[story-slug]_test.[ext]` — must exist and pass
- Integration: `tests/integration/[system]/[story-slug]_test.[ext]` OR playtest doc
- Visual/Feel: `production/qa/evidence/[story-slug]-evidence.md` + sign-off
- UI: `production/qa/evidence/[story-slug]-evidence.md` or interaction test
- Config/Data: smoke check pass (`production/qa/smoke-*.md`)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: [Story NNN-1 must be DONE, or "None"]
- Unlocks: [Story NNN+1, or "None"]
```

### 同时更新 `production/epics/[epic-slug]/EPIC.md`

将"Stories: Not yet created"行替换为包含数据的表：

```markdown
## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [title] | Logic | Ready | ADR-NNNN |
| 002 | [title] | Integration | Ready | ADR-MMMM |
```

### 同时更新 `production/epics/index.md`

在索引表中找到与此 epic 匹配的行（按 epic 名称或 slug）。将其 `Stories` 列从 `Not yet created` 更新为 `[N] stories`（N 是刚写入的 story 数量）。如果索引文件不存在，静默跳过。

---

## 7. 写入后

使用 `AskUserQuestion` 关闭，并提供上下文感知的后续步骤：

检查：
- `production/epics/` 中是否还有其他尚无 story 的 epic？列出它们。
- 这是最后一个 epic 吗？如果是，将 `/sprint-plan` 作为选项包含。

小部件：
- 提示："[N] stories written to `production/epics/[epic-slug]/`. What next?"
- 选项（包括所有适用的）：
  - `[A] Start implementing — run /story-readiness [first-story-path]` (Recommended)
  - `[B] Create stories for [next-epic-slug] — run /create-stories [slug]` (only if other epics have no stories yet)
  - `[C] Plan the sprint — run /sprint-plan new` (only if all epics have stories)
  - `[D] Stop here for this session`

在输出中注明："Work through stories in order — each story's `Depends on:` field tells you what must be DONE before you can start it."

---

## 协作协议

1. **先读取再展示** — 在显示 story 列表之前静默加载所有输入
2. **一次性询问** — 在一个摘要中展示该 epic 的所有 story，而不是逐个展示
3. **在阻塞 story 上发出警告** — 在写入前标记任何具有 Proposed ADR 的 story
4. **写入前询问** — 在写入文件之前获得整个 story 集的批准
5. **不得虚构** — 验收标准来自 GDD，实现说明来自 ADR，规则来自清单
6. **绝不开始实现** — 本 skill 止步于 story 文件层面

写入后（或拒绝后）：

- **结论：COMPLETE** — [N] 个 story 已写入 `production/epics/[epic-slug]/`。运行 `/story-readiness` → `/dev-story` 开始实现。
- **结论：BLOCKED** — 用户拒绝。未写入任何 story 文件。
