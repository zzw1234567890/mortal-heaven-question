---
name: team-qa
description: "编排 QA 团队完成完整的测试周期。协调 qa-lead（QA 主管，策略 + 测试计划）和 qa-tester（QA 测试员，测试用例编写 + 缺陷报告），为一个 sprint 或功能生成完整的 QA 包。涵盖：测试计划生成、测试用例编写、冒烟检查关卡、手动 QA 执行和签收报告。"
argument-hint: "[sprint | feature: system-name] [--review full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Task, AskUserQuestion

agent: qa-lead
---


当本 skill 被调用时，通过结构化测试周期编排 QA 团队。

**决策节点：** 在每个阶段过渡时，使用 `AskUserQuestion` 向用户展示子代理的提案作为可选选项。在对话中完整记录代理的分析，然后以简洁的标签记录决策。用户必须批准后才能进入下一阶段。

## 阶段 0：解析审查模式

1. 如果 `--review [mode]` 作为参数传入，使用该模式。
2. 否则读取 `production/review-mode.txt` — 使用其中写入的内容。
3. 否则默认为 `lean`。

模式：
- `full` — 按描述生成所有总监和主管关卡
- `lean` — 跳过总监关卡，除非是阶段关卡类型（CD-PHASE-GATE、TD-PHASE-GATE、PR-PHASE-GATE、AD-PHASE-GATE）
- `solo` — 完全跳过所有总监关卡生成；在没有任何代理关卡的情况下运行 skill

将解析后的模式存储起来，用于所有后续阶段。

## 团队组成

- **qa-lead（QA 主管）** — QA 策略、测试计划生成、story 分类、签收报告
- **qa-tester（QA 测试员）** — 测试用例编写、缺陷报告编写、手动 QA 文档

## 如何委派

使用 Task 工具将每个团队成员生成为子代理：
- `subagent_type: qa-lead` — 策略、规划、分类、签收
- `subagent_type: qa-tester` — 测试用例编写和缺陷报告编写

始终为每个代理提供完整的上下文（story 文件路径、QA 计划路径、范围约束）。在可能的情况下并行启动独立的 qa-tester 任务（例如阶段 5 中的多个 story 可以同时搭建）。

## 管线

### 阶段 1：加载上下文

在开始任何其他操作之前，收集完整范围：

1. 从参数中检测当前 sprint 或功能范围：
   - 如果参数是 sprint 标识符（例如 `sprint-03`）：在 `production/sprints/` 中 Glob 匹配 `*[sprint-identifier]*.md` 的文件。读取匹配的文件。如果多个匹配，使用最近修改的那个。
   - 如果参数是 `feature: [system-name]`：glob 标记为属于该系统的 story 文件
   - 如果没有参数：读取 `production/session-state/active.md` 和 `production/sprint-status.yaml`（如果存在）以推断当前活动的 sprint

2. 读取 `production/stage.txt` 以确认当前项目阶段。

3. 统计找到的 story 数量并向用户报告：
   > "QA 周期即将开始，针对 [sprint/feature]。找到 [N] 个 story。当前阶段：[stage]。准备开始 QA 策略？"

### 阶段 2：QA 策略（qa-lead）

通过 Task 生成 `qa-lead` 以审查所有范围内的 story 并制定 QA 策略。

提示 qa-lead 执行以下操作：
- 读取每个 story 文件
- 按类型对每个 story 进行分类：**Logic** / **Integration** / **Visual/Feel** / **UI** / **Config/Data**
- 识别哪些 story 需要自动化测试证据 vs. 手动 QA
- 标记任何缺少验收标准或缺少会阻塞 QA 的测试证据的 story
- 估算手动 QA 工作量（所需的测试会话次数）
- **在评估冒烟状态之前，检查现有冒烟检查报告**：Glob `production/qa/smoke-*.md` 并读取最近修改的文件（如果找到）。如果报告存在，直接使用其裁决和发现——不要重新询问用户。如果不存在报告，注明："未找到先前的冒烟检查报告——请在继续前运行 `/smoke-check sprint`。"并将冒烟检查状态设置为 UNKNOWN（为继续目的视为 PASS WITH WARNINGS）。生成冒烟检查裁决：**PASS** / **PASS WITH WARNINGS [列表]** / **FAIL [失败列表]** / **UNKNOWN（未找到报告）**
- 生成策略摘要表和冒烟检查结果：

  | Story | 类型 | 需要自动化 | 需要手动 | 阻塞？ |
  |-------|------|-------------|----------|--------|
  
  **冒烟检查**：[PASS / PASS WITH WARNINGS / FAIL / UNKNOWN] — [来源：`production/qa/smoke-[date].md` 或"未找到报告"] — [如果不是 PASS 则提供详情]

