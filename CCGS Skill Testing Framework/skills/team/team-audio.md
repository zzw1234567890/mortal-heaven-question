# Skill 测试规格：/team-audio


## Skill 概述

编排音频团队，完成四个步骤的流水线：音频方向（audio-director）→ 音效设计 + 无障碍审查并行（sound-designer + accessibility-specialist）→ 技术实现 + 引擎验证并行（technical-artist + 主引擎专家）→ 代码集成（gameplay-programmer）。在启动代理前，读取相关的 GDD、音效圣经（如存在）以及现有音频资产列表。将所有产出汇编为一份音频设计文档，保存到 `design/gdd/audio-[feature].md`。在每个步骤转换处使用 `AskUserQuestion`。当音频设计文档生成后，结论为 COMPLETE。当未配置引擎时，优雅地跳过引擎专家的生成。

---

## 静态断言（结构性）

- [ ] 具有必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个步骤/阶段标题
- [ ] 包含结论关键词：COMPLETE、BLOCKED
- [ ] 包含 "File Write Protocol" 章节
- [ ] 文件写入委托给子代理 —— 编排者不直接写文件
- [ ] 子代理在任何写入前执行 "May I write to [path]?" 协议
- [ ] 末尾有下一步交接（引用 `/dev-story`、`/asset-audit`）
- [ ] 存在 Error Recovery Protocol 章节
- [ ] 在步骤转换处使用 `AskUserQuestion`，在继续前征得用户批准
- [ ] Step 2 明确生成 sound-designer 和 accessibility-specialist（并行）
- [ ] Step 3 明确生成 technical-artist 和引擎专家（并行，当引擎已配置时）
- [ ] 在上下文收集期间，如果存在则读取 `design/gdd/sound-bible.md`
- [ ] 输出文档保存到 `design/gdd/audio-[feature].md`

---

## 测试用例

### 用例 1：顺利路径 —— 所有步骤完成，音频设计文档保存

**前置条件（Fixture）：**
- 目标功能的 GDD 存在于 `design/gdd/combat.md`
- 音效圣经存在于 `design/gdd/sound-bible.md`
- 现有音频资产列于 `assets/audio/`
- 引擎已在 `.claude/docs/technical-preferences.md` 中配置
- 在规划的音频事件列表中不存在无障碍缺口

**输入：** `/team-audio combat`

**预期行为：**
1. 上下文收集：编排者在启动任何代理前读取 `design/gdd/combat.md`、`design/gdd/sound-bible.md` 和 `assets/audio/` 资产列表
2. Step 1：生成 audio-director；定义战斗的音频身份、情感基调、自适应音乐方向、混音目标和自适应音频规则
3. `AskUserQuestion` 展示音频方向；用户在 Step 2 开始前批准
4. Step 2：并行生成 sound-designer 和 accessibility-specialist；sound-designer 产出 SFX 规格说明、含触发条件的音频事件列表以及混音组；accessibility-specialist 识别关键游戏音频事件并指定视觉回退和字幕需求
5. `AskUserQuestion` 展示 SFX 规格和无障碍需求；用户在 Step 3 开始前批准
6. Step 3：并行生成 technical-artist 和主引擎专家；technical-artist 设计总线结构、中间件集成、内存预算和流式传输策略；引擎专家验证集成方式对所配置的引擎是否惯用
7. `AskUserQuestion` 展示技术方案；用户在 Step 4 开始前批准
8. Step 4：生成 gameplay-programmer；将音频事件连接到游戏触发器、实现自适应音乐、设置遮挡区域、为音频事件触发器编写单元测试
9. 编排者将所有产出汇编为一份音频设计文档
10. 子代理在写入前询问 "May I write the audio design document to `design/gdd/audio-combat.md`?"
11. 摘要输出列出：音频事件数量、预估资产数量、实现任务以及任何未决问题
12. 结论：COMPLETE

