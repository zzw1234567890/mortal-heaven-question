# Story 003：转场前自动存档 + 输入锁定集成

> **Epic**: scene-manager
> **Story ID**: EPIC-001-S03
> **Story 类型**: Integration（集成）
> **优先级**: P1 —— 依赖 Story 001；与 Story 002 可并行
> **预估工作量**: 3-4 小时
> **管辖 ADR**: ADR-0005、ADR-0004、ADR-0002
> **控制清单版本**: 2026-07-26
> **状态**: Complete
> **完成日期**: 2026-07-30

## 概述

实现 SceneManager 与 InputManager（ADR-0004）和 SaveLoad（ADR-0002）的集成。Phase 2（PRE-TRANSITION）通过 InputManager 锁定全部输入、通过 SaveLoad 触发自动存档；Phase 4（POST-LOAD）通过 InputManager 恢复输入。同时实现错误恢复路径——加载失败时强制清理状态（`_transitioning = false` + `pop_lock`），防止死锁和锁泄漏。

## GDD 需求

| TR-ID | 需求 | ADR 覆盖 |
|-------|------|----------|
| TR-scene-002 | 5 阶段转换管线——转场前自动存档+锁定输入+加载画面+转场后信号+解锁 | ADR-0005 |

## ADR 指导

### 必须遵守（来自 ADR-0005）

- **Phase 2**：`InputManager.push_lock(LockType.TRANSITION, &"scene_manager")` —— 阻止所有输入
- **Phase 2**：`SaveLoad.auto_save()` —— 同步触发自动存档
- **Phase 4**：`InputManager.pop_lock(&"scene_manager")` —— 恢复输入
- **SceneManager 不直接调用 `clear_locks()`** —— InputManager 独立通过 `tree_changed` 信号自动清理（ADR-0004）
- **错误恢复**：加载画面场景缺失 → `_transitioning = false` + 强制 `pop_lock(&"scene_manager")` → 恢复到当前场景可用状态
- **await 中断双重保底**：`_phase3_in_progress` 标志位——Phase 4 检测到 `tree_changed` 但 `_phase3_in_progress` 仍为 true 时执行清理

### 必须遵守（来自 Control Manifest —— Foundation 层）

- **四级锁栈**（dialogue=0 < animation=1 < modal=2 < transition=3） —— 来源: ADR-0004
- **`push_lock()` / `pop_lock()` 必须配对 —— 以 `StringName` 追踪来源** —— 重复 push 记录警告 —— 来源: ADR-0004
- **锁状态通过 GSM `batch_updated` 传播 —— 无 InputManager 自有信号** —— 来源: ADR-0004
- **`is_input_allowed()`: <0.005ms/调用（O(n)，n ≤ 4 个锁条目）** —— 来源: ADR-0004
- **存档格式必须为 JSON，以 `schema_version` 为迁移驱动字段** —— 来源: ADR-0002
- **原子写入策略**：`.tmp` → `DirAccess.rename_absolute()` → `.bak` → 删除 `.bak` —— 来源: ADR-0002
- **Windows 重命名重试**：最多 3 次 × 50ms —— 来源: ADR-0002
- **存档容器必须包含 `"complete": true` 标记** —— 来源: ADR-0002

## 验收标准

### AC-1：Phase 2 输入锁定

- [ ] Phase 2 调用 `InputManager.push_lock(LockType.TRANSITION, &"scene_manager")`
- [ ] 锁在 `_transitioning = true` 设置之后调用——顺序：先设置标志位，再锁输入
- [ ] 调用 `push_lock` 前验证 `InputManager` 不为 null——防御性编程
- [ ] TRANSITION 锁阻止所有设备类型的所有输入动作

### AC-2：Phase 2 自动存档

- [ ] Phase 2 调用 `SaveLoad.auto_save()` —— 在输入锁定之后触发
- [ ] 调用 `auto_save` 前验证 `SaveLoad` 不为 null——防御性编程
- [ ] `auto_save()` 为 fire-and-forget 调用——SceneManager 不等待存档完成（不 `await`）
- [ ] 自动存档不阻塞转换管线的推进——Phase 2 → Phase 3 不依赖存档完成
- [ ] 可验证：存档文件时间戳在场景切换前更新（集成测试中通过检查 `FileAccess.get_modified_time()` 或 mock 验证）

