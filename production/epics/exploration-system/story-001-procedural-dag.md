# Story 001: 程序化 DAG 地图生成（generate_map）

> **Epic**: exploration-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1.0d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-29

## Context

**GDD**: `design/gdd/exploration-system.md`
**Requirement**: `TR-explore-001`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0014（探索系统 — Autoload + GSM 主存储 + 程序化 DAG 生成 + 信号驱动子系统委托）
**ADR Decision Summary**: 地图节点图完全程序化生成——加权随机分配节点类型 + 确定性边连接 + 后处理约束验证（精英/商店数、独立路径 ≥2）。使用独立 RNG 实例，seed 来自 GSM.meta.seed 确保确定性。DAG 结构纯 Dictionary/Array 格式保证 JSON 可序列化。

**Engine**: Godot 4.6 | **Risk**: MEDIUM（DAG 生成算法 + 边连接连通性保证 + 独立路径验证——非简单 API 调用）
**Engine Notes**: DAG 生成在地图加载时执行（非每帧），100-200 节点图生成预计 <5ms。使用 `RandomNumberGenerator`、`Dictionary`/`Array` 数据结构——4.0+ 稳定 API。

**Control Manifest Rules (Feature 层)**:
- **Required**: 探索运行时状态通过 GSM exploration.* 域存储 —— 来源: ADR-0014
- **Required**: DAG 计算中间产物作为内部成员变量不持久化 —— 来源: ADR-0014
- **Required**: 使用独立 RNG 实例 + seed 来自 GSM.meta.seed —— 来源: ADR-0014
- **Forbidden**: 绝不在事件节点生成时分配具体事件——到达时才触发 —— 来源: ADR-0014

---

## Acceptance Criteria

*From ADR-0014 §决策 2 程序化 DAG 生成 + GDD §2-3 节点图布局与生成流程:*

- [ ] **AC-001**: `generate_map(map_id, player_realm)` 返回 DAG 图结构 Dictionary，含 `graph`(邻接表) / `nodes`(节点详情) / `layers`(每层节点数) / `boss_node_id` / `path_count`
- [ ] **AC-002**: 图层数 4-6（含入口层 0 和 Boss 层末层），由地图难度配置决定（低=4/中=5/高=5/极高=6）
- [ ] **AC-003**: 第 0 层固定 1 个入口节点，末层固定 1 个 Boss 节点
- [ ] **AC-004**: 中间层节点数 2-4（随机），由地图难度配置的 min_nodes/max_nodes 决定
- [ ] **AC-005**: 节点类型加权随机分配（战斗 40/事件 30/商店 15/回复 10/精英 5），入口=Boss 固定类型
- [ ] **AC-006**: 精英/商店数量不超过地图难度配置上限——超限时重新加权随机分配其他类型
- [ ] **AC-007**: 每层每个节点至少连接上层 1 个节点——无孤儿节点
- [ ] **AC-008**: 至少 2 条顶点不相交路径可达 Boss 节点——不满足时添加交叉边（最多 3 次），仍不满足则重新生成（最多 2 次重试）
- [ ] **AC-009**: 同一 seed + 同一 map_id + 同一 entry_count 生成同一节点图（确定性）
- [ ] **AC-010**: DAG 结构为纯 Dictionary/Array 格式——可通过 JSON.stringify 序列化
- [ ] **AC-011**: 事件节点不分配具体事件——仅记录 event_pool（到达时才触发）
- [ ] **AC-012**: 战斗节点在生成时分配敌人阵容（通过注入回调或桩）
- [ ] **AC-013**: 商店节点在生成时分配库存（通过注入回调或桩）

---

## Implementation Notes

*Derived from ADR-0014 §决策 2 + GDD §3 地图生成流程:*

1. **文件位置**: `src/feature/exploration_system.gd`（新建——本 Story 创建 ExplorationSystem Autoload 骨架 + generate_map 方法）
2. **ExplorationSystem Autoload 骨架**:
   - `extends Node` 不声明 class_name（同 CombatSystem/DeploymentSystem 先例）
   - 不注册进 project.godot——待各系统接线后统一注册（5-0b 终验）
   - 内部状态：`_node_graph`、`_node_details`、`_reachable_cache`、`_map_config`、`_rng`
3. **generate_map 流程**（6 个 Phase，ADR-0014 §决策 2 伪代码）：
   - Phase 1：读取地图配置（从 RealmSystem 或注入回调获取层数/节点数/权重）
   - Phase 2：生成 DAG 骨架（每层随机节点数，入口/Boss 层固定 1）
   - Phase 3：加权随机分配节点类型（排除超限类型）
   - Phase 4：边连接 + 连通性验证 + ≥2 独立路径
   - Phase 5：填充节点内容（战斗=敌人阵容、事件=pool、商店=库存）
   - Phase 6：返回图结构 Dictionary
