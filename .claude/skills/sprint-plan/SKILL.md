---
name: sprint-plan
description: "根据当前里程碑、已完成工作和可用容量生成新的冲刺计划或更新现有计划。从生产文档和设计积压中提取上下文。"
argument-hint: "[new|update|status] [--review full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Task, AskUserQuestion

context: |
  !ls production/sprints/ 2>/dev/null
---


## 阶段 0：解析参数

提取模式参数（`new`、`update` 或 `status`）并确定审查模式（一次确定，存储用于本轮所有关卡调用）：
1. 如果传入了 `--review [full|lean|solo]` → 使用该值
2. 否则读取 `production/review-mode.txt` → 使用该值
3. 否则 → 默认使用 `lean`

完整的检查模式参见 `.claude/docs/director-gates.md`。

**审查模式检查**（在关卡运行前）：
- 如果 `production/review-mode.txt` 存在，则读取它。使用该模式。
- 如果文件不存在且这是 `new` 冲刺：使用 `AskUserQuestion`：
  - 提示："未设置审查模式。你希望为此冲刺使用哪种审查深度？"
  - 选项：
    - `[A] full — 启动所有主管和主管关卡`
    - `[B] lean — 跳过非阶段关口的主管审查（推荐用于大多数冲刺）`
    - `[C] solo — 跳过所有关卡启动`
  - 选择后：将所选模式写入 `production/review-mode.txt`。提示："审查模式已设置为 [mode] 并保存到 production/review-mode.txt。"
- 如果文件不存在且这不是 `new` 冲刺（例如，更新现有冲刺）：静默默认使用 `lean`。

---

## 阶段 1：收集上下文

1. **读取当前里程碑**，从 `production/milestones/` 中获取。

2. **读取上一个冲刺**（如有），从 `production/sprints/` 中获取，
   以了解速度和结转项。

3. **扫描设计文档**，在 `design/gdd/` 中查找标记为
   可投入实现的特性。

4. **检查风险登记册**，位于 `production/risk-register/`。

---

## 阶段 2：生成输出

对于 `new`：

**生成冲刺计划**，遵循以下格式并向用户展示。**不要**请求写入——制作人可行性关卡（阶段 4）首先运行，可能需要在写入文件前进行修改。

```markdown
# Sprint [N] — [开始日期] 至 [结束日期]

## 冲刺目标
[一句话描述此冲刺对里程碑的贡献]

## 容量
- 总天数：[X]
- 缓冲（20%）：[保留用于计划外工作的 Y 天]
- 可用：[Z 天]

## 任务

### 必须完成（关键路径）
| ID | 任务 | 智能体/负责人 | 预估天数 | 依赖项 | 验收标准 |
|----|------|-------------|-----------|-------------|-------------------|

### 应该完成
| ID | 任务 | 智能体/负责人 | 预估天数 | 依赖项 | 验收标准 |
|----|------|-------------|-----------|-------------|-------------------|

### 可以完成
| ID | 任务 | 智能体/负责人 | 预估天数 | 依赖项 | 验收标准 |
|----|------|-------------|-----------|-------------|-------------------|

## 上一个冲刺的结转项
| 任务 | 原因 | 新预估 |
|------|--------|-------------|

## 风险
| 风险 | 概率 | 影响 | 缓解措施 |
|------|------------|--------|------------|

## 外部因素依赖
- [列出任何外部依赖]

## 此冲刺的完成定义
- [ ] 所有必须完成的任务已完成
- [ ] 所有任务通过验收标准
- [ ] QA 计划已存在 (`production/qa/qa-plan-sprint-[N].md`)
- [ ] 所有逻辑/集成类故事有通过的单元/集成测试
- [ ] 冒烟检查已通过 (`/smoke-check sprint`)
- [ ] QA 签收报告：APPROVED 或 APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] 已交付特性中无 S1 或 S2 的 bug
- [ ] 任何偏差已更新设计文档
- [ ] 代码已审查并合并
```

对于 `update`：

**更新现有冲刺计划**：

