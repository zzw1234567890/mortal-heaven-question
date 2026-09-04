# Story 2：ai_system.gd 拆分

- **Epic**: file-refactor
- **Sprint**: 10
- **状态**: Done
- **预估**: 1.0d

## 目标

将 `ai_system.gd`（583 行）中的敌方阵容工厂逻辑（模板→实例、阵位分配、难度缩放、预配置绑定注册）提取到 `ai_roster_factory.gd` RefCounted 子模块，主文件降至 466 行。

## 拆分内容

| 提取到 `ai_roster_factory.gd` (236 行) | 保留在 `ai_system.gd` (466 行) |
|---|---|
| `create_state` / `_create_by_id` | 信号声明 + 常量 + 状态字段 |
| `create_enemy_roster` | `load_templates` 模板加载 |
| `_assign_positions` / `_compare_by_defense_desc` / `_compare_by_attack_desc` | 查询 API（`get_template_count` / `has_template` / `get_template`）|
| `_apply_difficulty_scaling` / `_apply_difficulty_scaling_to_roster` | 决策引擎委托（`execute_turn` / `_decide_*` / `_evaluate_skills` 等）|
| `register_preconfigured_bindings` / `remove_enemy_bindings` | BossPhaseMgr 委托 |
| `_EnemyBattleState` / `_EnemyTemplate` preload 常量 | 辅助方法（`_get_behavior_profile` / `_is_alive` 等）|
| | `_emit_safe` + `_get_decision_engine()` / `_get_boss_phases()` / `_get_roster_factory()` 惰性初始化 + 薄委托 |

## 架构特点

- **持有 `_parent` 引用**：子模块通过 `_init(parent)` 构造注入，通过 `_parent.get()` / `_parent.call()` 访问父节点状态（`_template_registry` / `_enemy_roster` / `FRONT_CAPACITY` / `BACK_CAPACITY`）。
- **自有 preload 常量**：子模块自行 `preload` `_EnemyBattleState` 和 `_EnemyTemplate`，避免通过 `_parent.get()` 传递 Resource 常量。
- **惰性初始化**：`_get_roster_factory()` 在首次调用时 `load("res://src/feature/ai/ai_roster_factory.gd").new(self)`。
- **薄委托**：主文件保留 9 个方法签名作为薄委托（`create_state` / `_create_by_id` / `create_enemy_roster` / `_assign_positions` / `_compare_by_defense_desc` / `_compare_by_attack_desc` / `_apply_difficulty_scaling` / `_apply_difficulty_scaling_to_roster` / `register_preconfigured_bindings` / `remove_enemy_bindings`）。
- **无新增 Autoload**：RefCounted 子模块。

## 风险与处理

- **风险等级**：中——工厂逻辑涉及 BindingManager 调用，但测试通过公共方法间接调用。
- **处理方式**：纯结构变更，不修改逻辑。`_compare_by_defense_desc` / `_compare_by_attack_desc` 比较器作为薄委托保留在主文件（`sort_custom` 传入函数引用）。

## 验证

- ai_system 单元测试：101/101 passed（4 scripts）
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing / 9195 asserts
- 零回归 ✓

## 完成定义

- [x] `ai_roster_factory.gd` 子模块创建（236 行）
- [x] `ai_system.gd` 主文件修改（466 行）
- [x] ai_system 单元测试全部通过（101/101）
- [x] 全量测试零回归（2455 tests / 0 failing）
- [x] 无新增 Autoload
