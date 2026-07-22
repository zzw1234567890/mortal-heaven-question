---
name: story-done
description: "故事完成审查。读取故事文件，对照实现验证每个验收标准，检查GDD/ADR偏差，提示代码审查，将故事状态更新为完成，并从冲刺中呈现下一个就绪的故事。"
argument-hint: "[story-file-path] [--review full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion, Task

---


# 故事完成 (Story Done)

此技能在设计实现之间建立闭环。在实现任何故事的末尾运行它。它确保在每个故事被标记完成之前，每个验收标准都经过验证，GDD 和 ADR 的偏差被明确记录而非静默引入，代码审查被提示而非遗忘，且故事文件反映实际的完成状态。

**输出：** 更新后的故事文件（Status: Complete）+ 显示下一个故事。

---

## 阶段 1：找到故事

确定审查模式（一次确定，存储用于本轮所有关卡调用）：
1. 如果传入了 `--review [full|lean|solo]` → 使用该值
2. 否则读取 `production/review-mode.txt` → 使用该值
3. 否则 → 默认使用 `lean`

完整的检查模式参见 `.claude/docs/director-gates.md`。

**如果提供了文件路径**（例如 `/story-done production/epics/core/story-damage-calculator.md`）：
直接读取该文件。

**如果未提供参数：**

1. 检查 `production/session-state/active.md` 中当前活跃的故事。
2. 如果未找到，读取 `production/sprints/` 中最近的文件，查找标记为 IN PROGRESS 的故事。
3. 如果找到多个进行中的故事，使用 `AskUserQuestion`：
   - "我们正在完成哪个故事？"
   - 选项：列出进行中的故事文件名。
4. 如果找不到任何故事，请用户提供路径。

---

## 阶段 2：读取故事

完整读取故事文件。提取并在上下文中保留：

- **故事名称和 ID**
- **GDD 需求 TR-ID** 引用（例如 `TR-combat-001`）
- **故事标题中嵌入的清单版本**（例如 `2026-03-10`）
- **ADR 引用**
- **验收标准** — 完整列表（每个复选框项目）
- **实现文件** — "files to create/modify"下列出的文件
- **故事类型** — 故事标题中的 `Type:` 字段（Logic / Integration / Visual/Feel / UI / Config/Data）
- **引擎注意事项** — 任何记录在案的引擎特定约束
- **完成定义** — 如果存在，故事级别的 DoD
- **预估与实际范围** — 如果记录了预估

同时读取：
- `docs/architecture/tr-registry.yaml` — 在注册表中查找每个 TR-ID。
  读取注册表条目中的*当前* `requirement` 文本。这是 GDD 所要求内容的真理来源——不要使用故事中可能行内引用的任何需求文本（可能已过时）。
- 引用的 GDD 章节——仅验收标准和关键规则，而非完整文档。用此交叉检查注册表文本是否仍然准确。
- 引用的 ADR——仅决策和后果部分。
- `docs/architecture/control-manifest.md` 头部——提取当前的 `Manifest Version:` 日期（用于阶段 4 的过期检查）。

---

## 阶段 3：验证验收标准

对于故事中的每个验收标准，使用三种方法之一尝试验证：

### 自动验证（无需询问运行）

- **文件存在性检查**：使用 `Glob` 查找故事声称会创建的文件。
- **测试通过检查**：如果提到了测试文件路径，通过 `Bash` 运行它。
- **无硬编码值检查**：使用 `Grep` 在游戏代码路径中查找应位于配置文件中的数值字面量。
- **无硬编码字符串检查**：使用 `Grep` 在 `src/` 中查找应位于本地化文件中的面向玩家的字符串。
- **依赖检查**：如果标准说"依赖于 X"，检查 X 是否存在。

### 手动验证需确认（使用 `AskUserQuestion`）

- 关于主观品质的标准（"感觉响应灵敏"、"动画播放正确"）
- 关于游戏行为的标准（"玩家在……时受到伤害"、"敌人对……做出响应"）
- 性能标准（"在 Xms 内完成"）——询问是否已分析或视为已通过

将最多 4 个手动验证问题批量放入单个 `AskUserQuestion` 调用：

```
question: "[标准] 是否通过？"
options: "是 — 通过", "否 — 失败", "尚未测试"
```

### 无法验证（标记但不阻塞）

