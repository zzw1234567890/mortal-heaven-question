
# 技能测试规范：/dev-story

## 技能概述

`/dev-story` 读取一个 story 文件，加载所有必需的上下文（引用的 ADR、注册表中的 TR-ID、控制清单、引擎偏好），实现该 story，验证所有验收标准均已满足，并将 story 标记为完成。该技能将实现路由到正确的专家代理，具体取决于引擎和文件类型 — 它不直接编写源代码。

在 `full` 评审模式下，LP-CODE-REVIEW 关卡在标记 story 完成之前运行。在 `lean` 或 `solo` 模式下，LP-CODE-REVIEW 被跳过，story 在用户确认所有标准均已满足后被标记为完成。该技能在更新 story 状态和编写代码文件前询问"May I write"。

---

## 静态断言（结构检查）

由 `/skill-test static` 自动验证 — 无需测试夹具。

- [ ] 具有必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题
- [ ] 包含判定关键词：COMPLETE、BLOCKED、IN PROGRESS、NEEDS CHANGES
- [ ] 包含 "May I write" 协作协议措辞（story 状态 + 代码文件）
- [ ] 末尾具有下一步交接（`/story-done`）
- [ ] 文档说明 LP-CODE-REVIEW 关卡：full 模式下激活，lean/solo 模式下跳过
- [ ] 注明实现被委派给专家代理（非直接完成）

---

## 总监关卡检查

在 `full` 模式下：LP-CODE-REVIEW 关卡在实现完成且所有标准均已验证之后、标记 story 完成之前运行。

在 `lean` 模式下：LP-CODE-REVIEW 被跳过。输出注明："LP-CODE-REVIEW skipped — lean mode"。Story 在用户确认后标记为完成。

在 `solo` 模式下：LP-CODE-REVIEW 被跳过，带有等效的说明。

---

## 测试用例

### 用例 1：正常路径 — Story 已实现并标记为完成（full 模式）

**测试夹具：**
- Story 文件存在于 `production/epics/[layer]/story-[name].md`，包含：
  - `Status: Ready`
  - 引用已注册需求的 TR-ID
  - 至少 2 条 Given-When-Then 验收标准
  - 测试证据路径
- 引用的 ADR 状态为 `Status: Accepted`
- `docs/architecture/control-manifest.md` 存在
- `.claude/docs/technical-preferences.md` 已配置引擎和语言
- `production/session-state/review-mode.txt` 包含 `full`

**输入：** `/dev-story production/epics/[layer]/story-[name].md`

**预期行为：**
1. 技能读取 story 文件和所有引用的上下文
2. 技能验证 ADR 为 Accepted（无阻塞）
3. 技能将实现路由到正确的专家代理
4. 所有验收标准均被验证为已满足
5. LP-CODE-REVIEW 关卡派生并返回 APPROVED
6. 技能询问"我可以将 story 状态更新为 Complete 吗？"
7. Story 状态更新为 Complete

**断言：**
- [ ] 技能在派生任何代理之前先读取 story
- [ ] 在实现开始之前检查 ADR 状态
- [ ] 实现被委派给专家代理（非内联完成）
- [ ] 在 LP-CODE-REVIEW 之前确认所有验收标准
- [ ] LP-CODE-REVIEW 在输出中作为已完成的关卡出现
- [ ] Story 状态仅在关卡批准和用户同意后更新为 Complete
- [ ] 测试文件作为实现的一部分编写（非推迟）

---

### 用例 2：失败路径 — 引用的 ADR 为 Proposed

**测试夹具：**
- Story 文件存在，状态为 `Status: Ready`
- 该 story 的 TR-ID 指向一个由状态为 `Status: Proposed` 的 ADR 覆盖的需求

**输入：** `/dev-story production/epics/[layer]/story-[name].md`

**预期行为：**
1. 技能读取 story 文件
2. 技能解析 TR-ID 并读取管辖 ADR
3. ADR 状态为 Proposed — 技能输出 BLOCKED 消息
4. 技能指明阻塞该 story 的具体 ADR
5. 技能推荐运行 `/architecture-decision` 以推进 ADR
6. 实现不开始

**断言：**
- [ ] 当 ADR 为 Proposed 时，技能不开始实现
- [ ] BLOCKED 消息指明具体的 ADR 编号和标题
- [ ] 技能推荐 `/architecture-decision` 作为下一步操作
- [ ] Story 状态保持不变（未被设置为 In Progress 或 Complete）

