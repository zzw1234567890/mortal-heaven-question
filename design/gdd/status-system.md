# 状态效果系统 (Status Effect System)

> **状态 (Status)**：设计中 (In Design)
> **作者 (Author)**：Claude Code + 用户
> **最后更新 (Last Updated)**：2026-07-23
> **最后验证 (Last Verified)**：2026-07-23（设计审查 / design-review）
> **实现的支柱 (Implements Pillar)**：支柱1「自由组牌，策略为王」—— 状态效果的确定性是策略可信的基础

## 概述 (Overview)

状态效果系统负责管理所有战斗中 buff/debuff/特殊状态的完整生命周期——包括创建、叠加、持续时间倒计时、免疫判定和自动移除。它是卡牌效果引擎的下游执行层：效果引擎解析并决定"应该施加什么状态"，状态系统负责"如何施加、如何跟踪、何时移除"。系统维护每个角色身上的活跃状态列表，处理同名状态的叠加/刷新规则，并在每个回合的准备阶段（阶段0）统一倒计时和清理过期状态。

对玩家来说，状态系统是他们"读懂战场"的关键——角色头顶的状态图标告诉他们谁被强化了、谁被削弱了、还剩几回合。状态的准确性和一致性直接影响玩家对游戏规则的信任。

## 玩家幻想 (Player Fantasy)

状态效果系统是规则透明度的守护者。当玩家看到敌方身上有"冰冻"图标时，他们确信这个敌人本回合不能行动；当玩家看到己方角色身上有"中毒"标记和"3"的数字时，他们知道还需要扛3个回合。状态系统传递的核心情感是**确定性**——不是惊喜，不是随机，而是"我看到的规则就是会发生的规则"。这种确定性让玩家敢于做出多回合规划：这一回合挂毒、下一回合引爆毒的combo之所以可信，是因为毒的状态一定会在正确的时机触发和消失。

| 情感层 | 触发场景 | 强度 |
|--------|----------|------|
| **清晰的战场认知** | 扫一眼角色头顶图标就能理解当前场上局势 | 常在——每回合 |
| **规划的信任** | 倒数3回合的debuff在第3回合确实消失了 | 中频——验证信任 |
| **叠加的满足** | 看到同一个buff图标上的层数从1变成3 | 低频——但每次都有正向反馈 |
| **免疫的释然** | 敌方试图施加冰冻但"免疫"文字弹出——你知道你的构筑起作用了 | 低频——高风险场景 |

---

## 详细设计 (Detailed Design)

### 核心规则

#### 1. 状态数据结构

每个活跃状态使用以下强类型结构：

```
StatusEffect {
  id: String                     # 唯一实例标识（UUID或递增ID）
  template_id: String            # 状态模板ID（如 "poison_3", "freeze_1"）
  name: String                   # 显示名称（如 "中毒", "冰冻", "力量强化"）
  type: Enum[增益, 减益, 特殊]    # 状态分类
  duration: int                  # 剩余回合数；-1 = 永久（持续到战斗结束或手动移除）
  applied_turn: int              # 施加时的回合数（用于结算顺序判定）
  value: float                   # 效果数值（已计算后的有效值）
  base_value: float              # 原始基础值（用于刷新时重新计算）
  stack_rule: Enum[独立, 刷新, 叠加上限]  # 同名状态的叠加规则
  max_stacks: int                # stack_rule = 叠加上限 时的最大层数；否则为 0
  current_stacks: int            # 当前层数（≥1）
  source_card_id: String         # 来源卡牌的 template_id
  source_card_instance_id: String # 来源卡牌的 instance_id（用于精确追溯）
  priority: int                  # 同机结算时状态触发效果在效果引擎队列中的子优先级（默认 0，越大越先结算）
                                  # 嵌入规则：效果引擎结算顺序（主动出牌→先发→普通己方→敌方→instance_id）是主排序；
                                  # 当两个状态触发的效果位于效果引擎同一层级时，priority 作为次级决胜键（高于 card_instance_id）。
                                  # 详见 card-effect-engine.md §3「效果结算顺序规则」
  icon_path: String              # UI 图标资源路径
  is_hidden: bool                # true = 不显示在角色头顶（用于内部标记状态）
  is_expired: bool               # 运行时标记：已到期待移除
  metadata: Dictionary           # 扩展数据。标准键：
                                  #   "damage_type": String — 元素属性（"fire"/"ice"/"thunder"/"poison"/"dark"），用于属性免疫判定
                                  #   "trigger_count": int — 条件触发效果的累计触发次数（运行时由效果引擎维护）
                                  #   "stat_affected": String — 受影响的属性名（如 "ATK", "DEF"），用于 get_accumulated_value 过滤
                                  # 非标准键允许但不应依赖——下游系统读取前需 has() 守卫
}
```

