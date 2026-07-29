# Story 004: MODAL 覆盖机制与边缘情况

> **Epic**: input-manager (输入管理器)
> **Story 类型**: Logic（逻辑） + Integration（集成）
> **依赖 Story**: Story 001 + 002 + 003
> **管辖 ADR**: ADR-0004
> **预计工作量**: 5 点
> **Status**: Complete
> **优先级**: P2 — 防御性/完整性 Story；阻塞 MODAL 消费系统
> **Last Updated**: 2026-07-29

## GDD 需求

| TR-ID | 需求 | 验收标准 |
|-------|------|----------|
| TR-input-001 | 输入锁的单一仲裁者；投递前查询 GSM.session.input_locks | MODAL 弹窗拥有者通过 `has_lock(source)` 自检绕过 `is_input_allowed()` 的 false 返回 |
| TR-input-002 | 四级锁栈 + 4.6 双焦点独立判定 | MODAL 锁阻止非拥有者输入→拥有者通过 `has_lock()` 绕行 |

## ADR 指导

| 引用 | 内容 |
|------|------|
| ADR-0004 §MODAL 判定 | `is_input_allowed()` 返回 `false` 用于 MODAL——弹窗拥有者通过 `has_lock(source)` 自行判定 |
| ADR-0004 §push/pop 配对 | 严格的 LIFO 栈序 + 重复 push 检测——防止锁泄漏 |
| ADR-0004 §await 风险 | `await` 异常路径可能导致 `pop_lock()` 未执行→锁泄漏 |
| ADR-0004 §设备掩码 | 白名单语义——设备不在 mask 中→返回 false；允许部分锁（仅键盘、鼠标仍 hover） |
| ADR-0004 §调用方锁使用速查 | 8 种场景的设备掩码配置表 |
| ADR-0004 §性能护栏 | `is_input_allowed()` <0.005ms；锁栈深度 ≤4 |
| control-manifest.md L38 | `push_lock()` / `pop_lock()` 必须配对 |

## 验收标准

### MODAL 覆盖

- [x] **AC-001**: `push_lock(MODAL, &"settings_menu")` → `is_input_allowed(GAMEPLAY, MOUSE)` → `false`（非拥有者—InputManager 返回 false）
- [x] **AC-002**: `push_lock(MODAL, &"settings_menu")` → `has_lock(&"settings_menu")` → `true`（拥有者自检通过）
- [x] **AC-003**: 弹窗拥有者消费模式：调用方通过 `has_lock(source)` + 自行判定允许输入——**不在 InputManager 内部实现 MODAL 覆盖**
- [x] **AC-004**: MODAL 锁 + 非拥有者 source 调用 `has_lock()` → `false`
- [x] **AC-005**: 栈中无 MODAL 锁 → `has_lock(&"any")` → `false`
- [x] **AC-006**: 多个 MODAL 锁嵌套：`push(MODAL, &"a")` + `push(MODAL, &"b")` → `has_lock(&"a")` → `true`，`has_lock(&"b")` → `true`
- [x] **AC-007**: ESC 键在 MODAL 锁下：`is_input_allowed(UI_NAV, KEYBOARD)` → `false`——InputManager 不做特殊处理；弹窗自行通过 `has_lock()` 判定是否响应 ESC
- [x] **AC-008**: GAMEPLAY 输入在 MODAL 锁下：`is_input_allowed(GAMEPLAY, KEYBOARD)` → `false`——非拥有者被阻止
- [x] **AC-009**: TRANSITION 锁覆盖 MODAL 锁：`push(MODAL, &"a")` + `push(TRANSITION, &"scene")` → `is_input_allowed(ANY, MOUSE)` → `true`（ANY 始终允许）——但所有其他 action 类型返回 false

### 设备掩码边缘情况

- [x] **AC-010**: 仅锁键盘 + DIALOGUE：`push_lock(DIALOGUE, &"dialog", device_mask=MOUSE|GAMEPAD)` → `is_input_allowed(GAMEPLAY, MOUSE)` → `false`（白名单语义："仅锁键盘"=KEYBOARD 不在白名单 → device_mask=MOUSE|GAMEPAD=5。MOUSE 在白名单中 + DIALOGUE 阻止 GAMEPLAY → false）
- [x] **AC-011**: 仅锁键盘 + DIALOGUE：`push_lock(DIALOGUE, &"dialog", device_mask=MOUSE|GAMEPAD)` → `is_input_allowed(GAMEPLAY, KEYBOARD)` → `false`（键盘不在白名单中——被 _check_device_allowed 拒绝，无需到达严格度判定）
- [x] **AC-012**: GAMEPAD 独立锁：`push_lock(ANIMATION, &"cinematic", device_mask=GAMEPAD)` → 手柄全部被锁，鼠标/键盘正常
- [x] **AC-013**: 鼠标 hover（tooltip/高亮）在 DIALOGUE/ANIMATION 锁下仍触发→锁栈含 DIALOGUE 但 device_mask=ALL → `_check_device_allowed(MOUSE)` true + `ActionType.UI_NAV` 允许 → tooltip 正常显示

