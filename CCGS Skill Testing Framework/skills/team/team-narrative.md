# 技能测试规格：/team-narrative


## 技能摘要 (Skill Summary)

编排叙事团队（narrative team）通过五阶段管线：叙事方向（narrative-director）→ 世界观基础 + 对话草稿（world-builder 和 writer 并行）→ 关卡叙事整合（level-designer）→ 一致性审查（narrative-director）→ 润色 + 本地化合规（writer、localization-lead 和 world-builder 并行）。在每个阶段转换时使用 `AskUserQuestion` 以提供可选方案。产出叙事摘要报告，并通过各自执行"May I write?"协议的子代理交付叙事文档。当所有阶段成功时判定为 COMPLETE，当依赖项未解决时判定为 BLOCKED。

---

## 静态断言（结构类）

- [ ] 具备必填的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 拥有 ≥2 个阶段标题
- [ ] 包含判定关键词：COMPLETE、BLOCKED
- [ ] 包含"文件写入协议"（File Write Protocol）章节
- [ ] 文件写入由子代理委托完成 — 编排器不直接写入文件
- [ ] 子代理在写入前执行"May I write to [path]?"协议
- [ ] 末尾有下一步移交指引（引用了 `/design-review`、`/localize extract`、`/dev-story`）
- [ ] 存在错误恢复协议（Error Recovery Protocol）章节
- [ ] `AskUserQuestion` 在阶段转换时用于继续前获取批准
- [ ] 阶段 2 明确并行生成 world-builder 和 writer
- [ ] 阶段 5 明确并行生成 writer、localization-lead 和 world-builder

---

## 测试用例

### 用例 1：正常路径 — 全部五阶段完成，叙事文档交付

**测试夹具 (Fixture)：**
- 目标特性的游戏概念和 GDD 存在（例如 `design/gdd/faction-intro.md`）
- 角色语音档案存在（例如 `design/narrative/characters/`）
- 现有的世界观条目可用于交叉引用（例如 `design/narrative/lore/`）
- 现有条目与新内容之间不存在世界观矛盾

**输入：** `/team-narrative faction introduction cutscene for the Ironveil faction`

**预期行为：**
1. 阶段 1：生成 narrative-director；输出叙事简报，定义故事节拍、涉及角色、情感基调及世界观依赖
2. `AskUserQuestion` 展示叙事简报；用户在阶段 2 开始前批准
3. 阶段 2：并行生成 world-builder 和 writer；world-builder 为 Ironveil 阵营产出世界观条目；writer 使用角色语音档案起草对话台词
4. `AskUserQuestion` 展示世界观基础和对话草稿；用户在阶段 3 开始前批准
5. 阶段 3：生成 level-designer；产出环境叙事布局、触发器放置和节奏规划
6. `AskUserQuestion` 展示关卡叙事方案；用户在阶段 4 开始前批准
7. 阶段 4：narrative-director 根据语音档案审查所有对话，验证世界观一致性，确认节奏；批准或标记问题
8. `AskUserQuestion` 展示审查结果；用户在阶段 5 开始前批准
9. 阶段 5：并行生成 writer、localization-lead 和 world-builder；writer 执行最终自查；localization-lead 验证 i18n 合规性；world-builder 最终确定正典层级
10. 展示最终摘要报告；子代理在写入前询问"May I write the narrative document to [path]?"
11. 判定：COMPLETE

**断言：**
- [ ] narrative-director 在阶段 1 优先于其他所有代理生成
- [ ] `AskUserQuestion` 出现在阶段 1 输出之后、阶段 2 启动之前
- [ ] world-builder 和 writer 的 Task 调用在阶段 2 同时发出（非顺序执行）
- [ ] level-designer 在阶段 2 的 `AskUserQuestion` 获批之后才启动
- [ ] narrative-director 在阶段 4 重新生成以执行一致性审查
- [ ] 阶段 5 同时生成三个代理（writer、localization-lead、world-builder）
- [ ] 摘要报告包含：叙事简报状态、创建/更新的世界观条目、已编写对话台词、关卡叙事整合点、一致性审查结果
- [ ] 编排器不直接写入任何文件
- [ ] 判定在交付后为 COMPLETE

