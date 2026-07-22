---
name: test-flakiness
description: "通过读取 CI 运行日志或测试结果历史来检测非确定性（不稳定）测试。聚合每个测试的通过率，识别间歇性失败，建议隔离或修复，并维护不稳定测试注册表。最佳在打磨阶段或多次 CI 运行后运行。"
argument-hint: "[ci-log-path | scan | registry]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash

---


# 测试不稳定性检测 (Test Flakiness Detection)

不稳定测试 (flaky test) 是指有时通过有时失败，且没有任何代码变更的测试。在某些方面，不稳定测试比没有测试更糟糕——它们训练团队忽视红色 CI 运行，掩盖了真正的失败。本技能识别它们，解释可能的原因，并建议对每个测试是隔离还是修复。

**输出：** 更新的 `tests/regression-suite.md` 隔离部分 + 可选的 `production/qa/flakiness-report-[date].md`

**运行时机：**
- 打磨阶段 (Polish phase)（测试已运行多次；统计信号可靠）
- 当开发者开始将 CI 失败归结为"可能是不稳定"时
- 在 `/regression-suite` 识别出需要诊断的已隔离测试之后

---

## 1. 解析参数 (Parse Arguments)

**模式：**
- `/test-flakiness [ci-log-path]` — 分析特定的 CI 运行日志文件
- `/test-flakiness scan` — 扫描 `.github/` 或标准日志输出目录中所有可用的 CI 日志
- `/test-flakiness registry` — 读取现有的 regression-suite.md 隔离部分，为已知的不稳定测试提供修复指导
- 无参数 — 自动检测：如果可以访问 CI 日志则运行 `scan`，否则运行 `registry`

---

## 2. 定位 CI 日志数据 (Locate CI Log Data)

### 选项 A — GitHub Actions（推荐）

检查测试结果制品：
```bash
ls -t .github/ 2>/dev/null
ls -t test-results/ 2>/dev/null
```

对于 Godot 项目：GdUnit4 输出与 JUnit 格式兼容的 XML 结果。检查 `test-results/` 中的 `.xml` 文件。

对于 Unity 项目：game-ci 测试运行器默认将 NUnit XML 输出到 `test-results/`。

对于 Unreal 项目：自动化日志输出到 `Saved/Logs/`。使用 Grep 搜索 `Result: Success` 和 `Result: Fail` 模式。

### 选项 B — 本地日志文件

如果提供了路径参数，直接读取该文件。

### 选项 C — 无可用日志数据

如果未找到日志：
> "未找到 CI 日志数据。为了检测不稳定测试，本技能需要多次运行的测试结果历史。选项：
> 1. 运行测试套件至少 3 次并收集输出日志
> 2. 检查 CI 流水线输出并将日志保存到 `test-results/`
> 3. 运行 `/test-flakiness registry` 审查已标记为不稳定的测试（在 `tests/regression-suite.md` 中）"

停止并询问用户选择哪个选项。

---

## 3. 解析测试结果 (Parse Test Results)

对于每个找到的 CI 日志或结果文件，解析：

**JUnit XML 格式**（GdUnit4 / Unity）：
- 使用 Grep 搜索 `<testcase name=` 获取测试名称
- 使用 Grep 搜索 `<failure` 或 `<error` 识别失败
- 解析 `classname` 和 `name` 属性以获取完整测试标识符

**纯文本日志**：
- 使用 Grep 搜索通过/失败模式：
  - Godot：测试名称旁的 `PASSED` / `FAILED`
  - Unreal：`Result: Success` / `Result: Fail`
  - Unity：`Test passed` / `Test failed`

构建一个表格：`test_id → [run1_result, run2_result, run3_result, ...]`

---

## 4. 识别不稳定测试 (Identify Flaky Tests)

如果一个测试在结果历史中同时出现 PASS 和 FAIL 结果，且运行之间没有代码变更，则它是**不稳定 (flaky)** 的。

不稳定性阈值：
- **高不稳定性 (High flakiness)**：在 >25% 的运行中失败——立即隔离 (quarantine)
- **中等不稳定性 (Moderate flakiness)**：在 5–25% 的运行中失败——调查并尽快修复
- **低/疑似不稳定性 (Low/suspected flakiness)**：在 1–5% 的运行中失败——监控；可能是真正罕见的失败

对于每个不稳定测试，分类可能的原因：

### 原因分类

