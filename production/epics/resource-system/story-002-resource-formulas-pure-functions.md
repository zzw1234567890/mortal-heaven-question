# Story 002: 资源公式纯函数（拆解/出售/删卡/境界惩罚/天赋加成）

> **Epic**: resource-system
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic（需 GUT 单元测试）
> **Estimate**: 3h
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-08

## Context

**GDD**: `design/gdd/resource-system.md`
**Requirement**: `TR-resource-002`（待 `/architecture-review` 注册——当前 tr-registry.yaml 无 resource 条目，不阻塞实现）
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0019（资源系统——Core 层 Autoload 公式服务 + GSM 数据存储分离）
**ADR Decision Summary**: ResourceSystem 作为纯公式服务层，提供 6 个无副作用纯函数：拆解价值（dismantle_value）、炼制物拆折价（dismantle_crafted_value）、出售灵材价值（sell_ling_cai_value）、删卡费用（delete_card_cost）、境界差额惩罚（realm_gap_penalty）、灵石天赋加成（apply_ling_shi_bonus）。所有函数接受原始类型参数——不接收领域对象（Card/Identity），避免 Core 层对象耦合，保证函数纯粹性和可测试性。

**Engine**: Godot 4.6.3 | **Risk**: LOW（纯整数/浮点数运算）
**Engine Notes**: 无截止后 API。`floori()` 在 GDScript 4.0+ 返回 int；`maxi()`/`maxf()` 返回对应类型。

**Control Manifest Rules (Core 层)**:
- **Required**: 所有资源公式真理来源在 ResourceSystem —— 消费者系统（DeckEditingSystem、AlchemySystem 等）调用这些纯函数，绝不重新定义
- **Required**: 公式函数接受原始类型参数（int/float/bool）—— 不接收领域对象
- **Forbidden**: 绝不在消费者系统中硬编码资源数值 —— 必须调用 ResourceSystem 公式
- **Forbidden**: 公式函数绝不直接读写 `GSM.player.resources` —— 它们是纯计算，调用方负责通过 add_resource/spend_resource 应用结果

---

## Acceptance Criteria

*From GDD §公式 1/1b/2/3/6/7 + §验收标准 §拆解与炼制物/删卡费用/身份与境界:*

- [ ] **AC-001**: `dismantle_value(rarity: int, level: int) -> int` 方法签名
- [ ] **AC-002**: dismantle_value(1, 1)（白卡 1 级）→ 10（base=10, bonus=0）
- [ ] **AC-003**: dismantle_value(4, 1)（金卡 1 级）→ 400
- [ ] **AC-004**: dismantle_value(5, 20)（暗金满级）→ 3900（2000 + floor(2000×19×0.05)=1900）
- [ ] **AC-005**: dismantle_value(3, 10)（紫卡 10 级）→ 145（100 + floor(100×9×0.05)=45）
- [ ] **AC-006**: `dismantle_crafted_value(rarity: int, level: int, is_crafted: bool) -> int` 方法签名
- [ ] **AC-007**: dismantle_crafted_value(4, 1, true)（炼制金卡）→ 200（floor(400×0.5)）
- [ ] **AC-008**: dismantle_crafted_value(4, 1, false)（非炼制金卡）→ 400（等同 dismantle_value）
- [ ] **AC-009**: `sell_ling_cai_value(quality: int, quantity: int) -> int` 方法签名
- [ ] **AC-010**: sell_ling_cai_value(1, 2)（低级灵材×2）→ 20（10×2）
- [ ] **AC-011**: sell_ling_cai_value(3, 1)（高级灵材×1）→ 80
- [ ] **AC-012**: sell_ling_cai_value(4, 3)（顶级灵材×3）→ 600（200×3）
- [ ] **AC-013**: `delete_card_cost(delete_count: int) -> int` 方法签名
- [ ] **AC-014**: delete_card_cost(1)（首次删卡）→ 50
- [ ] **AC-015**: delete_card_cost(5)（第 5 次删卡）→ 150（50 + 25×4）
- [ ] **AC-016**: `realm_gap_penalty(player_level: int, map_max_level: int) -> float` 方法签名
- [ ] **AC-017**: realm_gap_penalty(3, 1)（金丹回炼气地图）→ 0.4（gap=2, 1.0-2×0.3=0.4）
- [ ] **AC-018**: realm_gap_penalty(4, 1)（元婴回炼气地图）→ 0.1（gap=3, 保底 0.1）
- [ ] **AC-019**: realm_gap_penalty(2, 3)（玩家低于地图上限）→ 1.0（gap≤0 无惩罚）
- [ ] **AC-020**: `apply_ling_shi_bonus(base_amount: int, has_ling_shi_boost: bool) -> int` 方法签名
- [ ] **AC-021**: apply_ling_shi_bonus(25, true)（青云剑宗天赋）→ 28（floor(25×1.15)=28）
- [ ] **AC-022**: apply_ling_shi_bonus(25, false)（无天赋）→ 25（原值返回）

