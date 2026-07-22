# 技能测试规格：/help


## 技能概述 (Skill Summary)

`/help` 分析项目工作流中已完成的工作以及接下来要做什么。它运行在 Haiku 模型上（只读、格式化任务），读取 `production/stage.txt`、活跃的冲刺文件和最近的会话状态，生成简洁的情境指导摘要。技能可选地接受上下文查询（例如，`/help testing`），以针对特定主题展示相关技能。

输出始终是信息性的——不写入文件，不调用总监关卡 (director gates)。裁决结果始终为 HELP COMPLETE。该技能充当工作流导航器，根据当前项目状态建议 2-3 个后续技能。

---

## 静态断言 (Structural)

由 `/skill-test static` 自动验证——无需测试夹具。

- [ ] 拥有必需的前置元字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 有 ≥2 个阶段标题
- [ ] 包含裁决关键词：HELP COMPLETE
- [ ] 不包含"May I write"语言（技能为只读）
- [ ] 有下一步交接（根据状态建议 2-3 个相关技能）

---

## 总监关卡检查 (Director Gate Checks)

无。`/help` 是一个只读导航技能。不设总监关卡。

---

## 测试用例 (Test Cases)

### 用例 1：正常路径 (Happy Path) —— 生产阶段，有活跃冲刺

**测试夹具：**
- `production/stage.txt` 内容为 `Production`
- `production/sprints/sprint-004.md` 存在，包含进行中的故事
- `production/session-state/active.md` 有最近的检查点

**输入：** `/help`

**预期行为：**
1. 技能读取 stage.txt 和活跃冲刺
2. 技能识别当前冲刺编号和进行中的故事数量
3. 技能输出：当前阶段、冲刺摘要和 3 个建议的后续技能（例如，`/sprint-status`、`/dev-story`、`/story-done`）
4. 建议按与当前冲刺状态的相关性排序
5. 裁决结果为 HELP COMPLETE

**断言：**
- [ ] 显示当前阶段 (Production)
- [ ] 提及活跃的冲刺编号和故事数量
- [ ] 恰好给出 2-3 个技能建议（不是所有技能的列表）
- [ ] 建议适合 Production 阶段
- [ ] 裁决结果为 HELP COMPLETE
- [ ] 没有文件被写入

---

### 用例 2：概念阶段 (Concept Stage) —— 展示从概念到系统设计的工作流路径

**测试夹具：**
- `production/stage.txt` 内容为 `Concept`
- 没有冲刺文件，没有 GDD 文件
- `technical-preferences.md` 已配置（引擎已选择）

**输入：** `/help`

**预期行为：**
1. 技能读取 stage.txt——检测到 Concept 阶段
2. 技能输出 Concept 阶段工作流：brainstorm → map-systems → design-system
3. 建议的技能为：`/brainstorm`、`/map-systems`（如果概念存在）
4. 注明当前进度："引擎已配置，概念尚未创建"

**断言：**
- [ ] 阶段被识别为 Concept
- [ ] 工作流路径显示该阶段的预期序列
- [ ] 建议不包含 Production 阶段的技能（例如，`/dev-story`）
- [ ] 裁决结果为 HELP COMPLETE

---

### 用例 3：无 stage.txt (No stage.txt) —— 显示完整工作流概览

**测试夹具：**
- 没有 `production/stage.txt`
- 没有冲刺文件
- `technical-preferences.md` 包含占位符

**输入：** `/help`

**预期行为：**
1. 技能无法从 stage.txt 确定阶段
2. 技能运行 project-stage-detect 逻辑，根据现有制品推断阶段
3. 如果无法推断阶段：输出从 Concept 到 Release 的完整工作流概览作为参考地图
4. 主要建议是运行 `/start` 开始配置

**断言：**
- [ ] 当 stage.txt 不存在时技能不会崩溃
- [ ] 当无法确定阶段时显示完整工作流概览
- [ ] `/start` 或 `/project-stage-detect` 是首要建议
- [ ] 裁决结果为 HELP COMPLETE

---

### 用例 4：上下文查询 (Context Query) —— 用户请求测试方面的帮助

**测试夹具：**
- `production/stage.txt` 内容为 `Production`
- 活跃冲刺中有一个故事状态为 `Status: In Review`

**输入：** `/help testing`

**预期行为：**
1. 技能读取上下文查询："testing"
2. 技能展示与测试相关的技能：`/qa-plan`、`/smoke-check`、`/regression-suite`、`/test-setup`、`/test-evidence-review`
3. 输出聚焦于测试工作流，而非一般冲刺导航
4. 当前处于 Review 状态的故事被突出显示为测试候选

**断言：**
- [ ] 上下文查询在输出中被确认（"帮助主题：testing"）
- [ ] 至少列出 3 个与测试相关的技能
- [ ] 一般冲刺技能（例如，`/sprint-plan`）不是主要建议
- [ ] 裁决结果为 HELP COMPLETE

---

### 用例 5：总监关卡检查 (Director Gate Check) —— 无关卡；help 是只读导航

**测试夹具：**
- 任意项目状态

**输入：** `/help`

**预期行为：**
1. 技能生成工作流指导摘要
2. 未生成任何总监代理
3. 输出中不出现关卡 ID
4. 未调用任何写入工具

**断言：**
- [ ] 未调用任何总监关卡
- [ ] 未调用任何写入工具
- [ ] 未出现关卡跳过消息
- [ ] 无需任何关卡检查，裁决结果为 HELP COMPLETE

---

## 协议合规性 (Protocol Compliance)

- [ ] 在生成建议之前读取阶段、冲刺和会话状态
- [ ] 建议针对当前项目状态（非通用）
- [ ] 上下文查询（如果提供）缩小了建议范围
- [ ] 不写入任何文件
- [ ] 在所有情况下裁决结果均为 HELP COMPLETE

---

## 覆盖说明 (Coverage Notes)

- 活跃冲刺已完成的情况（所有故事均为 Done）未单独测试；技能会建议为下一个冲刺运行 `/sprint-plan`。
- `/help` 技能不验证建议的技能是否可用——它假定标准技能目录的可用性。
- 阶段检测回退（当 stage.txt 不存在时）委托给与 `/project-stage-detect` 相同的逻辑，此处未详细重新测试。