#### 2. 状态生命周期

```
创建 → 施加检查 → 施加/合并 → 持续跟踪 → 倒计时/触发 → 到期移除
  │        │                    │              │
  └─ 同名? ─┤                    │              │
            ├─ 免疫? → 拒绝施加   │              │
            ├─ 同名+刷新 → 更新duration    │
            ├─ 同名+叠加上限 → 增加层数/拒绝  │
            └─ 非同or独立 → 新建实例        │
```

#### 3. 叠加规则（由状态系统强制执行）

| 叠加规则 | 行为 | 示例 |
|---------|------|------|
| **独立** | 每次施加创建独立实例，互不干扰 | 不同来源的护盾效果 |
| **刷新** | 同名状态已存在 → 刷新持续时间，数值取新值 | "中毒"重新施加 → 重置为2回合 |
| **叠加上限** | 同名状态已存在 → 层数+1（不超过max_stacks），刷新持续时间 | "力量强化"最多3层 |

**刷新时的持续时间规则**：取 `max(旧剩余回合, 新施加回合数)` —— 防止"刷新→反而更快到期"的反直觉行为。

**叠加 vs 非叠加的判断依据**：按 `template_id` 判断同名（如两张不同卡牌都产生 `template_id = "poison_3"` 的状态，视为同名）。**绝不**使用卡牌名称判断——名称可被本地化修改。

#### 4. 持续时间倒计时

每个己方回合的**阶段0（准备阶段）**执行以下流程：

```
# 阶段0 开始时执行倒计时
for each 角色 in 全场角色:
  if 角色.active_statuses.is_empty():        # 性能优化：跳过无状态的角色
    continue
  for each status in 角色.active_statuses:
    if status.duration > 0:                  # duration=-1 永久状态不递减（跳过内层循环）
      status.duration -= 1
      if status.duration == 0:
        status.is_expired = true

# 阶段0 结算完成后统一移除过期状态
for each 角色 in 全场角色:
  remove_expired_statuses(角色)
```

- 永久状态（duration = -1）不参与倒计时
- 倒计时在阶段0**开始时**执行，但过期移除在阶段0**结算完成后**——确保"回合开始触发"效果仍能看到duration=1的状态
- 同一回合内新施加的状态（阶段2出牌→阶段5敌方行动）duration不减——仅在下一己方回合的阶段0倒计时

#### 5. 免疫判定

施加状态前执行免疫检查：

```
can_apply(target, status_template) → bool:
  if target.has_immunity(status_template.type):
    return false        # 类型免疫（如"免疫所有减益"）
  if target.has_immunity(status_template.template_id):
    return false        # 特定状态免疫（如"免疫冰冻"）
  if target.has_immunity(status_template.metadata.get("damage_type")):
    return false        # 属性免疫（如"免疫火系伤害"）
  return true
```

免疫判定不消耗施加来源（卡牌仍正常进弃牌堆），但状态不创建。

#### 6. 接口规范（对效果引擎暴露）

```
# ---- 写入接口 ----

apply_status(target_id: String, template: StatusTemplate) → ApplyResult
  # 施加状态到目标。
  # ApplyResult = {applied: bool, status_id: String, reason: String}
  # reason: "new" | "refreshed" | "stacked" | "immune" | "max_stacks"

remove_status(status_id: String) → bool
  # 移除指定状态实例

remove_statuses_by_source(target_id: String, source_card_instance_id: String) → int
  # 批量移除指定来源卡牌产生的所有状态，返回移除数量

clear_all_statuses(target_id: String) → int
  # 清除目标身上所有非永久状态（如丹药复活后清debuff）

suspend_statuses_by_source(source_card_instance_id: String) → [String]
  # 暂挂来源卡牌的所有状态效果（角色离场/阵亡时使用），返回被暂挂的状态ID列表
  # ⚠ 作用域限制：仅处理非绑定来源的状态（敌方debuff、丹药buff、卡牌效果等）。
  #    绑定来源的效果由 binding-system.md 独立处理（永久移除，不可恢复）。
  #    见 binding-system.md §7「角色阵亡与涅槃丹复活」。

restore_statuses(status_ids: [String]) → int
  # 恢复暂挂的状态（角色复活时使用），返回恢复数量
  # ⚠ 作用域限制：仅恢复非绑定来源的暂挂状态。绑定来源的状态在阵亡时已被永久移除，不可恢复。
  #    涅槃丹复活后角色为空载状态（见 binding-system.md §7）。

# ---- 读取接口 ----

get_active_statuses(target_id: String) → Array[StatusEffect]
  # 获取目标的所有活跃状态

get_statuses_by_type(target_id: String, type: Enum) → Array[StatusEffect]
  # 按类型过滤

has_status(target_id: String, template_id: String) → bool
  # 检查目标是否有指定模板的状态

get_accumulated_value(target_id: String, stat_name: String) → float
  # 查询所有状态对指定属性的累计修正值（用于属性计算）
```

