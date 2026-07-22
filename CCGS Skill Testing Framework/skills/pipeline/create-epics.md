
# 技能测试规范：/create-epics

## 技能概述

`/create-epics` 读取所有已批准的 GDD（游戏设计文档）并将其转换为 EPIC.md 文件，每个系统一个。史诗按层级（Foundation → Core → Feature → Presentation）组织，并在每个层级内按优先级顺序处理。每个 EPIC.md 包含范围、管辖 ADR、GDD 需求、引擎风险等级和完成定义（Definition of Done）。该技能在创建每个 EPIC 文件前询问"May I write"。

在 `full` 评审模式下，PR-EPIC 关卡（制作人，producer）在起草史诗之后、写入任何文件之前运行。在 `lean` 或 `solo` 模式下，PR-EPIC 被跳过并注明。史诗写入 `production/epics/[layer]/EPIC-[name].md`。

---

## 静态断言（结构检查）

由 `/skill-test static` 自动验证 — 无需测试夹具。

- [ ] 具有必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题
- [ ] 包含判定关键词：CREATED、BLOCKED
- [ ] 包含 "May I write" 协作协议措辞（每个史诗的批准）
- [ ] 末尾具有下一步交接（`/create-stories`）
- [ ] 文档说明 PR-EPIC 关卡行为：full 模式下运行；lean/solo 模式下跳过

---

## 总监关卡检查

在 `full` 模式下：PR-EPIC（制作人）关卡在史诗起草之后、写入任何史诗文件之前运行。如果 PR-EPIC 返回 CONCERNS，则在"May I write"询问之前修订史诗。

在 `lean` 模式下：PR-EPIC 被跳过。输出注明："PR-EPIC skipped — lean mode"。

在 `solo` 模式下：PR-EPIC 被跳过。输出注明："PR-EPIC skipped — solo mode"。

---

## 测试用例

### 用例 1：正常路径 — 两个已批准的 GDD 创建两个 EPIC 文件

**测试夹具：**
- `design/gdd/systems-index.md` 存在，列出 2 个系统
- 两个系统在 `design/gdd/` 中均有已批准的 GDD
- `docs/architecture/architecture.md` 存在，具有匹配的模块
- 每个系统至少有一个 Accepted ADR
- `production/session-state/review-mode.txt` 包含 `lean`

**输入：** `/create-epics`

**预期行为：**
1. 技能读取系统索引和两个 GDD
2. 起草 2 个 EPIC 定义（层级、GDD 路径、ADR、需求、引擎风险）
3. PR-EPIC 关卡被跳过（lean 模式）— 在输出中注明
4. 对于每个史诗：询问"我可以写入 `production/epics/[layer]/EPIC-[name].md` 吗？"
5. 批准后：写入两个 EPIC 文件
6. 创建或更新 `production/epics/index.md`

**断言：**
- [ ] 在任何写入询问之前先展示史诗摘要
- [ ] "May I write" 按每个史诗分别询问（非一次性询问所有史诗）
- [ ] 每个 EPIC.md 包含：层级、GDD 路径、管辖 ADR、需求表格、完成定义
- [ ] 在输出中注明 PR-EPIC 已跳过
- [ ] 写入后更新 `production/epics/index.md`
- [ ] 未经每个史诗的单独批准，技能不会写入 EPIC 文件

---

### 用例 2：失败路径 — 未找到已批准的 GDD

**测试夹具：**
- `design/gdd/systems-index.md` 存在
- `design/gdd/` 中没有 GDD 具有已批准状态（均为草稿或进行中）

**输入：** `/create-epics`

**预期行为：**
1. 技能读取系统索引并尝试查找已批准的 GDD
2. 未找到已批准的 GDD
3. 技能输出："没有可转换的已批准 GDD。GDD 必须为已批准状态后才能创建史诗。"
4. 技能建议先运行 `/design-system` 并完成 GDD 批准
5. 技能退出，不创建任何 EPIC 文件

**断言：**
- [ ] 当没有已批准的 GDD 时，技能以清晰的消息干净地停止
- [ ] 未写入任何 EPIC 文件
- [ ] 技能推荐正确的下一步操作
- [ ] 判定为 BLOCKED

