# Story 004: 难度缩放 + register_preconfigured_bindings

> **Epic**: AI 系统（敌方 AI） (ai-system)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**:

## Context

**GDD**: `design/gdd/ai-system.md`
**Requirement**: `TR-ai-003`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0017（AI 系统 — Feature 层独立 Autoload + 效果引擎统一路径 + Boss 内部阶段状态机）
**ADR Decision Summary**: 难度缩放公式 `scale = 1.0 + (player_realm - enemy_realm) × 0.3`，仅在玩家境界高于敌人基准时应用（提升 HP/ATK/DEF），在 `create_enemy_roster()` 时通过 `RealmSystem.get_realm_property()` 获取玩家境界。精英/Boss 预配置绑定在 `battle_start()` 时调用 `BindingManager.register_binding(character_id, card_id, is_enemy=true)` 注册。

**Engine**: Godot 4.6 | **Risk**: LOW（整数/浮点缩放计算 + BindingManager 直接调用——4.x 成熟 API）
**Engine Notes**: 不依赖 4.4+ 新特性。缩放为纯函数计算，`round()` 取整。绑定注册单一路径（ADR-0013 §接口契约已稳定）。

**Control Manifest Rules (Feature 层)**:
- **Required**: 难度缩放 `scale = 1.0 + gap × 0.3`——在 `battle_start()` / `create_enemy_roster()` 时应用（来源：ADR-0017）
- **Required**: 所有境界属性查询必须通过 `RealmSystem.get_realm_property(level, key)`（来源：ADR-0010）
- **Required**: 精英/Boss 预配置绑定在 `battle_start()` 时通过 BindingManager 注册（来源：ADR-0017）
- **Forbidden**: 绝不在消费者系统中硬编码境界数值——始终查询 RealmSystem（来源：ADR-0010）
- **Forbidden**: 绝不绕过 `BindingManager.register_binding()` 直接操纵绑定——单一路径（来源：ADR-0013, ADR-0017）

---

## Acceptance Criteria

*From ADR-0017 §关键接口 + GDD ai-system.md §6（敌方绑定与阵法）+ §9（难度缩放）+ §公式 5 + §边缘情况 + §验收标准:*

- [ ] **AC-001**: 难度缩放公式 `scale = 1.0 + (player_realm - enemy_realm) × 0.3`——玩家境界高于敌人基准时应用
- [ ] **AC-002**: `player_realm > enemy_realm` → `max_hp = round(base_hp × scale)`、`attack = round(base_attack × scale)`、`defense = round(base_defense × scale)`
- [ ] **AC-003**: `player_realm <= enemy_realm` → 不缩放（返回基础值，境界压制规则由战斗系统处理）
- [ ] **AC-004**: 通过 `RealmSystem.get_realm_property()` 获取玩家境界——不硬编码境界数值
- [ ] **AC-005**: 缩放应用时机在 `create_enemy_roster()` 时（创建实例后、分配阵位前或后按 ADR 顺序）
- [ ] **AC-006**: `register_preconfigured_bindings(enemy)` 遍历 `preconfigured_bindings` 调用 `BindingManager.register_binding(character_id, card_id, is_enemy=true)`
- [ ] **AC-007**: 普通敌人无预配置绑定（`preconfigured_bindings` 为空，不调用注册）
- [ ] **AC-008**: 精英敌人战前配置 → 预配置绑定已注册到 BindingManager
- [ ] **AC-009**: Boss 敌人战前配置 → 预配置绑定已注册到 BindingManager
- [ ] **AC-010**: 敌方绑定不消耗费用、不占用出牌机会（绑定为预配置，非战斗中打出）
- [ ] **AC-011**: 敌方角色阵亡 → 绑定随角色阵亡直接移除（不走玩家绑定链销毁流程）

---

## Implementation Notes

*Derived from ADR-0017 §关键接口 + GDD ai-system.md §6/§9 + §公式 5:*

1. **难度缩放实现**（ADR §关键接口 `_apply_difficulty_scaling`）：
   ```gdscript
   func _apply_difficulty_scaling(template: EnemyTemplate, player_realm: int) -> Dictionary:
       if player_realm <= template.realm:
           return {"max_hp": template.base_hp, "attack": template.base_attack, "defense": template.base_defense}
       var scale: float = 1.0 + (player_realm - template.realm) * 0.3
       return {
           "max_hp": round(template.base_hp * scale),
           "attack": round(template.base_attack * scale),
           "defense": round(template.base_defense * scale),
       }
   ```
2. **境界来源**：`player_realm` 由调用方从 `RealmSystem.get_realm_property()` 查询后传入（或 AI 内部只读查询 `GSM.player.realm_level` 再通过 RealmSystem 查询属性）。绝不硬编码境界数值
3. **缩放应用时机**：在 `create_enemy_roster()` 内——EnemyFactory 创建实例后，将 `_apply_difficulty_scaling` 返回值写入实例 max_hp/attack/defense
4. **预配置绑定注册**（ADR §关键接口 `register_preconfigured_bindings`）：
   ```gdscript
   func register_preconfigured_bindings(enemy: EnemyBattleState) -> void:
       for binding_card_id in enemy.template.preconfigured_bindings:
           BindingManager.register_binding(character_id, binding_card_id, is_enemy=true)
   ```
   在 `create_enemy_roster()` 中自动调用（仅精英/Boss，普通敌人 preconfigured_bindings 为空）