#### 7. 信号广播

状态系统维护自己的 Godot 信号总线（独立于 GSM 的信号系统——状态事件数量多、频率高，通过专用通道避免 GSM 信号表膨胀）。以下信号由状态系统 Autoload 单例直接发射：

| 事件 | 触发时机 | 载荷 |
|------|---------|------|
| `status_applied` | 状态成功施加到目标 | `{target_id, status_id, template_id, stacks, reason}` |
| `status_removed` | 状态被移除（自然过期/手动移除/溢出驱逐） | `{target_id, status_id, template_id, reason}` |
| `status_updated` | 状态的层数/数值/持续时间变更 | `{target_id, status_id, changes: {stacks, value, duration}}` |
| `status_immunity_blocked` | 施加被免疫阻挡 | `{target_id, template_id, immunity_type}` |

**路由规则：** 战斗 UI 系统（角色头顶图标）和 HUD 系统（tooltip 详情）直接订阅状态系统信号。GSM 不转发这些信号——但状态导致的属性变更最终会通过 `batch_updated`（战斗结算时）或属性查询接口反映到 GSM 数据层。

#### 8. 属性修正的累计计算

当多个状态影响同一属性时（如两个不同的buff都提供ATK加成）：

```
get_accumulated_value(target_id, "ATK") → float:
  total = 0
  for status in get_active_statuses(target_id):
    # 独立 和 叠加上限 类型
    if status.type == 增益 or 减益:
      if status affects "ATK":
        if not status.is_hidden:     # 隐藏状态不计入可见属性（对齐 §2 公式）
          total += status.value × status.current_stacks
  return total
```

加法叠加——不做额外乘法。本命加成（×1.5）在效果引擎计算 `status.value` 时已体现（`base_value × 1.5 → value`），状态系统只负责加总。

### 状态与转换

```
状态实例生命周期：
  创建（apply_status 调用）
    → 活跃（active，参与属性计算和回合结算）
    → 暂挂（suspended，角色阵亡时触发，效果暂停但不销毁）
    → 恢复（restore，角色复活时触发，效果重新生效）
    → 移除（removed，duration归零、手动移除、或来源解除）
```

---

## 公式 (Formulas)

### 1. 叠加后的有效数值

```
effective_value = base_value × current_stacks
```

| 变量 | 类型 | 范围 | 描述 |
|------|------|------|------|
| base_value | float | [0, ∞) | 单层的效果数值 |
| current_stacks | int | [1, max_stacks] | 当前层数 |
| effective_value | float | [0, ∞) | 叠加后的总数值 |

### 2. 属性累计修正

```
total_stat_modifier(character, stat) = sum(
  status.value × status.current_stacks
  for status in character.active_statuses
  where status affects stat
    and not status.is_expired
    and not status.is_hidden    # 隐藏状态不计入可见属性
)
```

### 3. 施加结果判定

```
apply_result = {
  if target.immune_to(template):           → IMMUNE
  elif existing = find_same(template_id):   # 同名状态已存在
    if existing.stack_rule == 刷新:          → REFRESHED (duration = max(old, new), value = new)
    elif existing.stack_rule == 叠加上限:
      if existing.current_stacks < existing.max_stacks:
                                           → STACKED (stacks += 1, duration refreshed)
      else:                                → MAX_STACKS (rejected)
    elif existing.stack_rule == 独立:        → NEW (create independent instance)
  else:                                    → NEW
}
```

---

## 边界情况 (Edge Cases)

