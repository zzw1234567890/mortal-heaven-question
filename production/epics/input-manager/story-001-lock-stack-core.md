# Story 001: 四级锁栈核心实现

> **Epic**: input-manager (输入管理器)
> **Status**: Complete
> **Last Updated**: 2026-07-29
> **Manifest Version**: 2026-07-26
> **Story 类型**: Logic（逻辑）
> **依赖 Story**: 无（Foundation 层首个 story）
> **管辖 ADR**: ADR-0004
> **预计工作量**: 3 点
> **优先级**: P0 — 阻塞所有后续 Story

## GDD 需求

| TR-ID | 需求 | 验收标准 |
|-------|------|----------|
| TR-input-001 | 输入锁的单一仲裁者；在投递前查询 GSM.session.input_locks | InputManager 作为 Autoload #2 常驻；所有 UI 系统在消费输入前通过 `is_input_allowed()` 查询 |
| TR-input-002 | 四级锁栈 (dialogue=0, animation=1, modal=2, transition=3) | LockType 枚举定义四级锁 + 严格度排序；`push_lock()` / `pop_lock()` 管理栈 |

## ADR 指导

| 引用 | 内容 |
|------|------|
| ADR-0004 §决策 | 四级锁栈 + 严格度升序 + push/pop 配对 + source 追踪 |
| ADR-0004 §LockEntry | `{type: LockType, source: StringName, device_mask: int}` 内部结构 |
| ADR-0004 §push_lock | 重复 push 检测（同一 source 再 push → 警告 + 跳过） |
| ADR-0004 §pop_lock | 从栈尾向前查找 source → 移除；未找到 → `push_warning` |
| ADR-0004 §clear_locks | 支持按 source 过滤清除；空参 = 全部清除 |
| ADR-0004 §性能 | `is_input_allowed()` O(n)，n≤4，每次调用 <0.005ms |
| control-manifest.md L36 | 四级锁栈 (dialogue=0 < animation=1 < modal=2 < transition=3) |
| control-manifest.md L38 | `push_lock()` / `pop_lock()` 必须配对 —— 以 `StringName` 追踪来源 |

## 验收标准

- [ ] **AC-001**: `LockType` 枚举定义完整：`DIALOGUE=0, ANIMATION=1, MODAL=2, TRANSITION=3`
- [ ] **AC-002**: `LockEntry` 内部类包含 `type: LockType`、`source: StringName`、`device_mask: int` 三个字段
- [ ] **AC-003**: `push_lock(DIALOGUE, &"dialogue_system")` → 栈深度 +1，打印日志
- [ ] **AC-004**: 同一 source 重复 `push_lock()` → `push_warning` + 跳过（不增加栈元素）
- [ ] **AC-005**: `pop_lock(&"dialogue_system")` → 从栈尾向前查找并移除，打印日志
- [ ] **AC-006**: `pop_lock("nonexistent")` → `push_warning`，栈不变
- [ ] **AC-007**: 多锁共存：`push(A, &"sys_a")` + `push(B, &"sys_b")` + `pop(&"sys_a")` → 栈剩 sys_b 一个元素
- [ ] **AC-008**: `clear_locks()` 无参 → 栈清空，所有输入恢复
- [ ] **AC-009**: `clear_locks(&"sys_a")` → 仅移除 source==sys_a 的元素，其余保留
- [ ] **AC-010**: `get_current_lock()` → 返回栈中最高 LockType（空栈返回 -1 或预定义常量）
- [ ] **AC-011**: `get_lock_stack()` → 返回 `Array[Dictionary]`，包含完整栈快照（调试/诊断用）
- [ ] **AC-012**: `has_lock(&"sys_a")` → 栈中存在 source==sys_a 时返回 true
- [ ] **AC-013**: InputManager 初始化为 Autoload #2（GSM 之后，SceneManager 之前；验证 `_ready()` 中 `_lock_stack` 为空）
- [ ] **AC-014**: Autoload 注册 — 在 Project Settings > Autoload 中将 `input_manager.gd` 配置为 #2

