
# Claude Code Game Studios —— 完整工作流指南


> **如何使用 Agent 架构从零到发布一款游戏。**
>
> 本指南带你走过游戏开发的每一个阶段，使用 49-Agent 系统、73 个斜杠命令
> 和 12 个自动化钩子。假设你已安装 Claude Code 并从项目根目录工作。
>
> 流水线共 7 个阶段。每个阶段都有正式的关卡 (`/gate-check`)，必须通过
> 才能推进。权威的阶段序列定义在 `.claude/docs/workflow-catalog.yaml` 中，
> 由 `/help` 读取。

---

## 目录

1. [快速开始](#quick-start)
2. [阶段 1：概念](#phase-1-concept)
3. [阶段 2：系统设计](#phase-2-systems-design)
4. [阶段 3：技术搭建](#phase-3-technical-setup)
5. [阶段 4：预制作](#phase-4-pre-production)
6. [阶段 5：制作](#phase-5-production)
7. [阶段 6：打磨](#phase-6-polish)
8. [阶段 7：发布](#phase-7-release)
9. [横切关注点](#cross-cutting-concerns)
10. [附录 A：Agent 速查](#appendix-a-agent-quick-reference)
11. [附录 B：斜杠命令速查](#appendix-b-slash-command-quick-reference)
12. [附录 C：常见工作流](#appendix-c-common-workflows)

---

## Quick Start

### 你需要什么

开始之前，请确保你有：

- **Claude Code** 已安装并能工作
- **Git** 配 Git Bash（Windows）或标准终端（Mac/Linux）
- **jq**（可选但推荐 —— 缺失时钩子会回退到 `grep`）
- **Python 3**（可选 —— 部分钩子用它做 JSON 校验）

### 第 1 步：克隆并打开

```bash
git clone <repo-url> my-game
cd my-game
```

### 第 2 步：运行 /start

若是首次会话：

```
/start
```

此引导式入门会询问你当前所处的位置，并把路由到正确阶段：

- **路径 A** —— 还没想法：路由到 `/brainstorm`
- **路径 B** —— 模糊想法：带种子路由到 `/brainstorm`
- **路径 C** —— 清晰概念：路由到 `/setup-engine` 和 `/map-systems`
- **路径 D1** —— 已有项目、产物少：正常流程
- **路径 D2** —— 已有项目、GDD/ADR 已存在：先跑 `/project-stage-detect`
  再跑 `/adopt` 做棕地迁移

### 第 3 步：验证钩子是否工作

启动一个新的 Claude Code 会话。你应看到 `session-start.sh` 钩子的输出：

```
=== Claude Code Game Studios -- Session Context ===
Branch: main
Recent commits:
  abc1234 Initial commit
===================================
```

若看到此输出，钩子工作正常。若没有，检查 `.claude/settings.json`，
确认钩子路径对你的操作系统正确。

### 第 4 步：随时寻求帮助

任何时候运行：

```
/help
```

它会从 `production/stage.txt` 读取你当前阶段，检查哪些产物已存在，
并告诉你下一步该做什么。它会区分必需 (REQUIRED) 与可选 (OPTIONAL) 的下一步。

### 第 5 步：创建你的目录结构

目录按需创建。系统期望以下布局：

```
src/                  # 游戏源代码
  core/               # 引擎/框架代码
  gameplay/           # 玩法系统
  ai/                 # AI 系统
  networking/         # 多人代码
  ui/                 # UI 代码
  tools/              # 开发工具
assets/               # 游戏资产
  art/                # 精灵、模型、贴图
  audio/              # 音乐、SFX
  vfx/                # 粒子效果
  shaders/            # 着色器文件
  data/               # JSON 配置/平衡数据
design/               # 设计文档
  gdd/                # 游戏设计文档
  narrative/          # 故事、背景、对白
  levels/             # 关卡设计文档
  balance/            # 平衡性表格与数据
  ux/                 # UX 规格
docs/                 # 技术文档
  architecture/       # 架构决策记录
  api/                # API 文档
  postmortems/        # 复盘
tests/                # 测试套件
prototypes/           # 一次性原型
production/           # 冲刺计划、里程碑、发布
  sprints/
  milestones/
  releases/
  epics/              # 史诗与故事文件（来自 /create-epics + /create-stories）
  playtests/          # 试玩报告
  session-state/      # 临时会话状态（gitignored）
  session-logs/       # 会话审计留痕（gitignored）
```

> **提示：** 你不需要在第一天就把所有目录都建好。到达需要它们的阶段时
> 再创建。重要的是创建时遵循此结构，因为**规则系统**会根据文件路径
> 强制执行标准。`src/gameplay/` 下的代码适用玩法规则，`src/ai/` 下的
> 代码适用 AI 规则，以此类推。

---

## Phase 1: Concept

### 本阶段发生什么

你从"没想法"或"模糊想法"出发，产出一份结构化的游戏概念文档，
包含明确的支柱与玩家旅程。这里你要弄清楚**做什么**以及**为什么**。

### 阶段 1 流水线

```
/brainstorm  -->  game-concept.md  -->  /design-review  -->  /setup-engine
     |                                        |                    |
     v                                        v                    v
  10 个概念       带支柱、MDA、              概念文档            引擎锁定在
  MDA 分析        核心循环、USP 的          校验                technical-preferences.md
  玩家动机        概念文档
                                                                   |
                                                                   v
                                                             /prototype
                                                       （概念原型 —— 1-3 天）
                                                        PROCEED ↓     PIVOT → /brainstorm
                                                                   |
                                                                   v (PROCEED)
                                                             /map-systems
                                                                   |
                                                                   v
                                                            systems-index.md
                                                            （全部系统、依赖、
                                                             优先级层级）
```

### 步骤 1.1：用 /brainstorm 头脑风暴

这是你的起点。运行头脑风暴技能：

```
/brainstorm
```

或带类型提示：

```
/brainstorm roguelike deckbuilder
```

**会发生什么：** 头脑风暴技能用专业工作室技法引导你走完协作式的 6 阶段
构思过程：

1. 询问你的兴趣、主题与约束
2. 生成 10 个概念种子，配 MDA（机制、动态、美学）分析
3. 你挑 2-3 个最爱的做深度分析
4. 进行玩家动机映射与受众定位
5. 你选出获胜概念
6. 形式化为 `design/gdd/game-concept.md`

概念文档包含：

- 电梯演讲（一句话）
- 核心幻想（玩家想象自己在做什么）
- MDA 拆解
- 目标受众（Bartle 类型、人口统计）
- 核心循环图
- 独特卖点 (USP)
- 可比作品与差异化
- 游戏支柱（3-5 条不可妥协的设计价值）
- 反支柱（游戏有意避免的东西）

### 步骤 1.2：审阅概念（可选但推荐）

```
/design-review design/gdd/game-concept.md
```

在继续之前校验结构与完整性。

### 步骤 1.3：选择你的引擎

```
/setup-engine
```

或指定引擎：

```
/setup-engine godot 4.6
```

**/setup-engine 做什么：**

- 用命名约定、性能预算和引擎特定默认值填充 `.claude/docs/technical-preferences.md`
- 检测知识盲区（引擎版本比 LLM 训练数据新）并建议交叉引用
  `docs/engine-reference/`
- 在 `docs/engine-reference/` 创建版本锁定的参考文档

**为何重要：** 一旦设定引擎，系统就知道该用哪些引擎专家 Agent。
若你选 Godot，`godot-specialist`、`godot-gdscript-specialist`、
`godot-shader-specialist` 等 Agent 就成为你的首选专家。

### 步骤 1.4：把概念拆解为系统

在写个别 GDD 之前，枚举你游戏所需的全部系统：

```
/map-systems
```

这会创建 `design/gdd/systems-index.md` —— 一份主追踪文档，它：

- 列出你游戏所需的每一个系统（战斗、移动、UI 等）
- 映射系统间依赖
- 分配优先级层级（MVP、垂直切片、Alpha、完整愿景）
- 确定设计顺序（基础 > 核心 > 功能 > 表现 > 打磨）

此步骤在进入阶段 2 之前是**必需的**。来自 155 份游戏复盘的研究证实，
跳过系统枚举在制作期会多花 5-10 倍成本。

### 阶段 1 关卡

```
/gate-check concept
```

**通过要求：**

- 引擎已在 `technical-preferences.md` 中配置
- `design/gdd/game-concept.md` 存在并含支柱
- `design/gdd/systems-index.md` 存在并含依赖排序

**裁决：** PASS / CONCERNS / FAIL。CONCERNS 在承认风险的前提下可放行。
FAIL 阻断推进。

---

## Phase 2: Systems Design

### 本阶段发生什么

你创建所有定义游戏如何运作的设计文档。此时尚不写代码 —— 纯设计。
系统索引中识别的每个系统都有自己的 GDD，逐章创作、个别审阅，
然后所有 GDD 一起做一致性交叉检查。

### 阶段 2 流水线

```
/map-systems next  -->  /design-system  -->  /design-review
       |                     |                     |
       v                     v                     v
  从 systems-index      逐章节                校验 8 个
  选下一个系统          GDD 创作              必填章节
                       （增量写入）          APPROVED/NEEDS REVISION
       |
       |  （对每个 MVP 系统重复）
       v
/review-all-gdds
       |
       v
  跨 GDD 一致性 + 设计理论审阅
  PASS / CONCERNS / FAIL
```

### 步骤 2.1：创作系统 GDD

按依赖顺序用引导式工作流设计每个系统：

```
/map-systems next
```

这会挑选最高优先级且尚未设计的系统，交给 `/design-system`，
后者引导你逐章创建其 GDD。

也可以直接设计某个具体系统：

```
/design-system combat-system
```

**/design-system 做什么：**

1. 读取你的游戏概念、系统索引，以及任何上下游 GDD
2. 运行技术可行性预检（领域映射 + 可行性简报）
3. 一次带你走完 8 个必填 GDD 章节中的一个
4. 每章节遵循：背景 > 提问 > 选项 > 决策 > 草案 > 批准 > 写入
5. 每章节批准后立即写入文件（防崩溃）
6. 标记与已批准 GDD 的冲突
7. 按类别路由到专家 Agent（systems-designer 管数学、economy-designer
   管经济、narrative-director 管故事系统）

**8 个必填 GDD 章节：**

| # | 章节 | 这里写什么 |
|---|---------|---------------|
| 1 | **概览 (Overview)** | 系统的一段式摘要 |
| 2 | **玩家幻想 (Player Fantasy)** | 玩家使用此系统时想象/感受到什么 |
| 3 | **详细规则 (Detailed Rules)** | 明确无歧义的机制规则 |
| 4 | **公式 (Formulas)** | 每个计算，含变量定义与取值范围 |
| 5 | **边缘情况 (Edge Cases)** | 奇怪情境下发生什么？显式解决。 |
| 6 | **依赖 (Dependencies)** | 此系统连接到哪些其他系统（双向） |
| 7 | **调参旋钮 (Tuning Knobs)** | 哪些值设计师可安全改动，及安全范围 |
| 8 | **验收标准 (Acceptance Criteria)** | 如何测试它是否奏效？具体、可度量。 |

外加一个**游戏手感 (Game Feel)** 章节：手感参考、输入响应（ms/帧）、
动画手感目标（启动/激活/恢复）、冲击瞬间、重量感画像。

### 步骤 2.2：审阅每个 GDD

在下一个系统开始前，校验当前这个：

```
/design-review design/gdd/combat-system.md
```

检查全部 8 个章节的完整性、公式清晰度、边缘情况解决、双向依赖、
以及可测试的验收标准。

**裁决：** APPROVED / NEEDS REVISION / MAJOR REVISION。只有 APPROVED
的 GDD 应继续。

### 步骤 2.3：无需完整 GDD 的小改动

对于调整改动、小幅新增或不值得写完整 GDD 的微调：

```
/quick-design "侧翼攻击附加 10% 伤害加成"
```

这会在 `design/quick-specs/` 创建轻量规格，而非完整 8 章节 GDD。
用于调参、改数值、小新增。

### 步骤 2.4：跨 GDD 一致性审阅

所有 MVP 系统 GDD 个别批准后：

```
/review-all-gdds
```

这会同时读取所有 GDD 并跑两个分析阶段：

**阶段 1 —— 跨 GDD 一致性：**
- 依赖双向性（A 引用 B，B 是否引用 A？）
- 系统间规则矛盾
- 对已重命名或已移除系统的陈旧引用
- 归属冲突（两个系统声称同一职责）
- 公式取值范围兼容性（系统 A 的输出是否适配系统 B 的输入？）
- 验收标准交叉检查

**阶段 2 —— 设计理论（游戏设计整体性）：**
- 竞争性进度循环（两个系统是否争夺同一奖励空间？）
- 认知负荷（同时活跃系统超过 4 个？）
- 主导策略（一种做法使其他全部失效？）
- 经济循环分析（来源与 sink 是否平衡？）
- 跨系统难度曲线一致性
- 支柱对齐与反支柱违背
- 玩家幻想连贯性

**输出：** `design/gdd/gdd-cross-review-[date].md`，附裁决。

### 步骤 2.5：叙事设计（如适用）

若你的游戏有故事、背景或对白，此时构建：

1. **世界构建** —— 用 `world-builder` 定义阵营、历史、地理和世界规则
2. **故事结构** —— 用 `narrative-director` 设计故事弧、角色弧和叙事节拍
3. **角色卡** —— 用 `narrative-character-sheet.md` 模板

### 阶段 2 关卡

```
/gate-check systems-design
```

**通过要求：**

- `systems-index.md` 中所有 MVP 系统 `Status: Approved`
- 每个 MVP 系统都有一份已审阅的 GDD
- 存在跨 GDD 审阅报告（`design/gdd/gdd-cross-review-*.md`）
  且裁决为 PASS 或 CONCERNS（非 FAIL）

---

## Phase 3: Technical Setup

### 本阶段发生什么

你做出关键技术决策，以架构决策记录 (ADR) 文档化，通过审阅验证，
并产出给程序员扁平、可执行规则的控制清单。你还建立 UX 基础。

### 阶段 3 流水线

```
/create-architecture  -->  /architecture-decision (x N)  -->  /architecture-review
        |                          |                                   |
        v                          v                                   v
  覆盖所有系统的             每个决策的 ADR                   校验完整性、
  主架构文档                 位于 docs/architecture/          依赖排序、
  architecture.md            adr-*.md                         引擎兼容性
                                                                      |
                                                                      v
                                                         /create-control-manifest
                                                                      |
                                                                      v
                                                         扁平程序员规则
                                                         docs/architecture/
                                                         control-manifest.md
        本阶段还包含：
        -------------------
        /ux-design  -->  /ux-review
        无障碍需求文档
        交互模式库
```

### 步骤 3.1：主架构文档

```
/create-architecture
```

在 `docs/architecture/architecture.md` 创建覆盖系统边界、数据流和
集成点的总架构文档。

### 步骤 3.2：架构决策记录 (ADR)

对每个重大技术决策：

```
/architecture-decision "NPC AI 用状态机还是行为树"
```

**会发生什么：** 技能引导你创建一份 ADR，包含：
- 背景与决策驱动因素
- 全部选项及优缺点和引擎兼容性
- 所选方案及理由
- 后果（正面、负面、风险）
- 依赖（Depends On、Enables、Blocks、Ordering Note）
- 所应对的 GDD 需求（按 TR-ID 关联）

ADR 经历生命周期：Proposed > Accepted > Superseded/Deprecated。

**关卡检查前至少需要 3 份基础层 (Foundation) ADR。**

**改造已有 ADR：** 若你已有棕地项目的 ADR：

```
/architecture-decision retrofit docs/architecture/adr-005.md
```

这会检测缺少哪些模板章节并只补那些，绝不覆盖已有内容。

### 步骤 3.3：架构审阅

```
/architecture-review
```

一起校验所有 ADR：
- ADR 依赖的拓扑排序（检测环）
- 引擎兼容性核验
- GDD 修订标记（根据 ADR 选择标记需更新的 GDD 章节）
- TR-ID 注册表维护（`docs/architecture/tr-registry.yaml`）

### 步骤 3.4：控制清单

```
/create-control-manifest
```

取所有 Accepted ADR 并产出扁平程序员规则表：

```
docs/architecture/control-manifest.md
```

包含按代码层组织的 必须做 (Required) 模式、禁止做 (Forbidden) 模式和
护栏 (Guardrails)。后续创建的故事会嵌入清单版本日期，以便检测过期。

### 步骤 3.5：无障碍需求

用模板创建 `design/accessibility-requirements.md`。承诺一个等级
（基础 / 标准 / 全面 / 示范）并填写四轴功能矩阵
（视觉、运动、认知、听觉）。

此文档在阶段 3 是必需的，因为 UX 规格（阶段 4 写）会引用此等级 ——
它是设计前置条件，而非 UX 交付物。

### 阶段 3 关卡

```
/gate-check technical-setup
```

**通过要求：**

- `docs/architecture/architecture.md` 存在
- 至少 3 份 ADR 存在且为 Accepted
- 存在架构审阅报告
- `docs/architecture/control-manifest.md` 存在
- `design/accessibility-requirements.md` 存在

---

## Phase 4: Pre-Production

### 本阶段发生什么

你为关键屏幕创建 UX 规格，为高风险机制做原型，把设计文档转为可实现的
故事，规划首个冲刺，并构建一个垂直切片 (Vertical Slice) 证明核心循环
确实好玩。

### 阶段 4 流水线

```
/ux-design  -->  /vertical-slice  -->  /create-epics  -->  /create-stories  -->  /sprint-plan
    |                   |                   |                   |                       |
    v                   v                   v                   v                       v
  UX 规格            生产级                史诗文件在          故事文件在              首个冲刺含
  design/ux/         端到端构建            production/         production/             已排优先级的故事
                    位于 prototypes/      epics/*/EPIC.md     epics/*/story-*.md      production/sprints/
                    PROCEED/PIVOT/KILL   （每模块一份）       （每个行为一份）         sprint-*.md
    |                                                          |
    v                                                          v
 /ux-review                                             /story-readiness
 （在史诗之前                                           （每个故事被领取前校验）
  校验规格）
                                                               |
                                                               v
                                                           /dev-story
                                                         （实现故事，
                                                          路由到对的 Agent）
```

### 步骤 4.1：关键屏幕的 UX 规格

在写史诗之前，创建 UX 规格，让故事作者知道存在哪些屏幕、必须支持
哪些玩家交互。

**UX 规格：**

```
/ux-design main-menu
/ux-design core-gameplay-hud
```

三种模式：屏幕/流程、HUD、交互模式。输出到 `design/ux/`。每份规格包含：
玩家需求、布局区域、状态、交互映射、数据需求、引发事件、无障碍、本地化。

读取你在阶段 3 写的 `accessibility-requirements.md` 以及
`technical-preferences.md` 中的输入方式配置，以驱动无障碍与输入覆盖
检查 —— 无需逐屏重新指定。

> **提示：** `/design-system` 会为每个有 UI 需求的系统生成一个 📌 UX 标记。
> 把这些标记当作"哪些屏幕需要规格"的清单。

**交互模式库：**

```
/ux-design interaction-patterns
```

创建 `design/ux/interaction-patterns.md` —— 16 种标准控件加游戏特定模式
（背包槽、技能图标、HUD 条、对话框等），含动画与音效标准。

**UX 审阅：**

```
/ux-review all
```

校验 UX 规格的 GDD 对齐与无障碍等级合规。
产出 APPROVED / NEEDS REVISION / MAJOR REVISION NEEDED 裁决。

### 步骤 4.2：构建垂直切片

垂直切片是在投入全面制作之前，证明你能端到端构建完整游戏循环的
生产级证据。

```
/vertical-slice
```

**它证明什么：** 一个玩家从零开始，在没有开发者引导的情况下，能在几分钟内
体验到核心幻想吗？

**它构建什么：** 一个接近生产质量的可玩构建，覆盖至少一个完整的
[起始 → 挑战 → 解决] 循环。使用真实架构层、真实命名约定、无硬编码值 ——
但非最终美术或音频。这不是像概念原型那样的一次性产物；它演示的是
生产流水线的可行性。

**关于概念原型的说明：** 若你在阶段 1（概念）跑过 `/prototype`，
你已经验证了核心想法有趣。垂直切片现在验证你能正确地把它建出来。
它们回答的是不同问题。若你跳过了概念原型，现在是个合理的时机先跑一个，
再投入完整切片。

**裁决：** 垂直切片产出 PROCEED / PIVOT / KILL 裁决。
- **PROCEED** → 进入步骤 4.3（史诗与故事）
- **PIVOT** → 用 `/design-system [mechanic]` 修订受影响 GDD，再重跑 `/vertical-slice`
- **KILL** → 带着所学回到 `/brainstorm`

### 步骤 4.3：从设计产物创建史诗与故事

```
/create-epics layer: foundation
/create-stories [epic-slug]   # 对每个史诗重复
/create-epics layer: core
/create-stories [epic-slug]   # 对每个核心史诗重复
```

`/create-epics` 读取你的 GDD、ADR 和架构来定义史诗范围 —— 每个架构
模块一个史诗。然后 `/create-stories` 把每个史诗拆成可实现的
故事文件，放在 `production/epics/[slug]/`。每个故事嵌入：
- GDD 需求引用（TR-ID，不是引文 —— 保持常新）
- ADR 引用（仅来自 Accepted ADR；Proposed ADR 会导致 `Status: Blocked`）
- 控制清单版本日期（用于检测过期）
- 引擎特定实现说明
- 来自 GDD 的验收标准

故事就绪后，运行 `/dev-story [story-path]` 实现一个 —— 它会自动路由
到正确的程序员 Agent。

### 步骤 4.4：领取前校验故事

```
/story-readiness production/epics/combat/story-combat-damage-calc.md
```

检查：设计完整性、架构覆盖、范围清晰、完成定义。裁决：
READY / NEEDS WORK / BLOCKED。

### 步骤 4.5：工作量估算

```
/estimate production/epics/combat/story-combat-damage-calc.md
```

提供带风险评估的工作量估算。

### 步骤 4.6：规划首个冲刺

```
/sprint-plan new
```

**会发生什么：** `producer` Agent 协作进行冲刺规划：
- 询问冲刺目标与可用时间
- 把目标拆成 必须有 / 应该有 / 锦上添花 的任务
- 识别风险与阻塞
- 创建 `production/sprints/sprint-01.md`
- 填充 `production/sprint-status.yaml`（机器可读的故事追踪）

### 步骤 4.7：垂直切片（硬关卡）

进入制作阶段之前，你必须构建并试玩一个垂直切片：

- 一个完整端到端核心循环，可从头玩到尾
- 代表性质量（并非全部占位）
- 至少 3 个会话中无引导游玩
- 写出试玩报告（`/playtest-report`）

这是**硬关卡** —— 若无人无引导游玩过构建，`/gate-check` 会自动 FAIL。

### 阶段 4 关卡

```
/gate-check pre-production
```

**通过要求：**

- `design/ux/` 中至少 1 份已审阅 UX 规格
- UX 审阅完成（APPROVED 或 NEEDS REVISION 并附记录的风险）
- 至少 1 个带 README 的原型
- `production/epics/[epic-slug]/` 中存在故事文件
- 至少 1 份冲刺计划
- 至少 1 份试玩报告（垂直切片在 3+ 个会话中玩过）

---

## Phase 5: Production

### 本阶段发生什么

这是核心制作循环。你以冲刺（通常 1-2 周）为单位工作，逐故事实现功能，
追踪进度，并通过结构化的完成审阅关闭故事。此阶段重复直至你的游戏
内容完成。

### 阶段 5 流水线（每个冲刺）

```
/sprint-plan new  -->  /story-readiness  -->  implement  -->  /story-done
       |                     |                    |                |
       v                     v                    v                v
  冲刺已创建            故事已校验            代码已写         8 阶段审阅：
  sprint-status.yaml    READY 裁决            测试通过         校验标准、
  已填充                                                      检查偏离、
                                                             更新故事状态
       |
       |  （逐故事重复直至冲刺完成）
       v
  /sprint-status  （随时 30 行快照）
  /scope-check    （若范围在膨胀）
  /retrospective  （冲刺结束时）
```

### 步骤 5.1：故事生命周期

制作阶段围绕**故事生命周期**展开：

```
/story-readiness  -->  implement  -->  /story-done  -->  下一个故事
```

**1. 故事就绪：** 领取故事前，校验它：

```
/story-readiness production/epics/combat/story-combat-damage-calc.md
```

检查设计完整性、架构覆盖、ADR 状态（ADR 仍 Proposed 则阻断）、
控制清单版本（过期则警告）、范围清晰度。裁决：READY / NEEDS WORK / BLOCKED。

**2. 实现：** 与相应 Agent 协作：

- `gameplay-programmer` 玩法系统
- `engine-programmer` 核心引擎工作
- `ai-programmer` AI 行为
- `network-programmer` 多人
- `ui-programmer` UI 代码
- `tools-programmer` 开发工具

所有 Agent 遵循协作协议：读设计文档、提澄清性问题、给架构选项、
获你批准、再实现。

**3. 故事完成：** 故事完成时：

```
/story-done production/epics/combat/story-combat-damage-calc.md
```

这跑一个 8 阶段完成审阅：
1. 找到并读取故事文件
2. 加载引用的 GDD、ADR 和控制清单
3. 校验验收标准（可自动检查、手动、延期）
4. 检查 GDD/ADR 偏离（BLOCKING / ADVISORY / OUT OF SCOPE）
5. 提示做代码审阅
6. 生成完成报告（COMPLETE / COMPLETE WITH NOTES / BLOCKED）
7. 更新故事 `Status: Complete` 及完成备注
8. 呈现下一个就绪故事

审阅中发现的技术债记入 `docs/tech-debt-register.md`。

### 步骤 5.2：冲刺追踪

随时检查进度：

```
/sprint-status
```

从 `production/sprint-status.yaml` 读取的 30 行快速快照。

若范围在膨胀：

```
/scope-check production/sprints/sprint-03.md
```

把当前范围与原计划对比，标记范围增长，建议裁剪。

### 步骤 5.3：内容追踪

```
/content-audit
```

把 GDD 指定的内容与已实现内容对比。及早发现内容缺口。

### 步骤 5.4：设计变更传播

GDD 在故事已创建后变更时：

```
/propagate-design-change design/gdd/combat-system.md
```

对 GDD 做 git-diff，找受影响 ADR，生成影响报告，
并带你走 Superseded/更新/保留 的决策。

### 步骤 5.5：多系统功能（团队编排）

对于跨多个领域的功能，用团队技能：

```
/team-combat "带持续回复和净化的治疗技能"
/team-narrative "第二幕故事内容"
/team-ui "背包界面重设计"
/team-level "森林地牢关卡"
/team-audio "战斗音频通版"
```

每个团队技能协调一个 6 阶段协作工作流：
1. **设计** —— game-designer 提问、给选项
2. **架构** —— lead-programmer 提出代码结构
3. **并行实现** —— 专家同时工作
4. **集成** —— gameplay-programmer 把一切接起来
5. **验证** —— qa-tester 对照验收标准跑
6. **报告** —— 协调者汇总状态

编排是自动化的，但**决策点仍归你**。

### 步骤 5.6：冲刺回顾与下一个冲刺

冲刺结束时：

```
/retrospective
```

分析计划 vs 完成、速率、阻塞和可执行改进。

然后规划下一个冲刺：

```
/sprint-plan new
```

### 步骤 5.7：里程碑审阅

在里程碑检查点：

```
/milestone-review "alpha"
```

产出功能完整性、质量指标、风险评估和 go/no-go 建议。

### 阶段 5 关卡

```
/gate-check production
```

**通过要求：**

- 所有 MVP 故事完成
- 试玩：3 个会话覆盖新玩家、中期和难度曲线
- 趣味假设已验证
- 试玩数据中无困惑循环

---

## Phase 6: Polish

### 本阶段发生什么

你的游戏功能已完成。现在让它变好。此阶段聚焦于性能、平衡、无障碍、
音频、视觉打磨和试玩。

### 阶段 6 流水线

```
/perf-profile  -->  /balance-check  -->  /asset-audit  -->  /playtest-report (x3)
       |                  |                    |                    |
       v                  v                    v                    v
  分析 CPU/GPU         分析公式与           校验命名、            覆盖：新玩家、
  内存，优化瓶颈       数据，找出           格式、大小            中期、难度曲线
                      破碎的进度

  /tech-debt  -->  /team-polish
       |                |
       v                v
  追踪并            协调式通版：
  排序债务项        性能 + 美术 +
                   音频 + UX + QA
```

### 步骤 6.1：性能分析

```
/perf-profile
```

引导你走结构化性能分析：
- 建立目标（FPS、内存、平台）
- 按影响排序识别瓶颈
- 生成可执行的优化任务，附代码位置和预期收益

### 步骤 6.2：平衡分析

```
/balance-check assets/data/combat_damage.json
```

分析平衡数据中的统计离群值、破碎进度曲线、退化策略和经济失衡。

### 步骤 6.3：资产审计

```
/asset-audit
```

校验全部资产的命名约定、文件格式标准和大小预算。

### 步骤 6.4：试玩（必需：3 个会话）

```
/playtest-report
```

生成结构化试玩报告。需要 3 个会话，覆盖：
- 新玩家体验
- 中期系统
- 难度曲线

### 步骤 6.5：技术债评估

```
/tech-debt
```

扫描 TODO/FIXME/HACK 注释、代码重复、过于复杂的函数、缺失测试、
过时依赖。每项分类并排序。

### 步骤 6.6：协调式打磨通版

```
/team-polish "combat system"
```

并行协调 4 位专家：
1. 性能优化 (performance-analyst)
2. 视觉打磨 (technical-artist)
3. 音频打磨 (sound-designer)
4. 手感/弹性 (gameplay-programmer + technical-artist)

你设优先级；团队在每一步获你批准后执行。

### 步骤 6.7：本地化与无障碍

```
/localize src/
```

扫描硬编码字符串、破坏翻译的字符串拼接、未考虑文本扩展的文本、
以及缺失的 locale 文件。

无障碍按阶段 3 无障碍需求文档承诺的等级审计。

### 阶段 6 关卡

```
/gate-check polish
```

**通过要求：**

- 至少 3 份试玩报告
- 协调式打磨通版已完成（`/team-polish`）
- 无阻塞性能问题
- 无障碍等级要求已满足

---

## Phase 7: Release

### 本阶段发生什么

你的游戏已打磨、测试并就绪。现在发布它。

### 阶段 7 流水线

```
/release-checklist  -->  /launch-checklist  -->  /team-release
        |                       |                      |
        v                       v                      v
  跨代码、内容、           完整的跨部门              协调：
  商店、法律的             校验（每个部门            构建、QA 签字、
  发布前校验               的 Go/No-Go）             部署、发布
                    另含：/changelog、/patch-notes、/hotfix
```

### 步骤 7.1：发布清单

```
/release-checklist v1.0.0
```

生成全面的发布前清单，覆盖：
- 构建校验（所有平台编译并运行）
- 认证要求（平台特定）
- 商店元数据（描述、截图、宣传片）
- 法律合规（EULA、隐私政策、分级）
- 存档兼容性
- 分析校验

### 步骤 7.2：发布就绪（完整校验）

```
/launch-checklist
```

完整跨部门校验：

| 部门 | 检查什么 |
|-----------|---------------|
| **工程** | 构建稳定性、崩溃率、内存泄漏、加载时间 |
| **设计** | 功能完整性、教程流程、难度曲线 |
| **美术** | 资产质量、缺失贴图、LOD 层级 |
| **音频** | 缺失音效、混音电平、空间音频 |
| **QA** | 按严重度统计的开放 bug 数、回归套件通过率 |
| **叙事** | 对白完整性、背景一致性、错别字 |
| **本地化** | 全部字符串已翻译、无截断、locale 测试 |
| **无障碍** | 合规清单、辅助功能测试 |
| **商店** | 元数据完整、截图已批、定价已设 |
| **市场** | 媒体包就绪、发布宣传片、社交媒体已排期 |
| **社区** | 补丁说明草稿、FAQ 已备、支持渠道就绪 |
| **基础设施** | 服务器已扩容、CDN 已配置、监控已激活 |
| **法务** | EULA 定稿、隐私政策、COPPA/GDPR 合规 |

每项获得一个 **Go / No-Go** 状态。全部必须 Go 才能发布。

### 步骤 7.3：生成面向玩家的内容

```
/patch-notes v1.0.0
```

从 git 历史和冲刺数据生成玩家友好的补丁说明。
把开发者语言翻译成玩家语言。

```
/changelog v1.0.0
```

生成内部 changelog（更技术性，给团队用）。

### 步骤 7.4：协调发布

```
/team-release
```

协调 release-manager、QA 和 DevOps 走过：
1. 发布前校验
2. 构建管理
3. 最终 QA 签字
4. 部署准备
5. Go/No-Go 决策

### 步骤 7.5：发布

推送到 `main` 或 `develop` 时 `validate-push` 钩子会警告你。
这是有意的 —— 发布推送应当审慎：

```bash
git tag v1.0.0
git push origin main --tags
```

### 步骤 7.6：发布后

**热修工作流**，用于关键生产 bug：

```
/hotfix "玩家背包超过 99 件物品时丢失存档"
```

绕过正常冲刺流程，但留有完整审计留痕：
1. 创建热修分支
2. 实现修复
3. 确保回移植到开发分支
4. 记录事件

**复盘**，在发布稳定后：

```
请 Claude 用模板创建复盘，模板位于
.claude/docs/templates/post-mortem.md
```

---

## Cross-Cutting Concerns

这些主题横跨所有阶段。

### 总监审阅模式

总监关卡是在关键工作流步骤审阅你工作的专家 Agent。
默认在每个检查点运行。你可以控制获得多少审阅。

**在 `/start` 期间一次性设定你的审阅强度。** 保存到
`production/review-mode.txt`。

| 模式 | 运行什么 | 适合 |
|------|-----------|----------|
| `full` | 每步都跑全部总监关卡 | 新项目、学习系统 |
| `lean` | 仅阶段切换时跑总监（`/gate-check`） | 老练开发者 |
| `solo` | 不做总监审阅 | 游戏 jam、原型、最大速度 |

**单次运行覆盖**，不改全局设置：

```
/brainstorm space horror --review full
/architecture-decision --review solo
```

`--review` 标志对所有使用关卡的技能生效。随时直接编辑
`production/review-mode.txt` 或重跑 `/start` 改全局模式。

完整关卡定义与检查模式：`.claude/docs/director-gates.md`

---

### 协作协议

本系统是**用户驱动协作式**的，非自主。

**模式：** 提问 > 选项 > 决策 > 草案 > 批准

每次 Agent 交互都遵循此模式：
1. Agent 提出澄清性问题
2. Agent 给出 2-4 个带权衡与理由的选项
3. 你决策
4. Agent 依据你的决策起草
5. 你审阅并细化
6. Agent 在写入前询问"可以把它写入 [filepath] 吗？"

完整协议与示例见 `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`。

### AskUserQuestion 工具

Agent 用 `AskUserQuestion` 工具做结构化选项呈现。
模式是"先解释再捕获"：先在对话文本中给完整分析，再用干净的 UI 选择器
捕获决策。用于设计选择、架构决策和战略问题。不用于开放式探索问题
或简单的是/否确认。

### Agent 协调（3 层层级）

```
第 1 层（总监）：    creative-director, technical-director, producer
                                          |
第 2 层（主管）：    game-designer, lead-programmer, art-director,
                   audio-director, narrative-director, qa-lead,
                   release-manager, localization-lead
                                          |
第 3 层（专家）：    gameplay-programmer, engine-programmer,
                   ai-programmer, network-programmer, ui-programmer,
                   tools-programmer, systems-designer, level-designer,
                   economy-designer, world-builder, writer,
                   technical-artist, sound-designer, ux-designer,
                   qa-tester, performance-analyst, devops-engineer,
                   analytics-engineer, accessibility-specialist,
                   live-ops-designer, prototyper, security-engineer,
                   community-manager, godot-specialist,
                   godot-gdscript-specialist, godot-shader-specialist,
                   godot-csharp-specialist, godot-gdextension-specialist,
                   unity-specialist, unity-dots-specialist,
                   unity-shader-specialist, unity-addressables-specialist,
                   unity-ui-specialist, unreal-specialist,
                   ue-blueprint-specialist, ue-gas-specialist,
                   ue-replication-specialist, ue-umg-specialist
```

**协调规则：**
- 垂直委派：总监 > 主管 > 专家。复杂决策绝不跨层。
- 横向咨询：同层 Agent 可互相咨询，但不得在自身领域外做约束性决策。
- 冲突解决：设计冲突交 `creative-director`。技术冲突交 `technical-director`。
  范围冲突交 `producer`。
- 不得单方面跨领域改动。

### 自动化钩子（安全网）

系统有 12 个自动运行的钩子：

| 钩子 | 触发 | 做什么 |
|------|---------|-------------|
| `session-start.sh` | 会话开始 | 显示分支、近期提交、检测 active.md 以恢复 |
| `detect-gaps.sh` | 会话开始 | 检测新项目（无引擎、无概念）并建议 `/start` |
| `pre-compact.sh` | 压缩前 | 把会话状态倾倒进对话以自动恢复 |
| `post-compact.sh` | 压缩后 | 提醒 Claude 从 `active.md` 恢复会话状态 |
| `notify.sh` | 通知事件 | 通过 PowerShell 显示 Windows toast 通知 |
| `validate-commit.sh` | 提交前 | 检查设计文档引用、有效 JSON、无硬编码值 |
| `validate-push.sh` | 推送前 | 推送到 main/develop 时警告 |
| `validate-assets.sh` | 提交前 | 检查资产命名与大小 |
| `validate-skill-change.sh` | 技能文件写入后 | 建议在 `.claude/skills/` 改动后跑 `/skill-test` |
| `log-agent.sh` | Agent 启动 | 记录 Agent 调用以留审计留痕 |
| `log-agent-stop.sh` | Agent 停止 | 完成 Agent 审计留痕（启动 + 停止） |
| `session-stop.sh` | 会话结束 | 最终会话日志 |

### 上下文韧性

**会话状态文件：** `production/session-state/active.md` 是一个活检查点。
每个重要里程碑后更新它。任何中断（压缩、崩溃、`/clear`）后，先读此文件。

**增量写作：** 创建多章节文档时，每章批准后立即写入文件。这意味着
已完成章节能在崩溃和上下文压缩中幸存。关于已写章节的先前讨论可以
安全压缩。

**自动恢复：** `session-start.sh` 钩子自动检测并预览 `active.md`。
`pre-compact.sh` 钩子在压缩前把状态倾倒进对话。

**冲刺状态追踪：** `production/sprint-status.yaml` 是机器可读的故事
追踪器。由 `/sprint-plan`（初始化）和 `/story-done`（状态更新）写入。
由 `/sprint-status`、`/help`、`/story-done`（下一个故事）读取。
消除脆弱的 markdown 扫描。

### 棕地采用

对于已有部分产物的现有项目：

```
/adopt
```

或定向：

```
/adopt gdds
/adopt adrs
/adopt stories
/adopt infra
```

这会审计已有产物的**格式**（而非是否存在），把缺口分类为
BLOCKING/HIGH/MEDIUM/LOW，构建有序迁移计划，并写入
`docs/adoption-plan-[date].md`。核心原则：迁移而非替换 ——
它绝不重新生成已有工作，只补缺口。

个别技能也支持改造模式：

```
/design-system retrofit design/gdd/combat-system.md
/architecture-decision retrofit docs/architecture/adr-005.md
```

这些检测哪些章节已有 vs 缺失，只补缺口。

### 关卡系统

阶段关卡是正式检查点。用转换名运行 `/gate-check`：

```
/gate-check concept              # 概念 -> 系统设计
/gate-check systems-design       # 系统设计 -> 技术搭建
/gate-check technical-setup      # 技术搭建 -> 预制作
/gate-check pre-production       # 预制作 -> 制作
/gate-check production           # 制作 -> 打磨
/gate-check polish               # 打磨 -> 发布
```

**裁决：**
- **PASS** —— 全部要求满足，推进到下一阶段
- **CONCERNS** —— 要求满足但承认有风险，可放行
- **FAIL** —— 要求未满足，附具体补救措施阻断推进

关卡通过时，`production/stage.txt` 才更新（仅此时），它控制
状态行和 `/help` 行为。

### 反向文档化

对于无设计文档的已有代码（棕地采用后常见）：

```
/reverse-document src/gameplay/combat/
```

读取已有代码并从其生成 GDD 格式的设计文档。

---

## Appendix A: Agent 速查

### "我要做 X —— 用哪个 Agent？"

| 我要…… | Agent | 层级 |
|-------------|-------|------|
| 构思游戏点子 | `/brainstorm` 技能 | -- |
| 设计游戏机制 | `game-designer` | 2 |
| 设计具体公式/数值 | `systems-designer` | 3 |
| 设计游戏关卡 | `level-designer` | 3 |
| 设计掉落表 / 经济 | `economy-designer` | 3 |
| 构建世界背景 | `world-builder` | 3 |
| 写对白 | `writer` | 3 |
| 规划故事 | `narrative-director` | 2 |
| 规划冲刺 | `producer` | 1 |
| 做创意决策 | `creative-director` | 1 |
| 做技术决策 | `technical-director` | 1 |
| 实现玩法代码 | `gameplay-programmer` | 3 |
| 实现核心引擎系统 | `engine-programmer` | 3 |
| 实现 AI 行为 | `ai-programmer` | 3 |
| 实现多人 | `network-programmer` | 3 |
| 实现 UI | `ui-programmer` | 3 |
| 构建开发工具 | `tools-programmer` | 3 |
| 审阅代码架构 | `lead-programmer` | 2 |
| 创建着色器 / VFX | `technical-artist` | 3 |
| 定义视觉风格 | `art-director` | 2 |
| 定义音频风格 | `audio-director` | 2 |
| 设计音效 | `sound-designer` | 3 |
| 设计 UX 流程 | `ux-designer` | 3 |
| 写测试用例 | `qa-tester` | 3 |
| 规划测试策略 | `qa-lead` | 2 |
| 分析性能 | `performance-analyst` | 3 |
| 搭建 CI/CD | `devops-engineer` | 3 |
| 设计分析 | `analytics-engineer` | 3 |
| 检查无障碍 | `accessibility-specialist` | 3 |
| 规划在线运营 | `live-ops-designer` | 3 |
| 管理发布 | `release-manager` | 2 |
| 管理本地化 | `localization-lead` | 2 |
| 快速原型 | `prototyper` | 3 |
| 审计安全 | `security-engineer` | 3 |
| 与玩家沟通 | `community-manager` | 3 |
| Godot 专属帮助 | `godot-specialist` | 3 |
| GDScript 专属帮助 | `godot-gdscript-specialist` | 3 |
| Godot 着色器帮助 | `godot-shader-specialist` | 3 |
| GDExtension 模块 | `godot-gdextension-specialist` | 3 |
| Unity 专属帮助 | `unity-specialist` | 3 |
| Unity DOTS/ECS | `unity-dots-specialist` | 3 |
| Unity 着色器/VFX | `unity-shader-specialist` | 3 |
| Unity Addressables | `unity-addressables-specialist` | 3 |
| Unity UI Toolkit | `unity-ui-specialist` | 3 |
| Unreal 专属帮助 | `unreal-specialist` | 3 |
| Unreal GAS | `ue-gas-specialist` | 3 |
| Unreal Blueprints | `ue-blueprint-specialist` | 3 |
| Unreal replication | `ue-replication-specialist` | 3 |
| Unreal UMG/CommonUI | `ue-umg-specialist` | 3 |

### Agent 层级

```
                    creative-director / technical-director / producer
                                         |
          ---------------------------------------------------------------
          |            |           |           |          |        |       |
    game-designer  lead-prog  art-dir  audio-dir  narr-dir  qa-lead  release-mgr
          |            |           |           |          |        |        |
     specialists  programmers  tech-art  snd-design  writer   qa-tester  devops
     (systems,    (gameplay,             (sound)     (world-  (perf,     (analytics,
      economy,     engine,                           builder)  access.)   security)
      level)       ai, net,
                   ui, tools)
```

**升级规则：** 若两个 Agent 意见不一，往上走。设计冲突交
`creative-director`。技术冲突交 `technical-director`。范围冲突交
`producer`。

---

## Appendix B: 斜杠命令速查

### 按类别列出全部 73 个命令

#### 入门与导航 (6)

| 命令 | 用途 | 阶段 |
|---------|---------|-------|
| `/start` | 引导式入门，路由到正确工作流 | 任意（首次会话） |
| `/help` | 上下文感知的"下一步做什么" | 任意 |
| `/project-stage-detect` | 全面项目审计以确定当前阶段 | 任意 |
| `/setup-engine` | 配置引擎、锁定版本、设定偏好 | 1 |
| `/adopt` | 棕地审计与迁移计划 | 任意（已有项目） |
| `/skill-improve` | 通过测试-修复-重测循环改进技能 | 任意 |

#### 游戏设计 (6)

| 命令 | 用途 | 阶段 |
|---------|---------|-------|
| `/brainstorm` | 带 MDA 分析的协作式构思 | 1 |
| `/map-systems` | 把概念拆解为系统索引 | 1-2 |
| `/design-system` | 引导式逐章节 GDD 创作 | 2 |
| `/quick-design` | 小改动的轻量规格 | 2+ |
| `/review-all-gdds` | 跨 GDD 一致性与设计理论审阅 | 2 |
| `/propagate-design-change` | 找受 GDD 改动影响的 ADR/故事 | 5 |

#### UX 与界面 (2)

| 命令 | 用途 | 阶段 |
|---------|---------|-------|
| `/ux-design` | 创作 UX 规格（屏幕/流程、HUD、模式） | 4 |
| `/ux-review` | 校验 UX 规格的无障碍与 GDD 对齐 | 4 |

#### 架构 (4)

| 命令 | 用途 | 阶段 |
|---------|---------|-------|
| `/create-architecture` | 主架构文档 | 3 |
| `/architecture-decision` | 创建或改造一份 ADR | 3 |
| `/architecture-review` | 校验全部 ADR、依赖排序 | 3 |
| `/create-control-manifest` | 从 Accepted ADR 生成扁平程序员规则 | 3 |

#### 故事与冲刺 (8)

| 命令 | 用途 | 阶段 |
|---------|---------|-------|
| `/create-epics` | 把 GDD + ADR 翻译为史诗（每模块一份） | 4 |
| `/create-stories` | 把单个史诗拆为故事文件 | 4 |
| `/dev-story` | 实现故事 —— 路由到正确的程序员 Agent | 5 |
| `/sprint-plan` | 创建或管理冲刺计划 | 4-5 |
| `/sprint-status` | 30 行快速冲刺快照 | 5 |
| `/story-readiness` | 校验故事是否可实现就绪 | 4-5 |
| `/story-done` | 8 阶段故事完成审阅 | 5 |
| `/estimate` | 带风险评估的工作量估算 | 4-5 |

#### 审阅与分析 (13)

| 命令 | 用途 | 阶段 |
|---------|---------|-------|
| `/design-review` | 按 8 章节标准校验 GDD | 1-2 |
| `/code-review` | 架构级代码审阅 | 5+ |
| `/balance-check` | 游戏平衡公式分析 | 5-6 |
| `/asset-audit` | 资产命名、格式、大小校验 | 6 |
| `/asset-spec` | 单资产的视觉规格与 AI 生成提示 | 5-6 |
| `/content-audit` | GDD 指定内容 vs 已实现 | 5 |
| `/consistency-check` | 跨 GDD 实体与公式不一致扫描 | 2+ |
| `/scope-check` | 范围蔓延检测 | 5 |
| `/perf-profile` | 性能分析工作流 | 6 |
| `/tech-debt` | 技术债扫描与排序 | 6 |
| `/gate-check` | 带 PASS/CONCERNS/FAIL 的正式阶段关卡 | 所有切换 |
| `/reverse-document` | 从已有代码生成设计文档 | 任意 |
| `/security-audit` | 安全漏洞审计（存档、网络、输入） | 6-7 |

#### QA 与测试 (9)

| 命令 | 用途 | 阶段 |
|---------|---------|-------|
| `/qa-plan` | 为冲刺或功能生成 QA 测试计划 | 5 |
| `/smoke-check` | QA 交接前的关键路径冒烟测试关卡 | 5-6 |
| `/soak-test` | 长时间游玩的浸泡测试协议 | 6 |
| `/regression-suite` | 映射测试覆盖、找出缺回归测试的已修 bug | 5-6 |
| `/test-setup` | 脚手架测试框架与 CI/CD 流水线 | 4 |
| `/test-helpers` | 生成引擎特定的测试辅助库 | 4-5 |
| `/test-evidence-review` | 测试文件与人工证据的质量审阅 | 5 |
| `/test-flakiness` | 从 CI 日志检测非确定性测试 | 5-6 |
| `/skill-test` | 校验技能文件的结构与行为正确性 | 任意 |

#### 制作管理 (6)

| 命令 | 用途 | 阶段 |
|---------|---------|-------|
| `/milestone-review` | 里程碑进度与 go/no-go | 5 |
| `/retrospective` | 冲刺回顾分析 | 5 |
| `/bug-report` | 结构化 bug 报告创建 | 5+ |
| `/bug-triage` | 重新评估开放 bug 的优先级、严重度、归属 | 5+ |
| `/playtest-report` | 结构化试玩会话报告 | 4-6 |
| `/onboard` | 新成员入门 | 任意 |

#### 发布 (6)

| 命令 | 用途 | 阶段 |
|---------|---------|-------|
| `/release-checklist` | 发布前校验 | 7 |
| `/launch-checklist` | 完整跨部门发布就绪 | 7 |
| `/changelog` | 自动生成内部 changelog | 7 |
| `/patch-notes` | 面向玩家的补丁说明 | 7 |
| `/hotfix` | 紧急修复工作流 | 7+ |
| `/day-one-patch` | 针对母带后发现问题的小范围补丁 | 7+ |

#### 创意 (4)

| 命令 | 用途 | 阶段 |
|---------|---------|-------|
| `/prototype` | 概念原型 —— 在 GDD 之前验证核心想法 | 1 |
| `/art-bible` | 引导式美术圣经创作 —— 视觉身份规格 | 1-2 |
| `/vertical-slice` | 进入制作前的生产级端到端构建 | 4 |
| `/localize` | 字符串抽取与校验 | 6-7 |

#### 团队编排 (9)

| 命令 | 用途 | 阶段 |
|---------|---------|-------|
| `/team-combat` | 战斗功能：从设计到实现 | 5 |
| `/team-narrative` | 叙事内容：从结构到对白 | 5 |
| `/team-ui` | UI 功能：从 UX 规格到打磨实现 | 5 |
| `/team-level` | 关卡：从布局到布置好的遭遇 | 5 |
| `/team-audio` | 音频：从方向到已实现事件 | 5-6 |
| `/team-polish` | 协调式打磨：性能 + 美术 + 音频 + QA | 6 |
| `/team-release` | 发布协调：构建 + QA + 部署 | 7 |
| `/team-live-ops` | 在线运营规划：季活、战斗通行证、留存 | 7+ |
| `/team-qa` | 完整 QA 循环：策略、执行、覆盖、签字 | 6-7 |

---

## Appendix C: 常见工作流

### 工作流 1："我刚起步，还没有游戏点子"

```
1. /start （根据你所在位置路由）
2. /brainstorm （协作式构思，选一个概念）
3. /setup-engine （锁定引擎与版本）
4. /design-review 概念文档（可选，推荐）
5. /map-systems （把概念拆成带依赖与优先级的系统）
6. /gate-check concept （校验你已为系统设计就绪）
7. /design-system 每个系统 （引导式 GDD 创作）
```

### 工作流 2："我有设计，想开始写代码"

```
1. /design-review 每个 GDD （确保它们扎实）
2. /review-all-gdds （跨 GDD 一致性）
3. /gate-check systems-design
4. /create-architecture + /architecture-decision （每个重大决策）
5. /architecture-review
6. /create-control-manifest
7. /gate-check technical-setup
8. /create-epics layer: foundation + /create-stories [slug] （定义史诗，拆为故事）
9. /sprint-plan new
10. /story-readiness -> implement -> /story-done （故事生命周期）
```

### 工作流 3："制作中需要加一个复杂功能"

```
1. /design-system 或 /quick-design （视范围而定）
2. /design-review 校验
3. /propagate-design-change 若修改已有 GDD
4. /estimate 估算工作量与风险
5. /team-combat、/team-narrative、/team-ui 等 （合适的团队技能）
6. /story-done 完成时
7. /balance-check 若影响游戏平衡
```

### 工作流 4："生产环境出了问题"

```
1. /hotfix "问题描述"
2. 在热修分支上实现修复
3. /code-review 修复
4. 跑测试
5. /release-checklist 热修构建
6. 部署并回移植
```

### 工作流 5："我已有项目，想用这套系统"

```
1. /start （选路径 D —— 已有工作）
2. /project-stage-detect （确定当前阶段）
3. /adopt （审计已有产物，构建迁移计划）
4. /design-system retrofit [path] （补 GDD 缺口）
5. /architecture-decision retrofit [path] （补 ADR 缺口）
6. /gate-check 在合适的切换处
```

### 工作流 6："开新冲刺"

```
1. /retrospective （回顾上个冲刺）
2. /sprint-plan new （创建下个冲刺）
3. /scope-check （确保范围可控）
4. /story-readiness 每个故事领取前
5. 实现故事
6. /story-done 每个完成的故事
7. /sprint-status 随时快速查进度
```

### 工作流 7："发布游戏"

```
1. /gate-check polish （校验打磨阶段完成）
2. /tech-debt （决定哪些在发布时可以接受）
3. /localize （最终本地化通版）
4. /release-checklist v1.0.0
5. /launch-checklist （完整跨部门校验）
6. /team-release （协调发布）
7. /patch-notes 与 /changelog
8. 发布！
9. /hotfix 若发布后出问题
10. 发布稳定后做复盘
```

### 工作流 8："我迷路了 / 不知道下一步做什么"

```
1. /help （读你的阶段，检查产物，告诉你下一步）
2. 若 /help 没帮助：/project-stage-detect （全面审计）
3. 若阶段看着不对：在你认为所在的切换处 /gate-check
```

---

## 充分利用本系统的提示

1. **总是先设计再实现。** Agent 系统建立在"代码写入前存在设计文档"
   的假设之上。Agent 会不断引用 GDD。

2. **跨领域功能用团队技能。** 不要试图自己手动协调 4 个 Agent —— 让
   `/team-combat`、`/team-narrative` 等处理编排。

3. **信任规则系统。** 当规则在你的代码中标记了什么，去修它。规则
   编码了来之不易的游戏开发智慧（数据驱动值、delta time、无障碍等）。

4. **主动压缩。** 在 ~65-70% 上下文使用量时压缩或 `/clear`。
   pre-compact 钩子会保存你的进度。不要等到接近上限。

5. **用对的 Agent 层级。** 不要让 `creative-director` 写着色器。不要让
   `qa-tester` 做设计决策。层级存在是有原因的。

6. **不确定时跑 /help。** 它读你实际的项目状态并告诉你单一最重要的
   下一步。

7. **把设计交给程序员前跑 `/design-review`。** 这能及早抓住不完整的
   规格，省返工。

8. **每个大功能后跑 `/code-review`。** 在架构问题扩散前抓住它。

9. **先给高风险机制做原型。** 一天原型可能省掉一周在不奏效机制上的
   制作。

10. **保持冲刺计划诚实。** 定期用 `/scope-check`。范围蔓延是独立游戏
    的头号杀手。

11. **用 ADR 记录决策。** 未来的你会感谢现在的你记录了*为什么*东西
    要那样建。

12. **严格用故事生命周期。** 领取前 `/story-readiness`，完成后
    `/story-done`。这能及早抓偏离，让流水线保持诚实。

13. **及早并经常写入文件。** 增量章节写作意味着你的设计决策能在
    崩溃和压缩中幸存。文件才是记忆，不是对话。
