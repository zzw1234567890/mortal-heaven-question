# Skill 测试规格：/team-combat


## Skill 概述

为单个战斗功能编排完整的战斗团队流水线，端到端完成。协调 game-designer、gameplay-programmer、ai-programmer、technical-artist、sound-designer、主引擎专家以及 qa-tester，完成六个结构化阶段：设计 → 架构（含引擎专家验证） → 实现（并行） → 集成 → 验证 → 签核。在每个阶段转换处使用 `AskUserQuestion`。将所有文件写入委托给子代理。产出摘要报告，结论为 COMPLETE / NEEDS WORK / BLOCKED，并交接给 `/code-review`、`/balance-check` 和 `/team-polish`。

---

## 静态断言（结构性）

- [ ] 具有必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题（Phase 1 到 Phase 6 全部存在）
- [ ] 包含结论关键词：COMPLETE、NEEDS WORK、BLOCKED
- [ ] 包含 "May I write" 或 "File Write Protocol" —— 写入委托给子代理，编排者不直接写文件
- [ ] 末尾有下一步交接（引用 `/code-review`、`/balance-check`、`/team-polish`）
- [ ] 存在 Error Recovery Protocol 章节，且包含全部四个恢复步骤
- [ ] 在阶段转换处使用 `AskUserQuestion`，在继续前征得用户批准
- [ ] Phase 3 明确标记为并行（gameplay-programmer、ai-programmer、technical-artist、sound-designer）
- [ ] Phase 2 包含生成主引擎专家（从 `.claude/docs/technical-preferences.md` 读取）
- [ ] 团队组成列出全部七个角色（game-designer、gameplay-programmer、ai-programmer、technical-artist、sound-designer、引擎专家、qa-tester）

---

## 测试用例

### 用例 1：顺利路径 —— 所有代理成功，完整流水线运行至完成

**前置条件（Fixture）：**
- `design/gdd/game-concept.md` 存在且已填充内容
- 引擎已在 `.claude/docs/technical-preferences.md` 中配置（Engine Specialists 部分已填写）
- 请求的战斗功能尚无现有 GDD

**输入：** `/team-combat parry and riposte system`

**预期行为：**
1. Phase 1 —— 生成 game-designer；产出 `design/gdd/parry-riposte.md`，覆盖全部 8 个必需章节（概述、玩家幻想、规则、公式、边缘情况、依赖关系、调优旋钮、验收标准）；要求用户批准设计文档
2. Phase 2 —— 生成 gameplay-programmer + ai-programmer；产出架构草图，包含类结构、接口和文件列表；然后生成主引擎专家以验证惯用用法；整合引擎专家的输出；在 Phase 3 开始前使用 `AskUserQuestion` 展示架构选项
3. Phase 3 —— 并行生成 gameplay-programmer、ai-programmer、technical-artist、sound-designer；全部四个返回输出后才进入 Phase 4
4. Phase 4 —— 将 Phase 3 的所有输出集成在一起；验证调优旋钮是数据驱动的；`AskUserQuestion` 在 Phase 5 前确认集成
5. Phase 5 —— 生成 qa-tester；根据验收标准编写测试用例；验证边缘情况；根据预算检查性能影响
6. Phase 6 —— 产出摘要报告：设计 COMPLETE，所有团队成员 COMPLETE，列出测试用例，结论：COMPLETE
7. 列出后续步骤：`/code-review`、`/balance-check`、`/team-polish`

**断言：**
- [ ] 在每个阶段关口调用 `AskUserQuestion`（至少 Phase 3 之前和 Phase 5 之前）
- [ ] Phase 3 代理同时启动 —— gameplay-programmer、ai-programmer、technical-artist、sound-designer 之间无顺序依赖
- [ ] 引擎专家在 Phase 2 中运行，在 Phase 3 开始之前（输出整合到架构中）
- [ ] 所有文件写入委托给子代理（编排者从不直接调用 Write/Edit）
- [ ] 最终报告中包含 COMPLETE 结论
- [ ] 后续步骤包括 `/code-review`、`/balance-check`、`/team-polish`
- [ ] 设计文档覆盖全部 8 个必需的 GDD 章节

---

### 用例 2：代理受阻 —— 某个子代理在流水线中途返回 BLOCKED

**前置条件（Fixture）：**
- `design/gdd/parry-riposte.md` 存在（Phase 1 已完成）
- ai-programmer 代理返回 BLOCKED，因为不存在 AI 系统架构 ADR（ADR 状态为 Proposed）

**输入：** `/team-combat parry and riposte system`

**预期行为：**
1. Phase 1 —— 设计文档已找到；game-designer 确认其有效；阶段已批准
2. Phase 2 —— gameplay-programmer 完成架构草图；ai-programmer 返回 BLOCKED："AI behavior system 的 ADR 为 Proposed — 在 ADR 被 Accepted 之前无法实现"
3. 触发 Error Recovery Protocol："ai-programmer: BLOCKED — AI behavior ADR is Proposed"
4. 提供 `AskUserQuestion` 选项：(a) 跳过 ai-programmer 并记录缺口；(b) 缩小范围重试；(c) 在此停止，先运行 `/architecture-decision`
5. 如果用户选择 (a)：Phase 3 仅继续 gameplay-programmer、technical-artist、sound-designer；ai-programmer 缺口记录在部分报告中
6. 产出最终报告：记录部分实现，ai-programmer 部分标记为 BLOCKED，总体结论：BLOCKED

