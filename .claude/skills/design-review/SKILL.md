---
name: design-review
description: "审查游戏设计文档的完整性、内部一致性、可实现性以及对项目设计标准的遵守情况。在将设计文档交给程序员之前运行此审查。"
argument-hint: "[path-to-design-doc] [--depth full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Task, AskUserQuestion

---


## 第零阶段：解析参数

如果存在 `--depth [full|lean|solo]`，提取它。未给出标志时默认值为 `full`。

**注意**：`--depth` 控制本 skill 的*分析深度*（生成多少个专家代理）。它独立于 `production/review-mode.txt` 中的全局 review 模式，后者控制主管门禁的生成。这是两个不同概念——`--depth` 关于本 skill 分析文档的彻底程度。

- **`full`**：完整审查——所有阶段 + 专家代理委派（第 3b 阶段）
- **`lean`**：所有阶段，无专家代理——更快，单会话分析
- **`solo`**：仅第 1-4 阶段，无委派，无第 5 阶段后续步骤提示——从其他 skill 内部调用时使用

---

## 第一阶段：加载文档

完整读取目标设计文档。读取 CLAUDE.md 以了解项目上下文和标准。读取目标文档引用或隐含的相关设计文档（检查 `design/gdd/` 中的相关系统）。

**依赖关系图验证：** 对于依赖关系（Dependencies）部分中列出的每个系统，使用 Glob 检查其 GDD 文件是否存在于 `design/gdd/` 中。标记任何尚不存在的文件——这些是下游作者将会遇到的中断引用。

**传说/叙事一致性：** 如果 `design/gdd/game-concept.md` 或 `design/narrative/` 中的任何文件存在，读取它们。注意此 GDD 中与既定世界规则、基调或设计支柱相矛盾的机制选择。将此上下文传递给第 3b 阶段中的 `game-designer`。

**先前审查检查：** 检查 `design/gdd/reviews/[doc-name]-review-log.md` 是否存在。如果存在，读取最近的条目——注意给出的结论和列出的阻塞项。本次会话是重新审查；追踪先前的项目是否已解决。

---

## 第二阶段：完整性检查

对照设计文档标准清单进行评估：

- [ ] 有概述（Overview）部分（一段摘要）
- [ ] 有玩家幻想（Player Fantasy）部分（预期感受）
- [ ] 有详细规则（Detailed Rules）部分（无歧义的机制）
- [ ] 有公式（Formulas）部分（所有数学用变量定义）
- [ ] 有边缘情况（Edge Cases）部分（处理异常情况）
- [ ] 有依赖关系（Dependencies）部分（列出其他系统）
- [ ] 有调优旋钮（Tuning Knobs）部分（标识可配置值）
- [ ] 有验收标准（Acceptance Criteria）部分（可测试的成功条件）

---

## 第三阶段：一致性和可实现性

**内部一致性：**
- 公式产生的数值是否与描述的行为相匹配？
- 边缘情况是否与主要规则矛盾？
- 依赖关系是否为双向（另一个系统是否知道此系统的存在）？

**可实现性：**
- 规则是否足够精确，使程序员无需猜测即可实现？
- 是否存在任何"模糊处理"部分缺少细节？
- 是否考虑了性能影响？

**跨系统一致性：**
- 是否与任何现有机制冲突？
- 是否与其他系统产生意外交互？
- 是否与游戏已确立的基调和支柱一致？

---

## 第 3b 阶段：对抗性专家审查（仅 full 模式）

**在 `lean` 或 `solo` 模式下跳过此阶段。**

**在 full 模式下此阶段是强制性的。** 不要跳过它。

**在生成任何代理之前**，打印此通知：
> "Full review: spawning specialist agents in parallel. This typically takes 8–15 minutes. Use `--review lean` for faster single-session analysis."

### 步骤 1 — 识别 GDD 涉及的所有领域

读取 GDD 并识别存在的每个领域。一个 GDD 可以同时涉及多个领域——要彻底。常见信号：

| 如果 GDD 包含... | 生成这些代理 |
|------------------------|-------------------|
| 成本、价格、掉落、奖励、经济 | `economy-designer` |
| 战斗属性、伤害、生命值、DPS | `game-designer`、`systems-designer` |
| AI 行为、寻路、目标选择 | `ai-programmer` |
| 关卡布局、生成、波次结构 | `level-designer` |
| 玩家成长、经验值、解锁 | `economy-designer`、`game-designer` |
| UI、HUD、菜单、面向玩家的显示 | `ux-designer`、`ui-programmer` |
| 对话、任务、故事、传说 | `narrative-director` |
| 动画、手感、时机、效果增强 | `gameplay-programmer` |
| 多人、同步、复制 | `network-programmer` |
| 音频提示、音乐触发 | `audio-director` |
| 性能、绘制调用、内存 | `performance-analyst` |
| 引擎特定模式或 API | 主要引擎专家（来自 `.claude/docs/technical-preferences.md`） |
| 验收标准、测试覆盖 | `qa-lead` |
| 数据模式、资源结构 | `systems-designer` |
| 任何游戏玩法系统 | `game-designer`（始终） |

