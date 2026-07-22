
# Skill 测试规格：/team-ui

## Skill 概述

编排 UI 团队（UI team）完成单个 UI 功能的完整用户体验（UX）管线。协调
ux-designer、ui-programmer、art-director、引擎 UI 专家（engine UI specialist）
和 accessibility-specialist，经过五个结构化阶段：上下文收集 + UX 规格（第 1a/1b 阶段）
→ UX 审查关口（第 1c 阶段）→ 视觉设计（第 2 阶段）→ 实现（第 3 阶段）→
并行审查（第 4 阶段）→ 打磨（第 5 阶段）。在每个阶段转换处使用 `AskUserQuestion`。
将所有文件写入委托给子代理和子技能（`/ux-design`、`ui-programmer`）。产出摘要报告，
结论为 COMPLETE / BLOCKED，并交接给 `/ux-review`、`/code-review`、`/team-polish`。

---

## 静态断言（结构性）

- [ ] 具有必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题（第 1a 阶段到第 5 阶段全部存在）
- [ ] 包含结论关键词：COMPLETE、BLOCKED
- [ ] 包含 "May I write" 或 "File Write Protocol" —— 写入委托给子代理和子技能，编排器不直接写文件
- [ ] 末尾有下一步交接（引用 `/ux-review`、`/code-review`、`/team-polish`）
- [ ] 存在 Error Recovery Protocol 章节，且包含全部四个恢复步骤
- [ ] 在阶段转换处使用 `AskUserQuestion`，在继续前征得用户批准
- [ ] 第 4 阶段明确标记为并行（ux-designer、art-director、accessibility-specialist）
- [ ] UX 审查关口（第 1c 阶段）被定义为阻塞性关口 —— 技能在未获得 APPROVED 结论前不得进入第 2 阶段
- [ ] 团队组成列出全部五个角色（ux-designer、ui-programmer、art-director、引擎 UI 专家、accessibility-specialist）
- [ ] 引用交互模式库（`design/ux/interaction-patterns.md`）—— ui-programmer 必须使用现有模式
- [ ] 第 1a 阶段在设计开始前读取 `design/accessibility-requirements.md`

---

## 测试用例

### 用例 1：顺利路径 —— 从 UX 规格到打磨的完整流水线成功

**前置条件（Fixture）：**
- `design/gdd/game-concept.md` 存在，包含平台目标和目标受众
- `design/player-journey.md` 存在
- `design/ux/interaction-patterns.md` 存在，包含相关模式
- `design/accessibility-requirements.md` 存在，包含承诺的等级（例如 Enhanced）
- 引擎 UI 专家已在 `.claude/docs/technical-preferences.md` 中配置

**输入：** `/team-ui inventory screen`

**预期行为：**
1. 第 1a 阶段 —— 编排器读取 game-concept.md、player-journey.md、相关 GDD UI 章节、interaction-patterns.md、accessibility-requirements.md；为 ux-designer 汇总简报
2. 第 1b 阶段 —— 调用 `/ux-design inventory-screen`（或直接启动 ux-designer）；使用 `ux-spec.md` 模板生成 `design/ux/inventory-screen.md`；`AskUserQuestion` 在审查前确认规格
3. 第 1c 阶段 —— 调用 `/ux-review design/ux/inventory-screen.md`；返回 APPROVED；关口通过，进入第 2 阶段
4. 第 2 阶段 —— 启动 art-director；审查完整 UX 规格（不仅是线框图）；应用视觉处理；验证颜色对比度；生成包含资产清单的视觉设计规格；`AskUserQuestion` 在第 3 阶段前确认
5. 第 3 阶段 —— 首先启动引擎 UI 专家（从 technical-preferences.md 读取）；为 ui-programmer 生成实现说明；使用 UX 规格 + 视觉规格 + 引擎说明启动 ui-programmer；生成实现；如果引入新模式，更新 interaction-patterns.md
6. 第 4 阶段 —— ux-designer、art-director、accessibility-specialist 并行启动；全部三个在第 5 阶段前返回结果
7. 第 5 阶段 —— 处理审查反馈；验证动画可跳过；确认 UI 声音通过音频事件系统播放；最终检查 interaction-patterns.md；结论：COMPLETE
8. 摘要报告：UX 规格 APPROVED，视觉设计 COMPLETE，实现 COMPLETE，无障碍 COMPLIANT，所有输入方法受支持，模式库已更新，结论：COMPLETE