### 设计细化声明：原始类型参数 vs 领域对象

**GDD 原签名**: `dismantle_crafted_value(card)` / `apply_ling_shi_bonus(base_amount, identity)`

**本 Story 细化签名**: `dismantle_crafted_value(rarity, level, is_crafted)` / `apply_ling_shi_bonus(base_amount, has_ling_shi_boost)`

**理由**: ADR-0019 §纯公式服务层要求公式函数无副作用且不耦合领域对象。若 dismantle_crafted_value 接收 CardInstance 对象，ResourceSystem（Core 层）将耦合 CardSystem（Core 层）的类定义——破坏纯函数的可测试性（测试需构造完整 CardInstance）。改用原始类型参数后：
1. 函数真正纯粹——输入输出仅依赖原始类型，无对象图遍历
2. 测试无需构造 CardInstance/Identity 复杂对象
3. 调用方（DeckEditingSystem/CombatSystem）从领域对象提取字段后传入，职责清晰

**公式体不变**——仅参数列表细化。GDD §公式 1/1b/2/3/6/7 的数学逻辑完全保留。

---

## Implementation Notes

*Derived from ADR-0019 §关键接口 + GDD §公式:*

1. **文件位置**: `src/core/resource_system.gd`（同 Story 001，扩展公式方法）
2. **常量定义**（GDD §调优旋钮——所有调参旋钮集中为 const）:
   ```gdscript
   const DISMANTLE_BASE: Array = [10, 30, 100, 400, 2000]  # 白/蓝/紫/金/暗金
   const CRAFTED_DISCOUNT: float = 0.5  # 炼制物拆解折价 50%
   const DELETE_BASE: int = 50
   const DELETE_INCREMENT: int = 25
   const LING_CAI_SELL_PRICE: Array = [10, 30, 80, 200]  # 低/中/高/顶
   const REALM_PENALTY_PER_GAP: float = 0.3
   const REALM_PENALTY_FLOOR: float = 0.1
   const LING_SHI_BOOST_MULTIPLIER: float = 1.15
   ```
3. **dismantle_value 实现**（GDD §公式 1）:
   ```gdscript
   func dismantle_value(rarity: int, level: int) -> int:
       if rarity < 1 or rarity > 5:
           push_error("ResourceSystem: invalid rarity %d" % rarity)
           return 0
       var base: int = DISMANTLE_BASE[rarity - 1]
       var bonus: int = floori(base * maxi(0, level - 1) * 0.05)
       return base + bonus
   ```
   - **注**: `floori()` 返回 int（Godot 4.0+）；`maxi()` 返回 int。GDD 用 `floor()` 但 floori 返回 int 更安全。
4. **dismantle_crafted_value 实现**（GDD §公式 1b）:
   ```gdscript
   func dismantle_crafted_value(rarity: int, level: int, is_crafted: bool) -> int:
       var standard: int = dismantle_value(rarity, level)
       if is_crafted:
           return floori(standard * CRAFTED_DISCOUNT)
       return standard
   ```
5. **sell_ling_cai_value 实现**（GDD §公式 2）:
   ```gdscript
   func sell_ling_cai_value(quality: int, quantity: int) -> int:
       if quality < 1 or quality > 4:
           push_error("ResourceSystem: invalid quality %d" % quality)
           return 0
       if quantity < 0:
           push_error("ResourceSystem: negative quantity %d" % quantity)
           return 0
       var unit_price: int = LING_CAI_SELL_PRICE[quality - 1]
       return unit_price * quantity
   ```
