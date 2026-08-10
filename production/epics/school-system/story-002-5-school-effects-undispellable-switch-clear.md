# Story 002: 5 流派增益公式 + 不可驱散约束 + 流派切换清空

> **Epic**: school-system
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-10

## Context

**GDD**: `design/gdd/school-system.md`
**Requirement**: `TR-school-002`（待 `/architecture-review` 注册——5 流派增益效果数值 + 系统级不可驱散 + 切换清空）

**ADR Governing Implementation**: ADR-0025（流派系统——增益定义在 SCHOOL_LIBRARY + CombatSystem 执行 + 系统级效果不可驱散）
**ADR Decision Summary**: 5 流派的增益效果数值在 `SCHOOL_LIBRARY[school_id].effects` 中定义，CombatSystem 在战斗开始时读取并注册到战斗上下文（不经过 StatusEffectSystem——流派增益是系统级效果，不可被敌方驱散，不占用 buff 槽位）。流派切换时旧增益立即清空，新增益应用——同一时刻唯一流派。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 增益效果为纯数据 Dictionary，CombatSystem 读取后应用。本 Story 聚焦数值正确性 + 不可驱散约束 + 切换清空——增益落地执行属战斗 Epic。

**Control Manifest Rules (Core 层)**:
- **Required**: 增益数值在 `SCHOOL_LIBRARY` const 中定义——单一真理来源
- **Required**: 流派增益是系统级效果——不经过 StatusEffectSystem，不可被 `remove_status` 驱散
- **Required**: 流派切换时旧增益立即清空——无重叠期
- **Forbidden**: 增益数值硬编码在战斗代码——必须从 SCHOOL_LIBRARY 读取
- **Forbidden**: 流派增益占用 StatusEffect 20 槽位——系统级效果独立于 buff 系统

---

## Acceptance Criteria

*From ADR-0025 §解决的 GDD 需求 + GDD school-system.md §验收标准 §调优参数:*

- [ ] **AC-001**: 正道发育流 effects 含——regen(value=2, trigger=turn_end) + damage_reduce(value=1, floor=1) + formation_ease(value=-1)
- [ ] **AC-002**: 魔道快攻流 effects 含——attack_boost(value=2, trigger=first_3_turns) + draw_on_kill(value=1) + cost_boost(turn_1, value=1)
- [ ] **AC-003**: 正邪混合流 effects 含——stat_boost(target=mixed, atk=1, def=1) + cost_discount(chance=0.3, value=1) + formation_ease(value=-1)
- [ ] **AC-004**: 归墟真灵流 effects 含——stat_boost(target=spirit, hp=3, atk=1) + immune_debuff(debuffs=[fear, confusion]) + aura_hp(value=1, per_unit=spirit)
- [ ] **AC-005**: 百艺炼丹流 effects 含——pill_boost(value=0.2) + cost_reduce(target=alchemy_material, value=1, floor=1) + action_recover(per_pills=3, value=1, max_triggers=3) + pill_breakthrough(chance=0.1)
- [ ] **AC-006**: 正道 damage_reduce floor=1——伤害最低 1，不归零
- [ ] **AC-007**: 魔道 attack_boost 仅前 3 回合生效——第 4 回合失效
- [ ] **AC-008**: 归墟 aura_hp 叠加——3 归墟角色在场 → 全体友方 +3HP（每人 +1×3）
- [ ] **AC-009**: 百艺 pill_boost——回复 100HP 丹药实际回复 120HP（+20%）
- [ ] **AC-010**: 百艺 action_recover——每 3 张丹药回 1AP，每局最多触发 3 次
- [ ] **AC-011**: 流派增益不可被 `StatusEffectSystem.remove_status` 移除——系统级效果独立于 buff 系统
- [ ] **AC-012**: 流派增益不占用 StatusEffect 20 槽位
- [ ] **AC-013**: 流派切换时旧增益立即清空——从 A 切换到 B，A 的增益不再生效
- [ ] **AC-014**: 切换无重叠期——同一时刻仅一个流派增益生效
- [ ] **AC-015**: `school_changed` 信号在切换时发射（old_id, new_id）
- [ ] **AC-016**: 魔道首回合 +1 费与魔修遗孤天赋叠加——基础 +1（天赋）+1（流派）= +2
- [ ] **AC-017**: 流派增益在战斗开始时锁定——战中角色阵亡导致阵营条件不满足时增益仍生效（战后重新检测）
- [ ] **AC-018**: 无流派激活时无增益——`detect()` 返回 `&""` 时 CombatSystem 不注册任何流派增益

