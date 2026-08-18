# Story 004: clear_standby_state + mark_unavailable + revive_character

> **Epic**: deployment-system
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-18

## Completion Notes
**Completed**：2026-08-18
**Criteria**：14/14 通过（AC-001~014 由单元测试覆盖）
**Deviations**：
1. **ADR-0016 `is_game_over` 签名偏离（retrofit）**：ADR 原声明 `is_game_over() → bool` 无参，实现改为 `is_game_over(roster: Array) → bool` 必传参数。原因：DeploymentSystem 不持有角色位总列表（角色位属 CardSystem/CombatSystem 管理，ADR-0016 本就在「角色位来源」上含糊），由调用方注入角色位角色 ID 列表。采用必传参数（非默认参数）消除「漏传 roster → 永远不判负」的静默失败模式（lead-programmer CONCERNS）。已回写 ADR-0016。
2. **`revival_methods` 深拷贝**：`mark_unavailable` 存储 `revival_methods` 时用 `.duplicate(true)`，防止调用方事后 mutate 污染 DeploymentSystem 内部状态。
**Test Evidence**：`tests/unit/deployment_system/test_standby_unavailable_revive.gd`（22 测试全通过）；全量套件 71 scripts / 1311 tests / 1310 passing / 1 pending / 0 failing 零回归
**Code Review**：lead-programmer CONCERNS→已采纳（C1 is_game_over 必传 roster + ADR 回写 + C2 revival_methods 深拷贝）；qa-lead GAPS→已补齐（G1 复活后重新上场闭环 + G2 revival_methods 非空值透传 + G3 重复标记语义 + G4 全空场 clear_standby_state）

## Context

**GDD**: `design/gdd/deployment-system.md`
**Requirement**: `TR-deploy-003`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0016（上场阵位系统——Feature 层 Autoload + 内部状态机 + GSM 快照持久化）
**ADR Decision Summary**: 待命状态由 DeploymentSystem 内部状态机管理——`clear_standby_state()` 由 CombatSystem 在 Phase 6 END 回合结束时调用，STANDBY→READY、ACTED→READY。不可用角色生命周期：`mark_unavailable()` 战斗结算时标记，`revive_character()` 从不可用列表移除（角色属性保留但空载），`is_game_over()` 判定全部角色位不可用。跨战斗死亡通过 `_unavailable_characters` Dictionary 持久。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 不依赖 4.4+ 新特性。`clear_standby_state()` 遍历最多 6 个阵位 <0.02ms。`_unavailable_characters` 最多 6 个 entry ≈ 200 bytes。

**Control Manifest Rules (Feature 层)**:
- **Required**: 待命规则——上场角色在部署回合标记为「待命」STANDBY——不可攻击，下回合转 READY（来源 ADR-0016）
- **Required**: 跨战斗角色死亡——`_unavailable_characters` 通过 GSM 持久化——需复活恢复（来源 ADR-0016）
- **Required**: Cat 2 信号必须通过 `_emit_signal_safe()` 包装器路由（来源 ADR-0007）
- **Forbidden**: 绝不直接写 GSM 属性——始终通过第二层原子方法（来源 ADR-0001）

---

## Acceptance Criteria

*From ADR-0016 §验证标准 + GDD deployment-system.md §验收标准/§状态与转换:*

- [x] **AC-001**: `clear_standby_state()` STANDBY 角色 → READY（待命清除）
- [x] **AC-002**: `clear_standby_state()` ACTED 角色 → READY（已行动恢复，回合循环）
- [x] **AC-003**: `clear_standby_state()` READY 角色不变；DEAD 角色不变；空位跳过
- [x] **AC-004**: `clear_standby_state()` 有 STANDBY→READY 转换时发射 `standby_cleared` 信号，载荷 (character_ids: Array[int])——仅含待命清除的角色（不含 ACTED→READY）
- [x] **AC-005**: `clear_standby_state()` 无 STANDBY 角色时不发射 `standby_cleared` 信号
- [x] **AC-006**: `mark_unavailable(character_id, death_context)` 将角色加入 `_unavailable_characters`，发射 `character_unavailable` 信号
- [x] **AC-007**: `mark_unavailable` 的 death_context 正确存储 {death_turn, death_battle_id}
- [x] **AC-008**: `get_unavailable_characters()` 返回不可用角色 ID 列表
- [x] **AC-009**: `revive_character(character_id)` 从 `_unavailable_characters` 移除 → 返回 true；发射 `character_revived` 信号
- [x] **AC-010**: `revive_character(不在不可用列表的角色)` → 返回 false，不发射信号
- [x] **AC-011**: `is_game_over()` 全部角色位角色均不可用时 → true
- [x] **AC-012**: `is_game_over()` 有至少 1 个可用角色时 → false
- [x] **AC-013**: 不可用角色不可上场——`setup_field`/`deploy` 拒绝不可用角色（与 story-001/002 协同验证）
- [x] **AC-014**: 待命清除时序——`clear_standby_state` 在 Phase 6 END 由 CombatSystem 调用（本 story 验证调用点契约，实际调用属战斗 Epic）

