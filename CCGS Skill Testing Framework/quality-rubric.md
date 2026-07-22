
# 技能质量评分标准 (Skill Quality Rubric)

由 `/skill-test category [name|all]` 使用，用于评估技能在结构合规性之外的方面。
每个类别定义了 4–5 个针对该技能工作的二元通过/失败度量标准。

当技能的书面指令明确满足标准时，度量为 PASS（通过）。
当指令缺失、模糊或自相矛盾时，度量为 FAIL（失败）。
当指令部分满足标准时，度量为 WARN（警告）。

---

## 技能类别 (Skill Categories)

### `gate`

**技能 (Skills)**：gate-check

关卡 (Gate) 技能控制阶段转换。它们必须确保正确性而不自动推进阶段，
并且必须尊重三种评审模式。

| 度量 (Metric) | PASS (通过) 标准 |
|---|---|
| **G1 — 读取评审模式** | 技能在决定生成哪些总监之前，先读取 `production/session-state/review-mode.txt`（或等效文件） |
| **G2 — 完整模式：全部 4 位总监生成** | 在 `full`（完整）模式下，并行调用全部 4 位一级总监（CD、TD、PR、AD）的阶段关卡提示 |
| **G3 — 精简模式：仅阶段关卡** | 在 `lean`（精简）模式下，仅运行 `*-PHASE-GATE` 关卡；跳过内联关卡（CD-PILLARS、TD-ARCHITECTURE 等） |
| **G4 — 单独模式：无总监** | 在 `solo`（单独）模式下，不生成任何总监关卡；每项记录为"已跳过 — Solo 模式" |
| **G5 — 不自动推进** | 未经用户明确确认（通过"May I write"），技能绝不会写入 `production/stage.txt` |

---

### `review`

**技能 (Skills)**：design-review, architecture-review, review-all-gdds

评审 (Review) 技能读取文档并产生结构化判定。它们主要是只读的，
并且在分析阶段不得触发总监关卡。

| 度量 (Metric) | PASS (通过) 标准 |
|---|---|
| **R1 — 只读执行** | 未经用户明确批准，技能不会修改被评审的文档；任何写入操作（评审日志、索引更新）都需经"May I write"同意 |
| **R2 — 8 章节检查** | 技能明确评估所有 8 个必需的 GDD 章节（或等效的架构章节） |
| **R3 — 正确的判定词汇** | 判定必须是以下之一：APPROVED（批准）/ NEEDS REVISION（需要修订）/ MAJOR REVISION NEEDED（需要重大修订）（设计类）或 PASS（通过）/ CONCERNS（关切）/ FAIL（失败）（架构类） |
| **R4 — 分析阶段无总监关卡** | 技能在分析阶段不会生成总监关卡；分析后的总监评审（如 architecture-review 中的做法）在技能范围和重要性允许的情况下是可接受的 |
| **R5 — 结构化发现** | 输出在最终判定之前包含按章节的状态表或检查清单 |

> **例外：**
> - `design-review`：`allowed-tools` 中包含 `Write, Edit` 以支持可选的"立即修订"路径（所有写入需经用户批准）以及写入评审日志。R1 满足，因为被评审的文档不会被静默修改。
> - `architecture-review`：在分析完成后生成 TD-ARCHITECTURE 和 LP-FEASIBILITY 关卡。这是有意为之——架构评审风险高，需要总监签批。R4 满足，因为关卡在分析后运行，而非分析期间。

---

### `authoring`

**技能 (Skills)**：design-system, quick-design, architecture-decision, ux-design, ux-review, art-bible, create-architecture

创作 (Authoring) 技能以协作方式创建或更新设计文档。完整的 GDD/UX
创作技能使用逐章节循环；轻量级创作技能使用适合其较小范围的
单稿模式。

