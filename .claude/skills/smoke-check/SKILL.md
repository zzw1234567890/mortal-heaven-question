---
name: smoke-check
description: "在移交QA之前运行关键路径冒烟测试关卡。执行自动化测试套件，验证核心功能，并生成PASS/FAIL报告。在冲刺故事实现后、手动QA开始前运行。冒烟检查失败意味着构建尚未准备好交给QA。"
argument-hint: "[sprint | quick | --platform pc|console|mobile|all]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write, AskUserQuestion

---


# 冒烟检查 (Smoke Check)

此技能是"实现完成"和"准备 QA 移交"之间的关卡。它运行自动化测试套件、检查测试覆盖率缺口、与开发者批量验证关键路径，并生成 PASS/FAIL 报告。

规则很简单：**未通过冒烟检查的构建不会进入 QA。** 将损坏的构建交给 QA 会浪费他们的时间并打击团队士气。

**输出：** `production/qa/smoke-[date].md`

---

## 解析参数 (Parse Arguments)

参数可以组合使用：`/smoke-check sprint --platform console`

**基本模式**（第一个参数，默认为：`sprint`）：
- `sprint` — 针对当前冲刺 (sprint) 的故事进行完整冒烟检查
- `quick` — 跳过覆盖率扫描（阶段 3）和批处理 3；用于快速重新检查

**平台标志**（`--platform`，默认为：无）：
- `--platform pc` — 添加 PC 特定检查（键盘、鼠标、窗口模式）
- `--platform console` — 添加主机特定检查（手柄、TV 安全区域、
  平台认证要求）
- `--platform mobile` — 添加移动端特定检查（触屏、竖屏/横屏、
  电池/热行为）
- `--platform all` — 添加所有平台变体；输出按平台裁定的表格

如果提供了 `--platform`，阶段 4 会添加平台特定批处理，
阶段 5 会输出按平台裁定的表格以及总体裁定。

---

## 阶段 1：检测测试设置 (Detect Test Setup)

在运行任何内容之前，了解环境：

1. **测试框架检查**：验证 `tests/` 目录是否存在。
   如果不存在："在 `tests/` 未找到测试目录。运行 `/test-setup`
   以搭建测试基础设施，如果测试在其他地方则手动创建目录。"然后停止。

2. **CI 检查**：检查 `.github/workflows/` 是否包含引用测试的工作流文件。
   在报告中注明 CI 是否已配置。

3. **引擎检测**：读取 `.claude/docs/technical-preferences.md` 并
   提取 `Engine:` 值。存储此值以在阶段 2 中选择测试命令。

4. **冒烟测试列表**：检查 `production/qa/smoke-tests.md` 或
   `tests/smoke/` 是否存在。如果找到冒烟测试列表，加载它以在
   阶段 4 中使用。如果两者都不存在，冒烟测试将从当前 QA
   计划中选取（阶段 4 回退）。

5. **QA 计划检查**：glob 搜索 `production/qa/qa-plan-*.md` 并取最近
   修改的文件。如果找到，记录其路径 —— 它将在
   阶段 3 和阶段 4 中使用。如果未找到，记录："未找到 QA 计划。运行
   `/qa-plan sprint` 以获得最佳冒烟检查效果。"

在继续之前报告发现："环境：[engine]。测试目录：
[found / not found]。CI 已配置：[yes / no]。QA 计划：[path / not found]。"

---

## 阶段 2：运行自动化测试 (Run Automated Tests)

尝试通过 Bash 运行测试套件。根据阶段 1 检测到的引擎选择命令：

**Godot 4：**
```bash
godot --headless --script tests/gdunit4_runner.gd 2>&1
```
如果 GDUnit4 运行器脚本在该路径不存在，尝试：
```bash
godot --headless -s addons/gdunit4/GdUnitRunner.gd 2>&1
```
如果两个路径都不存在，记录："未找到 GDUnit4 运行器 —— 请确认您的测试框架的运行器路径。"

