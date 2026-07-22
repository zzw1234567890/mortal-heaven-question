---
name: milestone-review
description: "生成全面的里程碑进度审查，包括功能完成度、质量指标、风险评估和通过/否决建议。在里程碑检查点或评估里程碑截止日期就绪度时使用。"
argument-hint: "[milestone-name|current] [--review full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Task, AskUserQuestion

---


## 阶段 0：解析参数 (Parse Arguments)

提取里程碑名称（`current` 或特定名称）并解析审查模式（一次确定，本次运行所有关卡调用的存储值）：
1. 如果传递了 `--review [full|lean|solo]` → 使用该值
2. 否则读取 `production/review-mode.txt` → 使用该值
3. 否则 → 默认为 `lean`

完整检查模式参见 `.claude/docs/director-gates.md`。

---

## 阶段 1：加载里程碑数据 (Load Milestone Data)

从 `production/milestones/` 读取里程碑定义。如果参数为 `current`，使用最近修改的里程碑文件。

从 `production/sprints/` 读取此里程碑范围内所有冲刺 (sprint) 的冲刺报告。

---

## 阶段 2：扫描代码库健康状况 (Scan Codebase Health)

- 扫描指示未完成工作的 `TODO`、`FIXME`、`HACK` 标记
- 检查 `production/risk-register/` 处的风险登记册

---

## 阶段 3：生成里程碑审查报告 (Generate the Milestone Review)

```markdown
# Milestone Review: [Milestone Name]

## Overview
- **Target Date**: [Date]
- **Current Date**: [Today]
- **Days Remaining**: [N]
- **Sprints Completed**: [X/Y]

## Feature Completeness

### Fully Complete
| Feature | Acceptance Criteria | Test Status |
|---------|-------------------|-------------|

### Partially Complete
| Feature | % Done | Remaining Work | Risk to Milestone |
|---------|--------|---------------|------------------|

### Not Started
| Feature | Priority | Can Cut? | Impact of Cutting |
|---------|----------|----------|------------------|

## Quality Metrics
- **Open S1 Bugs**: [N] -- [List]
- **Open S2 Bugs**: [N]
- **Open S3 Bugs**: [N]
- **Test Coverage**: [X%]
- **Performance**: [Within budget? Details]

## Code Health
- **TODO count**: [N across codebase]
- **FIXME count**: [N]
- **HACK count**: [N]
- **Technical debt items**: [List critical ones]

## Risk Assessment
| Risk | Status | Impact if Realized | Mitigation Status |
|------|--------|-------------------|------------------|

## Velocity Analysis
- **Planned vs Completed** (across all sprints): [X/Y tasks = Z%]
- **Trend**: [Improving / Stable / Declining]
- **Adjusted estimate for remaining work**: [Days needed at current velocity]

## Scope Recommendations
### Protect (Must ship with milestone)
- [Feature and why]

### At Risk (May need to cut or simplify)
- [Feature and risk]

### Cut Candidates (Can defer without compromising milestone)
- [Feature and impact of cutting]

## Go/No-Go Assessment

**Recommendation**: [GO / CONDITIONAL GO / NO-GO]

**Conditions** (if conditional):
- [Condition 1 that must be met]
- [Condition 2 that must be met]

**Rationale**: [Explanation of the recommendation]

## Action Items
| # | Action | Owner | Deadline |
|---|--------|-------|----------|
```

---

## 阶段 3b：生产者风险评估 (Producer Risk Assessment)

**审查模式检查** — 在生成 PR-MILESTONE 之前应用：
- `solo` → 跳过。备注："PR-MILESTONE 已跳过 —— Solo 模式。" 直接呈现 Go/No-Go 部分，无需生产者裁定。
- `lean` → 跳过（非阶段关卡）。备注："PR-MILESTONE 已跳过 —— Lean 模式。" 直接呈现 Go/No-Go 部分，无需生产者裁定。
- `full` → 正常生成。

在生成 Go/No-Go 建议之前，通过 Task 使用关卡 **PR-MILESTONE**（`.claude/docs/director-gates.md`）生成 `producer`。

传递：里程碑名称和目标日期、当前完成百分比、被阻塞的故事数量、冲刺报告中的速度数据（如可用）、待删减候选列表。

在 Go/No-Go 部分内联呈现生产者的评估结果。生产者的裁定（ON TRACK / AT RISK / OFF TRACK）为整体建议提供依据。

如果 OFF TRACK，在生成建议之前使用 `AskUserQuestion`：
- 提示："生产者裁定：OFF TRACK。该里程碑处于危险之中。此审查将建议 NO-GO。您想如何处理？"
- 选项：
  - `[A] 接受 NO-GO — 以该建议生成完整审查报告`
  - `[B] 覆盖为 CONDITIONAL GO — 我将自行记录已接受的风险`
  - `[C] 停止 — 我需要在生成审查报告之前解决阻塞项`

如果 AT RISK，使用 `AskUserQuestion`：
- 提示："生产者裁定：AT RISK。里程碑可能延期。Go/No-Go 部分应如何表述？"
- 选项：
  - `[A] CONDITIONAL GO — 在审查报告中包含生产者提出的条件`
  - `[B] NO-GO — 条件无法按时满足`
  - `[C] GO — 我接受该风险并希望继续`

除非用户明确选择了上述 [B]，否则不要针对 OFF TRACK 裁定发出 GO。

---

## 阶段 4：保存审查报告 (Save Review)

向用户呈现审查报告。

询问："我可以将此写入 `production/milestones/[milestone-name]-review.md` 吗？"

如果是，则写入文件，必要时创建目录。裁定：**COMPLETE** —— 里程碑审查报告已保存。

如果否，在此停止。裁定：**BLOCKED** —— 用户拒绝了写入。

---

## 阶段 5：后续步骤 (Next Steps)

- 如果此里程碑标志着开发阶段边界，运行 `/gate-check` 以获取正式的阶段关口裁定。
- 运行 `/sprint-plan` 以根据上述范围建议调整下一个冲刺 (sprint)。
