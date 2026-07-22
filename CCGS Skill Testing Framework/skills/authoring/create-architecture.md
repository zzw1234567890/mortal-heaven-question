
# 技能测试规格：/create-architecture

## 技能概述

`/create-architecture` 引导用户逐节编写技术架构文档 (Technical Architecture Document)。它采用"骨架优先"方法 —— 在填充任何内容之前，先创建包含所有必需章节标题的文件。每个章节都在用户批准后逐一讨论、起草和写入。如果架构文档已存在，该技能提供改造模式 (Retrofit Mode) 以更新特定章节。

在 `full` 审查模式下，TD-ARCHITECTURE（技术总监 (Technical Director)）和 LP-FEASIBILITY（主程 (Lead Programmer)）在完整草稿完成后启动。在 `lean` 或 `solo` 模式下，两个关卡均被跳过。该技能写入 `docs/architecture/architecture.md`。

---

## 静态断言（结构）

由 `/skill-test static` 自动验证 —— 无需测试夹具。

- [ ] 包含必需的前置元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判定关键词：APPROVED、NEEDS REVISION、MAJOR REVISION NEEDED
- [ ] 包含"我可以写入吗"（May I write）协作协议措辞（逐节批准）
- [ ] 末尾包含下一步交接说明（`/architecture-review` 或 `/create-control-manifest`）
- [ ] 记录骨架优先方法
- [ ] 记录关卡行为：full 模式下为 TD-ARCHITECTURE + LP-FEASIBILITY；lean/solo 模式下跳过
- [ ] 记录针对现有架构文档的改造模式

---

## 总监关卡检查

在 `full` 模式下：TD-ARCHITECTURE（技术总监 (Technical Director)）和 LP-FEASIBILITY（主程 (Lead Programmer)）在所有章节起草完成后、任何最终批准写入之前并行启动。

在 `lean` 模式下：两个关卡均被跳过。输出注明："TD-ARCHITECTURE skipped — lean mode"和"LP-FEASIBILITY skipped — lean mode"。

在 `solo` 模式下：两个关卡均被跳过，附带相应的说明。

---

## 测试用例

### 用例 1：正常路径 —— 新架构文档，骨架优先，full 模式关卡批准

**测试夹具：**
- 不存在现有的 `docs/architecture/architecture.md`
- `docs/architecture/` 包含已接受的 ADR 供参考
- `production/session-state/review-mode.txt` 包含 `full`

**输入：** `/create-architecture`

**预期行为：**
1. 技能创建骨架文件 `docs/architecture/architecture.md`，包含所有必需章节标题
2. 针对每个章节：起草内容、展示草稿、询问"我可以写入 [章节] 吗？"、批准后写入
3. 所有章节起草完成后：TD-ARCHITECTURE 和 LP-FEASIBILITY 并行启动
4. 两个关卡均返回 APPROVED
5. 询问最终的"我可以确认架构已完成吗？"
6. 更新会话状态

**断言：**
- [ ] 在任何内容写入之前，先创建包含所有章节标题的骨架文件
- [ ] 编写过程中逐节询问"我可以写入 [章节] 吗？"
- [ ] TD-ARCHITECTURE 和 LP-FEASIBILITY 并行启动（非顺序）
- [ ] 在最终完成确认之前，两个关卡均完成
- [ ] 当两个关卡均返回 APPROVED 时，判定结果为 APPROVED
- [ ] 包含指向 `/architecture-review` 或 `/create-control-manifest` 的下一步交接

---

### 用例 2：失败路径 —— TD-ARCHITECTURE 返回 MAJOR REVISION

**测试夹具：**
- 架构文档已完全起草（所有章节）
- `production/session-state/review-mode.txt` 包含 `full`
- TD-ARCHITECTURE 关卡返回 MAJOR REVISION："[具体的结构问题]"

**输入：** `/create-architecture`

**预期行为：**
1. 所有章节已起草并写入
2. TD-ARCHITECTURE 关卡运行并返回 MAJOR REVISION，附带具体反馈
3. 技能向用户展示反馈
4. 架构未被标记为最终定稿
5. 询问用户：修订被标记的章节，或接受文档为草稿

