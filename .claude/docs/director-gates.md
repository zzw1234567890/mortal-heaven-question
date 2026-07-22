# 主管关口 (Director Gates) —— 共享审查模式


本文档定义了所有主管和负责人审查的标准关口提示，适用于每个工作流阶段。各技能通过引用本文档中的关口 ID 而非内联嵌入完整提示 —— 在提示需要更新时消除漂移。

**范围**：所有 7 个生产阶段（概念 → 发布）、所有 3 个 Tier 1 主管、所有关键 Tier 2 负责人。任何技能、团队编排器或工作流均可调用这些关口。

---

## 如何使用本文档 (How to Use This Document)

在任何技能中，将内联的主管提示替换为引用：

```
通过 Task 使用 `.claude/docs/director-gates.md` 中的关口 **CD-PILLARS** 生成 `creative-director`。
```

传入该关口 **Context to pass（需传递的上下文）** 字段下列出的上下文，然后使用下面的 **Verdict handling（裁决处理）** 规则处理裁决。

---

## 审查模式 (Review Modes)

审查强度控制主管关口是否运行。它可以全局设置（跨会话持久化），也可以在每次技能运行时覆盖。

**全局配置**：`production/review-mode.txt` —— 一个词：`full`、`lean` 或 `solo`。在 `/start` 期间设置一次。直接编辑文件可随时更改。

**每次运行覆盖**：任何使用关口的技能都接受 `--review [full|lean|solo]` 作为参数。这仅覆盖本次运行的全局配置。

示例：
```
/brainstorm space horror           → 使用全局模式
/brainstorm space horror --review full   → 本次运行强制使用 full 模式
/architecture-decision --review solo     → 本次运行跳过所有关口
```

| 模式 (Mode) | 运行内容 | 最佳用途 |
|------|-----------|----------|
| `full` | 所有关口激活 —— 每个工作流步骤都被审查 | 团队、学习中的用户，或者希望在每一步都获得详尽的主管反馈时 |
| `lean` | 仅 PHASE-GATE（阶段关口）(`/gate-check`) —— 跳过每个技能的关口 | **默认** —— 独立开发者和小型团队；主管仅在里程碑节点进行审查 |
| `solo` | 任何地方都没有主管关口 | 游戏黑客松、原型制作、追求最快速度 |

**检查模式 —— 在每次生成关口前应用：**

```
在生成关口 [GATE-ID] 之前：
1. 如果技能使用 --review [mode] 调用，则使用该模式
2. 否则读取 production/review-mode.txt
3. 否则默认为 lean

应用解析后的模式：
- solo → 跳过所有关口。记录："[GATE-ID] skipped — Solo mode"
- lean → 跳过，除非这是 PHASE-GATE（阶段关口）(CD-PHASE-GATE、TD-PHASE-GATE、PR-PHASE-GATE、AD-PHASE-GATE)
         记录："[GATE-ID] skipped — Lean mode"
- full → 正常生成
```

---

## 调用模式 (Invocation Pattern) —— 复制到任何技能中

**强制要求：在每次生成关口之前解析审查模式。** 未经检查不得生成关口。解析后的模式在每次技能运行中确定一次：
1. 如果技能使用 `--review [mode]` 调用，则使用该模式
2. 否则读取 `production/review-mode.txt`
3. 否则默认为 `lean`

应用解析后的模式：
- `solo` → **跳过所有关口**。在输出中记录：`[GATE-ID] skipped — Solo mode`
- `lean` → **跳过，除非这是 PHASE-GATE（阶段关口）** (CD-PHASE-GATE、TD-PHASE-GATE、PR-PHASE-GATE、AD-PHASE-GATE)。记录：`[GATE-ID] skipped — Lean mode`
- `full` → 正常生成

```
# 应用模式检查，然后：
通过 Task 生成 `[agent-name]`：
- 关口： [GATE-ID] （详见 .claude/docs/director-gates.md）
- 上下文： [该关口下列出的字段]
- 等待裁决后再继续。
```

对于并行生成（在同一关口点有多个主管）：