- **同名状态的不同来源**：两个不同的卡牌产生相同的 `template_id = "poison_3"` → 视为同名，按叠加规则处理。来源卡牌ID仅用于追溯和 `remove_statuses_by_source`
- **最大层数溢出**：层数已达 `max_stacks` → 施加返回 `MAX_STACKS` 拒绝结果，不刷新持续时间，不消耗施加来源
- **角色阵亡时的状态处理**：角色阵亡 → 对于**非绑定来源的状态**（如敌方施加的debuff、丹药卡产生的buff），调用 `suspend_statuses_by_source()` 暂挂，涅槃丹复活后可通过 `restore_statuses()` 恢复。**绑定来源的状态**（功法/法宝绑定产生的效果）由 binding-system.md §7 独立处理：永久移除，不可恢复。来自阵亡角色施加给其他角色的状态不受影响。
- **永久状态（duration = -1）与移除**：永久状态不被倒计时自动移除，但可被 `remove_status` / `clear_all_statuses` 手动移除。"直接移除状态"的卡牌效果可以移除永久状态
- **清除效果的范围**：`clear_all_statuses(target)` 移除所有 `duration ≠ -1` 的状态。永久状态不受影响（除非效果明确指定"包括永久状态"）
- **状态在结算中途被移除**：如果状态A在阶段0触发效果 → 该效果施加了状态B → 状态B在当前阶段0不参与倒计时（同回合施加的状态不从当前回合开始计时）
- **叠加 vs 刷新的优先级**：同名判定优先于叠加规则判定。先找到同名状态 → 再根据其叠加规则决定行为
- **免疫的多层检查顺序**：类型免疫（减益免疫）→ 模板免疫（冰冻免疫）→ 属性免疫（火系免疫）。第一层通过即拒绝，短路求值
- **移除不存在的状态**：`remove_status(nonexistent_id)` 返回 false，日志 DEBUG 级别，不报错
- **暂挂状态在暂挂期间来源卡牌被移除**：暂挂状态的 `source_card_instance_id` 引用保持，恢复时如果来源卡牌仍在游戏中 → 正常恢复；如果来源卡牌已不可用 → 状态自动移除，日志 WARN
- **角色在暂挂期间永久死亡**：角色阵亡后状态进入暂挂（suspend），若在暂挂期间角色永久死亡（无法复活——如涅槃丹耗尽）→ 所有该角色的暂挂状态被销毁（不触发 status_removed 事件——无目标可通知）。日志 DEBUG 级别记录销毁数量。此清理防止暂挂状态泄漏积累。注：渡劫失败中的角色阵亡走标准死亡规则（标记不可用但可复活），不是永久死亡
- **多层叠加状态的部分移除**：如果状态有3层，效果"移除1层" → `current_stacks` 减1。层数归0 → 状态完全移除。如果效果"完全移除此状态" → 无视层数直接移除
- **状态溢出驱逐**：当角色活跃状态数达到 `max_active_statuses_per_character`（调优参数，默认 20）时，新状态施加前自动驱逐最旧的非永久状态。最旧判定规则：按 `applied_turn` 升序（先施加的先驱逐）；若多个状态在同一回合施加 → 按 `id` 字典序决胜。永久状态（duration=-1）和隐藏状态（is_hidden=true）不受驱逐影响。被驱逐的状态触发 `status_removed` 事件（reason="overflow"）
- **remove_statuses_by_source 零匹配**：`remove_statuses_by_source(target_id, source_card_instance_id)` 在指定来源未产生任何状态时返回 0——这不是错误，不记录日志。调用方通过返回值判断是否有状态被移除

---

## 依赖关系 (Dependencies)

| 依赖系统 | 性质 | 说明 |
|----------|------|------|
| **游戏状态管理器** | 硬依赖 | 状态数据存储在 GSM 的 `battle.temp_effects` 域；状态变更通过 GSM 信号广播 |
| **卡牌系统** | 软依赖 | 验证 `source_card_id` 的有效性（引用完整性） |

### 下游依赖者

| 下游系统 | 依赖性质 | 说明 |
|----------|---------|------|
| **卡牌效果引擎** | 硬依赖 | 效果解析后通过状态系统接口施加/移除状态 |
| **战斗系统** | 硬依赖 | 阶段0 触发倒计时；战斗结束时清理所有状态 |
| **绑定系统** | 软依赖 | 角色阵亡时绑定来源的状态由绑定系统独立处理（永久移除），状态系统仅处理非绑定来源的状态暂挂/恢复。见 binding-system.md §7 |
| **AI系统** | 软依赖 | 查询目标身上的状态以评估技能价值 |
| **战斗UI系统** | 软依赖 | 订阅状态变更信号更新角色头顶图标 |
| **HUD系统** | 软依赖 | 显示角色状态的详细tooltip信息 |

---

## 调优参数 (Tuning Knobs)