- 需要完整游戏构建才能测试的标准（端到端游戏场景）
- 标记为：`DEFERRED — 需要试玩会话`

### 测试-标准可追溯性

在完成上述通过/失败/延迟检查后，将每个验收标准映射到覆盖它的测试：

对于故事中的每个验收标准：

1. 询问：是否存在直接验证此标准的测试——单元测试、集成测试或已确认的手动试玩测试？
   - **单元测试**：检查 `tests/unit/` 中是否有与标准主题匹配的测试文件或函数名（使用 `Glob` 和 `Grep`）
   - **集成测试**：类似地检查 `tests/integration/`
   - **手动确认**：如果标准通过上述 `AskUserQuestion` 以"是 — 通过"答案验证，则视为手动测试

2. 生成一个可追溯性表：

```
| 标准 | 测试 | 状态 |
|-----------|------|--------|
| AC-1: [标准文本] | tests/unit/test_foo.gd::test_bar | COVERED |
| AC-2: [标准文本] | 手动试玩确认 | COVERED |
| AC-3: [标准文本] | — | UNTESTED |
```

3. 应用这些升级规则：

   - 如果 **>50% 的标准是 UNTESTED**：升级为 **BLOCKING（阻塞）**——测试覆盖不足以确认故事实际上已完成。阶段 6 中的判定不能为 COMPLETE，直到覆盖有所改善。
   - 如果 **部分（≤50%）标准是 UNTESTED**：保持 **ADVISORY（建议）**——不阻塞完成，但必须出现在完成备注中。
   - 如果 **所有标准都是 COVERED**：无需操作，只需在报告中包含该表。

4. 对于任何 ADVISORY 级别的未测试标准，在阶段 7 的完成备注中添加：
   `"未测试的标准：[AC-N 列表]。建议在后续故事中添加测试。"`

### 测试证据要求

根据阶段 2 提取的故事类型，检查所需的证据：

| 故事类型 | 所需证据 | 关卡级别 |
|---|---|---|
| **Logic** | `tests/unit/[system]/` 中的自动化单元测试——必须存在且通过 | BLOCKING |
| **Integration** | `tests/integration/[system]/` 中的集成测试或试玩文档 | BLOCKING |
| **Visual/Feel** | `production/qa/evidence/` 中的截图 + 签收 | ADVISORY |
| **UI** | `production/qa/evidence/` 中的手动演练文档或交互测试 | ADVISORY |
| **Config/Data** | `production/qa/smoke-*.md` 中的冒烟检查通过报告 | ADVISORY |

**对于 Logic 故事**：首先读取故事的 **Test Evidence** 部分以提取确切的必需文件路径。使用 `Glob` 检查该确切路径。如果未找到确切路径，也广泛搜索 `tests/unit/[system]/`（文件可能位于稍有不同的位置）。如果两个位置都未找到测试文件：
- 标记为 **BLOCKING**："Logic 故事没有单元测试文件。故事要求在 `[Test-Evidence-section 中的确切路径]` 处存在。在将此故事标记为 Complete 之前创建并运行测试。"

**对于 Integration 故事**：读取故事的 **Test Evidence** 部分以获取确切的必需路径。首先使用 `Glob` 检查该确切路径，然后广泛搜索 `tests/integration/[system]/`，然后检查 `production/session-logs/` 中是否有引用此故事的试玩记录。
如果未找到任何内容：标记为 **BLOCKING**（与 Logic 相同的规则）。

**对于 Visual/Feel 和 UI 故事**：在 `production/qa/evidence/` 中 glob 搜索引用此故事的文件。
- 如果未找到：标记为 **ADVISORY**——"未找到手动测试证据。使用测试证据模板创建 `production/qa/evidence/[story-slug]-evidence.md`，并在最终关闭前获得签收。"
- 如果找到：读取文件并检查签收表中是否有未勾选的框。Grep 搜索匹配 `| .* | .* | .* | \[ \] Approved` 的行（带有未选中复选框的签收行）。如果发现任何未勾选的签收行：标记为 **ADVISORY**——"在 `[path]` 找到证据文件，但 [N] 个签收项仍待处理（在签收表中显示为 `[ ] Approved`）。在最终关闭前获得所需的签收。注意：对于独立开发者，所有角色可以由同一个人签收。"
- 如果所有签收行都显示 `[x] Approved` 或等效内容：注明"已找到证据文件且所有签收已完成——ADVISORY 通过。"

