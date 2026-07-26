# ADR-0005：场景管理器 — 唯一场景转换仲裁者 + 5 阶段管线

## 状态
Accepted

## 日期
2026-07-24

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Foundation / Scene Management |
| **知识风险** | LOW（`SceneTree.change_scene_to_file()` 为 4.0+ 稳定 API；`tree_changed` 信号为 4.x 稳定信号） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/deprecated-apis.md`、`docs/engine-reference/godot/modules/ui.md` |
| **使用的截止后 API** | None——核心 API（`SceneTree.change_scene_to_file()`、`SceneTree.tree_changed`）均为 4.0+ 稳定 |
| **需要验证** | `change_scene_to_file()` 在 4.6 D3D12 默认渲染器下的白闪/黑闪行为（见 §风险 #5）——加载画面根 Control 必须为全屏 `ColorRect` 以遮挡渲染器级闪烁 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——`session.current_scene` 写入 + `scene_changed` 信号发射）、ADR-0004（InputManager——`push_lock(TRANSITION)` / `pop_lock(TRANSITION)` / `clear_locks()`）、ADR-0002（SaveLoad——转场前 `auto_save()` 触发；存档 `meta` 容器需新增 `current_scene` + `current_scene_id` 字段以支持读档恢复） |
| **启用** | 所有场景依赖转换的系统（战斗系统→场景加载、探索系统→主菜单返回、存档/读档→场景恢复） |
| **阻塞** | 战斗 Epic（战斗场景的加载和退出）、探索 Epic（探索场景与主菜单/事件场景之间的导航）、叙事 Epic（剧情/对话场景切换）、读档 Epic（读档后场景恢复） |
| **排序说明** | Foundation 层第 5 个 ADR（architecture.md §必需的 ADR #5）。Autoload 初始化顺序 #3：`GSM → InputManager → **SceneManager** → SaveLoad → EventSystem`。SceneManager 在 InputManager 之后初始化——转场锁依赖 InputManager。在 SaveLoad 之前初始化——读档恢复依赖 SceneManager 的场景跳转能力 |

## 上下文

### 问题陈述

游戏有多达 15+ 个场景（主菜单、身份选择、卡组编辑、探索地图、战斗、渡劫、商店、事件面板、结算、战败、加载画面……），被至少 6 个系统触发（主菜单 UI、探索系统、战斗系统、对话系统、存档系统、渡劫系统）。在没有单一仲裁者的情况下：

- **绕过钩子**：任何系统可以直接调用 `get_tree().change_scene_to_file()`，跳过输入锁定、跳过自动存档、跳过音频过渡——导致玩家在转场动画期间能操作、进度漏存、BGM 与场景不匹配
- **冲突写入 `current_scene`**：多个系统竞相更新 `GSM.session.current_scene`，信号发射顺序不确定
- **加载画面不统一**：不同系统各自实现加载指示器（或忘记实现），玩家体验不一致
- **转场碰撞**：两个系统同时请求场景跳转（如探索触发事件 + 战斗触发渡劫），引擎行为未定义

需要的是一个唯一入口，任何系统要切换场景都必须通过它——并且在这个入口强制所有 pre/post 钩子。

### 约束

- 必须作为 Godot Autoload 运行——在任何场景加载之前存在且在场景变更后留存
- 必须与 InputManager（ADR-0004）协作——转场期间锁全部输入，新场景就绪后解锁
- 必须与 SaveLoad（ADR-0002）协作——转场前触发自动存档
- 必须与 GSM（ADR-0001）协作——通过 GSM 写入 `current_scene` 并发射 `scene_changed` 信号
- Godot 的 `change_scene_to_file()` 是异步的——调用立即返回，新场景在下一帧才就绪。SceneManager 必须追踪"转场进行中"状态
- 加载画面必须是独立场景（防止旧场景状态泄漏到新场景）

### 需求

- 所有场景转换必须通过 `SceneManager.request_scene_change()`——禁止直接调用 `get_tree().change_scene_to_file()`
- 转场前：自动保存（触发 SaveLoad）、锁定输入（push_lock TRANSITION）、展示加载画面
- 转场后：更新 `GSM.session.current_scene`、发射 `scene_changed` 信号、解锁输入（pop_lock TRANSITION）、隐藏加载画面
- 正在转场时拒绝新的转换请求（返回 `false`）
- 场景路径通过集中式枚举注册表管理——类型安全，编译时检查

## 决策

**SceneManager 将作为 Godot Autoload 实现，拥有 5 阶段场景转换管线：**

### 5 阶段转换管线

```
Phase 1 — VALIDATE
  request_scene_change(from, to, type) → bool
  ├─ 校验：_transitioning == false（拒绝并发请求）
  ├─ 校验：to 在 SCENE_PATHS 中存在
  └─ 校验：from == _current_scene_id（防御性检查）→ 不匹配时记录警告但继续

