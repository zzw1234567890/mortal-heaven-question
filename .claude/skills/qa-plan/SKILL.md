---
name: qa-plan
description: "为 sprint 或功能生成 QA 测试计划。读取 GDD 和 story 文件，按测试类型（逻辑/集成/视觉/UI）对 story 进行分类，并生成结构化测试计划，涵盖所需的自动化测试、手动测试用例、冒烟测试范围和试玩签收要求。在 sprint 开始前或开始重大功能时运行。"
argument-hint: "[sprint | feature: system-name | story: path]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, AskUserQuestion

agent: qa-lead
---


# QA 计划

该技能为 sprint、功能或单个 story 生成结构化的 QA 计划。它读取所有范围内的 story 文件及其引用的 GDD，按测试类型对每个 story 进行分类，并生成一个计划，告诉开发者确切需要自动化什么、需要手动验证什么、冒烟测试范围是什么以及何时引入试玩测试员。

在 sprint 开始前运行此技能，以便团队提前知道需要哪些测试工作。在实现之后编写的测试计划是事后总结，而非计划。

**输出：** `production/qa/qa-plan-[sprint-slug]-[date].md`

---

## Phase 1：解析范围

**参数：** `$ARGUMENTS`（空白 = 通过 AskUserQuestion 询问用户）

从参数确定范围：

- **`sprint`** — 读取 `production/sprints/` 中最新的文件，提取每个引用的 story 文件路径。如果 `production/sprint-status.yaml` 存在，将其用作主要 story 列表，并回退到 sprint 计划获取 story 元数据。
- **`feature: [system-name]`** — 搜索 `production/epics/*/story-*.md`，过滤出文件路径或标题包含系统名称的 story。同时检查该系统目录中的 epic 索引文件（`EPIC.md`）。
- **`story: [path]`** — 验证路径是否存在并加载该单个文件。
- **无参数** — 使用 `AskUserQuestion`：
  - "此 QA 计划的范围是什么？"
  - 选项："当前 sprint"、"特定功能（输入系统名称）"、"特定 story（输入路径）"、"完整 epic"

解析范围后报告："正在为 [scope] 中的 [N] 个 story 构建 QA 计划。"

如果某个 story 文件路径被引用但文件不存在，将其记录为缺失并继续处理其他 story。不要因一个缺失文件而失败整个计划。

---

## Phase 2：加载输入

对于每个范围内的 story 文件，读取完整文件并提取：

- **Story 标题**和 story ID（来自文件名或标题）
- **Story 类型**字段（如果文件头中有 — 例如 `Type：Logic`）
- **验收标准** — 完整的编号/要点列表
- **实现文件** — 列在"要创建/修改的文件"或类似标题下
- **引擎说明** — 任何引擎 API 警告或版本特定说明
- **GDD 引用** — 引用的 GDD 路径
- **ADR 引用** — 引用的 ADR
- **估算** — 如果存在，小时数或 story 点数
- **依赖** — 此 story 依赖的其他 story

读取 story 后，一次性加载支持性上下文（不是每个 story 都加载）：

- `design/gdd/systems-index.md` — 了解系统优先级和哪些 GDD 已批准
- 对于所有 story 中引用的每个唯一 GDD：读取**验收标准**、**公式**和**边界情况**章节。不要加载完整的 GDD 文本。这三个章节包含可测试的需求、需要验证的数学逻辑以及测试必须覆盖的边界条件。如果 GDD 中缺少边界情况章节，按 GDD 记录："未找到边界情况章节 — 边界情况覆盖将仅从验收标准推断。"
- `docs/architecture/control-manifest.md` — 扫描自动化测试应防范的禁止模式（如果文件存在）

如果 story 中没有引用 GDD，将其记录为差距但不要阻塞计划。该 story 将仅使用验收标准进行分类。

---

## Phase 3：分类每个 Story

为每个 story 分配一个 Story 类型：

- **如果 story 标题中已有 `Type:` 字段**：按原样接受。不要重新分类或根据以下标准进行验证 — 类型由 lead-programmer 在 story 创建时设置，具有权威性。按原样记录。
- **如果 `Type:` 字段缺失**：使用下表从验收标准推断类型，并在报告中注明该类型是推断的（而非声明的）。将此标记为差距 — story 应在实现开始前显式声明其类型。

