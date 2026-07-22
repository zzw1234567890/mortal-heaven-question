
# 游戏工作室代理架构——快速入门指南 (Quick Start Guide)

## 这是什么？

这是一个完整的用于游戏开发的 Claude Code 代理架构。它将 49 个专门的 AI 代理
组织成一个工作室层级结构，模拟真实的游戏开发团队，具有明确的职责、委托
规则和协调协议。它包括针对 Godot、Unity 和 Unreal 的引擎专家代理——
每个引擎都配有专门的子专家，覆盖主要的引擎子系统。所有设计代理和模板都基于
成熟的游戏设计理论（MDA 框架、自我决定理论、心流状态、Bartle 玩家类型）。
选择与你项目匹配的引擎套装。

## 如何使用

### 1. 理解层级结构

代理分为三个层级：

- **第 1 层（Opus）**：总监（Directors）——负责高层决策
  - `creative-director`——愿景与创意冲突解决
  - `technical-director`——架构与技术决策
  - `producer`——进度安排、协调与风险管理

- **第 2 层（Sonnet）**：部门主管（Department Leads）——负责各自领域
  - `game-designer`、`lead-programmer`、`art-director`、`audio-director`、
    `narrative-director`、`qa-lead`、`release-manager`、`localization-lead`

- **第 3 层（Sonnet/Haiku）**：专家（Specialists）——在各自领域内执行
  - 设计师、程序员、美术师、编剧、测试员、工程师

### 2. 为任务选择合适的代理

问自己："在真实工作室中，哪个部门会处理这个？"

| 我需要…… | 使用此代理 |
|-------------|---------------|
| 设计一个新机制 | `game-designer` |
| 编写战斗代码 | `gameplay-programmer` |
| 创建着色器 | `technical-artist` |
| 撰写对白 | `writer` |
| 规划下一个冲刺 | `producer` |
| 审查代码质量 | `lead-programmer` |
| 编写测试用例 | `qa-tester` |
| 设计关卡 | `level-designer` |
| 解决性能问题 | `performance-analyst` |
| 设置 CI/CD | `devops-engineer` |
| 设计掉落表 | `economy-designer` |
| 解决创意冲突 | `creative-director` |
| 做出架构决策 | `technical-director` |
| 管理发布 | `release-manager` |
| 准备待翻译的字符串 | `localization-lead` |
| 快速测试机制创意 | `prototyper` |
| 审查代码安全 | `security-engineer` |
| 检查无障碍合规性 | `accessibility-specialist` |
| 获取 Unreal Engine 建议 | `unreal-specialist` |
| 获取 Unity 建议 | `unity-specialist` |
| 获取 Godot 建议 | `godot-specialist` |
| 设计 GAS 技能/效果 | `ue-gas-specialist` |
| 定义 BP/C++ 边界 | `ue-blueprint-specialist` |
| 实现 UE 复制 | `ue-replication-specialist` |
| 构建 UMG/CommonUI 控件 | `ue-umg-specialist` |
| 设计 DOTS/ECS 架构 | `unity-dots-specialist` |
| 编写 Unity 着色器/VFX | `unity-shader-specialist` |
| 管理 Addressable 资源 | `unity-addressables-specialist` |
| 构建 UI Toolkit/UGUI 界面 | `unity-ui-specialist` |
| 编写地道的 GDScript | `godot-gdscript-specialist` |
| 编写 Godot C# 代码 | `godot-csharp-specialist` |
| 创建 Godot 着色器 | `godot-shader-specialist` |
| 构建 GDExtension 模块 | `godot-gdextension-specialist` |
| 规划线上活动与赛季 | `live-ops-designer` |
| 编写面向玩家的补丁说明 | `community-manager` |
| 头脑风暴新游戏创意 | 使用 `/brainstorm` 技能 |

### 3. 使用斜杠命令处理常见任务