```
# 先对每个关口应用模式检查，然后生成所有通过的关口：
通过 Task 同时生成所有 [N] 个代理 —— 在等待任何结果之前发出所有 Task 调用。
收集所有裁决后再继续。
```

---

## 标准裁决格式 (Standard Verdict Format)

所有关口都返回三种裁决之一。技能必须处理全部三种：

| 裁决 (Verdict) | 含义 (Meaning) | 默认操作 (Default action) |
|---------|---------|----------------|
| **APPROVE / READY** | 无问题。继续。 | 继续工作流 |
| **CONCERNS [list]** | 存在但不构成阻塞的问题。 | 通过 `AskUserQuestion` 向用户展示 —— 选项：`Revise flagged items` / `Accept and proceed` / `Discuss further` |
| **REJECT / NOT READY [blockers]** | 阻塞性问题。不得继续。 | 向用户展示阻塞项。在问题解决之前，不得写入文件或推进阶段。 |

**升级规则 (Escalation rule)**：当多个主管并行生成时，适用最严格的裁决 —— 一个 NOT READY 覆盖所有 READY 裁决。

---

## 记录关口结果 (Recording Gate Outcomes)

关口解决后，将裁决记录在相关文档的状态头部：

```markdown
> **[Director] Review ([GATE-ID])**: APPROVED [date] / CONCERNS (accepted) [date] / REVISED [date]
```

对于阶段关口，酌情记录在 `docs/architecture/architecture.md` 或 `production/session-state/active.md` 中。

---

## Tier 1 —— 创意总监关口 (Creative Director Gates)

代理 (Agent)：`creative-director` | 模型层级 (Model tier)：Opus | 领域 (Domain)：愿景、支柱、玩家体验

---

### CD-PILLARS —— 支柱压力测试 (Pillar Stress Test)

**触发条件 (Trigger)**：在游戏支柱和反支柱定义之后（brainstorm 阶段 4，或任何修订支柱的时机）

**需传递的上下文 (Context to pass)**：
- 完整的支柱集，包括名称、定义和设计测试
- 反支柱列表
- 核心幻想陈述
- 独特卖点 ("Like X, AND ALSO Y")

**提示 (Prompt)**：
> "审查这些游戏支柱。它们是否可证伪 —— 一个真实的设计决策是否可能未能通过该支柱？它们之间是否形成了有意义的张力？它们是否使这款游戏与其最接近的可比作品区分开来？它们能否在实践中帮助解决设计分歧，还是过于模糊而无法发挥作用？为每个支柱返回具体反馈，以及一个总体裁决：APPROVE（强有力）、CONCERNS [list]（需要打磨）或 REJECT（薄弱 —— 支柱缺乏分量）。"

**裁决 (Verdicts)**：APPROVE / CONCERNS / REJECT

---

### CD-GDD-ALIGN —— GDD 支柱对齐检查 (GDD Pillar Alignment Check)

**触发条件 (Trigger)**：在系统 GDD 编写之后（design-system、quick-design 或任何生成 GDD 的工作流）

**需传递的上下文 (Context to pass)**：
- GDD 文件路径
- 游戏支柱（来自 `design/gdd/game-concept.md` 或 `design/gdd/game-pillars.md`）
- 该游戏的 MDA 美学目标
- 系统的玩家幻想部分陈述

**提示 (Prompt)**：
> "审查此系统 GDD 的支柱对齐情况。每个章节是否都服务于所述的支柱？是否存在与支柱相悖或削弱支柱的机制或规则？玩家幻想章节是否与游戏的核心幻想相匹配？返回 APPROVE、CONCERNS [具体有问题的章节] 或 REJECT [必须在此系统可实施之前重新设计的支柱违规]。"

**裁决 (Verdicts)**：APPROVE / CONCERNS / REJECT

---

### CD-SYSTEMS —— 系统分解愿景检查 (Systems Decomposition Vision Check)

**触发条件 (Trigger)**：在 `/map-systems` 编写系统索引之后 —— 在开始 GDD 编写之前验证完整的系统集

