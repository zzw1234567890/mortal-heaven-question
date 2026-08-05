# Story 002: 境界压制计算 + 地图境界压制 + 稀有度权重

> **Epic**: realm-system
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic（需 GUT 单元测试）
> **Estimate**: 3h
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-05

## Context

**GDD**: `design/gdd/realm-system.md`
**Requirement**: `TR-realm-002`（境界压制规则——delta=1 压制 20%、delta>=2 压制 50%）
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0010（境界系统——专用 Autoload 服务 + 静态数据表 + GSM 状态所有权分离）
**ADR Decision Summary**: RealmSystem 提供三个纯计算方法：`realm_penalty(atk, def)` 境界压制系数、`map_effective_realm(player, map_max)` 柔性地图压制、`get_rarity_weights(pool_tier)` 稀有度权重查询。DROP_POOL_WEIGHTS 为 const Dictionary。

**Engine**: Godot 4.6.3 | **Risk**: LOW（纯整数比较 + 字典查询）
**Engine Notes**: 无截止后 API。

**Control Manifest Rules (Core 层)**:
- **Required**: `realm_penalty(attacker_lv, defender_lv) → float` —— CombatSystem 在伤害结算时调用
- **Required**: `get_rarity_weights(pool_tier) → Dictionary` —— CardSystem 调用获取稀有度分布
- **Forbidden**: 绝不写 `realm_table` 或 `DROP_POOL_WEIGHTS` 内容 —— const Dictionary 并非真正冻结
- **Forbidden**: 绝不在消费者系统中硬编码境界数值

---

## Acceptance Criteria

*From ADR-0010 §关键接口 + GDD §3 境界压制规则 + §5 卡牌掉落池 + §6 地图境界压制 + §验收标准:*

- [ ] **AC-001**: `realm_penalty(attacker_lv: int, defender_lv: int) -> float` 方法签名
- [ ] **AC-002**: attacker_lv=1, defender_lv=2（敌方高1级）→ 返回 0.8（-20%）
- [ ] **AC-003**: attacker_lv=1, defender_lv=3（敌方高2级）→ 返回 0.5（-50%）
- [ ] **AC-004**: attacker_lv=2, defender_lv=1（己方高）→ 返回 1.0（无压制）
- [ ] **AC-005**: attacker_lv=3, defender_lv=3（同级）→ 返回 1.0
- [ ] **AC-006**: `map_effective_realm(player_lv: int, map_max_lv: int) -> Dictionary` 方法签名
- [ ] **AC-007**: player_lv=3, map_max_lv=1（金丹回炼气地图）→ 返回 `{"offensive_lv": 1, "defensive_lv": 3}`（进攻属性压制，防御保留）
- [ ] **AC-008**: player_lv=2, map_max_lv=3（玩家低于地图上限）→ 返回 `{"offensive_lv": 2, "defensive_lv": 2}`（无压制）
- [ ] **AC-009**: `const DROP_POOL_WEIGHTS: Dictionary` 含 5 个池等级（tier 1~5）
- [ ] **AC-010**: `get_rarity_weights(1)` 返回 `{white:60, blue:30, purple:10, gold:0, darkgold:0}`
- [ ] **AC-011**: `get_rarity_weights(3)` 返回 `{white:15, blue:30, purple:35, gold:18, darkgold:2}`
- [ ] **AC-012**: `get_rarity_weights(5)` 返回 `{white:5, blue:15, purple:25, gold:35, darkgold:20}`
- [ ] **AC-013**: 无效 pool_tier（如 6 或 0）→ 返回空 Dictionary + `push_warning`

---

## Implementation Notes

*Derived from ADR-0010 §关键接口:*

