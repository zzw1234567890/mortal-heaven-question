# 技能测试规格：/day-one-patch


## 技能概述 (Skill Summary)

`/day-one-patch` 为发布时已知但推迟到 v1.0 版本之后解决的问题，准备一份首日补丁计划。它读取 `production/bugs/` 中的开放 Bug 报告、故事文件中推迟的验收标准（标记为 `Status: Done` 但记录有推迟 AC 的故事），并生成一份按优先顺序排列的补丁计划，包含每个问题的预估修复时间。

补丁计划在"May I write"询问后写入 `production/releases/day-one-patch.md`。如果发现 P0 级问题（关键的发布后问题），技能会在补丁之前触发引导运行 `/hotfix`。不设总监关卡 (director gates)。裁决结果始终为 COMPLETE。

---

## 静态断言 (Structural)

由 `/skill-test static` 自动验证——无需测试夹具。

- [ ] 拥有必需的前置元字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 有 ≥2 个阶段标题
- [ ] 包含裁决关键词：COMPLETE
- [ ] 在编写计划前包含"May I write"协作协议语言
- [ ] 有下一步交接（例如，P0 问题使用 `/hotfix`，后续使用 `/release-checklist`）

---

## 总监关卡检查 (Director Gate Checks)

无。`/day-one-patch` 是一个发布计划工具。不设总监关卡。

---

## 测试用例 (Test Cases)

### 用例 1：正常路径 (Happy Path) —— 3 个已知问题，带修复估算的补丁计划

**测试夹具：**
- `production/bugs/` 包含 3 个开放 Bug，严重程度为：1 个 MEDIUM、2 个 LOW
- 冲刺故事中没有推迟的 AC
- 所有 Bug 都有重现步骤和系统标识

**输入：** `/day-one-patch`

**预期行为：**
1. 技能读取所有 3 个开放 Bug
2. 技能分配修复工作量估算：MEDIUM Bug = 1-2 天，LOW Bug = 每个 4 小时
3. 技能生成补丁计划，优先处理 MEDIUM Bug
4. 计划包括：优先顺序、预估时间线、负责系统、修复描述
5. 技能询问"是否可以写入 `production/releases/day-one-patch.md`？"
6. 文件写入；裁决结果为 COMPLETE

**断言：**
- [ ] 所有 3 个 Bug 都出现在计划中
- [ ] Bug 按严重程度优先排序（MEDIUM 在 LOW 之前）
- [ ] 每个问题都提供了修复估算
- [ ] 在写入之前询问"May I write"
- [ ] 裁决结果为 COMPLETE

---

### 用例 2：发布后发现关键问题 (Critical Issue Discovered Post-Ship) —— P0，触发 /hotfix 引导

**测试夹具：**
- v1.0 发布后在 `production/bugs/` 中发现一个 CRITICAL 严重程度的 Bug
- 该 Bug 导致所有存档文件数据丢失

**输入：** `/day-one-patch`

**预期行为：**
1. 技能读取 Bug 并识别出 CRITICAL 严重程度问题
2. 技能升级："检测到 P0 问题——数据丢失 Bug 需要在进行补丁计划前立即热修复"
3. 技能不将 P0 问题包含在补丁计划时间线中
4. 技能明确指示："请先运行 `/hotfix` 解决此问题"
5. 发布 P0 引导后：其余低严重程度 Bug 的计划仍然生成并写入；裁决结果为 COMPLETE

**断言：**
- [ ] P0 升级消息在补丁计划之前突出显示
- [ ] 明确指示对 P0 问题运行 `/hotfix`
- [ ] P0 问题未安排在补丁计划时间线中（需要立即处理）
- [ ] 非 P0 问题仍按计划处理；裁决结果为 COMPLETE

---

### 用例 3：故事完成中推迟的 AC (Deferred AC From Story-Done) —— 自动纳入补丁计划

**测试夹具：**
- `production/sprints/sprint-008.md` 中有一个故事标记为 `Status: Done`，并附说明：
  "推迟的 AC (DEFERRED AC)：受到伤害时手柄震动——推迟到发布后补丁"
- 同一系统没有开放 Bug

**输入：** `/day-one-patch`

**预期行为：**
1. 技能读取冲刺故事并检测到推迟的 AC 说明
2. 推迟的 AC 自动作为工作项纳入补丁计划
3. 计划条目："来自 sprint-008 的推迟项：受到伤害时手柄震动"
4. 分配修复估算；在"May I write"批准后写入补丁计划
5. 裁决结果为 COMPLETE

**断言：**
- [ ] 故事文件中的推迟 AC 自动纳入计划
- [ ] 推迟项按其来源故事标注（sprint-008）
- [ ] 推迟 AC 像 Bug 条目一样获得修复估算
- [ ] 裁决结果为 COMPLETE

---

### 用例 4：无已知问题 (No Known Issues) —— 带模板说明的空计划

**测试夹具：**
- `production/bugs/` 为空
- 没有故事有推迟的 AC

**输入：** `/day-one-patch`

**预期行为：**
1. 技能读取 Bug——未找到
2. 技能读取故事推迟的 AC——未找到
3. 技能生成空补丁计划，附带说明："发布时无已知问题"
4. 模板结构保留（标题完整）供将来使用
5. 技能询问"是否可以写入 `production/releases/day-one-patch.md`？"
6. 文件写入；裁决结果为 COMPLETE

**断言：**
- [ ] "发布时无已知问题"说明出现在写入的文件中
- [ ] 空计划中存在模板标题
- [ ] 当没有需要计划的问题时，技能不会报错
- [ ] 裁决结果为 COMPLETE

---

### 用例 5：总监关卡检查 (Director Gate Check) —— 无关卡；首日补丁是计划工具

**测试夹具：**
- `production/bugs/` 中存在已知问题

**输入：** `/day-one-patch`

**预期行为：**
1. 技能生成并写入补丁计划
2. 未生成任何总监代理
3. 输出中不出现关卡 ID

**断言：**
- [ ] 未调用任何总监关卡
- [ ] 未出现关卡跳过消息
- [ ] 无需任何关卡检查，裁决结果为 COMPLETE

---

## 协议合规性 (Protocol Compliance)

- [ ] 在生成计划之前读取 `production/bugs/` 中的开放 Bug
- [ ] 扫描故事文件中推迟的 AC 说明
- [ ] 对 CRITICAL (P0) Bug 发出升级警报，并明确引导运行 `/hotfix`
- [ ] 当没有问题存在时，生成附带说明的空计划（非错误）
- [ ] 在写入之前询问"是否可以写入 `production/releases/day-one-patch.md`？"
- [ ] 所有路径的裁决结果均为 COMPLETE

---

## 覆盖说明 (Coverage Notes)

- 存在多个 CRITICAL Bug 的情况与用例 2 的处理方式相同；所有 P0 问题一起升级。
- 补丁的时间线估算（例如，"补丁可在 3 天内提供"）需要手动 QA 和构建时间估算；技能根据严重程度使用粗略估算，而非实际团队速度。
- 补丁说明玩家沟通文档（`/patch-notes`）是一个独立的技能，在补丁计划执行后调用。
