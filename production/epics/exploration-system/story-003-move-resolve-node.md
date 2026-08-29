# Story 003: move_to_node / resolve_node 节点推进

> **Epic**: exploration-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-29

## Context

**GDD**: `design/gdd/exploration-system.md`
**Requirement**: `TR-explore-003`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0014（探索系统 — Autoload + GSM 主存储 + 程序化 DAG 生成 + 信号驱动子系统委托）
**ADR Decision Summary**: move_to_node 验证链路（可达性 → 未访问 → 行动力 → 非回退）+ AP 消耗 + GSM 导航状态更新 + 信号发射。resolve_node 按节点类型分发 Cat 2b 委托信号。can_move_to 只读查询分离命令与查询。

**Engine**: Godot 4.6 | **Risk**: MEDIUM（验证链路逻辑 + AP 豁免矩阵 + 信号分发）
**Engine Notes**: 节点导航每帧 O(1) 查询（邻接表查 has）。信号通过 GSM._emit_signal_safe 路由（ADR-0007 Cat 2b）。均为 4.0+ 稳定 API。

**Control Manifest Rules (Feature 层)**:
- **Required**: move_to_node 成功后更新 GSM exploration.node_position + visited_nodes —— 来源: ADR-0014
- **Required**: 节点委托通过 Cat 2b 信号 —— 来源: ADR-0014
- **Forbidden**: can_move_to 修改任何状态 —— 来源: ADR-0014（查询 vs 命令分离）
- **Forbidden**: 事件节点在生成时分配具体事件 —— 来源: ADR-0014（到达时才触发）

---

## Acceptance Criteria

*From ADR-0014 §关键接口 + GDD §4 节点导航:*

- [ ] **AC-001**: `move_to_node(from_node, to_node)` 返回 Dictionary `{success: bool, reason: String, ap_remaining: int}`
- [ ] **AC-002**: 可达性验证——非邻接节点（graph[from] 不含 to）拒绝移动，success=false, reason="不可达"
- [ ] **AC-003**: 已访问节点拒绝移动（visited_nodes 含 to_node），success=false, reason="已访问"
- [ ] **AC-004**: 行动力不足（ap < 1 且非豁免类型）拒绝移动，success=false, reason="行动力不足"
- [ ] **AC-005**: AP=0 豁免——传送(TELEPORT)、行动力泉(ACTION_SPRING)、Boss(BOSS) 节点不消耗 AP 且行动力不足时仍可移动
- [ ] **AC-006**: 成功移动消耗 1 AP（非豁免节点），ap_remaining = ap_before - 1
- [ ] **AC-007**: 成功移动更新 GSM node_position + visited_nodes（通过第二层方法）
- [ ] **AC-008**: `can_move_to(from_node, to_node)` 只读查询——不修改任何状态，返回 bool
- [ ] **AC-009**: `resolve_node(node_id)` 按节点类型发射委托信号——EVENT→event_node_reached, COMBAT/ELITE→combat_node_reached, BOSS→boss_node_reached, SHOP/REST/ACTION_SPRING/TELEPORT/TRIBULATION→node_interaction_triggered
- [ ] **AC-010**: move_to_node 成功后自动调用 resolve_node（节点到达触发交互）
- [ ] **AC-011**: move_to_node 发射 node_moved(from, to, ap_remaining) Cat 2b 信号

---

## Implementation Notes

*Derived from ADR-0014 §关键接口 + §决策 3 信号委托 + GDD §4:*

1. **文件位置**: `src/feature/exploration_system.gd` — 新增 move_to_node / can_move_to / resolve_node 方法
2. **MoveResult 结构**: `{success: bool, reason: String, ap_remaining: int}`
3. **验证链路顺序**: 可达性 → 已访问 → 行动力（短路求值，首项失败立即返回）
4. **AP 豁免矩阵**: TELEPORT(6) / ACTION_SPRING(7) / BOSS(3) — 这三种节点不消耗 AP，行动力不足时仍可移动
5. **信号定义**（Cat 2b，遵循 ADR-0007）:
   - `node_moved(from_node: int, to_node: int, ap_remaining: int)`
   - `event_node_reached(map_pool: Array, player_realm: int)`
   - `combat_node_reached(enemy_roster: Array, combat_type: StringName)`
   - `boss_node_reached(boss_data: Dictionary)`
   - `node_interaction_triggered(node_id: int, interaction_type: StringName, payload: Dictionary)`
6. **信号路由**: 通过 GSM._emit_signal_safe（同 CombatSystem _emit_safe 模式）
7. **can_move_to 纯查询**: 复用验证逻辑但不写入、不消耗 AP、不发射信号
8. **resolve_node 分发**: match node_type → 发射对应委托信号

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 004**: DAG 缓存重建 + _dag_ready 就绪标志——本 Story 假设 _node_graph 已就绪
- **Story 005**: 事件节点分配 + 经济计算——本 Story 只发射 event_node_reached 信号，不处理事件内容
- **end_exploration 结算**: AP 耗尽结束探索——属后续 Story
- **地图选择 UI**: 节点图渲染和交互——UI Epic 职责

---

## QA Test Cases

*From ADR-0014 §验证标准 + GDD §4:*

- **AC-001**: move_to_node 返回结构
  - Given: enter_map 后处于入口节点
  - When: move_to_node(0, 100)
  - Then: 返回 {success: true, reason: "", ap_remaining: max_ap - 1}

- **AC-002**: 可达性验证
  - Given: DAG 中 0→100 有边，0→200 无边
  - When: move_to_node(0, 200)
  - Then: success=false, reason 含 "不可达"

- **AC-003**: 已访问节点
  - Given: 已移动到 100
  - When: move_to_node(100, 0)（回退到入口）
  - Then: success=false, reason 含 "已访问" 或 "回退"

- **AC-004**: 行动力不足
  - Given: ap=0, 目标节点为 COMBAT
  - When: move_to_node(from, to)
  - Then: success=false, reason 含 "行动力不足"

- **AC-005**: AP=0 豁免
  - Given: ap=0, 目标节点为 BOSS
  - When: move_to_node(from, boss_node)
  - Then: success=true, ap_remaining=0

- **AC-006**: AP 消耗
  - Given: ap=5, 目标为 COMBAT
  - When: move_to_node(from, to)
  - Then: ap_remaining=4

- **AC-007**: GSM 更新
  - Given: move_to_node 成功
  - When: 读取 GSM exploration.node_position + visited_nodes
  - Then: node_position={layer, idx} 更新，visited_nodes 含 to_node

- **AC-008**: can_move_to 只读
  - Given: 当前状态
  - When: can_move_to(from, to) 多次调用
  - Then: 返回相同结果，GSM 状态无变化

- **AC-009**: resolve_node 信号分发
  - Given: 各类型节点
  - When: resolve_node(node_id)
  - Then: 发射对应委托信号

- **AC-010**: move_to_node 自动 resolve
  - Given: move_to_node 成功
  - When: 移动完成
  - Then: 对应节点委托信号也被发射

- **AC-011**: node_moved 信号
  - Given: move_to_node 成功
  - When: 移动完成
  - Then: node_moved(from, to, ap_remaining) 信号被发射

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/exploration_system/test_move_resolve_node.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 5-1（generate_map 提供 _node_graph）；Story 5-2（GSM exploration.* 第二层方法）
- Unblocks: Story 004（缓存重建需 move_to_node 配合）；Story 005（事件分配需 resolve_node 信号）
