# 技能测试规格：/bug-triage


## 技能概述 (Skill Summary)

`/bug-triage` 读取 `production/bugs/` 中的所有开放 Bug 报告，并按严重程度（CRITICAL → HIGH → MEDIUM → LOW）生成优先排序的分类表。它运行在 Haiku 模型上（只读、格式化/排序任务），不产生文件写入——分类输出为对话形式。技能会标记缺少重现步骤的 Bug，并通过比较标题和受影响系统来识别可能的重复项。

裁决结果始终为 TRIAGED——该技能是建议性和信息性的。不设总监关卡 (director gates)。输出旨在帮助制作人 (producer) 或 QA 负责人确定接下来需要处理哪些 Bug。

---

## 静态断言 (Structural)

由 `/skill-test static` 自动验证——无需测试夹具。

- [ ] 拥有必需的前置元字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 有 ≥2 个阶段标题
- [ ] 包含裁决关键词：TRIAGED
- [ ] 不包含"May I write"语言（技能为只读）
- [ ] 有下一步交接（例如，`/bug-report` 创建新报告，关键 Bug 使用 `/hotfix`）

---

## 总监关卡检查 (Director Gate Checks)

无。`/bug-triage` 是一个只读建议性技能。不设总监关卡。

---

## 测试用例 (Test Cases)

### 用例 1：正常路径 (Happy Path) —— 5 个不同严重程度的 Bug，生成排序表

**测试夹具：**
- `production/bugs/` 包含 5 个 Bug 报告文件：
  - bug-2026-03-10-audio-crash.md (CRITICAL)
  - bug-2026-03-12-score-overflow.md (HIGH)
  - bug-2026-03-14-ui-overlap.md (MEDIUM)
  - bug-2026-03-15-typo-tutorial.md (LOW)
  - bug-2026-03-16-vfx-flicker.md (HIGH)

**输入：** `/bug-triage`

**预期行为：**
1. 技能读取所有 5 个 Bug 报告文件
2. 技能提取每个报告的严重程度、标题、系统和重现状态
3. 技能生成分类表，排序为：CRITICAL 优先，然后 HIGH、MEDIUM、LOW
4. 在同一严重程度内，Bug 按日期排序（最早在前）
5. 裁决结果为 TRIAGED

**断言：**
- [ ] 分类表恰好有 5 行
- [ ] CRITICAL Bug 出现在两个 HIGH Bug 之前
- [ ] HIGH Bug 出现在 MEDIUM 和 LOW Bug 之前
- [ ] 裁决结果为 TRIAGED
- [ ] 没有文件被写入

---

### 用例 2：未找到 Bug 报告 (No Bug Reports Found) —— 引导运行 /bug-report

**测试夹具：**
- `production/bugs/` 目录存在但为空（或不存在）

**输入：** `/bug-triage`

**预期行为：**
1. 技能扫描 `production/bugs/` 未发现任何报告
2. 技能输出："在 production/bugs/ 中未发现开放 Bug 报告"
3. 技能建议运行 `/bug-report` 创建 Bug 报告
4. 不生成分类表

**断言：**
- [ ] 输出明确说明未找到 Bug
- [ ] 建议 `/bug-report` 作为下一步
- [ ] 技能不会报错——它能优雅处理空目录
- [ ] 裁决结果为 TRIAGED（附带"未发现 Bug"的上下文）

---

### 用例 3：Bug 缺少重现步骤 (Bug Missing Reproduction Steps) —— 标记为 NEEDS REPRO INFO

**测试夹具：**
- `production/bugs/` 包含 3 个 Bug 报告；其中一个的"重现步骤"部分为空

**输入：** `/bug-triage`

**预期行为：**
1. 技能读取所有 3 个报告
2. 技能检测到缺少重现步骤的报告
3. 该 Bug 在分类表中显示时带有 `NEEDS REPRO INFO` 标签
4. 其他 Bug 正常分类
5. 裁决结果为 TRIAGED

**断言：**
- [ ] 缺少重现步骤的 Bug 旁边出现 `NEEDS REPRO INFO` 标签
- [ ] 被标记的 Bug 仍包含在表中（未被排除）
- [ ] 其他 Bug 不受影响
- [ ] 裁决结果为 TRIAGED

---

### 用例 4：可能的重复 Bug (Possible Duplicate Bugs) —— 在分类输出中标记

**测试夹具：**
- `production/bugs/` 包含 2 个标题相似的 Bug 报告：
  - bug-2026-03-18-player-fall-through-floor.md
  - bug-2026-03-20-player-clips-through-floor.md
  - 两者都影响"物理 (Physics)"系统，严重程度相同

**输入：** `/bug-triage`

**预期行为：**
1. 技能读取两个报告，检测到相似的标题 + 相同的系统 + 相同的严重程度
2. 两个 Bug 都包含在分类表中
3. 每个 Bug 都标记有 `POSSIBLE DUPLICATE` 并交叉引用另一个报告
4. 不合并或删除任何 Bug——标记为建议性
5. 裁决结果为 TRIAGED

**断言：**
- [ ] 两个 Bug 都出现在表中（未合并）
- [ ] 两者都标记为 `POSSIBLE DUPLICATE`
- [ ] 每个交叉引用另一个（通过文件名或标题）
- [ ] 裁决结果为 TRIAGED

---

### 用例 5：总监关卡检查 (Director Gate Check) —— 无关卡；分类是建议性的

**测试夹具：**
- `production/bugs/` 包含任意数量的报告

**输入：** `/bug-triage`

**预期行为：**
1. 技能生成分类表
2. 未生成任何总监代理
3. 输出中不出现关卡 ID
4. 未调用任何写入工具

**断言：**
- [ ] 未调用任何总监关卡
- [ ] 未调用任何写入工具
- [ ] 未出现关卡跳过消息
- [ ] 无需任何关卡检查，裁决结果为 TRIAGED

---

## 协议合规性 (Protocol Compliance)

- [ ] 在生成表格之前读取 `production/bugs/` 中的所有文件
- [ ] 按严重程度排序（CRITICAL → HIGH → MEDIUM → LOW）
- [ ] 标记缺少重现步骤的 Bug
- [ ] 通过标题/系统相似性标记可能的重复项
- [ ] 不写入任何文件
- [ ] 在所有情况下裁决结果均为 TRIAGED（即使为空）

---

## 覆盖说明 (Coverage Notes)

- Bug 报告格式错误的情况（完全缺少严重程度字段）未进行夹具测试；技能会将其标记为 `UNKNOWN SEVERITY` 并在表中排在最后。
- 状态转换（将 Bug 标记为已解决）不在本技能范围内——bug-triage 是只读的。
- 重复检测启发式方法（标题相似性 + 相同系统）是近似性的；精确匹配逻辑在技能主体中定义。