**断言：**
- [ ] BLOCKED 表面消息在任何依赖阶段继续之前出现
- [ ] `AskUserQuestion` 至少提供三个选项：跳过 / 重试 / 停止
- [ ] 产出部分报告 —— 已完成代理的工作不被丢弃
- [ ] 任何代理未解决时，总体结论为 BLOCKED（而非 COMPLETE）
- [ ] 受阻原因引用 ADR 并建议使用 `/architecture-decision`
- [ ] 编排者不会静默越过受阻的依赖继续执行

---

### 用例 3：无参数 —— 显示清晰的用法指引

**前置条件（Fixture）：**
- 任意项目状态

**输入：** `/team-combat`（无参数）

**预期行为：**
1. Skill 检测到未提供参数
2. 输出用法消息，说明必需参数（战斗功能描述）
3. 提供调用示例：`/team-combat [combat feature description]`
4. Skill 退出，不生成任何子代理

**断言：**
- [ ] 未提供参数时，Skill 不生成任何子代理
- [ ] 用法消息包含 frontmatter 中的 argument-hint 格式
- [ ] 错误消息至少包含一个有效调用示例
- [ ] 不进行超出检测缺失参数所需的文件读取
- [ ] 不显示结论（流水线从未运行）

---

### 用例 4：并行阶段验证 —— Phase 3 代理同时运行

**前置条件（Fixture）：**
- `design/gdd/parry-riposte.md` 存在且完整
- 架构草图已被批准
- 引擎专家已验证架构

**输入：** `/team-combat parry and riposte system`（从 Phase 2 完成后恢复）

**预期行为：**
1. 架构批准后 Phase 3 开始
2. 所有四个 Task 调用 —— gameplay-programmer、ai-programmer、technical-artist、sound-designer —— 在等待任何结果之前发出
3. Skill 等待所有四个代理完成后才进入 Phase 4
4. 如果某个代理提前完成，Skill 不会在全部四个代理返回之前开始 Phase 4

**断言：**
- [ ] 四个 Task 调用在单个批次中发出（它们之间无顺序等待）
- [ ] 直到所有四个 Phase 3 代理返回结果后，Phase 4 才开始
- [ ] Skill 不会将一个 Phase 3 代理的输出作为输入传递给另一个 Phase 3 代理（它们是独立的）
- [ ] 所有四个 Phase 3 代理的结果在 Phase 4 集成步骤中被引用

---

### 用例 5：架构阶段的引擎路由 —— 引擎专家收到正确的上下文

**前置条件（Fixture）：**
- `.claude/docs/technical-preferences.md` 的 Engine Specialists 部分已填充（例如，Primary: godot-specialist）
- gameplay-programmer 产出的架构草图可用
- 引擎版本固定在 `docs/engine-reference/godot/VERSION.md`

**输入：** `/team-combat parry and riposte system`

**预期行为：**
1. Phase 2 —— gameplay-programmer 产出架构草图
2. Skill 读取 `.claude/docs/technical-preferences.md` 的 Engine Specialists 部分，以识别主引擎专家代理类型
3. 生成引擎专家，附带：架构草图、GDD 路径、`VERSION.md` 中的引擎版本，以及检查已弃用 API 的明确指示
4. 引擎专家输出（惯用用法说明、已弃用 API 警告、原生系统建议）返回给编排者
5. 编排者在向用户展示 Phase 2 结果之前将引擎说明整合到架构中
6. `AskUserQuestion` 将引擎专家的说明与架构草图一同展示

**断言：**
- [ ] 引擎专家代理类型从 `.claude/docs/technical-preferences.md` 读取 —— 非硬编码
- [ ] 引擎专家提示包含架构草图和 GDD 路径
- [ ] 引擎专家根据固定的引擎版本检查已弃用 API
- [ ] 引擎专家输出在 Phase 3 开始之前被整合（非跳过或单独附加）
- [ ] 如果未配置引擎，引擎专家步骤被跳过，并在报告中添加说明

---

## 协议合规性

- [ ] 每个阶段转换处使用 `AskUserQuestion` —— 用户批准后流水线才前进
- [ ] 所有文件写入通过 Task 委托给子代理 —— 编排者不直接调用 Write 或 Edit
- [ ] 遵循 Error Recovery Protocol：浮现 → 评估 → 提供选项 → 部分报告
- [ ] Phase 3 代理按照 skill 规格并行启动
- [ ] 即使代理 BLOCKED，也始终产出部分报告
- [ ] 结论为 COMPLETE / NEEDS WORK / BLOCKED 之一
- [ ] 末尾给出后续步骤：`/code-review`、`/balance-check`、`/team-polish`

---

## 覆盖说明

- NEEDS WORK 结论路径（qa-tester 在 Phase 5 发现失败）未在此处单独测试；它遵循与用例 2 相同的错误恢复和部分报告协议。
- "缩小范围重试"错误恢复选项在断言中列出，但其完整递归行为（通过 `/create-stories` 拆分）由 `/create-stories` 规格覆盖。
- Phase 4 集成逻辑（连接 gameplay、AI、VFX、音频）由顺利路径案例隐式验证；专用的集成测试需要前置条件代码文件。
- 引擎专家不可用（未配置引擎）在用例 5 中断言中部分覆盖 —— 为未配置引擎状态设置专用前置条件将加强覆盖。