---

## Implementation Notes

*Derived from ADR-0025 §解决的 GDD 需求 + GDD school-system.md §2 §5 §调优参数:*

1. **effects 数值来源**: 全部从 `SCHOOL_LIBRARY[id].effects` const 读取——本 Story 完善数值定义，不新增代码逻辑（Story 001 已建立结构）
2. **正道 damage_reduce floor**: 在 effect entry 中声明 `floor: 1`——CombatSystem 应用时 `max(1, damage - value)`
3. **魔道 first_3_turns trigger**: effect entry 声明 `trigger: "first_3_turns"` + `turn_limit: 3`——CombatSystem 在 turn ≤ 3 时应用，turn ≥ 4 失效
4. **归墟 aura_hp**: effect entry 声明 `type: "aura_hp", value: 1, per_unit: "spirit"`——CombatSystem 计算 `count_spirit_on_field × value` 加到全体友方 HP
5. **百艺 action_recover**: effect entry 声明 `type: "action_recover", per_pills: 3, value: 1, max_triggers: 3`——CombatSystem 计数丹药使用次数，每 3 次回 1AP，封顶 3 次
6. **不可驱散约束**: 流派增益不注册到 StatusEffectSystem._instances——CombatSystem 在战斗上下文中独立持有；`StatusEffectSystem.remove_status` 无法触及
7. **切换清空**: CombatSystem 在 `school_changed` 信号触发时清除旧流派增益注册 → 应用新流派增益（本 Story 验证约束，落地执行属战斗 Epic）
8. **school_changed 发射**: 由 CombatSystem/DeckEdit 在 `detect()` 返回值与当前 `GSM.battle.active_school` 不同时发射——SchoolSystem 本身不发射（纯计算无副作用，Story 001 已声明信号）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: SCHOOL_LIBRARY 结构 + 纯查询/检测接口——已实现
- **CombatSystem 增益落地执行**: 伤害修正/回复/抽牌/费用折扣的战斗结算 ——战斗 Epic（ADR-0008）职责
- **天赋系统联动**: 魔修遗孤天赋的 +1 费用 ——身份/天赋 Epic 职责（本 Story 仅验证可叠加约束）
- **流派 UI 提示**: 激活/切换的视觉反馈 ——战斗 UI Epic 职责

---

## QA Test Cases

*From QA 计划 qa-plan-sprint-3-2026-08-10.md §Story 3-8 + GDD §调优参数:*

- **AC-001**: 正道发育流 effects 数值
  - Given: SCHOOL_LIBRARY 已加载
  - When: `ss.get_school_effects(&"righteous_dev")`
  - Then: 含 regen(value=2, trigger=turn_end) + damage_reduce(value=1, floor=1) + formation_ease(value=-1)
  - Edge cases: 3 个 effect entry

- **AC-002**: 魔道快攻流 effects 数值
  - Given: SCHOOL_LIBRARY 已加载
  - When: `ss.get_school_effects(&"demonic_aggro")`
  - Then: 含 attack_boost(value=2, trigger=first_3_turns, turn_limit=3) + draw_on_kill(value=1) + cost_boost(turn_1, value=1)
  - Edge cases: 3 个 effect entry

- **AC-003**: 正邪混合流 effects 数值
  - Given: SCHOOL_LIBRARY 已加载
  - When: `ss.get_school_effects(&"mixed_alignment")`
  - Then: 含 stat_boost(target=mixed, atk=1, def=1) + cost_discount(chance=0.3, value=1) + formation_ease(value=-1)
  - Edge cases: 3 个 effect entry

- **AC-004**: 归墟真灵流 effects 数值
  - Given: SCHOOL_LIBRARY 已加载
  - When: `ss.get_school_effects(&"spirit_realm_beast")`
  - Then: 含 stat_boost(target=spirit, hp=3, atk=1) + immune_debuff(debuffs=[fear, confusion]) + aura_hp(value=1, per_unit=spirit)
  - Edge cases: 3 个 effect entry

- **AC-005**: 百艺炼丹流 effects 数值
  - Given: SCHOOL_LIBRARY 已加载
  - When: `ss.get_school_effects(&"alchemy_mastery")`
  - Then: 含 pill_boost(value=0.2) + cost_reduce(target=alchemy_material, value=1, floor=1) + action_recover(per_pills=3, value=1, max_triggers=3) + pill_breakthrough(chance=0.1)
  - Edge cases: 4 个 effect entry