**断言：**
- [ ] 第 1a 阶段在向 ux-designer 提供简报前读取全部五个来源
- [ ] 在第 2 阶段前检查 UX 审查关口 —— 第 2 阶段在获得 APPROVED 前不会开始
- [ ] 第 2 阶段的 art-director 审查完整规格，而不仅是线框图图像
- [ ] 第 3 阶段中引擎 UI 专家在 ui-programmer 之前启动
- [ ] 第 4 阶段代理同时启动（ux-designer、art-director、accessibility-specialist）
- [ ] 所有文件写入委托给子代理和子技能
- [ ] 最终摘要报告中结论为 COMPLETE
- [ ] 后续步骤包括 `/ux-review`、`/code-review`、`/team-polish`

---

### 用例 2：UX 审查关口 —— 规格未通过审查；技能在实现前停止

**前置条件（Fixture）：**
- `design/ux/inventory-screen.md` 由第 1b 阶段生成
- `/ux-review` 返回结论 NEEDS REVISION，并标记了具体关注点（例如，游戏手柄导航流程不完整、对比度低于最低要求）

**输入：** `/team-ui inventory screen`

**预期行为：**
1. 第 1a + 1b 阶段完成 —— UX 规格已生成
2. 第 1c 阶段 —— `/ux-review design/ux/inventory-screen.md` 返回 NEEDS REVISION
3. Skill 不进入第 2 阶段
4. `AskUserQuestion` 展示具体的标记关注点及选项：
   - (a) 返回 ux-designer 处理问题并重新审查
   - (b) 接受风险并在第 2 阶段继续（有意识决策）
5. 如果用户选择 (a)：ux-designer 修订规格，重新运行 `/ux-review`；循环持续直到 APPROVED 或用户覆盖
6. 如果用户选择 (b)：技能继续，最终报告中附带显式的 NEEDS REVISION 说明
7. Skill 不会悄悄越过关口继续

**断言：**
- [ ] UX 审查结论为 NEEDS REVISION 时，第 2 阶段不会开始
- [ ] `AskUserQuestion` 在提供选项前展示具体的标记关注点
- [ ] 用户必须有意识地选择覆盖 —— skill 不会假定覆盖
- [ ] 如果用户接受风险，NEEDS REVISION 关注点记录在最终报告中
- [ ] 提供修订和重新审查循环（不仅是一次性失败）
- [ ] 审查失败时 Skill 不会丢弃已生成的 UX 规格

---

### 用例 3：无参数 —— 显示用法指引

**前置条件（Fixture）：**
- 任意项目状态

**输入：** `/team-ui`（无参数）

**预期行为：**
1. Skill 检测到未提供参数
2. 输出用法消息，说明必需参数（UI 功能描述）
3. 提供调用示例：`/team-ui [UI feature description]`
4. Skill 退出，不启动任何子代理，也不读取任何项目文件

**断言：**
- [ ] 未提供参数时，Skill 不启动任何子代理
- [ ] 用法消息包含 frontmatter 中的 argument-hint 格式
- [ ] 至少展示一个有效调用示例
- [ ] 在失败前不读取任何 UX 规格文件或 GDD
- [ ] 不显示结论（流水线从未启动）

---

### 用例 4：无障碍并行审查 —— 第 4 阶段同时运行三个流

**前置条件（Fixture）：**
- `design/ux/inventory-screen.md` 存在（已 APPROVED）
- 视觉设计规格完成
- 实现完成
- `design/accessibility-requirements.md` 承诺等级：Enhanced

**输入：** `/team-ui inventory screen`（从第 3 阶段完成恢复）

**预期行为：**
1. 确认实现完成后开始第 4 阶段
2. 同时发出三个 Task 调用：ux-designer、art-director、accessibility-specialist
3. 每个流独立运行：
   - ux-designer：验证实现与线框图匹配，测试纯键盘和纯手柄导航，检查无障碍功能正常工作
   - art-director：验证在最低和最高支持分辨率下与艺术圣经的视觉一致性
   - accessibility-specialist：根据 `design/accessibility-requirements.md` 中的 Enhanced 无障碍等级进行审计；任何违规标记为阻塞项