## 排除范围

- ❌ 本 Story 不包含 `is_input_allowed()` 实现（Story 002）
- ❌ 不包含 GSM 同步（Story 003）
- ❌ 不包含 MODAL 特殊判定（Story 004）
- ❌ `device_mask` 字段在本 Story 中定义但不进行位掩码判定 — 接收并存储即可

## 测试证据路径

- `tests/unit/input/test_lock_stack.gd` — GUT 单元测试
  - `test_push_lock_adds_entry`
  - `test_push_lock_duplicate_source_warns`
  - `test_pop_lock_removes_by_source`
  - `test_pop_lock_nonexistent_source_warns`
  - `test_multi_lock_lifo_behaviour`
  - `test_clear_locks_all_and_filtered`
  - `test_get_current_lock_returns_highest`
  - `test_get_lock_stack_returns_snapshot`
  - `test_has_lock_true_when_present`
  - `test_autoload_init_order`

## 实现指导

### 文件

| 文件 | 用途 |
|------|------|
| `src/foundation/input_manager.gd` | InputManager Autoload — 锁栈管理 + 枚举定义 |
| `tests/unit/input/test_lock_stack.gd` | 锁栈单元测试 |

### 关键代码骨架

```gdscript
# input_manager.gd
extends Node

enum LockType { DIALOGUE = 0, ANIMATION = 1, MODAL = 2, TRANSITION = 3 }

class LockEntry:
    var type: LockType
    var source: StringName
    var device_mask: int  # 保留字段——Story 002 使用

var _lock_stack: Array[LockEntry] = []

func _ready() -> void:
    _lock_stack = []
    # 连接 SceneTree.tree_changed 用于场景变更时自动清除（Story 003）

func push_lock(type: LockType, source: StringName, device_mask: int = 7) -> void: ...
func pop_lock(source: StringName) -> void: ...
func clear_locks(source: StringName = "") -> void: ...
func get_current_lock() -> LockType: ...
func get_lock_stack() -> Array[Dictionary]: ...
func has_lock(source: StringName) -> bool: ...
```

### 严格度映射表

| 当前锁 | 允许 GAMEPLAY | 允许 DIALOGUE | 允许 UI_NAV |
|--------|:---:|:---:|:---:|
| DIALOGUE | No | Yes | Yes |
| ANIMATION | No | No | Yes |
| MODAL | No | No | No（拥有者自检除外） |
| TRANSITION | No | No | No |
| (无锁) | Yes | Yes | Yes |

> 注意：此表在 Story 002 的 `is_input_allowed()` 中实现——此处仅作为设计参考。

## 阻塞项

- 依赖 GSM Autoload #1 已在 Project Settings 中注册
- 依赖 `src/foundation/` 目录存在

## 相关 Story

| Story | 关系 |
|-------|------|
| Story 002 | 在锁栈基础上实现 `is_input_allowed()` 判定 |
| Story 003 | 将锁状态同步到 GSM + 传播信号 |
| Story 004 | MODAL 覆盖 + 边缘情况 |

## Completion Notes

**Completed**：2026-07-29
**Criteria**：14/14 通过
**Deviations**：
- ADVISORY：实现路径 `src/foundation/input_manager.gd` 与故事最初指定的 `src/autoload/` 不同——`project.godot` 注册为 `src/foundation/`，故事文件已修正
- ADVISORY：故事最初缺少 `Manifest Version:` 嵌入字段——已补充（2026-07-26，无过期风险）
**Test Evidence**：`tests/unit/input/test_lock_stack.gd`——37 测试函数，14/14 AC 覆盖。Godot CLI 不在 PATH，未无头运行——结构由 QA Lead + 首席程序员审查确认
**Code Review**：首席程序员 APPROVED WITH SUGGESTIONS——已应用（`_sync_to_gsm()` 空桩 + 路径修正）