如果冒烟检查结果为 **FAIL**，qa-lead 必须突出列出失败项。QA 不得在冒烟检查失败的情况下越过策略阶段继续。

将 qa-lead 的完整策略呈现给用户，然后使用 `AskUserQuestion`：

```
question: "QA 策略审查"
options:
  - "看起来不错——继续进行测试计划"
  - "在继续前调整 story 类型"
  - "跳过阻塞的 story，继续处理其余部分"
  - "冒烟检查失败——修复问题并重新运行 /team-qa"
  - "取消——先解决阻塞因素"
```

如果冒烟检查 **FAIL**：不要进入阶段 3。上报冒烟检查报告中的失败并停止。用户必须修复它们，重新运行 `/smoke-check sprint`，然后重新运行 `/team-qa`。
如果冒烟检查 **UNKNOWN**：上报警告——"未找到冒烟检查报告。建议在 QA 前运行 `/smoke-check sprint`。谨慎继续。"
如果冒烟检查 **PASS WITH WARNINGS**：在签收报告中记录警告并继续。
如果存在阻塞因素：明确列出它们。用户可以选择跳过阻塞的 story 或取消该周期。

### 阶段 3：测试计划生成

使用阶段 2 的策略，生成结构化的测试计划文档。

测试计划应涵盖：
- **范围**：sprint/功能名称、story 数量、日期
- **Story 分类表**：来自阶段 2 的策略
- **自动化测试要求**：哪些 story 需要测试文件，`tests/` 中的预期路径
- **手动 QA 范围**：哪些 story 需要手动走查以及要验证什么
- **范围外**：明确说明本周期不测试的内容及原因
- **准入标准**：QA 开始前必须为真的条件。始终包含：(1) 存在 PASS 或 PASS WITH WARNINGS 的冒烟检查报告在 `production/qa/smoke-*.md` 中，(2) 构建稳定（启动不崩溃），(3) 所有必须有的 story 在 `production/sprint-status.yaml` 中状态为进行中或已完成。除此之外添加任何 sprint 特定的标准。
- **准出标准**：构成完整 QA 周期的条件（所有 story PASS 或 FAIL 并已提交缺陷）

询问："May I write the QA plan to `production/qa/qa-plan-[sprint]-[date].md`?"

仅在获得批准后写入。

### 阶段 4：测试用例编写（qa-tester）

> **冒烟检查**作为阶段 2（QA 策略）的一部分执行。如果阶段 2 中冒烟检查返回 FAIL，周期已在此停止。只有在阶段 2 冒烟检查结果为 PASS、PASS WITH WARNINGS 或 UNKNOWN 时，本阶段才会运行。

对于每个需要手动 QA 的 story（Visual/Feel、UI、没有自动化测试的 Integration）：

为每个 story 通过 Task 生成 `qa-tester`（在可能的情况下并行运行），提供：
- story 文件路径
- QA 计划中与该 story 相关的部分
- 被测试系统的 GDD 验收标准（如可用）
- 编写覆盖所有验收标准的详细测试用例的说明

每组测试用例应包括：
- **前置条件**：测试开始前所需的游戏状态
- **步骤**：编号的、无歧义的操作
- **预期结果**：应该发生什么
- **实际结果**：留空供测试员填写
- **通过/失败**：留空

在执行前将测试用例呈现给用户审查。按 story 分组。

使用 `AskUserQuestion` 对每个 story 组进行询问（每次批处理 3-4 个）：

```
question: "[Story 组] 的测试用例已就绪。在手动 QA 开始前进行审查？"
options:
  - "已批准——开始这些 story 的手动 QA"
  - "修订 [story 名称] 的测试用例"
  - "跳过 [story 名称] 的手动 QA——尚未准备就绪"
```

### 阶段 5：手动 QA 执行

逐一走查已批准的手动 QA 列表中的每个 story。

将 story 分批为每组 3-4 个，并对每组使用 `AskUserQuestion`：