**Unity：**
Unity 测试需要编辑器，在大多数环境中无法通过 shell 无头运行。检查最近的测试结果工件：
```bash
# List most recent test results (bash) — on Windows PowerShell use the fallback below
ls -t test-results/ 2>/dev/null | head -5 \
  || powershell -Command "Get-ChildItem test-results/ -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5 -ExpandProperty Name"
```
如果存在测试结果文件（XML 或 JSON），读取最近的文件并解析 PASS/FAIL 计数。如果没有工件："Unity 测试必须从编辑器或 CI 管道运行。请在继续之前手动确认测试状态。"

**Unreal Engine：**
```bash
# List most recent Unreal automation logs (bash) — on Windows PowerShell use the fallback below
ls -t Saved/Logs/ 2>/dev/null | grep -i "test\|automation" | head -5 \
  || powershell -Command "Get-ChildItem Saved/Logs/ -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'test|automation' } | Sort-Object LastWriteTime -Descending | Select-Object -First 5 -ExpandProperty Name"
```
如果未找到匹配的日志："UE 自动化测试必须通过 Session Frontend 或 CI 管道运行。请手动确认测试状态。"

**未知引擎 / 未配置：**
"引擎未在 `.claude/docs/technical-preferences.md` 中配置。运行 `/setup-engine` 以指定引擎，然后重新运行 `/smoke-check`。"

**如果测试运行器在此环境中不可用**（引擎二进制不在 PATH 上、运行器脚本未找到等），清晰报告：

"无法执行自动化测试 —— 引擎二进制未在 PATH 上找到。状态将记录为 NOT RUN。从您的本地 IDE 或 CI 管道确认测试结果。未经确认的 NOT RUN 被视为 PASS WITH WARNINGS，而非 FAIL —— 开发者必须手动确认结果。"

不要将 NOT RUN 视为自动 FAIL。将其记录为警告。开发者在阶段 4 中的手动确认可以解决它。

解析运行器输出并提取：
- 运行的总测试数
- 通过数量
- 失败数量
- 任何失败测试的名称（最多 10 个；如果更多，记录数量）
- 运行器本身的任何崩溃或错误输出

---

## 阶段 3：检查测试覆盖率 (Check Test Coverage)

按优先级顺序从以下来源绘制故事列表：
1. 阶段 1 中发现的 QA 计划（其测试摘要表格列出了每个故事的预期测试文件路径）
2. `production/sprints/` 中的当前冲刺计划（最近修改的文件）
3. 如果传递了 `quick` 参数，完全跳过此阶段并记录：
   "覆盖率扫描已跳过 —— 运行 `/smoke-check sprint` 以获得完整的覆盖率分析。"

对于范围内的每个故事：

1. 从故事的文件路径中提取系统短名称
   （例如，`production/epics/combat/story-001.md` → `combat`）
2. Glob 搜索 `tests/unit/[system]/` 和 `tests/integration/[system]/` 以查找其名称包含故事短名称或密切相关术语的文件
3. 检查故事文件本身是否有 `Test file:` 标题字段或"Test Evidence"部分

为每个故事分配一个覆盖率状态：

| Status | Meaning |
|--------|---------|
| **COVERED** | 找到了与此故事系统和范围匹配的测试文件 |
| **MANUAL** | 故事类型为 Visual/Feel 或 UI；找到了测试证据文档 |
| **MISSING** | Logic 或 Integration 故事没有匹配的测试文件 |
| **EXPECTED** | Config/Data 故事 —— 不需要测试文件；抽查就足够了 |
| **UNKNOWN** | 故事文件缺失或无法读取 |

MISSING 条目是建议性缺口。它们不会导致 FAIL 裁定，但必须在报告中醒目显示，并且必须在 `/story-done` 能完全关闭这些故事之前解决。

---

## 阶段 4：运行手动冒烟检查 (Run Manual Smoke Checks)

按优先级顺序从以下来源绘制冒烟检查清单：
1. QA 计划的"冒烟测试范围"部分（如果阶段 1 中找到了 QA 计划）
2. `production/qa/smoke-tests.md`（如果存在）
3. `tests/smoke/` 目录内容（如果存在）
4. 下面的标准回退列表（仅在以上各项都不存在时使用）

将批处理 2 和 3 调整为从冲刺或 QA 计划中识别出的实际系统。将括号中的占位符替换为当前冲刺故事的真正机制名称。

