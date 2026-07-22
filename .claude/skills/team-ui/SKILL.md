---
name: team-ui
description: "编排 UI 团队完成完整的 UX 管线：从 UX 规范创作到视觉设计、实现、审查和打磨。与 /ux-design、/ux-review 和工作室 UX 模板集成。"
argument-hint: "[UI feature description] [--review full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash, Task, AskUserQuestion, TodoWrite

---


当本 skill 被调用时，通过结构化管线编排 UI 团队。

**决策节点：** 在每个阶段过渡时，使用 `AskUserQuestion` 向用户展示子代理的提案作为可选选项。在对话中完整记录代理的分析，然后以简洁的标签记录决策。用户必须批准后才能进入下一阶段。

## 阶段 0：解析审查模式

1. 如果 `--review [mode]` 作为参数传入，使用该模式。
2. 否则读取 `production/review-mode.txt` — 使用其中写入的内容。
3. 否则默认为 `lean`。

模式：
- `full` — 按描述生成所有总监和主管关卡
- `lean` — 跳过总监关卡，除非是阶段关卡类型（CD-PHASE-GATE、TD-PHASE-GATE、PR-PHASE-GATE、AD-PHASE-GATE）
- `solo` — 完全跳过所有总监关卡生成；在没有任何代理关卡的情况下运行 skill

将解析后的模式存储起来，用于所有后续阶段。

**总监关卡跳过规则**：在生成 creative-director、art-director 或任何其他 Tier 1/2 总监进行审查之前（阶段关卡触发器除外），应用已解析的模式：如果为 solo 模式则跳过；如果为 lean 模式且不是阶段关卡则跳过。

## 团队组成
- **ux-designer（UX 设计师）** — 用户流程、线框图、无障碍、输入处理
- **ui-programmer（UI 程序员）** — UI 框架、屏幕、小部件、数据绑定、实现
- **art-director（艺术总监）** — 视觉风格、布局打磨、与艺术圣经的一致性
- **engine UI specialist（引擎 UI 专家）** — 根据引擎特定最佳实践验证 UI 实现模式（从 `.claude/docs/technical-preferences.md` 的 Engine Specialists → UI Specialist 读取）
- **accessibility-specialist（无障碍专家）** — 在阶段 4 审计无障碍合规性

**本管线使用的模板：**
- `ux-spec.md` — 标准屏幕/流程 UX 规范
- `hud-design.md` — HUD 特定 UX 规范
- `interaction-pattern-library.md` — 可复用的交互模式
- `accessibility-requirements.md` — 承诺的无障碍层级和要求

## 如何委派

使用 Task 工具将每个团队成员生成为子代理：
- `subagent_type: ux-designer` — 用户流程、线框图、无障碍、输入处理
- `subagent_type: ui-programmer` — UI 框架、屏幕、小部件、数据绑定
- `subagent_type: art-director` — 视觉风格、布局打磨、与艺术圣经的一致性
- `subagent_type: [UI 引擎专家]` — 特定引擎的 UI 模式验证（例如 unity-ui-specialist、ue-umg-specialist、godot-specialist）
- `subagent_type: accessibility-specialist` — 无障碍合规审计

始终为每个代理提供完整的上下文（功能需求、现有 UI 模式、目标平台）。在管线允许的情况下并行启动独立代理（例如阶段 4 的审查代理可以同时运行）。

## 管线

### 阶段 1a：上下文收集

在设计任何内容之前，读取并整合：
- `design/gdd/game-concept.md` — 目标平台和预期受众
- `design/player-journey.md` — 玩家到达此屏幕时的状态和上下文
- 与此功能相关的所有 GDD UI 需求部分
- `design/ux/interaction-patterns.md` — 要复用的现有模式（不重新发明）
- `design/accessibility-requirements.md` — 承诺的无障碍层级（例如 Basic、Enhanced、Full）

**如果 `design/ux/interaction-patterns.md` 不存在**，立即上报缺口：
> "interaction-patterns.md 不存在——没有可复用的现有模式。"