| 参数 | 默认值 | 安全范围 | 说明 |
|------|:-----:|:--------:|------|
| 每角色最大活跃状态数 | 20 | 10-50 | 防止状态爆炸，超过上限时最旧的非永久状态被替换 |
| 倒计时时机 | 阶段0开始 | — | 持续时间在准备阶段开始时-1 |
| 过期移除时机 | 阶段0结算后 | — | 过期状态在准备阶段结束时统一移除 |
| 状态图标单角色最大显示数 | 6 | 3-10 | 超过此数的隐藏状态折叠为"... +N" |
| 状态日志级别 | WARN | DEBUG/WARN/ERROR | 免疫阻挡/施加失败的最低日志级别 |

---

## 验收标准 (Acceptance Criteria)

- **GIVEN** 目标无任何状态，**WHEN** 施加 `template_id="poison_3"` 的状态（duration=3, stack_rule=刷新），**THEN** 目标获得该状态，`current_stacks=1`，`duration=3`
- **GIVEN** 目标已有 `poison_3` 状态（duration=2, stack_rule=刷新），**WHEN** 再次施加同名状态（duration=3），**THEN** 原状态的 duration 刷新为 `max(2,3)=3`，不创建新实例
- **GIVEN** 目标有 `strength_up` 状态（stacks=2, max_stacks=3, stack_rule=叠加上限），**WHEN** 再次施加同名状态，**THEN** stacs 变为 3，duration 刷新
- **GIVEN** 目标有 `strength_up` 状态（stacks=3, max_stacks=3），**WHEN** 再次施加同名状态，**THEN** 施加被拒绝，返回 `MAX_STACKS`，状态不变
- **GIVEN** 目标有"免疫减益"的免役效果，**WHEN** 施加 type=减益 的状态，**THEN** 施加被拒绝，返回 `IMMUNE`，不创建状态实例
- **GIVEN** 目标有 duration=3 的状态，**WHEN** 己方回合阶段0执行，**THEN** duration-1 变为 2；再经2个己方回合阶段0后 duration=0 → 状态在阶段0结算后自动移除
- **GIVEN** 目标有 duration=-1 的永久状态，**WHEN** 己方回合阶段0执行，**THEN** duration 保持 -1，状态不被自动移除
- **GIVEN** 目标身上有3个活跃状态，**WHEN** 调用 `get_active_statuses(target)`，**THEN** 返回含全部3个状态的数组，每个状态包含完整字段
- **GIVEN** 目标有 ATK+2 和 ATK+3 两个不同状态，**WHEN** 调用 `get_accumulated_value(target, "ATK")`，**THEN** 返回 5.0
- **GIVEN** 目标有同名堆叠状态（stacks=3, value=2），**WHEN** 调用 `get_accumulated_value(target, "ATK")`，**THEN** 返回 6.0（3层 × 2）
- **GIVEN** 角色阵亡，**WHEN** 调用 `suspend_statuses_by_source(dead_char_card_id)`，**THEN** 该角色产生的所有状态被暂挂，其施加给其他角色的buff立即失效
- **GIVEN** 暂挂的状态ID列表，**WHEN** 角色复活并调用 `restore_statuses(ids)`，**THEN** 状态恢复生效，duration 保持暂挂前的剩余值
- **GIVEN** 各目标有多个状态，**WHEN** 调用 `remove_status_by_source(source_card_instance_id)`，**THEN** 仅移除来源为该卡牌实例的状态，其他来源的同名状态不受影响

---

## 待解决问题 (Open Questions)

| # | 问题 | 影响 | 建议解决时间 |
|---|------|------|------------|
| 1 | 状态系统在 Godot 中的实现形态——自定 `RefCounted` 类 vs Resource？GDT 建议运行时使用 RefCunted + 强类型类（见 card-effect-egnine 审查） | 实现架构 | 架构阶段 |
| 2 | 叠加上限的 N 值由谁定义？卡牌模板中的 `effect_value` 还是状态模板数据表中的 `max_stacks`？初步建议：状态模板数据表 | 数据管线 | 卡牌数据设计时 |
| 3 | ~~隐藏状态（is_hidden=true）是否应该完全不影响 `get_accumulated_value`？还是仅不显示但计入数值？~~ **✅ 已解决 (2026-07-23)**：`is_hidden=true` 的状态不计入 `get_accumulated_value`——§2 公式已明确排除（`and not status.is_hidden`）。隐藏状态仅内部使用，不影响任何属性计算。 | 内部逻辑标记 | — |

---

## 视觉/音频需求 (Visual/Audio Requirements)

状态系统本身无视觉输出，但为战斗UI提供数据支撑：
- 施加新状态 → 角色头顶图标闪现（0.2s，见 card-effect-engine.md §视觉/音频需求）
- 层数变更 → 图标上的数字跳变
- 状态到期移除 → 图标淡出（0.15s）
- 免疫阻挡 → "免疫"文字弹出（0.3s）