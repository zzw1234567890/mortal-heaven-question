
# 技能测试规格：/architecture-decision

## 技能概述

`/architecture-decision` 引导用户逐节编写新的架构决策记录 (Architecture Decision Record, ADR)。所需章节包括：Status（状态）、Context（背景）、Decision（决策）、Consequences（后果）、Alternatives（备选方案）和 Related ADRs（相关 ADR）。该技能还会将 `docs/engine-reference/` 中的引擎版本参考标记到 ADR 中，以实现可追溯性。

在 `full` 审查模式下，草稿完成后将启动 TD-ADR（技术总监 (Technical Director)）和 LP-FEASIBILITY（主程 (Lead Programmer)）关卡代理。如果两个关卡均返回 APPROVED，则 ADR 状态设置为 Accepted。在 `lean` 或 `solo` 模式下，两个关卡均被跳过，ADR 以 Status: Proposed 写入。技能在编写过程中逐节询问"我可以写入吗？"。ADR 写入到 `docs/architecture/adr-NNN-[name].md`。

---

## 静态断言（结构）

由 `/skill-test static` 自动验证 —— 无需测试夹具。

- [ ] 包含必需的前置元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判定关键词：ACCEPTED、PROPOSED、CONCERNS
- [ ] 包含"我可以写入吗"（May I write）协作协议措辞（逐节批准）
- [ ] 末尾包含下一步交接说明
- [ ] 记录关卡行为：full 模式下为 TD-ADR + LP-FEASIBILITY；lean/solo 模式下跳过
- [ ] 记录 ADR 状态为 Accepted（full 模式，关卡批准）或 Proposed（其他情况）
- [ ] 提及来自 `docs/engine-reference/` 的引擎版本标记

---

## 总监关卡检查

在 `full` 模式下：ADR 草稿完成后启动 TD-ADR（技术总监 (Technical Director)）和 LP-FEASIBILITY（主程 (Lead Programmer)）。如果两者均返回 APPROVED，ADR 状态设置为 Accepted。如果任一返回 CONCERNS 或 FAIL，ADR 保持 Proposed。

在 `lean` 模式下：两个关卡均被跳过。ADR 以 Status: Proposed 写入。输出注明："TD-ADR skipped — lean mode"和"LP-FEASIBILITY skipped — lean mode"。

在 `solo` 模式下：两个关卡均被跳过。ADR 以 Status: Proposed 写入。

---

## 测试用例

### 用例 1：正常路径 —— 为渲染方案创建新 ADR，full 模式，关卡批准

**测试夹具：**
- `docs/architecture/` 存在，且没有关于渲染的现有 ADR
- `docs/engine-reference/[engine]/VERSION.md` 存在
- `production/session-state/review-mode.txt` 包含 `full`

**输入：** `/architecture-decision rendering-approach`

**预期行为：**
1. 技能引导用户完成每个必需章节（Status、Context、Decision、Consequences、Alternatives、Related ADRs）
2. 从 `docs/engine-reference/` 将引擎版本标记到 ADR 中
3. 针对每个章节：展示草稿、询问"我可以写入此章节吗？"、获得批准
4. 所有章节完成后：TD-ADR 和 LP-FEASIBILITY 关卡并行启动
5. 两个关卡均返回 APPROVED
6. ADR 状态设置为 Accepted
7. 技能写入 `docs/architecture/adr-NNN-rendering-approach.md`
8. 如果定义了新的 TR-ID，则更新 `docs/architecture/tr-registry.yaml`

**断言：**
- [ ] 所有 6 个必需章节均被编写并写入
- [ ] ADR 中包含引擎版本参考标记
- [ ] TD-ADR 和 LP-FEASIBILITY 并行启动（非顺序）
- [ ] 在 full 模式下，当两个关卡均返回 APPROVED 时，ADR 状态为 Accepted
- [ ] 编写过程中逐节询问"我可以写入吗？"
- [ ] 文件写入到 `docs/architecture/adr-NNN-[name].md`

---

### 用例 2：失败路径 —— TD-ADR 返回 CONCERNS

**测试夹具：**
- ADR 草稿已完成（所有章节已填写）
- `production/session-state/review-mode.txt` 包含 `full`
- TD-ADR 关卡返回 CONCERNS："该决策未解决 [具体问题]"

**输入：** `/architecture-decision [topic]`

**预期行为：**
1. TD-ADR 关卡启动并返回 CONCERNS，附带具体反馈
2. 技能向用户展示关注点
3. ADR 状态保持 Proposed（而非 Accepted）
4. 询问用户：修订决策以解决关注点，或接受为 Proposed
5. 如果关注点未解决，ADR 以 Status: Proposed 写入