**对于 Config/Data 故事**：检查是否有任何 `production/qa/smoke-*.md` 文件。
如果无：标记为 **ADVISORY**——"未找到冒烟检查报告。运行 `/smoke-check`。"

**如果未设置故事类型**：标记为 **ADVISORY**——
"Story Type 未声明。在故事头部添加 `Type: [Logic|Integration|Visual/Feel|UI|Config/Data]` 以便在未来故事中启用测试证据关卡强制执行。"

任何 BLOCKING 级别的测试证据缺口阻止阶段 6 的 COMPLETE 判定。

---

## 阶段 4：检查偏差

将实现与设计文档进行比较。

自动运行这些检查：

1. **GDD 规则检查**：使用来自 `tr-registry.yaml` 的当前需求文本（通过故事的 TR-ID 查找），检查实现是否反映 GDD 现在实际要求的内容——而非故事编写时所要求的内容。使用 `Grep` 在实现文件中搜索当前 GDD 章节中提到的关键函数名、数据结构或类名。

2. **清单版本过期检查**：比较故事标题中嵌入的 `Manifest Version:` 日期与当前 `docs/architecture/control-manifest.md` 头部中的 `Manifest Version:` 日期。
   - 如果匹配 → 静默通过。
   - 如果故事的版本更旧 → 标记为 ADVISORY：
     `ADVISORY：Story was written against manifest v[story-date]; current manifest is v[current-date]. New rules may apply. Run /story-readiness to check.`
   - 如果 control-manifest.md 不存在 → 跳过此检查。

3. **ADR 约束检查**：读取引用的 ADR 的决策部分。检查 `docs/architecture/control-manifest.md` 中的禁止模式（如果存在）。使用 `Grep` 搜索 ADR 中明确禁止的模式。

4. **硬编码值检查**：使用 `Grep` 在实现文件中搜索游戏逻辑中应位于数据文件中的数值字面量。

5. **范围检查**：实现是否触及了故事所述范围之外的文件？（不在"files to create/modify"中的文件）

对于发现的每个偏差，进行分类：

- **BLOCKING（阻塞）**——实现与 GDD 或 ADR 相矛盾（在标记完成前必须修复）
- **ADVISORY（建议）**——实现与规范略有偏离，但功能上等价（记录，用户决定）
- **OUT OF SCOPE（超出范围）**——额外文件被触及，超出了故事所述的边界（标记以提醒——可能是合理的或范围蔓延）

---

## 阶段 4b：QA 覆盖关卡

**审查模式检查**——在启动 QL-TEST-COVERAGE 前应用：
- `solo` → 跳过。备注："QL-TEST-COVERAGE skipped — Solo mode." 进入阶段 5。
- `lean` → 跳过（不是 PHASE-GATE）。备注："QL-TEST-COVERAGE skipped — Lean mode." 进入阶段 5。
- `full` → 正常启动。

在阶段 4 的偏差检查完成后，通过 Task 使用关卡 **QL-TEST-COVERAGE**（`.claude/docs/director-gates.md`）生成 `qa-lead`。

传递：
- 故事文件路径和故事类型
- 阶段 3 中找到的测试文件路径（确切路径，或"未找到"）
- 故事的 `## QA Test Cases` 章节（故事创建时预写的测试规范）
- 故事的 `## Acceptance Criteria` 列表

QA-lead 审查测试是否实际覆盖了指定的内容——而不仅仅是文件是否存在。

应用判定：
- **ADEQUATE（充分）** → 进入阶段 5
- **GAPS（有缺口）** → 标记为 **ADVISORY**："QA lead 识别出覆盖缺口：[列表]。故事可以完成，但缺口应在后续故事中解决。"
- **INADEQUATE（不充分）** → 标记为 **BLOCKING**："QA lead：关键逻辑未经测试。在覆盖改善之前判定不能为 COMPLETE。具体缺口：[列表]。"

对于 Config/Data 故事跳过此阶段（无需代码测试）。

---

## 阶段 5：首席程序员代码审查关卡