然后使用 `AskUserQuestion` 提供选项：
- (a) 先运行 `/ux-design patterns` 建立模式库，然后继续
- (b) 在没有模式库的情况下继续——ui-programmer 将把所有创建的交互模式视为新的，并在完成时添加到新的 `design/ux/interaction-patterns.md` 中

不要仅从功能名称或 GDD 凭空发明或假设模式。如果用户选择 (b)，在阶段 3 中明确指示 ui-programmer 将所有模式视为新的，并在实现完成后将它们记录到 `design/ux/interaction-patterns.md` 中。在最终总结报告中记录模式库状态（已创建 / 不存在 / 已更新）。

为 ux-designer 总结上下文的简报：玩家在做什么、他们需要什么、适用什么约束、以及哪些现有模式是相关的。

### 阶段 1b：UX 规范创作

调用 `/ux-design [功能名称]` skill 或直接委派给 ux-designer，按照 `ux-spec.md` 模板生成 `design/ux/[功能名称].md`。

如果设计 HUD，使用 `hud-design.md` 模板而不是 `ux-spec.md`。

> **关于特殊情况的说明：**
> - 针对 HUD 设计，调用 `/ux-design` 并传入 `argument: hud`（例如 `/ux-design hud`）。
> - 对于交互模式库，在项目开始时运行 `/ux-design patterns` 一次，并在后续阶段引入新模式时更新。

输出：`design/ux/[功能名称].md`，包含所有已填写的必需规范部分。

### 阶段 1c：UX 审查

规范完成后，调用 `/ux-review design/ux/[功能名称].md`。

**关卡**：在裁决为 APPROVED 之前，不要进入阶段 2。如果裁决为 NEEDS REVISION，ux-designer 必须处理标记的问题并重新运行审查。用户可以明确接受 NEEDS REVISION 的风险并继续，但这必须是一个有意识的决定——在询问是否继续之前，通过 `AskUserQuestion` 呈现具体关注点。

### 阶段 2：视觉设计

委派给 **art-director**：
- 审查完整的 UX 规范（流程、线框图、交互模式、无障碍说明）——不仅仅是线框图图像
- 应用艺术圣经中的视觉处理：颜色、排版、间距、动画风格
- 检查视觉设计是否保留了无障碍合规性：验证色彩对比度比率，并确认颜色永远不是状态的唯一指示符（形状、文本或图标必须强化它）
- 指定艺术管线所需的所有素材需求：指定尺寸的图标、背景纹理、字体、装饰元素——带有精确尺寸和格式要求
- 确保与现有已实现 UI 屏幕的一致性
- 输出：带有风格说明和素材清单的视觉设计规范

### 阶段 3：实现

在实现开始之前，生成 **engine UI specialist（引擎 UI 专家）**（来自 `.claude/docs/technical-preferences.md` 的 Engine Specialists → UI Specialist）以审查 UX 规范和视觉设计规范，获得引擎特定的实现指导：
- 此屏幕应使用哪个引擎 UI 框架？（例如 Unity 中的 UI Toolkit vs UGUI，Godot 中的 Control 节点 vs CanvasLayer，Unreal 中的 UMG vs CommonUI）
- 对于提议的布局或交互模式，是否有任何引擎特定的注意事项？
- 推荐的引擎小部件/节点结构？
- 输出：在 ui-programmer 开始之前交与其的引擎 UI 实现说明

如果未配置引擎，跳过此步骤。

委派给 **ui-programmer**：
- 按照 UX 规范和视觉设计规范实现 UI
- **使用 `design/ux/interaction-patterns.md` 中的模式**——不要重新发明已指定的模式。如果某个模式几乎适用但需要修改，记录偏差并标记以供 ux-designer 审查。
- **UI 从不拥有或修改游戏状态**——仅显示；为所有玩家操作发出事件
- 所有文本通过本地化系统——没有硬编码的面向玩家字符串
- 支持两种输入方式（键盘/鼠标和游戏手柄）
- 按照 `design/accessibility-requirements.md` 中承诺的层级实现无障碍功能
- 将数据绑定连接到游戏状态
- **如果在实现期间创建了任何新的交互模式**（即模式库中尚未存在的），在标记实现完成之前将其添加到 `design/ux/interaction-patterns.md`
- 输出：已实现的 UI 功能