**需传递的上下文 (Context to pass)**：
- 系统索引路径 (`design/gdd/systems-index.md`)
- 游戏支柱和核心幻想（来自 `design/gdd/game-concept.md`）
- 优先级层级分配 (MVP / Vertical Slice / Alpha / Full Vision)
- 依赖关系图中识别出的高风险或瓶颈系统

**提示 (Prompt)**：
> "对照游戏的设计支柱审查此系统分解。完整的 MVP 层级系统集是否共同交付了核心幻想？是否存在其机制不服务于任何所述支柱的系统 —— 表明可能是范围蔓延？是否存在没有指定系统来交付的支柱关键玩家体验？核心循环所需的关键系统是否缺失？返回 APPROVE（系统服务于愿景）、CONCERNS [具体缺口或与其支柱影响相关的不一致] 或 REJECT [根本性缺口 —— 分解遗漏了关键设计意图，必须在开始 GDD 编写前修订]。"

**裁决 (Verdicts)**：APPROVE / CONCERNS / REJECT

---

### CD-NARRATIVE —— 叙事一致性检查 (Narrative Consistency Check)

**触发条件 (Trigger)**：在叙事 GDD、世界观文档、对话规格或世界构建文档编写之后（team-narrative、故事系统的 design-system、编剧交付物）

**需传递的上下文 (Context to pass)**：
- 文档文件路径
- 游戏支柱
- 叙事方向简报或语调指南（如果存在于 `design/narrative/`）
- 新文档引用的任何现有世界观

**提示 (Prompt)**：
> "审查此叙事内容与游戏支柱和既定世界规则的一致性。语调是否与游戏既定的声音一致？是否存在与现有世界观或世界构建的矛盾？内容是否服务于玩家体验支柱？返回 APPROVE、CONCERNS [具体不一致之处] 或 REJECT [破坏世界连贯性的矛盾]。"

**裁决 (Verdicts)**：APPROVE / CONCERNS / REJECT

---

### CD-PLAYTEST —— 玩家体验验证 (Player Experience Validation)

**触发条件 (Trigger)**：在试玩测试报告生成之后（`/playtest-report`），或任何产生产生玩家反馈的会话之后

**需传递的上下文 (Context to pass)**：
- 试玩测试报告文件路径
- 游戏支柱和核心幻想陈述
- 正在测试的特定假设

**提示 (Prompt)**：
> "对照游戏的设计支柱和核心幻想审查此试玩测试报告。玩家体验是否与预期幻想相符？是否存在代表支柱漂移的系统性问题 —— 那些单独看似正常但削弱预期体验的机制？返回 APPROVE（核心幻想正在实现）、CONCERNS [预期体验与实际体验之间的差距] 或 REJECT [核心幻想未体现 —— 在进一步试玩测试前需要重新设计]。"

**裁决 (Verdicts)**：APPROVE / CONCERNS / REJECT

---

### CD-PHASE-GATE —— 阶段过渡创意就绪度 (Creative Readiness at Phase Transition)

**触发条件 (Trigger)**：始终在 `/gate-check` 时 —— 与 TD-PHASE-GATE 和 PR-PHASE-GATE 并行生成

**需传递的上下文 (Context to pass)**：
- 目标阶段名称
- 所有现有产物的列表（文件路径）
- 游戏支柱和核心幻想

**提示 (Prompt)**：
> "从创意方向角度审查当前项目状态是否准备好进入 [目标阶段] 关口。游戏支柱是否在所有设计产物中得到忠实体现？当前状态是否保留了核心幻想？是否有跨越 GDD 或架构的设计决策损害了预期玩家体验？返回 READY、CONCERNS [list] 或 NOT READY [blockers]。"

**裁决 (Verdicts)**：READY / CONCERNS / NOT READY

---

## Tier 1 —— 技术总监关口 (Technical Director Gates)

代理 (Agent)：`technical-director` | 模型层级 (Model tier)：Opus | 领域 (Domain)：架构、引擎风险、性能

---

### TD-SYSTEM-BOUNDARY —— 系统边界架构审查 (System Boundary Architecture Review)