6. **delete_card_cost 实现**（GDD §公式 3）:
   ```gdscript
   func delete_card_cost(delete_count: int) -> int:
       if delete_count < 1:
           push_error("ResourceSystem: invalid delete_count %d" % delete_count)
           return DELETE_BASE
       return DELETE_BASE + DELETE_INCREMENT * (delete_count - 1)
   ```
7. **realm_gap_penalty 实现**（GDD §公式 7）:
   ```gdscript
   func realm_gap_penalty(player_level: int, map_max_level: int) -> float:
       var gap: int = player_level - map_max_level
       if gap <= 0:
           return 1.0
       return maxf(REALM_PENALTY_FLOOR, 1.0 - gap * REALM_PENALTY_PER_GAP)
   ```
8. **apply_ling_shi_bonus 实现**（GDD §公式 6）:
   ```gdscript
   func apply_ling_shi_bonus(base_amount: int, has_ling_shi_boost: bool) -> int:
       if has_ling_shi_boost:
           return floori(base_amount * LING_SHI_BOOST_MULTIPLIER)
       return base_amount
   ```
9. **调用方职责**（GDD §11——资源系统不感知其他系统经济细节）:
   - DeckEditingSystem 拆解卡牌时：从 CardInstance 提取 rarity/level/is_crafted → 调用 dismantle_crafted_value → 调用 add_resource(&"ling_shi", result)
   - 商店出售灵材时：调用 sell_ling_cai_value → 调用 spend_resource(&"ling_cai", quantity, quality) + add_resource(&"ling_shi", result)
   - 战斗战利品结算时：查询身份天赋 → 调用 apply_ling_shi_bonus(base, has_boost) → 调用 add_resource(&"ling_shi", boosted)
   - 地图通关奖励时：调用 realm_gap_penalty → base × penalty → add_resource
10. **测试模式**: 测试用 `var rs: Node = RS_SCRIPT.new()` 动态分派——纯函数不依赖 GSM，无需清理 GSM 状态（同 RealmSystem Story 001/002 模式）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: ResourceSystem Autoload + LingCaiQuality 枚举 + GSM 第二层扩展 + 读写 API
- **拆解流程触发**: DeckEditingSystem Epic 职责（调用 dismantle_value + add_resource）
- **删卡流程触发**: DeckEditingSystem Epic 职责（调用 delete_card_cost + spend_resource）
- **出售灵材流程**: ShopSystem/ExplorationSystem Epic 职责（调用 sell_ling_cai_value）
- **境界惩罚应用**: ExplorationSystem Epic 职责（调用 realm_gap_penalty 应用到地图奖励）
- **天赋加成查询**: IdentitySelectionSystem Epic 职责（提供 has_ling_shi_boost 标志）
- **坊市灵材溢价兑换**: ShopSystem Epic 职责（独立公式，非本 Story 范围）

---

## QA Test Cases

*Derived from ADR-0019 §验证标准 + GDD §验收标准 §拆解与炼制物/删卡费用/身份与境界:*

- **AC-001**: dismantle_value 方法签名
  - Given: `var rs: Node = RS_SCRIPT.new()`
  - When: `var val: int = rs.dismantle_value(1, 1)`
  - Then: `assert_eq(typeof(val), TYPE_INT)`
  - Edge cases: 无效 rarity（0/6）返回 0 + push_error

- **AC-002**: dismantle_value(1, 1) 白卡 1 级 → 10
  - Given: rs 已创建
  - When: `rs.dismantle_value(1, 1)`
  - Then: `assert_eq(result, 10)`（base=10, bonus=floor(10×0×0.05)=0）
  - Edge cases: GDD AC-6 直接引用

- **AC-003**: dismantle_value(4, 1) 金卡 1 级 → 400
  - Given: rs 已创建
  - When: `rs.dismantle_value(4, 1)`
  - Then: `assert_eq(result, 400)`（base=400, bonus=0）
  - Edge cases: GDD AC-7 直接引用