Phase 2 — PRE-TRANSITION
  ├─ _transitioning = true
  ├─ InputManager.push_lock(LockType.TRANSITION, &"scene_manager")  # 阻止所有输入
  ├─ SaveLoad.auto_save()  # 触发自动存档——同步写入磁盘（预计 30-100ms），加载画面在此期间显示
  └─ _transition_type = type  # 传递给加载画面
     → 发射 pre_transition(from, to, type)  # 音频系统/UI 系统监听

Phase 3 — LOAD → CHANGE
  ├─ change_scene_to_file(SCENE_LOADING)  # 先切到加载画面场景
  ├─ await tree_changed  # 加载画面场景就绪
  ├─ 向 loading_screen 场景传递进度上下文（from, to, type）
  └─ change_scene_to_file(SCENE_PATHS[to])  # 切到目标场景

Phase 4 — POST-LOAD
  ├─ await tree_changed（目标场景就绪）
  ├─ ⚠️ 防御：if get_tree().current_scene.scene_file_path != SCENE_PATHS[to]:
  │     # tree_changed 可能被非场景切换的树变更提前触发——使用 if 而非 assert
  │     # 以确保在发布构建（release）中也执行此防御逻辑
  │     # 失败时：记录错误，_transitioning = false，pop_lock，返回——不执行后续步骤
  ├─ GSM.session.current_scene = SCENE_PATHS[to]
  ├─ GSM.session.scene_id = to
  ├─ GSM 发射 scene_changed  # 通过 batch_updated: {"session.current_scene": {old, new}}
  ├─ InputManager.pop_lock(&"scene_manager")
  └─ 发射 post_transition(from, to)  # ⚠️ 在新场景 _ready() 之后、第一个 _process() 之前发射
     # 消费者在此信号中可安全访问新场景的节点树，但不能依赖 _process() 中计算的状态

Phase 5 — FINALIZE
  ├─ _transitioning = false
  └─ _transition_type = TransitionType.NONE
```

### TransitionType 枚举

```gdscript
enum TransitionType {
    NONE = 0,
    MENU_TO_GAME = 1,      # 主菜单→游戏（长淡入，1.5s BGM过渡）
    GAME_TO_MENU = 2,      # 游戏→主菜单（长淡出，1.5s BGM过渡）
    EXPLORE_TO_COMBAT = 3, # 探索→战斗（快速切入，0.5s BGM过渡）
    COMBAT_TO_EXPLORE = 4, # 战斗→探索（正常切回，1.0s BGM过渡）
    TRIBULATION = 5,       # 渡劫战斗（特殊BGM，0.3s过渡）
}
```

`TransitionType` 驱动音频系统的过渡矩阵（参见 audio-system.md §场景切换音频过渡矩阵）。仅包含场景级转换——UI overlay（弹窗、菜单面板）不属于 SceneManager 职责，由 UI 系统直接管理（必要时通过 InputManager 控制输入锁、通过 GSM.session.ui_state 标记状态）。

### 场景路径注册表

```gdscript
enum SceneID {
    MAIN_MENU = 0,
    IDENTITY_SELECT = 1,
    DECK_EDITING = 2,
    EXPLORATION = 3,
    COMBAT = 4,
    TRIBULATION = 5,
    SHOP = 6,
    EVENT_PANEL = 7,
    RESULT_SCREEN = 8,
    DEFEAT_SCREEN = 9,
    CULTIVATION = 10,
    LOADING = 99        # 内部使用——加载画面
}

