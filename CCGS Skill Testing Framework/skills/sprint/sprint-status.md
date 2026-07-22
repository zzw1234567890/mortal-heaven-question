
# 技能测试规格：/sprint-status

## 技能概述 (Skill Summary)

`/sprint-status` 是一个 Haiku 层级 (Haiku-tier) 的只读技能，读取当前活跃的冲刺 (sprint) 文件和会话状态，生成简洁的冲刺健康摘要。它按状态（已完成 / 进行中 / 受阻 / 未开始）报告故事数量，并输出以下三种冲刺健康判决 (verdict) 之一：ON TRACK（正常）、AT RISK（有风险）或 BLOCKED（受阻）。它从不写入文件，也不调用任何主管门控 (director gate)。它专为在会话期间进行快速、低成本的状况检查而设计。

---

## 静态断言（结构）

由 `/skill-test static` 自动验证——无需测试夹具 (fixture)。

- [ ] 包含所需 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题或编号检查章节
- [ ] 包含判决关键词：ON TRACK、AT RISK、BLOCKED
- [ ] 不要求"我可以写入吗"这一类用语（只读技能）
- [ ] 具有下一步交接指引（根据判决该做什么）

---

## 主管门控检查 (Director Gate Checks)

无。`/sprint-status` 是一个只读报告技能；不调用任何门控。

---

## 测试用例 (Test Cases)

### 用例 1：快乐路径——混合冲刺，AT RISK 并附有命名的阻塞项

**测试夹具 (Fixture)：**
- `production/sprints/sprint-004.md` 存在（活跃冲刺，链接在 `active.md` 中）
- 冲刺包含 6 个故事：
  - 3 个状态为 `Status: Complete`
  - 2 个状态为 `Status: In Progress`
  - 1 个状态为 `Status: Blocked`（阻塞项："等待物理系统 ADR 批准"）
- 冲刺结束日期在 2 天后

**输入：** `/sprint-status`

**预期行为：**
1. 技能读取 `production/session-state/active.md` 以找到活跃冲刺引用
2. 技能读取 `production/sprints/sprint-004.md`
3. 技能按状态统计故事数量：3 个已完成，2 个进行中，1 个受阻
4. 技能检测到受阻的故事和即将到来的截止日期
5. 技能输出 AT RISK 判决，并明确指明阻塞项

**断言 (Assertions)：**
- [ ] 输出包含按状态分类的故事数量明细
- [ ] 输出指明具体的受阻故事及其阻塞原因
- [ ] 当有任何故事处于 Blocked 状态时，判决为 AT RISK（非 BLOCKED，非 ON TRACK）
- [ ] 技能不写入任何文件

---

### 用例 2：所有故事已完成——SPRINT COMPLETE 判决

**测试夹具 (Fixture)：**
- `production/sprints/sprint-004.md` 存在
- 全部 5 个故事的状态均为 `Status: Complete`

**输入：** `/sprint-status`

**预期行为：**
1. 技能读取冲刺文件——所有故事均为 Complete
2. 技能输出 ON TRACK 判决或 SPRINT COMPLETE 标签
3. 技能建议运行 `/milestone-review` 或 `/sprint-plan` 作为下一步

**断言：**
- [ ] 当所有故事均为 Complete 时，判决为 ON TRACK 或 SPRINT COMPLETE
- [ ] 输出注明冲刺已全部完成
- [ ] 下一步建议引用 `/milestone-review` 或 `/sprint-plan`
- [ ] 不写入任何文件

---

### 用例 3：无活跃冲刺文件——引导运行 /sprint-plan

**测试夹具 (Fixture)：**
- `production/session-state/active.md` 未引用活跃冲刺
- `production/sprints/` 目录为空或不存在

**输入：** `/sprint-status`

**预期行为：**
1. 技能读取 `active.md`——未找到活跃冲刺引用
2. 技能检查 `production/sprints/`——未找到文件
3. 技能输出信息性消息：未检测到活跃冲刺
4. 技能建议运行 `/sprint-plan` 创建一个

**断言：**
- [ ] 当没有冲刺文件时，技能不会报错或崩溃
- [ ] 输出明确说明未找到活跃冲刺
- [ ] 输出推荐 `/sprint-plan` 作为下一步操作
- [ ] 不发出任何判决关键词（没有冲刺可评估）

---

### 用例 4：边缘情况——过时的进行中故事（已标记）

**测试夹具 (Fixture)：**
- `production/sprints/sprint-004.md` 存在
- 一个故事的状态为 `Status: In Progress`，并在 `active.md` 中有一条记录：
  `Last updated: 2026-03-30`（早于今日会话日期超过 2 天）
- 没有故事处于 Blocked 状态

**输入：** `/sprint-status`

**预期行为：**
1. 技能读取冲刺文件和会话状态
2. 技能检测到该故事处于 In Progress 状态超过 2 天未更新
3. 技能在输出中将该故事标记为"过时"
4. 判决为 AT RISK（过时的进行中故事表明存在隐藏的阻塞项）

**断言：**
- [ ] 技能将故事的"最后更新"元数据与会话日期进行比较
- [ ] 过时的进行中故事在输出中按名称被标记
- [ ] 当检测到过时故事时，判决为 AT RISK，而非 ON TRACK
- [ ] 输出不会将"过时"与"受阻"混为一谈——标签是区分开的

---

### 用例 5：门控合规——只读；不调用门控

**测试夹具 (Fixture)：**
- `production/sprints/sprint-004.md` 存在，包含 4 个故事（2 个已完成，2 个进行中）
- `production/session-state/review-mode.txt` 包含 `full`

**输入：** `/sprint-status`

**预期行为：**
1. 技能读取冲刺并生成状态摘要
2. 无论审查模式如何，技能均不调用任何主管门控
3. 输出是一份简洁的状态报告，附带 ON TRACK、AT RISK 或 BLOCKED 判决
4. 技能不提示用户批准或请求写入任何文件

**断言：**
- [ ] 在任何审查模式下均不调用主管门控
- [ ] 输出不包含任何"我可以写入吗"提示
- [ ] 技能完成并返回判决，无需用户交互
- [ ] 审查模式文件被本技能忽略（或确认为无关）

---

## 协议合规性 (Protocol Compliance)

- [ ] 不使用 Write 或 Edit 工具（只读技能）
- [ ] 在发出判决前展示故事数量明细
- [ ] 不请求批准
- [ ] 末尾根据判决提供推荐的下一步操作
- [ ] 在 Haiku 模型层级上运行（快速、低成本）

---

## 覆盖范围说明 (Coverage Notes)

- 多个冲刺同时活跃的情况未进行测试；技能读取 `active.md` 引用的那个冲刺。
- 部分冲刺完成百分比未进行明确验证；按状态统计数量的输出隐含了这一点。
- `solo` 模式的审查模式变体未单独测试；用例 5 中的门控行为适用于所有模式。