### await 异常路径锁泄漏防护

- [x] **AC-014**: 正常路径：`push_lock(ANIMATION, &"combat")` + `await animate()` + `pop_lock(&"combat")` → 锁正确释放
- [x] **AC-015**: 防御性清理：同一 source 在 push 后、pop 前的任何时刻调用 `clear_locks(&"combat")` → 栈中该 source 的所有锁被移除
- [x] **AC-016**: 场景变更自动清理：战斗动画 `await` 未完成时 SceneManager 切换场景 → `tree_changed` 触发 `clear_locks()` → 遗留的 animation 锁被清理
- [x] **AC-017**: 调用方文档：Story 包含调用方最佳实践示例——每个 `push_lock()` 后必须在返回/异常路径中配对的 `pop_lock()`（或使用 `clear_locks(source)` 清理）

### 调用方锁使用速查表实现验证

- [x] **AC-018**: 对话进行中场景：`push_lock(DIALOGUE, &"dialogue_system", ALL)` → gameplay 阻止，dialogue + UI nav 允许
- [x] **AC-019**: 战斗动画场景：`push_lock(ANIMATION, &"combat_system", ALL)` → gameplay + dialogue 阻止，UI nav 允许
- [x] **AC-020**: 设置弹窗场景：`push_lock(MODAL, &"settings_menu", ALL)` → 弹窗外所有输入阻止
- [x] **AC-021**: 战利品选择场景：`push_lock(MODAL, &"loot_screen", ALL)` → 模态覆盖
- [x] **AC-022**: 场景加载场景：`push_lock(TRANSITION, &"scene_manager", ALL)` → 所有输入阻止
- [x] **AC-023**: 仅锁键盘保持鼠标 hover 场景：`push_lock(ANIMATION, &"combat_system", MOUSE|GAMEPAD)` → 键盘输入被锁，鼠标 tooltip 仍活跃

### 防御性检查

- [x] **AC-024**: 锁栈深度在正常运行中不超过 4 层（DIALOGUE → ANIMATION → MODAL → TRANSITION）
- [x] **AC-025**: InputManager 在节点退出时断开 `tree_changed` 连接——防止悬挂引用
- [x] **AC-026**: `_exit_tree()` 中清理锁栈 + 最终 `_sync_to_gsm()`——确保 GSM 中无残留状态

## 排除范围

- ❌ 不包含 UI 弹窗系统的实现——仅验证 InputManager 的 MODAL API
- ❌ 不包含 Input Map action 的完整分类表——各消费系统自行定义
- ❌ 不包含 GUT perf 测试框架搭建——性能标准在 QA 冒烟测试中验证

## 测试证据路径

- `tests/unit/input/test_modal_override.gd` — GUT 单元测试
  - `test_modal_blocks_non_owner`
  - `test_modal_owner_has_lock_true`
  - `test_modal_non_owner_has_lock_false`
  - `test_has_lock_empty_stack_false`
  - `test_nested_modal_both_owners_detected`
  - `test_esc_key_blocked_under_modal`
  - `test_gameplay_input_blocked_under_modal`
  - `test_transition_overrides_modal`
- `tests/unit/input/test_device_mask_edge_cases.gd` — GUT 单元测试
  - `test_modal_keyboard_only_mouse_still_allowed`
  - `test_modal_keyboard_only_blocks_keyboard`
  - `test_gamepad_exclusive_lock`
  - `test_mouse_hover_allowed_under_dialogue_lock`
  - `test_mouse_hover_allowed_under_animation_lock`
- `tests/unit/input/test_lock_leak_prevention.gd` — GUT 单元测试
  - `test_clear_locks_by_source_removes_only_that_source`
  - `test_tree_changed_clears_all_orphaned_locks`
  - `test_same_source_push_pop_paired_no_leak`
- `tests/integration/input/test_modal_integration.gd` — 集成测试
  - `test_modal_push_pop_cycle`
  - `test_transition_clears_modal`
  - `test_full_pause_menu_escape_under_combat_lock`

## 实现指导

### 文件