const SCENE_PATHS := {
    SceneID.MAIN_MENU:       "res://src/ui/main_menu/main_menu.tscn",
    SceneID.IDENTITY_SELECT: "res://src/ui/identity_select/identity_select.tscn",
    SceneID.DECK_EDITING:    "res://src/ui/deck_editing/deck_editing.tscn",
    SceneID.EXPLORATION:     "res://src/feature/exploration/exploration_scene.tscn",
    SceneID.COMBAT:          "res://src/feature/combat/combat_scene.tscn",
    SceneID.TRIBULATION:     "res://src/feature/tribulation/tribulation_scene.tscn",
    SceneID.SHOP:            "res://src/feature/shop/shop_scene.tscn",
    SceneID.EVENT_PANEL:     "res://src/ui/event_panel/event_panel.tscn",
    SceneID.RESULT_SCREEN:   "res://src/ui/result_screen/result_screen.tscn",
    SceneID.DEFEAT_SCREEN:   "res://src/ui/defeat_screen/defeat_screen.tscn",
    SceneID.CULTIVATION:     "res://src/feature/cultivation/cultivation_scene.tscn",
    SceneID.LOADING:         "res://src/ui/loading/loading_screen.tscn",
}
```

路径在 `const` 字典中——编译时可用，无运行时文件 I/O 开销。新增场景需在此注册表中添加条目。

### 加载画面策略

SceneManager 使用**专用加载场景**（`loading_screen.tscn`）：

```
request_scene_change(exploration, combat) →
  1. change_scene_to_file("res://src/ui/loading/loading_screen.tscn")
  2. 加载画面接收上下文（from=EXPLORATION, to=COMBAT, type=EXPLORE_TO_COMBAT）
     → 通过 SceneManager 调用 loading_screen 根节点的同步方法 set_context() 传递
     → ⚠️ 必须同步——不依赖 _ready() 中的 await，确保上下文在加载画面渲染前就绪
  3. change_scene_to_file("res://src/feature/combat/combat_scene.tscn")
     → Godot 异步加载新场景（加载画面场景仍显示直到新场景就绪）
  4. 新场景 _ready() → SceneManager 检测到 tree_changed → Phase 4-5
```

加载画面是独立场景而非 CanvasLayer overlay——无旧场景状态泄漏风险，且可以利用 Godot 的 `change_scene_to_file()` 异步特性（加载画面场景体积小，切换几乎是即时的）。

### 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                  SceneManager (Autoload #3)                  │
│                                                              │
│  ┌─ 公共 API ───────────────────────────────────────┐       │
│  │ request_scene_change(from, to, type) → bool        │       │
│  │ get_current_scene_id() → SceneID                   │       │
│  │ is_transitioning() → bool                          │       │
│  └───────────────────────────────────────────────────┘       │
│                                                              │
│  ┌─ 场景注册表 ───────────────────────────────────────┐      │
│  │ SCENE_PATHS: Dictionary[SceneID, String]            │      │
│  │ → 集中管理所有场景路径                               │      │
│  │ → 编译时常量，类型安全                               │      │
│  └────────────────────────────────────────────────────┘      │
│                                                              │
│  ┌─ 转换管线 ────────────────────────────────────────┐       │
│  │ Phase 1: VALIDATE (并发检查 + 场景ID存在性)          │       │
│  │ Phase 2: PRE-TRANSITION (锁输入 + 自动存档)          │       │
│  │ Phase 3: LOAD → CHANGE (加载画面 → 目标场景)         │       │
│  │ Phase 4: POST-LOAD (GSM更新 + 信号 + 解锁)           │       │
│  │ Phase 5: FINALIZE (_transitioning = false)           │       │
│  └────────────────────────────────────────────────────┘      │
│                                                              │
│  ┌─ 信号 ───────────────────────────────────────────┐       │
│  │ pre_transition(from, to, type)                     │       │
│  │ post_transition(from, to)                          │       │
│  └───────────────────────────────────────────────────┘       │
│                                                              │
│  ┌─ 内部状态 ───────────────────────────────────────┐       │
│  │ _transitioning: bool = false                        │       │
│  │ _transition_type: TransitionType = NONE             │       │
│  │ _current_scene_id: SceneID                          │       │
│  └────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
    ┌─────────┐      ┌──────────────┐      ┌──────────┐
    │ GSM      │      │ InputManager │      │ SaveLoad │
    │ write    │      │ push/pop     │      │ auto_save│
    │ scene    │      │ TRANSITION   │      │ (fire &  │
    │ + signal │      │ lock         │      │  forget) │
    └─────────┘      └──────────────┘      └──────────┘
```

