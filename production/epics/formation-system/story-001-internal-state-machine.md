# Story 001: 内部条件状态机 + 阵法位管理

> **Epic**: 阵法系统 (Formation System)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**:

## Context

**GDD**: `design/gdd/formation-system.md`
**Requirement**: `TR-formation-001`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0024（阵法系统 — Feature 层 Autoload + 内部条件状态机 + GSM 快照持久化）
**ADR Decision Summary**: FormationSystem 实现为 Feature 层 Autoload #23，采用内部状态机管理阵法位数据——阵法位状态、激活/未激活判定、角色归属关系均在内部 Dictionary 中管理，战斗期间不经过 GSM。阵法区最多 3 格（slot_index 0-2），独立于角色阵位。

**Engine**: Godot 4.6 | **Risk**: LOW（Dictionary 操作、信号系统、enum 状态机均为 4.x 成熟 API）
**Engine Notes**: 不依赖 4.4+ 新增 API。`Dictionary` 键查找、`signal` 发射、`enum` 状态机均为 4.0+ 稳定 API。

**Control Manifest Rules (Feature 层)**:
- **Required**: FormationSystem 3 个阵法位、场上状态变更时实时重判条件（ADR-0024）
- **Required**: 角色归属锁定直到阵法失效（ADR-0024）
- **Forbidden**: 绝不缓存阵法激活状态——场上变更时通过 `FactionSystem.check_condition()` 重判（ADR-0024）

---

## Acceptance Criteria

*From GDD `design/gdd/formation-system.md` §1 阵法区 + §2 部署流程 + §3 激活与失效 + §4 覆盖规则 + §5 角色归属，scoped to this story:*

- [ ] **AC-001**: 场上无阵法，打出阵法卡 → 阵法部署到阵法区空位（slot_index 自动分配）
- [ ] **AC-002**: 场上已有 3 个阵法，打出阵法卡 → `deploy_formation()` 返回 `slots_full`（进入覆盖流程，由 `overwrite_formation()` 承接）
- [ ] **AC-003**: 条件满足（如场上 ≥3 正道），部署对应阵法 → 阵法立即进入 ACTIVE 状态
- [ ] **AC-004**: 条件不满足，部署阵法 → 阵法处于 DEPLOYED_UNACTIVE 状态（未激活，灰色）
- [ ] **AC-005**: 覆盖旧阵法，确认覆盖 → 旧阵法进入 DISCARDED 状态（弃牌堆），新阵法部署到该阵位并立即判定条件
- [ ] **AC-006**: 场上未激活的阵法，检查阵法位占用 → 仍计为 1/3（未激活阵法占用阵位）
- [ ] **AC-007**: 角色满足多阵法条件，归属选择 → `set_character_affilation()` 手动指定该角色归属（每角色最多 1 个阵法）
- [ ] **AC-008**: 角色已归属某阵法，该阵法失效 → 角色回到无归属（`clear_character_affilation()` 自动清除）

---

## Implementation Notes

*Derived from ADR-0024 §对象模型 §阵法状态机 §关键接口 §覆盖流程 §角色归属管理 §与 CardEffectEngine 的集成:*

1. **文件位置**: `src/feature/formation_system.gd`（Feature 层 Autoload #23）
2. **内部数据模型**（战斗期间不经过 GSM）:
   ```gdscript
   enum SlotState { EMPTY, DEPLOYED_UNACTIVE, ACTIVE, DISCARDED }
   enum AuraScope { GLOBAL, AFFILIATED_CHARACTERS, SAME_FACTION, FORMATION_TRIGGER }

   var _slots: Dictionary[int, Dictionary]  # slot_index(0-2) → {
       #   formation_id: int, card_instance_id: int, template_id: StringName,
       #   state: SlotState, deployed_turn: int, requirement: Dictionary,
       #   aura_scope: AuraScope, effect_config: Dictionary, max_level: int,
       #   base_value: float, affiliated_chars: Array[int]
       # }
   var _affiliations: Dictionary[int, int]  # character_id → formation_id（每角色最多 1 个）
   var _next_formation_id: int = 1
   ```
