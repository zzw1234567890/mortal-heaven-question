# ADR-0005：输入管理器 — 四级锁栈 + 双焦点独立判定

## 状态
Proposed

## 日期
2026-07-24

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Foundation / Input |
| **知识风险** | HIGH（Godot 4.6 LLM 知识截止 2025-05——双焦点系统、SDL3 手柄驱动均在截止之后） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/modules/input.md`、`docs/engine-reference/godot/breaking-changes.md`、`docs/engine-reference/godot/deprecated-apis.md`、`docs/engine-reference/godot/current-best-practices.md` |
| **使用的截止后 API** | 4.6 双焦点系统（mouse ≠ keyboard focus——`grab_focus()` 仅影响键盘/手柄焦点，不影响鼠标焦点）；4.5 SDL3 手柄驱动（API 不变——但底层行为变化可能影响设备检测和映射）；4.5 递归 Control 禁用（`process_mode` + `mouse_filter` 可禁用整个节点层级的交互） |
| **需要验证** | 4.6 双焦点在自定义 Control 组件上的实际行为——`_gui_input()` 和 `_unhandled_input()` 在鼠标和键盘分别获得焦点时的响应差异（参见 architecture.md OQ-02） |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——`session.input_locks: Array[int]` 由 InputManager 写入；锁状态变更发射 `batch_updated` 信号——HUD 和其他系统通过 GSM 信号获知锁变更，而非直接依赖 InputManager） |
| **启用** | 无（本 ADR 不启用其他 ADR——输入锁栈是横切基础设施，所有需要锁输入的系统在实现时查询锁栈） |
| **阻塞** | 战斗 Epic（战斗系统调用 `push_lock(animation)` 播放动画时）、叙事 Epic（对话系统调用 `push_lock(dialogue)` 展示对话时）、UI Epic（弹窗调用 `push_lock(modal)` 展示弹窗时）、场景管理 Epic（场景转换调用 `push_lock(transition)` 加载场景时） |
| **排序说明** | Foundation 层第 4 个 ADR（按 architecture.md §必需的 ADR 编号）。Autoload 初始化顺序 #2：`GSM → InputManager → SceneManager → SaveLoad → EventSystem`。InputManager 在 SceneManager 之前初始化——SceneManager 的场景转换锁依赖 InputManager |

## 上下文

### 问题陈述

游戏有多个系统需要在特定时刻阻止或限制玩家输入：
- **对话系统**：对话进行时应阻止 gameplay 输入（移动地图/触发事件），但允许 UI 导航（选项选择/对话推进）
- **战斗动画**：卡牌效果结算动画播放时阻止所有 gameplay 和对话输入，但允许 UI 导航（查看卡牌详情）
- **弹窗/模态**：模态弹窗（设置、确认、战利品选择）展示时阻止弹窗外的所有输入
- **场景转换**：加载/转场时阻止所有输入——防止玩家在半加载的场景中触发操作

Godot 4.6 的核心技术挑战：**双焦点系统**将鼠标/触摸焦点与键盘/手柄焦点分离。在 Godot 4.5 之前，`grab_focus()` 对所有输入设备生效；在 4.6 中，它只影响键盘/手柄焦点——鼠标 hover 焦点独立存在。这意味着即使输入被锁阻止，鼠标 hover 效果（高亮、tooltip）仍可能触发——需要在锁栈判定中显式处理设备类型。

同时，多个系统可能同时请求输入锁（如对话中弹出确认弹窗），需要一种机制防止乱序解锁——系统 A push 的锁不应被系统 B 误 pop。

### 约束

- **双焦点显式处理**：锁判定须区分鼠标和键盘/手柄设备——设备类型由调用方显式传递，不依赖自动检测
- **栈式锁管理**：push/pop 配对——锁按照 LIFO（后进先出）顺序释放。错误 pop（比如 pop 不属于自己的锁）须记录警告
- **单线程语义**：Godot GDScript 是单线程的——锁是语义 guard，不是多线程互斥锁。术语选用 `push_lock` / `pop_lock` 而非 `lock` / `unlock` 以避免混淆
- **GSM 为锁状态的所有者**：`session.input_locks` 存储在 GSM 中——锁变更通过 GSM 的 `batch_updated` 信号传播，而非 InputManager 独立信号
- **初始化顺序**：InputManager 在 GSM 之后、SceneManager 之前初始化（Autoload #2）
- **帧预算**：`is_input_allowed()` 每帧可能被多次调用（UI 系统 × N 个控件）——必须 O(1) 且 <0.01ms

### 需求

- 四级锁栈，严格度递增：dialogue(0) → animation(1) → modal(2) → transition(3)
- 严格度判定：当前锁栈中的最高级锁决定允许的输入类型
- 动作类型分类：GAMEPLAY（地图移动、事件触发）、DIALOGUE（对话推进、选项选择）、UI_NAV（菜单浏览、卡牌详情）、ANY（所有输入）
- 设备类型分类：MOUSE、KEYBOARD、GAMEPAD——调用方显式传递
- 锁ID追踪：每个锁携带 `source: StringName`（调用方标识），防止跨系统误 pop
- 锁变更通知：通过 GSM 信号传播——HUD、场景管理器等消费系统通过 GSM 获知锁状态变化

## 决策

**输入管理器实现为四级锁栈 + 设备类型独立判定。锁严格度 ascending（dialogue < animation < modal < transition），每级锁定义允许的动作类型范围。push/pop 配对调用——调用方标识追踪 source，错误 pop 记录警告。4.6 双焦点通过 `check_device_allowed(device_type)` 独立判定处理——鼠标锁和键盘锁独立管理。**

### 架构图

```
┌──────────────────────────────────────────────────────────────────┐
│                    InputManager (Autoload #2)                     │
│                                                                   │
│  ┌─ 锁栈 ────────────────────────────────────────────────┐       │
│  │ _lock_stack: Array[LockEntry]                          │       │
│  │   LockEntry = {                                        │       │
│  │     type: LockType,          # dialogue|animation|...  │       │
│  │     source: StringName,      # 调用方标识              │       │
│  │     device_mask: int,        # 位掩码——限制的设备      │       │
│  │   }                                                    │       │
│  │                                                        │       │
│  │ 严格度映射 (ascending):                                │       │
│  │   dialogue  = 0  → 允许 DIALOGUE + UI_NAV + ANY       │       │
│  │   animation = 1  → 允许 UI_NAV + ANY                  │       │
│  │   modal     = 2  → 允许 MODAL_OWNER + ANY              │       │
│  │   transition = 3 → 允许 NOTHING                        │       │
│  │                                                        │       │
│  │ 设备类型位掩码 (可组合):                               │       │
│  │   MOUSE    = 1 << 0   (= 1)                            │       │
│  │   KEYBOARD = 1 << 1   (= 2)                            │       │
│  │   GAMEPAD  = 1 << 2   (= 4)                            │       │
│  │   ALL      = MOUSE | KEYBOARD | GAMEPAD  (= 7)         │       │
│  └────────────────────────────────────────────────────────┘       │
│                                                                   │
│  ┌─ 公共 API ────────────────────────────────────────────┐       │
│  │                                                        │       │
│  │ ## 锁管理                                              │       │
│  │ push_lock(type: LockType, source: StringName,           │       │
│  │           device_mask: int = DEVICE_ALL) → void         │       │
│  │ pop_lock(source: StringName) → void                    │       │
│  │ clear_locks(source: StringName = "") → void             │       │
│  │                                                        │       │
│  │ ## 输入判定（每帧调用）                                 │       │
│  │ is_input_allowed(action_type: ActionType,               │       │
│  │                   device: DeviceType) → bool            │       │
│  │ is_action_blocked(action_name: StringName) → bool       │       │
│  │                                                        │       │
│  │ ## 查询                                                │       │
│  │ get_current_lock() → LockType  # 当前最高级锁           │       │
│  │ get_lock_stack() → Array[Dictionary]  # 调试/诊断用     │       │
│  │ has_lock(source: StringName) → bool                    │       │
│  └────────────────────────────────────────────────────────┘       │
│                                                                   │
│  ┌─ 信号（通过 GSM 传播）─────────────────────────────────┐       │
│  │ push_lock() → GSM 写入 session.input_locks              │       │
│  │             → GSM 发射 batch_updated 信号                │       │
│  │ pop_lock()  → GSM 写入 session.input_locks              │       │
│  │             → GSM 发射 batch_updated 信号                │       │
│  │                                                        │       │
│  │ 监听者：HUD（更新输入提示）、场景管理器（转场确认）       │       │
│  └────────────────────────────────────────────────────────┘       │
└──────────────────────────────────────────────────────────────────┘
         │                              │
         │ GSM.session.input_locks      │ _input(event) / 
         │ (读写)                        │ _unhandled_input(event)
         ▼                              ▼
    ┌──────────┐                  ┌──────────────┐
    │   GSM    │                  │  Control 树   │
    │ session  │                  │ (5 UI 系统)   │
    │ .input_  │                  │              │
    │  locks   │                  │ ⚠️ 4.6 双焦点  │
    └──────────┘                  │ 鼠标焦点 ≠    │
                                  │ 键盘焦点      │
                                  └──────────────┘
```

### 关键接口

#### LockType 和 ActionType 枚举

```gdscript
## 锁类型——严格度递增
## 当前锁栈最高级锁 = max(所有活跃锁的 LockType)
enum LockType {
    DIALOGUE = 0,    # 对话进行中——允许 DIALOGUE + UI_NAV + ANY
    ANIMATION = 1,   # 动画播放中——允许 UI_NAV + ANY
    MODAL = 2,       # 模态弹窗——仅允许 MODAL_OWNER + ANY（在弹窗上下文中）
    TRANSITION = 3,  # 场景转场——阻止所有输入
}

## 动作类型——被锁判定过滤
enum ActionType {
    ANY = 0,          # 系统级动作（退出、截图——始终允许）
    UI_NAV = 1,       # UI 导航（菜单浏览、卡牌详情、tooltip）
    DIALOGUE = 2,     # 对话交互（选项选择、对话推进）
    GAMEPLAY = 3,     # 玩法输入（地图移动、卡牌拖拽、事件触发、战斗操作）
}

## 设备类型——4.6 双焦点独立判定
enum DeviceType {
    MOUSE = 1,        # 鼠标/触摸
    KEYBOARD = 2,     # 键盘
    GAMEPAD = 4,      # 手柄 (SDL3, 4.5+)
}
```

#### 输入允许判定——核心算法

```gdscript
## 每帧被 UI 系统调用多次——必须 O(1) + 轻量
func is_input_allowed(action_type: ActionType, device: DeviceType) -> bool:
    ## ANY 类型始终允许——系统级快捷键不可被锁阻止
    if action_type == ActionType.ANY:
        return true
    
    ## 空栈 = 无锁 = 所有输入允许
    if _lock_stack.is_empty():
        return true
    
    ## 检查设备类型是否被锁 —— 4.6 双焦点独立判定
    if not _check_device_allowed(device):
        return false
    
    ## 当前最高级锁 = max(栈中所有锁的 LockType)
    var current_lock: LockType = _get_highest_lock()
    
    ## 严格度判定
    match current_lock:
        LockType.DIALOGUE:
            # 对话锁——仅阻止 GAMEPLAY，允许 DIALOGUE + UI_NAV
            return action_type != ActionType.GAMEPLAY
        LockType.ANIMATION:
            # 动画锁——阻止 GAMEPLAY + DIALOGUE，允许 UI_NAV
            return action_type == ActionType.UI_NAV
        LockType.MODAL:
            # 模态锁——仅允许特定弹窗的输入（在弹窗上下文中处理）
            # 默认阻止所有非 ANY 输入——弹窗自行覆盖
            return false
        LockType.TRANSITION:
            # 转场锁——阻止所有输入（包括 UI_NAV）
            return false
    
    return false  # 不应到达

## 4.6 双焦点——检查设备是否被当前锁栈中的设备掩码覆盖
func _check_device_allowed(device: DeviceType) -> bool:
    for lock_entry in _lock_stack:
        # device_mask 是位掩码——检查 device 位是否被设置
        if not (lock_entry.device_mask & device):
            return false  # 此设备被该锁的掩码排除
    return true
```

#### push/pop 配对 + source 追踪

```gdscript
## LockEntry 内部结构
class LockEntry:
    var type: LockType
    var source: StringName      # 调用方标识（如 &"dialogue_system"、&"scene_manager"）
    var device_mask: int        # 此锁限制的设备位掩码

## push 锁——调用方负责：系统完成后 pop_lock(source)
func push_lock(type: LockType, source: StringName, device_mask: int = DEVICE_ALL) -> void:
    ## 重复 push 检测——同一 source 重复 push 是代码 bug
    for entry in _lock_stack:
        if entry.source == source:
            push_warning("InputManager: duplicate push_lock('%s') from '%s'——可能丢失了 pop_lock() 调用" %
                        [LockType.find_key(type), source])
            return
    
    var entry := LockEntry.new()
    entry.type = type
    entry.source = source
    entry.device_mask = device_mask
    _lock_stack.append(entry)
    
    ## 写入 GSM → 发射 batch_updated
    _sync_to_gsm()
    
    print("InputManager: push %s lock (source: '%s', stack depth: %d)" %
          [LockType.find_key(type), source, _lock_stack.size()])

## pop 锁——调用方在操作完成/取消时调用
func pop_lock(source: StringName) -> void:
    ## 检查 source 是否在栈中
    var found := false
    for i in range(_lock_stack.size() - 1, -1, -1):
        if _lock_stack[i].source == source:
            var removed_type: LockType = _lock_stack[i].type  # 必须在 remove_at() 之前捕获——否则访问已移位/OOB 元素
            _lock_stack.remove_at(i)
            found = true
            print("InputManager: pop %s lock (source: '%s', stack depth: %d)" %
                  [LockType.find_key(removed_type), source, _lock_stack.size()])
            break
    
    if not found:
        push_warning("InputManager: pop_lock('%s') called but source not in stack——可能已通过 clear_locks() 移除" % source)
        return

## 清除指定 source 的所有锁——用于应急/系统重置
func clear_locks(source: StringName = "") -> void:
    if source == "":
        _lock_stack.clear()
    else:
        _lock_stack = _lock_stack.filter(func(e): return e.source != source)
    _sync_to_gsm()
```

#### GSM 同步 + 信号传播

```gdscript
## 内部——将锁栈写入 GSM session 域
## ⚠️ 类型细化说明：ADR-0001 声明 session.input_locks 为 Array[int]，
##    本 ADR 将其细化为 Array[Dictionary]——每个字典包含 {type, source, device_mask}。
##    这是 ADR 之间正常的契约细化——ADR-0001 定义总体形状，ADR-0005 定义精确负载。
func _sync_to_gsm() -> void:
    var serialized: Array[Dictionary] = []
    for entry in _lock_stack:
        serialized.append({
            "type": entry.type,
            "source": entry.source,
            "device_mask": entry.device_mask,
        })
    GSM.set_input_locks(serialized)  # GSM 第二层原子方法（新增——见 ADR-0001）
    # set_input_locks() 内部发射 batch_updated 信号:
    #   {"session.input_locks": {"old": [...], "new": serialized}}
```

#### 调用方模式

```gdscript
## 对话系统——展示对话时
func _show_dialogue() -> void:
    InputManager.push_lock(LockType.DIALOGUE, &"dialogue_system")
    ## 展示对话 UI ...

func _on_dialogue_closed() -> void:
    InputManager.pop_lock(&"dialogue_system")

## 场景管理器——转场时锁所有输入
func request_scene_change(from: String, to: String, type: int) -> void:
    InputManager.push_lock(LockType.TRANSITION, &"scene_manager")
    ## 加载新场景 ...

func _on_scene_loaded(new_scene: Node) -> void:
    InputManager.pop_lock(&"scene_manager")

## 战斗系统——播放卡牌效果动画时锁 gameplay + dialogue
func _play_card_animation(card: CardInstance) -> void:
    InputManager.push_lock(LockType.ANIMATION, &"combat_system")
    await _animate_card_effect(card)
    InputManager.pop_lock(&"combat_system")
```

#### 4.6 双焦点集成模式（UI 系统消费侧）

```gdscript
## ⚠️ 输入分发路径选择（Godot 4.6 事件派发顺序）：
##   _input(event) → GUI 处理 (_gui_input) → _unhandled_input(event)
## Control 节点获得键盘焦点后会消耗 InputEventKey——_unhandled_input() 不会触发
## 因此采用双路径策略：
##   GAMEPLAY 键盘输入 → Input Map 动作轮询 (_process 中 is_action_just_pressed)
##   UI_NAV 快捷键 → _input()（在 GUI 派发前拦截）
##   鼠标交互 → _gui_input()（标准 Control 事件）

## 路径 A：GAMEPLAY 键盘输入——通过 Input Map 动作轮询（推荐的惯用模式）
## 在 InputManager Autoload 的 _process() 中集中处理：
func _process(_delta: float) -> void:
    ## Input Map 动作——可重映射，不受 GUI 焦点影响
    if Input.is_action_just_pressed(&"end_turn"):
        if _check_gameplay_action(&"end_turn", DeviceType.KEYBOARD):
            _on_end_turn_requested()
    if Input.is_action_just_pressed(&"pause"):
        if InputManager.is_input_allowed(ActionType.UI_NAV, DeviceType.KEYBOARD):
            toggle_pause()

func _check_gameplay_action(action: StringName, device: DeviceType) -> bool:
    if not InputManager.is_input_allowed(ActionType.GAMEPLAY, device):
        return false

## 路径 B：UI_NAV 快捷键——_input() 在 GUI 派发前拦截
## InputManager Autoload 本身处理全局快捷键：
func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
        if InputManager.is_input_allowed(ActionType.UI_NAV, DeviceType.KEYBOARD):
            toggle_pause()
            accept_event()  # 阻止进一步传播

## 路径 C：鼠标交互——标准 _gui_input() 在 Control 节点上
## 适用于所有 Control 派生节点：
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if not InputManager.is_input_allowed(ActionType.GAMEPLAY, DeviceType.MOUSE):
            return  # 鼠标 gameplay 输入被锁
        handle_click(event.position)

## 非 Control 交互元素（Area2D、Sprite2D 拖拽等）：
func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
    if event is InputEventMouseButton:
        if not InputManager.is_input_allowed(ActionType.GAMEPLAY, DeviceType.MOUSE):
            return
        handle_card_drag(event.position)
```

**关键设计决策**：
- **GAMEPLAY 键盘动作 → Input Map 轮询**（`Input.is_action_just_pressed()`）：不受 GUI 焦点影响——当某个 Control 获得键盘焦点时 `_unhandled_input()` 不会触发，但 `Input` 单例直接读取设备状态。同时支持可重映射按键。
- **UI_NAV 快捷键 → `_input()`**：在 GUI 派发前拦截——Control 节点可能消耗 Escape/Space 事件，全局快捷键不应受此影响
- **鼠标交互 → `_gui_input()` / `_input_event()`**：标准 Godot 事件派发——鼠标事件由 Control 树或 Area2D 碰撞区域自动路由

### 初始化顺序

```
T+0: GSM._ready() → gsm_initialized
T+1: InputManager._ready() → _lock_stack = []（从 GSM.session.input_locks 恢复）
T+2: SceneManager._ready() → 可调用 InputManager.push_lock()
```

**场景变更后**：InputManager 连接 `SceneTree.tree_changed` 信号自动清除所有锁（`_lock_stack.clear()`——新场景不应继承旧场景的锁）。SceneManager 调用 `change_scene_to_file()` 后，tree 变更触发 InputManager 的清理。SceneManager 仍可在 `_on_scene_loaded` 中显式调用 `InputManager.clear_locks()` 作为防御——但 InputManager 的自动清理不依赖 SceneManager 存在。

### 调用方锁使用速查

| 场景 | 锁类型 | Device mask | 允许什么 | 调用方 source |
|------|--------|-------------|---------|-------------|
| 对话进行中 | DIALOGUE | ALL | DIALOGUE + UI_NAV | `&"dialogue_system"` |
| 战斗动画 | ANIMATION | ALL | UI_NAV | `&"combat_system"` |
| 设置弹窗 | MODAL | ALL | 仅弹窗内 | `&"settings_menu"` |
| 战利品选择 | MODAL | ALL | 仅弹窗内 | `&"loot_screen"` |
| 场景加载 | TRANSITION | ALL | 无 | `&"scene_manager"` |
| 战斗转场（动画期间） | TRANSITION | ALL | 无 | `&"scene_manager"` |
| 仅锁键盘（允许鼠标查看） | ANIMATION | MOUSE \| GAMEPAD | 键盘锁——鼠标仍可 hover tooltip | `&"combat_system"` |

## 考虑的替代方案

### 替代方案 A：全局单一布尔开关
- **描述**：`input_enabled: bool`——全局开关，设置 false 阻止所有输入
- **优点**：极简——一行代码设置；无 push/pop 顺序问题
- **缺点**：无细粒度控制——"对话时阻止 gameplay 但允许 UI 导航"无法实现。两个系统同时需要锁时产生冲突（系统 A 解锁覆盖系统 B 的锁）
- **拒绝原因**：游戏需要 UI_NAV 在对话/动画期间保持可用（查看卡牌详情、浏览菜单）——单一开关无法区分

### 替代方案 B：完全依赖 Godot Control 树机制
- **描述**：不实现集中的 InputManager——通过 `Control.mouse_filter` 和 `Node.process_mode` 在各个节点上分散管理
- **优点**：无额外代码——完全利用引擎原生功能；4.5+ 递归 Control 禁用可一次性禁用整个子树
- **缺点**：分散在各节点上——无集中仲裁者，无法统一审计"当前哪些输入被阻止"。"对话中阻止 gameplay"需要每个 gameplay Control 节点都检查对话状态——紧耦合且维护成本高
- **拒绝原因**：集中 lock 判定是横切关注点——分散在 30+ Control 节点上的状态检查将导致不可调试的"为什么这个按钮不工作"问题。集中判定一次，所有消费者通过 `is_input_allowed()` 查询

### 替代方案 C：优先级数字锁（非栈式）
- **描述**：`set_lock(priority: int)`——优先级数字越高锁越严格。系统设置和清除优先级数字，而非 push/pop。
- **优点**：无栈序问题——不需要配对 push/pop
- **缺点**：如果两个系统设置相同的优先级数字，其中一个清除时可能错误地解锁另一个。且调用方忘记清除锁时无自动恢复——只能依赖超时
- **拒绝原因**：栈式管理强制调用方配对 push/pop——忘记 pop 的 bug 会被重复 push 检测捕获（push 相同 source 时警告）。优先级数字方案无法提供同等级别的调用方问责

## 后果

### 积极的
- **细粒度控制**：四级锁栈支持"对话中禁止 gameplay 但允许 UI 导航"等复杂场景
- **4.6 双焦点安全**：设备类型独立判定——鼠标 hover 和键盘操作分开处理
- **调用方问责**：source 追踪 + 重复 push 检测——忘记 pop 的 bug 在开发阶段即被日志暴露
- **集中可调试**：`get_lock_stack()` 返回当前所有活跃锁——调试"为什么输入不响应"时可立即定位原因
- **GSM 单一数据源**：锁状态通过 GSM 传播——HUD 不需要直接依赖 InputManager，只需监听 GSM 信号
- **栈序保护**：LIFO 释放确保嵌套操作（对话中弹确认框→关闭确认框→恢复对话）不会意外解除对话锁

### 消极的
- **push/pop 配对要求严格**：每个 push_lock() 必须对应一个 pop_lock()。使用 `await` 的异步流程中如果异常路径没有 catch + pop，将导致锁泄漏
- **每帧多次判定开销**：UI 系统可能每帧调用 `is_input_allowed()` 数十次——虽然每次 O(1) 但仍然是额外开销
- **设备掩码复杂度**：部分调用方可能不理解位掩码——需要清晰文档和默认值（DEVICE_ALL）

### 风险
- **`await` 异常路径锁泄漏**：战斗动画 `await _animate()` 被取消或异常 → `pop_lock()` 从未执行。缓解：在调用方中使用 try-finally 模式（GDScript 无 try-catch——但有 `_on_animation_finished` 信号 + 超时保底）。InputManager 在 `clear_locks()` 调用时重置所有锁（SceneManager 在场景卸载时调用）
- **source 名称冲突**：两个不同系统使用相同的 source 名称 → push 检测误报警告。缓解：使用明确的 StringName 标识（按系统命名规范）——`&"dialogue_system"`、`&"combat_system"`、`&"scene_manager"`
- **4.6 双焦点未充分测试**：在目标硬件上，鼠标 hover 和键盘焦点切换的实际行为未知（architecture.md OQ-02）。缓解：在编码前于目标硬件上测试 `_gui_input` / `_unhandled_input` 对双焦点事件的响应

## 解决的 GDD 需求

无专用 GDD——输入管理器是横切基础设施，不直接对应玩家面向的机制。其需求来自 architecture.md §Foundation 层模块归属。

| 来源 | 需求 | 本 ADR 如何解决 |
|------|------|--------------------------|
| architecture.md §Foundation 层 | `session.input_locks` 栈由 InputManager 拥有 | 确立 LockType 枚举 + LockEntry 结构 + _lock_stack 管理 |
| architecture.md §输入管理器 | `is_input_allowed(type)` / `push_lock(type)` / `pop_lock(type)` | 确立公共 API——`is_input_allowed(ActionType, DeviceType)` / `push_lock(LockType, source, device_mask)` / `pop_lock(source)` |
| architecture.md §输入管理器 | 四级锁栈 (dialogue=0, animation=1, modal=2, transition=3) | 确立 LockType 枚举 + 严格度判定算法——`_get_highest_lock()` 判定当前最高级锁 |
| architecture.md §输入管理器 | 信号: `input_lock_changed(lock_type, is_locked)` | 锁变更通过 GSM `batch_updated` 信号传播——`session.input_locks` 变更 → HUD 响应 |
| architecture.md §关键约束 | 所有使用 Control 节点的 UI 系统必须处理 4.6 双焦点 | 确立 DeviceType 枚举 + `_check_device_allowed()` 独立判定——鼠标和键盘分别检查 |
| architecture.md §初始化顺序 | T+0: GSM → InputManager → SceneManager → SaveLoad → EventSystem | 确立 InputManager Autoload #2——在 GSM 之后、SceneManager 之前 |
| architecture.md §路径 D：初始化 | DIALOGUE LOCK 场景支持 | 确立 dialogue lock 判定规则——允许 DIALOGUE + UI_NAV |
| architecture.md OQ-02 | 4.6 双焦点在自定义 Control 组件上的实际行为 | 在「需要验证」中标记——需在目标硬件上测试 |
| ADR-0001 §第二层 | GSM 通过 `batch_updated` 信号传播锁变更 | 确立 `_sync_to_gsm()`——写入 `GSM.session.input_locks` → 发射 `batch_updated` |

## 性能影响
- **CPU**：`is_input_allowed()` 每次调用 O(n) 遍历锁栈（n ≤ 4——四级锁栈深度极少超过 2）。每次调用 <0.005ms。每帧最多 ~50 次调用（UI 系统输入处理）→ 总开销 <0.25ms/帧——远低于 16.6ms 预算
- **内存**：锁栈 Array[LockEntry] 通常 0-2 元素 × ~32B = <64B。GSM 序列化后的 `session.input_locks` <100B
- **加载时间**：无——InputManager._ready() 仅初始化空数组

## 迁移计划
无现有代码需迁移。

## 验证标准
- 通过 GUT：`InputManager` 测试套件覆盖：
  - `push_lock(DIALOGUE)` + `is_input_allowed(GAMEPLAY, MOUSE)` → false（对话锁阻止 gameplay）
  - `push_lock(DIALOGUE)` + `is_input_allowed(DIALOGUE, KEYBOARD)` → true（对话锁允许对话输入）
  - `push_lock(ANIMATION)` + `is_input_allowed(UI_NAV, MOUSE)` → true（动画锁允许 UI 导航）
  - `push_lock(TRANSITION)` + `is_input_allowed(UI_NAV, KEYBOARD)` → false（转场锁阻止一切）
  - `is_input_allowed(ANY, MOUSE)` → true（ANY 始终允许——无论锁栈状态）
  - 多个锁同时存在 → `_get_highest_lock()` 返回最高严格度
  - `push_lock(DIALOGUE, "sys_a")` + `push_lock(ANIMATION, "sys_b")` → `pop_lock("sys_a")` → 当前锁为 ANIMATION（b 仍活跃）
  - `pop_lock("nonexistent")` → 记录警告（源不存在）
  - `push_lock(DIALOGUE, "sys_a")` + `push_lock(DIALOGUE, "sys_a")`（重复）→ 记录警告并跳过
  - 设备独立判定：`push_lock(..., device_mask=KEYBOARD)` → mouse 输入仍允许
  - `clear_locks()` → 栈清空，所有输入恢复
- 通过集成测试：
  - 对话系统 push + pop 不影响 UI_NAV 可操作性
  - 场景转场中所有输入被阻止 → 转场完成后恢复

## 相关决策
- ADR-0001（GSM——`session.input_locks` 状态持有 + `batch_updated` 信号传播）
- architecture.md §场景管理器（SceneManager 消费 `push_lock(TRANSITION)` 和 `clear_locks()`）
