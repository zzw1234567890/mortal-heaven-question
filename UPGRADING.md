
# 升级 Claude Code Game Studios

本指南涵盖将你现有的游戏项目仓库从模板的一个版本升级到下一个版本。

**查找你当前的版本**，在你的 git log 中：
```bash
git log --oneline | grep -i "release\|setup"
```
或检查 `README.md` 中的版本徽章。

---

## 目录

- [升级策略](#升级策略)
- [v1.0.0-beta → v1.0](#v100-beta--v10)
- [v0.4.x → v1.0](#v04x--v10)
- [v0.4.0 → v0.4.1](#v040--v041)
- [v0.3.0 → v0.4.0](#v030--v040)
- [v0.2.0 → v0.3.0](#v020--v030)
- [v0.1.0 → v0.2.0](#v010--v020)

---

## 升级策略

有三种方式引入模板更新。根据你的仓库设置来选择。

### 策略 A — Git 远程合并（推荐）

适用场景：你克隆了模板并在其上有自己的提交。

```bash
# 将模板添加为远程（一次性设置）
git remote add template https://github.com/Donchitos/Claude-Code-Game-Studios.git

# 拉取新版本
git fetch template main

# 合并到你的分支
git merge template/main --allow-unrelated-histories
```

Git 只会在模板*和*你都改动过的文件中标记冲突。逐个解决——你的游戏内容保留，结构性改进随之而来。然后提交合并。

**提示：** 最可能冲突的文件是 `CLAUDE.md` 和
`.claude/docs/technical-preferences.md`，因为你已经填入了你的引擎和项目设置。保留你的内容；接受结构性变更。

---

### 策略 B — 挑选特定提交

适用场景：你只想要一个特定的功能（例如只要那个新技能，不要完整更新）。

```bash
git remote add template https://github.com/Donchitos/Claude-Code-Game-Studios.git
git fetch template main

# 挑选你想要的特定提交
git cherry-pick <commit-sha>
```

每个版本的提交 SHA 列在下面的版本章节中。

---

### 策略 C — 手动文件复制

适用场景：你没有用 git 设置模板（只是下载了 zip）。

1. 在你的仓库旁边下载或克隆新版本。
2. 直接复制下面**"可安全覆盖"**下列出的文件。
3. 对于**"仔细合并"**下的文件，并排打开两个版本，手动合并结构性变更同时保留你的内容。

---

## v0.4.1

**发布：** 2026-04-02
**关键主题：** 美术方向集成、资产规格管线

### 变更内容

| 类别 | 变更 |
|----------|---------|
| **新技能** | `/art-bible`——引导式逐章视觉身份创作（9 个章节）。每章强制 art-director Task 生成。AD-ART-BIBLE 签字门禁。在技术设置阶段必需。 |
| **新技能** | `/asset-spec`——按资产生成视觉规格和 AI 生成提示。读取美术圣经 + GDD/关卡/角色文档。写入 `design/assets/specs/` 文件和 `design/assets/asset-manifest.md`。支持 full/lean/solo 模式。 |
| **新总监门禁 (3)** | `AD-CONCEPT-VISUAL`（brainstorm 阶段 4）、`AD-ART-BIBLE`（美术圣经签字）、`AD-PHASE-GATE`（gate-check 评审组） |
| **`/brainstorm` 更新** | 在 allowed-tools 中添加了 `Task`（之前缺失——阻止了所有总监生成）。Art-director 现在在支柱锁定后与 creative-director 并行生成。视觉身份锚点写入 game-concept.md。 |
| **`/gate-check` 更新** | Art-director 作为第 4 个并行总监加入（AD-PHASE-GATE）。视觉产物检查：视觉身份锚点（概念门禁）、美术圣经（技术设置门禁）、AD-ART-BIBLE 签字 + 角色视觉档案（预制作门禁）。 |
| **`/team-level` 更新** | Art-director 加入步骤 1 并行生成（在布局前进行视觉方向）。Level-designer 现在将 art-director 目标作为明确约束接收。步骤 4 art-director 角色更正为仅 production-concepts。 |
| **`/team-narrative` 更新** | Art-director 加入阶段 2 并行生成（角色视觉设计、环境叙事、电影调性）。 |
| **`/design-system` 更新** | 路由表扩展了 art-director + technical-artist，用于战斗、UI、对话、动画/VFX、角色类别。视觉/音频章节现在对 7 个系统类别是必需的（带 art-director Task 生成）。 |
| **`workflow-catalog.yaml`** | `/art-bible` 加入技术设置（必需）。`/asset-spec` 加入预制作（可选，可重复）。 |

### 文件：可安全覆盖

**要添加的新文件：**
```
.claude/skills/art-bible/SKILL.md
.claude/skills/asset-spec/SKILL.md
.claude/docs/director-gates.md
```

**要覆盖的现有文件（无用户内容）：**
```
.claude/skills/brainstorm/SKILL.md
.claude/skills/gate-check/SKILL.md
.claude/skills/team-level/SKILL.md
.claude/skills/team-narrative/SKILL.md
.claude/skills/design-system/SKILL.md
.claude/docs/workflow-catalog.yaml
README.md
UPGRADING.md
```

### 文件：仔细合并

无——所有变更都是基础设施文件，没有用户内容。

---

## v1.0.0-beta → v1.0

**发布：** 2026-05-13
**提交范围：** `49d1e45..HEAD`
**关键主题：** 新的 `/vertical-slice` 门禁、技能打磨和 bug 修复、贡献者文档

### 变更内容

| 类别 | 变更 |
|----------|---------|
| **新技能** | `/vertical-slice`——预制作门禁，在进入制作之前用一个生产质量的端到端构建验证完整的游戏循环。与翻新的 `/prototype`（在 `/brainstorm` 之后立即进行概念验证）配对。 |
| **新流程** | `/map-systems` 中的实体清单步骤——预先展示所有命名实体，使下游 GDD 创作更干净。 |
| **UX 打磨** | 为 7 个技能添加了缺失的 `AskUserQuestion` 小部件；对一致性、提示和流程缺口进行了全面技能审计；为所有 `team-*` 技能在 `argument-hints` 中暴露了 `--review` 标志。 |
| **Bug 修复** | `#21` log-agent 钩子记录了 "unknown" 的 `agent_type`；`#36` `/architecture-decision` 和 `/story-done` 中缺失 `allowed-tools`；`#42` `rg --type gdscript` 无效（现在使用 `--glob *.gd`）；`#43` session-start 预览显示最旧的状态而非最新的；`#45` `/architecture-decision` 中重复的 `## 0.` 标题和损坏的步骤编号。 |
| **项目文档** | 添加了 `CONTRIBUTING.md`（框架贡献指南）和 `SECURITY.md`（协调披露策略）。 |
| **计数/引用** | 在 `WORKFLOW-GUIDE.md`、`README.md` 和智能体名册之间同步了智能体/技能/钩子计数；修复了过时的智能体名称和技能模型层级字段。 |

---

### 文件：可安全覆盖

**要添加的新文件：**
```
.claude/skills/vertical-slice/SKILL.md
CONTRIBUTING.md
SECURITY.md
```

**要覆盖的现有文件（无用户内容）：**
- 提交范围内修改的 `.claude/skills/` 下所有文件（技能审计 + AskUserQuestion 小部件 + `--review` argument-hints）
- `.claude/hooks/log-agent.sh`（修复 #21）
- `README.md`、`docs/WORKFLOW-GUIDE.md`、`docs/examples/skill-flow-diagrams.md`
- `UPGRADING.md`

---

### 文件：仔细合并

无——所有变更都是基础设施文件，没有用户内容。

---

## v0.4.x → v1.0

**发布：** 2026-03-29
**提交范围：** `6c041ac..HEAD`
**关键主题：** 总监门禁系统、门禁强度模式、Godot C# 专家

### 变更内容

| 类别 | 变更 |
|----------|---------|
| **新系统** | 总监门禁——命名审查检查点，在所有工作流技能之间共享。定义在 `.claude/docs/director-gates.md` |
| **新功能** | 门禁强度模式：`full`（所有总监门禁）、`lean`（仅阶段门禁）、`solo`（无总监）。在 `/start` 期间通过 `production/review-mode.txt` 全局设置，或在任意使用门禁的技能上用 `--review [mode]` 按次覆盖 |
| **新智能体** | `godot-csharp-specialist`——Godot 4 项目中的 C# 代码质量 |
| **技能更新 (13)** | 所有使用门禁的技能现在都会解析 `--review [full\|lean\|solo]` 并将其包含在 argument-hint 中：`brainstorm`、`map-systems`、`design-system`、`architecture-decision`、`create-architecture`、`create-epics`、`create-stories`、`sprint-plan`、`milestone-review`、`playtest-report`、`prototype`、`story-done`、`gate-check` |
| **`/start` 更新** | 添加了阶段 3b——在入门期间设置评审模式，写入 `production/review-mode.txt` |
| **`/setup-engine` 更新** | Godot 的语言选择步骤（GDScript vs C#） |
| **文档** | `director-gates.md`——完整门禁目录；`WORKFLOW-GUIDE.md`——总监评审模式章节；`README.md`——评审强度自定义 |

---

### 文件：可安全覆盖

**要添加的新文件：**
```
.claude/agents/godot-csharp-specialist.md
.claude/docs/director-gates.md
```

**要覆盖的现有文件（无用户内容）：**
```
.claude/skills/brainstorm/SKILL.md
.claude/skills/map-systems/SKILL.md
.claude/skills/design-system/SKILL.md
.claude/skills/architecture-decision/SKILL.md
.claude/skills/create-architecture/SKILL.md
.claude/skills/create-epics/SKILL.md
.claude/skills/create-stories/SKILL.md
.claude/skills/sprint-plan/SKILL.md
.claude/skills/milestone-review/SKILL.md
.claude/skills/playtest-report/SKILL.md
.claude/skills/prototype/SKILL.md
.claude/skills/story-done/SKILL.md
.claude/skills/gate-check/SKILL.md
.claude/skills/start/SKILL.md
.claude/skills/quick-design/SKILL.md
.claude/skills/setup-engine/SKILL.md
README.md
docs/WORKFLOW-GUIDE.md
UPGRADING.md
```

---

### 文件：仔细合并

此版本中没有文件需要手动合并。所有变更都是基础设施文件，没有用户内容。

---

### 新功能

#### 总监门禁系统

所有主要工作流技能现在都引用定义在
`.claude/docs/director-gates.md` 中的命名门禁检查点。门禁由领域前缀和名称标识
（例如 `CD-CONCEPT`、`TD-ARCHITECTURE`、`LP-CODE-REVIEW`）。每个门禁定义
生成哪个总监、传递什么输入、各种裁定的含义，以及
lean/solo 模式如何影响它。

技能使用 `Task` 生成门禁，传入门禁 ID 和文档化的输入，而不是
内联嵌入总监提示。这保持了技能主体干净，并使
门禁行为在所有工作流阶段保持一致。

#### 门禁强度模式

三种模式让你控制获得多少总监评审：

- **`full`**（默认）——所有总监门禁在每个审查检查点运行
- **`lean`**——跳过按技能的总监评审；`/gate-check` 处的阶段门禁仍然运行
- **`solo`**——任何地方都没有总监门禁；`/gate-check` 仅检查产物是否存在

在 `/start` 期间全局设置（写入 `production/review-mode.txt`）。在任意使用门禁的技能上用 `--review [mode]` 覆盖单次运行：

```
/design-system combat --review lean
/gate-check concept --review full
/brainstorm my-game-idea --review solo
```

---

### 升级后

1. 运行一次 `/start` 来设置你偏好的评审模式——或手动创建 `production/review-mode.txt`，内容为 `full`、`lean` 或 `solo`。
2. 如果你正在项目进行中，查看 `.claude/docs/director-gates.md` 以了解哪些门禁适用于你当前阶段。
3. 运行 `/skill-test static all` 验证所有技能通过结构检查。

---

## v0.4.0 → v0.4.1

**发布：** 2026-03-26
**提交范围：** `04ed5d5..HEAD`
**关键主题：** 类型无关智能体、新技能、技能修复

### 变更内容

| 类别 | 变更 |
|----------|---------|
| **新技能 (1)** | `/consistency-check`——跨 GDD 实体一致性扫描器 |
| **技能修复（所有 team-*）** | 添加了无参数守卫、正式的 `Verdict: COMPLETE / BLOCKED` 关键字、按步骤 AskUserQuestion 门禁、相邻区域依赖检查（team-level）、伦理执行（team-live-ops）、带阶段跳过的 NO-GO 路径（team-release） |
| **智能体修复 (4)** | game-designer、systems-designer、economy-designer、live-ops-designer 中的类型无关语言——移除了 RPG 特定术语 |

---

### 文件：可安全覆盖

**要添加的新文件：**
```
.claude/skills/consistency-check/SKILL.md
```

**要覆盖的现有文件（无用户内容）：**
```
.claude/skills/team-combat/SKILL.md      ← no-arg guard, verdict keywords, gate improvements
.claude/skills/team-narrative/SKILL.md   ← no-arg guard, verdict keywords, gate improvements
.claude/skills/team-ui/SKILL.md          ← no-arg guard, verdict keywords, gate improvements
.claude/skills/team-release/SKILL.md     ← no-arg guard, verdict keywords, NO-GO path
.claude/skills/team-polish/SKILL.md      ← no-arg guard, verdict keywords, gate improvements
.claude/skills/team-audio/SKILL.md       ← no-arg guard, verdict keywords, gate improvements
.claude/skills/team-level/SKILL.md       ← no-arg guard, verdict keywords, adjacent area checks
.claude/skills/team-live-ops/SKILL.md    ← no-arg guard, verdict keywords, ethics enforcement
.claude/skills/team-qa/SKILL.md          ← no-arg guard, verdict keywords, gate improvements
.claude/skills/map-systems/SKILL.md      ← verdict keywords
.claude/skills/create-epics/SKILL.md     ← "May I write" protocol fix, verdict keywords
.claude/skills/create-stories/SKILL.md   ← verdict keywords
.claude/agents/game-designer.md          ← genre-agnostic language
.claude/agents/systems-designer.md       ← genre-agnostic language
.claude/agents/economy-designer.md       ← genre-agnostic language
.claude/agents/live-ops-designer.md      ← genre-agnostic language
```

---

### 文件：仔细合并

此版本中没有文件需要手动合并。所有变更都是基础设施文件，没有用户内容。

---

### 升级后

1. 运行 `/skill-test catalog` 验证所有技能已索引。
2. 在任何技能编辑后运行 `/skill-test lint [skill-name]` 检查结构合规性。
3. 如果你自定义了任何 team-* 技能，请查看更新后的版本——无参数守卫和 `Verdict:` 关键字现在对所有 team-* 技能是必需的。

---

## v0.3.0 → v0.4.0

**发布：** 2026-03-21
**提交范围：** `b1cad29..HEAD`
**关键主题：** 完整 UX/UI 管线、完整故事生命周期、棕地采纳、全面 QA/测试框架、管线完整性、29 个新技能

### 变更内容

| 类别 | 变更 |
|----------|---------|
| **新技能 (17)** | `/ux-design`、`/ux-review`、`/help`、`/quick-design`、`/review-all-gdds`、`/story-readiness`、`/story-done`、`/sprint-status`、`/adopt`、`/create-architecture`、`/create-control-manifest`、`/create-epics`、`/create-stories`、`/dev-story`、`/propagate-design-change`、`/content-audit`、`/architecture-review` |
| **新 QA 技能 (12)** | `/qa-plan`、`/smoke-check`、`/soak-test`、`/regression-suite`、`/test-setup`、`/test-helpers`、`/test-evidence-review`、`/test-flakiness`、`/skill-test`、`/bug-triage`、`/team-live-ops`、`/team-qa` |
| **新钩子 (4)** | `log-agent-stop.sh`——智能体审计轨迹停止；`notify.sh`——Windows 弹窗通知；`post-compact.sh`——压缩后的会话恢复提醒；`validate-skill-change.sh`——在技能编辑后建议 `/skill-test` |
| **新模板 (8)** | `ux-spec.md`、`hud-design.md`、`accessibility-requirements.md`、`interaction-pattern-library.md`、`player-journey.md`、`difficulty-curve.md`，以及 2 个采纳计划模板 |
| **新基础设施** | `workflow-catalog.yaml`（7 阶段流水线，由 `/help` 读取）、`docs/architecture/tr-registry.yaml`（稳定的 TR-ID）、`production/sprint-status.yaml` 模式 |
| **技能更新** | `/gate-check`——3 个门禁现在需要 UX 产物；预制作门禁需要垂直切片（硬门禁） |
| **技能更新** | `/sprint-plan`——写入 `sprint-status.yaml`；`/sprint-status` 读取它 |
| **技能更新** | `/story-done`——8 阶段完成评审，更新故事文件，浮现下一个就绪的故事 |
| **技能更新** | `/design-review`——移除了架构缺口检查（阶段不对） |
| **技能更新** | `/team-ui`——完整 UX 管线（ux-design → ux-review → team 阶段） |
| **智能体更新** | 14 个专家智能体——添加了 `memory: project` |
| **智能体更新** | `prototyper`——`isolation: worktree`（在隔离的 git 分支中做一次性工作） |
| **模型路由** | Haiku/Sonnet/Opus 层级分配记录在协调规则中；技能在 frontmatter 中声明其层级 |
| **目录 CLAUDE.md** | 脚手架了 `design/CLAUDE.md`、`src/CLAUDE.md`、`docs/CLAUDE.md`——每个目录的路径作用域指令 |
| **管线完整性** | TR-ID 稳定性、清单版本化、ADR 状态门禁、TR-ID 引用而非引用号 |
| **GDD 模板** | 添加了 `## Game Feel` 章节（输入响应性、动画目标、冲击时刻） |

---

### 文件：可安全覆盖

**要添加的新文件：**
```
.claude/skills/ux-design/SKILL.md
.claude/skills/ux-review/SKILL.md
.claude/skills/help/SKILL.md
.claude/skills/quick-design/SKILL.md
.claude/skills/review-all-gdds/SKILL.md
.claude/skills/story-readiness/SKILL.md
.claude/skills/story-done/SKILL.md
.claude/skills/sprint-status/SKILL.md
.claude/skills/adopt/SKILL.md
.claude/skills/create-architecture/SKILL.md
.claude/skills/create-control-manifest/SKILL.md
.claude/skills/create-epics/SKILL.md
.claude/skills/create-stories/SKILL.md
.claude/skills/dev-story/SKILL.md
.claude/skills/propagate-design-change/SKILL.md
.claude/skills/content-audit/SKILL.md
.claude/skills/architecture-review/SKILL.md
.claude/skills/qa-plan/SKILL.md
.claude/skills/smoke-check/SKILL.md
.claude/skills/soak-test/SKILL.md
.claude/skills/regression-suite/SKILL.md
.claude/skills/test-setup/SKILL.md
.claude/skills/test-helpers/SKILL.md
.claude/skills/test-evidence-review/SKILL.md
.claude/skills/test-flakiness/SKILL.md
.claude/skills/skill-test/SKILL.md
.claude/skills/bug-triage/SKILL.md
.claude/skills/team-live-ops/SKILL.md
.claude/skills/team-qa/SKILL.md
.claude/hooks/log-agent-stop.sh
.claude/hooks/notify.sh
.claude/hooks/post-compact.sh
.claude/hooks/validate-skill-change.sh
.claude/docs/workflow-catalog.yaml
.claude/docs/templates/ux-spec.md
.claude/docs/templates/hud-design.md
.claude/docs/templates/accessibility-requirements.md
.claude/docs/templates/interaction-pattern-library.md
.claude/docs/templates/player-journey.md
.claude/docs/templates/difficulty-curve.md
design/CLAUDE.md
src/CLAUDE.md
docs/CLAUDE.md
```

**要覆盖的现有文件（无用户内容）：**
```
.claude/skills/gate-check/SKILL.md
.claude/skills/sprint-plan/SKILL.md
.claude/skills/sprint-status/SKILL.md
.claude/skills/design-review/SKILL.md
.claude/skills/team-ui/SKILL.md
.claude/skills/story-readiness/SKILL.md
.claude/skills/story-done/SKILL.md
.claude/docs/templates/game-design-document.md    ← adds Game Feel section
README.md
docs/WORKFLOW-GUIDE.md
UPGRADING.md
```

**要覆盖的智能体文件**（如果你没有在其中写入自定义提示）：
```
.claude/agents/prototyper.md         ← adds isolation: worktree
.claude/agents/art-director.md       ← adds memory: project
.claude/agents/audio-director.md     ← adds memory: project
.claude/agents/economy-designer.md   ← adds memory: project
.claude/agents/game-designer.md      ← adds memory: project
.claude/agents/gameplay-programmer.md ← adds memory: project
.claude/agents/lead-programmer.md    ← adds memory: project
.claude/agents/level-designer.md     ← adds memory: project
.claude/agents/narrative-director.md ← adds memory: project
.claude/agents/systems-designer.md   ← adds memory: project
.claude/agents/technical-artist.md   ← adds memory: project
.claude/agents/ui-programmer.md      ← adds memory: project
.claude/agents/ux-designer.md        ← adds memory: project
.claude/agents/world-builder.md      ← adds memory: project
```

---

### 文件：仔细合并

#### `.claude/settings.json`

此版本注册了四个新钩子。如果你没有自定义过 `settings.json`，覆盖是安全的。否则，手动添加以下钩子条目：

- `log-agent-stop.sh`——`SubagentStop` 事件（智能体审计轨迹停止）
- `notify.sh`——`Notification` 事件（Windows 弹窗通知）
- `post-compact.sh`——`PostCompact` 事件（会话恢复提醒）
- `validate-skill-change.sh`——`PostToolUse` 事件，过滤到 `.claude/skills/` 写入

#### 自定义过的智能体文件

如果你在智能体 `.md` 文件中添加了项目特定的知识，请做一次 diff 并在合适的地方手动将 `memory: project` 行添加到 YAML frontmatter。创意和技术总监智能体有意保留 `memory: user`——只有专家智能体获得 `memory: project`。

---

### 新功能

#### 完整故事生命周期

故事现在有由两个技能强制执行的正式生命周期：

- **`/story-readiness`**——在开发者领取故事之前验证它是否已准备好实现。检查设计（GDD 需求已链接）、架构（ADR 已接受）、范围（标准可测试）和 DoD（清单版本最新）。裁定：READY / NEEDS WORK / BLOCKED。
- **`/story-done`**——实现后的 8 阶段完成评审。验证每个验收标准，检查 GDD/ADR 偏差，提示代码评审，将故事文件更新为 `Status: Complete`，并浮现下一个就绪的故事。

流程：`/story-readiness` → 实现 → `/story-done` → 下一个故事

#### 完整 UX/UI 管线

- **`/ux-design`**——引导式逐章 UX 规格创作。三种模式：屏幕/流程、HUD 或交互模式库。读取 GDD UI 需求和玩家旅程。输出到 `design/ux/`。
- **`/ux-review`**——根据 GDD 对齐、无障碍层级和模式库验证 UX 规格。裁定：APPROVED / NEEDS REVISION / MAJOR REVISION。
- **`/team-ui`** 更新：阶段 1 现在在视觉设计开始之前将 `/ux-design` + `/ux-review` 作为硬门禁运行。

#### 棕地采纳

**`/adopt`** 将现有项目接入模板格式。审计 GDD、ADR、故事、systems-index 和基础设施的内部结构。分类缺口（BLOCKING/HIGH/MEDIUM/LOW）。构建有序迁移计划。绝不重新生成已有产物——只填补缺口。

参数模式：`full | gdds | adrs | stories | infra`

此外：`/design-system retrofit [path]` 和 `/architecture-decision retrofit [path]` 检测现有文件并仅添加缺失章节。

#### 冲刺跟踪 YAML

`production/sprint-status.yaml` 现在是权威的故事跟踪格式：
- 由 `/sprint-plan`（初始化所有故事）和 `/story-done`（将状态设置为 `done`）写入
- 由 `/sprint-status`（快速快照）和 `/help`（制作阶段的按故事状态）读取
- 状态值：`backlog | ready-for-dev | in-progress | review | done | blocked`
- 如果文件不存在，优雅地回退到 markdown 扫描

#### `/help`——上下文感知的下一步

`/help` 读取你当前阶段和进行中的工作，检查哪些产物已完成，并告诉你接下来确切该做什么——一个主要必需步骤，加上可选机会。区别于 `/start`（仅首次）和 `/project-stage-detect`（完整审计）。

#### 全面 QA 和测试框架

九个新 QA/测试技能覆盖完整测试生命周期：

- **`/test-setup`**——为你的引擎脚手架测试框架和 CI/CD 管线
- **`/test-helpers`**——生成引擎特定的测试辅助库（GDUnit4、NUnit 等）
- **`/qa-plan`**——为冲刺或功能生成 QA 测试计划，按测试类型分类故事
- **`/smoke-check`**——在 QA 移交前运行关键路径冒烟测试门禁
- **`/soak-test`**——为长时间游戏会话生成浸泡测试协议（稳定性、内存泄漏）
- **`/regression-suite`**——将测试覆盖映射到 GDD 关键路径，识别缺乏回归测试的已修复 bug
- **`/test-evidence-review`**——测试文件和手动证据文档的质量评审
- **`/test-flakiness`**——通过读取 CI 运行日志检测非确定性测试
- **`/skill-test`**——验证技能文件的结构合规性和行为正确性（三种模式：lint、spec、catalog）

此外新增：**`/bug-triage`** 重新评估所有未关闭 bug 的优先级、严重性和归属。

#### 技能验证器 (`/skill-test`)

`/skill-test` 是一个用于验证框架本身的元技能。在编辑任何技能文件后运行它。三种模式：
- `lint`——验证 YAML frontmatter 和必需字段
- `spec [skill-name]`——对特定技能运行行为规格测试
- `catalog`——检查 `.claude/skills/` 中的所有技能是否已在目录中索引

新的 `validate-skill-change.sh` 钩子会在技能文件被修改时自动提醒你运行 `/skill-test`。

#### 团队 Live-Ops 和团队 QA 编排

- **`/team-live-ops`**——协调 live-ops-designer + economy-designer + community-manager + analytics-engineer 进行发布后内容规划（季节性活动、战斗通行证、留存）
- **`/team-qa`**——编排 qa-lead + qa-tester + gameplay-programmer + producer 完成完整 QA 周期：策略、执行、覆盖和签字

#### 模型层级路由

技能现在根据任务复杂度被明确分配到 Haiku、Sonnet 或 Opus 层级。只读状态检查使用 Haiku；复杂的多文档综合使用 Opus；其他一切默认为 Sonnet。层级分配记录在 `.claude/docs/coordination-rules.md` 中。

#### 目录 CLAUDE.md 文件

三个新的目录作用域 CLAUDE.md 文件（`design/`、`src/`、`docs/`）为在这些目录中工作的智能体提供路径特定指令。当 Claude Code 读取该目录中的文件时会自动加载。

---

### 升级后

1. **验证新钩子**已在 `.claude/settings.json` 中注册——检查全部四个：`log-agent-stop.sh`、`notify.sh`、`post-compact.sh`、`validate-skill-change.sh`。

2. **测试审计轨迹**，通过生成任意一子智能体——开始和停止事件都应出现在 `production/session-logs/` 中。

3. **生成 sprint-status.yaml**，如果你正在活跃制作中：
   ```
   /sprint-plan status
   ```

4. **运行 `/adopt`**，如果你有早于此模板版本的现有 GDD 或 ADR——它会识别需要添加哪些章节而不会覆盖你的内容。

5. **验证你的技能**，在任何技能编辑后用 `/skill-test`——新的 `validate-skill-change.sh` 钩子会自动提醒你这样做。

---

## v0.2.0 → v0.3.0

**发布：** 2026-03-09
**提交范围：** `e289ce9..HEAD`
**关键主题：** `/design-system` GDD 创作、`/map-systems` 重命名、自定义状态行

### 破坏性变更

#### `/design-systems` 重命名为 `/map-systems`

`/design-systems` 技能被重命名为 `/map-systems` 以求清晰
（分解 = *mapping*（映射），而非 *designing*（设计））。

**需要操作：** 更新任何调用
`/design-systems` 的文档、笔记或脚本。新的调用是 `/map-systems`。

### 变更内容

| 类别 | 变更 |
|----------|---------|
| **新技能** | `/design-system`（引导式 GDD 创作，逐章） |
| **重命名技能** | `/design-systems` → `/map-systems`（破坏性重命名） |
| **新文件** | `.claude/statusline.sh`、`.claude/settings.json` statusline 配置 |
| **技能更新** | `/gate-check`——在 PASS 时写入 `production/stage.txt`，新阶段定义 |
| **技能更新** | `brainstorm`、`start`、`design-review`、`project-stage-detect`、`setup-engine`——交叉引用修复 |
| **Bug 修复** | `log-agent.sh`、`validate-commit.sh`——钩子执行修复 |
| **文档** | 添加了 `UPGRADING.md`，更新了 `README.md`，更新了 `WORKFLOW-GUIDE.md` |

---

### 文件：可安全覆盖

**要添加的新文件：**
```
.claude/skills/design-system/SKILL.md
.claude/statusline.sh
```

**要覆盖的现有文件（无用户内容）：**
```
.claude/skills/map-systems/SKILL.md      ← was design-systems/SKILL.md
.claude/skills/gate-check/SKILL.md
.claude/skills/brainstorm/SKILL.md
.claude/skills/start/SKILL.md
.claude/skills/design-review/SKILL.md
.claude/skills/project-stage-detect/SKILL.md
.claude/skills/setup-engine/SKILL.md
.claude/hooks/log-agent.sh
.claude/hooks/validate-commit.sh
README.md
docs/WORKFLOW-GUIDE.md
UPGRADING.md
```

**删除（由重命名替代）：**
```
.claude/skills/design-systems/   ← entire directory; replaced by map-systems/
```

---

### 文件：仔细合并

#### `.claude/settings.json`

新版本添加了一个指向
`.claude/statusline.sh` 的 `statusLine` 配置块。如果你没有自定义过 `settings.json`，覆盖是安全的。否则，手动添加此块：

```json
"statusLine": {
  "script": ".claude/statusline.sh"
}
```

---

### 新功能

#### 自定义状态行

`.claude/statusline.sh` 在终端状态行中显示一个 7 阶段制作流水线面包屑：

```
ctx: 42% | claude-sonnet-4-6 | Systems Design
```

在制作/打磨/发布阶段，如果存在 `<!-- STATUS -->` 块，它还会显示来自
`production/session-state/active.md` 的活跃 Epic/Feature/Task：

```
ctx: 42% | claude-sonnet-4-6 | Production | Combat System > Melee Combat > Hitboxes
```

当前阶段从项目产物自动检测，或可通过
向 `production/stage.txt` 写入阶段名称来固定。

#### `/gate-check` 阶段推进

当门禁 PASS 裁定被确认时，`/gate-check` 现在会将新阶段
名称写入 `production/stage.txt`。这会立即为所有
未来会话更新状态行，无需手动编辑文件。

---

### 升级后

1. **删除旧技能目录：**
   ```bash
   rm -rf .claude/skills/design-systems/
   ```

2. **测试状态行**，通过启动一个 Claude Code 会话——你应该在终端底部看到
   阶段面包屑。

3. **验证钩子执行**仍然工作：
   ```bash
   bash .claude/hooks/log-agent.sh '{}' '{}'
   bash .claude/hooks/validate-commit.sh '{}' '{}'
   ```

---

## v0.1.0 → v0.2.0

**发布：** 2026-02-21
**提交范围：** `ad540fe..e289ce9`
**关键主题：** 上下文韧性、AskUserQuestion 集成、`/map-systems` 技能

### 变更内容

| 类别 | 变更 |
|----------|---------|
| **新技能** | `/start`（入门）、`/map-systems`（系统分解）、`/design-system`（引导式 GDD 创作） |
| **新钩子** | `session-start.sh`（恢复）、`detect-gaps.sh`（缺口检测） |
| **新模板** | `systems-index.md`、3 个协作协议模板 |
| **上下文管理** | 大重写——添加了文件 backed 状态策略 |
| **智能体更新** | 14 个设计/创意智能体——AskUserQuestion 集成 |
| **技能更新** | 所有 7 个 `team-*` 技能 + `brainstorm`——在阶段转换处使用 AskUserQuestion |
| **CLAUDE.md** | 从约 159 行精简到约 60 行；5 个文档导入而非 10 个 |
| **钩子更新** | 所有 8 个钩子——Windows 兼容性修复、新功能 |
| **移除的文档** | `docs/IMPROVEMENTS-PROPOSAL.md`、`docs/MULTI-STAGE-DOCUMENT-WORKFLOW.md` |

---

### 文件：可安全覆盖

这些是纯基础设施——你没有自定义过它们。直接复制新
版本，对你的项目内容没有风险。

**要添加的新文件：**
```
.claude/skills/start/SKILL.md
.claude/skills/map-systems/SKILL.md
.claude/skills/design-system/SKILL.md
.claude/docs/templates/systems-index.md
.claude/docs/templates/collaborative-protocols/design-agent-protocol.md
.claude/docs/templates/collaborative-protocols/implementation-agent-protocol.md
.claude/docs/templates/collaborative-protocols/leadership-agent-protocol.md
.claude/hooks/detect-gaps.sh
.claude/hooks/session-start.sh
production/session-state/.gitkeep
docs/examples/README.md
.github/ISSUE_TEMPLATE/bug_report.md
.github/ISSUE_TEMPLATE/feature_request.md
.github/PULL_REQUEST_TEMPLATE.md
```

**要覆盖的现有文件（无用户内容）：**
```
.claude/skills/brainstorm/SKILL.md
.claude/skills/design-review/SKILL.md
.claude/skills/gate-check/SKILL.md
.claude/skills/project-stage-detect/SKILL.md
.claude/skills/setup-engine/SKILL.md
.claude/skills/team-audio/SKILL.md
.claude/skills/team-combat/SKILL.md
.claude/skills/team-level/SKILL.md
.claude/skills/team-narrative/SKILL.md
.claude/skills/team-polish/SKILL.md
.claude/skills/team-release/SKILL.md
.claude/skills/team-ui/SKILL.md
.claude/hooks/log-agent.sh
.claude/hooks/pre-compact.sh
.claude/hooks/session-stop.sh
.claude/hooks/validate-assets.sh
.claude/hooks/validate-commit.sh
.claude/hooks/validate-push.sh
.claude/rules/design-docs.md
.claude/docs/hooks-reference.md
.claude/docs/skills-reference.md
.claude/docs/quick-start.md
.claude/docs/directory-structure.md
.claude/docs/context-management.md
docs/COLLABORATIVE-DESIGN-PRINCIPLE.md
docs/WORKFLOW-GUIDE.md
README.md
```

**要覆盖的智能体文件**（如果你没有在其中写入自定义提示）：
```
.claude/agents/art-director.md
.claude/agents/audio-director.md
.claude/agents/creative-director.md
.claude/agents/economy-designer.md
.claude/agents/game-designer.md
.claude/agents/level-designer.md
.claude/agents/live-ops-designer.md
.claude/agents/narrative-director.md
.claude/agents/producer.md
.claude/agents/systems-designer.md
.claude/agents/technical-director.md
.claude/agents/ux-designer.md
.claude/agents/world-builder.md
.claude/agents/writer.md
```

如果你*已经*自定义了智能体提示，请参见下面的"仔细合并"。

---

### 文件：仔细合并

这些文件同时包含模板结构和你的项目特定内容。
**不要**覆盖它们——手动合并变更。

#### `CLAUDE.md`

模板版本从约 159 行精简到约 60 行。关键
结构性变更：移除了 5 个文档导入，因为它们反正会被
Claude Code 自动加载（agent-roster、skills-reference、hooks-reference、
rules-reference、review-workflow）。

**从你的版本中保留什么：**
- `## Technology Stack` 章节（你的引擎/语言选择）
- 你添加的任何项目特定内容

**从新版本中采纳什么：**
- 更精简的导入列表（如果存在则丢弃 5 个冗余的 `@` 导入）
- 更新的协作协议措辞

#### `.claude/docs/technical-preferences.md`

如果你运行过 `/setup-engine`，这个文件有你的引擎配置、命名
约定和性能预算。全部保留。模板版本
只是空的占位符。

#### `.claude/docs/templates/game-concept.md`

次要结构性更新——添加了一个指向
`/map-systems` 的 `## Next Steps` 章节。如果你想要更新的
指引，将该章节添加到你的副本中，但不是必需的。

#### `.claude/settings.json`

检查新版本是否添加了你想要的任何权限规则。变更
很小（模式更新）。如果你没有自定义过你的 `settings.json`，
覆盖是安全的。

#### 自定义过的智能体文件

如果你为任何智能体
`.md` 文件添加了项目特定的知识或自定义行为，请做一次 diff 并手动添加新的 AskUserQuestion 集成
章节，而不是覆盖。每个智能体中的变更是系统提示
末尾一个标准化的协作协议块。

---

### 文件：删除

这些文件在 v0.2.0 中被移除。如果你的仓库中存在，你可以安全地
删除它们——它们被组织得更好的替代方案取代。

```
docs/IMPROVEMENTS-PROPOSAL.md      → superseded by WORKFLOW-GUIDE.md
docs/MULTI-STAGE-DOCUMENT-WORKFLOW.md → content merged into context-management.md
```

---

### 升级后

1. **运行 `/project-stage-detect`** 验证系统用新的检测
   逻辑正确读取你的项目。

2. **运行一次 `/start`**，如果你还没有用过——它现在能正确识别
   你的阶段并跳过你已经完成的入门步骤。

3. **检查 `production/session-state/`** 存在且被 gitignored：
   ```bash
   ls production/session-state/
   cat .gitignore | grep session-state
   ```

4. **测试钩子执行**——如果你在 Windows 上，验证新钩子在
   Git Bash 中无错误运行：
   ```bash
   bash .claude/hooks/detect-gaps.sh '{}' '{}'
   bash .claude/hooks/session-start.sh '{}' '{}'
   ```

---

*未来的每个版本都会在本文件中有自己的章节。*
