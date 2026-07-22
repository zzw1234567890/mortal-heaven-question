
# 技能测试规格：/qa-plan

## 技能概述 (Skill Summary)

`/qa-plan` 为特性或冲刺里程碑生成结构化的 QA 测试计划。它读取指定冲刺的故事文件，从每个故事中提取验收标准（Acceptance Criteria, AC），交叉参考 `coding-standards.md` 中的测试标准以分配适当的测试类型（单元测试、集成测试、视觉测试、UI 测试或配置/数据测试），并生成优先级排序的 QA 计划文档。

技能在持久化输出前询问"我可以写入 `production/qa/qa-plan-sprint-NNN.md` 吗？"。如果找到同一冲刺的现有测试计划，技能主动提供更新（update）而非替换（replace）选项。计划写入后判定结果为 COMPLETE。不使用主管关口——故事级别的关口就绪性由 `/story-readiness` 处理。

---

## 静态断言（结构性）

由 `/skill-test static` 自动验证——无需测试夹具。

- [ ] 包含必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判定关键词：COMPLETE
- [ ] 在写入计划前包含"May I write"协作协议用语
- [ ] 包含下一步交接（例如 `/smoke-check` 或 `/story-readiness`）

---

## 主管关口检查

无。`/qa-plan` 是一个计划工具。故事就绪性关口是独立的。

---

## 测试用例

### 用例 1：正常路径——4 个故事的冲刺生成完整测试计划

**测试夹具：**
- `production/sprints/sprint-003.md` 列出了 4 个故事，每个都定义了验收标准
- 故事类型涵盖：1 个逻辑（公式）、1 个集成、1 个视觉、1 个 UI
- `coding-standards.md` 存在并包含测试证据表

**输入：** `/qa-plan sprint-003`

**预期行为：**
1. 技能读取 sprint-003.md 并识别出 4 个故事
2. 技能读取每个故事的验收标准
3. 技能根据 coding-standards.md 表分配测试类型：
   - 逻辑故事 → 单元测试（BLOCKING）
   - 集成故事 → 集成测试（BLOCKING）
   - 视觉故事 → 截图 + 主管签字批准（ADVISORY）
   - UI 故事 → 手动演练文档（ADVISORY）
4. 技能草拟 QA 计划，包含逐个故事的测试类型分解
5. 技能询问"我可以写入 `production/qa/qa-plan-sprint-003.md` 吗？"
6. 批准后写入文件；判定结果为 COMPLETE

**断言：**
- [ ] 计划中包含所有 4 个故事
- [ ] 测试类型根据 coding-standards.md 分配（而非猜测）
- [ ] 为每个故事注明关口级别（BLOCKING 或 ADVISORY）
- [ ] 使用正确的文件路径询问"May I write"
- [ ] 判定结果为 COMPLETE

---

### 用例 2：故事无验收标准——标记为 UNTESTABLE

**测试夹具：**
- `production/sprints/sprint-004.md` 列出了 3 个故事；其中一个故事的验收标准章节为空

**输入：** `/qa-plan sprint-004`

**预期行为：**
1. 技能读取所有 3 个故事
2. 技能检测到无验收标准的故事
3. 该故事在计划中标记为 `UNTESTABLE — 需要验收标准 (Acceptance Criteria)`
4. 其他 2 个故事获得正常的测试类型分配
5. 计划写入时标记了 UNTESTABLE 故事；判定结果为 COMPLETE

**断言：**
- [ ] 无验收标准的故事出现 UNTESTABLE 标签
- [ ] 计划不被阻塞——其他故事仍被计划
- [ ] 输出建议向被标记的故事添加验收标准（下一步）
- [ ] 判定结果为 COMPLETE（计划仍被生成）

---

### 用例 3：找到现有测试计划——提供更新而非替换

**测试夹具：**
- `production/qa/qa-plan-sprint-003.md` 已存在（来自之前的运行）
- 自上一份计划以来，sprint-003 新增了 2 个故事

**输入：** `/qa-plan sprint-003`

**预期行为：**
1. 技能读取 sprint-003.md 并检测到 2 个不在现有计划中的故事
2. 技能报告："找到 sprint-003 的现有 QA 计划——提供更新"
3. 技能展示 2 个新故事及其建议的测试分配
4. 技能询问"我可以更新 `production/qa/qa-plan-sprint-003.md` 吗？"（而非覆盖）
5. 批准后写入更新后的计划

**断言：**
- [ ] 技能检测到现有的计划文件
- [ ] 使用"更新"（update）用语（而非"覆盖"）
- [ ] 仅建议添加新故事——保留现有条目
- [ ] 判定结果为 COMPLETE

---

### 用例 4：未找到该冲刺的故事——带指导的错误提示

**测试夹具：**
- `production/sprints/sprint-007.md` 不存在
- 无其他匹配 sprint-007 的冲刺文件

**输入：** `/qa-plan sprint-007`

**预期行为：**
1. 技能尝试读取 sprint-007.md——文件未找到
2. 技能输出："未找到 sprint-007 的冲刺文件"
3. 技能建议先运行 `/sprint-plan` 创建冲刺
4. 不写入任何计划；不询问"May I write"

**断言：**
- [ ] 错误信息指明了缺失的冲刺文件
- [ ] 建议将 `/sprint-plan` 作为补救步骤
- [ ] 未调用写入工具
- [ ] 判定结果不是 COMPLETE（错误状态）

---

### 用例 5：主管关口检查——无关卡；QA 计划是工具

**测试夹具：**
- 包含有效故事和验收标准的冲刺

**输入：** `/qa-plan sprint-003`

**预期行为：**
1. 技能生成并写入 QA 计划
2. 不生成任何主管智能体
3. 输出中不出现关口 ID

**断言：**
- [ ] 未调用主管关口
- [ ] 不出现关口跳过消息
- [ ] 技能达到 COMPLETE，不附带任何关口检查

---

## 协议合规性

- [ ] 在分配测试类型前读取 coding-standards.md 测试证据表
- [ ] 按故事类型分配 BLOCKING 或 ADVISORY 关口级别
- [ ] 将无验收标准的故事标记为 UNTESTABLE（不会静默跳过）
- [ ] 检测现有计划并提供更新路径
- [ ] 在创建或更新计划文件前询问"May I write"
- [ ] 计划写入后判定结果为 COMPLETE

---

## 覆盖说明

- `coding-standards.md` 缺失（技能无法分配测试类型）的情况未使用夹具测试；行为将遵循 BLOCKED 模式，并附有恢复标准文件的说明。
- 多冲刺计划（跨越 2 个冲刺）未测试；该技能设计为一次处理一个冲刺。
- 配置/数据故事类型（平衡调优 → 冒烟检查）遵循与用例 1 中其他类型相同的分配模式，未单独测试。