- **AC-006**: 正道 damage_reduce floor=1
  - Given: 正道发育流激活 + 正道角色受 1 点伤害
  - When: CombatSystem 应用 damage_reduce(value=1, floor=1)
  - Then: 实际伤害 = max(1, 1 - 1) = 1（不归零）
  - Edge cases: 受 3 点伤害 → max(1, 3-1) = 2

- **AC-007**: 魔道 attack_boost 前 3 回合失效
  - Given: 魔道快攻流激活 + turn=4
  - When: CombatSystem 检查 attack_boost(trigger=first_3_turns, turn_limit=3)
  - Then: turn=1/2/3 时 ATK+2 生效，turn=4 时失效
  - Edge cases: turn_limit=3 边界

- **AC-008**: 归墟 aura_hp 叠加
  - Given: 归墟真灵流激活 + 3 归墟角色在场
  - When: CombatSystem 计算 aura_hp(value=1, per_unit=spirit)
  - Then: 全体友方 +3HP（3 × value=1）
  - Edge cases: 2 归墟 → +2HP

- **AC-009**: 百艺 pill_boost 加成
  - Given: 百艺炼丹流激活 + 使用回复 100HP 丹药
  - When: CombatSystem 应用 pill_boost(value=0.2)
  - Then: 实际回复 = 100 × (1 + 0.2) = 120HP
  - Edge cases: value=0.2 = +20%

- **AC-010**: 百艺 action_recover 封顶
  - Given: 百艺炼丹流激活 + 使用 9 张丹药
  - When: CombatSystem 计算 action_recover(per_pills=3, max_triggers=3)
  - Then: 回 3AP（9/3=3 次，封顶 3 次）
  - Edge cases: 使用 12 张丹药仍回 3AP（max_triggers=3）

- **AC-011**: 流派增益不可被 remove_status 移除
  - Given: 正道发育流激活 + 流派增益已注册到战斗上下文
  - When: `StatusEffectSystem.remove_status(any_status_id)`
  - Then: 流派增益仍生效（不注册在 StatusEffectSystem._instances）
  - Edge cases: 系统级效果独立于 buff 系统

- **AC-012**: 流派增益不占用 20 槽位
  - Given: 正道发育流激活 + 3 个正道 buff
  - When: `StatusEffectSystem.get_active_count(target_id)`
  - Then: 不含流派增益——20 槽位仅计 StatusEffect 实例
  - Edge cases: 流派增益独立计数

- **AC-013**: 流派切换旧增益清空
  - Given: 当前激活正道发育流
  - When: detect() 返回魔道快攻流 + school_changed 发射
  - Then: 正道 regen/damage_reduce/formation_ease 立即失效
  - Edge cases: 无重叠期

- **AC-014**: 切换无重叠期
  - Given: school_changed(old=righteous_dev, new=demonic_aggro)
  - When: CombatSystem 处理切换
  - Then: 同一时刻仅魔道增益生效，正道增益已清空
  - Edge cases: 原子切换

- **AC-015**: school_changed 信号发射
  - Given: 监听 school_changed
  - When: detect() 返回值与当前 active_school 不同
  - Then: 发射 school_changed(old_id, new_id)
  - Edge cases: 由调用方（CombatSystem）发射，SchoolSystem 仅声明

- **AC-016**: 魔道首回合 +1 费与天赋叠加
  - Given: 魔修遗孤天赋（+1 费）+ 魔道快攻流激活（+1 费）
  - When: 战斗首回合费用上限计算
  - Then: 基础 +1（天赋）+1（流派）= +2
  - Edge cases: 两个来源独立叠加

- **AC-017**: 战斗中增益锁定
  - Given: 战斗开始时正道发育流激活（3 正道角色）
  - When: 战中 1 正道角色阵亡（剩 2 正道，不满足条件）
  - Then: 增益仍生效（战中锁定，战后重新检测）
  - Edge cases: GDD §边缘情况明确要求

- **AC-018**: 无流派无增益
  - Given: detect() 返回 `&""`（无流派）
  - When: CombatSystem 查询流派增益
  - Then: 不注册任何流派增益——无效果应用
  - Edge cases: 纯中立无惩罚

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/school_system/test_school_effects.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（SCHOOL_LIBRARY 结构 + get_school_effects 接口）
- Unlocks: 战斗 Epic（CombatSystem 流派增益落地执行 + 切换清空）；天赋 Epic（魔修遗孤 +1 费叠加联动）
