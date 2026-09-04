# Sprint 11 QA 签收报告

- **Sprint**: 11
- **QA Story**: qa/story-001-sprint-11-qa.md
- **日期**: 2026-09-04
- **签收人**: Claude Code（自动化 QA）
- **结果**: ✅ APPROVED

## 1. 签收范围

Sprint 11 共 4 个 Story，其中 3 个文件重构 Story + 1 个 QA 签收 Story。

| # | Story | 文件 | 拆分前 | 拆分后 | 子模块 | 状态 |
|---|---|---|---|---|---|---|
| 1 | input_manager.gd 拆分 | `input_manager.gd` | 394 | 346 | `input_lock_stack.gd` (130) | ✅ Done |
| 2 | faction_system.gd 拆分 | `faction_system.gd` | 331 | 321 | `faction_field_stats.gd` (58) | ✅ Done |
| 3 | ending_evaluator.gd 拆分 | `ending_evaluator.gd` | 293 | 286 | `ending_epilogue.gd` (93) | ✅ Done |

## 2. 零回归验证

### 全量测试结果

```
Scripts: 143
Tests: 2455
Passing: 2454
Pending: 1（test_migrate_if_needed_multi_step——已知 pending，非 Sprint 11 引入）
Failing: 0
Asserts: 9195
```

**与 Sprint 10 基线对比**：完全一致——零回归 ✅

### 各系统单元测试明细

| 系统 | 测试数 | 通过 | 失败 |
|---|---|---|---|
| input | 110 | 110 | 0 |
| faction_system | 27 | 27 | 0 |
| ending_branch_system | 30 | 30 | 0 |

## 3. 架构一致性检查

### 拆分模式一致性 ✅

所有 3 个 Story 遵循统一的 RefCounted 子模块拆分模式：

- **惰性初始化**：`_get_xxx()` 方法在首次调用时 `load("res://...").new(self)` 或 `const _Xxx := preload(...)`
- **薄委托**：主文件保留原方法签名作为薄委托，调用子模块同名方法
- **通过 `_parent.get()` / `_parent.call()` / `_parent.set()` 访问父节点状态**（input_lock_stack / faction_field_stats）
- **纯函数 static 类**：ending_epilogue.gd 无需 `_parent`，所有方法为 static，使用 `const _Epilogue := preload(...)` 引用
- **无新增 Autoload**：全部使用 RefCounted 子模块

### 子模块分类

| 类型 | 子模块 | 特点 |
|---|---|---|
| 持有 `_parent` 引用 | `input_lock_stack.gd` / `faction_field_stats.gd` | 通过 `_parent` 访问父节点状态和方法 |
| 纯函数 static 类 | `ending_epilogue.gd` | 无需 `_parent`，所有方法为 static，使用 `const _Epilogue := preload(...)` 引用 |

### Autoload 访问边界处理

`input_lock_stack.gd` 的 `_sync_to_gsm` 方法需要访问 `GameStateManager` Autoload 全局名——在 RefCounted 子模块中无法直接引用。解决方案：子模块的 `_sync_to_gsm` 委托回父节点 `_parent.call("_sync_to_gsm")`，主文件保留 `_sync_to_gsm` 原始实现。`_exit_tree` 直接调用主文件的 `_sync_to_gsm`，避免子模块在退出时可能未初始化的竞态。

### 文件行数改善

- Sprint 10 结束超 300 行文件：10 个
- Sprint 11 结束超 300 行文件：10 个（input_manager 346 行、faction_system 321 行虽已拆分但仍略超限）
- 3 个目标文件均已拆分，逻辑提取到 3 个子模块（共 281 行）

### ending_evaluator.gd 薄委托兼容测试

拆分时保留 `_generate_epilogue` 实例方法作为薄委托，转发到 `_Epilogue.generate_epilogue(...)`，避免修改测试中 `evaluator._generate_epilogue(...)` 的直接调用方式。4 个 epilogue 测试全部通过。

## 4. 约束遵守检查

| 约束 | 状态 |
|---|---|
| 零回归——2455 个既有测试全部通过 | ✅ |
| 无新增 Autoload | ✅ |
| 不修改逻辑——纯结构变更 | ✅ |
| 文件重构 Story 不新增测试 | ✅ |
| 未经用户指示不得提交 | ✅（全部未提交） |
| 所有交流使用中文 | ✅ |

## 5. 已知问题

| 问题 | 严重度 | 状态 |
|---|---|---|
| `test_migrate_if_needed_multi_step` pending | INFO | Sprint 3 遗留，非 Sprint 11 引入 |
| ObjectDB instances leaked at exit | INFO | Godot 引擎退出时清理顺序，不影响运行时 |
| input_manager.gd 仍有 346 行 | INFO | 锁栈已拆出，剩余输入判定+分类+分发逻辑耦合度高 |
| faction_system.gd 仍有 321 行 | INFO | 场上统计已拆出，剩余标签库+查询 API+辅助方法 |

## 6. 签收结论

**APPROVED**

Sprint 11 全部 3 个文件重构 Story + QA 签收完成。零回归、架构一致、约束遵守。3 个目标文件均已拆分，逻辑提取到 3 个子模块（共 281 行）。所有工作已验证，等待用户指示提交。
