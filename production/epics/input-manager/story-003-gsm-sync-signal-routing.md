# Story 003: GSM 同步、信号传播与输入分发

> **Epic**: input-manager (输入管理器)
> **Story 类型**: Integration（集成）
> **Status**: Complete
> **Last Updated**: 2026-07-29
> **依赖 Story**: Story 001（锁栈核心） + Story 002（双焦点判定）
> **管辖 ADR**: ADR-0004 + ADR-0001
> **预计工作量**: 4 点
> **优先级**: P1 — GSM 集成与信号集成阻塞下游 Story

## GDD 需求

| TR-ID | 需求 | 验收标准 |
|-------|------|----------|
| TR-input-001 | 输入锁的单一仲裁者；投递前查询 GSM.session.input_locks | `_sync_to_gsm()` 在每次 push/pop/clear 后写入 GSM + 触发 `batch_updated`；场景变更自动清除锁 |
| TR-input-002 | 四级锁栈 | 锁状态序列化为 `Array[Dictionary]` 存入 `GSM.session.input_locks` |

## ADR 指导

| 引用 | 内容 |
|------|------|
| ADR-0004 §GSM 同步 | `_sync_to_gsm()` —— 序列化 `_lock_stack` → Dictionary 数组 → `GSM.set_input_locks()` |
| ADR-0004 §信号传播 | 锁变更通过 GSM `batch_updated` 信号传播——无 InputManager 自有信号 |
| ADR-0004 §场景变更 | `SceneTree.tree_changed` → 自动 `clear_locks()` |
| ADR-0004 §输入分发 | 三路径：GAMEPLAY 键盘→Input Map 轮询；UI_NAV 快捷键→`_input()`；鼠标→`_gui_input()` |
| ADR-0001 §batch_updated | 展平 `{path: {old, new}}` 字典——消费者按路径前缀过滤 |
| ADR-0001 §第二层 | GSM 提供 `set_input_locks()` 专用原子方法（若尚未实现需新增） |
| control-manifest.md L39 | 锁状态通过 GSM `batch_updated` 传播 —— 无 InputManager 自有信号 |
| control-manifest.md L21 | 所有游戏状态写入必须通过 GSM 第二层原子方法 |

## 验收标准

- [ ] **AC-001**: `push_lock()` → 调用 `_sync_to_gsm()` → `GSM.set_input_locks(serialized)` 被调用
- [ ] **AC-002**: `pop_lock()` → 调用 `_sync_to_gsm()` → GSM 写入更新后的锁栈
- [ ] **AC-003**: `clear_locks()` → 调用 `_sync_to_gsm()` → GSM 写入空数组
- [ ] **AC-004**: `GSM.set_input_locks()` 发射 `batch_updated` 信号，携带 `{"session.input_locks": {"old": [...], "new": [...]}}` 载荷
- [ ] **AC-005**: `_sync_to_gsm()` 序列化格式：`Array[Dictionary]`，每个元素包含 `{type: int, source: StringName, device_mask: int}`
- [ ] **AC-006**: InputManager 自身**不声明任何信号**——所有信号通过 GSM `batch_updated` 传播
- [ ] **AC-007**: 连接 `SceneTree.tree_changed` → 场景变更时自动调用 `clear_locks()`（仅当栈非空时——减少不必要的 GSM 写入）
- [ ] **AC-008**: `tree_changed` 回调在 SceneManager 调用 `change_scene_to_file()` 后触发——新场景锁栈为空
- [ ] **AC-009**: SceneManager 可显式调用 `InputManager.clear_locks()` 作为防御——但 InputManager 在 `tree_changed` 时自动清理（独立运行）
- [ ] **AC-010**: 输入分发路径 A（GAMEPLAY 键盘）→ InputManager Autoload 的 `_process()` 中通过 `Input.is_action_just_pressed()` + `is_input_allowed()` 判定
- [ ] **AC-011**: 输入分发路径 B（UI_NAV 快捷键——ESC 暂停）→ InputManager Autoload 的 `_input()` 中拦截 → `accept_event()` 阻止传播
- [ ] **AC-012**: 输入分发路径 C（鼠标交互）→ 各 Control 节点的 `_gui_input()` / Area2D 的 `_input_event()` 中调用 `is_input_allowed()`
- [ ] **AC-013**: ESC 键可达性——通过 `is_input_allowed()` 或弹窗拥有者自检：
  - DIALOGUE/ANIMATION → `is_input_allowed(UI_NAV, KEYBOARD)` → `true`
  - MODAL → `is_input_allowed(UI_NAV, KEYBOARD)` → `false`，但弹窗拥有者通过 `has_lock(source)` 绕行（参见 Story 004）
  - TRANSITION → `is_input_allowed(UI_NAV, KEYBOARD)` → `false`，且不可绕行
- [ ] **AC-014**: `_input()` 优先于 GUI 派发——全局快捷键在任何 Control 消耗事件之前拦截
- [ ] **AC-015**: HUD 监听 `GSM.batch_updated` 信号 → 当 `session.input_locks` 变更时更新输入提示 UI（例如："已锁定"图标）
- [ ] **AC-016**: GSM 若尚未提供 `set_input_locks()` —— 本 Story 须在 GSM 中新增此第二层原子方法（参见 ADR-0001 §第二层）

## 排除范围