**断言：**
- [ ] 在上下文收集期间（Step 1 之前），当音效圣经存在时被读取
- [ ] audio-director 在 sound-designer 或 accessibility-specialist 之前生成
- [ ] `AskUserQuestion` 在 Step 1 输出之后、Step 2 启动之前出现
- [ ] sound-designer 和 accessibility-specialist 的 Task 调用在 Step 2 中同时发出
- [ ] technical-artist 和引擎专家的 Task 调用在 Step 3 中同时发出
- [ ] gameplay-programmer 直到 Step 3 的 `AskUserQuestion` 被批准后才启动
- [ ] 音频设计文档写入到 `design/gdd/audio-combat.md`（而非其他路径）
- [ ] 摘要包含音频事件数量和预估资产数量
- [ ] 编排者不直接写入任何文件
- [ ] 文档交付后结论为 COMPLETE

---

### 用例 2：无障碍缺口 —— 关键游戏音频事件没有视觉回退

**前置条件（Fixture）：**
- 目标功能的 GDD 存在
- Step 1 和 Step 2 正在进行中
- sound-designer 的音频事件列表包含 "EnemyNearbyAlert" —— 一种空间音频提示，用于警告玩家有敌人从屏幕外接近
- accessibility-specialist 审查事件列表并发现 "EnemyNearbyAlert" 没有视觉回退（无屏幕指示器、无字幕、未指定控制器震动）

**输入：** `/team-audio stealth`（Step 2 场景）

**预期行为：**
1. Step 1–2 继续进行；并行生成 accessibility-specialist 和 sound-designer
2. accessibility-specialist 返回审查结果，提出 BLOCKING 关注点："`EnemyNearbyAlert` 是一个关键游戏音频事件（警告玩家有屏幕外威胁），但没有视觉回退 —— 听力障碍玩家无法检测到此威胁。这是一项 BLOCKING 无障碍缺口。"
3. 编排者在展示 `AskUserQuestion` 之前立即在对话中呈现该关注点
4. `AskUserQuestion` 将该无障碍关注点作为 BLOCKING 问题展示，并提供选项：
   - 为 EnemyNearbyAlert 添加视觉指示器（如 HUD 上的方向箭头）并继续
   - 添加控制器触觉反馈作为回退并继续
   - 此处停止，在进入 Step 3 前解决所有无障碍缺口
5. Step 3（technical-artist + 引擎专家）在用户解决或明确接受该缺口之前不会启动
6. 如果未解决，该无障碍缺口包含在最终音频设计文档的 "Open Accessibility Issues" 部分

**断言：**
- [ ] 无障碍缺口在报告中被标记为 BLOCKING（而非建议性意见）
- [ ] 指明了具体事件名称（"EnemyNearbyAlert"）和缺口性质
- [ ] `AskUserQuestion` 在 Step 3 启动前呈现该缺口
- [ ] 至少提供一个解决方案选项（添加视觉回退、添加触觉回退）
- [ ] 在缺口未解决且未经用户明确授权的情况下，Step 3 不会启动
- [ ] 如果缺口未解决而被延续，则在音频设计文档中记录为未决问题

---

### 用例 3：无参数 —— 显示用法指引或设计文档推断

**前置条件（Fixture）：**
- 任意项目状态

**输入：** `/team-audio`（无参数）

**预期行为：**
1. Skill 检测到未提供参数
2. 输出用法指引：例如 "Usage: `/team-audio [feature or area]` — specify the feature or area to design audio for (e.g., `combat`, `main menu`, `forest biome`, `boss encounter`)"
3. Skill 退出，不生成任何代理

**断言：**
- [ ] 未提供参数时，Skill 不生成任何代理
- [ ] 用法消息包含正确的调用格式及参数示例
- [ ] Skill 不会在没有用户指示的情况下尝试从现有设计文档推断功能
- [ ] 不使用 `AskUserQuestion` —— 输出为直接指引

---

### 用例 4：缺失音效圣经 —— Skill 记录缺口并在没有它的情况下继续

**前置条件（Fixture）：**
- 目标功能的 GDD 存在于 `design/gdd/main-menu.md`
- `design/gdd/sound-bible.md` 不存在
- 引擎已配置；其他上下文文件存在

**输入：** `/team-audio main menu`

**预期行为：**
1. 上下文收集：编排者读取 `design/gdd/main-menu.md` 并检查 `design/gdd/sound-bible.md`
2. 音效圣经未找到；编排者在对话中记录缺口："Note: `design/gdd/sound-bible.md` not found — audio direction will proceed without a project-wide sonic identity reference. Consider creating a sound bible if this is an ongoing project."
3. 流水线在无音效圣经作为输入的情况下正常进行所有四个步骤
4. Step 1 中的 audio-director 被告知没有音效圣经存在，必须仅从功能 GDD 建立音频身份
5. 缺失的音效圣经在最终摘要中被提及为建议的下一步

