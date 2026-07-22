
# 技能测试规格：/consistency-check（一致性检查）

## 技能概述（Skill Summary）

`/consistency-check` 扫描 `design/gdd/` 中的所有游戏设计文档（Game Design Document, GDD），检查跨文档的内部冲突。它生成一个结构化的发现结果表，包含列：系统 A vs 系统 B、冲突类型（Conflict Type）、严重程度（Severity）（HIGH / MEDIUM / LOW）。冲突类型包括：公式不匹配（formula mismatch）、所有权冲突（competing ownership）、过期引用（stale reference）和依赖缺口（dependency gap）。

该技能在分析过程中为只读。它没有主管关卡（Director Gate）。如果用户请求，可以将可选的一致性报告写入 `design/consistency-report-[date].md`，但技能在执行前会询问"May I write"。

---

## 静态断言（结构）（Static Assertions）

由 `/skill-test static` 自动验证 —— 无需测试夹具。

- [ ] 具有所需的前置元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题
- [ ] 包含裁决关键词：CONSISTENT（一致）、CONFLICTS FOUND（发现冲突）、DEPENDENCY GAP（依赖缺口）
- [ ] 在分析过程中不需要"May I write"用语（只读扫描）
- [ ] 最后具有下一步交接说明
- [ ] 说明报告写入为可选项且需经批准

---

## 主管关卡检查（Director Gate Checks）

无主管关卡 —— 该技能不生成任何主管关卡智能体。一致性检查是一种机械扫描；扫描本身不需要创意总监或技术总监的审查。

---

## 测试用例（Test Cases）

### 用例 1：正常路径 —— 4 个 GDD 且无冲突

**测试夹具（Fixture）：**
- `design/gdd/` 包含恰好 4 个系统 GDD
- 所有 GDD 具有一致的公式（无重叠变量且值不同）
- 没有两个 GDD 声称拥有相同游戏实体或机制的 ownership
- 所有依赖引用均指向存在的 GDD

**输入：** `/consistency-check`

**预期行为：**
1. 技能读取 `design/gdd/` 中所有 4 个 GDD
2. 运行跨 GDD 一致性检查（公式、所有权、引用）
3. 未发现冲突
4. 输出结构化发现结果表，显示 0 个问题
5. 裁决结果：CONSISTENT

**断言：**
- [ ] 在生成输出前读取所有 4 个 GDD
- [ ] 发现结果表存在（即使为空 —— 显示"未发现冲突"）
- [ ] 当不存在冲突时，裁决结果为 CONSISTENT
- [ ] 未经用户批准，技能不写入任何文件
- [ ] 存在下一步交接说明

---

### 用例 2：失败路径 —— 两个 GDD 存在冲突的伤害公式

**测试夹具：**
- GDD-A 定义伤害公式：`damage = attack * 1.5`
- GDD-B 对同一实体类型定义伤害公式：`damage = attack * 2.0`
- 两个 GDD 均引用相同的"attack"变量

**输入：** `/consistency-check`

**预期行为：**
1. 技能读取所有 GDD 并检测到公式不匹配
2. 发现结果表包含条目：GDD-A vs GDD-B | 公式不匹配（Formula Mismatch） | HIGH
3. 显示具体冲突的公式（不仅仅是"存在公式冲突"）
4. 裁决结果：CONFLICTS FOUND

**断言：**
- [ ] 裁决结果为 CONFLICTS FOUND（而非 CONSISTENT）
- [ ] 冲突条目列出两个 GDD 的文件名
- [ ] 冲突类型为"Formula Mismatch"
- [ ] 直接的公式矛盾严重程度为 HIGH
- [ ] 两个冲突的公式均在发现结果表中显示
- [ ] 技能不自动解决冲突

---

### 用例 3：部分路径 —— GDD 引用了没有对应 GDD 的系统

**测试夹具：**
- GDD-A 的依赖关系（Dependencies）部分将"system-B"列为依赖项
- `design/gdd/` 中不存在 system-B 的 GDD
- 所有其他 GDD 保持一致

**输入：** `/consistency-check`

**预期行为：**
1. 技能读取所有 GDD 并检查依赖引用
2. GDD-A 对"system-B"的引用无法解析 —— 不存在对应的 GDD
3. 发现结果表包含：GDD-A vs （缺失） | 依赖缺口（Dependency Gap） | MEDIUM
4. 裁决结果：DEPENDENCY GAP（而非 CONSISTENT 或 CONFLICTS FOUND）

**断言：**
- [ ] 裁决结果为 DEPENDENCY GAP（与 CONSISTENT 和 CONFLICTS FOUND 区分）
- [ ] 发现条目指明 GDD-A 和缺失的 system-B
- [ ] 未解决的依赖引用严重程度为 MEDIUM
- [ ] 技能建议运行 `/design-system system-B` 来创建缺失的 GDD

---

### 用例 4：边界情况 —— 未找到 GDD

**测试夹具：**
- `design/gdd/` 目录为空或不存在

**输入：** `/consistency-check`

**预期行为：**
1. 技能尝试读取 `design/gdd/` 中的文件
2. 未找到 GDD 文件
3. 技能输出错误："在 `design/gdd/` 中未找到 GDD。请先运行 `/design-system` 创建 GDD。"
4. 不生成发现结果表
5. 不发出裁决结果

**断言：**
- [ ] 当未找到 GDD 时，技能输出清晰的错误消息
- [ ] 不生成裁决结果（CONSISTENT / CONFLICTS FOUND / DEPENDENCY GAP）
- [ ] 技能推荐正确的下一步操作（`/design-system`）
- [ ] 技能不崩溃也不生成部分报告

---

### 用例 5：主管关卡 —— 不生成关卡；不读取 review-mode.txt

**测试夹具：**
- `design/gdd/` 包含 ≥2 个 GDD
- `production/session-state/review-mode.txt` 存在，内容为 `full`

**输入：** `/consistency-check`

**预期行为：**
1. 技能读取所有 GDD 并运行一致性扫描
2. 技能不读取 `production/session-state/review-mode.txt`
3. 在任何时候都不生成主管关卡智能体
4. 正常生成发现结果表和裁决结果

**断言：**
- [ ] 不生成任何主管关卡智能体（无 CD-、TD-、PR-、AD- 前缀的关卡）
- [ ] 技能不读取 `production/session-state/review-mode.txt`
- [ ] 输出中不包含"Gate: [GATE-ID]"或关卡跳过条目
- [ ] 审核模式对该技能的行为无影响

---

## 协议合规性（Protocol Compliance）

- [ ] 在生成发现结果表之前读取所有 GDD
- [ ] 在请求写入之前（如需要报告）先完整展示发现结果表
- [ ] 裁决结果恰好为以下之一：CONSISTENT、CONFLICTS FOUND、DEPENDENCY GAP
- [ ] 无主管关卡 —— 不读取 review-mode.txt
- [ ] 报告写入（如请求）需通过"May I write"批准
- [ ] 以与裁决结果相符的下一步交接说明结束

---

## 覆盖范围说明（Coverage Notes）

- 该技能检查 GDD 之间的结构一致性。深层设计理论分析（支柱偏离、主导策略）由 `/review-all-gdds` 处理。
- 公式冲突检测依赖于 GDD 之间一致的公式标记方式 —— 对同一机制的非正式描述可能无法被检测到。
- 冲突严重程度评分标准（HIGH / MEDIUM / LOW）在技能主体中定义，此处不再赘述。