3. **阵法状态机**（ADR-0024 §阵法状态机）:
   - `DEPLOYED_UNACTIVE` → 条件满足 → `ACTIVE`
   - `ACTIVE` → 条件不满足 → `UNACTIVE`（与 DEPLOYED_UNACTIVE 等价）
   - `UNACTIVE` → 条件恢复 → `ACTIVE`（重新激活，无需重新打出）
   - 任意非 DISCARDED 状态 → 被覆盖 → `DISCARDED`
   - 阵法位与角色阵位独立——阵法不占用角色位置，角色也不占用阵法位
4. **`deploy_formation(card_instance_id: int, template_id: StringName, slot_index: int = -1) → DeployResult`**:
   - slot_index = -1 时自动分配第一个空位
   - 部署到空位 → 立即判定条件（`FactionSystem.check_condition(requirement)`）→ 条件满足则 ACTIVE，否则 DEPLOYED_UNACTIVE
   - 阵法区满 3 个 → 返回 `{success: false, reason: "slots_full"}`（由调用方走覆盖流程）
   - DeployResult = `{success: bool, formation_id: int, slot_index: int, activated: bool, reason: String}`
5. **`overwrite_formation(card_instance_id: int, template_id: StringName, target_slot: int) → DeployResult`**（严格顺序，ADR-0024 §覆盖流程）:
   1. 旧阵法 state → DISCARDED
   2. 清除旧阵法全部归属（`_affiliations` 中指向旧 formation_id 的条目移除）
   3. `CardEffectEngine.remove_effects_by_source(old_card_instance_id)` —— 先移除旧效果
   4. 新阵法部署到该阵位
   5. 立即判定条件
   6. `CardEffectEngine.register_persistent_effect(new_card_instance_id, ...)` —— 再注册新效果（严格顺序）
6. **角色归属管理**（ADR-0024 §角色归属管理）:
   - `set_character_affilation(character_id: int, formation_id: int) → bool`：仅当角色当前无归属 + 阵法为 ACTIVE + 角色满足条件 → 返回 true；角色已有归属 → 返回 false（需先清除）。发射 `character_affiliated` 信号
   - `clear_character_affilation(character_id: int) → void`：阵法失效/覆盖时自动调用
   - 每角色最多归属 1 个阵法（`max_affiliations = 1`）；归属锁定到阵法失效，不可中途更换
7. **查询接口**（本 story 实现状态/位查询，光环查询归 Story 003）:
   - `get_formation_state(formation_id: int) → Dictionary`：O(1) 单阵法状态 `{slot_index, template_id, state, deployed_turn, requirement, affiliated_count, is_active}`
   - `get_active_formations() → Array[Dictionary]`：所有 ACTIVE 阵法摘要
   - `get_slot_states() → Array[Dictionary]`：3 个阵法位完整状态
   - `get_character_affilation(character_id: int) → int`：O(1) 归属查询，未归属返回 -1
   - `is_formation_active(formation_id: int) → bool`
   - `can_deploy() → CanDeployResult`：`{can_deploy, empty_slots, reason}`
8. **Cat 2b 信号（本 story 涉及，经 `_emit_signal_safe` 路由，ADR-0007）**:
   - `formation_deployed(formation_id, slot_index, template_id, deployed_turn)`
   - `formation_activated(formation_id, slot_index, template_id, trigger_reason: String)`
   - `formation_deactivated(formation_id, slot_index, reason: String)`
   - `formation_overwritten(old_formation_id, new_formation_id, slot_index)`
   - `character_affiliated(character_id, formation_id)`
9. **条件判定管线**（ADR-0024 §阵法条件判定管线）:
   - requirement 格式：`{tag_id: StringName, min_count: int}` 或 `{character_id: int}`（特定角色在场）或 `{binding_threshold: int}`（绑定条件）
   - 通过 `FactionSystem.check_condition(requirement)` 判定——不缓存激活状态
10. **Autoload 初始化**（ADR-0024 §Autoload 初始化）:
    - `_ready()`：等待 `gsm_initialized` → 初始化 3 个空阵位（state=EMPTY）→ `_affiliations` 为空 → `_next_formation_id = 1`
    - 连接 DeploymentSystem 信号（`character_deployed` / `character_removed` → `_on_field_changed`）——Story 002 实现重判逻辑，本 story 保留连接点

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: `recheck_all_conditions()` 激活条件实时重判逻辑（订阅 deployment 信号遍历 3 阵法位）——本 story 仅预留信号连接点
- **Story 003**: `get_aura_bonus()` O(1) 光环查询 + 梯度光环 `_calculate_gradient_aura()` 实时计算
- **Story 004**: `serialize_all()` / `deserialize_all()` / `clear_all_formations()` GSM 快照导出