---

### 用例 2：发现世界观矛盾 — world-builder 在 writer 继续前发现冲突

**测试夹具 (Fixture)：**
- 现有世界观条目 `design/narrative/lore/ironveil-history.md` 记载 Ironveil 阵营建立于 200 年前
- 新的叙事简报（来自阶段 1）称 Ironveil 建立于 50 年前
- writer 已在阶段 2 与 world-builder 并行生成

**输入：** `/team-narrative ironveil faction introduction cutscene`

**预期行为：**
1. 阶段 1–2 正常开始
2. 阶段 2 world-builder 检测到叙事简报与现有世界观之间存在事实矛盾：建国年份冲突
3. world-builder 返回 BLOCKED，附带原因："Lore contradiction found — founding date conflicts with `design/narrative/lore/ironveil-history.md`"
4. 编排器立即呈现矛盾："world-builder: BLOCKED — Lore contradiction: founding date in narrative brief (50 years ago) conflicts with existing canon (200 years ago in `ironveil-history.md`)"
5. 编排器评估依赖关系：writer 的对话依赖于正典世界观 — 不解决矛盾则 writer 的草稿无法定稿
6. `AskUserQuestion` 提供选项：
   - 修改叙事简报以匹配现有正典（200 年前）
   - 更新现有世界观条目以反映新正典（50 年前）
   - 在此处停止，先在世界观文档中解决矛盾
7. writer 输出被保留但标记为"待正典解决" — 已完成的工作不会被丢弃
8. 在矛盾解决或用户明确选择跳过之前，编排器不会进入阶段 3

**断言：**
- [ ] 矛盾在阶段 3 开始前被呈现
- [ ] 编排器不会通过自行选择一个版本来静默解决矛盾
- [ ] `AskUserQuestion` 提供至少 3 个选项，包括"先停止并解决"
- [ ] writer 的草稿输出在部分报告中保留，而非丢弃
- [ ] 阶段 3（level-designer）在用户解决矛盾之前不会启动
- [ ] 若用户选择停止以解决矛盾，判定为 BLOCKED（而非 COMPLETE）

---

### 用例 3：无参数 — 显示使用指引

**测试夹具 (Fixture)：**
- 任意项目状态

**输入：** `/team-narrative`（无参数）

**预期行为：**
1. 技能检测到未提供参数
2. 输出使用指引：例如 "Usage: `/team-narrative [narrative content description]` — describe the story content, scene, or narrative area to work on (e.g., `boss encounter cutscene`, `faction intro dialogue`, `tutorial narrative`)"
3. 技能退出，不生成任何代理

**断言：**
- [ ] 未提供参数时，技能不会生成任何代理
- [ ] 使用消息包含正确的调用格式及参数示例
- [ ] 技能不会尝试从项目文件中猜测或推断叙事主题
- [ ] 不使用 `AskUserQuestion` — 输出为直接指引

---

### 用例 4：本地化合规 — localization-lead 标记不可本地化的字符串

**测试夹具 (Fixture)：**
- 阶段 1–4 成功完成
- 阶段 5 开始；writer 和 world-builder 顺利完成
- localization-lead 发现一句对话台词使用了硬编码的格式化日期字符串（例如 `"On March 12th, Year 3"`），该格式无法在没有本地化感知格式化器的情况下适应特定语言环境的翻译

**输入：** `/team-narrative ironveil faction introduction cutscene`（阶段 5 场景）

**预期行为：**
1. 阶段 5 并行生成 writer、localization-lead 和 world-builder
2. localization-lead 完成审查并标记："String key `dialogue.ironveil.intro.003` contains a hardcoded date format (`March 12th, Year 3`) that will not localize correctly — requires a locale-aware date placeholder"
3. 编排器在摘要报告中呈现该本地化阻塞项
4. 该本地化问题在最终报告中标记为 BLOCKING（而非建议性质）
5. `AskUserQuestion` 提供选项：
   - 立即修复该字符串（writer 修改该句台词）
   - 记录该缺口并在标记问题后交付叙事文档
   - 停止并在定稿前解决
