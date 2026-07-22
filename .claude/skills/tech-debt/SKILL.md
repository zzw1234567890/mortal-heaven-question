---
name: tech-debt
description: "跨代码库跟踪、分类和优先级排序技术债务。扫描债务指标，维护债务登记表，并建议偿还计划。"
argument-hint: "[scan|add|prioritize|report]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, AskUserQuestion

---


## 阶段 1：解析子命令

根据参数确定模式：

- `scan` — 扫描代码库中的技术债务指标
- `add` — 手动添加新的技术债务条目
- `prioritize` — 重新对现有债务登记表进行优先级排序
- `report` — 生成当前债务状态的总结报告

如果未提供子命令，输出用法说明并停止。判定：**FAIL** — 缺少必需的子命令。

---

## 阶段 2A：扫描模式

搜索代码库中的债务指标：

- `TODO` 注释（计数和分类）
- `FIXME` 注释（这些是伪装成债务的错误）
- `HACK` 注释（需要适当解决方案的变通方法）
- `@deprecated` 标记
- 重复的代码块（多个文件中的相似模式）
- 超过 500 行的文件（潜在的上帝对象）
- 超过 50 行的函数（潜在的复杂度）

对每个发现进行分类：

- **架构债务 (Architecture Debt)**：错误的抽象、缺失的模式、耦合问题
- **代码质量债务 (Code Quality Debt)**：重复、复杂度、命名、缺失类型
- **测试债务 (Test Debt)**：缺失测试、不稳定测试、未测试的边缘情况
- **文档债务 (Documentation Debt)**：缺失文档、过时文档、未记录的 API
- **依赖债务 (Dependency Debt)**：过时的包、已弃用的 API、版本冲突
- **性能债务 (Performance Debt)**：已知的慢路径、未优化的查询、内存问题

将发现结果呈现给用户。

询问："我可以将这些发现写入 `docs/tech-debt-register.md` 吗？"

如果同意，更新登记表（追加新条目，不要覆盖现有条目）。判定：**COMPLETE** — 扫描结果已写入登记表。

如果不同意，在此停止。判定：**BLOCKED** — 用户拒绝写入。

---

## 阶段 2B：添加模式

询问用户描述、受影响的文件以及如果不修复会产生的影响（纯文本提示）。

然后使用 `AskUserQuestion` 收集 **类别**：
- 提示："此技术债务属于哪个类别？"
- 选项：
  - `[A] 架构债务 (Architecture Debt) — 错误的抽象、缺失的模式、耦合问题`
  - `[B] 代码质量债务 (Code Quality Debt) — 重复、复杂度、命名、缺失类型`
  - `[C] 测试债务 (Test Debt) — 缺失测试、不稳定测试、未测试的边缘情况`
  - `[D] 文档债务 (Documentation Debt) — 缺失/过时文档、未记录的 API`
  - `[E] 依赖债务 (Dependency Debt) — 过时的包、已弃用的 API、版本冲突`
  - `[F] 性能债务 (Performance Debt) — 已知的慢路径、内存问题、未优化的查询`

然后使用 `AskUserQuestion` 收集 **预估修复工作量**：
- 提示："修复此项的预估工作量是多少？"
- 选项：
  - `[A] S — 小（1 天以内）`
  - `[B] M — 中（1-3 天）`
  - `[C] L — 大（3-7 天）`
  - `[D] XL — 特大（超过 1 周）`

将完整的条目呈现给用户。

询问："我可以将此条目追加到 `docs/tech-debt-register.md` 吗？"

如果同意，追加条目。判定：**COMPLETE** — 条目已添加到登记表。

如果不同意，在此停止。判定：**BLOCKED** — 用户拒绝写入。

---

## 阶段 2C：优先排序模式

读取位于 `docs/tech-debt-register.md` 的债务登记表。

按照以下公式打分每个条目：`(未修复影响 × 遇到频率) / 修复工作量`

按优先级分数重新排序登记表，并推荐在下一个冲刺中包含哪些条目。

将重新排序后的登记表呈现给用户。

询问："我可以将重新排序后的登记表写回 `docs/tech-debt-register.md` 吗？"

如果同意，写入更新后的文件。判定：**COMPLETE** — 登记表已重新排序并保存。

如果不同意，在此停止。判定：**BLOCKED** — 用户拒绝写入。

---

## 阶段 2D：报告模式

读取债务登记表。生成汇总统计：

- 按类别统计的总条目数
- 总预估修复工作量
- 自上次报告以来新增 vs 已解决的条目数
- 趋势方向（增长中 / 稳定 / 缩小中）

标记任何已在登记表中超过 3 个冲刺的条目。

将报告输出给用户。此模式为只读 — 不写入文件。判定：**COMPLETE** — 债务报告已生成。

---

## 阶段 3：后续步骤

- 运行 `/sprint-plan` 将高优先级债务条目安排到下一个冲刺中。
- 在每个冲刺开始时运行 `/tech-debt report` 以跟踪债务随时间变化的趋势。

### 债务登记表格式

```markdown
## Technical Debt Register
Last updated: [Date]
Total items: [N] | Estimated total effort: [T-shirt sizes summed]

| ID | Category | Description | Files | Effort | Impact | Priority | Added | Sprint |
|----|----------|-------------|-------|--------|--------|----------|-------|--------|
| TD-001 | [Cat] | [Description] | [files] | [S/M/L/XL] | [Low/Med/High/Critical] | [Score] | [Date] | [Sprint to fix or "Backlog"] |
```

### 规则
- 技术债务本质上并非坏事——它是一种工具。登记表用于追踪有意识的决策。
- 每个债务条目必须解释为什么它被接受（截止日期、原型、信息缺失）
- "扫描"应至少每个冲刺运行一次，以捕获新增债务
- 超过 3 个冲刺未处理的条目应要么被修复，要么有意识地接受并记录理由
