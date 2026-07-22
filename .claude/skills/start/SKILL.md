---
name: start
description: "首次上手引导——询问你当前的进度，然后引导你进入正确的工作流程。不做任何假设。"
argument-hint: "[no arguments]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, AskUserQuestion

---


# 引导式上手 (Guided Onboarding)

此技能写入一个文件：`production/review-mode.txt`（审查模式配置在阶段 3b 中设置）。

此技能是新用户的入口点。它**不**假设你已有游戏创意、引擎偏好或任何先前经验。它先询问，然后将你引导到正确的工作流程。

---

## 阶段 1：检测项目状态

在询问任何问题之前，静默收集上下文，以便你能够量身定制指导。**不要**未经提示就展示这些结果——它们用于指导你的建议，而非开场白。

检查：
- **引擎是否已配置？** 读取 `.claude/docs/technical-preferences.md`。如果引擎字段包含 `[TO BE CONFIGURED]`，则引擎未设置。
- **游戏概念是否存在？** 检查 `design/gdd/game-concept.md`。
- **源代码是否存在？** 在 `src/` 中 glob 搜索源文件（`*.gd`、`*.cs`、`*.cpp`、`*.h`、`*.rs`、`*.py`、`*.js`、`*.ts`）。
- **原型是否存在？** 检查 `prototypes/` 中的子目录。
- **设计文档是否存在？** 计算 `design/gdd/` 中的 markdown 文件数量。
- **生产制品？** 检查 `production/sprints/` 或 `production/milestones/` 中的文件。

在内部存储这些发现，以验证用户的自我评估并定制建议。

---

## 阶段 2：询问用户处于哪个阶段

这是用户首先看到的内容。使用 `AskUserQuestion` 并提供这些确切的选项，使用户可以点击而非输入：

- **提示**："欢迎来到 Claude Code Game Studios！在我提出任何建议之前，我想了解你的出发点。你现在对你的游戏创意处于哪个阶段？"
- **选项**：
  - `A) 还没有想法` — 我完全没有游戏概念。我想探索并弄清楚要做什么。
  - `B) 模糊的想法` — 我心中有一个粗略的主题、感觉或类型（例如"关于太空的"或"一个舒适的农场游戏"），但没有具体内容。
  - `C) 清晰的概念` — 我知道核心想法——类型、基本机制，可能还有一个一句话宣传语——但尚未将其正式化为文档。
  - `D) 已有工作基础` — 我已经有设计文档、原型、代码或已完成的重要规划。我想组织或继续工作。

等待用户的选择。在用户响应之前不要继续。

---

## 阶段 3：根据答案路由

#### 如果 A：还没有想法

用户在开始其他工作之前需要创意探索。

1. 确认从零开始完全没有问题
2. 简要解释 `/brainstorm` 的功能（使用专业框架——MDA、玩家心理学、动词优先设计——的引导式构思）。提及它有两种模式：`/brainstorm open` 用于完全开放式的探索，或如果他们有一个哪怕模糊的主题（例如"太空"、"舒适"、"恐怖"），可以使用 `/brainstorm [hint]`。
3. 建议将 `/brainstorm open` 作为下一步运行，但如果他们想到什么，也邀请他们使用提示词
4. 展示推荐的路径：
   **概念阶段：**
   - `/brainstorm open` — 发现你的游戏概念
   - `/setup-engine` — 配置引擎（brainstorm 会推荐一个）
   - `/prototype` — 一次性概念构建：在设计前验证核心创意是否有趣（1-3 天）
   - `/art-bible` — 定义视觉身份（使用 brainstorm 产生的视觉身份锚点）
   - `/map-systems` — 将概念分解为系统
   - `/design-system` — 为每个 MVP 系统编写 GDD
   - `/review-all-gdds` — 跨系统一致性检查
   - `/gate-check` — 在架构工作前验证准备就绪
   **架构阶段：**
   - `/create-architecture` — 生成主架构蓝图和必需 ADR 列表
   - `/architecture-decision (×N)` — 记录关键技术决策，遵循必需 ADR 列表
   - `/create-control-manifest` — 将决策编译为可操作的规则表
   - `/architecture-review` — 验证架构覆盖范围
   **预生产阶段：**
   - `/ux-design` — 编写关键屏幕的 UX 规范（主菜单、HUD、核心交互）
   - `/vertical-slice` — 生产质量端到端构建，验证完整的游戏循环
   - `/playtest-report (×1+)` — 记录每次垂直切片试玩会话
   - `/create-epics` — 将系统映射到史诗
   - `/create-stories` — 将史诗分解为可实现的故事
   - `/sprint-plan` — 规划第一个冲刺
   **生产阶段：** → 使用 `/dev-story` 开始处理故事