| Story 类型 | 分类指标 |
|---|---|
| **逻辑** | 验收标准涉及计算、公式、数值阈值、状态转换、AI 决策、数据验证、buff/debuff 叠加、经济交易或任何可测试的计算 |
| **集成** | 标准涉及两个或多个系统交互、信号或事件跨系统边界传播、存档/读档往返、网络同步或持久化 |
| **视觉/手感** | 标准涉及动画行为、VFX、着色器输出、"感觉响应迅速"、感知时机、屏幕震动、粒子效果、音频同步或视觉反馈质量 |
| **UI** | 标准涉及菜单、HUD 元素、按钮、屏幕、对话框、库存面板、工具提示或任何面向玩家界面的元素 |
| **配置/数据** | 变更仅限于平衡性调优数值、数据文件或配置 — 不涉及新的代码逻辑 |

**混合 story**（例如，同时添加公式和 UI 显示的 story）：根据哪些验收标准承担最高实现风险分配主要类型，并注明次要类型。Logic+Integration 或 Visual+UI 组合最为常见。

对所有 story 分类后，在进入 Phase 4 之前在对话中生成分类汇总表。这使用户能够了解测试将如何分配。

---

## Phase 4：生成测试计划

组装完整的 QA 计划文档。使用此结构：

````markdown
# QA 计划：[Sprint/功能名称]
**日期**：[date]
**由**：/qa-plan 生成
**范围**：[涉及 [N 个系统] 的 [N] 个 story]
**引擎**：[来自 .claude/docs/technical-preferences.md 的引擎名称，或"未配置"]
**Sprint 文件**：[sprint 计划路径（如适用）]

---

## 测试摘要

| Story | 类型 | 需要自动化测试 | 需要手动验证 |
|-------|------|------------------------|------------------------------|
| [story title] | 逻辑 | 单元测试 — `tests/unit/[system]/` | 无 |
| [story title] | 集成 | 集成测试 — `tests/integration/[system]/` | 冒烟检查 |
| [story title] | 视觉/手感 | 无（不可自动化） | 截图 + 主管签收 |
| [story title] | UI | 交互走查 | 手动逐步验证 |
| [story title] | 配置/数据 | 数据验证测试 | 抽查游戏内数值 |

---

## 需要自动化测试

### [Story 标题] — [类型]
**测试文件路径**：`tests/[unit|integration]/[system]/[story-slug]_test.[ext]`
**测试内容**：
- [GDD 公式章节中的特定公式或规则]
- [每个命名的状态转换或决策分支]
- [每个应该或不应该发生的副作用]

**需要覆盖的边界情况**：
- 零/最小输入值（例如 0 伤害、空库存）
- 最大/边界输入值（例如最高等级、属性上限）
- 无效或空输入（例如缺少目标、死亡实体）
- [GDD 边界情况章节中明确指出的任何边界情况]

**预估测试数量**：~[N] 个单元测试

[如果此 story 未找到 GDD 公式引用，注明：]
*在引用的 GDD 中未找到公式 — 测试用例必须直接从验收标准推导。在编写测试前请审查 GDD 公式章节。*

---

## 手动 QA 检查清单

### [Story 标题] — [类型]
**验证方法**：[截图 + 设计师签收 | 试玩会期 | 手动逐步验证 | 对照参考素材进行比较]
**必须签收人**：[designer / lead-programmer / qa-lead / art-lead]
**需要捕获的证据**：[X 的截图 | Y 的视频片段 | 书面试玩笔记 | 并排对比]

检查清单：
- [ ] [具体的可观察条件 — 具体且可证伪]
- [ ] [另一个条件]
- [ ] [每个验收标准转化为手动检查项]

*如果任何标准使用主观语言（"感觉"、"看起来"、"似乎"），必须补充具体的基准或试玩协议说明。*

---

## 冒烟测试范围

在此 sprint 的任何 QA 交接前需要验证的关键路径：