1. **文件位置**: `src/core/realm_system.gd`（同 Story 001，扩展计算方法）
2. **DROP_POOL_WEIGHTS const 定义**（ADR-0010 §关键接口 + GDD §5）:
   ```gdscript
   const DROP_POOL_WEIGHTS: Dictionary = {
       1: {&"white": 60, &"blue": 30, &"purple": 10, &"gold": 0, &"darkgold": 0},
       2: {&"white": 30, &"blue": 40, &"purple": 25, &"gold": 5, &"darkgold": 0},
       3: {&"white": 15, &"blue": 30, &"purple": 35, &"gold": 18, &"darkgold": 2},
       4: {&"white": 10, &"blue": 20, &"purple": 30, &"gold": 30, &"darkgold": 10},
       5: {&"white": 5, &"blue": 15, &"purple": 25, &"gold": 35, &"darkgold": 20},
   }
   ```
3. **realm_penalty 实现**（ADR-0010 §关键接口 + GDD §公式 3）:
   ```gdscript
   func realm_penalty(attacker_lv: int, defender_lv: int) -> float:
       var delta: int = defender_lv - attacker_lv
       if delta <= 0:
           return 1.0
       if delta == 1:
           return 0.8
       return 0.5  # delta >= 2
   ```
4. **map_effective_realm 实现**（ADR-0010 §关键接口 + GDD §公式 5）:
   ```gdscript
   func map_effective_realm(player_lv: int, map_max_lv: int) -> Dictionary:
       if player_lv <= map_max_lv:
           return {"offensive_lv": player_lv, "defensive_lv": player_lv}
       return {"offensive_lv": map_max_lv, "defensive_lv": player_lv}
   ```
   - **参考实现声明**：GDD §6 明确"完整公式由 exploration-system.md 定义，境界系统提供参考实现"。本 Story 实现参考版本，探索系统 Epic 可调整——若出现差异以 exploration-system.md 为准。
5. **get_rarity_weights 实现**（ADR-0010 §关键接口）:
   ```gdscript
   func get_rarity_weights(pool_tier: int) -> Dictionary:
       if not DROP_POOL_WEIGHTS.has(pool_tier):
           push_warning("RealmSystem: invalid pool_tier %d" % pool_tier)
           return {}
       return DROP_POOL_WEIGHTS[pool_tier]
   ```
6. **压制规则说明**（GDD §3）:
   - 压制仅影响玩家→敌方的伤害（玩家攻击高境界敌人时），不影响敌方→玩家的伤害
   - 压制只计算大境界差距，不看同境界内的修为进度
   - 压制系数只影响基础攻防伤害计算，不影响卡牌效果、天赋效果、丹药回复量
7. **权重表语义**：DROP_POOL_WEIGHTS 的键用 StringName（`&"white"` 等），值为整数百分比权重（总和 100）。CardSystem 战利品生成时按权重做加权随机选择。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: realm_table + get_realm_property + get_current_property 查询接口
- **Story 003**: realm_up() 突破编排
- **战斗伤害结算**: CombatSystem Epic 职责（调用 realm_penalty）
- **战利品生成**: CardSystem/CombatSystem Epic 职责（调用 get_rarity_weights）
- **地图进入逻辑**: ExplorationSystem Epic 职责（调用 map_effective_realm）

---

## QA Test Cases

*Derived from ADR-0010 §验证标准 + GDD §验收标准:*

- **AC-001**: realm_penalty 方法签名
  - Given: `var rs: Node = RS_SCRIPT.new()`
  - When: `var penalty: float = rs.realm_penalty(1, 2)`
  - Then: `assert_eq(typeof(penalty), TYPE_FLOAT)`
  - Edge cases: 返回值范围 [0.5, 1.0]

- **AC-002**: attacker=1, defender=2 → 0.8
  - Given: rs 已创建
  - When: `rs.realm_penalty(1, 2)`
  - Then: `assert_eq(result, 0.8)`
  - Edge cases: GDD §验收标准直接引用——敌方高1级压制 20%

- **AC-003**: attacker=1, defender=3 → 0.5
  - Given: rs 已创建
  - When: `rs.realm_penalty(1, 3)`
  - Then: `assert_eq(result, 0.5)`
  - Edge cases: 敌方高2级以上压制 50%；defender=4、defender=5 同返回 0.5

