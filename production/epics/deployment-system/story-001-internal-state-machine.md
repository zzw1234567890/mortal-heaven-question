# Story 001: 内部状态机 + 阵位数据管理（STANDBY→READY→ACTED）

> **Epic**: deployment-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**:

## Context

**GDD**: `design/gdd/deployment-system.md`
**Requirement**: `TR-deploy-001`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0016（上场阵位系统——Feature 层 Autoload + 内部状态机 + GSM 快照持久化）
**ADR Decision Summary**: DeploymentSystem 实现为 Feature 层 Autoload #17，采用内部状态机管理阵位数据。阵位分布、角色在场状态、待命/已就绪标记均在内部 Dictionary 中管理——战斗期间阵位数据不经过 GSM。内部状态机：STANDBY（待命）→ READY（已就绪）→ ACTED（已行动）→ 回合结束 → READY；DEAD → 空位。上场人数上限 `max_deploy = L + 1` 通过 `RealmSystem.get_realm_property(level, &"max_deploy")` 查询，不自行维护映射。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 不依赖 4.4+ 新特性——Dictionary 键查找、signal 发射、enum 状态机均为 4.0+ 稳定 API。`is_targetable()` 热路径 O(1) 查询 <0.01ms（本 story 不含，属 story-002）。

**Control Manifest Rules (Feature 层)**:
- **Required**: DeploymentSystem 是 Autoload —— 6 固定阵位（前 3 + 后 3）、`max_deploy = L + 1`（来源 ADR-0016）
- **Required**: 待命规则——上场角色在部署回合标记为「待命」STANDBY——不可攻击（来源 ADR-0016）
- **Forbidden**: 绝不战中移动角色前后排位置——阵位调整仅在备战阶段（来源 ADR-0016）
- **Guardrail**: `deploy()` 单次 <0.3ms（来源 ADR-0016）

---

## Acceptance Criteria

*From GDD deployment-system.md §验收标准 + ADR-0016 §验证标准:*

- [ ] **AC-001**: `setup_field(character_ids, {})` 炼气期（max_deploy=2）传入 2 人 → 自动分配为前 2 后 0（slot 0、1 前排，slot 2-5 空位）
- [ ] **AC-002**: `setup_field(character_ids, {})` 金丹期（max_deploy=4）传入 4 人 → 自动分配为前 2 后 2
- [ ] **AC-003**: `setup_field(character_ids, {})` 化神期（max_deploy=6）传入 6 人 → 全 6 阵位填满（前 3 后 3）
- [ ] **AC-004**: `setup_field(character_ids, {})` 金丹期（max_deploy=4）只传 3 人 → 返回 true，允许以 3 人开始战斗（前 2 后 1）
- [ ] **AC-005**: `setup_field([], {})` 空数组（一个角色都没选）→ 返回 false（"至少选择 1 个角色上场"）
- [ ] **AC-006**: `setup_field(character_ids, layout)` 传入手动 layout（{char_id: is_front}）→ 手动分配覆盖自动填充
- [ ] **AC-007**: `setup_field(character_ids, {})` 传入人数超过 max_deploy → 返回 false
- [ ] **AC-008**: `is_front` 判定——slot_index ∈ [0,2] 为前排（true），slot_index ∈ [3,5] 为后排（false）
- [ ] **AC-009**: `setup_field` 后所有上场角色 state == STANDBY（第 1 回合不可攻击）
- [ ] **AC-010**: `is_standby(character_id)` 对 STANDBY 角色返回 true；对 READY 角色返回 false；对不在场上角色返回 false
- [ ] **AC-011**: `set_acted(character_id)` 将 READY 角色 → ACTED（攻击后由 CombatSystem 调用）
- [ ] **AC-012**: `get_field()` 返回按 slot_index 排序的 Array[Dictionary]，每个 Dictionary 含 slot_index/character_id/is_front/state/deploy_turn；空位为 character_id=-1 + state=EMPTY
- [ ] **AC-013**: `get_character_slot(character_id)` 返回角色所在 slot_index；未上场返回 -1
- [ ] **AC-014**: `get_front_count(true)` 返回前排存活角色数；`get_front_count(false)` 返回前排占用数（含阵亡）
- [ ] **AC-015**: `get_empty_slots()` 返回空位 slot_index 列表——前排优先排序（0,1,2,3,4,5 顺序）
- [ ] **AC-016**: `can_deploy()` 返回 {can_deploy: bool, empty_slots: int, max_deploy: int, reason: String}——有 2 个空位 + 未满 → can_deploy=true, empty_slots=2
- [ ] **AC-017**: `setup_field` 时重置 `_front_line_breached_emitted = false`（战斗边界标志重置）
- [ ] **AC-018**: DeploymentSystem extends Node，不声明 `class_name`（Autoload 固有权衡——同 CostSystem/StatusEffectSystem 模式）

---

## Implementation Notes