对于描述游戏机制或面向玩家规则的所有 GDD，生成 `game-designer`。
对于包含公式或系统交互规则的所有 GDD，生成 `systems-designer`。
这些是最常见的基线——但对于纯 UI 规格、音频规格或传说文档并非必需。使用上面的领域表确定哪些专家真正相关。

### 步骤 2 — 并行生成所有相关专家

**关键：本 skill 中的 Task 生成的是子代理（SUBAGENT）——一个拥有自己上下文窗口的独立 Claude 会话。它不是任务跟踪。不要内部模拟专家视角。不要自行推理领域观点。你必须发出实际的 Task 调用。模拟审查不是专家审查。**

同时发出所有 Task 调用。不要逐个生成。

**以对抗性方式提示每个专家：**
> "Here is the GDD for [system] and the main review's structural findings so far.
> Your job is NOT to validate this design — your job is to find problems.
> Challenge the design choices from your domain expertise. What is wrong,
> underspecified, likely to cause problems, or missing entirely?
> Be specific and critical. Disagreement with the main review is welcome."

**每种代理类型的额外说明：**

- **`game-designer`**：将你的审查锚定在此 GDD 第 B 节中声明的玩家幻想（Player Fantasy）。此设计是否确实实现了该幻想？玩家是否会感受到预期的体验？标记任何服务于可实现性但损害了声明的感受的规则。

- **`systems-designer`**：对于 GDD 中的每个公式，代入边界值（最小和最大合理输入）。报告是否有任何输出去到退化状态——负值、除零、无穷大或极端情况下的无意义结果。

- **`qa-lead`**：审查每个验收标准。标记任何不可独立测试的标准——像"感觉平衡"、"工作正常"、"性能良好"这样的短语不是合格的验收标准。为任何未通过此测试的标准建议具体的重写方案。

### 步骤 3 — 高级主管审查

在所有专家回复后，生成 `creative-director` 作为**高级审查员**：
- 提供：GDD、所有专家发现、他们之间的任何分歧
- 询问："Synthesise these findings. What are the most important issues? Do you agree with the specialists? What is your overall verdict on this design?"
- 创意总监（creative-director）的综合意见成为第四阶段的**最终结论**。

### 步骤 4 — 呈现分歧

如果专家之间或与创意总监之间存在分歧，不要默默选择某一方的观点。在第四阶段中明确呈现分歧，以便用户裁决。

用来源标记每个发现：`[game-designer]`、`[economy-designer]`、`[creative-director]` 等。

---

## 第四阶段：输出审查

```
## Design Review: [Document Title]
Specialists consulted: [list agents spawned]
Re-review: [Yes — prior verdict was X on YYYY-MM-DD / No — first review]

### Completeness: [X/8 sections present]
[List missing sections]

### Dependency Graph
[List each declared dependency and whether its GDD file exists on disk]
- ✓ enemy-definition-data.md — exists
- ✗ loot-system.md — NOT FOUND (file does not exist yet)

### Required Before Implementation
[Numbered list — blocking issues only. Each item tagged with source agent.]

### Recommended Revisions
[Numbered list — important but not blocking. Source-tagged.]

### Specialist Disagreements
[Any cases where agents disagreed with each other or with the main review.
Present both sides — do not silently resolve.]

### Nice-to-Have
[Minor improvements, low priority.]

### Senior Verdict [creative-director]
[Creative director's synthesis and overall assessment.]

### Scope Signal
Estimate implementation scope based on: dependency count, formula count,
systems touched, and whether new ADRs are required.
- **S** — single system, no formulas, no new ADRs, <3 dependencies
- **M** — moderate complexity, 1-2 formulas, 3-6 dependencies
- **L** — multi-system integration, 3+ formulas, may require new ADR
- **XL** — cross-cutting concern, 5+ dependencies, multiple new ADRs likely
Label clearly: "Rough scope signal: M (producer should verify before sprint planning)"

### Verdict: [APPROVED / NEEDS REVISION / MAJOR REVISION NEEDED]
```

本技能为只读——在第四阶段期间不写入文件。

---

## 第五阶段：后续步骤

对所有关闭交互使用 `AskUserQuestion`。绝不使用纯文本。