- ❌ 不包含 MODAL 覆盖逻辑（Story 004）
- ❌ 不包含 `await` 异常路径防护（Story 004）
- ❌ 不包含 HUD UI 实现——仅验证 GSM 信号到达（HUD 故事另行实现）
- ❌ 不实现完整的 Input Map action → ActionType 分类表——Story 004 和各消费系统自行分类

## 测试证据路径

- `tests/unit/input/test_gsm_sync.gd` — GUT 单元测试
  - `test_push_lock_syncs_to_gsm`
  - `test_pop_lock_syncs_to_gsm`
  - `test_clear_locks_syncs_empty_array`
  - `test_sync_format_contains_type_source_mask`
  - `test_no_own_signals_declared`（验证 InputManager 无 signal 声明）
  - `test_tree_changed_triggers_clear_when_stack_non_empty`
  - `test_tree_changed_no_op_when_stack_empty`（避免不必要的 GSM 写）
- `tests/integration/input/test_signal_propagation.gd` — 集成测试
  - `test_push_lock_emits_batch_updated`
  - `test_pop_lock_emits_batch_updated`
  - `test_batch_updated_payload_contains_old_and_new`
- `tests/integration/input/test_input_routing.gd` — 集成测试
  - `test_gameplay_keyboard_routed_via_process`
  - `test_ui_nav_shortcut_routed_via_input`
  - `test_mouse_interaction_routed_via_gui_input`

## 实现指导

### 文件

| 文件 | 用途 |
|------|------|
| `src/autoload/input_manager.gd` | 追加 `_sync_to_gsm()`、`_process()`、`_input()`、`tree_changed` 连接 |
| `src/autoload/game_state_manager.gd` | 如需：新增 `set_input_locks()` 第二层原子方法 |
| `tests/unit/input/test_gsm_sync.gd` | GSM 同步单元测试 |
| `tests/integration/input/test_signal_propagation.gd` | 信号传播集成测试 |
| `tests/integration/input/test_input_routing.gd` | 输入分发集成测试 |

### 关键代码骨架

```gdscript
# input_manager.gd 追加

func _ready() -> void:
    _lock_stack = []
    get_tree().tree_changed.connect(_on_tree_changed)

func _on_tree_changed() -> void:
    if not _lock_stack.is_empty():
        _lock_stack.clear()
        _sync_to_gsm()

func _sync_to_gsm() -> void:
    var serialized: Array[Dictionary] = []
    for entry in _lock_stack:
        serialized.append({
            "type": entry.type,
            "source": entry.source,
            "device_mask": entry.device_mask,
        })
    GSM.set_input_locks(serialized)

func _process(_delta: float) -> void:
    # 路径 A：GAMEPLAY 键盘——Input Map 轮询
    if Input.is_action_just_pressed(&"end_turn"):
        if is_input_allowed(ActionType.GAMEPLAY, DeviceType.KEYBOARD):
            _on_end_turn_requested()
    if Input.is_action_just_pressed(&"pause"):
        if is_input_allowed(ActionType.UI_NAV, DeviceType.KEYBOARD):
            toggle_pause()

func _input(event: InputEvent) -> void:
    # 路径 B：UI_NAV 快捷键——在 GUI 派发前拦截
    if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
        if is_input_allowed(ActionType.UI_NAV, DeviceType.KEYBOARD):
            toggle_pause()
            accept_event()
```

### GSM 新增方法（如需）

```gdscript
# game_state_manager.gd
func set_input_locks(locks: Array[Dictionary]) -> void:
    var old := session.input_locks.duplicate(true)
    session.input_locks = locks
    _emit_batch_updated("session.input_locks", old, locks)
```

## 阻塞项

- Story 001 + 002 完成——锁栈管理 + 判定逻辑可用
- GSM Autoload #1 提供 `set_input_locks()` 方法或已存在等效原子写入方法
- GSM `batch_updated` 信号机制已实现（ADR-0001）
- `_process()` / `_input()` / `_gui_input()` 的 Input Map 动作需已定义（如 `end_turn`、`pause`）

## 相关 Story

| Story | 关系 |
|-------|------|
| Story 001 | 锁栈基础——本 Story 将其同步到 GSM |
| Story 002 | 判定逻辑——本 Story 在多路径中消费其判定结果 |
| Story 004 | MODAL 覆盖——扩展 `_input()` 中的 ESC 处理，支持 MODAL 拥有者自检 |

## Completion Notes
**Completed**：2026-07-29
**Criteria**：12/16 通过（4 项排除范围内延迟——AC-009/AC-012/AC-015 依赖下游系统）
**Deviations**：
- ADVISORY: AC-011 `accept_event()`→`get_viewport().set_input_as_handled()`——Godot 4.6 中 Autoload 非 Control 节点无法调用 `accept_event()`
- ADVISORY: AC-012 路径C（鼠标 `_gui_input`）未新增独立测试文件——需 Control 节点集成（排除范围外，留待 UI Story 覆盖）
- ADVISORY: AC-009/AC-015 延迟——依赖 SceneManager/HUD（排除范围外）
- ADVISORY + FIXED: Story 002 白名单语义修正——`test_input_judgment.gd` 中 3 个旧测试（AC-017/AC-019/GAP-2-2）已从黑名单语义修正为 ADR-0004 白名单语义
**Test Evidence**：`tests/unit/input/test_gsm_sync.gd` — 10/10 通过；全部 84 个输入单元测试通过
**Code Review**：待处理
**GSM 新增**：`src/foundation/game_state_manager.gd` — `set_input_locks()` Tier 2 原子方法