#### 如果 B：模糊的想法

1. 请他们分享模糊的想法——即使只有几个词也足够了
2. 确认这是一个好的起点（不要评判或重新引导）
3. 建议运行 `/brainstorm [他们的提示词]` 来发展它
4. 展示推荐的路径：
   **概念阶段：**
   - `/brainstorm [提示词]` — 将想法发展为完整概念
   - `/setup-engine` — 配置引擎
   - `/prototype` — 一次性概念构建：在设计前验证核心创意是否有趣（1-3 天）
   - `/art-bible` — 定义视觉身份（使用 brainstorm 产生的视觉身份锚点）
   - `/map-systems` — 将概念分解为系统
   - `/design-system` — 为每个 MVP 系统编写 GDD
   - `/review-all-gdds` — 跨系统一致性检查
   - `/gate-check` — 在架构工作前验证准备就绪
   **架构阶段：**
   - `/create-architecture` — 生成主架构蓝图和必需 ADR 列表
   - `/architecture-decision (×N)` — 记录关键技术决策，遵循必需 ADR 列表
   - `/create-control-manifest` — 将决策编译为可操作的规则表
   - `/architecture-review` — 验证架构覆盖范围
   **预生产阶段：**
   - `/ux-design` — 编写关键屏幕的 UX 规范（主菜单、HUD、核心交互）
   - `/vertical-slice` — 生产质量端到端构建，验证完整的游戏循环
   - `/playtest-report (×1+)` — 记录每次垂直切片试玩会话
   - `/create-epics` — 将系统映射到史诗
   - `/create-stories` — 将史诗分解为可实现的故事
   - `/sprint-plan` — 规划第一个冲刺
   **生产阶段：** → 使用 `/dev-story` 开始处理故事

#### 如果 C：清晰的概念

1. 请他们用一句话描述他们的概念——类型和核心机制。使用纯文本，而非 AskUserQuestion（这是一个开放式回答）。
2. 确认概念，然后使用 `AskUserQuestion` 提供两条路径：
   - **提示**："你希望如何进行？"
   - **选项**：
     - `先将其正式化` — 运行 `/brainstorm [concept]` 将其结构化为合适的游戏概念文档
     - `直接跳入` — 立即转到 `/setup-engine`，之后手动编写 GDD
3. 展示推荐的路径：
   **概念阶段：**
   - `/brainstorm` 或 `/setup-engine` —（他们在步骤 2 中的选择）
   - `/prototype` — 一次性概念构建：在设计前验证核心创意是否有趣（1-3 天）
   - `/art-bible` — 定义视觉身份（如果在 brainstorm 之后运行，或在概念文档存在之后）
   - `/design-review` — 验证概念文档
   - `/map-systems` — 将概念分解为单个系统
   - `/design-system` — 为每个 MVP 系统编写 GDD
   - `/review-all-gdds` — 跨系统一致性检查
   - `/gate-check` — 在架构工作前验证准备就绪
   **架构阶段：**
   - `/create-architecture` — 生成主架构蓝图和必需 ADR 列表
   - `/architecture-decision (×N)` — 记录关键技术决策，遵循必需 ADR 列表
   - `/create-control-manifest` — 将决策编译为可操作的规则表
   - `/architecture-review` — 验证架构覆盖范围
   **预生产阶段：**
   - `/ux-design` — 编写关键屏幕的 UX 规范（主菜单、HUD、核心交互）
   - `/vertical-slice` — 生产质量端到端构建，验证完整的游戏循环
   - `/playtest-report (×1+)` — 记录每次垂直切片试玩会话
   - `/create-epics` — 将系统映射到史诗
   - `/create-stories` — 将史诗分解为可实现的故事
   - `/sprint-plan` — 规划第一个冲刺
   **生产阶段：** → 使用 `/dev-story` 开始处理故事

#### 如果 D：已有工作基础

1. 分享你在阶段 1 中发现的内容：
   - "我可以看到你有 [X 个源文件 / Y 个设计文档 / Z 个原型]……"
   - "你的引擎是 [已配置为 X / 尚未配置]……"

2. **子情况 D1——早期阶段**（引擎未配置或仅有游戏概念存在）：
   - 如果引擎未配置，建议先 `/setup-engine`
   - 然后 `/project-stage-detect` 进行差距盘点

   **子情况 D2——已存在 GDD、ADR 或故事：**
   - 解释："拥有文件并不等同于模板的技能能够使用它们。GDD 可能缺少必需的部分。`/adopt` 专门检查这一点。"
   - 建议：
     1. `/project-stage-detect` — 了解所处的阶段和完全缺失的内容
     2. `/adopt` — 审计现有制品是否符合正确的内部格式