### 关键接口

```
## 公共 API

request_scene_change(from: SceneID, to: SceneID, type: TransitionType) → bool
  # 请求场景转换——SceneManager 是唯一入口
  # 返回 false 的条件：
  #   - _transitioning == true（当前正在转场）
  #   - to 不在 SCENE_PATHS 中（未注册的场景ID）
  #   - from != _current_scene_id（防御：调用方持有过时引用）
  # 返回 true = 转换已被接受并将异步执行
  # 注意：返回 true 不意味转换完成——调用方应监听 post_transition 信号

get_current_scene_id() → SceneID
  # O(1) 查询——无 GSM 依赖

is_transitioning() → bool
  # 供 UI 系统检查是否可接收输入（InputManager 独立判定——此方法为附加校验层）

## 信号

pre_transition(from: SceneID, to: SceneID, type: TransitionType)
  # Phase 2 发射——消费系统做转场前准备
  # 主要消费者：音频系统（切换 BGM/SFX 场景状态）、HUD（清理浮动 UI）

post_transition(from: SceneID, to: SceneID)
  # Phase 4 发射——消费系统初始化新场景
  # 主要消费者：音频系统（启动新场景音频）、HUD（重建 UI）、探索系统（生成地图）

## GSM 集成

GSM.session.current_scene  # SceneManager 独占写入（String——场景文件路径）
GSM.session.scene_id       # SceneManager 独占写入（int——SceneID 枚举值）
  # 读取者：存档系统（记录玩家所在场景）、音频系统（判定当前场景音频模式）
  # 写入时机：Phase 4（仅在 change_scene_to_file() 成功、tree_changed 信号到达后）

GSM.batch_updated → scene_changed
  # 通过 GSM 的 batch_updated 信号传播——格式：
  # {"session.current_scene": {old: "res://.../exploration.tscn", new: "res://.../combat.tscn"}}

## 输入管理器集成

# Phase 2:
InputManager.push_lock(LockType.TRANSITION, &"scene_manager")
  # 转场期间阻止所有设备、所有输入动作
  # 防止玩家在加载画面/半加载场景中触发操作
  # ⚠️ 4.6 双焦点：TRANSITION 锁依赖 InputManager 的实现同时拦截鼠标焦点和键盘焦点——
  #    SceneManager 不直接管理焦点。若 InputManager 的 TRANSITION 锁仅拦截 Input Map 动作
  #    而允许鼠标 hover 焦点变更，加载画面可能收到 mouse_entered/mouse_exited 信号——
  #    视觉焦点闪烁的根源。缓解措施：loading_screen.tscn 不在 _ready() 中调用 grab_focus()

# Phase 4:
InputManager.pop_lock(&"scene_manager")
  # 新场景就绪后恢复输入

# SceneManager 不直接调用 clear_locks()——
# InputManager 独立通过 tree_changed 信号自动清理（ADR-0004）
# SceneManager 的转换锁推入和弹出遵循正常的 push/pop 生命周期

## 约束和禁止

✗ 任何系统不得直接调用 get_tree().change_scene_to_file()
  → 必须通过 SceneManager.request_scene_change()

✗ 任何系统不得写入 GSM.session.current_scene 或 GSM.session.scene_id
  → 仅 SceneManager 在 Phase 4 写入
  → **架构层面的委托例外**：SceneManager 是 GSM.session.current_scene 和 GSM.session.scene_id
    的指定写入者——此委托已在 architecture.yaml state_ownership 中注册。这并非"绕过 GSM"——
    SceneManager 是 GSM 授权的唯一写入者，其他系统通过 GSM 第三层信号（batch_updated → scene_changed）
    消费此数据。直接属性赋值在此处合法，因为 session 域为瞬态数据，不通过方法调用。详见 ADR-0001 §写入者契约。

✗ SceneManager 不拥有 UI overlay（弹窗、菜单面板）
  → 这些由 UI 系统直接管理，通过 GSM.session.ui_state 标记状态；需要输入锁时 UI 系统直接调用 InputManager
  → SceneManager 仅管理场景级转换——不在 TransitionType 中混杂 UI 状态标记
```