**断言：**
- [ ] 当 TD-ARCHITECTURE 返回 MAJOR REVISION 时，架构未被标记为最终定稿
- [ ] 关卡反馈展示给用户，附带具体问题描述
- [ ] 用户可以选择修订特定章节
- [ ] 尽管收到 MAJOR REVISION 反馈，技能不会自动定稿

---

### 用例 3：Lean 模式 —— 两个关卡均跳过；仅凭用户批准写入架构

**测试夹具：**
- 不存在现有的架构文档
- `production/session-state/review-mode.txt` 包含 `lean`

**输入：** `/create-architecture`

**预期行为：**
1. 创建骨架文件
2. 所有章节在用户批准下逐一编写并写入
3. 完成后：TD-ARCHITECTURE 和 LP-FEASIBILITY 被跳过
4. 输出注明："TD-ARCHITECTURE skipped — lean mode"和"LP-FEASIBILITY skipped — lean mode"
5. 架构仅凭用户批准即视为完成

**断言：**
- [ ] 输出中出现两个关卡跳过说明
- [ ] 在 lean 模式下，仅凭用户批准写入架构文档
- [ ] 技能不会因关卡被跳过而阻止完成
- [ ] 下一步交接仍然存在

---

### 用例 4：改造模式 —— 现有架构文档，用户更新章节

**测试夹具：**
- `docs/architecture/architecture.md` 已存在，所有章节均已填充

**输入：** `/create-architecture`

**预期行为：**
1. 技能检测到现有架构文档并读取其当前内容
2. 技能提供改造模式："架构文档已存在。您想更新哪个章节？"
3. 用户选择一个章节
4. 技能仅编写该章节，询问"我可以写入 [章节] 吗？"
5. 仅更新选定的章节 —— 其他章节不变

**断言：**
- [ ] 在提供改造模式之前，技能检测并读取现有架构文档
- [ ] 询问用户要更新哪个章节 —— 而非要求重写整个文档
- [ ] 仅更新选定的章节
- [ ] 在改造过程中，其他章节不被修改

---

### 用例 5：总监关卡 —— 架构引用了 Proposed 状态的 ADR；标记为风险

**测试夹具：**
- 正在编写架构文档
- 一个章节引用或依赖于一个 `Status: Proposed` 的 ADR
- `production/session-state/review-mode.txt` 包含 `full`

**输入：** `/create-architecture`

**预期行为：**
1. 技能编写所有章节
2. 在编写过程中，技能检测到对 Proposed 状态 ADR 的引用
3. 技能标记："注意：[章节] 引用了 ADR-NNN，其状态为 Proposed —— 在 ADR 被接受之前存在风险"
4. 风险标记嵌入到相关章节的内容中
5. TD-ARCHITECTURE 和 LP-FEASIBILITY 仍然运行 —— 它们会获知 Proposed 状态 ADR 的风险

**断言：**
- [ ] 在章节编写过程中检测并标记 Proposed 状态 ADR 引用
- [ ] 风险说明嵌入到架构文档章节中
- [ ] TD-ARCHITECTURE 和 LP-FEASIBILITY 仍然启动（风险不会阻塞关卡）
- [ ] 风险标记指明具体的 ADR 编号和标题

---

## 协议合规性

- [ ] 在任何内容写入之前，先创建包含所有章节标题的骨架文件
- [ ] 编写过程中逐节询问"我可以写入 [章节] 吗？"
- [ ] 在 full 模式下 TD-ARCHITECTURE 和 LP-FEASIBILITY 并行启动
- [ ] 在 lean/solo 输出中按名称和模式注明跳过的关卡
- [ ] 将 Proposed 状态 ADR 引用在文档中标记为风险
- [ ] 以下一步交接结束：`/architecture-review` 或 `/create-control-manifest`

---

## 覆盖说明

- 架构文档的必需章节列表在技能主体和 `/architecture-review` 技能中定义 —— 此处不再重新列举。
- 架构文档中的引擎版本标记（与 ADR 标记并行）是编写工作流的一部分 —— 通过用例 1 隐式测试。
- 在单次会话中更新多个章节的改造模式遵循相同的逐节批准模式 —— 未对多章节改造进行独立测试。