| 文件 | 用途 |
|------|------|
| `src/autoload/input_manager.gd` | 追加 `_exit_tree()` 清理 + MODAL 拥有者模式文档 |
| `tests/unit/input/test_modal_override.gd` | MODAL 覆盖单元测试 |
| `tests/unit/input/test_device_mask_edge_cases.gd` | 设备掩码边缘情况测试 |
| `tests/unit/input/test_lock_leak_prevention.gd` | 锁泄漏防护测试 |
| `tests/integration/input/test_modal_integration.gd` | MODAL 集成测试 |

### 关键代码追加

```gdscript
# input_manager.gd 追加

func _exit_tree() -> void:
    if get_tree():
        get_tree().tree_changed.disconnect(_on_tree_changed)
    _lock_stack.clear()
    _sync_to_gsm()
```

### MODAL 拥有者消费模式（示例——实现于 UI 弹窗系统，非 InputManager）

```gdscript
# 弹窗系统消费模式——此代码在 UI 系统的 Control 节点中，不在 InputManager 中
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        # InputManager 返回 false——但弹窗是 MODAL 拥有者，自行判定
        if InputManager.has_lock(&"settings_menu"):
            handle_click(event.position)
            return
        # 非拥有者——遵守 InputManager 判定
        if not InputManager.is_input_allowed(ActionType.GAMEPLAY, DeviceType.MOUSE):
            return
        handle_click(event.position)
```

### 调用方最佳实践文档（嵌入 Story 中作为参考）

```gdscript
## 最佳实践：使用 push_lock 时
##   1. 始终在 push_lock() 后立即安排 pop_lock()——在信号回调或 return 前
##   2. 若使用 await，确保所有退出路径（正常/异常）都调用 pop_lock()
##   3. 防御性代码：在系统退出/卸载时调用 clear_locks(source)
##
## 正确模式：
##   func play_animation() -> void:
##       InputManager.push_lock(ANIMATION, &"combat_system")
##       await animate()
##       InputManager.pop_lock(&"combat_system")  # 正常路径 pop
##
##   防御性模式：
##   func _exit_tree() -> void:
##       InputManager.clear_locks(&"combat_system")  # 清理所有遗留锁
```

## 阻塞项

- Story 001 + 002 + 003 全部完成——完整 API 可用
- 至少一个 MODAL 弹窗消费者（如暂停菜单）已实现或存根——用于集成测试
- `_exit_tree()` / `tree_changed` 在目标 Godot 4.6 引擎上的行为已验证

## 相关 Story

| Story | 关系 |
|-------|------|
| Story 001 | 锁栈——`has_lock()` 基于锁栈查询 |
| Story 002 | 判定——`is_input_allowed()` 返回 false → MODAL 拥有者绕行 |
| Story 003 | GSM 同步——`_exit_tree()` 中最后一次 `_sync_to_gsm()` |

## Completion Notes

**Completed**：2026-07-29
**Criteria**：26/26 通过
**Deviations**：
- **AC-010/AC-011 文本修正**：原 AC-010/AC-011 使用 `push_lock(MODAL, …, device_mask=KEYBOARD)` 期望鼠标返回 `true`——与白名单语义 + MODAL 无条件返回 false 的架构不兼容。已修正为 `push_lock(DIALOGUE, …, device_mask=MOUSE|GAMEPAD)`，匹配白名单语义（"仅锁键盘"=KEYBOARD 不在白名单内→`device_mask=MOUSE|GAMEPAD=5`）。
- **`_exit_tree()` 实现修正**：实际实现使用 `is_inside_tree()` 守卫（而非故事骨架中的 `get_tree()`）并添加了 `is_connected()` 前置检查——更安全，兼容非场景树单元测试环境。
- **ADVISORY（5 项——不阻塞完成）**：
  1. `pop_lock` 不存在的 source 警告路径无测试覆盖（`input_manager.gd:156`）
  2. 空栈 `clear_locks("")` 空操作路径无测试覆盖（`input_manager.gd:168`）
  3. `device_mask=0` 边界值无测试覆盖（`input_manager.gd:303`）
  4. `test_lock_leak_prevention.gd` 归类为单元测试但依赖 GSM Autoload（违反单元测试隔离原则）
  5. `test_modal_keyboard_only_mouse_still_allowed` 名称与首条断言不完全一致（测试实际覆盖 MODAL+DIALOGUE 两种锁场景）

**Test Evidence**：
- Logic：`tests/unit/input/test_modal_override.gd`（9 测试函数）、`tests/unit/input/test_device_mask_edge_cases.gd`（5 测试函数）、`tests/unit/input/test_lock_leak_prevention.gd`（8 测试函数）
- Integration：`tests/integration/input/test_modal_integration.gd`（13 测试函数）
- 测试结果：**123/123 通过，719 断言，零失败**

**Code Review**：✅ 已完成——GDScript 专家 + QA 测试员双审查，修复 4 项关键问题后通过