---
name: code-review
description: "对指定的文件或文件集执行架构与质量代码审查。检查编码标准合规性、架构模式遵循情况、SOLID 原则、可测试性和性能问题。"
argument-hint: "[path-to-file-or-directory]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion

agent: lead-programmer
---


## 第一阶段：加载目标文件

完整读取目标文件。读取 `CLAUDE.md` 了解项目编码标准。

---

## 第二阶段：识别引擎专家

读取 `.claude/docs/technical-preferences.md` 中的 `## Engine Specialists` 部分。注意：

- **主要（Primary）**专家（用于架构和广泛的引擎问题）
- **语言/代码专家（Language/Code Specialist）**（用于审查项目的 primary 语言文件）
- **着色器专家（Shader Specialist）**（用于审查着色器文件）
- **UI 专家（UI Specialist）**（用于审查 UI 代码）

如果该部分显示 `[TO BE CONFIGURED]`，则表示未指定引擎——跳过引擎专家步骤。

---

## 第三阶段：ADR 合规性检查

**参数：** `/code-review [file(s)]` 可选择性地在末尾包含一个故事文件路径（例如 `/code-review src/combat/attack.gd production/epics/combat/story-001.md`）。如果提供了故事路径，则读取它以提取管辖的 ADR 引用。

按优先级顺序搜索 ADR 引用：
1. 故事文件（如果作为参数提供）
2. 实现文件顶部的头注释
3. 引用这些文件的提交信息（`git log --oneline -- [file]`）

查找 `ADR-NNN` 或 `docs/architecture/ADR-` 等模式。

如果未找到 ADR 引用，记录："No ADR references found — ADR compliance check skipped. For full ADR compliance review, provide the story path: `/code-review [files] [story-path]`."

对于每个引用的 ADR：读取文件，提取**决策（Decision）**和**影响（Consequences）**部分，然后对任何偏差进行分类：

- **架构违规（ARCHITECTURAL VIOLATION）**（阻塞性）：使用了 ADR 中明确拒绝的模式
- **ADR 漂移（ADR DRIFT）**（警告）：有意义地偏离了所选方法，但未使用禁止模式
- **轻微偏差（MINOR DEVIATION）**（信息性）：与 ADR 指导的微小差异，不影响整体架构

---

## 第四阶段：标准合规性

识别系统类别（引擎、玩法、AI、网络、UI、工具）并评估：

- [ ] 公开方法和类具有文档注释
- [ ] 每个方法的圈复杂度（Cyclomatic complexity）低于 10
- [ ] 方法不超过 40 行（不包含数据声明）
- [ ] 依赖项通过依赖注入（无静态单例用于游戏状态）
- [ ] 配置值从数据文件加载
- [ ] 系统暴露接口（而非具体类依赖）

---

## 第五阶段：架构与 SOLID

**架构：**
- [ ] 正确的依赖方向（引擎 ← 玩法，而非反向）
- [ ] 模块之间无循环依赖
- [ ] 正确的层分离（UI 不拥有游戏状态）
- [ ] 使用事件/信号进行跨系统通信
- [ ] 与代码库中已建立的模式一致

**SOLID：**
- [ ] 单一职责（Single Responsibility）：每个类只有一个变更理由
- [ ] 开闭原则（Open/Closed）：可扩展而不修改
- [ ] 里氏替换（Liskov Substitution）：子类型可替换基类型
- [ ] 接口隔离（Interface Segregation）：无臃肿接口
- [ ] 依赖反转（Dependency Inversion）：依赖抽象而非具体实现

---

## 第六阶段：游戏特定关注点

- [ ] 帧率无关性（delta time 的使用）
- [ ] 热路径（更新循环）中无分配
- [ ] 适当的 null/空状态处理
- [ ] 必要时保证线程安全
- [ ] 资源清理（无泄漏）

---

## 第七阶段：专家评审（并行）

通过 Task 同时生成所有适用的专家——不要等待一个完成再开始下一个。

### 引擎专家

如果已配置引擎，确定每个文件适用的专家并并行生成：