**审查模式检查**——在启动 LP-CODE-REVIEW 前应用：
- `solo` → 跳过。备注："LP-CODE-REVIEW skipped — Solo mode." 进入阶段 6（完成报告）。
- `lean` → 在继续前使用 `AskUserQuestion`：
  - 提示："Code review 在 lean 模式下被跳过。你是否对实现的文件运行了 `/code-review`？"
  - 选项：
    - `是 — /code-review 已通过或已通过建议获批`
    - `否 — 跳过此故事的代码审查`
    - `否 — 我将在冲刺关闭前运行 /code-review`
  - 将答案记录在完成备注中（阶段 7）。所有三个选项均进入阶段 6。
- `full` → 正常启动。

通过 Task 使用关卡 **LP-CODE-REVIEW**（`.claude/docs/director-gates.md`）生成 `lead-programmer`。

传递：实现文件路径、故事文件路径、相关的 GDD 章节、管辖 ADR。

向用户展示判定结果。如果 CONCERNS（有疑虑），通过 `AskUserQuestion` 呈现：
- 选项：`修改标记的问题` / `接受并继续` / `进一步讨论`
如果 REJECT（拒绝），在问题解决前不进入阶段 6 判定。

如果故事尚无实现文件（判定在编码完成前运行），跳过此阶段并注明："LP-CODE-REVIEW skipped — 未找到实现文件。在实现完成后运行。"

---

## 阶段 6：呈现完成报告

在更新任何文件之前，呈现完整报告：

```markdown
## Story Done：[故事名称]
**故事**：[文件路径]
**日期**：[今天]

### 验收标准：[X/Y 通过]
- [x] [标准 1] — 自动验证（测试通过）
- [x] [标准 2] — 已确认
- [ ] [标准 3] — 失败：[原因]
- [?] [标准 4] — 已延迟：需要试玩测试

### 测试-标准可追溯性
| 标准 | 测试 | 状态 |
|-----------|------|--------|
| AC-1: [文本] | [测试文件::测试名称] | COVERED |
| AC-2: [文本] | 手动确认 | COVERED |
| AC-3: [文本] | — | UNTESTED |

### 测试证据
**故事类型**：[Logic | Integration | Visual/Feel | UI | Config/Data | 未声明]
**所需证据**：[单元测试文件 | 集成测试或试玩测试 | 截图 + 签收 | 演练文档 | 冒烟检查通过]
**发现的证据**：[YES — `[path]` | NO — BLOCKING | NO — ADVISORY]

### 偏差
[无] 或：
- BLOCKING：[描述] — [GDD/ADR 引用]
- ADVISORY：[描述] — 用户已接受 / 标记为技术债务

### 范围
[所有更改均在所述范围内] 或：
- 额外触及的文件：[列表] — [注明是否合理或范围蔓延]

### 判定：COMPLETE / COMPLETE WITH NOTES / BLOCKED
```

**判定定义：**
- **COMPLETE**：所有标准通过，无阻塞性偏差
- **COMPLETE WITH NOTES**：所有标准通过，记录了建议性偏差
- **BLOCKED**：必须首先解决失败的标准或阻塞性偏差

如果判定为 **BLOCKED**：不进入阶段 7。列出必须修复的内容。提供修复阻塞项的帮助。

---

## 阶段 7：更新故事状态

在写入任何内容前使用 `AskUserQuestion`：
- 提示："验证完成。你希望如何处理？"
- 选项：
  - `关闭故事 — 更新文件，标记为 Complete，记录备注（推荐）`
  - `关闭并将建议性偏差记录为技术债务，存入 docs/tech-debt-register.md`
  - `有些问题我想先修复 — 暂不关闭`
  - `按原样接受偏差并关闭`

如果"关闭"、"关闭并记录技术债务"或"接受偏差"：编辑故事文件。
如果"关闭并记录技术债务"：在更新故事文件后，还将建议性偏差追加到 `docs/tech-debt-register.md`（如果文件不存在则创建）。
如果"先修复"：在此停止并列出用户标记的内容。不写入任何文件。

1. 更新状态字段：`Status: Complete`
2. 更新故事标题中的 `Last Updated:` 字段为今天的日期（格式：`YYYY-MM-DD`）。如果该字段不存在，在 `Status:` 行之后添加。
3. 在底部添加 `## Completion Notes` 部分：

```markdown
## Completion Notes
**Completed**：[日期]
**Criteria**：[X/Y 通过]（[列出任何延迟项]）
**Deviations**：[无] 或 [建议性偏差列表]
**Test Evidence**：[Logic：路径处的测试文件 | Visual/Feel：路径处的证据文档 | 无需（Config/Data）]
**Code Review**：[待处理 / 已完成 / 已跳过]
```