**触发条件 (Trigger)**：在 `/map-systems` 阶段 3 依赖关系映射达成一致之后，但在 GDD 编写开始之前 —— 验证系统结构在架构上是否健全，然后再让团队投入编写 GDD

**需传递的上下文 (Context to pass)**：
- 系统索引路径（如果索引尚未编写，则为依赖关系图摘要）
- 层级分配 (Foundation / Core / Feature / Presentation / Polish)
- 完整的依赖关系图（每个系统依赖什么）
- 任何被标记的瓶颈系统（有许多依赖者）
- 任何发现的循环依赖关系及其建议的解决方案

**提示 (Prompt)**：
> "在 GDD 编写开始之前，从架构角度审查此系统分解。系统边界是否清晰 —— 每个系统是否拥有关注度最小的独特职责？是否存在上帝对象风险（系统做得太多）？依赖关系排序是否造成实现顺序问题？提出的边界中是否存在隐式的共享状态问题，在实现时会导致紧耦合？是否有 Foundation 层系统实际上依赖于 Feature 层系统（依赖反转）？返回 APPROVE（边界在架构上健全 —— 继续进行 GDD 编写）、CONCERNS [需要在 GDD 本身中解决的特定边界问题] 或 REJECT [根本性的边界问题 —— 系统结构将导致架构问题，必须在编写任何 GDD 之前进行重构]。"

**裁决 (Verdicts)**：APPROVE / CONCERNS / REJECT

---

### TD-FEASIBILITY —— 技术可行性评估 (Technical Feasibility Assessment)

**触发条件 (Trigger)**：在范围/可行性评估期间识别出最大的技术风险之后（brainstorm 阶段 6、quick-design，或任何存在技术未知数的早期概念阶段）

**需传递的上下文 (Context to pass)**：
- 概念的核心循环描述
- 平台目标
- 引擎选择（或"未决定"）
- 已识别的技术风险列表

**提示 (Prompt)**：
> "审查针对 [平台] 使用 [引擎或'未决定引擎'] 的 [类型] 游戏的技术风险。标记任何可能导致所述概念不可行的高风险项、任何特定于引擎且应影响引擎选择的风险，以及任何常被独立开发者低估的风险。返回 VIABLE（风险可控）、CONCERNS [list with mitigation suggestions] 或 HIGH RISK [需要修订概念或范围的阻塞项]。"

**裁决 (Verdicts)**：VIABLE / CONCERNS / HIGH RISK

---

### TD-ARCHITECTURE —— 架构签核 (Architecture Sign-Off)

**触发条件 (Trigger)**：在主架构文档草稿完成之后（`/create-architecture` 阶段 7），以及任何重大架构修订之后

**需传递的上下文 (Context to pass)**：
- 架构文档路径 (`docs/architecture/architecture.md`)
- 技术需求基线（TR-ID 及数量）
- ADR 列表及状态
- 引擎知识缺口清单

**提示 (Prompt)**：
> "审查此主架构文档的技术健全性。检查：(1) 基线中的每个技术需求是否都有架构决策覆盖？(2) 所有高风险引擎领域是否都明确处理或标记为待解决的问题？(3) API 边界是否清晰、最小且可实现？(4) Foundation 层 ADR 缺口是否在实现开始前已解决？返回 APPROVE、CONCERNS [list] 或 REJECT [必须在编码开始前解决的阻塞项]。"

**裁决 (Verdicts)**：APPROVE / CONCERNS / REJECT

---

### TD-ADR —— 架构决策审查 (Architecture Decision Review)

**触发条件 (Trigger)**：在单个 ADR 编写之后（`/architecture-decision`），在其标记为 Accepted 之前

**需传递的上下文 (Context to pass)**：
- ADR 文件路径
- 该领域的引擎版本和知识缺口风险等级
- 相关 ADR（如有）

