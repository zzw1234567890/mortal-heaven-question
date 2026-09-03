# Story 001：exploration_system.gd 拆分

> **Epic**: file-refactor
> **Story**: 001
> **Type**: Refactor
> **Status**: Done
> **Estimate**: 1.0d

## 描述

将 exploration_system.gd（1009 行）的 DAG 生成算法提取到 `exploration_dag_builder.gd`（RefCounted 子模块），经济计算提取到 `exploration_economy.gd`（RefCounted 子模块）。主文件保留枚举/常量/导航/GSM 状态管理/结算逻辑，通过薄委托方法调用子模块。

## 验收标准

| # | AC |
|---|---|
| 1 | exploration_dag_builder.gd 提取 DAG 生成算法（generate_map / _build_edges / _add_cross_edges / _count_vertex_disjoint_paths / _bfs_path / _assign_node_types / _fill_node_content） |
| 2 | exploration_economy.gd 提取经济计算（calculate_reentry_cost / calculate_map_clear_rewards / realm_gap_penalty / _get_difficulty_from_config） |
| 3 | 主文件通过薄委托方法调用子模块 |
| 4 | 常量保留在主文件（测试通过 es.get 访问） |
| 5 | 全量测试零回归 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/exploration_system.gd` | 主文件 1009→680 行，薄委托 |
| `src/feature/exploration/exploration_dag_builder.gd` | DAG 生成算法 328 行 |
| `src/feature/exploration/exploration_economy.gd` | 经济计算 90 行 |