- **AC-004**: attacker=2, defender=1 → 1.0
  - Given: rs 已创建
  - When: `rs.realm_penalty(2, 1)`
  - Then: `assert_eq(result, 1.0)`
  - Edge cases: 己方高于敌方无压制

- **AC-005**: attacker=3, defender=3 → 1.0
  - Given: rs 已创建
  - When: `rs.realm_penalty(3, 3)`
  - Then: `assert_eq(result, 1.0)`
  - Edge cases: 同级无压制；delta=0

- **AC-006**: map_effective_realm 方法签名
  - Given: rs 已创建
  - When: `var result: Dictionary = rs.map_effective_realm(3, 1)`
  - Then: `assert_eq(typeof(result), TYPE_DICTIONARY)`；含 `offensive_lv` 和 `defensive_lv` 键
  - Edge cases: 返回 Dictionary 含 2 个 int 字段

- **AC-007**: player=3, map_max=1 → offensive=1, defensive=3
  - Given: rs 已创建
  - When: `rs.map_effective_realm(3, 1)`
  - Then: `assert_eq(result["offensive_lv"], 1)`；`assert_eq(result["defensive_lv"], 3)`
  - Edge cases: GDD §验收标准——金丹回青云剑宗，进攻压制防御保留

- **AC-008**: player=2, map_max=3 → offensive=2, defensive=2
  - Given: rs 已创建
  - When: `rs.map_effective_realm(2, 3)`
  - Then: `assert_eq(result["offensive_lv"], 2)`；`assert_eq(result["defensive_lv"], 2)`
  - Edge cases: 玩家低于地图上限无压制

- **AC-009**: DROP_POOL_WEIGHTS 含 5 个池等级
  - Given: RealmSystem 脚本已加载
  - When: 读取 `RS_SCRIPT.DROP_POOL_WEIGHTS`
  - Then: `assert_eq(DROP_POOL_WEIGHTS.size(), 5)`；键为 1~5
  - Edge cases: 每个 tier 的权重总和 == 100

- **AC-010**: get_rarity_weights(1) → 炼气期权重
  - Given: rs 已创建
  - When: `rs.get_rarity_weights(1)`
  - Then: `assert_eq(result[&"white"], 60)`；`assert_eq(result[&"blue"], 30)`；`assert_eq(result[&"purple"], 10)`；`assert_eq(result[&"gold"], 0)`；`assert_eq(result[&"darkgold"], 0)`
  - Edge cases: GDD §验收标准直接引用

- **AC-011**: get_rarity_weights(3) → 金丹期权重
  - Given: rs 已创建
  - When: `rs.get_rarity_weights(3)`
  - Then: `assert_eq(result[&"white"], 15)`；`assert_eq(result[&"blue"], 30)`；`assert_eq(result[&"purple"], 35)`；`assert_eq(result[&"gold"], 18)`；`assert_eq(result[&"darkgold"], 2)`
  - Edge cases: GDD §验收标准直接引用

- **AC-012**: get_rarity_weights(5) → 化神期权重
  - Given: rs 已创建
  - When: `rs.get_rarity_weights(5)`
  - Then: `assert_eq(result[&"white"], 5)`；`assert_eq(result[&"blue"], 15)`；`assert_eq(result[&"purple"], 25)`；`assert_eq(result[&"gold"], 35)`；`assert_eq(result[&"darkgold"], 20)`
  - Edge cases: GDD §5 表格直接引用

- **AC-013**: 无效 pool_tier → 空 Dictionary + push_warning
  - Given: rs 已创建
  - When: `rs.get_rarity_weights(6)`
  - Then: `assert_eq(result, {})`；`assert_push_warning_count(1)`
  - Edge cases: pool_tier=0、pool_tier=-1 同处理

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/realm_system/test_realm_calculation.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（同文件 realm_system.gd 的基础结构）
- Unlocks: CombatSystem Epic（realm_penalty）、CardSystem Epic（get_rarity_weights）、ExplorationSystem Epic（map_effective_realm 参考实现）
