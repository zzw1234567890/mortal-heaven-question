# Story 002: 导航状态 GSM exploration.* 主存储

> **Epic**: exploration-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-29

## Context

**GDD**: `design/gdd/exploration-system.md`
**Requirement**: `TR-explore-002`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0014（探索系统 — Autoload + GSM 主存储 + 程序化 DAG 生成 + 信号驱动子系统委托）
**ADR Decision Summary**: 探索导航状态（current_map、node_position、visited_nodes、action_points、max_action_points、map_states）通过 GSM exploration.* 域存储以支持存档/读档。ExplorationSystem 通过 GSM 第二层原子方法写入——绝不绕过 GSM 直接赋值。DAG 计算中间产物（_node_graph 等）作为内部成员变量不持久化。

**Engine**: Godot 4.6 | **Risk**: LOW（GSM 第二层原子写入方法——遵循 CombatSystem battle.* 域先例，模式成熟）
**Engine Notes**: GSM 第二层方法在 gsm_atomic_writes.gd 中定义，game_state_manager.gd 薄转发。exploration 域默认值在 gsm_serializer.gd 的 _get_default_for_domain 中定义。均为 4.0+ 稳定 API。

**Control Manifest Rules (Feature 层)**:
- **Required**: 探索运行时状态通过 GSM exploration.* 域存储 —— 来源: ADR-0014
- **Required**: ExplorationSystem 通过 GSM 第二层原子方法写入 exploration.* 域 —— 来源: ADR-0014
- **Forbidden**: 绕过 GSM 直接赋值 exploration.* 域字段 —— 来源: ADR-0014
- **Forbidden**: DAG 计算中间产物持久化到 GSM —— 来源: ADR-0014

---

## Acceptance Criteria

*From ADR-0014 §决策 1 状态分层模型 + §GSM 写入契约:*

- [ ] **AC-001**: GSM exploration.* 域默认值含 6 个字段：current_map(StringName)、node_position(Dictionary {layer:int, idx:int})、visited_nodes(Array)、action_points(int)、max_action_points(int)、map_states(Dictionary)
- [ ] **AC-002**: `GSM.set_exploration_map(map_id)` 设置 exploration.current_map 并重置 node_position 为入口 {layer:0, idx:0}，通过 batch_updated 传播
- [ ] **AC-003**: `GSM.set_exploration_position(layer, idx)` 更新 exploration.node_position = {layer, idx}，通过 batch_updated 传播
- [ ] **AC-004**: `GSM.add_visited_node(node_id)` 追加 node_id 到 exploration.visited_nodes（去重——已存在不追加），通过 batch_updated 传播
- [ ] **AC-005**: `GSM.set_exploration_ap(current, max_ap)` 同时设置 action_points + max_action_points，通过 batch_updated 传播
- [ ] **AC-006**: `GSM.clear_exploration_navigation()` 清除 current_map、node_position、visited_nodes 为默认值，但保留 map_states（跨地图累计数据）
- [ ] **AC-007**: `GSM.update_exploration_map_state(map_id, changes)` 合并写入 map_states[map_id] 子字段（如 entry_count、collected_ling_shi），通过 batch_updated 传播
- [ ] **AC-008**: 所有 6 个方法的写入均通过 _buffer_change 进入帧末信号缓冲管线，不直接 emit 信号
- [ ] **AC-009**: GSM.serialize() 包含完整 exploration 域，deserialize() 往返后 exploration 域字段完整等价

---

## Implementation Notes

*Derived from ADR-0014 §GSM 写入契约 + §决策 1 状态分层模型:*

1. **文件位置**:
   - `src/foundation/gsm/gsm_atomic_writes.gd` — 新增 6 个第二层方法
   - `src/foundation/game_state_manager.gd` — 新增 6 个薄转发
   - `src/foundation/gsm/gsm_serializer.gd` — 修改 _get_default_for_domain 中 exploration 域默认值
   - `src/feature/exploration_system.gd` — 新增 enter_map 胶水方法（初始化导航状态）