1. 游戏启动到主菜单无崩溃
2. 可以开始新游戏/新会话
3. [本 sprint 引入或更改的主要机制]
4. [本 sprint 变更中存在回归风险的任何系统]
5. 存档/读档周期完成无数据丢失（如果存档系统存在）
6. 性能在目标硬件上符合预算（无新的帧尖峰）

*冒烟测试由开发者通过 `/smoke-check` 验证。运行该技能时参考此列表。*

---

## 试玩要求

| Story | 试玩目标 | 最少会期数 | 目标玩家类型 |
|-------|--------------|--------------|-------------------|
| [story] | [会期必须回答什么问题？] | [N] | [新玩家 / 有经验玩家] |

**签收要求**：试玩笔记必须写入 `production/session-logs/playtest-[sprint]-[story-slug].md`，并在 story 可以标记为完成之前由 [designer / qa-lead] 审查。

如果没有 story 需要试玩验证：*本次 sprint 无需试玩会期。*

---

## 完成定义 — 本次 Sprint

当以下所有条件都满足时，story 才算完成：

- [ ] 所有验收标准已验证 — 通过自动化测试结果或记录的手动证据（截图、视频或带签收的试玩笔记）
- [ ] 所有逻辑和集成类 story 的测试文件存在于指定路径
- [ ] 所有视觉/手感和 UI 类 story 的手动证据文档存在
- [ ] 冒烟检查通过（在 QA 交接前运行 `/smoke-check sprint`）
- [ ] 未引入回归问题
- [ ] 代码已审查（通过 `/code-review` 或记录的同行评审）
- [ ] Story 文件已更新为 `Status: Complete`（通过 `/story-done`）
````

生成内容时，使用 Phase 2 提取的实际 story 标题、GDD 公式文本和验收标准。不要使用占位文本 — 每个测试条目应反映这些特定 story 的真实需求。

---

## Phase 5：写入输出

在对话中显示完整计划（如果计划很长则显示摘要），然后使用 `AskUserQuestion` 同时问两个问题：

```
question: "准备写入 QA 计划。选择输出选项："
multiSelect: true
options:
  - "将 QA 计划写入 production/qa/qa-plan-[sprint-slug]-[date].md"
  - "同时将测试用例规格回填到每个 story 文件的 ## QA Test Cases 章节（推荐 — 支持 /dev-story 和 /code-review 可追溯性）"
```

如果选择了"写入 QA 计划"：按原样写入计划文件 — 不要截断。

如果选择了"同时回填 story 文件"：对于范围内每个逻辑和集成类 story，编辑其路径下的 story 文件。找到 `## QA Test Cases` 章节并将其内容替换为 Phase 4 为该 story 生成的测试用例规格。如果某个 story 没有 `## QA Test Cases` 章节，在 `## Test Evidence` 之前添加它。对于视觉/手感和 UI 类 story，写入手动验证步骤而非测试规格。

写入后：

"QA 计划已写入 `production/qa/qa-plan-[sprint-slug]-[date].md`。

后续步骤：
- 在 sprint 实现开始前与团队分享此计划
- 所有 sprint story 实现后，运行 `/smoke-check sprint` 以把关 QA 交接 — 还不是现在，只在实现完成后
- 对于逻辑/集成类 story，在标记 story 完成前在所列路径创建测试文件 — `/story-done` 会检查它们"

静默追加到 `production/session-state/active.md`（如果文件不存在则创建）：

```
<!-- QA-PLAN：[date] | System：[system/sprint identifier] | Plan written：production/qa/qa-plan-[identifier]-[date].md -->
```

---

## 协作协议

- **未经询问绝不写入计划** — Phase 5 需要明确批准。
- **保守分类**：当 story 在逻辑和集成之间模糊时，将其分类为集成 — 它需要单元测试和集成测试。
- **不要编造测试用例** — 仅使用验收标准和 GDD 公式支持的内容。如果 GDD 中缺少公式，标记出来而不是猜测。
- **试玩要求是建议性的**：用户决定对于边界性的视觉/手感 story 是否需要试玩。标记情况，不要强制要求。
- **未提供参数时**使用 `AskUserQuestion` 进行范围选择。保持所有其他阶段非交互 — 展示发现，然后一次性询问以批准写入。