*Derived from ADR-0016 §决策 §关键接口 §阵位数据模型:*

1. **文件位置**: `src/feature/deployment_system.gd`（Feature 层，Autoload #17——在 ResourceSystem #16 之后、AISystem #18 之前）
2. **类声明**: `extends Node`（不声明 class_name——Autoload 固有权衡）
3. **FieldState 枚举**: `enum FieldState { EMPTY = 0, STANDBY = 1, READY = 2, ACTED = 3, DEAD = 4 }`
4. **阵位数据模型**: `_field: Dictionary[int, Dictionary]`——key=slot_index（0-5），value={character_id: int, is_front: bool, deploy_turn: int, state: FieldState}。空位为 {character_id: -1, is_front: bool, deploy_turn: -1, state: EMPTY}
5. **slot_index 编码**: 0=前1, 1=前2, 2=前3, 3=后1, 4=后2, 5=后3。`is_front = slot_index ∈ [0, 2]`
6. **自动分配算法 `_auto_assign_slots`**: slot_order = [0,1,2,3,4,5]（前排优先），依次赋值 {character_id: slot_index}
7. **max_deploy 查询**: 通过 `RealmSystem.get_realm_property(level, &"max_deploy")` 获取——战斗开始时缓存，不自行维护境界→人数映射（L+1 公式在 RealmSystem 中）
8. **setup_field 实现**: 验证人数 ≤ max_deploy → 验证非空 → 验证所有角色「可用」→ 自动/手动分配 → 所有角色标记 STANDBY → 重置 `_front_line_breached_emitted = false`
9. **get_field 实现**: 遍历 6 个 slot，按 slot_index 升序，每项含 slot_index/character_id/is_front/state/deploy_turn
10. **is_standby 实现**: O(1)——`get_character_slot()` + `_field[slot].state == STANDBY`
11. **set_acted 实现**: READY → ACTED（其他状态不变）
12. **测试模式**: `DS_SCRIPT.new()` 构造实例，`var ds: Node` 持有 + 动态分派，返回值显式类型注解（Foundation/Feature Autoload 测试模式）
13. **信号**: 本 story 不发射信号（Cat 2b 信号 6 个属 story-002/story-004）。`character_deployed` 在 setup_field/deploy 中发射——deploy 属 story-002，故 setup_field 的 character_deployed 发射也暂缓至 story-002 统一实现（或本 story 仅做桩，待 story-002 补全）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: `deploy()` 战中补位 + `remove_character()` 阵亡清位 + `is_targetable()` 前后排保护 O(1) 查询 + `front_line_breached` 信号
- **Story 003**: `serialize_field()` / `deserialize_field()` 战斗结束快照导出 + `sync_unavailable_to_gsm()` / `load_unavailable_from_gsm()` GSM 同步
- **Story 004**: `clear_standby_state()` 回合结束待命清除 + `mark_unavailable()` / `revive_character()` / `get_unavailable_characters()` / `is_game_over()` 不可用角色生命周期
- **CombatSystem 集成**: `battle_start()` 调用 `setup_field()`、Phase 2 调用 `deploy()`、Phase 6 调用 `clear_standby_state()` ——战斗 Epic（ADR-0008）职责
- **RealmSystem `max_deploy` 属性**: L+1 公式的真理来源在 RealmSystem（ADR-0010）——本 story 仅查询，不实现公式
- **CombatUI 阵位显示**: 订阅 Cat 2b 信号更新阵位状态——战斗 UI Epic 职责

---

## QA Test Cases

*From ADR-0016 §验证标准 + GDD deployment-system.md §验收标准/§边缘情况:*

- **AC-001**: 炼气期自动分配前 2 后 0
  - Given: ds 实例已创建，max_deploy=2
  - When: `ds.setup_field([101, 102], {})`
  - Then: 返回 true；slot 0/1 为 character_id 101/102 且 is_front=true；slot 2-5 为 character_id=-1 + EMPTY
  - Edge cases: 2 人全部前排（无后排保护——GDD §2 规则）

- **AC-002**: 金丹期自动分配前 2 后 2
  - Given: max_deploy=4
  - When: `ds.setup_field([101,102,103,104], {})`
  - Then: slot 0/1 前排 + slot 3/4 后排（is_front=false）；slot 2、5 空位
  - Edge cases: 前排队列填满后才填后排（GDD §2 关键规则）

- **AC-003**: 化神期满阵分配
  - Given: max_deploy=6
  - When: `ds.setup_field([101,102,103,104,105,106], {})`
  - Then: 6 阵位全填满，前 3 后 3；`get_empty_slots()` 返回空数组
  - Edge cases: 满阵后 can_deploy=false

- **AC-004**: 上场人数可少于上限
  - Given: max_deploy=4
  - When: `ds.setup_field([101,102,103], {})`
  - Then: 返回 true；前 2 后 1（slot 0/1 前排 + slot 3 后排）；slot 2、4、5 空位
  - Edge cases: 玩家主动少带人（GDD 边界情况「上场人数不足上限」）