| 命令 | 功能 |
|---------|-------------|
| `/start` | 首次引导——询问你当前状态，引导你进入正确流程 |
| `/help` | 上下文感知的"我下一步该做什么？"——读取你的当前阶段和产物 |
| `/project-stage-detect` | 分析项目状态，检测阶段，识别差距 |
| `/setup-engine` | 配置引擎 + 版本，填充参考文档 |
| `/adopt` | 对现有项目进行棕地审计和迁移规划 |
| `/brainstorm` | 从零开始的引导式游戏概念构思 |
| `/map-systems` | 将概念分解为系统，映射依赖关系，指导每个系统的 GDD |
| `/design-system` | 单个游戏系统的引导式、逐章节 GDD 编写 |
| `/quick-design` | 小型变更的轻量级规格——调优、微调、小型新增 |
| `/review-all-gdds` | 跨 GDD 一致性和游戏设计理论审查 |
| `/propagate-design-change` | 查找受 GDD 变更影响的 ADR 和故事 |
| `/art-bible` | 引导式、逐章节艺术圣经编写——在资产制作前创建视觉身份规范 |
| `/asset-spec` | 根据 GDD 或角色设定生成每个资产的视觉规范和 AI 生成提示词 |
| `/ux-design` | 编写 UX 规范（界面/流程、HUD、交互模式） |
| `/ux-review` | 验证 UX 规范的无障碍合规性和 GDD 对齐 |
| `/create-architecture` | 游戏的主架构文档 |
| `/architecture-decision` | 创建 ADR |
| `/architecture-review` | 验证所有 ADR、依赖顺序、GDD 可追溯性 |
| `/create-control-manifest` | 根据已接受的 ADR 生成扁平化的程序员规则表 |
| `/create-epics` | 将 GDD + ADR 转化为史诗（每个架构模块一个） |
| `/create-stories` | 将单个史诗分解为可实施的故事文件 |
| `/dev-story` | 读取故事并实施——路由到正确的程序员代理 |
| `/sprint-plan` | 创建或更新冲刺计划 |
| `/sprint-status` | 快速 30 行冲刺快照 |
| `/story-readiness` | 验证故事在接手前是否已准备好实施 |
| `/story-done` | 故事完成审查——验证验收标准 |
| `/estimate` | 生成结构化的工作量估算 |
| `/design-review` | 审查设计文档 |
| `/code-review` | 审查代码质量和架构 |
| `/balance-check` | 分析游戏平衡性数据 |
| `/asset-audit` | 审计资产合规性 |
| `/content-audit` | GDD 指定内容 vs 已实现内容——查找差距 |
| `/scope-check` | 检测与计划相比的范围蔓延 |
| `/perf-profile` | 性能分析和瓶颈识别 |
| `/tech-debt` | 扫描、跟踪和优先处理技术债务 |
| `/gate-check` | 验证阶段就绪性（PASS/CONCERNS/FAIL） |
| `/consistency-check` | 扫描所有 GDD 的跨文档不一致性（冲突的数值、名称、规则） |
| `/security-audit` | 安全漏洞审计：存档篡改、作弊向量、网络攻击、数据泄露 |
| `/reverse-document` | 从现有代码生成设计/架构文档 |
| `/milestone-review` | 审查里程碑进展 |
| `/retrospective` | 执行冲刺/里程碑回顾 |
| `/bug-report` | 结构化 bug 报告创建 |
| `/playtest-report` | 创建或分析试玩反馈 |
| `/onboard` | 为某个角色生成引导文档 |
| `/release-checklist` | 验证发布前检查清单 |
| `/launch-checklist` | 完整的发布就绪性验证 |
| `/changelog` | 从 Git 历史生成变更日志 |
| `/patch-notes` | 生成面向玩家的补丁说明 |
| `/hotfix` | 带有审计追踪的紧急修复 |
| `/day-one-patch` | 为黄金版之后发现的已知问题准备有针对性的首日补丁 |
| `/prototype` | 概念原型——在编写 GDD 之前验证核心创意是否有趣（阶段 1） |
| `/vertical-slice` | 生产质量的端到端构建——验证完整游戏循环（阶段 4） |
| `/localize` | 本地化扫描、提取、验证 |
| `/team-combat` | 编排完整的战斗团队管线 |
| `/team-narrative` | 编排完整的叙事团队管线 |
| `/team-ui` | 编排完整的 UI 团队管线 |
| `/team-release` | 编排完整的发布团队管线 |
| `/team-polish` | 编排完整的精修团队管线 |
| `/team-audio` | 编排完整的音频团队管线 |
| `/team-level` | 编排完整的关卡创建管线 |
| `/team-live-ops` | 编排线上运营团队负责赛季、活动和发布后内容 |
| `/team-qa` | 编排完整 QA 团队周期——测试计划、测试用例、冒烟检查、签收 |
| `/qa-plan` | 为冲刺或功能生成 QA 测试计划 |
| `/bug-triage` | 重新排定待处理 bug 的优先级，分配到冲刺，发现系统性趋势 |
| `/smoke-check` | 在 QA 交接前运行关键路径冒烟测试门（PASS/FAIL） |
| `/soak-test` | 为长时间游戏会话生成浸泡测试协议 |
| `/regression-suite` | 映射 GDD 关键路径的覆盖范围，标记差距，维护回归测试套件 |
| `/test-setup` | 为项目引擎搭建测试框架 + CI 管线（运行一次） |
| `/test-helpers` | 生成引擎特定的测试辅助库和工厂函数 |
| `/test-flakiness` | 从 CI 历史中检测不稳定测试，标记隔离或修复 |
| `/test-evidence-review` | 对测试文件和人工证据进行质量审查——ADEQUATE/INCOMPLETE/MISSING |
| `/skill-test` | 验证技能文件的合规性和正确性（静态/规范/审计） |
| `/skill-improve` | 使用测试-修复-重测循环改进技能——诊断、提出修复、重写、验证 |

