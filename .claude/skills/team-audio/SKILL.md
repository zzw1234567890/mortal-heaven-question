---
name: team-audio
description: "编排音频团队：audio-director + sound-designer + technical-artist + gameplay-programmer，覆盖从音频方向到实现的完整音频管线。"
argument-hint: "[feature or area to design audio for] [--review full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash, Task, AskUserQuestion, TodoWrite

---


如果未提供参数，输出使用指引并退出，不派生任何 agent：
> 用法：`/team-audio [feature or area]` — 指定要设计音频的功能或区域（例如 `combat`、`main menu`、`forest biome`、`boss encounter`）。此处不要使用 `AskUserQuestion`，直接输出指引。

当以参数调用此技能时，通过结构化管线编排音频团队。

**决策点：** 在每个步骤过渡时，使用 `AskUserQuestion` 将子 agent 的
提案作为可选项呈现给用户。先在对话中写出 agent 的完整分析，然后用
简洁的标签捕获决策。用户批准后才能进入下一步。

## 阶段 0：解析评审模式

1. 如果参数中传入了 `--review [mode]`，使用该模式。
2. 否则读取 `production/review-mode.txt` — 使用其中所写内容。
3. 否则默认为 `lean`。

模式：
- `full` — 按描述派生所有 director 和 lead 关卡
- `lean` — 跳过 director 关卡，除非是 PHASE-GATE 类型（CD-PHASE-GATE、TD-PHASE-GATE、PR-PHASE-GATE、AD-PHASE-GATE）
- `solo` — 完全跳过所有 director 关卡的派生；运行技能时不带任何 agent 关卡

保存解析出的模式，供所有后续阶段使用。

1. **读取参数** 中的目标功能或区域（例如 `combat`、
   `main menu`、`forest biome`、`boss encounter`）。

2. **收集上下文**：
   - 读取 `design/gdd/` 中与该功能相关的设计文档
   - 读取 `design/gdd/sound-bible.md`（如果存在）
   - 读取 `assets/audio/` 中现有的音频资产清单
   - 读取该区域已有的声音设计文档

## 如何委派

使用 Task 工具将每位团队成员派生为子 agent：
- `subagent_type: audio-director` — 声音标识、情感基调、音频调色板
- `subagent_type: sound-designer` — 音效规格、音频事件、混音组
- `subagent_type: technical-artist` — 音频中间件、总线结构、内存预算
- `subagent_type: [primary engine specialist]` — 验证引擎的音频集成模式
- `subagent_type: gameplay-programmer` — 音频管理器、玩法触发器、自适应音乐

每个 agent 的提示中都要提供完整上下文（功能描述、现有音频资产、设计文档引用）。

3. **按顺序编排音频团队**：

### 步骤 1：音频方向（audio-director）
派生 `audio-director` agent 以：
- 定义该功能/区域的声音标识
- 明确情感基调和音频调色板
- 设定音乐方向（自适应分层、stem、过渡）
- 定义音频优先级和混音目标
- 建立自适应音频规则（战斗强度、探索、紧张感）

### 步骤 2：声音设计与音频无障碍（并行）
派生 `sound-designer` agent 以：
- 为每个音频事件创建详细的音效规格
- 定义声音类别（环境音、UI、玩法、音乐、对白）
- 指定每个声音的参数（音量范围、音高变化、衰减）
- 规划音频事件清单及触发条件
- 定义混音组和闪避（ducking）规则

并行派生 `accessibility-specialist` agent 以：
- 识别哪些音频事件承载关键玩法信息（受到伤害、敌人接近、目标完成），并需要为听力障碍玩家提供视觉替代
- 指定字幕需求：哪些音频事件需要字幕、文本格式、屏幕停留时长
- 检查没有玩法状态仅通过音频传达（全部必须有视觉兜底）
- 审查音频事件清单中可能给听觉敏感玩家带来问题的项（高频警报、突发巨响）
- 输出：音频无障碍需求清单，整合进音频事件规格

### 步骤 3：技术实现（并行）
派生 `technical-artist` agent 以：
- 设计音频中间件集成（Wwise/FMOD/原生）
- 定义音频总线结构和路由
- 指定各平台音频资产的内存预算
- 规划流式加载 vs 预加载的资产策略
- 设计音频驱动的视觉特效

并行派生 **primary engine specialist**（来自 `.claude/docs/technical-preferences.md` 的 Engine Specialists）以验证集成方案：
- 所提议的音频中间件集成是否符合该引擎的惯用法？（例如 Godot 内置 AudioStreamPlayer vs FMOD、Unity Audio Mixer vs Wwise、Unreal MetaSounds vs FMOD）
- 是否有应使用的引擎特有音频节点/组件模式？
- 锁定引擎版本中有哪些已知的音频系统变更会影响集成计划？
- 输出：引擎音频集成说明，与 technical-artist 的方案合并

如果未配置引擎，跳过该 specialist 的派生。

### 步骤 4：代码集成（gameplay-programmer）
派生 `gameplay-programmer` agent 以：
- 实现音频管理器系统或评审现有系统
- 将音频事件接入玩法触发器
- 实现自适应音乐系统（如有指定）
- 设置音频遮挡/混响区域
- 为音频事件触发器编写单元测试

4. **汇编音频设计文档**，合并所有团队输出。

5. **保存至** `design/audio/audio-[feature].md`。

   注意：如果 `design/audio/` 不存在，写入文档的子 agent 应创建它（写入文件时会自动创建目录）。

6. **输出摘要**，包含：音频事件数量、预估资产数量、
   实现任务，以及团队成员之间的待决问题。

判定：**COMPLETE** — 音频设计文档已产出，团队管线已完成。

如果管线因依赖未解决而停止（例如关键无障碍缺口或缺失的 GDD 未由用户解决）：

判定：**BLOCKED** — [原因]

## 文件写入协议

所有文件写入（音频设计文档、音效规格、实现文件）均委派给
通过 Task 派生的子 agent。每个子 agent 执行 "May I write to [path]?"
协议。本编排器不直接写文件。

## 后续步骤

- 实现开始前，与 audio-director 一起评审音频设计文档。
- 设计获批后，使用 `/dev-story` 实现音频管理器和事件系统。
- 音频资产创建后，运行 `/asset-audit` 验证命名和格式合规。

## 错误恢复协议

如果任何派生的 agent（通过 Task）返回 BLOCKED、出错或无法完成：

1. **立即上报**：在继续后续依赖阶段之前，向用户报告 "[AgentName]: BLOCKED — [原因]"
2. **评估依赖**：检查被阻塞 agent 的输出是否为后续阶段所需。如果是，在没有用户输入的情况下不要越过该依赖点。
3. **提供选项**，通过 AskUserQuestion 给出选择：
   - 跳过该 agent，并在最终报告中注明缺口
   - 缩小范围重试
   - 在此停止，先解决阻塞
4. **始终产出部分报告** — 输出已完成的内容。绝不因为某个 agent 阻塞就丢弃已完成的工作。

常见阻塞：
- 输入文件缺失（story 未找到、GDD 缺失）→ 重定向到创建它的技能
- ADR 状态为 Proposed → 不要实现；先运行 `/architecture-decision`
- 范围过大 → 通过 `/create-stories` 拆分为两个 story
- ADR 与 story 之间的指令冲突 → 暴露冲突，不要猜测