---

## Implementation Notes

*Derived from ADR-0016 §决策 §关键接口 §待命状态清除 §不可用角色生命周期:*

1. **文件位置**: `src/feature/deployment_system.gd`（同 story-001/002/003 文件——增量扩展）
2. **clear_standby_state 实现**: 遍历 `_field` → 跳过 character_id==-1 → match state: STANDBY→READY（加入 cleared_ids）、ACTED→READY（不加入 cleared_ids）、READY/DEAD 不变。cleared_ids.size()>0 时发射 `standby_cleared(cleared_ids)`
3. **standby_cleared 信号**: `signal standby_cleared(character_ids: Array[int])`——通过 `_emit_signal_safe` 路由
4. **mark_unavailable 实现**: `_unavailable_characters[character_id] = death_context`（death_context 含 death_turn/death_battle_id）→ 发射 `character_unavailable(character_id)`
5. **character_unavailable 信号**: `signal character_unavailable(character_id: int)`——订阅者：CombatUI（灰显+骷髅）、商店系统（复活道具）、事件系统（分支判定）
6. **revive_character 实现**: `if _unavailable_characters.has(character_id): _unavailable_characters.erase(character_id)` → 发射 `character_revived(character_id)` → return true；否则 return false
7. **character_revived 信号**: `signal character_revived(character_id: int)`——角色属性保留但空载（无绑定卡，绑定卡生命周期由 BindingManager 处理）
8. **get_unavailable_characters 实现**: 返回 `_unavailable_characters.keys()`（Array[int]）——商店/事件系统查询复活道具可用性
9. **is_game_over 实现**: 全部角色位角色均在 `_unavailable_characters` 中 → true。判定时机：战斗开始前（CombatSystem.battle_start 调用前检查）
10. **is_game_over 角色位数据来源**: 需要角色位总列表（6 个角色位）——通过 CardSystem 查询角色位或由 CombatSystem 传入。若角色位数据不在 DeploymentSystem 内，用注入的角色位列表参数实现
11. **MVP 边界（ADR §风险缓解）**: 复活时角色位已被替换 → 等待队列不实现——复活丹药 UI 灰显"角色位已满"。等待队列推迟到角色管理系统 ADR
12. **信号链深度 ≤2**: 不可用/复活信号 → CombatUI/商店/事件更新 → 无进一步级联（ADR-0016）
13. **测试模式**: `DS_SCRIPT.new()` + `var ds: Node` 动态分派 + 显式类型注解

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: `setup_field` + FieldState 枚举 + `_field` 数据模型——已实现
- **Story 002**: `deploy` / `remove_character` / `is_targetable`——已实现（本 story 依赖其阵位操作）
- **Story 003**: `serialize_field` / `sync_unavailable_to_gsm` / `load_unavailable_from_gsm` GSM 快照持久化——已实现（本 story 的 mark_unavailable 结果由 story-003 同步 GSM）
- **CombatSystem Phase 6 集成**: `clear_standby_state()` 的调用点——战斗 Epic（ADR-0008）职责
- **等待队列**: 复活时角色位被占用的排队逻辑——角色管理 Epic 职责（MVP 不实现）
- **复活道具/事件结算**: 调用 `revive_character()` 的上游触发——商店/事件 Epic 职责
- **BindingManager 空载处理**: 复活后角色无绑定卡——绑定 Epic（ADR-0013）职责
- **全部阵亡游戏失败编排**: 战斗开始前调用 `is_game_over()` 的时机——战斗 Epic 职责

---

## QA Test Cases

*From ADR-0016 §验证标准 + GDD deployment-system.md §状态与转换/§边界情况:*

- **AC-001**: clear_standby_state STANDBY→READY
  - Given: 角色 101 STANDBY，角色 102 READY
  - When: `ds.clear_standby_state()`
  - Then: 101 变 READY；102 不变
  - Edge cases: 待命清除——下回合开始可攻击（GDD §5）