### 4. 使用模板创建新文档

模板位于 `.claude/docs/templates/`：

- `game-design-document.md`——用于新机制和系统
- `architecture-decision-record.md`——用于技术决策
- `architecture-traceability.md`——将 GDD 需求映射到 ADR，再映射到故事 ID
- `risk-register-entry.md`——用于新风险
- `narrative-character-sheet.md`——用于新角色
- `test-plan.md`——用于功能测试计划
- `sprint-plan.md`——用于冲刺规划
- `milestone-definition.md`——用于新里程碑
- `level-design-document.md`——用于新关卡
- `game-pillars.md`——用于核心设计支柱
- `art-bible.md`——用于视觉风格参考
- `technical-design-document.md`——用于按系统的技术设计
- `post-mortem.md`——用于项目/里程碑回顾
- `sound-bible.md`——用于音频风格参考
- `release-checklist-template.md`——用于平台发布检查清单
- `changelog-template.md`——用于面向玩家的补丁说明
- `release-notes.md`——用于面向玩家的发布说明
- `incident-response.md`——用于线上事件响应手册
- `game-concept.md`——用于初始游戏概念（MDA、SDT、心流、Bartle）
- `pitch-document.md`——用于向利益相关者推介游戏
- `economy-model.md`——用于虚拟经济设计（消耗/产出模型）
- `faction-design.md`——用于阵营身份、背景故事和游戏角色
- `systems-index.md`——用于系统分解和依赖映射
- `project-stage-report.md`——用于项目阶段检测输出
- `design-doc-from-implementation.md`——用于将现有代码反向文档化为 GDD
- `architecture-doc-from-code.md`——用于将代码反向文档化为架构文档
- `concept-doc-from-prototype.md`——用于将原型反向文档化为概念文档
- `ux-spec.md`——用于按界面的 UX 规范（布局区域、状态、事件）
- `hud-design.md`——用于全局 HUD 理念、区域和元素规范
- `accessibility-requirements.md`——用于项目范围的无障碍级别和功能矩阵
- `interaction-pattern-library.md`——用于标准 UI 控件和游戏特定模式
- `player-journey.md`——用于按时间尺度的 6 阶段情感弧线和留存钩子
- `difficulty-curve.md`——用于难度轴、上手斜坡和跨系统交互
- `test-evidence.md`——用于记录人工测试证据的模板（截图、操作说明笔记）

另外在 `.claude/docs/templates/collaborative-protocols/` 中（由代理使用，通常不直接编辑）：

- `design-agent-protocol.md`——设计代理的提问-选项-草稿-批准循环
- `implementation-agent-protocol.md`——编程代理的故事接手到 `/story-done` 循环
- `leadership-agent-protocol.md`——主管级代理的跨部门委托和升级机制

### 5. 遵循协调规则

1. 工作沿层级向下流动：总监 -> 主管 -> 专家
2. 冲突沿层级向上升级
3. 跨部门工作由 `producer` 协调
4. 未经委托，代理不得修改其领域之外的文件
5. 所有决策均需记录在案

## 新项目的第一步

