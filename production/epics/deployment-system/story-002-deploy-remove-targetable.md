# Story 002: deploy / remove / is_targetable 前后排保护 O(1)

> **Epic**: deployment-system
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-17

## Completion Notes
**Completed**：2026-08-17
**Criteria**：15/15 通过（AC-001~015 由单元测试覆盖）
**Deviations**：
1. **deploy 上限检查**：ADR 编排设计是 `can_deploy()` 先查上限再 `deploy()`，但实现按 lead-programmer CONCERNS 在 `deploy()` 内部补了 `deployed >= max_deploy → field_full` 防御检查（reason 值域仍 4 个），使 `deploy` 独立调用也安全。
2. **deploy_turn=0 临时桩**：由 CombatSystem 传入真实回合数——本 Story 用硬编码 0，代码注释已标注待接入（Story Notes #10）。
**Test Evidence**：`tests/unit/deployment_system/test_deploy_targetable.gd`（22 测试全通过）；全量套件 69 scripts / 1269 tests / 1268 passing / 1 pending / 0 failing 零回归
**Code Review**：lead-programmer CONCERNS→已采纳（C1 deploy 补 max_deploy 上限检查 + C2 删 FileAccess 源码 contains 测试改运行时行为验证 + C3 deploy_turn 桩注释）；qa-lead GAPS→已补齐（G1 AC-001 前排优先场景修正 + G2 AC-015 源码 contains 移除 + G3 front_line_breached 运行时断言 + G4 deploy_turn 断言 + G5 哨兵/已在场/穿透短路/上限 4 分支回归）

## Context

**GDD**: `design/gdd/deployment-system.md`
**Requirement**: `TR-deploy-002`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0016（上场阵位系统——Feature 层 Autoload + 内部状态机 + GSM 快照持久化）
**ADR Decision Summary**: 前后排保护通过 `is_targetable(character_id, attacker_has_penetration=false)` 提供 O(1) 查询——前排有存活角色 + 目标在后排 + 无穿透 → false。`deploy()` 处理战中补位（检查空位→自动分配前排优先→标记待命→Cat 2b 信号）。`remove_character()` 是唯一阵亡入口——清空阵位，绑定卡洗回由 BindingManager 处理。前排全灭发射 `front_line_breached` 信号（仅一次，setup_field 重置标志）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 不依赖 4.4+ 新特性。`is_targetable()` O(1) Dictionary 查询 <0.01ms——AI 系统目标选择每帧调用。

**Control Manifest Rules (Feature 层)**:
- **Required**: 前排保护——前排有存活角色时敌方不可直接攻击后排（穿透效果除外）（来源 ADR-0016）
- **Required**: 战中补位——打出角色卡→选空位→待命 STANDBY（来源 ADR-0016）
- **Required**: Cat 2 信号必须通过 `_emit_signal_safe()` 包装器路由（来源 ADR-0007）
- **Forbidden**: 绝不战中移动角色前后排位置——阵位调整仅在备战阶段（来源 ADR-0016）
- **Guardrail**: `deploy()` 单次 <0.3ms；`is_targetable()` 每查询 <0.01ms（来源 ADR-0016）

---

## Acceptance Criteria

*From GDD deployment-system.md §验收标准 + ADR-0016 §验证标准:*

- [x] **AC-001**: `deploy(card_instance_id, character_id, -1)` 有 2 个空位时 → 自动分配到前排优先空位，返回 {success: true, slot_index, reason: "deployed"}
- [x] **AC-002**: `deploy(card_instance_id, character_id, -1)` 场上满员 6 人时 → 返回 {success: false, slot_index: -1, reason: "field_full"}
- [x] **AC-003**: `deploy(card_instance_id, character_id, invalid_slot)` 指定已占用槽位 → 返回 {success: false, slot_index: -1, reason: "invalid_slot"}
- [x] **AC-004**: `deploy(card_instance_id, unavailable_character_id, -1)` 不可用角色 → 返回 {success: false, slot_index: -1, reason: "character_unavailable"}
- [x] **AC-005**: `deploy` 成功后角色 state == STANDBY（本回合不可攻击）
- [x] **AC-006**: `deploy` 成功后发射 `character_deployed` 信号，载荷 (character_id, slot_index, is_front, deploy_turn)
- [x] **AC-007**: `remove_character(character_id)` 阵亡时清空阵位 → 该 slot 变为 character_id=-1 + EMPTY；发射 `character_removed` 信号
- [x] **AC-008**: `is_targetable(前排角色)` → 始终返回 true
- [x] **AC-009**: `is_targetable(后排角色, penetration=false)` 前排有存活角色时 → false（受保护）
- [x] **AC-010**: `is_targetable(后排角色, penetration=false)` 前排全灭时 → true + 发射 `front_line_breached` 信号（仅一次）
- [x] **AC-011**: `is_targetable(后排角色, penetration=true)` 前排有存活时 → true（穿透无视保护）
- [x] **AC-012**: `is_targetable(未上场角色)` → false
- [x] **AC-013**: `is_targetable(阵亡角色)` → false
- [x] **AC-014**: `is_targetable` 前排全灭后再补位前排角色 → 后排重新受保护（`front_line_breached` 不再重复发射）
- [x] **AC-015**: 6 个 Cat 2b 信号均通过 `_emit_signal_safe` 路由（character_deployed / character_removed / standby_cleared / character_unavailable / character_revived / front_line_breached 声明——本 story 实现 deployed/removed/front_line_breached 三个，其余属 story-004）