3. 展示 D2 推荐的路径：
   - `/project-stage-detect` — 阶段检测 + 存在性差距
   - `/adopt` — 格式合规审计 + 迁移计划
   - `/setup-engine` — 如果引擎未配置
   - `/design-system retrofit [path]` — 填充缺失的 GDD 章节
   - `/architecture-decision retrofit [path]` — 添加缺失的 ADR 章节
   - `/architecture-review` — 引导 TR 需求注册表
   - `/gate-check` — 验证下一阶段的准备就绪

---

## 阶段 3c：写入初始阶段文件

在确认起始路径后（并在询问审查模式之前），将初始阶段写入 `production/stage.txt`。如果 `production/` 目录不存在，则创建它。

阶段映射：
- **路径 A、B 或 C（从头开始）**：写入 `Concept`
- **路径 D，现有项目，引擎未配置或仅有游戏概念存在**：写入 `Concept`
- **路径 D，现有项目，有 GDD 但没有架构文档**：写入 `Systems Design`
- **路径 D，现有项目，有完整架构（ADR、架构文档）**：写入 `Technical Setup`

静默执行此操作——这个单行文件不需要"我可以写入吗？"的询问。

提示："我已将 `production/stage.txt` 设置为 `[stage]`——这将锚定你的状态栏和阶段检测。"

---

## 阶段 3b：设置审查模式

检查 `production/review-mode.txt` 是否已存在。

**如果存在**：读取并显示当前模式——"审查模式已设置为 `[current]`。"——然后继续到阶段 4。不要再次询问。

**如果不存在**：使用 `AskUserQuestion`：

- **提示**："一个设置选项：你在工作流程中希望进行多少设计审查？"
- **选项**：
  - `Full` — 主管专家在每个关键工作流步骤进行审查。最适合团队、学习工作流程，或当你希望对每个决策都获得全面反馈时。
  - `Lean（推荐）` — 仅阶段关口转换时的主管审查（/gate-check）。跳过每个技能的审查。适合独立开发者和小型团队的平衡方法。
  - `Solo` — 完全不需要主管审查。最大速度。最适合游戏开发大赛、原型制作，或当审查感觉像额外负担时。

在用户选择后立即将选择写入 `production/review-mode.txt`——无需单独的"我可以写入吗？"，因为写入是选择的直接结果：
- `Full` → 写入 `full`
- `Lean（推荐）` → 写入 `lean`
- `Solo` → 写入 `solo`

如果 `production/` 目录不存在，则创建它。

---

## 阶段 4：继续前确认

在展示推荐的路径后，使用 `AskUserQuestion` 询问用户想先进行哪一步。绝不自动运行下一个技能。

- **提示**："你想从 [推荐的第一步] 开始吗？"
- **选项**：
  - `是的，从 [推荐的第一步] 开始`
  - `我想先做点别的`

---

## 阶段 5：交接

当用户确认他们的下一步时，用简短的一句话回复："输入 `[skill command]` 开始。"不要多说。不要重新解释该技能或添加鼓励。`/start` 技能的工作已完成。

判定：**COMPLETE**——用户已获得引导并交接至下一步。

---

## 阶段 6：边缘情况

- **用户选择 D 但项目是空的**：温和地引导——"项目似乎是一个全新模板，还没有任何制品。路径 A 或 B 是否更合适？"
- **用户选择 A 但项目中有代码**：提及你的发现——"我注意到 `src/` 中已有代码。你是想选 D（已有工作基础）吗？"
- **用户是返回的（引擎已配置，概念已存在）**：完全跳过上手流程——"看起来你已经设置好了！你的引擎是 [X]，并且你在 `design/gdd/game-concept.md` 有一个游戏概念。审查模式：`[从 production/review-mode.txt 读取，如果缺失则默认为 'lean']`。想继续之前的工作吗？试试 `/sprint-plan` 或直接告诉我你想做什么。"
- **用户不符合任何选项**：让他们用自己的话描述情况并相应调整。

---

## 协作协议

1. **先询问**——绝不假设用户的状态或意图
2. **提供选项**——提供清晰的路径，而非强制要求
3. **用户决定**——他们选择方向
4. **不自动执行**——推荐下一个技能，未经询问不要运行它
5. **调整适应**——如果用户的情况不符合模板，倾听并调整