## 考虑的替代方案

### 替代方案 A：不设仲裁者——系统直接调用 SceneTree

- **描述**：各系统自行调用 `get_tree().change_scene_to_file()`。不需要 SceneManager Autoload。
- **优点**：零开销、无中间层、实现极简
- **缺点**：无法强制 pre/post 钩子（输入锁定、自动存档、音频过渡）——依赖每个调用方各自正确实现。音频系统需要监听底层 `tree_changed` 信号并猜测"这是哪种转换"。加载画面不统一。两个系统同时请求切换时行为未定义。
- **拒绝原因**：Godot 的 `change_scene_to_file()` 没有内置钩子系统、没有并发防护、没有转换类型语义。每个调用方自行实现这些就变成了分散的、不一致的非标准实现——这正是"仲裁者"模式要解决的问题。

### 替代方案 B：信号驱动——发射请求，由 TransitionController 场景处理

- **描述**：SceneManager 不直接切换场景。改为发射 `scene_change_requested(from, to, type)` 信号，由专门的 `TransitionController` 场景（持久化在 SceneTree 根节点）监听并执行实际的场景切换。
- **优点**：关注点分离更彻底——SceneManager 只管路由，TransitionController 管视觉效果。更容易自定义转场动画（替换 TransitionController 场景即可）。
- **缺点**：多了一层间接——调试时请求链（系统 A → 信号 → SceneManager → 信号 → TransitionController → change_scene）更长。TransitionController 作为场景内节点需要特别处理以在场景变更后存活（`process_mode = PROCESS_MODE_ALWAYS`）——增加了 Autoload 之外的复杂度。
- **拒绝原因**：5 阶段管线已经提供了足够的关注点分离——pre_transition / post_transition 信号让音频和 UI 系统自主响应，无需单独的 TransitionController 节点。额外的间接层对当前需求（单机 2D 卡牌游戏，15 个场景）来说是过度设计。如果未来需要复杂的 3D 转场效果（粒子过渡、摄像机飞行），可以在 SceneManager 内部扩展 `_play_transition_effect()`，而不改变公共 API。

### 替代方案 C：最小中介——SceneManager 只做路径解析 + 并发防护

- **描述**：SceneManager 维护场景路径注册表并防止并发转换，但**不编排钩子**。调用方负责在调用前自行 lock→save，在 tree_changed 后自行 post-load 初始化。
- **优点**：SceneManager 代码量极少（约 30 行）、无隐式行为（调用方完全控制钩子时序）
- **缺点**：将"不遗忘钩子"的责任从引擎转移到了每个调用方。6 个调用方 × 3 个必需钩子（lock、save、unlock）= 18 个分散的实现点——其中一个遗漏就会导致 bug。升级难度（新增钩子需要修改每个调用方）。
- **拒绝原因**：违反"不信任调用方"原则——防止人为错误的正确方式是集中化，而非依赖纪律。5 阶段管线保证所有转换都经过相同的钩子序列，零遗漏。

## 后果

### 积极的