---

## Implementation Notes

*Derived from ADR-0016 §决策 §关键接口 §前后排保护查询:*

1. **文件位置**: `src/feature/deployment_system.gd`（同 story-001 文件——增量扩展）
2. **deploy 实现**: `deploy(card_instance_id: int, character_id: int, slot_index: int = -1) -> Dictionary`（DeployResult）。slot_index=-1 时调用 `get_empty_slots()` 取前排优先第一个空位
3. **DeployResult 结构**: `{success: bool, slot_index: int, reason: String}`。reason ∈ 'deployed' / 'field_full' / 'character_unavailable' / 'invalid_slot'
4. **deploy 前置检查顺序**: 角色不可用检查 → 空位检查（can_deploy）→ 槽位合法性检查
5. **is_targetable 实现**: 严格遵循 ADR §前后排保护查询的 6 步判断——(1) 角色在场上 (2) 非 DEAD (3) 前排→true (4) 穿透→true (5) 后排+前排无存活→true+front_line_breached (6) 后排+前排有存活→false
6. **front_line_breached 信号**: 仅当前排从「有存活」变为「无存活」时发射一次——用 `_front_line_breached_emitted` 标志守卫，`setup_field` 重置（story-001 已实现）
7. **remove_character 实现**: 清空 `_field[slot]` → 重置为 EMPTY 空位结构 → 发射 `character_removed(character_id, slot_index, reason)`。绑定卡洗回由 BindingManager 处理——DeploymentSystem 不负责绑定卡生命周期
8. **Cat 2b 信号路由**: 所有信号通过 `_emit_signal_safe(self, &"signal_name", [args])` 发射（ADR-0007 包装器）
9. **信号声明**: `signal character_deployed(character_id: int, slot_index: int, is_front: bool, deploy_turn: int)`、`signal character_removed(character_id: int, slot_index: int, reason: String)`、`signal front_line_breached()`
10. **deploy_turn 来源**: 由 CombatSystem 传入（当前回合数）——本 story 用参数或测试桩传入，战斗 Epic 集成时接入真实回合计数
11. **信号链深度 ≤2**: 部署信号 → CombatUI/BindingManager/阵法系统更新 → 无进一步级联（ADR-0016）
12. **性能**: `is_targetable()` 必须 O(1)——`get_character_slot` O(n) 遍历仅 6 格可接受，但 `get_front_count` 缓存前排存活状态供 AI 复用（ADR §风险缓解）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: `setup_field` 阵位初始化 + FieldState 枚举 + 自动分配算法 + `_field` 数据模型——已实现
- **Story 003**: `serialize_field()` / `deserialize_field()` / `sync_unavailable_to_gsm()` / `load_unavailable_from_gsm()` GSM 快照持久化
- **Story 004**: `clear_standby_state()` / `mark_unavailable()` / `revive_character()` / `get_unavailable_characters()` / `is_game_over()` / `standby_cleared` / `character_unavailable` / `character_revived` 信号
- **BindingManager 绑定卡洗回**: `remove_character` 仅清阵位，绑定卡生命周期由 BindingManager（ADR-0013）处理
- **阵法系统重查**: 上场人数/阵位变更通知阵法系统——阵法 Epic（ADR-0024）职责
- **CombatSystem 编排**: `play_card()` 调用 `can_deploy()`+`deploy()`、`character_died` 信号触发 `remove_character()`——战斗 Epic（ADR-0008）职责
- **CombatUI 目标选择**: 调用 `is_targetable()` 做目标验证——战斗 UI Epic 职责

---

## QA Test Cases

*From ADR-0016 §验证标准 + GDD deployment-system.md §验收标准/§边缘情况:*

- **AC-001**: deploy 自动分配前排优先空位
  - Given: 已 setup_field 3 人（slot 0/1/3 占用），max_deploy=6
  - When: `ds.deploy(200, 201, -1)`
  - Then: 返回 {success: true, slot_index: 2, reason: "deployed"}（slot 2 为前排优先第一个空位）
  - Edge cases: 前排空位（0,1,2）优先于后排（3,4,5）