6. 若用户选择在标记问题后继续，判定为 COMPLETE 并附带已记录的本地化债务；若用户选择停止，判定为 BLOCKED

**断言：**
- [ ] localization-lead 在阶段 5 与 writer 和 world-builder 同时生成
- [ ] 硬编码的日期格式被识别为本地化阻塞项（而非静默放过）
- [ ] 问题报告中包含具体的字符串键和原因
- [ ] `AskUserQuestion` 提供"立即修复"与"标记后继续"的选项
- [ ] 若用户选择不修复继续，判定会注明本地化债务
- [ ] 未经用户批准，技能不会自动重写违规台词

---

### 用例 5：Writer 被阻塞 — 缺少角色语音档案

**测试夹具 (Fixture)：**
- 阶段 1 narrative-director 产出的叙事简报引用了两个角色：Commander Varek 和 Advisor Selene
- `design/narrative/characters/` 中不存在任一角色的语音档案
- 阶段 2 开始；world-builder 正常进行

**输入：** `/team-narrative ironveil surrender negotiation scene`

**预期行为：**
1. 阶段 1 完成；叙事简报列出 Commander Varek 和 Advisor Selene 作为角色
2. 阶段 2：writer 与 world-builder 并行生成
3. writer 返回 BLOCKED："Cannot produce dialogue — no voice profiles found for Commander Varek or Advisor Selene in `design/narrative/characters/`. Voice profiles required to match character tone and speech patterns."
4. 编排器立即呈现阻塞："writer: BLOCKED — Missing prerequisite: character voice profiles for Commander Varek and Advisor Selene"
5. world-builder 输出被保留；产出包含世界观条目的部分报告
6. `AskUserQuestion` 提供选项：
   - 先创建语音档案（重定向至 narrative-director 或设计工作流）
   - 内联提供简要语音指导，并以该上下文重试 writer
   - 在此处停止，在继续前创建语音档案
7. 编排器在无 writer 输出的情况下不会进入阶段 3（level-designer）

**断言：**
- [ ] writer 阻塞在阶段 3 开始前被呈现
- [ ] world-builder 已完成的世界观输出在部分报告中得到保留
- [ ] 缺失的依赖项（语音档案）被具体指明（角色名称和预期文件路径）
- [ ] `AskUserQuestion` 提供至少一种解决缺失依赖项的选项
- [ ] 编排器不会凭空编造语音档案或虚构角色声音
- [ ] 未经用户明确授权，在 writer 被 BLOCKED 时不会启动阶段 3

---

## 协议合规性

- [ ] 在每个阶段输出之后、下一阶段启动之前使用 `AskUserQuestion`
- [ ] 并行生成：阶段 2（world-builder + writer）和阶段 5（writer + localization-lead + world-builder）在等待结果前发出所有 Task 调用
- [ ] 编排器不直接写入任何文件 — 所有写入由子代理委托完成
- [ ] 每个子代理在写入前执行"May I write to [path]?"协议
- [ ] 任何代理的 BLOCKED 状态立即呈现 — 不会静默跳过
- [ ] 当部分代理完成而其他代理被阻塞时，始终产出部分报告
- [ ] 判定严格为 COMPLETE 或 BLOCKED — 不使用其他判定值
- [ ] 下一步移交指引引用了 `/design-review`、`/localize extract` 和 `/dev-story`

---

## 覆盖说明

- 阶段 3（level-designer）和阶段 4（narrative-director 审查）的正常路径行为由用例 1 隐式验证。这些阶段的单独边界用例无需定义，因其故障模式遵循标准错误恢复协议。
- "缩小范围重试"和"跳过此代理"的错误恢复协议解决路径未单独测试 — 它们遵循与用例 2 和 5 相同的 `AskUserQuestion` + 部分报告模式。
- 本地化问题中建议性质（例如德语/芬兰语 +30% 扩展警告）与阻塞性质（硬编码格式）的区分在用例 4 中体现；纯建议性场景遵循相同模式但不改变判定。
- writer 的"所有台词不超过 120 字符"和"使用字符串键而非原始字符串"检查在阶段 5 中由用例 4 的本地化合规场景隐式覆盖。
