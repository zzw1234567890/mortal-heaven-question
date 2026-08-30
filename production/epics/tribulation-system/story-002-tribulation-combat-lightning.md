# Story 002: 渡劫战斗委托 CombatSystem + 天雷 debuff

> **Epic**: tribulation-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-30

## Context

**GDD**: `design/gdd/tribulation-system.md`
**Requirement**: `TR-trib-002`

**ADR Governing Implementation**: ADR-0021（渡劫突破系统——Feature Autoload 编排器 + CombatSystem 配置复用）
**ADR Decision Summary**: 渡劫战通过 `CombatSystem.battle_start(tribulation_config)` 启动——传入 `is_tribulation: true` 标志。TribulationSystem 监听 `battle_ended` 信号执行渡劫专属结算。雷伤作为纯函数计算（GDD §公式 3），StatusEffectSystem 集成留到后续 Sprint。

**Engine**: Godot 4.6 | **Risk**: MEDIUM（跨系统委托 + 信号监听，需正确处理战斗生命周期）
**Engine Notes**: CombatSystem.battle_start(config) 已实现，battle_ended 信号已声明。TribulationSystem 监听信号需在 _ready 中建立连接。均为 4.0+ 稳定 API。

**Control Manifest Rules (Feature 层)**:
- **Required**: 渡劫战通过 CombatSystem.battle_start(config) 启动 —— 来源: ADR-0021 §CombatSystem 委托
- **Required**: is_tribulation: true 标志传入战斗配置 —— 来源: ADR-0021 §CombatSystem 扩展契约
- **Forbidden**: TribulationSystem 内部实现战斗逻辑 —— 来源: ADR-0021 §编排器职责

---

## Acceptance Criteria

*From ADR-0021 §渡劫战启动与结算监听 + GDD §3 渡劫战斗规则 + §公式 3:*

- [ ] **AC-001**: `start_tribulation_combat()` — 从 PREPARING → IN_COMBAT + 构建 tribulation_config + 委托 `CombatSystem.battle_start(config)`
- [ ] **AC-002**: `_build_tribulation_config()` — 构建 `{is_tribulation: true, tribulation_data: {realm_level, is_cross_realm, boss_config}}` 配置
- [ ] **AC-003**: `_on_battle_ended(result, rewards)` — 监听 CombatSystem.battle_ended 信号，仅在 IN_COMBAT 状态时响应
- [ ] **AC-004**: `calculate_lightning_damage(turn, layers_per_turn)` 纯函数——GDD §公式 3（先叠后伤，第1回合末即1层伤害）
- [ ] **AC-005**: `get_lightning_layers_per_turn(realm_level)` — 元婴劫(realm=4)为2层/回合，其余1层/回合
- [ ] **AC-006**: `get_tribulation_boss_config(realm)` — 从 RealmSystem 查询天劫 Boss 配置（桩阶段返回默认字典）
- [ ] **AC-007**: 越阶渡劫时 Boss 境界 = 玩家境界 + 1
- [ ] **AC-008**: 战斗结束时状态转换 IN_COMBAT → SUCCESS（VICTORY）/ FAILED（DEFEAT）

---

## Implementation Notes

*Derived from ADR-0021 §渡劫战启动与结算监听 + GDD §3:*

1. **start_tribulation_combat()**: 验证 PREPARING 状态 → _set_state(IN_COMBAT) → 构建 config → 调用 CombatSystem.battle_start
2. **_build_tribulation_config()**: 查询 GSM + _trib_type + get_tribulation_boss_config → 返回配置字典
3. **_on_battle_ended(result, rewards)**: 检查 tribulation_state == IN_COMBAT → VICTORY 转 SUCCESS / DEFEAT 转 FAILED
4. **calculate_lightning_damage(turn, layers_per_turn)**: 纯函数 `return turn * layers_per_turn`（GDD §公式 3）
5. **get_lightning_layers_per_turn(realm_level)**: realm == 4 (元婴) 返回 2，否则 1（GDD §3 雷伤叠加速度）
6. **get_tribulation_boss_config(realm)**: 桩阶段返回 `{realm: realm, hp: 1000, atk: 50}`（实际配置从 RealmSystem 查询，后续接线）
7. **越阶渡劫**: _trib_type == CROSS_REALM 时 boss_realm = player.realm + 1
8. **信号监听**: _ready() 中连接 CombatSystem.battle_ended → _on_battle_ended（同 CultivationSystem 订阅 realm_changed 模式）
9. **CombatSystem 引用**: 通过 _get_combat_system() 动态查找（同 _get_gsm 模式）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 5-12**: 渡劫丹辅助 + 成功/失败分支处理——本 Story 只做状态转换，不处理结算细节
- **Story 5-13**: 渡劫结果 GSM 同步 + 场景恢复——本 Story 不处理场景恢复
- **StatusEffectSystem 扩展**: 雷伤作为 StatusEffect 实例注册——后续 Sprint（需扩展 StatusTemplate）
- **InputManager 锁**: push_lock/pop_lock——Story 5-13

---

## QA Test Cases

- **AC-001**: start_tribulation_combat 进入 IN_COMBAT + 调用 battle_start
- **AC-002**: _build_tribulation_config 返回正确结构
- **AC-003**: _on_battle_ended 在 IN_COMBAT 时响应，其他状态忽略
- **AC-004**: calculate_lightning_damage 第1回合=1，第3回合=3，第5回合元婴劫=10
- **AC-005**: get_lightning_layers_per_turn 元婴=2，其余=1
- **AC-006**: get_tribulation_boss_config 返回非空字典
- **AC-007**: 越阶渡劫 Boss 境界 = 玩家境界 + 1
- **AC-008**: VICTORY → SUCCESS，DEFEAT → FAILED

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/tribulation_system/test_tribulation_combat.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 5-10（TribulationSystem 状态机）；CombatSystem.battle_start/battle_ended（已实现）
- Unblocks: Story 5-12（成功/失败结算需要状态转换）；Story 5-13（GSM 同步需要战斗结束状态）