**断言：**
- [ ] TD-ADR 的关注点逐字展示给用户
- [ ] 当 TD-ADR 返回 CONCERNS 时，ADR 状态为 Proposed（而非 Accepted）
- [ ] 在 CONCERNS 未解决时，技能不会将状态设置为 Accepted
- [ ] 用户可以选择修订并重新运行关卡

---

### 用例 3：Lean 模式 —— 两个关卡均跳过；ADR 以 Proposed 写入

**测试夹具：**
- `production/session-state/review-mode.txt` 包含 `lean`
- 针对新的技术决策编写 ADR 草稿

**输入：** `/architecture-decision [topic]`

**预期行为：**
1. 技能引导用户完成所有 6 个章节
2. 草稿完成后：TD-ADR 和 LP-FEASIBILITY 均被跳过
3. 输出注明："TD-ADR skipped — lean mode"和"LP-FEASIBILITY skipped — lean mode"
4. ADR 以 Status: Proposed 写入（非 Accepted，因为关卡未批准）
5. 在最终文件写入前仍会询问"我可以写入吗？"

**断言：**
- [ ] 输出中出现两个关卡跳过说明
- [ ] 在 lean 模式下 ADR 状态为 Proposed（而非 Accepted）
- [ ] 写入文件前仍会询问"我可以写入吗？"
- [ ] 技能在用户批准后写入 ADR

---

### 用例 4：边界情况 —— 该主题的 ADR 已存在

**测试夹具：**
- `docs/architecture/` 包含一个覆盖相同主题的现有 ADR
- 现有 ADR 的状态为 Accepted

**输入：** `/architecture-decision [same-topic]`

**预期行为：**
1. 技能检测到覆盖相同主题的现有 ADR
2. 技能询问："[主题] 的 ADR 已存在（[文件名]）。是更新它，还是创建新的替代 ADR？"
3. 用户选择更新或替代
4. 技能不会静默创建重复的 ADR

**断言：**
- [ ] 技能在开始编写前检测到现有 ADR
- [ ] 向用户提供更新或替代选项 —— 不会静默创建重复
- [ ] 如果选择更新：技能打开现有 ADR 进行逐节修订
- [ ] 如果选择替代：新 ADR 在 Related ADRs 章节中引用被替代的 ADR

---

### 用例 5：总监关卡 —— 根据模式和关卡结果正确设置状态

**测试夹具：**
- ADR 草稿已完成
- 两种场景：(a) full 模式，两个关卡 APPROVED；(b) full 模式，一个关卡 CONCERNS

**Full 模式，两个均 APPROVED：**
- ADR 状态设置为 Accepted

**断言（均批准）：**
- [ ] ADR 前置元数据/标题显示 `Status: Accepted`
- [ ] TD-ADR 和 LP-FEASIBILITY 在输出中均显示为 APPROVED

**Full 模式，一个关卡返回 CONCERNS：**
- ADR 状态保持 Proposed

**断言（CONCERNS）：**
- [ ] ADR 前置元数据/标题显示 `Status: Proposed`
- [ ] 关注点在输出中列出
- [ ] 当有关卡返回 CONCERNS 时，技能不会将状态设置为 Accepted

**Lean/solo 模式：**
- 无论内容质量如何，ADR 状态始终为 Proposed

**断言（lean/solo）：**
- [ ] 在 lean 模式下 ADR 状态为 Proposed
- [ ] 在 solo 模式下 ADR 状态为 Proposed
- [ ] lean 或 solo 模式下不显示关卡输出

---

## 协议合规性

- [ ] 在关卡审查之前完成所有 6 个必需章节的编写
- [ ] 从 `docs/engine-reference/` 将引擎版本标记到 ADR 中
- [ ] 编写过程中逐节询问"我可以写入吗？"
- [ ] 在 full 模式下 TD-ADR 和 LP-FEASIBILITY 并行启动
- [ ] 在 lean/solo 输出中按名称和模式注明跳过的关卡
- [ ] ADR 状态为 Accepted 仅当 full 模式且两个关卡均 APPROVED
- [ ] 以下一步交接结束：`/architecture-review` 或 `/create-control-manifest`

---

## 覆盖说明

- ADR 编号（自动递增的 NNN）未独立通过测试夹具验证 —— 技能读取现有 ADR 文件名以分配下一个编号。
- Related ADRs 章节的链接（替代/相关）通过用例 4 进行了结构测试，但未单独验证所有链接类型。
- TR-registry 更新（当 ADR 中定义新的 TR-ID 时）是写入阶段的一部分 —— 通过用例 1 隐式测试。