| 原因 | 症状 | 修复方向 |
|-------|----------|---------------|
| **时序 / 异步** | 在等待信号或定时器后失败；通过率与系统负载相关 | 添加显式的 await/同步；避免基于时间的延迟 |
| **顺序依赖** | 在特定其他测试之后运行失败；单独运行通过 | 添加适当的 setup/teardown；确保测试隔离 |
| **随机种子** | 间歇性失败无规律；涉及随机数生成 | 传递显式种子；测试中不使用 `randf()` |
| **资源泄漏** | 在测试运行后期更频繁地失败 | 修复 teardown 中的清理；检查孤立节点（Godot）或对象释放（Unity） |
| **外部状态** | 当文件、场景或全局变量来自先前测试时失败 | 将测试与文件系统隔离；使用内存中的模拟 (mock) |
| **浮点数** | 在类似 `== 0.5` 的比较上失败 | 使用 epsilon 比较（`is_equal_approx`、`Assert.AreApproximately`） |
| **场景/预制体加载竞态** | 场景尚未准备好时失败 | 在实例化后等待一帧；使用 `await get_tree().process_frame` |

使用 Grep 检查测试文件中的定时调用、randf、全局状态访问或浮点数相等比较，以缩小原因范围。

---

## 5. 建议行动 (Recommend Action)

对于每个不稳定测试：

**隔离（高不稳定性）：**
> "立即隔离此测试。通过添加 `@pytest.mark.skip` / `[Ignore]` / `GdUnitSkip` 注解在 CI 中禁用它。在 `tests/regression-suite.md` 的隔离部分中记录它。该测试现在仅为选择启用。在移除隔离前修复根本原因。"

**调查并尽快修复（中等不稳定性）：**
> "此测试间歇性不可靠。根本原因似乎是 [cause]。建议修复：[基于原因分类的具体修复]。暂时不要隔离——直接修复测试。"

**监控（低/疑似）：**
> "此测试显示疑似不稳定性。在隔离之前收集更多运行数据。在回归套件中将其标记为 'suspected'（疑似）。"

---

## 6. 生成报告 (Generate Reports)

### 对话内摘要

```
## Flakiness Detection Results

**Runs analysed**: [N]
**Tests tracked**: [N]

### Flaky Tests Found

| Test | System | Fail Rate | Likely Cause | Recommendation |
|------|--------|-----------|--------------|----------------|
| [test_name] | [system] | [N]% | Timing | Quarantine + fix async |
| [test_name] | [system] | [N]% | Float comparison | Fix: use epsilon compare |
| [test_name] | [system] | [N]% | Order dependency | Investigate teardown |

### Clean Tests (no flakiness detected)

[N] tests ran across [N] runs with consistent results — no flakiness detected.

### Data Limitations

[Note if fewer than 5 runs were available — fewer runs = less statistical confidence]
```

---

## 7. 更新回归套件 + 可选报告文件 (Update Regression Suite + Optional Report File)

询问："我可以更新 `tests/regression-suite.md` 的隔离部分，加入发现的不稳定测试吗？"

如果同意：使用 `Edit` 将条目追加到隔离测试表格 (Quarantined Tests table)。绝不要移除现有的隔离条目——只添加新条目。

询问（分开问）："我可以将完整的不稳定性报告写入 `production/qa/flakiness-report-[date].md` 吗？"

完整报告包含每个测试的分析，附带原因细节和引擎特定的修复代码片段。

写入后：

- 对于每个隔离的测试："添加引擎特定的跳过注解以在 CI 中禁用此测试。在根本原因修复后重新启用。"
- 对于可修复的测试："[test] 的修复很直接——将第 [N] 行的相等比较改为使用 `is_equal_approx`。"
- 总结："所有隔离注解应用后，CI 应保持绿色。在发布关卡前，安排对 [N] 个隔离测试的修复工作。"

---

## 协作协议 (Collaborative Protocol)

- **绝不要删除测试文件**——隔离意味着注解 + 列出，而非删除
- **统计置信度很重要**——在少于 3 次运行的情况下，将发现标记为"suspected"（疑似）而非"confirmed"（确认）；询问是否有更多运行数据可用
- **修复始终是目标**——隔离是临时的；即使在建议隔离时也要指明修复方向
- **写入前询问**——回归套件更新和报告文件都需要明确批准。写入时：判定：**COMPLETE（完成）**——不稳定性报告已写入。拒绝时：判定：**BLOCKED（阻塞）**——用户拒绝了写入。
- **CI 中的不稳定性是团队问题**——清晰地列出测试和建议的行动；不要在没有让团队知晓的情况下静默隔离
