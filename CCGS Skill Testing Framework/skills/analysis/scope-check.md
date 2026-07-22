
# 技能测试规格：/scope-check（范围检查）

## 技能概述（Skill Summary）

`/scope-check` 是一项 Haiku 层级（Haiku-tier）的只读技能，用于分析特性、冲刺（Sprint）或故事是否存在范围蔓延（Scope Creep）风险。它读取冲刺和故事文件，并与活跃的里程碑目标进行比较。该技能设计用于在规划之前或期间进行快速、低成本的检查。不调用任何主管关卡（Director Gate）。不写入任何文件。裁决结果（Verdict）：ON SCOPE（范围内的）、CONCERNS（关注）或 SCOPE CREEP DETECTED（检测到范围蔓延）。

---

## 静态断言（结构）（Static Assertions）

由 `/skill-test static` 自动验证 —— 无需测试夹具。

- [ ] 具有所需的前置元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题
- [ ] 包含裁决关键词：ON SCOPE、CONCERNS、SCOPE CREEP DETECTED
- [ ] 不需要"May I write"用语（只读技能）
- [ ] 具有下一步交接说明（根据裁决结果采取的操作建议）

---

## 主管关卡检查（Director Gate Checks）

无。范围检查是一项只读建议性技能；不调用任何关卡。

---

## 测试用例（Test Cases）

### 用例 1：正常路径 —— 冲刺故事与里程碑目标一致

**测试夹具（Fixture）：**
- `production/milestones/milestone-03.md` 列出 3 个目标：战斗系统、敌人 AI、关卡加载
- `production/sprints/sprint-006.md` 包含 5 个故事，全部标记到 3 个目标之一
- `production/session-state/active.md` 引用 milestone-03 作为活跃的里程碑

**输入：** `/scope-check`

**预期行为：**
1. 技能从 milestone-03 读取活跃的里程碑目标
2. 技能读取 sprint-006 的故事，并对照里程碑目标检查每个故事
3. 所有 5 个故事映射到 3 个目标之一
4. 技能输出映射表：故事 → 里程碑目标
5. 裁决结果为 ON SCOPE

**断言：**
- [ ] 输出中每个故事映射到一个里程碑目标
- [ ] 当所有故事映射到里程碑目标时，裁决结果为 ON SCOPE
- [ ] 不写入任何文件
- [ ] 技能不修改冲刺或里程碑文件

---

### 用例 2：检测到范围蔓延 —— 故事引入了里程碑中不存在的系统

**测试夹具：**
- `production/milestones/milestone-03.md` 目标：战斗、敌人 AI、关卡加载
- `production/sprints/sprint-006.md` 包含 5 个故事：
  - 3 个故事映射到里程碑目标
  - 2 个故事引用了"在线排行榜"和"成就系统"（不在 milestone-03 中）

**输入：** `/scope-check`

**预期行为：**
1. 技能读取里程碑目标和冲刺故事
2. 技能识别出 2 个没有匹配里程碑目标的故事
3. 技能明确指出超范围的故事名称："在线排行榜功能"、"成就系统设置"
4. 裁决结果为 SCOPE CREEP DETECTED

**断言：**
- [ ] 输出中明确列出超范围的故事名称
- [ ] 当任何故事没有匹配的里程碑目标时，裁决结果为 SCOPE CREEP DETECTED
- [ ] 技能不自动移除故事 —— 发现结果为建议性质
- [ ] 输出建议将超范围的故事推迟到后续里程碑

---

### 用例 3：未定义里程碑 —— CONCERNS；无法验证范围

**测试夹具：**
- `production/session-state/active.md` 没有里程碑引用
- `production/milestones/` 目录存在但为空
- `production/sprints/sprint-006.md` 有 4 个故事

**输入：** `/scope-check`

**预期行为：**
1. 技能读取 active.md —— 未找到里程碑引用
2. 技能检查 `production/milestones/` —— 未找到里程碑文件
3. 技能输出："未定义活跃的里程碑 —— 无法验证范围"
4. 裁决结果为 CONCERNS

**断言：**
- [ ] 当未定义里程碑时，技能不会报错
- [ ] 输出明确说明范围验证需要里程碑引用
- [ ] 裁决结果为 CONCERNS（而非 ON SCOPE 或 SCOPE CREEP DETECTED—— 缺乏数据）
- [ ] 输出建议运行 `/milestone-review` 或创建一个里程碑

---

### 用例 4：单个故事检查 —— 对照其父级史诗进行评估

**测试夹具：**
- 用户针对单个故事：`production/epics/combat/story-parry-timing.md`
- 故事引用父级史诗：`epic-combat.md`
- `production/epics/combat/epic-combat.md` 的范围是"近战战斗机制"
- 故事标题："实现格挡时机窗口" —— 与史诗范围匹配

**输入：** `/scope-check production/epics/combat/story-parry-timing.md`

**预期行为：**
1. 技能读取指定的故事文件
2. 技能读取父级史诗以获取范围定义
3. 技能对照史诗范围评估故事 —— "格挡时机"匹配"近战战斗"
4. 裁决结果为 ON SCOPE

**断言：**
- [ ] 接受单文件参数（故事路径，而非冲刺）
- [ ] 技能读取故事文件中引用的父级史诗
- [ ] 在单故事模式下，故事对照史诗范围（而非里程碑范围）进行评估
- [ ] 当故事匹配史诗范围时，裁决结果为 ON SCOPE

---

### 用例 5：关卡合规性 —— 无关卡；可单独咨询制作人

**测试夹具：**
- 冲刺有 2 个 SCOPE CREEP 故事和 3 个 ON SCOPE 故事
- `review-mode.txt` 包含 `full`

**输入：** `/scope-check`

**预期行为：**
1. 技能读取里程碑和冲刺；识别出 2 个范围蔓延项
2. 无论审核模式如何，均不调用任何主管关卡
3. 技能展示发现结果，裁决结果为 SCOPE CREEP DETECTED
4. 输出说明："建议在冲刺开始前向制作人（Producer）提出范围问题"
5. 技能结束，不写入任何文件

**断言：**
- [ ] 在任何审核模式下均不调用主管关卡
- [ ] 建议（而非强制）咨询制作人
- [ ] 不写入任何文件
- [ ] 裁决结果为 SCOPE CREEP DETECTED

---

## 协议合规性（Protocol Compliance）

- [ ] 在分析前读取里程碑目标和冲刺/故事文件
- [ ] 将每个故事映射到里程碑目标（或标记为未映射）
- [ ] 不写入任何文件
- [ ] 不调用任何主管关卡
- [ ] 在 Haiku 模型层级上运行（快速、低成本）
- [ ] 裁决结果为以下之一：ON SCOPE、CONCERNS、SCOPE CREEP DETECTED

---

## 覆盖范围说明（Coverage Notes）

- 冲刺文件本身不存在的情况未进行测试；该技能将输出 CONCERNS 裁决结果，并附带冲刺数据缺失的提示信息。
- 部分范围重叠（故事涉及里程碑目标，但同时引入了新范围）未进行明确测试；实现可能将其归类为 CONCERNS 而非 SCOPE CREEP DETECTED。
