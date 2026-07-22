
# 技能测试规范：/create-stories

## 技能概述

`/create-stories` 将单个史诗（epic）分解为开发者就绪的 story 文件。它读取 EPIC.md、对应的 GDD、管辖 ADR、控制清单（control manifest）和 TR 注册表。每个 story 具有结构化的 frontmatter，包括：标题（Title）、史诗（Epic）、层级（Layer）、优先级（Priority）、状态（Status）、TR-ID、ADR 引用、验收标准和完成定义。Story 按类型分类（Logic / Integration / Visual/Feel / UI / Config/Data），类型决定了所需的测试证据路径。

在 `full` 评审模式下，每个 story 创建后会运行 QL-STORY-READY 检查。在 `lean` 或 `solo` 模式下，QL-STORY-READY 被跳过。该技能在写入每个 story 文件前询问"May I write"。Story 写入 `production/epics/[layer]/story-[name].md`。

---

## 静态断言（结构检查）

由 `/skill-test static` 自动验证 — 无需测试夹具。

- [ ] 具有必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题
- [ ] 包含判定关键词：COMPLETE、BLOCKED、NEEDS WORK
- [ ] 包含 "May I write" 协作协议措辞（每个 story 的批准）
- [ ] 末尾具有下一步交接（`/story-readiness`、`/dev-story`）
- [ ] 文档说明 Story 状态：当管辖 ADR 为 Proposed 时状态为 Blocked
- [ ] 文档说明 QL-STORY-READY 关卡：full 模式下激活，lean/solo 模式下跳过

---

## 总监关卡检查

在 `full` 模式下：每个 story 创建后运行 QL-STORY-READY 检查。未通过检查的 story 在"May I write"询问前被标记为 NEEDS WORK。

在 `lean` 模式下：QL-STORY-READY 被跳过。输出注明每个 story 的 "QL-STORY-READY skipped — lean mode"。

在 `solo` 模式下：QL-STORY-READY 被跳过，带有等效的说明。

---

## 测试用例

### 用例 1：正常路径 — 具有 3 个 story 的史诗，所有 ADR 均为 Accepted

**测试夹具：**
- `production/epics/[layer]/EPIC-[name].md` 存在，包含 3 个 GDD 需求
- 对应的 GDD 存在，具有匹配的验收标准
- 所有管辖 ADR 的状态为 `Status: Accepted`
- `docs/architecture/control-manifest.md` 存在
- `docs/architecture/tr-registry.yaml` 对所有 3 个需求具有 TR-ID
- `production/session-state/review-mode.txt` 包含 `lean`

**输入：** `/create-stories [epic-name]`

**预期行为：**
1. 技能读取 EPIC.md、GDD、管辖 ADR、控制清单和 TR 注册表
2. 将每个需求分类为一种 story 类型（Logic / Integration / Visual/Feel / UI / Config/Data）
3. 起草 3 个具有正确 frontmatter 模式的 story 文件
4. QL-STORY-READY 被跳过（lean 模式）— 在输出中注明
5. 在写入每个 story 文件前询问"May I write"
6. 获得批准后写入全部 3 个 story 文件

**断言：**
- [ ] 每个 story 的 frontmatter 包含：标题、史诗、层级、优先级、状态、TR-ID、ADR 引用、验收标准、DoD
- [ ] Story 类型被正确分类（夹具中至少有一个 Logic 类型）
- [ ] "May I write" 按每个 story 分别询问（非一次性询问整个批次）
- [ ] QL-STORY-READY 跳过在输出中注明
- [ ] 全部 3 个 story 文件以正确的命名写入：`story-[name].md`
- [ ] 技能不启动实现

---

### 用例 2：失败路径 — 未找到史诗文件

**测试夹具：**
- 提供的史诗路径在 `production/epics/` 中不存在

**输入：** `/create-stories nonexistent-epic`

**预期行为：**
1. 技能尝试读取 EPIC.md 文件
2. 文件未找到
3. 技能输出清晰的错误信息，包含其搜索的路径
4. 技能建议检查 `production/epics/` 或先运行 `/create-epics`
5. 未创建任何 story 文件

**断言：**
- [ ] 技能输出清晰的错误信息，指明缺失的文件路径
- [ ] 未写入任何 story 文件
- [ ] 技能推荐正确的下一步操作（`/create-epics`）
- [ ] 没有有效的 EPIC.md 时，技能不会创建 story