---

### 用例 3：总监关卡 — Full 模式在写入前派生 PR-EPIC

**测试夹具：**
- 2 个已批准的 GDD 存在
- `production/session-state/review-mode.txt` 包含 `full`

**Full 模式预期行为：**
1. 技能起草两个史诗
2. PR-EPIC 关卡派生并审查史诗草稿
3. 如果 PR-EPIC 返回 APPROVED："May I write" 询问正常进行
4. 获得批准后写入史诗文件

**断言（full 模式）：**
- [ ] PR-EPIC 关卡在输出中作为活动关卡出现
- [ ] PR-EPIC 在任何 "May I write" 询问之前运行
- [ ] 在 PR-EPIC 完成之前不会写入史诗文件

**测试夹具（lean 模式）：**
- 相同的 GDD
- `production/session-state/review-mode.txt` 包含 `lean`

**Lean 模式预期行为：**
1. 史诗被起草
2. PR-EPIC 被跳过 — 在输出中注明
3. "May I write" 询问直接进行

**断言（lean 模式）：**
- [ ] "PR-EPIC skipped — lean mode" 出现在输出中
- [ ] 技能继续进行 "May I write" 询问，无需等待 PR-EPIC

---

### 用例 4：边界情况 — 某个 GDD 的史诗已存在

**测试夹具：**
- 某个已批准 GDD 的 `production/epics/[layer]/EPIC-[name].md` 已存在
- 另一个 GDD 尚无现存的 EPIC 文件

**输入：** `/create-epics`

**预期行为：**
1. 技能检测到第一个系统的现有 EPIC 文件
2. 技能提供更新而非覆盖的选项："EPIC-[name].md 已存在。更新还是跳过？"
3. 对于第二个系统（无现有文件）：正常进行 "May I write"

**断言：**
- [ ] 技能在写入前检测到现有 EPIC 文件
- [ ] 用户获得"更新"或"跳过"选项 — 不会被自动覆盖
- [ ] 新系统的 EPIC 正常创建，无冲突

---

### 用例 5：总监关卡 — PR-EPIC 返回 CONCERNS

**测试夹具：**
- 2 个已批准的 GDD 存在
- `production/session-state/review-mode.txt` 包含 `full`
- PR-EPIC 关卡返回 CONCERNS（例如，某个史诗范围过大）

**输入：** `/create-epics`

**预期行为：**
1. PR-EPIC 关卡派生并返回带具体反馈的 CONCERNS
2. 技能在任何写入询问前向用户展示关注点
3. 用户获得选项：修订史诗、接受关注点并继续、或停止
4. 如果用户修订：在 "May I write" 询问前展示更新后的史诗草稿
5. 当 CONCERNS 未被处理时技能不会写入史诗

**断言：**
- [ ] PR-EPIC 的 CONCERNS 在写入前展示给用户
- [ ] 当返回 CONCERNS 时技能不会自动写入史诗
- [ ] 用户获得明确的修订、继续或停止选择
- [ ] 在最终批准前，修订后的史诗草稿在修订后重新展示

---

## 协议合规性

- [ ] 在任何 "May I write" 询问前向用户展示史诗草稿
- [ ] "May I write" 按每个史诗分别询问，非一次性询问整个批次
- [ ] PR-EPIC 关卡（如果激活）在写入询问之前运行 — 而非之后
- [ ] 跳过的关卡按名称和模式在输出中注明
- [ ] EPIC.md 内容仅来源于 GDD、ADR 和架构文档 — 不凭空发明
- [ ] 以下一步交接结尾：每个创建的史诗对应 `/create-stories [epic-slug]`

---

## 覆盖说明

- Core、Feature 和 Presentation 层级的处理遵循与 Foundation 相同的按史诗模式 — 层级特定的排序未独立测试。
- 来自管辖 ADR 的引擎风险等级分配（LOW/MEDIUM/HIGH）通过用例 1 的夹具结构隐式验证。
- `layer: [name]` 和 `[system-name]` 参数模式遵循与默认（所有系统）模式相同的批准模式。