**断言：**
- [ ] 编排者在上下文收集期间（Step 1 之前）检查音效圣经是否存在
- [ ] 缺失的音效圣经在对话中被明确记录 —— 而非静默忽略
- [ ] 流水线不会因缺失音效圣经而停止
- [ ] audio-director 在其提示上下文中被告知没有音效圣经存在
- [ ] 摘要或下一步骤部分建议创建音效圣经
- [ ] 如果其他所有步骤成功，结论仍为 COMPLETE

---

### 用例 5：引擎未配置 —— 引擎专家步骤优雅跳过

**前置条件（Fixture）：**
- 引擎未在 `.claude/docs/technical-preferences.md` 中配置（显示 `[TO BE CONFIGURED]`）
- 目标功能的 GDD 存在
- 音效圣经可能存在也可能不存在

**输入：** `/team-audio boss encounter`

**预期行为：**
1. 上下文收集：编排者读取 `.claude/docs/technical-preferences.md` 并检测到未配置引擎
2. Step 1–2 正常进行（audio-director、sound-designer、accessibility-specialist）
3. Step 3：正常生成 technical-artist；引擎专家的生成被 SKIPPED
4. 编排者在对话中记录："Engine specialist not spawned — no engine configured in technical-preferences.md. Engine integration validation will be deferred until an engine is selected."
5. Step 4：gameplay-programmer 继续，并附注无法验证特定于引擎的音频集成模式
6. 引擎专家缺口包含在音频设计文档的 "Deferred Validation" 部分
7. 结论：COMPLETE（跳过程序是优雅的，不是阻塞项）

**断言：**
- [ ] 未配置引擎时，引擎专家不会被生成
- [ ] Skill 不会因缺失引擎配置而报错
- [ ] 跳过程序在对话中被明确记录 —— 而非静默忽略
- [ ] technical-artist 仍在 Step 3 中生成（跳过仅适用于引擎专家）
- [ ] gameplay-programmer 在 Step 4 中继续，并附带延迟验证的记录
- [ ] 延迟的引擎验证记录在音频设计文档中
- [ ] 结论为 COMPLETE（引擎未配置是一个已知的优雅情况）

---

## 协议合规性

- [ ] 上下文收集（GDD、音效圣经、资产列表）在任何代理生成之前运行
- [ ] 每个步骤输出后、下一个步骤启动前使用 `AskUserQuestion`
- [ ] 并行生成：Step 2（sound-designer + accessibility-specialist）和 Step 3（technical-artist + 引擎专家）在等待结果前发出所有 Task 调用
- [ ] 编排者不直接写入任何文件 —— 所有写入委托给子代理
- [ ] 每个子代理在任何写入前执行 "May I write to [path]?" 协议
- [ ] 任何代理返回的 BLOCKED 状态立即浮现 —— 不会静默跳过
- [ ] 当部分代理完成而其他代理阻塞时，始终产出部分报告
- [ ] 音频设计文档路径遵循 `design/gdd/audio-[feature].md` 模式
- [ ] 结论严格为 COMPLETE 或 BLOCKED —— 不使用其他结论值
- [ ] 下一步交接引用 `/dev-story` 和 `/asset-audit`

---

## 覆盖说明

- Error Recovery Protocol 中的"缩小范围重试"和"跳过此代理"解决方案路径未单独测试 —— 它们遵循已在用例 2 和 5 中验证的相同的 `AskUserQuestion` + 部分报告模式。
- Step 4（gameplay-programmer）的顺利路径行为由用例 1 隐式验证。此步骤的失败模式遵循标准的 Error Recovery Protocol。
- accessibility-specialist 的字幕和说明文字需求（超出视觉回退）由用例 1 隐式验证。用例 2 聚焦于更严重的情况，即关键游戏事件完全没有回退。
- 引擎专家验证逻辑（惯用集成、版本特定变更）仅针对已配置和未配置状态进行测试。引擎专家输出的具体内容不在本行为规格的范围之内。