1. 从 `production/sprints/` 读取最近的冲刺计划。
2. 展示当前故事列表及其来自 `production/sprint-status.yaml` 的当前状态。
3. 询问用户要更改什么：要添加、移除、重新排优先级或重新预估的故事。使用 `AskUserQuestion` 收集更改。
4. 应用更改并重新展示完整的修订计划以供审查。
5. 在修订后的计划上重新运行制作人可行性关卡（阶段 4）。
6. 一起写入更新后的 markdown 计划和 yaml（与 `new` 模式的批准方式相同）。

注意：`update` 模式不会重置故事状态。已标记为 `in-progress` 或 `done` 的故事保持其状态。只有 `backlog` 和 `ready-for-dev` 的故事可以自由移除或重新排优先级。

对于 `status`：

**生成状态报告**：

```markdown
# Sprint [N] 状态 -- [日期]

## 进度：[X/Y 个任务完成]（[Z%]）

### 已完成
| 任务 | 完成者 | 备注 |
|------|-------------|-------|

### 进行中
| 任务 | 负责人 | 完成 % | 阻塞项 |
|------|-------|--------|----------|

### 未开始
| 任务 | 负责人 | 有风险？ | 备注 |
|------|-------|----------|-------|

### 已阻塞
| 任务 | 阻塞项 | 阻塞项负责人 | 预计解决时间 |
|------|---------|-----------------|-----|

## 燃尽评估
[按计划进行 / 落后 / 超前]
[如果落后：正在削减或推迟的内容]

## 新出现风险
- [本次冲刺中发现的任何新风险]
```

---

## 阶段 3：准备冲刺状态文件

在生成新的冲刺计划后，同时准备 `production/sprint-status.yaml` 的内容。
这是故事状态的机器可读真理来源——由
`/sprint-status`、`/story-done` 和 `/help` 读取，无需 markdown 解析。

**暂不写入 yaml**——在上下文中保留。制作人可行性关卡（阶段 4）可能会修改故事列表。两个文件将在阶段 4 后在一次写入批准中一起写入。

格式：

```yaml
# 由 /sprint-plan 自动生成。由 /story-done 和 /dev-story 更新。
# 请勿手动编辑——使用 /story-done 更新故事状态。
#
# 状态值映射（yaml ↔ 故事文件 Status 字段）：
#   backlog        ↔  Not Started
#   ready-for-dev  ↔  Ready
#   in-progress    ↔  In Progress
#   review         ↔  In Review
#   done           ↔  Complete
#   blocked        ↔  Blocked

sprint: [N]
goal: "[冲刺目标]"
start: "[YYYY-MM-DD]"
end: "[YYYY-MM-DD]"
generated: "[YYYY-MM-DD]"
updated: "[YYYY-MM-DD]"

stories:
  - id: "[epic-story, e.g. 1-1]"
    name: "[故事名称]"
    file: "[production/stories/path.md]"
    priority: must-have        # must-have | should-have | nice-to-have
    status: ready-for-dev      # backlog | ready-for-dev | in-progress | review | done | blocked
    owner: ""
    estimate_days: 0
    blocker: ""
    completed: ""
```

从冲刺计划的任务表初始化每个故事：
- 必须完成的任务 → `priority: must-have`，`status: ready-for-dev`
- 应该完成的任务 → `priority: should-have`，`status: backlog`
- 可以完成的任务 → `priority: nice-to-have`，`status: backlog`

对于 `update`：读取现有的 `sprint-status.yaml`，保留未更改故事的状态，添加新故事，移除已删除的故事。

---

## 阶段 4：制作人可行性关卡

**审查模式检查**——在启动 PR-SPRINT 前应用：
- `solo` → 跳过。备注："PR-SPRINT skipped — Solo mode." 进入阶段 5（QA 计划关卡）。
- `lean` → 跳过（不是 PHASE-GATE）。备注："PR-SPRINT skipped — Lean mode." 进入阶段 5（QA 计划关卡）。
- `full` → 正常启动。

在最终确定冲刺计划前，通过 Task 使用关卡 **PR-SPRINT**（`.claude/docs/director-gates.md`）生成 `producer`。

传递：提议的故事列表（标题、预估、依赖项）、团队总容量（小时/天）、来自上一个冲刺的任何结转项、里程碑约束和截止日期。

展示制作人的评估。