- **强制执行钩子**：输入锁定、自动存档、加载画面在**每一次**场景转换中保证执行——调用方无法跳过
- **场景路径单一真理来源**：新增场景只需在 `SCENE_PATHS` 字典中添加一个条目——编译器会捕获拼写错误（`SceneID` 枚举）
- **转换类型驱动音频**：`TransitionType` 枚举直接映射到 audio-system.md 的 BGM 过渡矩阵——音频系统只需监听 `pre_transition` 信号并查表
- **加载画面体验一致**：所有转换使用统一的 `loading_screen.tscn`——美术资源和动画集中管理
- **可观测**：`pre_transition` / `post_transition` 信号为日志、调试工具、自动化测试提供了自然的插桩点

### 消极的

- **增加了 Foundation 层模块数**：SceneManager 是第 6 个 Foundation Autoload——初始化顺序（GSM → InputManager → SceneManager → SaveLoad → EventSystem）又多了一个需要维护和测试的节点
- **TransitionType 枚举需要与音频过渡矩阵保持同步**：每新增一种场景转换类型，enum 和 audio-system.md 都必须更新——这是同步开销（但由编译器强制：新增 enum 值后音频系统的 match 语句会在编译时报 missing-branch warning）
- **转场延迟增加的绝对最小值**：加载画面场景的加载（虽然体积很小）增加约 50-100ms 的额外延迟——对于 2D 卡牌游戏可接受

### 风险

- **加载画面场景加载失败**：如果 `loading_screen.tscn` 损坏或缺失，`change_scene_to_file()` 报错，`_transitioning` 保持 `true`——永久死锁。缓解措施：`change_scene_to_file()` 返回错误时 `_transitioning = false` 并强制 `pop_lock(&"scene_manager")`——恢复到当前场景的可用状态
- **`await` 中断导致锁泄漏**：如果 Phase 3 的 `await tree_changed` 在加载画面场景切到目标场景之间被异常中断（Godot 内部错误），`pop_lock` 不会执行。缓解措施：Phase 3 用标志位 `_phase3_in_progress` + `tree_changed` 双重保底。Phase 4 检测到 `tree_changed` 但 `_phase3_in_progress` 仍为 true 时执行清理
- **读档恢复时场景定位**：ADR-0001 的 `GSM.serialize()` 排除 `session` 域——`current_scene` 不在存档的 `game_state` 中。解决方案：存档系统在 `meta` 容器中存储 `current_scene`（字符串路径）和 `current_scene_id`（int 枚举值）——由 ADR-0002 的存档容器格式承接。读档流程：主菜单 → `SaveLoad.load()` → 从 `meta` 提取 `current_scene_id` → `SceneManager.request_scene_change(MAIN_MENU, meta.current_scene_id, GAME_TO_MENU)`。路径无法解析时回退到 `MAIN_MENU`。此字段不属于 `game_state` 的一部分（不和游戏逻辑状态一同序列化），而是存档元信息——与 ADR-0001 的"session 域不持久化"原则一致
- **D3D12 渲染器白闪/黑闪**：Godot 4.6 在 Windows 上默认使用 D3D12 渲染器。`change_scene_to_file()` 释放旧场景并实例化新场景时，D3D12 需要刷新并重新分配渲染目标——可能产生单帧白闪或黑闪，破坏平滑转场体验。缓解措施：loading_screen.tscn 的根节点必须为全屏 `ColorRect`（纯黑色或深色），确保渲染器级闪烁被遮挡。目标场景的第一个 Control 节点应在 `_ready()` 中以全屏不透明 ColorRect 开始，然后在 `_process()` 首帧淡出——双重保护

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| game-state-manager.md | §状态树 `session.current_scene`——当前场景路径 | 确立 SceneManager 为 `GSM.session.current_scene` 和 `GSM.session.scene_id` 的唯一写入者（Phase 4），通过 batch_updated 信号传播 `scene_changed` |
| game-state-manager.md | §信号 `scene_changed`——`{from_scene, to_scene}`——UI 系统、音频系统消费 | Phase 4 在 current_scene 更新后通过 GSM batch_updated 发射——UI 系统和音频系统不再各自猜测场景是否变更 |
| game-state-manager.md | §边缘情况——场景切换期间 input_locks 由场景管理器/UI系统管理 | Phase 2 通过 InputManager.push_lock(TRANSITION) 锁定全部输入；Phase 4 通过 pop_lock 恢复——确保转场期间无意外操作 |
| audio-system.md | §场景切换音频过渡矩阵（16×16 转换表） | `TransitionType` 枚举直接编码转换类型——音频系统监听 `pre_transition` 信号，用 `type` 参数查表，执行对应 BGM 淡入/淡出逻辑 |
| audio-system.md | §边缘情况 #3——过渡期间二次场景切换 | Phase 1 `_transitioning` 检查拒绝并发请求——防止音频系统收到冲突的淡入/淡出指令 |
| audio-system.md | §边缘情况 #11——读档后场景不匹配 | 读档恢复路径通过 `resolve_scene_id_from_path()` 解析——不匹配时回退到 MAIN_MENU，音频系统收到 `post_transition(UNKNOWN, MAIN_MENU)` 信号并播放主菜单默认 BGM |
| architecture.md | §初始化顺序 T+0——Autoload #3 SceneManager | 确立 Autoload 初始化位置——GSM → InputManager → SceneManager → SaveLoad → EventSystem |
| architecture.md | §路径 A/C 场景转换调用点——`request_scene_change(from, to, type)` | 确立唯一入口——战斗系统、探索系统、主菜单、存档系统均通过此 API 触发转换 |

