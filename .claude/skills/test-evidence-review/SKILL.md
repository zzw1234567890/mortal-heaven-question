---
name: test-evidence-review
description: "对测试文件和手动证据文档的质量审查。超越存在性检查——评估断言覆盖率、边界情况处理、命名规范和证据完整性。为每个故事生成 ADEQUATE/INCOMPLETE/MISSING 判定。在QA签收前或按需运行。"
argument-hint: "[story-path | sprint | system-name]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write

---

# 测试证据审查 (Test Evidence Review)


`/smoke-check` 负责验证测试文件 **存在** 且 **通过**。本技能更进一步 —— 它审查这些测试和证据文档的 **质量**。一个存在且通过的测试文件可能仍然遗漏了关键行为。一个存在的证据文档可能缺少结项所需的签字确认。

**输出：** 总结报告（对话中）+ 可选的 `production/qa/evidence-review-[date].md`

**运行时机：**
- 在质量保证 (Quality Assurance, QA) 交接签核前（`/team-qa` 阶段 5）
- 在任何测试质量存疑的故事上
- 作为里程碑 (Milestone) 审查的一部分，用于逻辑 (Logic) 和集成 (Integration) 故事质量审计

---

## 1. 解析参数 (Parse Arguments)

**模式：**
- `/test-evidence-review [story-path]` — 审查单个故事的证据
- `/test-evidence-review sprint` — 审查当前冲刺 (Sprint) 中的所有故事
- `/test-evidence-review [system-name]` — 审查史诗/系统中的所有故事
- 无参数 — 询问范围："单个故事 (Single story)"、"当前冲刺 (Current sprint)"、"某个系统 (A system)"

---

## 2. 加载范围内的故事 (Load Stories in Scope)

根据参数：

**单个故事 (Single story)**：直接读取故事文件。提取：故事类型 (Story Type)、测试证据 (Test Evidence) 部分、故事别名 (story slug)、系统名称。

**冲刺 (Sprint)**：读取 `production/sprints/` 中最近修改的文件。从冲刺计划中提取故事文件路径列表。读取每个故事文件。

**系统 (System)**：使用 Glob 搜索 `production/epics/[system-name]/story-*.md`。逐一读取。

对每个故事，收集：
- `Type:` 字段（逻辑 Logic / 集成 Integration / 视觉/感受 Visual/Feel / UI / 配置/数据 Config/Data）
- `## Test Evidence` 部分 —— 声明的预期测试文件路径或证据文档
- 故事别名（来自文件名）
- 系统名称（来自目录路径）
- 验收标准列表 (Acceptance Criteria list)（所有复选框项）

---

## 3. 定位证据文件 (Locate Evidence Files)

对每个故事，找到证据：

**逻辑故事 (Logic stories)**：使用 Glob 搜索 `tests/unit/[system]/[story-slug]_test.*`
  - 如果未找到，也尝试：在 `tests/unit/[system]/` 中使用 Grep 搜索包含故事别名的文件

**集成故事 (Integration stories)**：使用 Glob 搜索 `tests/integration/[system]/[story-slug]_test.*`
  - 同时检查 `production/session-logs/` 中提及该故事的试玩测试记录

**视觉/感受和 UI 故事 (Visual/Feel and UI stories)**：使用 Glob 搜索 `production/qa/evidence/[story-slug]-evidence.*`

**配置/数据故事 (Config/Data stories)**：使用 Glob 搜索 `production/qa/smoke-*.md`（任何冒烟检查报告）

记录每个故事找到（路径）或未找到（缺口）的内容。

---

## 4. 审查自动化测试质量 (Review Automated Test Quality)（逻辑 / 集成）

对每个找到的测试文件，读取并评估：

### 断言覆盖率 (Assertion coverage)

计算不同断言的数量（包含 assert、expect、check、verify 或引擎特定断言模式的行）。低断言数量是一个质量信号 —— 每个测试函数仅做 1 个断言的测试可能无法覆盖预期行为的范围。

阈值：
- **每个测试函数 3+ 个断言** → 正常
- **每个测试函数 1-2 个断言** → 标注为可能偏少
- **0 个断言**（测试存在但无断言）→ 标记为阻塞 (BLOCKING) —— 测试空洞地通过，不证明任何内容

### 边缘情况覆盖率 (Edge case coverage)

对故事中每个包含数字、阈值或"当 X 发生时"条件的验收标准：检查是否有测试函数名称或测试体引用了该特定情况。

启发式方法：
- 在测试文件中 Grep 搜索"zero"、"max"、"null"、"empty"、"min"、"invalid"、"boundary"、"edge" —— 存在任何一个都是正面信号
- 如果故事具有带特定边界的"公式 (Formulas)"部分：检查测试是否在最小/最大值处进行测试

### 命名质量 (Naming quality)

测试函数名称应描述：场景 + 预期结果。
模式：`test_[scenario]_[expected_outcome]`

将通用命名的函数（`test_1`、`test_run`、`testBasic`）标记为 **命名问题** —— 它们使失败诊断更加困难。

### 公式可追溯性 (Formula traceability)

对于游戏设计文档 (Game Design Document, GDD) 包含"公式 (Formulas)"部分的逻辑故事：检查测试文件是否包含至少一个测试，其名称或注释引用了公式名称或公式值。一个测试虽执行了公式但未提及公式名称，在公式变更时更难维护。

---