如果 UNREALISTIC（不切实际）：修改故事选择（将故事推迟到应该完成或可以完成）并在请求写入批准前重新展示更新后的计划。

如果 CONCERNS（有疑虑），使用 `AskUserQuestion`：
- 提示："制作人对此冲刺计划标记了疑虑。你希望如何处理？"
- 选项：
  - `[A] 按计划进行 — 我接受该风险`
  - `[B] 调整范围 — 推迟一些应该完成的故事`
  - `[C] 延长冲刺时间线`

如果 [A]：进行写入批准。
如果 [B]：修改故事列表，重新展示更新后的计划，然后进行写入批准。
如果 [C]：调整冲刺日期和容量，重新展示更新后的计划，然后进行写入批准。

处理完制作人的判定后，询问："我可以将冲刺计划写入 `production/sprints/sprint-[N].md` 和 `production/sprint-status.yaml` 吗？"如果同意，写入两个文件（根据需要创建目录）。判定：**COMPLETE**——冲刺计划和状态文件已创建。如果不同意：判定：**BLOCKED**——用户拒绝了写入。

写入后，添加：

> **范围检查：** 如果此冲刺包含了超出原始史诗范围的故事，在实现开始前运行 `/scope-check [epic]` 以检测范围蔓延。

---

## 阶段 5：QA 计划关卡

在关闭冲刺计划前，检查此冲刺是否存在 QA 计划。

使用 `Glob` 查找 `production/qa/qa-plan-sprint-[N].md` 或 `production/qa/` 中引用此冲刺编号的任何文件。

**如果找到 QA 计划**：在冲刺计划输出中注明——"QA Plan: `[path]`"——然后继续。

**如果不存在 QA 计划**：不要静默继续。明确提示此问题：

> "此冲刺没有 QA 计划。没有 QA 计划的冲刺意味着测试需求未定义——开发者从 QA 角度不知道'完成'是什么样子，并且该冲刺无法通过 Production → Polish 关卡的 QA 签收。
>
> 在开始任何实现前，立即运行 `/qa-plan sprint`。它只需一个会话即可生成每个故事所需的测试用例需求。"

使用 `AskUserQuestion`：
- 提示："未找到此冲刺的 QA 计划。你希望如何处理？"
- 选项：
  - `[A] 立即运行 /qa-plan sprint — 我将在开始实现前执行此操作（推荐）`
  - `[B] 暂时跳过 — 我理解 QA 签收将在 Production → Polish 关卡受阻`

如果 [A]：以"冲刺计划已写入。接下来运行 `/qa-plan sprint`——然后开始实现。"结束。
如果 [B]：在冲刺计划文档中添加一个警告块：

```markdown
> ⚠️ **无 QA 计划**：此冲刺在无 QA 计划的情况下开始。在最后一个故事实现前
> 运行 `/qa-plan sprint`。Production → Polish 关口需要 QA 签收
> 报告，而该报告需要 QA 计划。
```

---

## 阶段 6：后续步骤

在冲刺计划写入且 QA 计划状态确定后：

- `/qa-plan sprint` — **在实现开始前必需** — 为每个故事定义测试用例，使开发者根据 QA 规范实现，而非从空白开始
- `/story-readiness [story-file]` — 在开始之前验证故事是否准备就绪
- `/dev-story [story-file]` — 开始实现第一个故事
- `/sprint-status` — 在冲刺中期检查进度
- `/scope-check [epic]` — 在实现开始前验证无范围蔓延

**审查模式配置：** 所有主管关卡（制作人可行性、QA 审查、代码审查）都遵循项目的审查模式。审查模式在阶段 0 中当文件不存在时设置（对于 `new` 冲刺），或者可以通过 `--review full|lean|solo` 参数每次运行时覆盖。文件 `production/review-mode.txt` 包含以下之一：
- `lean` — 跳过自动化主管关卡（文件缺失时默认——对独立开发者最快）
- `full` — 运行所有主管关卡，作为生成的子智能体运行
- `solo` — 无条件跳过所有关卡（单人开发，无审查）

此文件由 `/sprint-plan`、`/story-readiness`、`/story-done` 和其他技能在启动时读取。