4. **节点类型枚举**: ENTRY=0 / COMBAT=1 / ELITE=2 / BOSS=3 / EVENT=4 / SHOP=5 / TELEPORT=6 / ACTION_SPRING=7 / REST=8 / TRIBULATION=9
5. **地图难度配置**: 低/中/高/极高 四档，含 layers / min_nodes / max_nodes / elite_count / shop_count / event_count / weights
6. **独立路径验证**: 使用 BFS/DFS 从入口到 Boss 计算顶点不相交路径数（最大流简化版）
7. **确定性 RNG**: seed = GSM.meta.seed XOR map_id.hash() XOR entry_count——确保同输入同输出
8. **可注入回调**: `get_map_config_cb`、`generate_enemy_roster_cb`、`get_event_pool_cb`、`generate_shop_inventory_cb`——桩模式同 CombatSystem 的 validate_targets_cb / resolve_cb

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: 导航状态 GSM exploration.* 域写入——本 Story 只生成 DAG 结构，不写入 GSM
- **Story 003**: move_to_node / resolve_node 节点推进——本 Story 只生成图，不处理导航
- **Story 004**: DAG 缓存重建——本 Story 的 generate_map 是首次生成，重建属 Story 004
- **Story 005**: 事件节点分配与经济计算——本 Story 仅记录 event_pool，不触发事件
- **地图选择 UI**: 地图选择界面渲染——UI Epic 职责
- **敌人阵容生成**: AISystem.create_enemy_roster——通过回调注入，本 Story 不实现具体生成逻辑

---

## QA Test Cases

*From ADR-0014 §验证标准 + GDD §2-3:*

- **AC-001**: generate_map 返回结构验证
  - Given: 注入低难度地图配置
  - When: `generate_map("test_map", 1)`
  - Then: 返回 Dictionary 含 graph/nodes/layers/boss_node_id/path_count 5 个键
  - Edge cases: 空 map_id 拒绝

- **AC-002**: 层数 4-6
  - Given: 四档难度配置
  - When: 分别调用 generate_map
  - Then: 低=4 层、中=5 层、高=5 层、极高=6 层

- **AC-003**: 入口/Boss 固定
  - Given: 任意地图配置
  - When: generate_map
  - Then: 第 0 层 1 节点类型=ENTRY，末层 1 节点类型=BOSS

- **AC-004**: 中间层节点数 2-4
  - Given: 中难度配置 min=2 max=4
  - When: generate_map 多次
  - Then: 中间层节点数 ∈ [2,4]

- **AC-005**: 加权随机分配
  - Given: 权重 {combat:40, event:30, shop:15, rest:10, elite:5}
  - When: generate_map 多次（100 次）
  - Then: 节点类型分布近似权重比（±15% 容差）

- **AC-006**: 精英/商店不超限
  - Given: 低难度 elite_count=1 shop_count=1
  - When: generate_map
  - Then: 精英 ≤1，商店 ≤1

- **AC-007**: 无孤儿节点
  - Given: 任意生成图
  - When: 遍历所有节点
  - Then: 每个节点（除入口）至少有 1 个上层父连接

- **AC-008**: ≥2 独立路径
  - Given: 任意生成图
  - When: 计算入口到 Boss 的顶点不相交路径数
  - Then: path_count ≥ 2

- **AC-009**: 确定性
  - Given: 同一 seed + map_id + entry_count
  - When: generate_map 两次
  - Then: 生成完全相同的图结构

- **AC-010**: JSON 可序列化
  - Given: 生成图
  - When: JSON.stringify(graph)
  - Then: 成功序列化无报错，JSON.parse 可还原

- **AC-011**: 事件节点不分配具体事件
  - Given: 生成含事件节点的图
  - When: 检查事件节点详情
  - Then: 含 event_pool 键，不含具体 event_template_id

- **AC-012**: 战斗节点分配敌人
  - Given: 注入 generate_enemy_roster_cb
  - When: generate_map
  - Then: 战斗节点含 enemy_roster 键

- **AC-013**: 商店节点分配库存
  - Given: 注入 generate_shop_inventory_cb
  - When: generate_map
  - Then: 商店节点含 inventory 键

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/exploration_system/test_procedural_dag.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: ADR-0014（探索系统架构决策）；RealmSystem（地图配置——通过回调注入，桩阶段不依赖）；GSM（meta.seed——通过回调或测试桩注入）
- Unblocks: Story 002（GSM 存储需要 DAG 结构）；Story 003（节点推进需要图结构）；Story 004（缓存重建需要 generate_map 逻辑）；Story 005（事件分配需要节点图）