- 主要语言文件（`.gd`、`.cs`、`.cpp`）→ 语言/代码专家
- 着色器文件（`.gdshader`、`.hlsl`、着色器图表）→ 着色器专家
- UI 屏幕/控件代码 → UI 专家
- 跨领域的或不明确的 → 主要专家

同时为任何涉及引擎架构的文件（场景结构、节点层级、生命周期钩子）生成**主要专家（Primary Specialist）**。

### QA 可测试性审查

对于逻辑型（Logic）和集成型（Integration）故事，同时通过 Task 生成 `qa-tester`，与引擎专家并行。传递：
- 正在审查的实现文件
- 故事的 `## QA Test Cases` 部分（qa-lead 预编写的测试规格）
- 故事的 `## Acceptance Criteria`

要求 qa-tester 评估：
- [ ] 所有测试钩子和接口是否已暴露（而非隐藏在私有/内部访问之后）？
- [ ] 故事 `## QA Test Cases` 部分中的 QA 测试用例是否映射到可测试的代码路径？
- [ ] 是否有任何验收标准在实现后无法测试（例如硬编码值、无可注入的接缝）？
- [ ] 实现是否引入了现有 QA 测试用例未覆盖的任何新边缘情况？
- [ ] 是否存在应有的可观察副作用但缺少测试？

对于视觉感受型（Visual/Feel）和 UI 型故事：qa-tester 审查 `## QA Test Cases` 中的手动验证步骤在实现中是否可实现——例如"手动检查器需要达到的状态实际上可达到吗？"

在生成输出之前收集所有专家评审结果。

---

## 第八阶段：输出审查

```
## Code Review: [File/System Name]

### Engine Specialist Findings: [N/A — no engine configured / CLEAN / ISSUES FOUND]
[Findings from engine specialist(s), or "No engine configured." if skipped]

### Testability: [N/A — Visual/Feel or Config story / TESTABLE / GAPS / BLOCKING]
[qa-tester findings: test hooks, coverage gaps, untestable paths, new edge cases]
[If BLOCKING: implementation must expose [X] before tests in ## QA Test Cases can run]

### ADR Compliance: [NO ADRS FOUND / COMPLIANT / DRIFT / VIOLATION]
[List each ADR checked, result, and any deviations with severity]

### Standards Compliance: [X/6 passing]
[List failures with line references]

### Architecture: [CLEAN / MINOR ISSUES / VIOLATIONS FOUND]
[List specific architectural concerns]

### SOLID: [COMPLIANT / ISSUES FOUND]
[List specific violations]

### Game-Specific Concerns
[List game development specific issues]

### Positive Observations
[What is done well -- always include this section]

### Required Changes
[Must-fix items before approval — ARCHITECTURAL VIOLATIONs always appear here]

### Suggestions
[Nice-to-have improvements]

### Verdict: [APPROVED / APPROVED WITH SUGGESTIONS / CHANGES REQUIRED]
```

本技能为只读——不写入任何文件。

---

## 第九阶段：后续步骤

使用 `AskUserQuestion`：
- 提示："Code review complete — verdict: [APPROVED / CHANGES REQUIRED / MAJOR REVISION]. How would you like to proceed?"
- 选项（根据结论调整）：
  - 如果为 APPROVED：
    - `[A] Run /story-done to mark the story complete`
    - `[B] Stop here`
  - 如果为 CHANGES REQUIRED 或 MAJOR REVISION：
    - `[A] Fix the issues and re-run /code-review`
    - `[B] Run /story-done anyway with noted exceptions`
    - `[C] Stop here`

如果发现架构违规（ARCHITECTURAL VIOLATION）：
- 如果违规与**现有 ADR**相矛盾：修复实现以符合 `docs/architecture/[adr-file].md`。如果设计确实发生了变化，运行 `/architecture-decision` 来正式*修订*现有 ADR——不要创建相竞争的 ADR。
- 如果被违反的模式**没有对应 ADR**：在修复代码之前运行 `/architecture-decision` 来记录正确的方法。
