
<p align="center">
  <h1 align="center">Claude Code Game Studios</h1>
  <p align="center">
    将单个 Claude Code 会话变成一个完整的游戏开发工作室。
    <br />
    49 个智能体 (agent)。73 个技能 (skill)。一个协同的 AI 团队。
  </p>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <a href=".claude/agents"><img src="https://img.shields.io/badge/agents-49-blueviolet" alt="49 Agents"></a>
  <a href=".claude/skills"><img src="https://img.shields.io/badge/skills-73-green" alt="73 Skills"></a>
  <a href=".claude/hooks"><img src="https://img.shields.io/badge/hooks-12-orange" alt="12 Hooks"></a>
  <a href=".claude/rules"><img src="https://img.shields.io/badge/rules-11-red" alt="11 Rules"></a>
  <a href="https://docs.anthropic.com/en/docs/claude-code"><img src="https://img.shields.io/badge/built%20for-Claude%20Code-f5f5f5?logo=anthropic" alt="Built for Claude Code"></a>
  <a href="https://www.buymeacoffee.com/donchitos3"><img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-Support%20this%20project-FFDD00?logo=buymeacoffee&logoColor=black" alt="Buy Me a Coffee"></a>
  <a href="https://github.com/sponsors/Donchitos"><img src="https://img.shields.io/badge/GitHub%20Sponsors-Support%20this%20project-ea4aaa?logo=githubsponsors&logoColor=white" alt="GitHub Sponsors"></a>
</p>

---

## 为什么会有这个项目

独自用 AI 开发游戏很强大——但单个聊天会话没有结构。没有人阻止你硬编码魔法数字、跳过设计文档，或者写出意大利面条式代码。没有 QA 流程，没有设计评审，没有人问"这真的符合游戏的愿景吗？"

**Claude Code Game Studios** 通过给你的 AI 会话赋予真实工作室的结构来解决这个问题。你不再是只有一个通用助手，而是得到 49 个组织成工作室层级的专门化智能体——守护愿景的总监、负责各自领域的部门主管，以及做实际动手工作的专家。每个智能体都有明确的职责、升级路径和质量门禁 (quality gate)。

结果是：你仍然做出每一个决定，但现在你有一个团队会提出正确的问题、及早发现错误，并让你的项目从最初的头脑风暴到发布都保持井井有条。

---

## 目录

