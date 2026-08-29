# Story 004: DAG 缓存重建 + _dag_ready 就绪标志

> **Epic**: exploration-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-29

## Context

**GDD**: `design/gdd/exploration-system.md`
**Requirement**: `TR-explore-004`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0014（探索系统 — Autoload + GSM 主存储 + 程序化 DAG 生成 + 信号驱动子系统委托）
**ADR Decision Summary**: 读档后 ExplorationSystem 检测 GSM.exploration.current_map 非空 → 从 map_state 重建 _node_graph + _node_details。DAG 计算中间产物不持久化——读档后从 map_state 重建。_dag_ready 标志保护边缘情况（UI 早期调用）。

**Engine**: Godot 4.6 | **Risk**: MEDIUM（读档后 DAG 重建 + _dag_ready 竞态保护）
**Engine Notes**: _ready() 中同步重建 DAG（<5ms）。Autoload _ready() 顺序：GSM(1) → ... → ExplorationSystem(14)。GSM 必然先就绪。均为 4.0+ 稳定 API。

**Control Manifest Rules (Feature 层)**:
- **Required**: DAG 计算中间产物作为内部成员变量不持久化 —— 来源: ADR-0014
- **Required**: 读档后从 map_state 重建 DAG 缓存 —— 来源: ADR-0014
- **Forbidden**: 持久化 _node_graph / _node_details / _reachable_cache 到 GSM —— 来源: ADR-0014

---

## Acceptance Criteria

*From ADR-0014 §决策 1 状态分层模型 + R7 _dag_ready 标志:*

- [ ] **AC-001**: `_dag_ready` 成员变量，初始 false，`_ready()` 末尾设为 true
- [ ] **AC-002**: `_ready()` 检测 GSM.exploration.current_map 非空（非 &""）→ 触发 `rebuild_dag_cache()` 从 map_state 重建
- [ ] **AC-003**: `rebuild_dag_cache(map_id, map_data)` 从已有 graph/nodes 数据重建 _node_graph + _node_details + _map_config
- [ ] **AC-004**: `move_to_node` / `can_move_to` / `resolve_node` 在 `_dag_ready == false` 时拒绝（返回错误或 false）
- [ ] **AC-005**: `clear_dag_cache()` 清理 _node_graph / _node_details / _reachable_cache / _map_config 并设 _dag_ready = false
- [ ] **AC-006**: 重建后 _node_graph + _node_details 与原始 generate_map 结果等价（通过注入相同 graph/nodes 数据验证）
- [ ] **AC-007**: 无活跃地图时（current_map == &""）`_ready()` 不触发重建，_dag_ready = true
- [ ] **AC-008**: `enter_map` 成功后 _dag_ready = true（generate_map 已填充缓存）

---

## Implementation Notes

*Derived from ADR-0014 §决策 1 状态分层模型 + R7 _dag_ready 标志:*

1. **文件位置**: `src/feature/exploration_system.gd` — 新增 _dag_ready + rebuild_dag_cache + clear_dag_cache + _ready
2. **_dag_ready 标志**: bool 成员，初始 false。所有公共入口方法检查此标志
3. **_ready() 流程**:
   - 检测 GSM.exploration.current_map 非空
   - 非空 → 从 GSM map_states 读取缓存的 graph/nodes → rebuild_dag_cache
   - 为空 → 跳过重建
   - 末尾设 _dag_ready = true
4. **rebuild_dag_cache(map_id, map_data)**: 直接从 map_data 参数重建 _node_graph + _node_details + _map_config
5. **clear_dag_cache()**: 清理所有内部缓存 + _dag_ready = false
6. **DAG 数据持久化策略**: Story 5-2 的 update_exploration_map_state 可存储 graph/nodes 快照到 map_states[map_id]——本 Story 的 _ready() 读取该快照重建
7. **enter_map 修改**: generate_map 成功后 _dag_ready = true（缓存已填充）
8. **公共方法守卫**: move_to_node / can_move_to / resolve_node 在 _dag_ready == false 时返回错误

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 005**: 事件节点分配 + 经济计算——本 Story 只重建缓存结构，不处理内容
- **end_exploration**: 探索结束结算——后续 Story
- **map_states 中 graph/nodes 快照写入**: 本 Story 只读取，写入逻辑在 enter_map 中扩展

---

## QA Test Cases

*From ADR-0014 §决策 1 状态分层模型 + R7:*

- **AC-001**: _dag_ready 初始 false
  - Given: ExplorationSystem 新实例
  - When: 读取 _dag_ready
  - Then: false

- **AC-002**: _ready() 检测 current_map 非空
  - Given: GSM exploration.current_map = &"test_map" + map_states 含 graph/nodes
  - When: _ready() 执行
  - Then: _node_graph / _node_details 已重建，_dag_ready = true

- **AC-003**: rebuild_dag_cache 从数据重建
  - Given: map_data = {graph, nodes, layers, boss_node_id, path_count}
  - When: rebuild_dag_cache(map_id, map_data)
  - Then: _node_graph == graph, _node_details == nodes

- **AC-004**: 公共方法 _dag_ready 守卫
  - Given: _dag_ready = false
  - When: move_to_node / can_move_to / resolve_node
  - Then: 返回错误/false

- **AC-005**: clear_dag_cache
  - Given: 有缓存的 ExplorationSystem
  - When: clear_dag_cache()
  - Then: _node_graph / _node_details 为空，_dag_ready = false

- **AC-006**: 重建后等价
  - Given: generate_map 产生 graph G
  - When: clear_dag_cache() → rebuild_dag_cache(map_id, {graph: G, nodes: N, ...})
  - Then: _node_graph == G, _node_details == N

- **AC-007**: 无活跃地图不重建
  - Given: GSM exploration.current_map = &""
  - When: _ready() 执行
  - Then: _node_graph 为空，_dag_ready = true

- **AC-008**: enter_map 后 _dag_ready
  - Given: enter_map 成功
  - When: 读取 _dag_ready
  - Then: true

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/exploration_system/test_dag_cache_rebuild.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 5-1（generate_map）；Story 5-2（GSM exploration.* map_states）；Story 5-3（move_to_node 等公共方法）
- Unblocks: Story 005（事件分配需要 DAG 缓存就绪）；探索→战斗→探索往返场景恢复