**第一个小部件——接下来做什么：**

如果为 APPROVED（首次通过，无需修订），直接进入 systems-index 小部件、review-log 小部件，然后最终关闭小部件。不显示单独的"接下来做什么"小部件——最终关闭小部件涵盖后续步骤。

如果为 NEEDS REVISION 或 MAJOR REVISION NEEDED，选项：
- `[A] Revise the GDD now — address blocking items together`
- `[B] Stop here — revise in a separate session`
- `[C] Accept as-is and move on (only if all items are advisory)`

**如果用户选择 [A] — 立即修订：**

处理所有阻塞项，仅在你无法单独从 GDD 和现有文档解决问题时询问设计决策。将所有设计决策问题分组到单个多选项 `AskUserQuestion` 中，然后再进行任何编辑——不要为每个阻塞项单独中断修订流程。

完成所有修订后，显示摘要表（阻塞项 → 已应用的修复）并使用 `AskUserQuestion` 作为**修订后关闭小部件**：

- 提示："Revisions complete — [N] blockers resolved. What next?"
- 注意当前上下文使用情况：如果上下文超过约 50%，添加："(Recommended: /clear before re-review — this session has used X% context. A full re-review runs 5 agents and needs clean context.)"
- 选项：
  - `[A] Re-review in a new session — run /design-review [doc-path] after /clear`
  - `[B] Accept revisions and mark Approved — update systems index, skip re-review`
  - `[C] Move to next system — /design-system [next-system] (#N in design order)`
  - `[D] Stop here`

永远不要以纯文本结束修订流程。始终使用此小部件关闭。

**第二个小部件——跟踪记录（已合并，适用于 APPROVED 路径）：**

当结论为 APPROVED 时，使用一个带有 `multiSelect: true` 的 `AskUserQuestion` 来批量处理两个跟踪更新：
- 提示："Verdict: APPROVED. I can update the tracking records now. Select any you'd like me to complete:"
- 选项：
  - `Update systems-index.md status to 'Approved' for [system]`
  - `Append approval entry to design/gdd/reviews/[doc-name]-review-log.md`

如果选择了 review-log 选项，追加与下面相同的格式。在显示最终关闭小部件之前，执行选定的两个操作。

当结论为 NEEDS REVISION 或 MAJOR REVISION NEEDED 时，像以前一样使用单独的小部件：

使用第二个 `AskUserQuestion`：
- 提示："May I update `design/gdd/systems-index.md` to mark [system] as [In Review / Approved]?"
- 选项：`[A] Yes — update it` / `[B] No — leave it as-is`

使用第三个 `AskUserQuestion`：
- 提示："May I append this review summary to `design/gdd/reviews/[doc-name]-review-log.md`? This creates a revision history so future re-reviews can track what changed."
- 选项：`[A] Yes — append to review log` / `[B] No — skip`

如果是，按此格式追加条目：
```
## Review — [YYYY-MM-DD] — Verdict: [APPROVED / NEEDS REVISION / MAJOR REVISION NEEDED]
Scope signal: [S/M/L/XL]
Specialists: [list]
Blocking items: [count] | Recommended: [count]
Summary: [2-3 sentence summary of key findings from creative-director verdict]
Prior verdict resolved: [Yes / No / First review]
```

---

**最终关闭小部件——在所有文件写入完成后始终显示：**

一旦 systems-index 和 review-log 小部件被回答，检查项目状态并显示一个最终的 `AskUserQuestion`：

在构建选项之前，读取：
- `design/gdd/systems-index.md` — 查找任何状态为 In Review 或 NEEDS REVISION 的系统（刚审查的那个除外）
- 统计 `design/gdd/` 中的 `.md` 文件数（排除 game-concept.md、systems-index.md）以确定是否值得提供 `/review-all-gdds`（≥2 个 GDD）
- 在设计顺序中找到下一个状态为 Not Started 的系统

动态构建选项列表——仅包含真正下一步的选项：
- `[_] Run /design-review [other-gdd-path] — [system name] is still [In Review / NEEDS REVISION]`（如果有其他 GDD 需要审查则包含）
- `[_] Run /consistency-check — verify this GDD's values don't conflict with existing GDDs`（如果存在 ≥1 个其他 GDD 则始终包含）
- `[_] Run /review-all-gdds — holistic design-theory review across all designed systems`（如果存在 ≥2 个 GDD 则包含）
- `[_] Run /design-system [next-system] — next in design order`（始终包含，指明实际系统名称）
- `[_] Stop here`

仅对包含的选项分配字母 A、B、C…。将最推进管线的选项标记为 `(recommended)`。

永远不要在文件写入后以纯文本结束 skill。始终使用此小部件关闭。