**提示 (Prompt)**：
> "审查此架构决策记录 (ADR)。它是否有清晰的问题陈述和理由？被拒绝的备选方案是否经过充分考量？后果章节是否诚实地承认了权衡？引擎版本是否已标注？后截止日期的 API 风险是否已标记？它是否链接到其覆盖的 GDD 需求？返回 APPROVE、CONCERNS [具体缺口] 或 REJECT [决策不够详细或做出了不健全的技术假设]。"

**裁决 (Verdicts)**：APPROVE / CONCERNS / REJECT

---

### TD-ENGINE-RISK —— 引擎版本风险审查 (Engine Version Risk Review)

**触发条件 (Trigger)**：当做出的架构决策涉及后截止日期的引擎 API 时，或在最终确定任何引擎特定的实现方法之前

**需传递的上下文 (Context to pass)**：
- 正在使用的特定 API 或功能
- 引擎版本和 LLM 知识截止日期（来自 `docs/engine-reference/[engine]/VERSION.md`）
- 来自重大变更或已弃用 API 文档的相关摘录

**提示 (Prompt)**：
> "对照版本参考审查此引擎 API 使用情况。该 API 是否存在于 [引擎版本] 中？自 LLM 知识截止日期以来，其签名、行为或命名空间是否发生了变化？是否存在已知的弃用项或后截止日期的替代方案？返回 APPROVE（按描述使用安全）、CONCERNS [在实现前需验证] 或 REJECT [API 已变更 —— 提供修正方法]。"

**裁决 (Verdicts)**：APPROVE / CONCERNS / REJECT

---

### TD-PHASE-GATE —— 阶段过渡技术就绪度 (Technical Readiness at Phase Transition)

**触发条件 (Trigger)**：始终在 `/gate-check` 时 —— 与 CD-PHASE-GATE 和 PR-PHASE-GATE 并行生成

**需传递的上下文 (Context to pass)**：
- 目标阶段名称
- 架构文档路径（如果存在）
- 引擎参考路径
- ADR 列表

**提示 (Prompt)**：
> "从技术方向角度审查当前项目状态是否准备好进入 [目标阶段] 关口。该阶段的架构是否健全？所有高风险引擎领域是否已处理？性能预算是否现实且已记录？Foundation 层决策是否足够完整以开始实现？返回 READY、CONCERNS [list] 或 NOT READY [blockers]。"

**裁决 (Verdicts)**：READY / CONCERNS / NOT READY

---

## Tier 1 —— 制作人关口 (Producer Gates)

代理 (Agent)：`producer` | 模型层级 (Model tier)：Opus | 领域 (Domain)：范围、时间线、依赖关系、生产风险

---

### PR-SCOPE —— 范围和时间线验证 (Scope and Timeline Validation)

**触发条件 (Trigger)**：在范围层级定义之后（brainstorm 阶段 6、quick-design，或任何生成 MVP 定义和时间线估算的工作流）

**需传递的上下文 (Context to pass)**：
- 完整愿景范围描述
- MVP 定义
- 时间线估算
- 团队规模（个人 / 小团队 / 等）
- 范围层级（如果时间不够，交付什么）

**提示 (Prompt)**：
> "审查此范围估算。在所述的时间线和团队规模下，MVP 是否可实现？范围层级是否按风险正确排序 —— 如果在某处停止工作，每个层级是否都能交付一个可发布的产品？在时间压力下最可能的裁剪点是什么 —— 是优雅的降级还是破碎的产品？返回 REALISTIC（范围匹配容量）、OPTIMISTIC [建议具体调整] 或 UNREALISTIC [阻塞项 —— 必须修订时间线或 MVP]。"

**裁决 (Verdicts)**：REALISTIC / OPTIMISTIC / UNREALISTIC

---

### PR-SPRINT —— 冲刺可行性审查 (Sprint Feasibility Review)

**触发条件 (Trigger)**：在最终确定冲刺计划之前（`/sprint-plan`），以及任何冲刺中期范围变更之后

**需传递的上下文 (Context to pass)**：
- 提议的冲刺故事列表（标题、估算、依赖关系）
- 团队容量（可用小时数）
- 当前冲刺的积压债务（如有）
- 里程碑约束