| 度量 (Metric) | PASS (通过) 标准 |
|---|---|
| **A1 — 逐章节循环** | 完整创作技能（design-system, ux-design, art-bible）一次创作一个章节，在继续下一章节之前展示内容以供批准。轻量级技能（quick-design, architecture-decision, create-architecture）可以起草完整文档然后请求批准——对于大约 4 小时实现范围以内的文档，单稿模式是可接受的。 |
| **A2 — 每章节的"May I write"** | 完整创作技能在每个章节写入前询问"May I write this to [文件路径]？"。轻量级技能只需针对完整文档询问一次。 |
| **A3 — 改造模式** | 技能检测目标文件是否已存在，并提供更新特定章节的选项，而非覆盖整个文档。始终创建新文件的轻量级技能（quick-design）可豁免。 |
| **A4 — 正确层级的总监关卡** | 如果该技能定义了总监关卡（例如 CD-GDD-ALIGN、TD-ADR），则在正确的模式阈值（full/lean）下运行——不在 solo 模式下运行 |
| **A5 — 骨架优先** | 完整创作技能在填充内容之前先创建包含所有章节标题的文件骨架，以在会话中断时保留进度。轻量级技能可豁免。 |

> **完整创作技能**（必须通过全部 5 项度量）：`design-system`、`ux-design`、`art-bible`
> **轻量级创作技能**（A1、A2、A5 使用单稿模式；A3 对仅新建文件的技能豁免）：`quick-design`、`architecture-decision`、`create-architecture`
> **评审模式技能**（按评审度量评估）：`ux-review`

---

### `readiness`

**技能 (Skills)**：story-readiness, story-done

就绪 (Readiness) 技能在实现前后验证故事 (story)。它们必须产生
多维度的判定结果，并正确集成总监关卡模式。

| 度量 (Metric) | PASS (通过) 标准 |
|---|---|
| **RD1 — 多维度检查** | 技能检查 ≥3 个独立维度（例如设计、架构、范围、DoD），并分别报告每个维度 |
| **RD2 — 三级判定** | 判定层级清晰定义：READY/COMPLETE > NEEDS WORK/COMPLETE WITH NOTES > BLOCKED |
| **RD3 — BLOCKED 需要外部行动** | BLOCKED 判定仅用于故事作者无法单独解决的问题（例如 Proposed 状态的 ADR、无法解决的依赖关系） |
| **RD4 — 正确模式的总监关卡** | QL-STORY-READY 或 LP-CODE-REVIEW 关卡在 `full` 模式下生成，在 `lean`/`solo` 模式下跳过并注明跳过信息 |
| **RD5 — 下一故事交接** | 完成后，技能展示当前冲刺 (sprint) 中下一个 READY 状态的故事 |

---

### `pipeline`

**技能 (Skills)**：create-epics, create-stories, dev-story, create-control-manifest, propagate-design-change, map-systems

管线 (Pipeline) 技能产生其他技能将消费的工件。它们必须以正确的模式
编写文件，遵循层级/优先级顺序，并在写入前进行关卡审核。

| 度量 (Metric) | PASS (通过) 标准 |
|---|---|
| **P1 — 正确的输出模式** | 每个生成的文件遵循项目模板（EPIC.md、story 前置元数据等）；技能引用模板路径 |
| **P2 — 层级/优先级排序** | 生成史诗或故事的技能遵循层级顺序（核心 → 扩展 → 元）和优先级字段 |
| **P3 — 每个工件前的"May I write"** | 技能在创建每个输出文件前询问"May I write [工件]？"，而不是一次性批量批准所有文件 |
| **P4 — 正确层级的总监关卡** | 范围相关的关卡（PR-EPIC、QL-STORY-READY、LP-CODE-REVIEW 等）在 `full` 模式下运行，在 `lean`/`solo` 模式下跳过并注明 |
| **P5 — 先读后写** | 技能在生成工件之前先读取相关的 GDD/ADR/清单，以确保一致性 |

---

### `analysis`

**技能 (Skills)**：consistency-check, balance-check, content-audit, code-review, tech-debt, scope-check, estimate, perf-profile, asset-audit, security-audit, test-evidence-review, test-flakiness

分析 (Analysis) 技能扫描项目并呈现发现。它们在分析期间为只读模式，
并且在建议任何文件写入前必须征询许可。