- **AC-002**: deploy 满员拒绝
  - Given: 已 setup_field 6 人满阵
  - When: `ds.deploy(200, 201, -1)`
  - Then: 返回 {success: false, slot_index: -1, reason: "field_full"}
  - Edge cases: GDD 边界情况「场上已满 6 人时打出角色卡」

- **AC-003**: deploy 无效槽位拒绝
  - Given: slot 0 已占用
  - When: `ds.deploy(200, 201, 0)`
  - Then: 返回 {success: false, slot_index: -1, reason: "invalid_slot"}
  - Edge cases: slot_index 越界（<0 或 >5）同样拒绝

- **AC-004**: deploy 不可用角色拒绝
  - Given: character_id 在 `_unavailable_characters` 中
  - When: `ds.deploy(200, unavailable_id, -1)`
  - Then: 返回 {success: false, slot_index: -1, reason: "character_unavailable"}
  - Edge cases: 不可用角色不可上场（GDD §10）

- **AC-005**: deploy 后 STANDBY
  - Given: `ds.deploy(200, 201, -1)` 成功
  - When: `ds.get_character_slot(201)` → `ds._field[slot].state`
  - Then: state == STANDBY
  - Edge cases: 战中补位角色本回合不可攻击（GDD §4）

- **AC-006**: character_deployed 信号载荷
  - Given: 订阅 `ds.character_deployed`
  - When: `ds.deploy(200, 201, 3)`
  - Then: 信号发射，载荷 (201, 3, false, deploy_turn)
  - Edge cases: is_front 由 slot_index 推导（3 → 后排 false）

- **AC-007**: remove_character 清空阵位
  - Given: 角色 101 在 slot 1，订阅 `ds.character_removed`
  - When: `ds.remove_character(101)`
  - Then: slot 1 变为 character_id=-1 + EMPTY；信号发射 (101, 1, reason)
  - Edge cases: 空位立即可用——同回合可补位（GDD 边界情况）

- **AC-008**: 前排角色始终可攻击
  - Given: 角色 101 在 slot 0（前排，READY）
  - When: `ds.is_targetable(101)`
  - Then: true
  - Edge cases: 前排无保护——AI 可直接攻击

- **AC-009**: 后排受保护
  - Given: 角色 103 在 slot 3（后排），前排 slot 0 有存活角色
  - When: `ds.is_targetable(103, false)`
  - Then: false
  - Edge cases: GDD §6 前后排规则——前排有存活时不可直接攻击后排

- **AC-010**: 前排全灭后排暴露 + front_line_breached
  - Given: 角色 103 在 slot 3（后排），前排 3 人全 DEAD，订阅 `ds.front_line_breached`
  - When: `ds.is_targetable(103, false)`
  - Then: true + `front_line_breached` 信号发射一次
  - Edge cases: 标志守卫——第二次调用不再发射（ADR §验证标准）

- **AC-011**: 穿透无视保护
  - Given: 角色 103 在 slot 3（后排），前排有存活
  - When: `ds.is_targetable(103, true)`
  - Then: true
  - Edge cases: 穿透效果（符箓/特殊功法）直接打后排（GDD §6）

- **AC-012**: 未上场角色不可攻击
  - Given: character_id 999 不在场上
  - When: `ds.is_targetable(999)`
  - Then: false
  - Edge cases: `get_character_slot` 返回 -1 → false

- **AC-013**: 阵亡角色不可攻击
  - Given: 角色 101 在 slot 0，state=DEAD
  - When: `ds.is_targetable(101)`
  - Then: false
  - Edge cases: DEAD 状态排除（ADR §前后排保护查询第 2 步）

- **AC-014**: 补位前排恢复保护
  - Given: 前排全灭后 `_front_line_breached_emitted=true`，再 deploy 补前排
  - When: `ds.is_targetable(后排角色, false)`
  - Then: false（重新受保护）
  - Edge cases: GDD 边界情况「若此时打出新角色上场补前排，前排恢复保护」；`front_line_breached` 不重复发射

- **AC-015**: Cat 2b 信号路由
  - Given: 订阅 character_deployed / character_removed / front_line_breached
  - When: 触发对应操作
  - Then: 信号均通过 `_emit_signal_safe` 路由发射（非直接 `emit_signal`）
  - Edge cases: 信号链深度 ≤2

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/deployment_system/test_deploy_targetable.gd` — must exist and pass
**Status**: [x] Created and passing (22 tests)

---

## Dependencies

- Depends on: Story 001（`_field` 数据模型 + FieldState 枚举 + `get_empty_slots`/`get_front_count`/`get_character_slot` 查询）
- Unlocks: Story 003（serialize_field 依赖 002 的 deploy/remove 完整阵位变更链路）；Story 004（mark_unavailable 与 remove_character 的协同）