4. 如果用户选择了"关闭并记录技术债务"：将每个建议性偏差追加到 `docs/tech-debt-register.md`，格式如下：
   ```
   - **[日期]**（[故事标题]）：[偏差描述] — 从 [故事文件路径] 追踪
   ```
   如果文件不存在，创建带有 `# Tech Debt Register` 标题的文件。

5. **更新 `production/sprint-status.yaml`**（如果存在）：
   - 找到与此故事文件路径或 ID 匹配的条目
   - 设置 `status: done` 和 `completed: [今天的日期]`
   - 更新顶层的 `updated` 字段
   - 这是静默更新——无需额外批准（已在上述步骤中批准）

6. **建议 git 提交**：输出一个即用型提交命令，涵盖 dev-story 摘要中的实现文件和更新后的故事文件：

```
建议提交：
git add [实现期间更改的 src/ 和 tests/ 文件] [故事文件路径]
git commit -m "feat：[故事标题]（[TR-ID]）"
```

`validate-commit.sh` 钩子将自动验证设计文档引用并检查硬编码值。

### 会话状态更新

在更新故事文件后，静默追加到 `production/session-state/active.md`：

    ## Session Extract — /story-done [日期]
    - Verdict：[COMPLETE / COMPLETE WITH NOTES / BLOCKED]
    - Story：[故事文件路径] — [故事标题]
    - Tech debt logged：[N 项，或"None"]
    - Next recommended：[下一个就绪故事标题和路径，或"None identified"]

如果 `active.md` 不存在，以此块作为初始内容创建它。
在对话中确认："会话状态已更新。"

---

## 阶段 8：显示下一个故事

完成后，帮助开发者保持势头：

1. 从 `production/sprints/` 读取当前冲刺计划。
2. 找到符合以下条件的故事：
   - 状态：READY 或 NOT STARTED
   - 未被其他未完成故事阻塞
   - 在 Must Have 或 Should Have 层级中

展示：

```
### 下一个任务
以下故事已就绪可接取：
1. [故事名称] — [一行描述] — 预估：[X 小时]
2. [故事名称] — [一行描述] — 预估：[X 小时]

在开始前运行 `/story-readiness [path]` 确认故事已可实施。
```

如果此冲刺中没有剩余的 Must Have 故事（全部为 Complete 或 Blocked）：

```
### 冲刺关闭流程

所有 Must Have 故事已完成。推进前需要 QA 签收。
按顺序运行：

1. `/smoke-check sprint` — 验证关键路径端到端仍正常工作
2. `/team-qa sprint` — 完整 QA 周期：测试用例执行、bug 分类、签收报告
3. `/retrospective` — 记录做得好的、做得不好的以及下一个冲刺的行动项
4. `/gate-check` — 一旦 QA 批准就推进到下一阶段（仅当推进阶段时）
5. `/sprint-plan new` — 规划下一个冲刺，结合速度数据和回顾行动项

在 `/team-qa` 返回 APPROVED 或 APPROVED WITH CONDITIONS 之前不要运行 `/gate-check`。
```

如果仍有 Should Have 故事未开始，与冲刺关闭流程一起展示，以便用户选择：立即关闭冲刺，还是先拉入更多工作。

如果没有更多故事就绪但 Must Have 故事仍在进行中（未 Complete）：
"没有更多故事可开始 — [N] 个 Must Have 故事仍在进行中。在冲刺关闭前继续实现这些故事。"

---

## 协作协议

- **未经用户批准绝不将故事标记为完成** — 阶段 7 需要明确的"是"才能编辑任何文件。
- **绝不自动修复失败的标准** — 报告它们并询问如何处理。
- **偏差是事实，不是评判** — 中立地呈现；用户决定它们是否可以接受。
- **BLOCKED 判定是建议性的** — 用户可以覆盖并仍然标记完成；如果他们这样做，明确记录风险。
- 对代码审查提示和批量手动标准确认使用 `AskUserQuestion`。

---

## 推荐后续步骤

- 运行 `/story-readiness [next-story-path]` 在开始实现前验证下一个故事
- 如果所有 Must Have 故事已完成：运行 `/smoke-check sprint` → `/team-qa sprint` → `/gate-check`
- 如果记录了技术债务：通过 `/tech-debt` 追踪以保持登记册最新