- **AC-002**: clear_standby_state ACTED→READY
  - Given: 角色 103 ACTED
  - When: `ds.clear_standby_state()`
  - Then: 103 变 READY（回合结束恢复）
  - Edge cases: ACTED→READY 是回合循环，非待命清除

- **AC-003**: clear_standby_state 其他状态不变
  - Given: 角色 104 DEAD，slot 5 空位
  - When: `ds.clear_standby_state()`
  - Then: DEAD 不变，空位跳过
  - Edge cases: READY/DEAD 不变（ADR §待命状态清除代码）

- **AC-004**: standby_cleared 信号仅含待命角色
  - Given: 角色 101 STANDBY + 角色 103 ACTED，订阅 `ds.standby_cleared`
  - When: `ds.clear_standby_state()`
  - Then: 信号发射，载荷 [101]（不含 103——ACTED→READY 非待命清除）
  - Edge cases: ADR §验证标准「standby_cleared 信号仅含待命角色」

- **AC-005**: 无 STANDBY 不发射信号
  - Given: 所有角色 READY（无 STANDBY）
  - When: `ds.clear_standby_state()`
  - Then: 不发射 `standby_cleared`
  - Edge cases: cleared_ids.size()==0 时跳过发射

- **AC-006**: mark_unavailable 标记 + 信号
  - Given: 角色 101 存活，订阅 `ds.character_unavailable`
  - When: `ds.mark_unavailable(101, {death_turn: 3, death_battle_id: "battle_001"})`
  - Then: `_unavailable_characters` 含 101；信号发射 (101)
  - Edge cases: 跨战斗死亡持久标记（GDD §10）

- **AC-007**: death_context 存储
  - Given: `ds.mark_unavailable(101, {death_turn: 3, death_battle_id: "battle_001"})`
  - When: 检查 `_unavailable_characters[101]`
  - Then: death_turn==3 + death_battle_id=="battle_001"
  - Edge cases: revival_methods 字段（可为空 Array）

- **AC-008**: get_unavailable_characters 列表
  - Given: 角色 101/102 不可用
  - When: `ds.get_unavailable_characters()`
  - Then: 返回 [101, 102]（或等价列表）
  - Edge cases: 空列表（无可标记者）

- **AC-009**: revive_character 复活
  - Given: 角色 101 不可用，订阅 `ds.character_revived`
  - When: `ds.revive_character(101)`
  - Then: 返回 true；`_unavailable_characters` 不含 101；信号发射 (101)
  - Edge cases: 角色属性保留但空载（无绑定卡——GDD §10）

- **AC-010**: revive 非不可用角色拒绝
  - Given: 角色 999 不在不可用列表
  - When: `ds.revive_character(999)`
  - Then: 返回 false；不发射信号
  - Edge cases: ADR §关键接口「返回 false = 角色不在不可用列表中」

- **AC-011**: is_game_over 全灭判定
  - Given: 所有角色位角色均在 `_unavailable_characters`
  - When: `ds.is_game_over()`
  - Then: true
  - Edge cases: 判定时机——战斗开始前（GDD §10「全部阵亡→游戏失败」）

- **AC-012**: is_game_over 有可用角色
  - Given: 至少 1 个角色位角色不在不可用列表
  - When: `ds.is_game_over()`
  - Then: false
  - Edge cases: 获得新角色卡后即使原角色全灭也继续游戏（GDD 边界情况）

- **AC-013**: 不可用角色拒绝上场
  - Given: 角色 101 已 mark_unavailable
  - When: `ds.setup_field([101], {})` / `ds.deploy(200, 101, -1)`
  - Then: 均拒绝（false / character_unavailable）
  - Edge cases: 不可用角色不可选上场（GDD §10 基本规则）

- **AC-014**: 待命清除调用点契约
  - Given: 战斗流程处于 Phase 6 END
  - When: CombatSystem 调用 `ds.clear_standby_state()`
  - Then: 待命清除在攻击声明（新回合 Phase 3）之前执行
  - Edge cases: 时序安全（Phase 6 → Phase 0 → Phase 1 → Phase 2 → Phase 3）；本 story 仅验证契约，实际调用属战斗 Epic

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/deployment_system/test_standby_unavailable_revive.gd` — must exist and pass
**Status**: [x] Created and passing (22 tests)

---

## Dependencies

- Depends on: Story 002（mark_unavailable 与 remove_character 协同——阵亡→清位→标记不可用链路；deploy 拒绝不可用角色）
- Unlocks: 战斗 Epic（Phase 6 调用 clear_standby_state、battle_start 前调用 is_game_over）；商店/事件 Epic（revive_character 上游触发）