- **AC-005**: 空选择拒绝
  - Given: ds 实例已创建
  - When: `ds.setup_field([], {})`
  - Then: 返回 false（至少选择 1 个角色上场）
  - Edge cases: 阵位全空置（GDD 边界情况「所有阵位空置」）

- **AC-006**: 手动布局覆盖自动分配
  - Given: max_deploy=4
  - When: `ds.setup_field([101,102,103,104], {101: false, 102: false})`
  - Then: 101/102 被放后排，103/104 按自动分配补前 2 个空位（前排）
  - Edge cases: layout 仅指定部分角色，未指定角色自动前排优先

- **AC-007**: 人数超上限拒绝
  - Given: max_deploy=4
  - When: `ds.setup_field([101,102,103,104,105], {})`
  - Then: 返回 false
  - Edge cases: 人数上限不可突破（GDD §2 关键规则）

- **AC-008**: is_front 边界判定
  - Given: ds 实例已创建
  - When: 检查 slot 0/1/2 vs 3/4/5 的 is_front
  - Then: 0/1/2 → true；3/4/5 → false
  - Edge cases: slot_index 边界 2（前排末）与 3（后排首）

- **AC-009**: setup_field 后全部 STANDBY
  - Given: `ds.setup_field([101,102], {})`
  - When: `ds.get_field()`
  - Then: 所有上场角色 state == STANDBY
  - Edge cases: 战前部署角色第 1 回合也遵守待命规则（GDD §5）

- **AC-010**: is_standby 查询
  - Given: STANDBY 角色 101 + READY 角色 102 + 未上场角色 999
  - When: `ds.is_standby(101)` / `ds.is_standby(102)` / `ds.is_standby(999)`
  - Then: true / false / false
  - Edge cases: O(1) 查询——攻击声明阶段排除待命角色

- **AC-011**: set_acted 状态转换
  - Given: 角色 101 处于 READY
  - When: `ds.set_acted(101)`
  - Then: `_field[slot].state == ACTED`
  - Edge cases: 对非 READY 角色（STANDBY/DEAD/EMPTY）调用不改变状态

- **AC-012**: get_field 结构与排序
  - Given: 已 setup_field 3 人
  - When: `ds.get_field()`
  - Then: 返回 6 项按 slot_index 升序；每项含 slot_index/character_id/is_front/state/deploy_turn；空位 character_id=-1 + state=EMPTY
  - Edge cases: 空位 deploy_turn=-1

- **AC-013**: get_character_slot 查询
  - Given: 角色 101 在 slot 2
  - When: `ds.get_character_slot(101)` / `ds.get_character_slot(999)`
  - Then: 2 / -1
  - Edge cases: O(n) 遍历（n≤6）

- **AC-014**: get_front_count 存活/占用计数
  - Given: 前排 3 人其中 1 人 DEAD
  - When: `ds.get_front_count(true)` / `ds.get_front_count(false)`
  - Then: 2 / 3
  - Edge cases: 前排全灭时 alive_only=true 返回 0（触发 front_line_breached 判定——story-002）

- **AC-015**: get_empty_slots 前排优先
  - Given: slot 2、5 为空
  - When: `ds.get_empty_slots()`
  - Then: [2, 5]（前排空位优先于后排）
  - Edge cases: 前排优先排序（0,1,2 先于 3,4,5）

- **AC-016**: can_deploy 结果结构
  - Given: max_deploy=6，已上场 4 人
  - When: `ds.can_deploy()`
  - Then: {can_deploy: true, empty_slots: 2, max_deploy: 6, reason: "..."}
  - Edge cases: 满员时 can_deploy=false + empty_slots=0

- **AC-017**: front_line_breached 标志重置
  - Given: 上一场战斗 `_front_line_breached_emitted` 已置 true
  - When: `ds.setup_field([...], {})`
  - Then: `_front_line_breached_emitted == false`
  - Edge cases: ADR 风险——标志位残留导致误判（缓解在 setup_field 重置）

- **AC-018**: extends Node + 不声明 class_name
  - Given: DeploymentSystem 脚本已加载
  - When: 检查 `DS_SCRIPT.get_instance_base_type()` 和 `get_global_name()`
  - Then: base type == "Node" + global_name == &""
  - Edge cases: 动态分派 `var ds: Node = DS_SCRIPT.new()`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/deployment_system/test_internal_state_machine.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 无（仅依赖 RealmSystem 查询 `max_deploy` + CardSystem 角色模板查询，均已就绪。CombatSystem/BindingManager 集成属后续 story）
- Unlocks: Story 002（deploy/remove/is_targetable 依赖 001 的阵位数据模型 + FieldState 枚举）；Story 004（clear_standby_state 依赖 001 的状态机）