```
question: "手动 QA — [Story 标题]\n[要测试内容的简要描述]"
options:
  - "PASS — 所有验收标准已验证"
  - "PASS WITH NOTES — 发现小问题（之后描述）"
  - "FAIL — 未达到标准（之后描述）"
  - "BLOCKED — 尚无法测试（原因）"
```

在每个 FAIL 结果之后：使用 `AskUserQuestion` 收集失败描述，然后通过 Task 生成 `qa-tester` 在 `production/qa/bugs/` 中编写正式的缺陷报告。

缺陷报告命名：`BUG-[NNN]-[short-slug].md`（从目录中现有缺陷递增 NNN）。

收集所有结果后，总结：
- Story PASS：[数量]
- Story PASS WITH NOTES：[数量]
- Story FAIL：[数量] — 已提交缺陷：[ID]
- Story BLOCKED：[数量]

### 阶段 6：QA 签收报告

通过 Task 生成 `qa-lead`，使用阶段 4-6 的所有结果生成签收报告。

签收报告格式：

```markdown
## QA 签收报告：[Sprint/功能]
**日期**：[日期]

### 测试覆盖率总结
| Story | 类型 | 自动化测试 | 手动 QA | 结果 |
|-------|------|------------|---------|------|
| [标题] | Logic | PASS | — | PASS |
| [标题] | Visual | — | PASS | PASS |

### 发现的缺陷
| ID | Story | 严重性 | 状态 |
|----|-------|--------|------|
| BUG-001 | [story] | S2 | 打开 |

### 裁决：APPROVED / APPROVED WITH CONDITIONS / NOT APPROVED

**条件**（如有）：[列出在构建推进前必须修复的内容]

### 下一步
[基于裁决的指导]
```

裁决规则：
- **APPROVED**：所有 story PASS 或 PASS WITH NOTES；没有打开的 S1/S2 缺陷
- **APPROVED WITH CONDITIONS**：S3/S4 缺陷打开，或 PASS WITH NOTES 问题已记录；没有 S1/S2 缺陷
- **NOT APPROVED**：任何 S1/S2 缺陷打开；或 story FAIL 且没有文档记录的解决方案

按裁决的下一步指导：
- APPROVED："构建已准备好进入下一阶段。运行 `/gate-check` 验证推进。"
- APPROVED WITH CONDITIONS："在推进前解决条件问题。S3/S4 缺陷可推迟到打磨阶段。"
- NOT APPROVED："解决 S1/S2 缺陷并在推进前重新运行 `/team-qa` 或针对性手动 QA。"

询问："May I write this QA sign-off report to `production/qa/qa-signoff-[sprint]-[date].md`?"

仅在获得批准后写入。

## 错误恢复协议

如果任何生成的代理（通过 Task）返回 BLOCKED、出错或无法完成：

1. **立即上报**：在继续依赖阶段之前向用户报告"[代理名称]：BLOCKED — [原因]"
2. **评估依赖关系**：检查被阻塞代理的输出是否为后续阶段所需。如果是，在没有用户输入的情况下不要越过该依赖点继续。
3. **通过 AskUserQuestion 提供选项**，包含以下选择：
   - 跳过此代理并在最终报告中记录缺口
   - 以更窄的范围重试
   - 在此停止，先解决阻塞因素
4. **始终生成部分报告** — 输出已完成的内容。绝不要因为一个代理阻塞而丢弃已完成的工作。

常见阻塞因素：
- 输入文件缺失（story 未找到，GDD 不存在）→ 重定向到创建该文件的 skill
- ADR 状态为 Proposed → 不实施；先运行 `/architecture-decision`
- 范围过大 → 通过 `/create-stories` 拆分为两个 story
- ADR 与 story 之间的指令冲突 → 上报冲突，不要猜测

## 输出

一份总结，涵盖：范围内的 story、冒烟检查结果、手动 QA 结果、已提交缺陷（含 ID 和严重性）以及最终的 APPROVED / APPROVED WITH CONDITIONS / NOT APPROVED 裁决。

裁决：**COMPLETE** — QA 周期完成。
裁决：**BLOCKED** — 冒烟检查失败或关键阻塞因素阻止了周期完成；已生成部分报告。

## 会话状态更新

在最终阶段完成后（签收报告已写入或达到 BLOCKED 裁决），静默追加到 `production/session-state/active.md`：

```
<!-- QA RUN: [日期] | Sprint: [sprint 标识符或"ad-hoc"] | Verdict: [PASS/FAIL/CONCERNS] | Report: production/qa/qa-[date].md -->
```
