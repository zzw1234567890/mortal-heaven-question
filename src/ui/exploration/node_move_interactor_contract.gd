## NodeMoveInteractor 声明面（继承链首段）——[b]4 个 preload / 4 张数据表 / 5 个信号 / 10 个实例字段[/b]。
##
## [b]本层职责[/b]：整条链的[b]共享声明[/b]，[b]不含任何方法[/b]。[br]
##   · 信号——[code]combat_arrival_forwarded[/code] / [code]boss_arrival_forwarded[/code] /
##     [code]node_interaction_forwarded[/code]（到达通知转发，006/007 弹窗消费点）、
##     [code]move_feedback_requested[/code]（失败反馈）、[code]keyboard_focus_changed[/code]
##     （键盘焦点）。[b]信号只能声明在链首[/b]：派生段 [code]emit[/code] 一个祖先段没声明的
##     信号，GDScript 解析期就报错（[method Object.emit_signal] 对未声明名则静默失败）；[br]
##   · preload——[code]InputManagerScript[/code]（[enum InputManager.ActionType] /
##     [enum InputManager.DeviceType] 枚举真理来源，[b]两个默认参数直接取它的值[/b]，
##     故必须落链首）/ [code]Animator[/code] / [code]Navigator[/code] /
##     [code]NodeStateLogicScript[/code]（[code]REACHABLE[/code] 去魔数）；[br]
##   · 数据表——[code]KEY_DIRECTIONS[/code]（方向键→向量，A3 数据表非 if-elif 链）/
##     [code]REASON_TEXTS[/code]（系统 reason → toast 文案，[code]"已访问" → ""[/code]
##     即 AC-4 静默语义）/ 三条文案常量（本地化豁免——S16/S17 各 story 同源口径）；[br]
##   · 实例字段——依赖注入位（[member exploration_system] / [member renderer]）与
##     瞬态交互状态（ADR-0031 §2.1：不进存档，刷新即弃）。
##
## [b]链序[/b]（GDScript 解析期硬约束——祖先段裸标识符引用不到后代段成员）：[br]
## [code]  node_move_interactor_contract.gd [/code] ← 本层：常量 / 信号 / 实例字段[br]
## [code]  node_move_interactor_move.gd     [/code] ← 点击与移动面：委托、缓冲、失败反馈、
## 动画驱动、输入锁栈与命中检测[br]
## [code]  node_move_interactor_route.gd    [/code] ← 接线与转发面：系统信号转发、键盘寻路[br]
## [code]  node_move_interactor.gd          [/code] ← 链尾：生命周期（装配 / 拆除 / 快照注入）[br]
##
## [b]为什么四段而不是三段[/b]：[method _finish_move_animation] 要推进缓冲队列
## （[method _submit_move] 在本段）、[method navigate_focus] 要用可达判定
## （[method _is_reachable_node] 在前一段）——被调方一律靠前，否则解析期就断。
##
## 来源: story-005-node-move-interaction.md、ADR-0031 §2/§3/§4、
## ADR-0014 §决策 3 委托流程、ADR-0004 双焦点、
## control-manifest §Presentation、design/ux/exploration-ui.md Interaction Map。
## 守卫用例：[code]tests/unit/exploration_ui/test_node_move_interactor_public_face_lock.gd[/code]。

extends Control


## InputManager 脚本常量——ActionType/DeviceType 枚举真理来源。
const InputManagerScript := preload("res://src/foundation/input_manager.gd")


## 动画编排（overlay 生命周期 + Tween）。
const Animator := preload("res://src/ui/exploration/node_move_animator.gd")


## 键盘寻路纯函数。
const Navigator := preload("res://src/ui/exploration/node_keyboard_navigator.gd")


## NodeStateLogic 脚本常量——REACHABLE 枚举（去魔数）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")


## 方向键 → 方向向量映射（A3——数据表而非 if-elif 链）。
const KEY_DIRECTIONS: Dictionary = {
	KEY_UP: Vector2i(0, -1),
	KEY_DOWN: Vector2i(0, 1),
	KEY_LEFT: Vector2i(-1, 0),
	KEY_RIGHT: Vector2i(1, 0),
}

## === 固定文案（本地化豁免——S16/S17 各 story 同源口径，待 localization epic）====


const TEXT_AP_INSUFFICIENT: String = "行动力不足"


const TEXT_UNREACHABLE: String = "路径不可达"


const TEXT_MOVE_FAILED: String = "无法移动"


## 系统 reason → toast 文案映射表（数据驱动，非 if-elif 链）。
const REASON_TEXTS: Dictionary = {
	"行动力不足": TEXT_AP_INSUFFICIENT,
	"不可达": TEXT_UNREACHABLE,
	"已访问": "",  # AC-4：已访问静默无反应
	"DAG 缓存未就绪": TEXT_MOVE_FAILED,
	"GSM 不可用": TEXT_MOVE_FAILED,
}

## === 信号（转发层——006/007 弹窗消费点）===================================


signal combat_arrival_forwarded(enemy_roster: Array, combat_type: StringName)


signal boss_arrival_forwarded(boss_data: Dictionary)


signal node_interaction_forwarded(node_id: int, interaction_type: StringName, payload: Dictionary)


## 移动失败反馈（toast 文案 + 抖动目标节点——宿主转发到通知区域）。
signal move_feedback_requested(toast_text: String, node_id: int)


## 键盘焦点变化（宿主转发到渲染器焦点环——A3）。
signal keyboard_focus_changed(node_id: int)

## === 依赖注入（测试可替换）=================================================


## 探索系统引用——move_to_node 调用方 + 信号源（测试注入 mock）。
var exploration_system: Node = null


## 渲染器引用——点击命中检测（NodeGraphRenderer 契约：hit_test_any/states/
## get_node_position）。
var renderer: Control = null

## === 瞬态交互状态（ADR-0031 §2.1——不进存档，刷新即弃）====================


## 当前渲染快照（graph/nodes/visited/current_node/ap_remaining）。
var _snapshot: Dictionary = {}


## 点击缓冲队列（AC-7）。元素为 [code][node_id, device][/code]——
## [b]保留输入设备[/b]（审查 M4）：缓冲来自键盘时锁栈须按 KEYBOARD 判定
## （ADR-0004 双焦点独立），不能一律回落 MOUSE。
var _click_buffer: Array = []


## 移动动画进行中标记（缓冲判定依据）。
var _animating: bool = false


## 键盘焦点节点（-1 = 无——A3 游标）。
var _keyboard_node: int = -1


## 动画进行中暂存的到达通知（B4「先移动后弹窗」）。
var _pending_arrival: Callable = Callable()


## 动画编排器（overlay + Tween 生命周期——preload 常量构造，无 class_name 依赖）。
var _animator: RefCounted = null


## 减少动态偏好（setup 前也可设置——宿主/测试常先设后绑）。
var _reduce_motion: bool = false


## 已连接的系统信号（[signal_name, Callable]——teardown 幂等断开）。
var _bound_signals: Array = []

## === 初始化 ================================================================