---

### 用例 3：不明确的验收标准 — 技能请求澄清

**测试夹具：**
- Story 文件存在，状态为 `Status: Ready`
- 引用的 ADR 为 Accepted
- 一条验收标准不明确（非 Given-When-Then；使用主观语言，如"感觉响应迅速"）

**输入：** `/dev-story production/epics/[layer]/story-[name].md`

**预期行为：**
1. 技能读取 story 并识别出不明确的标准
2. 在路由到专家之前，技能请求用户澄清该标准
3. 用户提供具体的、可测试的重述
4. 技能使用澄清后的标准继续实现
5. 技能不猜测意图行为

**断言：**
- [ ] 技能在实现开始前展示不明确的标准
- [ ] 技能请求用户澄清（非自动解释）
- [ ] 仅在提供澄清后开始实现
- [ ] 测试中使用澄清后的标准（而非原始模糊版本）

---

### 用例 4：边界情况 — 无参数；从会话状态读取

**测试夹具：**
- 未提供参数
- `production/session-state/active.md` 引用了一个活跃的 story 文件
- 该 story 文件存在，状态为 `Status: In Progress`

**输入：** `/dev-story`（无参数）

**预期行为：**
1. 技能检测到未提供参数
2. 技能读取 `production/session-state/active.md`
3. 技能找到活跃的 story 引用
4. 技能与用户确认："继续处理 [story 标题] — 是否正确？"
5. 确认后，技能继续处理该 story

**断言：**
- [ ] 未提供参数时，技能读取会话状态
- [ ] 技能在继续前与用户确认活跃的 story
- [ ] 技能不会在未经确认的情况下静默假定活跃的 story
- [ ] 如果会话状态中没有活跃的 story，技能询问要实现哪个 story

---

### 用例 5：总监关卡 — LP-CODE-REVIEW 返回 NEEDS CHANGES；lean 模式跳过关卡

**测试夹具（full 模式）：**
- Story 已实现且所有标准看似满足
- `production/session-state/review-mode.txt` 包含 `full`
- LP-CODE-REVIEW 关卡返回 NEEDS CHANGES，带有具体反馈

**Full 模式预期行为：**
1. 实现后派生 LP-CODE-REVIEW 关卡
2. 关卡返回 NEEDS CHANGES，包含 2 个具体问题
3. Story 状态保持为 In Progress — 不标记为 Complete
4. 向用户展示关卡反馈，并询问如何处理

**断言（full 模式）：**
- [ ] 当 LP-CODE-REVIEW 返回 NEEDS CHANGES 时，Story 不被标记为 Complete
- [ ] 关卡反馈逐字向用户展示
- [ ] Story 状态保持为 In Progress，直到问题解决且关卡通过

**测试夹具（lean 模式）：**
- 相同的 story，`production/session-state/review-mode.txt` 包含 `lean`

**Lean 模式预期行为：**
1. 实现完成
2. LP-CODE-REVIEW 关卡被跳过 — 在输出中注明
3. 要求用户确认所有标准均已满足
4. 用户确认后，story 标记为 Complete

**断言（lean 模式）：**
- [ ] "LP-CODE-REVIEW skipped — lean mode" 出现在输出中
- [ ] 用户确认标准后，Story 标记为 Complete（无需关卡）
- [ ] 技能不会在跳过的关卡上阻塞

---

## 协议合规性

- [ ] 不直接编写源代码 — 委派给专家代理
- [ ] 在实现前读取所有上下文（story、TR-ID、ADR、清单、引擎偏好）
- [ ] 在更新 story 状态和编写代码文件之前询问"May I write"
- [ ] 跳过的关卡在输出中按名称和模式注明
- [ ] story 完成后更新 `production/session-state/active.md`
- [ ] 以下一步交接结尾：`/story-done`

---

## 覆盖说明

- 引擎路由逻辑（Godot vs Unity vs Unreal）未按引擎分别测试 — 路由模式是一致的；引擎选择是一个配置事实。
- Visual/Feel 和 UI story 类型（无需自动化测试）具有不同的证据要求，未在这些用例中覆盖。
- 集成 story 类型遵循与 Logic 相同的模式，但具有不同的证据路径 — 未独立进行夹具测试。
