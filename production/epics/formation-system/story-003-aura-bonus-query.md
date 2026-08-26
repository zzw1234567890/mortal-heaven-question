# Story 003: get_aura_bonus O(1) 查询 + 梯度光环计算

> **Epic**: 阵法系统 (Formation System)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-24

## Context

**GDD**: `design/gdd/formation-system.md`
**Requirement**: `TR-formation-003`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0024（阵法系统 — Feature 层 Autoload + 内部条件状态机 + GSM 快照持久化）
**ADR Decision Summary**: 阵法光环效果通过 `get_aura_bonus()` 提供 O(1) 查询——CombatSystem 在伤害计算时、CombatUI 在显示属性时调用。同阵营梯度阵法效果等级实时计算：`effect_value = base_value × min(count_on_field(tag_id) - 1, max_level)`。

**Engine**: Godot 4.6 | **Risk**: LOW（Dictionary O(1) 查找 + 整数运算均为 4.x 成熟 API）
**Engine Notes**: 不依赖 4.4+ 新增 API。`Dictionary` 键查找、`mini()` 整数运算为 4.0+ 稳定 API。

**Control Manifest Rules (Feature 层)**:
- **Required**: 梯度阵法效果等级 = `min(count_on_field(tag) - 1, max_level)`——实时计算（ADR-0024）
- **Required**: 阵法光环作用域模型 GLOBAL / AFFILIATED_CHARACTERS / SAME_FACTION / FORMATION_TRIGGER（ADR-0024）
- **Forbidden**: 绝不缓存阵法激活状态——场上变更时通过 `FactionSystem.check_condition()` 重判（ADR-0024）
- **Forbidden**: 绝不缓存阵营计数——始终从当前场上状态统计（ADR-0018）

---

## Acceptance Criteria

*From GDD `design/gdd/formation-system.md` §7 阵法效果类型 §9 同阵营梯度阵法 + §公式 4 + §边界情况，scoped to this story:*

- [x] **AC-001**: 归属角色通过 `get_aura_bonus(character_id, stat_name)` 获得阵法光环加成（属性增益，如苍玄正道盟阵 HP+2/DEF+1）
- [x] **AC-002**: 未归属任何阵法的角色 `get_aura_bonus()` 返回 0 加成
- [x] **AC-003**: 同阵营梯度阵法——场上 2 人 → 效果等级 1；4 人 → 效果等级 3（`effect_level = count_on_field - 1`）
- [x] **AC-004**: 梯度阵法封顶——场上同阵营人数超过 max_level+1 时，效果取 max_level 封顶值，不溢出
- [x] **AC-005**: 梯度阵法人数从 4 降到 2 → 效果等级从 3 降到 1，不立即失效（≥2 门槛仍满足）
- [x] **AC-006**: 梯度阵法人数从 1 恢复到 2 → 效果重新从 1 级开始激活
- [x] **AC-007**: 多阵营平局时梯度判定——取先入场的阵营计算（不可同时为两个阵营生效）

---

## Implementation Notes

*Derived from ADR-0024 §关键接口 §梯度阵法动态效果计算 §光环作用域模型:*

1. **文件位置**: `src/feature/formation_system.gd`（扩展 Story 001/002——新增 `get_aura_bonus()` + `_calculate_gradient_aura()`）
2. **`get_aura_bonus(character_id: int, stat_name: String) → AuraBonusResult`**（战斗热路径 O(1) 查询）:
   - `AuraBonusResult = {total_bonus: float, breakdown: Array[Dictionary]}`
   - 查询 `_affiliations[character_id]` → 得到 formation_id → O(1) 定位阵法位
   - 未归属返回 `{total_bonus: 0.0, breakdown: []}`
   - 仅 ACTIVE 阵法产生加成
3. **梯度阵法 `_calculate_gradient_aura(formation_id: int, target_character_id: int, stat_name: String) → float`**（ADR-0024 §梯度阵法动态效果计算）:
   ```gdscript
   var slot = _slots[_get_slot_by_formation(formation_id)]
   var requirement = slot.requirement
   var tag_id: StringName = requirement.get("tag_id", &"")
   if tag_id.is_empty():
       return 0.0
   var count_on_field: int = FactionSystem.count_on_field(tag_id)
   if count_on_field < 2:  # 门槛：≥2 人
       return 0.0
   var effect_level: int = mini(count_on_field - 1, slot.max_level)
   return slot.base_value * float(effect_level)
   ```
4. **梯度公式**：`effect_value = base_value × min(count_on_field(tag_id) - 1, max_level)`
   - max_level 由阵法稀有度决定（蓝 4 / 紫 5 / 金 6）
   - 2 人 → 1 级、3 人 → 2 级，依此类推
