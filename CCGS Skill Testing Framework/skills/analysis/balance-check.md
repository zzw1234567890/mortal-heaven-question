
# 技能测试规格：/balance-check（平衡性检查）

## 技能概述（Skill Summary）

`/balance-check` 读取平衡数据文件（JSON 或 YAML，位于 `assets/data/`），并根据 `design/gdd/` 下游戏设计文档（Game Design Document, GDD）中定义的设计公式检查每个值。它生成一个发现结果表，包含列：值（Value）→ 公式（Formula）→ 偏差（Deviation）→ 严重程度（Severity）。不调用任何主管关卡（只读分析）。该技能可选写入平衡报告，但在执行前会询问"May I write"。裁决结果（Verdict）：BALANCED（平衡）、CONCERNS（关注）或 OUT OF BALANCE（失衡）。

---

## 静态断言（结构）（Static Assertions）

由 `/skill-test static` 自动验证 —— 无需测试夹具。

- [ ] 具有所需的前置元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题
- [ ] 包含裁决关键词：BALANCED、CONCERNS、OUT OF BALANCE
- [ ] 包含"May I write"用语（可选的报告写入）
- [ ] 具有下一步交接说明（审查发现结果后的操作建议）

---

## 主管关卡检查（Director Gate Checks）

无。平衡性检查是一项只读分析技能；不调用任何关卡。

---

## 测试用例（Test Cases）

### 用例 1：正常路径 —— 所有平衡值在公式容差范围内

**测试夹具（Fixture）：**
- `assets/data/combat-balance.json` 存在，包含 6 个属性值
- `design/gdd/combat-system.md` 包含所有 6 个属性的公式，容差为 ±10%
- 所有 6 个值均在容差范围内

**输入：** `/balance-check`

**预期行为：**
1. 技能读取 `assets/data/` 中的所有平衡数据文件
2. 技能从 `design/gdd/` 读取 GDD 公式
3. 技能计算每个值相对于其公式的偏差
4. 所有偏差均在 ±10% 容差范围内
5. 技能输出发现结果表，所有行显示 PASS
6. 裁决结果为 BALANCED

**断言：**
- [ ] 对所有检查的值展示发现结果表
- [ ] 每行显示：属性名称、公式目标值、实际值、偏差百分比
- [ ] 在容差范围内时所有行显示 PASS 或等效标识
- [ ] 裁决结果为 BALANCED
- [ ] 未经用户批准不写入任何文件

---

### 用例 2：失衡 —— 玩家伤害超出公式目标 40%

**测试夹具：**
- `assets/data/combat-balance.json` 包含 `player_damage_base: 140`
- `design/gdd/combat-system.md` 公式指定 `player_damage_base = 100`（±10%）
- 所有其他属性在容差范围内

**输入：** `/balance-check`

**预期行为：**
1. 技能读取 combat-balance.json 并计算 `player_damage_base` 的偏差
2. 偏差为 +40% —— 远超 ±10% 容差范围
3. 技能在发现结果表中将该行标记为严重程度 HIGH
4. 裁决结果为 OUT OF BALANCE
5. 技能在表格之前突出显示严重程度为 HIGH 的项目

**断言：**
- [ ] `player_damage_base` 行显示偏差为 +40%
- [ ] 偏差超出容差范围 2 倍以上时，严重程度为 HIGH
- [ ] 当任何属性存在严重程度为 HIGH 的偏差时，裁决结果为 OUT OF BALANCE
- [ ] 严重程度为 HIGH 的项目被明确标出，而非埋没在表格行中

---

### 用例 3：无 GDD 公式 —— 无法验证，给出指导

**测试夹具：**
- `assets/data/economy-balance.yaml` 存在，包含 10 个属性值
- `design/gdd/` 中没有 GDD 包含经济属性的公式定义

**输入：** `/balance-check`

**预期行为：**
1. 技能读取平衡数据文件
2. 技能搜索 GDD 中的公式定义 —— 未找到经济属性的公式
3. 技能输出："无法验证经济属性 —— 未定义公式。请先运行 /design-system。"
4. 不生成经济属性的发现结果表
5. 裁决结果为 CONCERNS（数据存在但无法验证）

**断言：**
- [ ] 当 GDD 中不存在公式时，技能不捏造公式目标值
- [ ] 输出明确指明缺失的公式来源
- [ ] 输出建议运行 `/design-system` 来定义公式
- [ ] 裁决结果为 CONCERNS（而非 BALANCED，因为无法进行验证）

---

### 用例 4：孤立引用 —— 平衡文件引用了未定义的属性

**测试夹具：**
- `assets/data/combat-balance.json` 包含属性 `legacy_armor_mult: 1.5`
- `design/gdd/combat-system.md` 中没有 `legacy_armor_mult` 的公式
- 所有其他属性都有公式定义并通过验证

**输入：** `/balance-check`

**预期行为：**
1. 技能读取 combat-balance.json 中的所有属性
2. 技能在任何 GDD 中找不到 `legacy_armor_mult` 的公式
3. 技能在发现结果表中将 `legacy_armor_mult` 标记为 ORPHAN REFERENCE（孤立引用）
4. 其他属性正常评估；在容差范围内的显示 PASS
5. 裁决结果为 CONCERNS（孤立引用妨碍完整验证）

**断言：**
- [ ] `legacy_armor_mult` 在发现结果表中显示为 ORPHAN REFERENCE
- [ ] 孤立引用与公式偏差在表中加以区分
- [ ] 当发现任何孤立引用时，裁决结果为 CONCERNS
- [ ] 技能不静默跳过孤立属性

---

### 用例 5：关卡合规性 —— 只读；无关卡；可选报告需经批准

**测试夹具：**
- 平衡数据和 GDD 公式存在；1 个属性存在 CONCERNS 级别的偏差（超出目标 15%）
- `review-mode.txt` 包含 `full`

**输入：** `/balance-check`

**预期行为：**
1. 技能读取数据和 GDD；生成发现结果表
2. 裁决结果为 CONCERNS（一个属性略微超出范围）
3. 不调用任何主管关卡
4. 技能向用户展示发现结果表
5. 技能提供写入可选平衡报告的选项
6. 如果用户同意：技能询问"我可以写入 `production/qa/balance-report-[date].md` 吗？"
7. 如果用户拒绝：技能结束，不写入任何文件

**断言：**
- [ ] 在任何审核模式下均不调用主管关卡
- [ ] 在不自动写入任何内容的情况下展示发现结果表
- [ ] 提供可选报告写入但不强制
- [ ] 仅在用户选择报告时才出现"May I write"提示

---

## 协议合规性（Protocol Compliance）

- [ ] 在分析前同时读取平衡数据文件和 GDD 公式
- [ ] 发现结果表显示值（Value）、公式（Formula）、偏差（Deviation）和严重程度（Severity）列
- [ ] 未经用户明确批准不写入任何文件
- [ ] 不调用任何主管关卡
- [ ] 裁决结果为以下之一：BALANCED、CONCERNS、OUT OF BALANCE

---

## 覆盖范围说明（Coverage Notes）

- `assets/data/` 完全为空的情况未进行测试；行为遵循 CONCERNS 模式，并显示未找到数据文件的提示信息。
- 容差阈值（±10%、±20%）是该技能的实现细节；测试验证的是偏差是否被检测和分类，而非确切的阈值数值。