使用 `AskUserQuestion` 进行批量验证。最多保持 3 次调用。

**批处理 1 —— 核心稳定性（始终运行）：**
```
question: "Core stability — select any items that FAILED (leave all unselected if everything passed):"
multiSelect: true
options:
  - "Game does not launch or crashes before reaching the main menu"
  - "New game / session fails to start"
  - "Main menu does not respond to inputs"
  - "Crash or hang observed during basic navigation"
```

对于任何选中的项，在生成报告前要求用户简要描述失败情况。

**批处理 2 —— 冲刺变更和回归（始终运行）：**
```
question: "Sprint changes and regression — select any items that FAILED (leave all unselected if everything passed):"
multiSelect: true
options:
  - "[Primary mechanic this sprint] — FAILED"
  - "[Second notable change this sprint, if any] — FAILED"
  - "Regression in a previous sprint's feature — FAILED"
  - "Other unexpected breakage observed — FAILED"
```

对于任何选中的项，在生成报告前要求用户简要描述损坏情况。

**批处理 3 —— 数据完整性和性能（除非 `quick` 参数，否则运行）：**
```
question: "Data integrity and performance — select any items that FAILED or were skipped (leave all unselected if everything passed):"
multiSelect: true
options:
  - "Save / load — FAILED (data loss or corruption observed)"
  - "Save / load — N/A (save system not yet implemented)"
  - "Frame rate drops or hitches observed — FAILED"
  - "Performance not checked this session"
```

对于任何选中的 FAILED 项，在生成报告前要求用户描述损坏情况。

记录每个回答原样，以用于阶段 5 报告。

**平台批处理** *（仅在提供了 `--platform` 参数时运行）*：

**PC 平台**（`--platform pc` 或 `--platform all`）：
```
question: "PC Platform — select any items that FAILED (leave all unselected if everything passed):"
multiSelect: true
options:
  - "Keyboard controls — FAILED (describe issue after)"
  - "Mouse input or cursor visibility — FAILED (describe issue after)"
  - "Windowed / fullscreen mode — FAILED (describe issue after)"
  - "Resolution change — FAILED (describe issue after)"
```

对于任何选中的项，在生成报告前要求用户简要描述失败情况。

**主机平台**（`--platform console` 或 `--platform all`）：
```
question: "Console Platform — select any items that FAILED (leave all unselected if everything passed):"
multiSelect: true
options:
  - "Gamepad input — FAILED (describe issue after)"
  - "UI outside TV safe zone / text clipped — FAILED (describe what is clipped after)"
  - "Keyboard/mouse fallback shown to gamepad user — FAILED (describe after)"
  - "Cold start (no prior save) — FAILED (describe issue after)"
```

对于任何选中的项，在生成报告前要求用户简要描述失败情况。

**移动端平台**（`--platform mobile` 或 `--platform all`）：
```
question: "Mobile Platform — select any items that FAILED (leave all unselected if everything passed):"
multiSelect: true
options:
  - "Touch controls — FAILED (describe issue after)"
  - "Orientation change (portrait ↔ landscape) — FAILED (describe what breaks after)"
  - "Background / foreground transition (home button) — FAILED (describe issue after)"
  - "Performance / thermal throttling on target device — FAILED (describe after)"
```

对于任何选中的项，在生成报告前要求用户简要描述失败情况。

---

## 阶段 5：生成报告 (Generate Report)

组装完整的冒烟检查报告：

````markdown
## Smoke Check Report
**Date**: [date]
**Sprint**: [sprint name / number, or "Not identified"]
**Engine**: [engine]
**QA Plan**: [path, or "Not found — run /qa-plan first"]
**Argument**: [sprint | quick | blank]

---

### Automated Tests

**Status**: [PASS ([N] tests, [N] passing) | FAIL ([N] failures) |
NOT RUN ([reason])]

[If FAIL, list failing tests:]
- `[test name]` — [brief failure description from runner output]

[If NOT RUN:]
"Manual confirmation required: did tests pass in your local IDE or CI? This
will determine whether the automated test row contributes to a FAIL verdict."

---

### Test Coverage