2. **exploration 域默认值扩展**（gsm_serializer.gd `_get_default_for_domain`）:
   - 当前: `{current_map_id, node_position, action_points, revealed_nodes, map_state}` — 旧字段
   - 目标: `{current_map, node_position, visited_nodes, action_points, max_action_points, map_states}` — ADR-0014 规范
3. **6 个 GSM 第二层方法**（gsm_atomic_writes.gd）:
   - set_exploration_map(map_id) — 设置 current_map + 重置 node_position
   - set_exploration_position(layer, idx) — 更新 node_position
   - add_visited_node(node_id) — 追加 visited_nodes（去重）
   - set_exploration_ap(current, max_ap) — 设置行动力
   - update_exploration_map_state(map_id, changes) — 合并写入 map_states[map_id]
   - clear_exploration_navigation() — 清除导航字段保留 map_states
4. **模式遵循**: _set_battle_phase / _set_battle_active 等 battle.* 域方法的先例——null 守卫、去重、_buffer_change 路由
5. **ExplorationSystem 胶水**: enter_map(map_id) 方法——调用 generate_map 后，通过 GSM 第二层方法初始化导航状态（set_exploration_map + set_exploration_ap + update_exploration_map_state(entry_count++)）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 003**: move_to_node / resolve_node 节点推进验证逻辑——本 Story 只实现 GSM 写入方法
- **Story 004**: DAG 缓存重建 + _dag_ready 就绪标志——本 Story 的 enter_map 是首次生成，重建属 Story 004
- **Story 005**: 事件节点分配 + 经济计算——本 Story 的 update_exploration_map_state 只写入导航状态，不处理经济结算
- **move_to_node 完整验证链路**: 可达性、行动力扣减、回退检测——属 Story 003

---

## QA Test Cases

*From ADR-0014 §验证标准 + §GSM 写入契约:*

- **AC-001**: exploration 域默认值验证
  - Given: GSM 初始化
  - When: 读取 exploration 域
  - Then: 含 current_map、node_position、visited_nodes、action_points、max_action_points、map_states 6 个字段

- **AC-002**: set_exploration_map
  - Given: GSM 已初始化
  - When: set_exploration_map(&"test_map")
  - Then: exploration.current_map == &"test_map", node_position == {layer:0, idx:0}

- **AC-003**: set_exploration_position
  - Given: GSM 已初始化
  - When: set_exploration_position(2, 1)
  - Then: exploration.node_position == {layer:2, idx:1}

- **AC-004**: add_visited_node
  - Given: GSM 已初始化
  - When: add_visited_node(101), add_visited_node(101), add_visited_node(102)
  - Then: visited_nodes == [101, 102]（去重）

- **AC-005**: set_exploration_ap
  - Given: GSM 已初始化
  - When: set_exploration_ap(8, 10)
  - Then: action_points == 8, max_action_points == 10

- **AC-006**: clear_exploration_navigation
  - Given: exploration 域有导航数据 + map_states
  - When: clear_exploration_navigation()
  - Then: current_map/visited_nodes 重置，map_states 保留

- **AC-007**: update_exploration_map_state
  - Given: GSM 已初始化
  - When: update_exploration_map_state(&"test_map", {entry_count: 1})
  - Then: map_states[&"test_map"] == {entry_count: 1}

- **AC-008**: batch_updated 传播
  - Given: 订阅 batch_updated
  - When: 调用任一写入方法 + await 帧末
  - Then: batch_updated 信号携带 exploration.* 路径的变更

- **AC-009**: 序列化往返
  - Given: exploration 域有数据
  - When: serialize() → deserialize()
  - Then: exploration 域所有字段完整等价

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/gsm/test_exploration_domain.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 5-1（generate_map 提供 DAG 结构）；GSM exploration.* 域（ADR-0001 已注册，本 Story 扩展默认值）
- Unblocks: Story 003（move_to_node 需要 set_exploration_position / add_visited_node）；Story 004（缓存重建需要 set_exploration_map）；Story 005（update_exploration_map_state 用于经济计算）