**提示 (Prompt)**：
> "审查此冲刺计划的可行性。故事负载在可用容量下是否现实？故事是否按依赖关系正确排序？故事之间是否存在可能在中途阻塞冲刺的隐藏依赖关系？是否有故事因其技术复杂度而被低估？返回 REALISTIC（计划可实现）、CONCERNS [特定风险] 或 UNREALISTIC [冲刺必须缩减范围 —— 确定哪些故事应推迟]。"

**裁决 (Verdicts)**：REALISTIC / CONCERNS / UNREALISTIC

---

### PR-MILESTONE —— 里程碑风险评估 (Milestone Risk Assessment)

**触发条件 (Trigger)**：在里程碑审查时（`/milestone-review`）、冲刺中期回顾时，或当提出影响里程碑的范围变更时

**需传递的上下文 (Context to pass)**：
- 里程碑定义和目标日期
- 当前完成百分比
- 被阻塞的故事数量
- 冲刺速度数据（可用时）

**提示 (Prompt)**：
> "审查此里程碑状态。基于当前速度和被阻塞的故事数量，此里程碑能否达到目标日期？从现在到里程碑之间，前三大生产风险是什么？是否有为保护里程碑日期而应裁剪的范围项，与不可协商的范围项？返回 ON TRACK、AT RISK [具体缓解措施] 或 OFF TRACK [日期必须推迟或范围必须削减 —— 提供两种选项]。"

**裁决 (Verdicts)**：ON TRACK / AT RISK / OFF TRACK

---

### PR-EPIC —— Epic 结构可行性审查 (Epic Structure Feasibility Review)

**触发条件 (Trigger)**：在 `/create-epics` 定义 epics 之后，在分解出 stories 之前 —— 验证 epic 结构在 `/create-stories` 调用前是否可生产

**需传递的上下文 (Context to pass)**：
- Epic 定义文件路径（所有刚刚创建的 epics）
- Epic 索引路径 (`production/epics/index.md`)
- 里程碑时间线和目标日期
- 团队容量（个人 / 小团队 / 规模）
- 正在被 epiced 的层 (Foundation / Core / Feature / 等)

**提示 (Prompt)**：
> "在故事分解开始前审查此 epic 结构的生产可行性。Epic 边界划分是否合适 —— 每个 epic 是否能在里程碑截止日期前实际完成？Epics 是否按系统依赖关系正确排序 —— 是否有任何 epic 需要另一个 epic 的输出才能开始？是否有任何 epics 范围过小（太小，应合并）或范围过大（太大，应拆分为 2-3 个聚焦的 epics）？Foundation 层 epics 的范围是否允许 Core 层 epics 在 Foundation 完成后的下一个冲刺开始时启动？返回 REALISTIC（epic 结构可生产）、CONCERNS [在编写 stories 之前需要的特定结构调整] 或 UNREALISTIC [epics 必须拆分、合并或重新排序 —— 在解决之前不能开始故事分解]。"

**裁决 (Verdicts)**：REALISTIC / CONCERNS / UNREALISTIC

---

### PR-PHASE-GATE —— 阶段过渡生产就绪度 (Production Readiness at Phase Transition)

**触发条件 (Trigger)**：始终在 `/gate-check` 时 —— 与 CD-PHASE-GATE 和 TD-PHASE-GATE 并行生成

**需传递的上下文 (Context to pass)**：
- 目标阶段名称
- 现有的冲刺和里程碑产物
- 团队规模和容量
- 当前被阻塞的故事数量

**提示 (Prompt)**：
> "从生产角度审查当前项目状态是否准备好进入 [目标阶段] 关口。在所述时间线和团队规模下，范围是否现实？依赖关系是否正确排序，以便团队能够按顺序实际执行？是否存在可能在头两个冲刺内使阶段偏离轨道的里程碑或冲刺风险？返回 READY、CONCERNS [list] 或 NOT READY [blockers]。"

**裁决 (Verdicts)**：READY / CONCERNS / NOT READY

---

## Tier 1 —— 艺术总监关口 (Art Director Gates)