## 性能影响

- **CPU**：`request_scene_change()` 校验阶段 <0.01ms（两次字典查找 + 一个 bool 检查）。转场期间无每帧 CPU 开销（SceneManager 在 await 中挂起）。信号发射仅在转场首尾——非热路径
- **内存**：`SCENE_PATHS` 常数字典 <1KB。SceneManager Autoload 实例 <5KB（3 个 bool/int 状态字段 + 信号连接）。加载画面场景 <2MB（UI Control + 背景图片）
- **加载时间**：加载画面场景加载 → `change_scene_to_file()` → 目标场景加载。新增的加载画面场景切换增加约 50-100ms（小场景，主要开销是 `change_scene_to_file()` 的引擎底层操作）。对于 2D 卡牌游戏可接受——实际体验中加载画面背景会在此期间显示
- **网络**：不适用（纯单机游戏）

## 迁移计划

无现有代码需迁移——这是 Foundation 层初始决策。所有后续系统实现必须通过 `SceneManager.request_scene_change()` 触发场景转换，而非直接调用 `get_tree().change_scene_to_file()`。

## 验证标准

- 通过 GUT：`SceneManager` 测试套件覆盖：
  - `request_scene_change()` 在 `_transitioning == true` 时返回 false
  - `request_scene_change()` 对无效 `SceneID` 返回 false
  - `request_scene_change()` 在正常状态下返回 true
  - Phase 2 触发 `InputManager.push_lock(TRANSITION)` 调用
  - Phase 4 更新 `GSM.session.current_scene` 和 `GSM.session.scene_id`
  - Phase 4 触发 `InputManager.pop_lock()` 调用
  - Phase 5 设置 `_transitioning = false`
- 通过集成：两个系统同时调用 `request_scene_change()` → 第二个返回 false。转场期间系统尝试写入 `GSM.session.current_scene` → GSM 拒绝非 SceneManager 写入（记录警告）
- 通过手动测试：加载画面在所有场景转换中显示——主菜单→身份选择、探索→战斗、战斗→探索

## 相关决策

- ADR-0001（游戏状态管理器——`session.current_scene` 域 + `scene_changed` 信号）
- ADR-0004（输入管理器——`push_lock(TRANSITION)` / `pop_lock()` / `tree_changed` 自动清理）
- ADR-0002（存档/读档——`auto_save()` 在 Phase 2 触发；读档恢复通过 SceneManager 跳转场景）
- ADR-0003（事件系统——事件触发战斗/商店等场景转换时通过 SceneManager 请求）