- **AC-004**: dismantle_value(5, 20) 暗金满级 → 3900
  - Given: rs 已创建
  - When: `rs.dismantle_value(5, 20)`
  - Then: `assert_eq(result, 3900)`（base=2000, bonus=floor(2000×19×0.05)=1900）
  - Edge cases: GDD AC-8 直接引用——设计上限

- **AC-005**: dismantle_value(3, 10) 紫卡 10 级 → 145
  - Given: rs 已创建
  - When: `rs.dismantle_value(3, 10)`
  - Then: `assert_eq(result, 145)`（base=100, bonus=floor(100×9×0.05)=45）
  - Edge cases: GDD §公式 1 示例

- **AC-006**: dismantle_crafted_value 方法签名
  - Given: rs 已创建
  - When: `var val: int = rs.dismantle_crafted_value(4, 1, true)`
  - Then: `assert_eq(typeof(val), TYPE_INT)`
  - Edge cases: is_crafted=false 时等同 dismantle_value

- **AC-007**: dismantle_crafted_value(4, 1, true) 炼制金卡 → 200
  - Given: rs 已创建
  - When: `rs.dismantle_crafted_value(4, 1, true)`
  - Then: `assert_eq(result, 200)`（floor(400×0.5)）
  - Edge cases: GDD AC-9 直接引用

- **AC-008**: dismantle_crafted_value(4, 1, false) 非炼制金卡 → 400
  - Given: rs 已创建
  - When: `rs.dismantle_crafted_value(4, 1, false)`
  - Then: `assert_eq(result, 400)`（等同 dismantle_value(4,1)）
  - Edge cases: 非炼制物无折价

- **AC-009**: sell_ling_cai_value 方法签名
  - Given: rs 已创建
  - When: `var val: int = rs.sell_ling_cai_value(1, 2)`
  - Then: `assert_eq(typeof(val), TYPE_INT)`
  - Edge cases: 无效 quality（0/5）返回 0 + push_error

- **AC-010**: sell_ling_cai_value(1, 2) 低级灵材×2 → 20
  - Given: rs 已创建
  - When: `rs.sell_ling_cai_value(1, 2)`
  - Then: `assert_eq(result, 20)`（10×2）
  - Edge cases: GDD AC-10 直接引用

- **AC-011**: sell_ling_cai_value(3, 1) 高级灵材×1 → 80
  - Given: rs 已创建
  - When: `rs.sell_ling_cai_value(3, 1)`
  - Then: `assert_eq(result, 80)`
  - Edge cases: GDD AC-11 直接引用

- **AC-012**: sell_ling_cai_value(4, 3) 顶级灵材×3 → 600
  - Given: rs 已创建
  - When: `rs.sell_ling_cai_value(4, 3)`
  - Then: `assert_eq(result, 600)`（200×3）
  - Edge cases: 顶级灵材批量出售

- **AC-013**: delete_card_cost 方法签名
  - Given: rs 已创建
  - When: `var val: int = rs.delete_card_cost(1)`
  - Then: `assert_eq(typeof(val), TYPE_INT)`
  - Edge cases: delete_count < 1 返回 DELETE_BASE + push_error

- **AC-014**: delete_card_cost(1) 首次删卡 → 50
  - Given: rs 已创建
  - When: `rs.delete_card_cost(1)`
  - Then: `assert_eq(result, 50)`
  - Edge cases: GDD AC-12 直接引用

- **AC-015**: delete_card_cost(5) 第 5 次删卡 → 150
  - Given: rs 已创建
  - When: `rs.delete_card_cost(5)`
  - Then: `assert_eq(result, 150)`（50 + 25×4）
  - Edge cases: GDD AC-13 直接引用

- **AC-016**: realm_gap_penalty 方法签名
  - Given: rs 已创建
  - When: `var val: float = rs.realm_gap_penalty(3, 1)`
  - Then: `assert_eq(typeof(val), TYPE_FLOAT)`
  - Edge cases: 返回值范围 [0.1, 1.0]

