
# 智能体测试规格：ue-gas-specialist（GAS 专家）

## 智能体概述
- **领域 (Domain)**：游戏能力系统 (Gameplay Ability System, GAS) —— 能力 (UGameplayAbility)、游戏效果 (UGameplayEffect)、属性集 (UAttributeSet)、游戏标签 (Gameplay Tags)、能力任务 (UAbilityTask)、能力规格 (FGameplayAbilitySpec)、GAS 预测和延迟补偿
- **不负责**：能力状态的 UI 显示（ue-umg-specialist）、GAS 内置预测之外的网络复制（ue-replication-specialist）、能力反馈的美术或 VFX（vfx-artist）
- **模型层级 (Model tier)**：Sonnet
- **关卡 ID**：无；跨领域调用转交相应的专家

---

## 静态断言（结构）

- [ ] `description:` 字段存在且具有领域针对性（涉及 GAS、能力、GameplayEffect、AttributeSet）
- [ ] `allowed-tools:` 列表与智能体角色匹配（支持读取/写入 GAS 源文件；无部署或服务器工具）
- [ ] 模型层级为 Sonnet（专家角色的默认值）
- [ ] 智能体定义未声称对 UI 实现或底层网络序列化具有权威

---

## 测试用例

### 用例 1：领域内请求 —— 带冷却的冲刺能力
**输入**："实现一个冲刺能力，使玩家向前移动 500 单位，并具有 1.5 秒的冷却时间。"
**预期行为**：
- 生成 GAS AbilitySpec 结构或大纲：UGameplayAbility 子类，包含 ActivateAbility 逻辑、用于移动的 AbilityTask（例如 AbilityTask_ApplyRootMotionMoveToForce 或自定义根运动），以及用于冷却的 UGameplayEffect
- 冷却 GameplayEffect 使用 Duration 策略，时长 1.5 秒，并使用 GameplayTag 阻止重新激活
- 标签按照层级约定清晰命名（例如 Ability.Dash、Cooldown.Ability.Dash）
- 输出包括能力类大纲和 GameplayEffect 定义

### 用例 2：领域外请求 —— GAS 状态复制
**输入**："如何将玩家的能力冷却状态复制到所有客户端以便 UI 正确更新？"
**预期行为**：
- 说明 GAS 通过 AbilitySystemComponent 的复制模式内置了 AbilitySpec 和 GameplayEffect 的复制支持
- 解释三种 ASC 复制模式（Full、Mixed、Minimal）及其使用时机
- 对于超出 GAS 内置功能的自定义复制需求，明确说明："对于 GAS 数据的自定义网络序列化，请与 ue-replication-specialist 协调"
- 不得在未指明领域边界的情况下尝试编写 GAS 自身系统之外的自定义复制代码

### 用例 3：领域边界 —— 错误的 GameplayTag 层级
**输入**："我们有一个能力应用了一个名为 'Stunned' 的标签，而另一个能力检查的是 'Status.Stunned'。它们不匹配。"
**预期行为**：
- 识别根本原因：标签名称必须精确匹配，或通过 TagContainer 查询使用层级匹配
- 指出命名不一致：'Stunned' 是根级标签；'Status.Stunned' 是 'Status' 下的子标签 —— 它们是不同的标签
- 建议项目标签命名规范：所有状态效果放在 Status.* 下，所有能力放在 Ability.* 下
- 提供修复方案：要么将应用的标签重命名为 'Status.Stunned'，要么更新查询以匹配 'Stunned'
- 说明标签定义应放在何处（DefaultGameplayTags.ini 或 DataTable）

### 用例 4：冲突 —— 两个能力之间的属性集冲突
**输入**："我们的护盾能力和护甲能力都修改了一个 'DefenseValue' 属性。它们以非预期的方式叠加 —— 两者都激活后，防御力远超最大值。"
**预期行为**：
- 将其识别为 GameplayEffect 叠加和幅度计算问题
- 提出使用执行计算 (UGameplayEffectExecutionCalculation) 或修饰符聚合器 (Modifier Aggregators) 来限制组合结果的方案
- 或者建议使用游戏效果叠加策略 (Gameplay Effect Stacking policies)（Aggregate、None）来防止非预期的累加叠加
- 生成具体的解决方案：要么是 Execution Calculation 类大纲，要么是对修饰符操作（Modifier Op）的更改（将 Additive 改为 Override 以设置上限）
- 不得将移除其中一个能力作为解决方案提出

### 用例 5：上下文传递 —— 基于现有属性集进行设计
**输入上下文**：项目已有包含以下属性的 AttributeSet：Health、MaxHealth、Stamina、MaxStamina、Defense、AttackPower。
**输入**："设计一个狂战士能力，在生命值低于 30% 时增加 50% 的攻击力。"
**预期行为**：
- 使用现有的 Health、MaxHealth 和 AttackPower 属性 —— 不发明新属性
- 设计一个在 Health 变化时触发的被动 GameplayAbility（或触发式效果），通过 GameplayEffectExecutionCalculation 或基于属性的幅度检查 Health/MaxHealth 比率
- 使用 Gameplay Cue 或 GameplayTag 跟踪狂战士激活状态
- 引用所提供的 AttributeSet 中的实际属性名称（AttackPower，而非 "Damage" 或 "Strength"）

---

## 协议合规

- [ ] 保持在声明的领域内（GAS：能力、效果、属性、标签、能力任务）
- [ ] 将自定义复制请求重定向给 ue-replication-specialist，并明确解释边界
- [ ] 返回结构化发现（能力大纲 + GameplayEffect 定义），而非模糊描述
- [ ] 主动执行标签层级命名规范
- [ ] 仅使用所提供上下文中的属性和标签；不在未说明的情况下发明新内容

---

## 覆盖范围说明
- 用例 3（标签层级）是细微 Bug 的常见来源；标签命名规范变更时务必测试
- 用例 4 需要了解 GAS 叠加策略 —— 如果 GAS 集成深度发生变化，请验证此用例
- 用例 5 是最重要的上下文感知测试；失败意味着智能体忽略了项目状态
- 无自动运行器；手动审查或通过 `/skill-test` 进行