### 阶段 4：审查（并行）

并行委派：
- **ux-designer**：验证实现是否与线框图和交互规范匹配。测试仅键盘和仅游戏手柄导航。检查无障碍功能是否正常工作。
- **art-director**：验证与艺术圣经的视觉一致性。检查最小和最大支持分辨率。
- **accessibility-specialist**：对照 `design/accessibility-requirements.md` 中记录的无障碍层级验证合规性。将任何违规标记为阻塞因素。

所有三个审查流程必须在进入阶段 5 前报告。

### 阶段 5：打磨

- 处理所有审查反馈
- 验证动画可跳过且尊重玩家的动作减少偏好
- 确认 UI 音效通过音频事件系统触发（没有直接音频调用）
- 在所有支持的分辨率和宽高比下测试
- **验证 `design/ux/interaction-patterns.md` 是最新的**——如果在此功能实现期间引入了任何新模式，确认它们已添加到库中
- **确认所有 HUD 元素遵循 `design/ux/hud.md` 中定义的视觉预算**（元素数量、屏幕区域分配、最大不透明度值）

## 快速参考——何时使用何种 Skill

- `/ux-design` — 从头创作屏幕、流程或 HUD 的新 UX 规范
- `/ux-review` — 在实现前验证已完成的 UX 规范
- `/team-ui [功能]` — 从概念到打磨的完整管线（内部调用 `/ux-design` 和 `/ux-review`）
- `/quick-design` — 不需要完整新 UX 规范的小型 UI 更改

## 错误恢复协议

如果任何生成的代理（通过 Task）返回 BLOCKED、出错或无法完成：

1. **立即上报**：在继续依赖阶段之前向用户报告"[代理名称]：BLOCKED — [原因]"
2. **评估依赖关系**：检查被阻塞代理的输出是否为后续阶段所需。如果是，在没有用户输入的情况下不要越过该依赖点继续。
3. **通过 AskUserQuestion 提供选项**，包含以下选择：
   - 跳过此代理并在最终报告中记录缺口
   - 以更窄的范围重试
   - 在此停止，先解决阻塞因素
4. **始终生成部分报告** — 输出已完成的内容。绝不要因为一个代理阻塞而丢弃已完成的工作。

常见阻塞因素：
- 输入文件缺失（story 未找到，GDD 不存在）→ 重定向到创建该文件的 skill
- ADR 状态为 Proposed → 不实施；先运行 `/architecture-decision`
- 范围过大 → 通过 `/create-stories` 拆分为两个 story
- ADR 与 story 之间的指令冲突 → 上报冲突，不要猜测

## 文件写入协议

所有文件写入（UX 规范、交互模式库更新、实现文件）都委派给子代理和子 skill（`/ux-design`、`ui-programmer`）。每个子代理执行"May I write to [path]?"协议。此编排器不直接写入文件。

## 输出

一份总结报告，涵盖：UX 规范状态、UX 审查裁决、视觉设计状态、实现状态、无障碍合规性、输入法支持、交互模式库更新状态以及任何未解决的问题。

裁决：**COMPLETE** — UI 功能已通过完整管线交付（UX 规范 → 视觉→ 实现 → 审查 → 打磨）。
裁决：**BLOCKED** — 管线已停止；在停止前上报阻塞因素及其所属阶段。

## 后续步骤

- 如果尚未批准，在最终规范上运行 `/ux-review`。
- 在关闭 story 前对 UI 实现运行 `/code-review`。
- 如果需要进行视觉或音频打磨，运行 `/team-polish`。