## 5. 审查手动证据质量 (Review Manual Evidence Quality)（视觉/感受 / UI）

对每个找到的证据文档，读取并评估：

### 标准关联性 (Criterion linkage)

证据文档应引用故事中的每个验收标准。检查：证据文档是否包含每个标准（或清晰的转述）？缺少标准意味着某个标准从未被验证。

### 签核完整性 (Sign-off completeness)

检查三个签核行（或等效字段）：
- 开发者签核 (Developer sign-off)
- 设计师 / 美术主管签核（针对视觉/感受）
- 质量保证主管签核 (QA lead sign-off)

如果有任何缺失或空白：标记为不完整 (INCOMPLETE) —— 没有所有必需的签核，故事不能完全关闭。

### 截图 / 素材完整性 (Screenshot / Artefact Completeness)

对于视觉/感受故事：检查证据文档中是否引用了截图文件路径。如果已引用，使用 Glob 搜索确认它们存在。

对于 UI 故事：检查是否包含操作演练顺序（逐步交互日志）。

### 日期覆盖范围 (Date coverage)

证据文档应有日期。如果日期早于故事的最后一次重大变更（启发式方法：与冲刺计划中的冲刺开始日期比较），标记为可能过时 (POTENTIALLY STALE) —— 证据可能未覆盖最终实现。

---

## 6. 构建审查报告 (Build the Review Report)

对每个故事，分配一个裁定：

| 裁定 (Verdict) | 含义 |
|---------|---------|
| **充分 (ADEQUATE)** | 测试/证据存在，通过质量检查，所有标准均已覆盖 |
| **不完整 (INCOMPLETE)** | 测试/证据存在，但有质量差距（断言薄弱、缺少签核） |
| **缺失 (MISSING)** | 对需要测试/证据的故事类型，未找到测试或证据 |

整个冲刺/系统的最终裁定是存在的最差故事裁定。

```markdown
## 测试证据审查 (Test Evidence Review)

> **日期 (Date)**: [date]
> **范围 (Scope)**: [单个故事路径 | 冲刺 [N] | [系统名称]]
> **审查的故事数 (Stories reviewed)**: [N]
> **总体裁定 (Overall verdict)**: 充分 (ADEQUATE) / 不完整 (INCOMPLETE) / 缺失 (MISSING)

---

### 逐故事结果 (Story-by-Story Results)

#### [故事标题] — [类型] — [充分/不完整/缺失]

**测试/证据路径**: `[path]` (已找到) / (未找到)

**自动化测试质量** *(仅逻辑/集成)*:
- 断言覆盖率: [平均每个函数 N] — [充分 / 薄弱 / 无]
- 边缘情况: [已覆盖 / 部分覆盖 / 未找到]
- 命名: [一致 / 标记了 [N] 个通用名称]
- 公式可追溯性: [是 / 否 — 公式名称未在测试中引用]

**手动证据质量** *(仅视觉/感受/UI)*:
- 标准关联性: [引用了 N/M 个标准]
- 签核: [开发者 ✓ | 设计师 ✗ | 质量保证主管 ✗]
- 素材: [截图存在 / 缺失 / 不适用]
- 新鲜度: [日期为 [date] — 当前 / 可能过时]

**问题 (Issues)**:
- 阻塞 (BLOCKING): [描述] *(阻止 story-done 完成)*
- 建议 (ADVISORY): [描述] *(应在发布前修复)*

---

### 总结 (Summary)

| 故事 | 类型 | 裁定 | 问题 |
|-------|------|---------|--------|
| [标题] | 逻辑 (Logic) | 充分 (ADEQUATE) | 无 |
| [标题] | 集成 (Integration) | 不完整 (INCOMPLETE) | 断言薄弱（平均 1.2/函数） |
| [标题] | 视觉/感受 (Visual/Feel) | 不完整 (INCOMPLETE) | 缺少质量保证主管签核 |
| [标题] | 逻辑 (Logic) | 缺失 (MISSING) | 未找到测试文件 |

**阻塞项 (BLOCKING items)**（必须在故事关闭前解决）：[N]
**建议项 (ADVISORY items)**（应在发布前处理）：[N]
```

---

## 7. 写入输出（可选）(Write Output (Optional))

在对话中呈现报告。

询问："我可以将此测试证据审查写入 `production/qa/evidence-review-[date].md` 吗？"

此为可选项 —— 报告本身即可独立使用。仅当用户希望保留持久记录时才写入。

报告之后：

- 对于阻塞项："这些问题必须在 `/story-done` 能将故事标记为完成之前解决。您希望现在处理其中任何一个吗？"
- 对于弱断言："考虑运行 `/test-helpers [system]` 以查看常见情况的脚手架断言模式。"
- 对于缺失签核："需 [角色] 进行手动签核。将 `[evidence-path]` 分享给他们以完成签核。"

裁定：**完成 (COMPLETE)** —— 证据审查已完成。如果发现了阻塞项，则使用关注 (CONCERNS)。

---

## 协作协议 (Collaborative Protocol)

- **报告质量问题，而非修复它们** —— 本技能负责读取和评估；它不修改测试文件或证据文档
- **充分意味着足以发布，而非完美无缺** —— 避免对运行良好且足够全面以提供信心的测试吹毛求疵
- **阻塞 vs. 建议的区别很重要** —— 仅当缺口确实使故事标准未被验证时才标记为阻塞
- **写入前询问** —— 报告文件是可选的；始终在写入前确认
