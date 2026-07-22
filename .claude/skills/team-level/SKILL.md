---
name: team-level
description: "编排关卡设计团队：level-designer + narrative-director + world-builder + art-director + systems-designer + qa-tester，完成整个区域/关卡的创建。"
argument-hint: "[level name or area to design] [--review full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash, Task, AskUserQuestion, TodoWrite

---


当此 skill 被调用时：

**决策点：** 在每个步骤转换时，使用 `AskUserQuestion` 将子代理的提案以可选项的形式呈现给用户。先在对话中写出代理的完整分析，然后用简洁的标签捕获决策。必须获得用户批准后才能进入下一步。

## 阶段 0：解析评审模式

1. 如果参数中传入了 `--review [mode]`，使用该模式。
2. 否则读取 `production/review-mode.txt` —— 使用其中写入的值。
3. 否则默认为 `lean`。

模式：
- `full` —— 按描述生成所有 director 和 lead 关卡
- `lean` —— 跳过 director 关卡，除非它们是 PHASE-GATE 类型（CD-PHASE-GATE、TD-PHASE-GATE、PR-PHASE-GATE、AD-PHASE-GATE）
- `solo` —— 完全跳过所有 director 关卡的生成；不带任何代理关卡运行此 skill

保存解析后的模式，供后续所有阶段使用。

1. **读取参数**以确定目标关卡或区域（例如 `tutorial`、
   `forest dungeon`、`hub town`、`final boss arena`）。

2. **收集上下文**：
   - 读取游戏概念文档 `design/gdd/game-concept.md`
   - 读取游戏支柱文档 `design/gdd/game-pillars.md`
   - 读取 `design/levels/` 中已有的关卡文档
   - 读取 `design/narrative/` 中相关的叙事文档
   - 读取该区域所属地区/派系的世界观构建文档

## 如何委派

使用 Task 工具将每位团队成员生成为子代理：
- `subagent_type: narrative-director` —— 叙事目的、角色、情感弧线
- `subagent_type: world-builder` —— 背景设定上下文、环境叙事、世界规则
- `subagent_type: level-designer` —— 空间布局、节奏、遭遇战、导航
- `subagent_type: systems-designer` —— 敌人编成、掉落表、难度平衡
- `subagent_type: art-director` —— 视觉主题、配色方案、光照、资产需求
- `subagent_type: accessibility-specialist` —— 导航清晰度、色盲安全、认知负荷
- `subagent_type: qa-tester` —— 测试用例、边界测试、试玩测试清单

每个代理的提示词中务必提供完整上下文（游戏概念、支柱、现有关卡文档、叙事文档）。

3. **按顺序编排关卡设计团队**：

### 步骤 1：叙事 + 视觉方向（narrative-director + world-builder + art-director，并行）

同时生成全部三个代理 —— 在等待任何结果之前先发出全部三个 Task 调用。

生成 `narrative-director` 代理以：
- 定义该区域的叙事目的（这里发生哪些故事节拍？）
- 识别关键角色、对话触发点和背景设定元素
- 明确情感弧线（玩家进入时、过程中、离开时应分别有怎样的感受？）

生成 `world-builder` 代理以：
- 提供该区域的背景设定上下文（历史、派系存在、生态）
- 定义环境叙事机会
- 明确任何影响该区域玩法的世界规则

生成 `art-director` 代理以：
- 确立该区域的视觉主题目标 —— 这些是布局的输入，而非布局的输出
- 定义该区域的色温和光照氛围（与相邻区域有何不同？）
- 明确形状语言方向（棱角分明的堡垒？有机的洞穴？衰败的宏伟？）
- 命名将为玩家提供方向感的主要视觉地标
- 如果存在 `design/art/art-bible.md`，则读取它 —— 所有方向都要锚定在已确立的美术圣经上

**步骤 1 中 art-director 的视觉目标必须作为明确约束传递给步骤 2 的 level-designer**。布局决策发生在视觉方向之内，而非之前。

**关卡**：使用 `AskUserQuestion` 展示步骤 1 的全部三个输出（叙事简报、背景设定基础、视觉方向目标），确认后再进入步骤 2。

### 步骤 2：布局与遭遇战设计（level-designer）
生成 `level-designer` 代理，以步骤 1 的完整输出作为上下文：
- 叙事简报（来自 narrative-director）
- 背景设定基础（来自 world-builder）
- **视觉方向目标（来自 art-director）** —— 布局必须在这些目标内工作，不得与之矛盾

level-designer 应当：
- 设计空间布局（关键路径、可选路径、隐藏区域）—— 确保主要路线与步骤 1 的视觉地标目标一致
- 定义节奏曲线（紧张峰值、休息区域、探索区域）—— 与 narrative-director 的情感弧线协调
- 布置具有难度递进的遭遇战
- 设计环境谜题或导航挑战
- 定义用于寻路的兴趣点和地标 —— 这些必须与 art-director 指定的视觉地标匹配
- 明确入口/出口点以及与相邻区域的连接

**相邻区域依赖检查**：布局产出后，针对 level-designer 引用的每个相邻区域检查 `design/levels/`。如果任何被引用区域的 `.md` 文件不存在，将该缺口暴露出来：
> "关卡引用了 [area-name] 作为相邻区域，但 `design/levels/[area-name].md` 不存在。"

使用 `AskUserQuestion` 提供选项：
- (a) 以占位引用继续 —— 在关卡文档中将该连接标记为 UNRESOLVED，并在总结报告的跨关卡待解决依赖部分列出
- (b) 暂停并先运行 `/team-level [area-name]` 来确立该区域