代理 (Agent)：`art-director` | 模型层级 (Model tier)：Sonnet | 领域 (Domain)：视觉身份、艺术圣经、视觉生产就绪度

---

### AD-CONCEPT-VISUAL —— 视觉身份锚点 (Visual Identity Anchor)

**触发条件 (Trigger)**：在游戏支柱锁定之后（brainstorm 阶段 4），与 CD-PILLARS 并行

**需传递的上下文 (Context to pass)**：
- 游戏概念（电梯演讲、核心幻想、独特卖点）
- 完整的支柱集，包括名称、定义和设计测试
- 目标平台（如果已知）
- 用户提到的任何参考游戏或视觉试金石

**提示 (Prompt)**：
> "基于这些游戏支柱和核心概念，提出 2-3 个不同的视觉身份方向。对于每个方向，提供：(1) 一条可指导所有视觉决策的单行视觉规则（例如'万物皆动'、'美在衰败中'），(2) 氛围和情绪目标，(3) 形状语言（锐利/圆润/有机/几何侧重），(4) 色彩理念（调色板方向，色彩在这个世界中的含义）。要具体 —— 避免泛泛的描述。其中一个方向应直接服务于主要设计支柱。为每个方向命名。推荐哪个方向最能服务于所述的支柱并解释原因。"

**裁决 (Verdicts)**：CONCEPTS（多个有效选项 —— 用户选择）/ STRONG（一个方向明显占优）/ CONCERNS（支柱尚未提供足够的方向来区分视觉身份）

---

### AD-ART-BIBLE —— 艺术圣经签核 (Art Bible Sign-Off)

**触发条件 (Trigger)**：在艺术圣经草稿完成之后（`/art-bible`），在资产生产开始之前

**需传递的上下文 (Context to pass)**：
- 艺术圣经路径 (`design/art/art-bible.md`)
- 游戏支柱和核心幻想
- 平台和性能约束（来自 `.claude/docs/technical-preferences.md`，如已配置）
- 头脑风暴期间选择的视觉身份锚点（来自 `design/gdd/game-concept.md`）

**提示 (Prompt)**：
> "审查此艺术圣经的完整性和内部一致性。色彩系统是否与情绪目标匹配？形状语言是否从视觉身份陈述中衍生而来？资产标准是否在平台约束内可实现？角色设计方向是否给艺术家提供了足够的工作依据而不过度具体？各章节之间是否存在矛盾？外包团队是否能够根据此文档生成资产而无需额外简报？返回 APPROVE（艺术圣经已准备好生产）、CONCERNS [需要澄清的特定章节] 或 REJECT [必须在资产生产开始前解决的根本性不一致]。"

**裁决 (Verdicts)**：APPROVE / CONCERNS / REJECT

---

### AD-PHASE-GATE —— 阶段过渡视觉就绪度 (Visual Readiness at Phase Transition)

**触发条件 (Trigger)**：始终在 `/gate-check` 时 —— 与 CD-PHASE-GATE、TD-PHASE-GATE 和 PR-PHASE-GATE 并行生成

**需传递的上下文 (Context to pass)**：
- 目标阶段名称
- 所有艺术/视觉产物的列表（文件路径）
- 来自 `design/gdd/game-concept.md` 的视觉身份锚点（如果存在）
- 艺术圣经路径（如果存在，`design/art/art-bible.md`）

**提示 (Prompt)**：
> "从视觉方向角度审查当前项目状态是否准备好进入 [目标阶段] 关口。视觉身份是否已建立并记录到该阶段所需的程度？正确的视觉产物是否已到位？视觉团队是否能够在没有视觉方向缺口 —— 缺口会导致代价高昂的后期返工 —— 的情况下开始工作？是否有视觉决策被推迟到其最晚负责时间之后？返回 READY、CONCERNS [可能导致生产返工的具体视觉方向缺口] 或 NOT READY [在此阶段成功之前必须存在的视觉阻塞项 —— 指定缺少什么产物以及为什么在该阶段至关重要]。"

**裁决 (Verdicts)**：READY / CONCERNS / NOT READY