| Story | Type | Test File | Coverage Status |
|-------|------|-----------|----------------|
| [title] | Logic | `tests/unit/[system]/[slug]_test.[ext]` | COVERED |
| [title] | Visual/Feel | `tests/evidence/[slug]-screenshots.md` | MANUAL |
| [title] | Logic | — | MISSING ⚠ |
| [title] | Config/Data | — | EXPECTED |

**Summary**: [N] covered, [N] manual, [N] missing, [N] expected.

---

### Manual Smoke Checks

- [x] Game launches without crash — PASS
- [x] New game starts — PASS
- [x] [Core mechanic] — PASS
- [ ] [Other check] — FAIL: [user's description]
- [x] Save / load — PASS
- [-] Performance — not checked this session

---

### Missing Test Evidence

Stories that must have test evidence before they can be marked COMPLETE via
`/story-done`:

- **[story title]** (`[path]`) — Logic story has no test file.
  Expected location: `tests/unit/[system]/[story-slug]_test.[ext]`

[If none:] "All Logic and Integration stories have test coverage."

---

### Platform-Specific Results *(only if `--platform` was provided)*

| Platform | Checks Run | Passed | Failed | Platform Verdict |
|----------|-----------|--------|--------|-----------------|
| PC | [N] | [N] | [N] | PASS / FAIL |
| Console | [N] | [N] | [N] | PASS / FAIL |
| Mobile | [N] | [N] | [N] | PASS / FAIL |

**Platform notes**: [any platform-specific observations not captured in pass/fail]

Any platform with one or more FAIL checks contributes to the overall FAIL verdict.

---

### Verdict: [PASS | PASS WITH WARNINGS | FAIL]

[Verdict rules — first matching rule wins:]

**FAIL** if ANY of:
- Automated test suite ran and reported one or more test failures
- Any Batch 1 (core stability) check returned FAIL
- Any Batch 2 (primary sprint mechanic or regression check) returned FAIL

**PASS WITH WARNINGS** if ALL of:
- Automated tests PASS or NOT RUN (developer has not yet confirmed)
- All Batch 1 and Batch 2 smoke checks PASS
- One or more Logic/Integration stories have MISSING test evidence

**PASS** if ALL of:
- Automated tests PASS
- All smoke checks in all batches PASS or N/A
- No MISSING test evidence entries
````

---

## 阶段 6：写入和关卡 (Write and Gate)

在对话中呈现完整报告，然后询问：

"我可以将此冒烟检查报告写入 `production/qa/smoke-[date].md` 吗？"

仅在批准后写入。

写入后，交付关卡裁定：

**如果裁定为 FAIL：**

"冒烟检查失败。在解决以下失败之前不要移交给 QA：

[列出每个失败的自动化测试或冒烟检查，附带一行描述]

修复失败并在 QA 移交前重新运行 `/smoke-check` 以重新通关。"

**如果裁定为 PASS WITH WARNINGS：**

"冒烟检查通过但有警告。构建已准备好进行手动 QA。

在受影响的故事上运行 `/story-done` 之前需解决的建议性事项：
[列出 MISSING 测试证据条目]

QA 移交：将 `production/qa/qa-plan-[sprint].md` 共享给 qa-tester 智能体以开始手动验证。"

**如果裁定为 PASS：**

"冒烟检查干净通过。构建已准备好进行手动 QA。

QA 移交：将 `production/qa/qa-plan-[sprint].md` 共享给 qa-tester 智能体以开始手动验证。"

---

## 协作协议 (Collaborative Protocol)

- **绝不将 NOT RUN 视为自动 FAIL** — 将其记录为 NOT RUN，让开发者手动确认状态。未经确认的 NOT RUN 会导致 PASS WITH WARNINGS，而非 FAIL。
- **绝不自修复失败** — 报告它们并说明必须解决什么。不要尝试编辑源代码或测试文件。
- **PASS WITH WARNINGS 不阻止 QA 移交** — 它记录建议性缺口，供 `/story-done` 跟进。
- **`quick` 参数**跳过阶段 3（覆盖率扫描）和阶段 4 批处理 3。在修复特定失败后用于快速重新检查。
- 对所有手动冒烟检查验证使用 `AskUserQuestion`。
- **未经询问绝不写入报告** — 阶段 6 要求在创建任何文件之前获得明确批准。