5. **阵亡移除**：敌方角色阵亡 → 绑定随角色直接移除（CombatSystem 通知 AI 后清理），不走玩家"洗回牌库"流程——这是简化设计（GDD §6）
6. **绑定不消耗费用/不占出牌机会**：预配置绑定在战前注册，战斗中自动生效，无需 AI 决策消耗行动
7. **测试模式**：缩放公式为纯函数，脚本内直接单测；绑定注册需 mock BindingManager（`register_binding` 调用验证）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: EnemyFactory 创建实例 + 阵位分配——本 Story 在 create_enemy_roster 内追加缩放 + 绑定注册两步
- **Story 002**: execute_turn 决策主循环——本 Story 不涉及每回合决策
- **Story 003**: BossPhaseMgr 阶段转换——本 Story 不涉及阶段
- **BindingManager 内部实现**: register_binding 的注册表管理、本命绑定判定——绑定 Epic（ADR-0013）职责
- **阵法注册**: `register_preconfigured_formations()` 预配置阵法部署——阵法系统（ADR-0024，尚无 AI 侧 ADR 前向引用）职责，本 Story 只处理绑定不处理阵法
- **境界压制规则**: delta=1 压制 20%、delta>=2 压制 50%——RealmSystem（ADR-0010）/战斗系统职责，非本 Story

---

## QA Test Cases

*From ADR-0017 §验证标准 + GDD ai-system.md §边缘情况 + §验收标准:*

- **AC-001**: 缩放公式
  - Given: player_realm=3, enemy_realm=1
  - When: `_apply_difficulty_scaling()`
  - Then: scale = 1.0 + (3-1)×0.3 = 1.6
  - Edge cases: gap=2 → ×1.6；gap=3 → ×1.9

- **AC-002**: 缩放应用
  - Given: base_hp=100, base_attack=20, base_defense=10, player_realm=3, enemy_realm=1
  - When: `_apply_difficulty_scaling()`
  - Then: max_hp=160, attack=32, defense=16（round(×1.6)）
  - Edge cases: round 取整规则（四舍五入）

- **AC-003**: 不缩放
  - Given: player_realm=1, enemy_realm=2（或相等）
  - When: `_apply_difficulty_scaling()`
  - Then: 返回基础值（max_hp=base_hp 等，scale 不应用）
  - Edge cases: player_realm == enemy_realm → 不缩放；境界压制由战斗系统处理

- **AC-004**: 境界来源 RealmSystem
  - Given: RealmSystem 提供 `get_realm_property(level, key)`
  - When: AI 获取玩家境界
  - Then: 通过 RealmSystem 查询（不硬编码）
  - Edge cases: 直接读 GSM.player.realm_level 作为 level 参数，属性值经 RealmSystem

- **AC-005**: 缩放时机
  - Given: create_enemy_roster() 调用
  - When: 创建实例后
  - Then: 实例 max_hp/attack/defense 已按缩放值写入
  - Edge cases: 缩放发生在阵位分配前（不影响分配逻辑）

- **AC-006**: register_preconfigured_bindings 调用
  - Given: 敌人模板 preconfigured_bindings=["card_001", "card_002"]
  - When: `register_preconfigured_bindings(enemy)`
  - Then: BindingManager.register_binding 被调用 2 次，is_enemy=true
  - Edge cases: character_id 为敌方角色 ID，card_id 为模板 ID

- **AC-007**: 普通敌人无绑定
  - Given: 普通敌人 preconfigured_bindings 为空
  - When: create_enemy_roster()
  - Then: 不调用 register_binding
  - Edge cases: 空数组遍历零次

- **AC-008**: 精英预配置绑定注册
  - Given: 精英敌人 preconfigured_bindings 非空
  - When: create_enemy_roster()
  - Then: 绑定已注册到 BindingManager（is_enemy=true）
  - Edge cases: 精英 formation_limit=1 与绑定并存（formation_limit 属 Story 001）

- **AC-009**: Boss 预配置绑定注册
  - Given: Boss 敌人 preconfigured_bindings 非空
  - When: create_enemy_roster()
  - Then: 绑定已注册（is_enemy=true）
  - Edge cases: Boss 可有多条预配置绑定

- **AC-010**: 绑定不消耗费用/不占出牌
  - Given: 精英敌人已注册预配置绑定
  - When: 战斗中敌方行动
  - Then: 绑定生效但不消耗费用、不占出牌机会（预配置绑定非 AI 决策产物）
  - Edge cases: 绑定效果自动生效，等同已在绑定位

- **AC-011**: 阵亡移除绑定
  - Given: 敌人角色阵亡
  - When: 清理流程
  - Then: 绑定随角色阵亡直接移除（不走"洗回牌库"）
  - Edge cases: 已阵亡敌人不复活、绑定不残留

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ai_system/test_difficulty_scaling_bindings.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002（execute_turn 决策主循环——难度缩放/绑定注册集成到战斗流程）+ Story 003（BossPhaseMgr——Boss 阶段转换就绪后统一集成）
- Unlocks: 战斗 Epic（CombatSystem battle_start 调用 create_enemy_roster 完成缩放 + 绑定注册）；绑定 Epic（预配置绑定在战斗中自动生效的验证）