---

## QA Test Cases

*Derived from ADR-0024 §验证标准 + GDD §验收标准 §边界情况:*

- **AC-001**: deploy_formation 空位部署
  - Given: 阵法区 3 格全空（无阵法）
  - When: `deploy_formation(card_id, template_id)`（slot_index = -1 自动分配）
  - Then: 返回 `success=true`；阵法落到 slot_index 0；`_slots[0]` 状态非 EMPTY
  - Edge cases: slot_index=-1 时分配第一个空位（按 0→1→2 顺序）

- **AC-002**: 满位部署返回 slots_full
  - Given: 阵法区 3 格全满
  - When: `deploy_formation(card_id, template_id)`
  - Then: 返回 `{success: false, reason: "slots_full"}`；不新增阵法；`_slots` 保持 3 个
  - Edge cases: 满位含未激活阵法时同样返回 slots_full（未激活阵法仍占用位）

- **AC-003**: 条件满足立即 ACTIVE
  - Given: 场上 3 正道角色；部署 requirement 为 `{tag_id: "zhengdao", min_count: 3}` 的阵法
  - When: `deploy_formation(...)`
  - Then: 返回 `activated=true`；阵法 state=ACTIVE；发射 `formation_deployed` + `formation_activated`
  - Edge cases: 部署时条件判定通过 `FactionSystem.check_condition()` 实时执行

- **AC-004**: 条件不满足 → DEPLOYED_UNACTIVE
  - Given: 场上 0 正道角色；部署 requirement 为 `{tag_id: "zhengdao", min_count: 3}` 的阵法
  - When: `deploy_formation(...)`
  - Then: 返回 `activated=false`；阵法 state=DEPLOYED_UNACTIVE；发射 `formation_deployed`（不发射 `formation_activated`）
  - Edge cases: 未激活阵法不产生任何效果，但占用阵位

- **AC-005**: overwrite_formation 覆盖流程
  - Given: 阵法区 3 格全满，target_slot=1 有旧阵法（含归属角色）
  - When: `overwrite_formation(new_card_id, new_template_id, 1)`
  - Then: 旧阵法 state=DISCARDED；旧阵法全部归属清除；新阵法部署到 slot 1 并立即判定；发射 `formation_overwritten` + `formation_deployed`（+ `formation_activated` 若条件满足）
  - Edge cases: 被覆盖的旧阵法若已失效（阵眼阵亡），覆盖不影响任何角色（归属已空）

- **AC-006**: 未激活阵法占用阵位
  - Given: 阵法区有 1 个未激活阵法
  - When: 检查阵法位占用（`can_deploy()` 或 `get_slot_states()`）
  - Then: `empty_slots` 返回 2（3-1）；未激活阵法计为 1/3
  - Edge cases: 3 个阵法全部未激活却满位——允许，玩家可覆盖但不可再直接部署

- **AC-007**: set_character_affilation 归属指定
  - Given: 阵法为 ACTIVE；角色无归属且满足该阵法条件
  - When: `set_character_affilation(character_id, formation_id)`
  - Then: 返回 true；`_affiliations[character_id] = formation_id`；发射 `character_affiliated`
  - Edge cases: 角色已有归属 → 返回 false（需先 clear）；阵法非 ACTIVE → 返回 false

- **AC-008**: 阵法失效清除归属
  - Given: 角色已归属某阵法
  - When: 该阵法变为 UNACTIVE/DISCARDED（`clear_character_affilation()` 被触发）
  - Then: `_affiliations` 中该角色条目移除；`get_character_affilation(character_id)` 返回 -1
  - Edge cases: 角色阵亡时保留归属记录（不影响阵法其他归属角色）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/formation_system/test_internal_state_machine.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None（FactionSystem `check_condition()` 已由 faction-system Story 002 提供；CardEffectEngine persistent effect 接口依赖 card-effect-engine，但在本 story 中通过可注入接缝调用）
- Unlocks: Story 002（recheck_all_conditions 依赖状态机）、Story 003（get_aura_bonus 依赖阵法位数据）、Story 004（serialize_all 依赖阵位状态）