5. **光环作用域模型**（`AuraScope` 枚举，Story 001 已定义）:
   - `GLOBAL`：影响战斗规则（如抽卡概率）
   - `AFFILIATED_CHARACTERS`：作用于归属角色（属性增益）
   - `SAME_FACTION`：作用于同一阵营所有角色（每回合回复）
   - `FORMATION_TRIGGER`：条件触发（如击杀后攻击 +2）
   - CardEffectEngine 在注册光环效果时根据 AuraScope 确定目标集合——FormationSystem 仅提供作用域标记，不直接操作角色属性（ADR-0024 §光环作用域模型）
6. **固定阵法 vs 梯度阵法的统一接口**（ADR-0024 §后果——积极）:
   - `get_aura_bonus()` 内部处理梯度计算和固定值两种情况
   - 消费者（CombatSystem / CombatUI / AI）无需知道阵法类型差异
7. **多阵营平局处理**（GDD §9 + ADR-0024 §解决的 GDD 需求）:
   - 若场上存在多个阵营，取人数最多的阵营计算梯度；平局时取先入场的阵营
   - 通过 `FactionSystem` 的入场顺序信息判定（或 FormationSystem 记录首次满足门槛的阵营）
8. **性能预算**（ADR-0024 §性能影响）:
   - `get_aura_bonus()` <0.001ms（Dictionary 查找 + 梯度实时计算）
   - 一帧内多次调用（伤害计算 + 属性显示 × 6 角色 ≈ 20-30 次遍历）在当前规模下可忽略

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: 阵法位数据模型、状态机、归属管理 API——本 story 只消费这些数据
- **Story 002**: 激活/失效的信号重判——本 story 只计算已 ACTIVE 阵法的光环值
- **Story 004**: serialize_all 快照导出（光环值是动态计算，不序列化）
- **CardEffectEngine Epic**: 光环效果的实际结算与目标集合分配——FormationSystem 只返回加成数值，不操作角色属性

---

## QA Test Cases

*Derived from ADR-0024 §验证标准 + GDD §公式 4 §边界情况:*

- **AC-001**: 归属角色获得光环加成
  - Given: 阵法 ACTIVE（固定属性增益：HP+2/DEF+1）；角色已归属该阵法
  - When: `get_aura_bonus(character_id, "hp")` 和 `get_aura_bonus(character_id, "def")`
  - Then: 返回 `{total_bonus: 2.0}`（hp）和 `{total_bonus: 1.0}`（def）
  - Edge cases: breakdown 数组记录来源阵法与作用域

- **AC-002**: 未归属角色返回 0
  - Given: 角色无归属（`_affiliations` 无该角色条目）
  - When: `get_aura_bonus(character_id, "hp")`
  - Then: 返回 `{total_bonus: 0.0, breakdown: []}`
  - Edge cases: 角色归属的阵法非 ACTIVE 时同样返回 0

- **AC-003**: 梯度阵法效果等级随人数增长
  - Given: 梯度阵法（base_value=1, max_level=5）；场上 2 个同阵营角色
  - When: `_calculate_gradient_aura(...)` 计算
  - Then: effect_level=1 → effect_value=1.0；场上 4 人时 effect_level=3 → effect_value=3.0
  - Edge cases: 门槛 <2 人时返回 0（`count_on_field < 2`）

- **AC-004**: 梯度阵法封顶
  - Given: 梯度阵法（max_level=4，蓝色）；场上 6 个同阵营角色
  - When: `_calculate_gradient_aura(...)` 计算
  - Then: `mini(6-1, 4)` = 4 → effect_value = base_value × 4（不溢出到 5）
  - Edge cases: 超过封顶值取封顶值，不产生额外叠加

- **AC-005**: 梯度降级不失效
  - Given: 梯度阵法（门槛 2，max_level=5）；场上 4 人（effect_level=3）
  - When: 人数降到 2
  - Then: effect_level 降到 1（`mini(2-1, 5)`）；阵法仍 ACTIVE（≥2 门槛满足）
  - Edge cases: 威力减弱但不消失

- **AC-006**: 梯度从不足恢复到满足
  - Given: 梯度阵法（门槛 2）；场上 1 人（未激活/无效果）
  - When: 人数恢复到 2
  - Then: 重新从 effect_level=1 开始（`mini(2-1, max_level)` = 1）
  - Edge cases: 不保留之前的等级记忆

- **AC-007**: 多阵营平局取先入场阵营
  - Given: 场上正道 3 人 + 魔道 3 人（平局）；正道角色先入场
  - When: 梯度阵法判定梯度阵营
  - Then: 取正道（先入场阵营）计算梯度；不可同时为两个阵营生效
  - Edge cases: 人数不同时取人数最多的阵营

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/formation_system/test_aura_bonus_query.gd` — must exist and pass
**Status**: [x] Created — 20 tests, all passing (AC-001~007 全覆盖 + 梯度性能 + base_value 非 1.0 + fixed_bonus_cb 注入)

---

## Dependencies

- Depends on: Story 001（阵法位数据模型 + 归属管理 + `_slots` Dictionary）；跨 Epic 依赖 FactionSystem `count_on_field()`（faction-system Story 002 已提供）
- Unlocks: Story 004（serialize_all 需光环查询稳定后导出阵位状态）