| 度量 (Metric) | PASS (通过) 标准 |
|---|---|
| **AN1 — 只读扫描** | 分析阶段仅使用 Read/Glob/Grep 工具；扫描过程中不使用 Write 或 Edit |
| **AN2 — 结构化发现表** | 输出包含结构化的发现表或检查清单（不仅限于文字描述），每项发现附带严重性/优先级 |
| **AN3 — 不自动写入** | 任何建议的文件写入（例如技术债务登记表、修复补丁）都需经"May I write"同意 |
| **AN4 — 分析阶段无总监关卡** | 分析技能不生成总监关卡；它们为人工审查提供发现 |

---

### `team`

**技能 (Skills)**：team-combat, team-narrative, team-audio, team-level, team-ui, team-qa, team-release, team-polish, team-live-ops

团队 (Team) 技能编排多个专家代理以实现部门级任务。它们必须
生成正确的代理，并行运行独立代理，并立即上报阻塞问题。

| 度量 (Metric) | PASS (通过) 标准 |
|---|---|
| **T1 — 命名代理列表** | 技能明确命名它生成的代理及其顺序 |
| **T2 — 独立任务并行执行** | 输入互不依赖的代理并行生成（单条消息中包含多个 Task 调用） |
| **T3 — BLOCKED 上报** | 如果任何生成的代理返回 BLOCKED 或失败，技能立即上报并暂停依赖工作——绝不静默跳过 |
| **T4 — 收集所有判定后再继续** | 依赖阶段等待所有并行代理完成后才继续 |
| **T5 — 无参数时显示用法错误** | 如果缺少必要参数（例如功能名称），技能输出用法提示并停止，不生成代理 |

---

### `sprint`

**技能 (Skills)**：sprint-plan, sprint-status, milestone-review, retrospective, changelog, patch-notes

冲刺 (Sprint) 技能读取生产状态并生成报告或规划工件。
它们在特定模式阈值下具有 PR-SPRINT 或 PR-MILESTONE 关卡。

| 度量 (Metric) | PASS (通过) 标准 |
|---|---|
| **SP1 — 读取冲刺/里程碑状态** | 技能在生成输出前读取 `production/sprints/` 或 `production/milestones/` |
| **SP2 — 正确的冲刺关卡** | PR-SPRINT（用于规划）或 PR-MILESTONE（用于里程碑评审）关卡在 `full` 模式下运行，在 `lean`/`solo` 模式下跳过 |
| **SP3 — 结构化输出** | 输出使用一致的结构（速度表、风险列表、行动项），而非自由格式的文字 |
| **SP4 — 不自动提交** | 未经"May I write"同意，技能绝不写入冲刺文件或里程碑记录 |

---

### `utility`

**技能 (Skills)**：start, help, brainstorm, onboard, adopt, hotfix, prototype, localize, launch-checklist, release-checklist, smoke-check, soak-test, test-setup, test-helpers, regression-suite, qa-plan, bug-triage, bug-report, playtest-report, asset-spec, reverse-document, project-stage-detect, setup-engine, skill-test, skill-improve, day-one-patch，以及任何未归入上述类别的其他技能

工具 (Utility) 技能通过 7 项标准静态检查。如果它们恰好生成了总监关卡，
则关卡模式逻辑也必须正确。

| 度量 (Metric) | PASS (通过) 标准 |
|---|---|
| **U1 — 通过全部 7 项静态检查** | `/skill-test static [name]` 返回 COMPLIANT，0 个 FAIL |
| **U2 — 关卡模式正确（如适用）** | 如果技能生成了任何总监关卡，它读取评审模式并正确应用 full/lean/solo 逻辑 |

---

## 代理类别 (Agent Categories)

用于验证 `tests/agents/` 中的代理规格文件。

### `director`（总监）

**代理 (Agents)**：creative-director, technical-director, art-director, producer