- **AC-017**: realm_gap_penalty(3, 1) 金丹回炼气 → 0.4
  - Given: rs 已创建
  - When: `rs.realm_gap_penalty(3, 1)`
  - Then: `assert_eq(result, 0.4)`（gap=2, 1.0-0.6=0.4）
  - Edge cases: GDD AC-15 直接引用

- **AC-018**: realm_gap_penalty(4, 1) 元婴回炼气 → 0.1（保底）
  - Given: rs 已创建
  - When: `rs.realm_gap_penalty(4, 1)`
  - Then: `assert_eq(result, 0.1)`（gap=3, 1.0-0.9=0.1，触底）
  - Edge cases: gap=5 时仍返回 0.1（保底）

- **AC-019**: realm_gap_penalty(2, 3) 玩家低于地图上限 → 1.0
  - Given: rs 已创建
  - When: `rs.realm_gap_penalty(2, 3)`
  - Then: `assert_eq(result, 1.0)`（gap=-1 ≤0，无惩罚）
  - Edge cases: 同级（gap=0）也返回 1.0

- **AC-020**: apply_ling_shi_bonus 方法签名
  - Given: rs 已创建
  - When: `var val: int = rs.apply_ling_shi_bonus(25, true)`
  - Then: `assert_eq(typeof(val), TYPE_INT)`
  - Edge cases: has_ling_shi_boost=false 返回原值

- **AC-021**: apply_ling_shi_bonus(25, true) 青云剑宗天赋 → 28
  - Given: rs 已创建
  - When: `rs.apply_ling_shi_bonus(25, true)`
  - Then: `assert_eq(result, 28)`（floor(25×1.15)=28）
  - Edge cases: GDD AC-14 直接引用

- **AC-022**: apply_ling_shi_bonus(25, false) 无天赋 → 25
  - Given: rs 已创建
  - When: `rs.apply_ling_shi_bonus(25, false)`
  - Then: `assert_eq(result, 25)`（原值返回）
  - Edge cases: 无加成时原值不变

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/resource_system/test_resource_formulas.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（同文件 resource_system.gd 的基础结构 + LingCaiQuality 枚举——sell_ling_cai_value 可复用品质校验逻辑）
- Unlocks: DeckEditingSystem Epic（dismantle_value + dismantle_crafted_value + delete_card_cost）、ShopSystem/ExplorationSystem Epic（sell_ling_cai_value）、ExplorationSystem Epic（realm_gap_penalty）、CombatSystem/ExplorationSystem Epic（apply_ling_shi_bonus）

---

## Completion Notes

**Completed**：2026-08-08
**Criteria**：22/22 通过（AC-001..AC-022 全部 COVERED + 8 项边缘情况补强测试）

**Deviations**（全部 ADVISORY，已修复）：
- **MEDIUM**（已修复）负 quantity 守卫无测试——补 test_sell_ling_cai_negative_quantity_returns_zero
- **LOW**（已修复）dismantle_crafted_value 无效 rarity 传递路径无测试——补 test_dismantle_crafted_value_invalid_rarity_returns_zero
- **LOW**（已修复）gap=1（0.7）未测试——补 test_realm_gap_one_level_partial_penalty
- **LOW**（已修复）REALM_PENALTY_FLOOR_EXPECTED 常量定义位置夹在方法间——移至文件顶部与 RS_SCRIPT 并列
- **LOW**（已修复）RS_SCRIPT 未显式类型注解——改为 `const RS_SCRIPT: GDScript = preload(...)`
- **LOW**（已修复）delete_card_cost 守卫返回 DELETE_BASE 而非 0 缺说明——文档注释补"保守默认费用，避免低估扣减"
- **正向偏离**（表扬）const 用 PackedInt32Array 替代 Array——值类型语义（传递即复制）、类型安全、内存紧凑

**Test Evidence**：Logic — `tests/unit/resource_system/test_resource_formulas.gd`（33 测试覆盖 22 条 AC + 8 项边缘情况）
**Code Review**：已完成——gdscript-specialist APPROVED WITH SUGGESTIONS（修复后）+ qa-tester PASS（22/22 AC COVERED）

**测试结果**：全量套件 756/755 通过（1 pending 是与本 Story 无关的 save_load 多步迁移占位），2666 断言