**不知从何开始？** 运行 `/start`。它会询问你当前状态，并引导你
进入正确的流程。不会对你的游戏、引擎或经验水平做任何假设。

如果你已清楚自己需要什么，直接跳转到相关路径：

### 路径 A："我不知道要做什么游戏"

1. **运行 `/start`**（或 `/brainstorm open`）——引导式创意探索：
   什么让你兴奋、你玩过什么、你的限制条件
   - 生成 3 个概念，帮助你选择一个，定义核心循环和支柱
   - 生成游戏概念文档并推荐引擎
2. **设置引擎**——运行 `/setup-engine`（使用头脑风暴的推荐）
   - 配置 CLAUDE.md，检测知识差距，填充参考文档
   - 创建 `.claude/docs/technical-preferences.md`，包含命名约定、
     性能预算和引擎特定默认设置
   - 如果引擎版本新于 LLM 的训练数据，它会从网络获取
     当前文档，以便代理建议正确的 API
3. **验证概念**——运行 `/design-review design/gdd/game-concept.md`
4. **分解为系统**——运行 `/map-systems` 映射所有系统和依赖关系
5. **设计每个系统**——运行 `/design-system [系统名称]`（或 `/map-systems next`）
   按依赖顺序编写 GDD
6. **原型验证机制**——运行 `/prototype [核心机制]`（1–3 天——在编写 GDD 之前）
7. **设计每个系统**——运行 `/design-system [系统名称]` 编写 GDD，结合原型发现
8. **规划第一个冲刺**——架构和 `/vertical-slice` 完成后，运行 `/sprint-plan new`
9. 开始构建

### 路径 B："我知道要做什么游戏"

如果你已有游戏概念和引擎选择：

1. **设置引擎**——运行 `/setup-engine [引擎] [版本]`
   （例如 `/setup-engine godot 4.6`）——同时创建技术偏好
2. **编写游戏支柱**——委托给 `creative-director`
3. **分解为系统**——运行 `/map-systems` 枚举系统和依赖关系
4. **设计每个系统**——运行 `/design-system [系统名称]` 按依赖顺序编写 GDD
5. **创建初始 ADR**——运行 `/architecture-decision`
6. **在 `production/milestones/` 中创建第一个里程碑**
7. **规划第一个冲刺**——运行 `/sprint-plan new`
8. 开始构建

### 路径 C："我了解游戏但不了解引擎"

如果你有概念但不知道哪个引擎合适：

1. **不带参数运行 `/setup-engine`**——它会询问你的游戏
   需求（2D/3D、平台、团队规模、语言偏好）并根据你的回答推荐引擎
2. 从路径 B 的第 2 步开始

### 路径 D："我有现有项目"

如果你已有设计文档、原型或代码：

1. **运行 `/start`**（或 `/project-stage-detect`）——分析现有内容，
   识别差距，并推荐下一步
2. 如果已有 GDD、ADR 或故事，**运行 `/adopt`**——审计
   内部格式合规性并建立编号迁移计划以填补差距，
   而不会覆盖你现有的工作
3. **如有需要配置引擎**——如果尚未配置，运行 `/setup-engine`
4. **验证阶段就绪性**——运行 `/gate-check` 查看你的状况
5. **规划下一个冲刺**——运行 `/sprint-plan new`

## 文件结构参考

```
CLAUDE.md                          -- 主配置（首先阅读此文件，约 60 行）
.claude/
  settings.json                    -- Claude Code 钩子和项目设置
  agents/                          -- 49 个代理定义（YAML 前置元数据）
  skills/                          -- 73 个斜杠命令定义（YAML 前置元数据）
  hooks/                           -- 12 个钩子脚本（.sh），由 settings.json 连接
  rules/                           -- 11 个路径特定规则文件
  docs/
    quick-start.md                 -- 本文件
    technical-preferences.md       -- 项目特定标准（由 /setup-engine 填充）
    coding-standards.md            -- 编码和设计文档标准
    coordination-rules.md          -- 代理协调规则
    context-management.md          -- 上下文预算和压缩说明
    directory-structure.md         -- 项目目录布局
    workflow-catalog.yaml          -- 7 阶段管线定义（由 /help 读取）
    setup-requirements.md          -- 系统先决条件（Git Bash、jq、Python）
    settings-local-template.md     -- 个人 settings.local.json 指南
    templates/                     -- 41 个文档模板
```