4. Skill 等待全部三个结果后再进入第 5 阶段
5. `AskUserQuestion` 在第 5 阶段开始前展示全部三个审查结果

**断言：**
- [ ] 全部三个 Task 调用在任何结果被等待之前发出（并行，非顺序）
- [ ] 第 5 阶段在全部三个第 4 阶段代理返回前不会开始
- [ ] Accessibility-specialist 明确读取 `design/accessibility-requirements.md` 了解承诺等级
- [ ] 无障碍违规标记为 BLOCKING（不仅是建议性意见）
- [ ] `AskUserQuestion` 在第 5 阶段批准前一起展示全部三个审查流的审查结果
- [ ] 没有第 4 阶段代理的输出被用作另一个第 4 阶段代理的输入

---

### 用例 5：缺少交互模式库 —— Skill 记录缺口而非编造模式

**前置条件（Fixture）：**
- `design/ux/interaction-patterns.md` 不存在
- 所有其他必需文件存在

**输入：** `/team-ui settings menu`

**预期行为：**
1. 第 1a 阶段 —— 编排器尝试读取 `design/ux/interaction-patterns.md`；文件未找到
2. Skill 浮现缺口："interaction-patterns.md 不存在 —— 无现有模式可复用"
3. `AskUserQuestion` 提供选项：
   - (a) 先运行 `/ux-design patterns` 建立模式库，然后继续
   - (b) 在无模式库的情况下继续 —— ux-designer 将在创建新模式时记录它们
4. Skill 不会从其他来源编造或假定模式
5. 如果用户选择 (b)：明确指示 ui-programmer 将所有创建的模式视为新模式，并在完成时将每个模式添加到新的 `design/ux/interaction-patterns.md`
6. 最终报告注明 interaction-patterns.md 已创建（或如果用户跳过则仍不存在）

**断言：**
- [ ] Skill 不会静默忽略缺失的模式库
- [ ] Skill 不会仅凭功能名称或 GDD 猜测模式
- [ ] `AskUserQuestion` 提供"先创建模式库"选项（引用 `/ux-design patterns`）
- [ ] 如果用户在无库的情况下继续，告知 ui-programmer 将所有模式视为新模式
- [ ] 最终报告记录模式库状态（已创建 / 不存在 / 已更新）
- [ ] Skill 不会完全失败 —— 记录缺口并给用户选择

---

## 协议合规性

- [ ] 在每个阶段转换处使用 `AskUserQuestion` —— 用户批准后流水线才前进
- [ ] UX 审查关口（第 1c 阶段）是阻塞性的 —— 没有 APPROVED 或用户明确覆盖，第 2 阶段不能开始
- [ ] 所有文件写入委托给子代理和子技能 —— 编排器不直接调用 Write 或 Edit
- [ ] 第 4 阶段代理按 skill 规格并行启动
- [ ] 遵循 Error Recovery Protocol：浮现 → 评估 → 提供选项 → 部分报告
- [ ] 即使代理 BLOCKED，也始终产出部分报告
- [ ] 结论为 COMPLETE / BLOCKED 之一
- [ ] 末尾给出后续步骤：`/ux-review`、`/code-review`、`/team-polish`

---

## 覆盖说明

- HUD 特定路径（`/ux-design hud` + `hud-design.md` 模板 + 第 5 阶段视觉预算检查）
  未在此处单独测试；它共享相同的阶段结构但使用不同的模板。
- interaction-patterns.md 的"原地更新"路径（实现期间添加新模式）在用例 1 第 5 步中
  隐式练习；一个带有已知新模式的专用前置条件将加强覆盖。
- 引擎 UI 专家不可用（未配置引擎）—— skill 规格说明"如果未配置引擎则跳过"；
  该路径在用例 1 中断言但未给专用前置条件。
- NEEDS REVISION 接受风险覆盖（用例 2 选项 b）要求覆盖在报告中明确记录；
  该行为已被断言但未进一步测试下游影响。