不要为缺失的相邻区域虚构内容。

**关卡**：使用 `AskUserQuestion` 展示步骤 2 的布局（包括任何未解决的相邻区域依赖），确认后再进入步骤 3。

### 步骤 3：系统集成（systems-designer）
生成 `systems-designer` 代理以：
- 明确敌人编成和遭遇战公式
- 定义掉落表和奖励摆放
- 根据预期玩家等级/装备平衡难度
- 设计任何区域特有的机制或环境危害
- 明确资源分布（生命恢复道具、存档点、商店）

**关卡**：使用 `AskUserQuestion` 展示步骤 3 的输出，确认后再进入步骤 4。

### 步骤 4：制作概念 + 无障碍（art-director + accessibility-specialist，并行）

**注意**：art-director 的方向性工作（视觉主题、色彩目标、氛围）已在步骤 1 完成。这一轮是针对具体位置的制作概念 —— 给定最终布局，每个具体空间应该是什么样子？

生成 `art-director` 代理，使用步骤 2 的最终布局：
- 为关键空间（入口、关键遭遇战区域、地标、出口）产出针对具体位置的概念规格
- 明确哪些美术资产是该区域独有的、哪些来自全局共享池
- 定义每个关键空间的视线和光照设置（这些现在是基于布局的，而非方向性的）
- 明确该区域布局特有的 VFX 需求（天气体积、粒子、大气效果）
- 标记布局与步骤 1 目标产生视觉方向冲突的任何位置 —— 将这些作为制作风险暴露出来

并行生成 `accessibility-specialist` 代理以：
- 评审关卡布局的导航清晰度（玩家能否在不依赖颜色的情况下辨别方向？）
- 检查关键路径的路标除颜色外是否使用形状/图标/声音提示
- 评审任何谜题机制的认知负荷 —— 标记任何需要同时保持 3 个以上状态的设计
- 检查关键玩法区域对色盲玩家是否有足够的对比度
- 输出：按严重程度分类的无障碍问题清单（BLOCKING / RECOMMENDED / NICE TO HAVE）

等待两个代理都返回后再继续。

**关卡**：使用 `AskUserQuestion` 展示步骤 4 的两项结果。如果 accessibility-specialist 返回了任何 BLOCKING 级别的问题，将其突出显示并提供：
- (a) 返回 level-designer 和 art-director，在步骤 5 之前重新设计被标记的元素
- (b) 将其记录为已知的无障碍缺口，在最终报告中明确记录该问题后继续步骤 5

在用户确认任何 BLOCKING 级别的无障碍问题之前，不要进入步骤 5。

### 步骤 5：QA 规划（qa-tester）
生成 `qa-tester` 代理以：
- 为关键路径编写测试用例
- 识别边界和边缘情况（顺序破坏、软锁）
- 为该区域创建试玩测试清单
- 定义关卡完成的验收标准

4. **汇编关卡设计文档**，将所有团队输出合并为关卡设计模板格式。

收集完所有子代理输出后，通过 Task 生成 `level-designer` 来汇编并撰写最终文档：
- 传入：所有子代理输出（原文）、关卡简报、游戏支柱、相关 GDD 章节
- 要求 level-designer：汇编成关卡设计文档格式，然后在写入前请求用户批准（"我可以将汇编好的关卡设计写入 design/levels/[level-name].md 吗？"）
- 编排者不直接调用 Write 来写入最终文档。

5. **保存到** `design/levels/[level-name].md`（由 level-designer 子代理在用户批准后处理 —— 见上文）。

6. **输出总结**，包含：区域概览、遭遇战数量、预估资产清单、叙事节拍、任何跨团队依赖或待解决问题、待解决的跨关卡依赖（被引用但尚未设计的相邻区域，每个标记为 UNRESOLVED），以及无障碍问题及其解决状态。

## 文件写入协议

所有文件写入（关卡设计文档、叙事文档、测试清单）都委派给通过 Task 生成的子代理。每个子代理执行"我可以写入 [path] 吗？"协议。本编排者不直接写入文件。

判定：**COMPLETE** —— 关卡设计文档已产出，所有团队输出已汇编。
判定：**BLOCKED** —— 一个或多个代理受阻；产出包含未解决项清单的部分报告。

## 后续步骤

- 运行 `/design-review design/levels/[level-name].md` 验证已完成的关卡设计文档。
- 设计批准后运行 `/dev-story` 实现关卡内容。
- 运行 `/qa-plan` 为该关卡生成 QA 测试计划。

## 错误恢复协议

如果任何生成的代理（通过 Task）返回 BLOCKED、出错或无法完成：

1. **立即暴露**：在继续依赖阶段之前向用户报告 "[AgentName]: BLOCKED —— [原因]"
2. **评估依赖**：检查后续阶段是否需要受阻代理的输出。如果需要，在没有用户输入的情况下不要越过该依赖点。
3. **通过 AskUserQuestion 提供选项**：
   - 跳过此代理并在最终报告中记录该缺口
   - 缩小范围后重试
   - 就此停止，先解决阻塞问题
4. **始终产出部分报告** —— 输出已完成的内容。永远不要因一个代理受阻而丢弃工作成果。

常见阻塞原因：
- 输入文件缺失（找不到 story、GDD 不存在）→ 重定向到创建它的 skill
- ADR 状态为 Proposed → 不要实现；先运行 `/architecture-decision`
- 范围过大 → 通过 `/create-stories` 拆分为两个 story
- ADR 与 story 之间存在指令冲突 → 暴露冲突，不要猜测