- [包含内容](#包含内容)
- [工作室层级](#工作室层级)
- [斜杠命令](#斜杠命令)
- [快速开始](#快速开始)
- [升级](#升级)
- [项目结构](#项目结构)
- [工作原理](#工作原理)
- [设计哲学](#设计哲学)
- [自定义](#自定义)
- [平台支持](#平台支持)
- [社区](#社区)
- [支持本项目](#支持本项目)
- [许可证](#许可证)

---

## 包含内容

| 类别 | 数量 | 说明 |
|----------|-------|-------------|
| **智能体 (Agents)** | 49 | 横跨设计、程序、美术、音频、叙事、QA 和制作的专门化子智能体 |
| **技能 (Skills)** | 73 | 覆盖每个工作流阶段的斜杠命令（`/start`、`/design-system`、`/create-epics`、`/create-stories`、`/dev-story`、`/story-done` 等） |
| **钩子 (Hooks)** | 12 | 在提交、推送、资产变更、会话生命周期、智能体审计轨迹和缺口检测时自动执行验证 |
| **规则 (Rules)** | 11 | 在编辑玩法、引擎、AI、UI、网络代码等时按路径作用域强制执行的编码标准 |
| **模板 (Templates)** | 41 | 用于 GDD、UX 规格、ADR、冲刺计划、HUD 设计、无障碍等的文档模板 |

## 工作室层级

智能体被组织为三个层级，与现实工作室的运作方式一致：

```
Tier 1 — Directors (Opus)
  creative-director    technical-director    producer

Tier 2 — Department Leads (Sonnet)
  game-designer        lead-programmer       art-director
  audio-director       narrative-director    qa-lead
  release-manager      localization-lead

Tier 3 — Specialists (Sonnet/Haiku)
  gameplay-programmer  engine-programmer     ai-programmer
  network-programmer   tools-programmer      ui-programmer
  systems-designer     level-designer        economy-designer
  technical-artist     sound-designer        writer
  world-builder        ux-designer           prototyper
  performance-analyst  devops-engineer       analytics-engineer
  security-engineer    qa-tester             accessibility-specialist
  live-ops-designer    community-manager
```

### 引擎专家

模板包含适用于三大主流引擎的智能体集合。使用与你的项目匹配的那一套：

| 引擎 | 主管智能体 | 子专家 |
|--------|-----------|-----------------|
| **Godot 4** | `godot-specialist` | GDScript、着色器、GDExtension |
| **Unity** | `unity-specialist` | DOTS/ECS、着色器/VFX、Addressables、UI Toolkit |
| **Unreal Engine 5** | `unreal-specialist` | GAS、Blueprints、复制、UMG/CommonUI |

## 斜杠命令

在 Claude Code 中输入 `/` 即可访问全部 73 个技能：

**入门与导航**
`/start` `/help` `/project-stage-detect` `/setup-engine` `/adopt`

**游戏设计**
`/brainstorm` `/map-systems` `/design-system` `/quick-design` `/review-all-gdds` `/propagate-design-change`

**美术与资产**
`/art-bible` `/asset-spec` `/asset-audit`

**UX 与界面设计**
`/ux-design` `/ux-review`

**架构**
`/create-architecture` `/architecture-decision` `/architecture-review` `/create-control-manifest`

**故事与冲刺**
`/create-epics` `/create-stories` `/dev-story` `/sprint-plan` `/sprint-status` `/story-readiness` `/story-done` `/estimate`

**评审与分析**
`/design-review` `/code-review` `/balance-check` `/content-audit` `/scope-check` `/perf-profile` `/tech-debt` `/gate-check` `/consistency-check` `/security-audit`

**QA 与测试**
`/qa-plan` `/smoke-check` `/soak-test` `/regression-suite` `/test-setup` `/test-helpers` `/test-evidence-review` `/test-flakiness` `/skill-test` `/skill-improve`

**制作**
`/milestone-review` `/retrospective` `/bug-report` `/bug-triage` `/reverse-document` `/playtest-report`

**发布**
`/release-checklist` `/launch-checklist` `/changelog` `/patch-notes` `/hotfix` `/day-one-patch`

**创意与内容**
`/prototype` `/onboard` `/localize`

**团队编排**（在单个功能上协调多个智能体）
`/team-combat` `/team-narrative` `/team-ui` `/team-release` `/team-polish` `/team-audio` `/team-level` `/team-live-ops` `/team-qa`

## 快速开始

### 前置条件

- [Git](https://git-scm.com/)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)（`npm install -g @anthropic-ai/claude-code`）
- **推荐**：[jq](https://jqlang.github.io/jq/)（用于钩子验证）和 Python 3（用于 JSON 验证）

所有钩子在缺少可选工具时都会优雅地失败——不会出问题，你只是失去一些验证能力。

### 安装

1. **克隆或作为模板使用**：
   ```bash
   git clone https://github.com/Donchitos/Claude-Code-Game-Studios.git my-game
   cd my-game
   ```

2. **打开 Claude Code** 并启动一个会话：
   ```bash
   claude
   ```

3. **运行 `/start`**——系统会问你在哪个阶段（没有想法、模糊的概念、清晰的设计、已有工作），并引导你到合适的工作流。不做任何假设。

   如果你已经知道自己需要什么，也可以直接跳到某个具体技能：
   - `/brainstorm`——从零开始探索游戏创意
   - `/setup-engine godot 4.6`——如果你已经确定，配置你的引擎
   - `/project-stage-detect`——分析一个已有项目

## 升级

已经在使用旧版本的模板？参见 [UPGRADING.md](UPGRADING.md)
获取分步迁移说明、版本之间的变更分解，以及哪些文件可以安全覆盖、哪些需要手动合并。

## 项目结构

```
CLAUDE.md                           # 主配置
.claude/
  settings.json                     # 钩子、权限、安全规则
  agents/                           # 49 个智能体定义（markdown + YAML frontmatter）
  skills/                           # 73 个斜杠命令（每个技能一个子目录）
  hooks/                            # 12 个钩子脚本（bash，跨平台）
  rules/                            # 11 个路径作用域编码标准
  statusline.sh                     # 状态行脚本（上下文%、模型、阶段、史诗面包屑）
  docs/
    workflow-catalog.yaml           # 7 阶段流水线定义（由 /help 读取）
    templates/                      # 41 个文档模板
src/                                # 游戏源代码
assets/                             # 美术、音频、VFX、着色器、数据文件
design/                             # GDD、叙事文档、关卡设计
docs/                               # 技术文档和 ADR
tests/                              # 测试套件（单元、集成、性能、试玩）
tools/                              # 构建和流水线工具
prototypes/                         # 一次性原型（与 src/ 隔离）
production/                         # 冲刺计划、里程碑、发布跟踪
```

## 工作原理

### 智能体协作

智能体遵循结构化的委派模型：

1. **垂直委派**——总监委派给主管，主管委派给专家
2. **横向协商**——同层级的智能体可以互相协商，但不能做出跨领域的约束性决定
3. **冲突解决**——分歧向上升级到共同的父级（设计方面升级到 `creative-director`，技术方面升级到 `technical-director`）
4. **变更传播**——跨部门变更由 `producer` 协调
5. **领域边界**——智能体不会在没有明确委派的情况下修改其领域之外的文件

### 协作而非自治

这**不是**一个自动驾驶系统。每个智能体都遵循严格的协作协议：

1. **提问**——智能体在提出方案前先提问
2. **呈现选项**——智能体展示 2-4 个选项及优缺点
3. **你来决定**——用户始终做最终决定
4. **起草**——智能体在定稿前先展示工作成果
5. **批准**——没有你的签字，什么都不会写入

你始终保持控制。智能体提供的是结构和专业能力，而非自治权。

### 自动化安全

**钩子**在每次会话时自动运行：

| 钩子 | 触发条件 | 作用 |
|------|---------|--------------|
| `validate-commit.sh` | PreToolUse (Bash) | 检查硬编码值、TODO 格式、JSON 有效性、设计文档章节——如果命令不是 `git commit` 则提前退出 |
| `validate-push.sh` | PreToolUse (Bash) | 对推送到受保护分支发出警告——如果命令不是 `git push` 则提前退出 |
| `validate-assets.sh` | PostToolUse (Write/Edit) | 验证命名约定和 JSON 结构——如果文件不在 `assets/` 中则提前退出 |
| `session-start.sh` | 会话开启 | 显示当前分支和最近提交以供定位 |
| `detect-gaps.sh` | 会话开启 | 检测新项目（建议 `/start`）以及当代码或原型存在时缺失的设计文档 |
| `pre-compact.sh` | 压缩前 | 保留会话进度笔记 |
| `post-compact.sh` | 压缩后 | 提醒 Claude 从 `active.md` 恢复会话状态 |
| `notify.sh` | 通知事件 | 通过 PowerShell 显示 Windows 弹窗通知 |
| `session-stop.sh` | 会话关闭 | 将 `active.md` 归档到会话日志并记录 git 活动 |
| `log-agent.sh` | 智能体生成 | 审计轨迹开始——记录子智能体调用 |
| `log-agent-stop.sh` | 智能体停止 | 审计轨迹停止——完成子智能体记录 |
| `validate-skill-change.sh` | PostToolUse (Write/Edit) | 在任何 `.claude/skills/` 变更后建议运行 `/skill-test` |

> **注意**：`validate-commit.sh`、`validate-assets.sh` 和 `validate-skill-change.sh` 会在每次 Bash/Write 工具调用时触发，当命令或文件路径不相关时立即退出（exit 0）。这是正常的钩子行为——不是性能问题。

`settings.json` 中的**权限规则**自动允许安全操作（git status、测试运行）并阻止危险操作（force push、`rm -rf`、读取 `.env` 文件）。

### 路径作用域规则

编码标准根据文件位置自动强制执行：

| 路径 | 强制执行 |
|------|----------|
| `src/gameplay/**` | 数据驱动值、使用 delta time、无 UI 引用 |
| `src/core/**` | 热点路径零分配、线程安全、API 稳定性 |
| `src/ai/**` | 性能预算、可调试性、数据驱动参数 |
| `src/networking/**` | 服务器权威、版本化消息、安全 |
| `src/ui/**` | 不持有游戏状态、本地化就绪、无障碍 |
| `design/gdd/**` | 必需的 8 个章节、公式格式、边缘情况 |
| `tests/**` | 测试命名、覆盖率要求、夹具模式 |
| `prototypes/**` | 放宽标准、需要 README、记录假设 |

## 设计哲学

这个模板扎根于专业的游戏开发实践：

- **MDA 框架**——用于游戏设计的机制 (Mechanics)、动态 (Dynamics)、美学 (Aesthetics) 分析
- **自我决定理论**——用于玩家动机的自主 (Autonomy)、胜任 (Competence)、关系 (Relatedness)
- **心流状态设计**——用于玩家投入的挑战-技能平衡
- **Bartle 玩家类型**——受众定位与验证
- **验证驱动开发**——先写测试，再实现

## 自定义

这是一个**模板**，不是锁死的框架。一切都是为了被自定义而设计的：

- **添加/删除智能体**——删除你不需要的智能体文件，为你的领域添加新的
- **编辑智能体提示**——调整智能体行为，添加项目特定的知识
- **修改技能**——调整工作流以匹配你团队的过程
- **添加规则**——为你的项目目录结构创建新的路径作用域规则
- **调整钩子**——调整验证严格程度，添加新检查
- **选择你的引擎**——使用 Godot、Unity 或 Unreal 智能体集合（或都不用）
- **设置评审强度**——`full`（所有总监门禁）、`lean`（仅阶段门禁）或 `solo`（无门禁）。在 `/start` 时设置或编辑 `production/review-mode.txt`。在任意技能上用 `--review solo` 按次覆盖。

## 平台支持

主要在 **Windows 10** 上使用 Git Bash 进行开发和测试。所有钩子都使用 POSIX 兼容模式（`grep -E`，而非 `grep -P`）并为缺失的工具提供回退，因此它们应该能在 macOS 和 Linux 上运行。`notify.sh` 钩子使用 PowerShell 实现 Windows 弹窗通知，在其他平台上是空操作——macOS/Linux 上的桌面通知尚未接入。跨平台测试正在进行中；如遇任何平台特定的故障请提交 issue。

## 社区

- **讨论**——[GitHub Discussions](https://github.com/Donchitos/Claude-Code-Game-Studios/discussions)，用于提问、创意和展示你构建的内容
- **Issues**——[Bug 报告和功能请求](https://github.com/Donchitos/Claude-Code-Game-Studios/issues)

---

## 支持本项目

Claude Code Game Studios 是免费且开源的。如果它为你节省了时间或帮助你发布了游戏，请考虑支持持续开发：

<p>
  <a href="https://www.buymeacoffee.com/donchitos3"><img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me a Coffee"></a>
  &nbsp;
  <a href="https://github.com/sponsors/Donchitos"><img src="https://img.shields.io/badge/GitHub%20Sponsors-ea4aaa?style=for-the-badge&logo=githubsponsors&logoColor=white" alt="GitHub Sponsors"></a>
</p>

- **[Buy Me a Coffee](https://www.buymeacoffee.com/donchitos3)**——一次性支持
- **[GitHub Sponsors](https://github.com/sponsors/Donchitos)**——通过 GitHub 进行持续支持

赞助有助于资助维护技能、添加新智能体、跟进 Claude Code 和引擎 API 变更以及响应社区问题所花费的时间。

---

*为 Claude Code 而构建。持续维护和扩展——欢迎通过 [GitHub Discussions](https://github.com/Donchitos/Claude-Code-Game-Studios/discussions) 贡献。*

## 许可证

MIT License。详情见 [LICENSE](LICENSE)。