| 度量 (Metric) | PASS (通过) 标准 |
|---|---|
| **D1 — 正确的判定词汇** | 返回 APPROVE（批准）/ CONCERNS（关切）/ REJECT（拒绝）（或领域等效：producer 使用 REALISTIC（可行）/ CONCERNS（关切）/ UNREALISTIC（不可行）） |
| **D2 — 尊重领域边界** | 不在其声明的领域之外做出具有约束力的决策 |
| **D3 — 冲突升级** | 当两个部门发生冲突时，升级至正确的上级（creative-director 或 technical-director），而非单方面裁决 |
| **D4 — Opus 模型层级** | 根据 coordination-rules.md，代理被分配 Opus 模型 |

### `lead`（主管）

**代理 (Agents)**：lead-programmer, qa-lead, narrative-director, audio-director, game-designer, systems-designer, level-designer

| 度量 (Metric) | PASS (通过) 标准 |
|---|---|
| **L1 — 领域判定** | 返回领域特定的判定（例如 lead-programmer 使用 FEASIBLE（可行）/ INFEASIBLE（不可行），qa-lead 使用 PASS（通过）/ FAIL（失败）） |
| **L2 — 升级至共享上级** | 领域外冲突升级至 creative-director（设计类）或 technical-director（技术类） |
| **L3 — Sonnet 模型层级** | 根据 coordination-rules.md，代理被分配 Sonnet 模型（默认） |

### `specialist`（专家）

**代理 (Agents)**：gameplay-programmer, ai-programmer, technical-artist, sound-designer, engine-programmer, tools-programmer, network-programmer, security-engineer, accessibility-specialist, ux-designer, ui-programmer, performance-analyst, prototyper, qa-tester, writer, world-builder

| 度量 (Metric) | PASS (通过) 标准 |
|---|---|
| **S1 — 停留在领域内** | 明确限定自身在其声明的领域内；将领域外的请求转交 |
| **S2 — 无跨领域约束性决策** | 不单方面决定属于其他专家的事项 |
| **S3 — 正确转交** | 领域外请求被重定向至正确的代理，而非静默拒绝 |

### `engine`（引擎）

**代理 (Agents)**：godot-specialist, godot-gdscript-specialist, godot-csharp-specialist, godot-shader-specialist, godot-gdextension-specialist, unity-specialist, unity-ui-specialist, unity-shader-specialist, unity-dots-specialist, unity-addressables-specialist, unreal-specialist, ue-blueprint-specialist, ue-gas-specialist, ue-umg-specialist, ue-replication-specialist

| 度量 (Metric) | PASS (通过) 标准 |
|---|---|
| **E1 — 版本感知** | 在建议 API 调用前引用 `docs/engine-reference/` 中的引擎版本；标记截止日期后风险 |
| **E2 — 文件路由** | 将文件类型路由至正确的子专家（例如 `.gdshader` → godot-shader-specialist，而非 godot-gdscript-specialist） |
| **E3 — 引擎特定模式** | 执行引擎特有的惯用法（例如 GDScript 静态类型、C# 属性导出、Blueprint 函数库） |

### `qa`（质量保证）

**代理 (Agents)**：qa-tester, qa-lead, security-engineer, accessibility-specialist

| 度量 (Metric) | PASS (通过) 标准 |
|---|---|
| **Q1 — 产出工件而非代码** | 主要输出是测试用例、错误报告或覆盖缺口——而非实现代码 |
| **Q2 — 证据格式** | 测试用例遵循项目的测试证据格式（根据 coding-standards.md 区分为单元/集成/视觉/UI） |
| **Q3 — 无范围蔓延** | 不提议新功能；将缺口标记为由人类决定 |

### `operations`（运维）

**代理 (Agents)**：devops-engineer, release-manager, live-ops-designer, community-manager, analytics-engineer, economy-designer, localization-lead

| 度量 (Metric) | PASS (通过) 标准 |
|---|---|
| **O1 — 领域所有权明确** | 代理描述明确声明其所有权范围（管线、发布、经济等） |
| **O2 — 转交实现** | 不编写游戏逻辑或引擎代码；委托至适当的专家 |
| **O3 — 工具集匹配角色** | 前置元数据中的 `allowed-tools` 与该角色的运维（而非编码）性质相匹配 |