---

### 用例 3：阻塞的 Story — ADR 为 Proposed

**测试夹具：**
- EPIC.md 存在，包含 2 个需求
- 需求 1 被一个 Accepted ADR 覆盖
- 需求 2 被一个状态为 `Status: Proposed` 的 ADR 覆盖

**输入：** `/create-stories [epic-name]`

**预期行为：**
1. 技能读取需求 2 的 ADR，发现状态为 Proposed
2. 需求 2 的 story 以 `Status: Blocked` 起草
3. 阻塞说明引用具体的 ADR："BLOCKED: ADR-NNN is Proposed"
4. 需求 1 的 story 以 `Status: Ready` 正常起草
5. 两个 story 均在草稿中展示 — 用户对两个 story 均被询问"May I write"

**断言：**
- [ ] Story 2 在其 frontmatter 中具有 `Status: Blocked`
- [ ] 阻塞说明指定了具体的 ADR 编号，并推荐 `/architecture-decision`
- [ ] Story 1 具有 `Status: Ready` — 阻塞状态不影响未阻塞的 story
- [ ] 写入前在草稿预览中显示阻塞状态
- [ ] 两个 story 文件均被写入（被阻塞的 story 仍然写入 — 仅做标记）

---

### 用例 4：边界情况 — 未提供参数

**测试夹具：**
- `production/epics/` 目录存在，包含 ≥2 个史诗子目录

**输入：** `/create-stories`（无参数）

**预期行为：**
1. 技能检测到未提供参数
2. 输出用法错误："No epic specified. Usage: /create-stories [epic-name]"
3. 技能列出 `production/epics/` 中可用的史诗
4. 未创建任何 story 文件

**断言：**
- [ ] 未提供参数时，技能输出用法错误
- [ ] 技能列出可用的史诗以帮助用户选择
- [ ] 未写入任何 story 文件
- [ ] 技能不会在无用户输入的情况下静默选择一个史诗

---

### 用例 5：总监关卡 — Full 模式运行 QL-STORY-READY；未通过的 story 标记为 NEEDS WORK

**测试夹具：**
- EPIC.md 存在，包含 2 个需求
- 两个管辖 ADR 均为 Accepted
- `production/session-state/review-mode.txt` 包含 `full`
- QL-STORY-READY 检查发现一个 story 的验收标准不明确

**输入：** `/create-stories [epic-name]`

**预期行为：**
1. 两个 story 均被起草
2. 对每个 story 运行 QL-STORY-READY 检查
3. Story 1 通过 QL-STORY-READY
4. Story 2 未通过 QL-STORY-READY — 标记为 NEEDS WORK，带有具体反馈
5. 在"May I write"之前，两个 story 均向用户展示其通过/未通过状态
6. 用户可以选择继续（story 按原样写入，带有 NEEDS WORK 说明）或先修订

**断言：**
- [ ] QL-STORY-READY 结果在输出中按每个 story 展示
- [ ] Story 2 被标记为 NEEDS WORK，带有具体的未通过标准
- [ ] Story 1 显示为通过 QL-STORY-READY
- [ ] 用户被给予继续或修订的选择
- [ ] 技能不会在无用户输入的情况下自动阻止写入未通过 QL-STORY-READY 的 story

---

## 协议合规性

- [ ] 在起草 story 之前加载所有上下文（EPIC、GDD、ADR、清单、TR 注册表）
- [ ] 在任何"May I write"询问之前完整展示 story 草稿
- [ ] "May I write"按每个 story 分别询问（非一次性询问整个批次）
- [ ] 被阻塞的 story 在写入批准前标记 — 而非在写入后发现
- [ ] TR-ID 引用注册表 — 需求文本不直接嵌入 story 文件中
- [ ] 控制清单规则按每个 story 从清单引用，而非凭空发明
- [ ] 以下一步交接结尾：`/story-readiness` → `/dev-story`

---

## 覆盖说明

- 集成 story 的测试证据（试玩测试文档替代方案）遵循与 Logic story 相同的批准模式 — 未独立进行夹具测试。
- Story 排序（基础先行，UI 最后）通过用例 1 的多 story 夹具隐式验证。
- Story 大小规则（拆分大型需求组）在此未测试 — 在 `/create-stories` 技能的内部逻辑中处理。