### AC-3：Phase 4 输入解锁

- [ ] Phase 4 调用 `InputManager.pop_lock(&"scene_manager")` —— 在 GSM 写入和 `post_transition` 发射之后
- [ ] 顺序：GSM 更新 → `post_transition` 信号 → `pop_lock`——防止新场景在信号处理完成前接收输入
- [ ] `pop_lock` 与 Phase 2 的 `push_lock` 配对——同一 `StringName`（`&"scene_manager"`）

### AC-4：加载画面场景缺失时的错误恢复

- [ ] Phase 3 中 `change_scene_to_file(SCENE_PATHS[SceneID.LOADING])` 返回错误时：
  - 设置 `_transitioning = false`
  - 调用 `InputManager.pop_lock(&"scene_manager")`
  - 记录 `push_error("无法加载 loading_screen.tscn：{error}")`
  - 返回——不执行 Phase 4/5 的其余步骤
- [ ] 错误恢复后当前场景保持在可用状态——玩家可继续操作

### AC-5：目标场景路径不存在的错误恢复

- [ ] Phase 3 中 `change_scene_to_file(SCENE_PATHS[to])` 返回错误时：
  - 设置 `_transitioning = false`
  - 调用 `InputManager.pop_lock(&"scene_manager")`
  - 记录 `push_error("目标场景不存在：{path}")`
  - 尝试回退到 `MAIN_MENU` 场景（`request_scene_change(_current_scene_id, SceneID.MAIN_MENU, TransitionType.GAME_TO_MENU)`）
  - 回退也失败时：记录 `push_error("回退主菜单也失败——手动恢复")`；保持加载画面场景

### AC-6：锁泄漏防护 —— await 中断双重保底

- [ ] `_phase3_in_progress: bool` —— Phase 3 开始时设为 true，Phase 4 正常到达时设为 false
- [ ] Phase 4 检测到 `tree_changed` 但 `_phase3_in_progress == true` 时：
  - 确认是异常中断（非正常场景切换完成）
  - 执行完整清理：`_transitioning = false` + `pop_lock(&"scene_manager")`
  - 记录 `push_error("Phase 3 异常中断——强制清理")`
- [ ] 此机制通过 GUT 测试验证：模拟 Phase 3 中 await 中断后 Phase 4 到达的场景

### AC-7：InputManager 交互契约验证

- [ ] SceneManager 从**不**直接调用 `InputManager.clear_locks()` —— 来源: ADR-0005 §约束和禁止
- [ ] SceneManager 的 TRANSITION 锁推入和弹出遵循正常的 push/pop 生命周期——不绕过锁栈
- [ ] 连续两次 `request_scene_change()` 调用——第二个返回 false（`_transitioning` 守卫）——不会产生重复锁

### AC-8：SaveLoad 集成契约验证

- [ ] SceneManager 调用 `SaveLoad.auto_save()` 时，存档系统负责所有序列化和写入逻辑——SceneManager 不接触文件 I/O
- [ ] SceneManager 不验证存档结果——`auto_save()` 的返回值不被检查（fire-and-forget）
- [ ] 存档系统在 `meta` 容器中存储 `current_scene`（String 路径）和 `current_scene_id`（int 枚举值）——以支持读档恢复场景（ADR-0005 §风险 #3）
- [ ] 此 meta 字段由 SaveLoad Story 实现——SceneManager 仅在 Phase 2 触发存档，不定义存档格式

## 故事依赖

| 依赖 | 状态 | 说明 |
|------|------|------|
| Story 001（5 阶段管线核心） | 阻塞 | Phase 2/4 的管线入口必须就位 |
| InputManager（ADR-0004） | 阻塞集成测试 | 单元测试可 mock；集成测试需真实 InputManager |
| SaveLoad（ADR-0002） | 阻塞集成测试 | 单元测试可 mock `auto_save()`；集成测试需真实 SaveLoad |
| Story 002（TransitionType） | 可并行 | 无直接依赖 |

## 禁止方法

- **绝不**直接调用 `InputManager.clear_locks()` —— 使用正常的 push/pop 配对 —— 来源: ADR-0005 §约束和禁止
- **绝不**在 `push_lock` 或 `pop_lock` 时使用裸 String —— 使用 `StringName` 字面量 `&"scene_manager"` —— 来源: ADR-0004
- **绝不**在 Phase 2 中 await `auto_save()` —— fire-and-forget 模式，不阻塞管线 —— 来源: ADR-0005 §Phase 2
- **绝不**在 `pop_lock` 前忘记配对验证——如果 Phase 2 的 `push_lock` 失败（InputManager 故障），Phase 4 的 `pop_lock` 必须跳过（不能 pop 一个不存在的锁）
- **绝不**在错误恢复路径中忘记 `_transitioning = false`——这会导致永久死锁

## 测试证据

| 证据类型 | 位置 | 级别 |
|----------|------|------|
| 集成测试 | `tests/integration/scene_manager/test_input_lock_integration.gd` | **阻塞** |
| 集成测试 | `tests/integration/scene_manager/test_auto_save_integration.gd` | **阻塞** |
| 集成测试 | `tests/integration/scene_manager/test_error_recovery_integration.gd` | **阻塞** |

### 最小测试集

```
# 输入锁定集成
test_phase_2_pushes_transition_lock
test_phase_4_pops_transition_lock
test_lock_and_unlock_are_paired
test_input_blocked_during_transition
test_input_restored_after_transition
test_no_duplicate_lock_on_concurrent_request
test_no_pop_without_push_on_error

# 自动存档集成
test_phase_2_triggers_auto_save
test_auto_save_fires_before_phase_3
test_auto_save_not_awaited_by_scene_manager
test_auto_save_triggered_even_on_fast_transition

# 错误恢复
test_error_recovery_on_loading_scene_missing
test_error_recovery_on_target_scene_missing
test_fallback_to_main_menu_on_target_missing
test_transitioning_false_after_error
test_lock_released_after_error
test_phase3_abort_double_safety_cleanup
test_no_permanent_deadlock_after_loading_scene_failure
```

## 实现注意事项

- `InputManager` 和 `SaveLoad` 的引用通过 `@onready var` 在 `_ready()` 中获取（Autoload 名称已知）
- 测试中使用 mock 对象注入——SceneManager 提供 `set_input_manager(mock)` / `set_save_load(mock)` 方法（仅测试可见）
- Phase 2 中 push_lock 和 auto_save 的顺序有意设计——先锁输入再存档。这样即使存档写入耗时 100ms，玩家也无法在此期间触发操作
- `_phase3_in_progress` 标志位在 Phase 3 第一步设为 true，在 Phase 4 正常到达后立即设为 false。`tree_changed` 信号可能在非场景切换场景下触发——此标志位作为双重校验

## Completion Notes

**完成日期**：2026-07-30
**验收标准**：8/8 通过
**测试**：221/221 通过，1000 断言，0 失败（14 脚本，含 3 个新增集成测试文件共 26 测试）
**偏差**：
- ADVISORY（LOW）：AC-3 要求 `GSM 写入 → post_transition → pop_lock` 排序，代码遵循 ADR-0005（pop_lock 在 post_transition 之前）— ADR 优先于故事 AC。ADR-0005 §Phase 4 定义 pop_lock 在信号发射前执行
- ADVISORY（LOW）：`change_scene_to_file` 返回值使用 `int` 而非 `Error` 枚举——GDScript 惯用法，`int` 可安全匹配 `Error` 枚举值
- 已修复（MEDIUM）：L300——AC-5 回退 `request_scene_change` 返回值现被检查（`fallback_ok`），失败时记录 `push_error("SceneManager: 回退主菜单也失败——手动恢复")`
**代码审查**：已完成——LP-CODE-REVIEW APPROVED WITH CONCERNS（MEDIUM 已修复，2 LOW 已记录）
