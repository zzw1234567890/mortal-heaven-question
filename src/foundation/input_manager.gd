extends Node
## InputManager (Autoload #2) —— 四级输入锁栈的单一仲裁者。
##
## 所有需要限制玩家输入的系统在操作开始/结束时调用 [method push_lock] / [method pop_lock]，
## 消费者在投递输入前通过 [method is_input_allowed] 或 [method has_lock]
## （MODAL 弹窗拥有者）查询当前锁状态。[br]
## [br]
## [b]锁严格度（升序）[/b]: DIALOGUE(0) < ANIMATION(1) < MODAL(2) < TRANSITION(3)[br]
## [b]push/pop 配对[/b]: 以 [StringName] source 标识调用方，重复 push 同 source 记录警告。[br]
## [b]GSM 同步[/b]: push/pop/clear 通过 [method _sync_to_gsm] 写入 GSM.session.input_locks，
##               由 GSM [signal batch_updated] 传播锁状态变更。[br]
## [b]场景切换[/b]: 连接 [signal SceneTree.tree_changed] 自动清除锁栈。[br]
## [br]
## [b]调用示例[/b]:[br]
## [codeblock]
##   InputManager.push_lock(InputManager.LockType.DIALOGUE, &"dialogue_system")
##   InputManager.pop_lock(&"dialogue_system")
## [/codeblock]

## === 枚举 ====================================================================

## 锁类型——严格度从低到高排列。
## 当前锁栈中的最高级锁决定允许的输入范围。
enum LockType {
	DIALOGUE = 0,   ## 对话进行中——阻止 GAMEPLAY，允许 DIALOGUE + UI_NAV
	ANIMATION = 1,  ## 动画播放中——阻止 GAMEPLAY + DIALOGUE，允许 UI_NAV
	MODAL = 2,      ## 模态弹窗——阻止所有非弹窗拥有者的输入
	TRANSITION = 3, ## 场景转场——阻止一切输入
}

## 动作类型——被 [method is_input_allowed] 过滤。
## ANY 始终允许（系统级快捷键不可被锁阻止）。
enum ActionType {
	ANY = 0,        ## 系统级动作（退出、截图——始终允许）
	UI_NAV = 1,     ## UI 导航（菜单浏览、卡牌详情、tooltip）
	DIALOGUE = 2,   ## 对话交互（选项选择、对话推进）
	GAMEPLAY = 3,   ## 玩法输入（地图移动、卡牌拖拽、事件触发、战斗操作）
}

## 设备类型——Godot 4.6 双焦点独立判定。
## 可组合位掩码：[code]DeviceType.MOUSE | DeviceType.KEYBOARD[/code]。
enum DeviceType {
	MOUSE = 1,      ## 鼠标/触摸
	KEYBOARD = 2,   ## 键盘
	GAMEPAD = 4,    ## 手柄 (SDL3, 4.5+)
}

## === 常量 ====================================================================

## [method get_current_lock] 在空栈时的返回值——表示没有任何输入锁。
const NO_LOCK := -1

## 向后兼容别名 —— 指向 [enum DeviceType] 枚举成员。
## 供已有调用方（push_lock 默认参数、测试）使用。
const DEVICE_MOUSE    := DeviceType.MOUSE     ## = 1 — 鼠标/触摸
const DEVICE_KEYBOARD := DeviceType.KEYBOARD  ## = 2 — 键盘
const DEVICE_GAMEPAD  := DeviceType.GAMEPAD   ## = 4 — 手柄
const DEVICE_ALL      := DeviceType.MOUSE | DeviceType.KEYBOARD | DeviceType.GAMEPAD  ## = 7 — 全部设备（默认值）

## === 内部类 ==================================================================

## 锁栈条目——记录一次 [method push_lock] 调用的完整信息。
class LockEntry:
	var type: LockType        ## 锁类型（DIALOGUE / ANIMATION / MODAL / TRANSITION）
	var source: StringName    ## 调用方标识，用于配对 push/pop
	var device_mask: int      ## 此锁允许的设备位掩码（白名单语义）

## === 状态 ====================================================================

## 四级锁栈——按 push 顺序存储，LIFO 释放。
## 深度极少超过 2，O(n) 遍历 n≤4 在性能预算内。
var _lock_stack: Array[LockEntry] = []

## is_action_blocked 的内置分类映射表。
## 键 = 动作名，值 = [ActionType, DeviceType]。
## 调用方亦可直接调用 is_input_allowed() 替代此映射表。
const _ACTION_CLASSIFICATION: Dictionary = {
	&"end_turn": [ActionType.GAMEPLAY, DeviceType.KEYBOARD],
	&"pause":    [ActionType.UI_NAV, DeviceType.KEYBOARD],
	&"escape":   [ActionType.UI_NAV, DeviceType.KEYBOARD],
}


# ═══════════════════════════════════════════════════════════════════════════════
# 生命周期
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_lock_stack = []
	if is_inside_tree():
		get_tree().tree_changed.connect(_on_tree_changed)


## 节点退出时断开 tree_changed 连接、清除锁栈并执行最终 GSM 同步。
## [br]
## [b]AC-025[/b]: 断开 tree_changed 连接——防止悬挂引用。[br]
## [b]AC-026[/b]: 清理锁栈 + 最终 _sync_to_gsm()——确保 GSM 中无残留状态。
func _exit_tree() -> void:
	if is_inside_tree() and get_tree().tree_changed.is_connected(_on_tree_changed):
		get_tree().tree_changed.disconnect(_on_tree_changed)
	_lock_stack.clear()
	_sync_to_gsm()


# ═══════════════════════════════════════════════════════════════════════════════
# 锁管理 API
# ═══════════════════════════════════════════════════════════════════════════════

## 推入一个输入锁。调用方应在操作结束时调用 [method pop_lock] 配对移除。
##
## [param type] 锁类型——严格度由 [enum LockType] 定义。
## [param source] 调用方标识——必须与 [method pop_lock] 的参数一致。
## [param device_mask] 此锁允许的设备位掩码（白名单语义）。默认为 [constant DEVICE_ALL]（=7）。
##                     位掩码判定由 [method _check_device_allowed] 执行。
##
## [b]边缘情况[/b]: 如果栈中已存在相同 [param source] 的锁条目，记录 [code]push_warning[/code]
##                  并跳过（不增加栈元素）。这是代码 bug 的早期检测——调用方可能丢失了
##                  [method pop_lock] 调用。
func push_lock(type: LockType, source: StringName, device_mask: int = DEVICE_ALL) -> void:
	# 重复 push 检测——同一 source 重复 push 意味着代码 bug（丢失 pop_lock）
	for entry in _lock_stack:
		if entry.source == source:
			push_warning("InputManager: duplicate push_lock(%s) from '%s' —— "
					% [LockType.find_key(type), source]
					+ "可能丢失了 pop_lock() 调用。跳过本次 push。")
			return

	var entry := LockEntry.new()
	entry.type = type
	entry.source = source
	entry.device_mask = device_mask
	_lock_stack.append(entry)

	print("InputManager: push %s lock (source: '%s', stack depth: %d)"
			% [LockType.find_key(type), source, _lock_stack.size()])

	_sync_to_gsm()


## 弹出一个输入锁。从栈尾向前查找匹配 [param source] 的条目并移除（LIFO 顺序）。
##
## [param source] 调用方标识——必须与 [method push_lock] 的参数一致。
##
## [b]边缘情况[/b]: 如果栈中不存在匹配 [param source] 的条目，记录 [code]push_warning[/code]
##                  但栈不变。调用方可能已通过 [method clear_locks] 移除，或传入了错误的 source。
func pop_lock(source: StringName) -> void:
	for i in range(_lock_stack.size() - 1, -1, -1):
		if _lock_stack[i].source == source:
			var removed_type: LockType = _lock_stack[i].type
			_lock_stack.remove_at(i)
			print("InputManager: pop %s lock (source: '%s', stack depth: %d)"
					% [LockType.find_key(removed_type), source, _lock_stack.size()])
			_sync_to_gsm()
			return

	push_warning("InputManager: pop_lock('%s') called but source not found in stack —— "
			% source + "可能已通过 clear_locks() 移除，或传入了错误的 source。")


## 清除锁栈中的条目。
##
## [param source] 如果为空字符串（默认），则清除全部锁。
##               如果非空，则仅移除 source 匹配的条目。
##
## [b]使用场景[/b]: 场景变更时 SceneManager 调用 [code]clear_locks()[/code]（无参）重置所有锁。
##             在 Story 003 中，此方法还将连接 SceneTree.tree_changed 信号自动清除。
func clear_locks(source: StringName = "") -> void:
	if source == "":
		var count := _lock_stack.size()
		_lock_stack.clear()
		if count > 0:
			print("InputManager: clear_locks() — 清除了全部 %d 个锁" % count)
	else:
		var old_size := _lock_stack.size()
		_lock_stack = _lock_stack.filter(func(e: LockEntry) -> bool: return e.source != source)
		var removed := old_size - _lock_stack.size()
		if removed > 0:
			print("InputManager: clear_locks('%s') — 清除了 %d 个锁，剩余 %d 个"
					% [source, removed, _lock_stack.size()])

	_sync_to_gsm()


# ═══════════════════════════════════════════════════════════════════════════════
# 输入判定 API — Story 002
# ═══════════════════════════════════════════════════════════════════════════════

## 判定指定动作类型和设备组合在当前锁栈下是否允许。[br]
## [br]
## 每帧被 UI 系统调用多次——必须 O(n)（n ≤ 4）且轻量。[br]
## [br]
## [b]判定顺序[/b]:[br]
## 1. ANY 动作始终允许（系统级快捷键不可被锁阻止）[br]
## 2. 空栈 = 无锁 = 所有输入放行[br]
## 3. 设备白名单检查——任一锁的 device_mask 不包含该设备则拒绝[br]
## 4. 当前最高级锁的严格度判定 [br]
## [br]
## [b]4.6 双焦点[/b]: [param device] 独立判定——鼠标和键盘分别检查。
## 鼠标 hover 不被键盘锁阻止，反之亦然。
func is_input_allowed(action_type: ActionType, device: DeviceType) -> bool:
	# ANY 类型始终允许——系统级快捷键不可被锁阻止
	if action_type == ActionType.ANY:
		return true

	# 空栈 = 无锁 = 所有输入允许
	if _lock_stack.is_empty():
		return true

	# 设备白名单检查 —— 4.6 双焦点独立判定
	if not _check_device_allowed(device):
		return false

	# 当前最高级锁 = max(栈中所有锁的 LockType)
	var current_lock: LockType = _get_highest_lock()

	# 严格度判定
	match current_lock:
		LockType.DIALOGUE:
			# 对话锁——仅阻止 GAMEPLAY，允许 DIALOGUE + UI_NAV
			return action_type != ActionType.GAMEPLAY
		LockType.ANIMATION:
			# 动画锁——阻止 GAMEPLAY + DIALOGUE，允许 UI_NAV
			return action_type == ActionType.UI_NAV
		LockType.MODAL:
			# 模态锁——默认阻止所有非 ANY 输入
			# 弹窗拥有者通过 has_lock(source) 自行判定是否允许输入（Story 004）
			return false
		LockType.TRANSITION:
			# 转场锁——阻止所有输入
			return false

	return false  # 不应到达


## 判定命名动作是否被当前锁栈阻止。[br]
## [br]
## 委托给 [method is_input_allowed]——通过内置分类映射表推导 ActionType 和 DeviceType。[br]
## 调用方亦可直接调用 [method is_input_allowed] 替代此方法。[br]
## [br]
## [b]内置映射[/b]: end_turn→(GAMEPLAY,KEYBOARD); pause/escape→(UI_NAV,KEYBOARD)[br]
## [b]未知动作[/b]: 默认分类为 (GAMEPLAY, KEYBOARD)——保守拒绝。
func is_action_blocked(action_name: StringName) -> bool:
	return not is_input_allowed(_classify_action(action_name), _classify_device(action_name))


# ═══════════════════════════════════════════════════════════════════════════════
# 查询 API
# ═══════════════════════════════════════════════════════════════════════════════

## 返回当前锁栈中最高严格度的 LockType 值。[br]
## [br]
## [b]空栈[/b]: 返回 [constant NO_LOCK]（= -1），表示没有任何输入锁——所有输入均应放行。[br]
## [b]性能[/b]: O(n)，n ≤ 4——遍历栈一次取最大值。[br]
## [br]
## [b]注意[/b]: 返回类型为 [int] 而非 [enum LockType]，因为空栈时返回 -1 不在枚举值范围内。
##           调用方应先通过 [method has_lock] 或栈大小判断是否有活跃锁后再将此值与枚举值比较。
func get_current_lock() -> int:
	if _lock_stack.is_empty():
		return NO_LOCK

	var highest: int = 0
	for entry in _lock_stack:
		if entry.type > highest:
			highest = entry.type
	return highest


## 返回锁栈的完整快照，供调试和诊断使用。
##
## [b]返回值[/b]: [code]Array[Dictionary][/code]——每个字典包含
##             [code]{"type": LockType, "source": StringName, "device_mask": int}[/code]。
##             返回的是快照副本——调用方修改不会影响内部栈。
func get_lock_stack() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for entry in _lock_stack:
		snapshot.append({
			"type": entry.type,
			"source": entry.source,
			"device_mask": entry.device_mask,
		})
	return snapshot


## 检查栈中是否存在指定 [param source] 的锁条目。
##
## [b]使用场景[/b]: MODAL 弹窗在处理内部输入前调用 [code]has_lock(&"my_source")[/code]
##             以确认自己仍是活跃的模态拥有者（Story 002/004 中完整使用）。
func has_lock(source: StringName) -> bool:
	for entry in _lock_stack:
		if entry.source == source:
			return true
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# 内部方法
# ═══════════════════════════════════════════════════════════════════════════════

## Godot 4.6 双焦点——检查设备是否被锁栈中的所有锁允许（白名单语义）。[br]
## [br]
## 遍历所有活跃锁条目——任一锁的 [member LockEntry.device_mask] 不包含 [param device] 位
## 则返回 [code]false[/code]（白名单语义：device_mask 定义允许的设备，而非阻止的设备）。
func _check_device_allowed(device: DeviceType) -> bool:
	for entry in _lock_stack:
		if not (entry.device_mask & device):
			return false
	return true


## 返回锁栈中最高严格度的 LockType。[br]
## [br]
## [b]调用前提[/b]: 仅当 _lock_stack 非空时调用。[br]
## [b]与 [method get_current_lock] 的区别[/b]: 返回类型为 [enum LockType] 而非 [int]——
## 用于 [method is_input_allowed] 的 match 分支（需枚举类型以启用 exhaustiveness 检查）。
func _get_highest_lock() -> LockType:
	assert(not _lock_stack.is_empty(), "_get_highest_lock() called on empty stack")
	var highest: int = -1
	for entry in _lock_stack:
		if entry.type > highest:
			highest = entry.type
	return highest as LockType


## 根据动作名推导 ActionType。[br]
## [br]
## 内置分类映射表见 [constant _ACTION_CLASSIFICATION]。[br]
## 未知动作默认分类为 [enum ActionType.GAMEPLAY]——保守拒绝策略。
func _classify_action(action_name: StringName) -> ActionType:
	if _ACTION_CLASSIFICATION.has(action_name):
		return _ACTION_CLASSIFICATION[action_name][0] as ActionType
	return ActionType.GAMEPLAY  # 未知动作：保守拒绝


## 根据动作名推导 DeviceType。[br]
## [br]
## 内置分类映射表见 [constant _ACTION_CLASSIFICATION]。[br]
## 未知动作默认分类为 [enum DeviceType.KEYBOARD]——保守拒绝策略。
func _classify_device(action_name: StringName) -> DeviceType:
	if _ACTION_CLASSIFICATION.has(action_name):
		return _ACTION_CLASSIFICATION[action_name][1] as DeviceType
	return DeviceType.KEYBOARD  # 未知动作：保守拒绝


## 将锁栈序列化写入 GSM.session.input_locks 并通过 batch_updated 信号传播。[br]
## [br]
## 序列化格式：[code]Array[Dictionary][/code]，每元素 [code]{type: int, source: StringName, device_mask: int}[/code]。[br]
## 遍历现有 _lock_stack 构造副本（而非直接传递引用以避免外部修改）。[br]
## [br]
## [b]GSM 依赖[/b]: 调用 [code]GameStateManager.set_input_locks()[/code]——GSM Story 005 已提供此 Tier 2 原子方法。
func _sync_to_gsm() -> void:
	var serialized: Array[Dictionary] = []
	for entry in _lock_stack:
		serialized.append({
			"type": entry.type,
			"source": entry.source,
			"device_mask": entry.device_mask,
		})
	GameStateManager.set_input_locks(serialized)

## 场景树变更回调——场景切换时自动清除输入锁。[br]
## [br]
## 由 [method Node._ready] 连接至 [signal SceneTree.tree_changed]。[br]
## [b]优化[/b]: 仅当栈非空时清除——避免不必要的 GSM 写入。
func _on_tree_changed() -> void:
	if not _lock_stack.is_empty():
		_lock_stack.clear()
		_sync_to_gsm()

# ═══════════════════════════════════════════════════════════════════════════════
# 输入分发（路径 A + B）—— Story 003
# ═══════════════════════════════════════════════════════════════════════════════

## 路径 A：GAMEPLAY 键盘——Input Map 轮询。[br]
## [br]
## 每帧在 [method Node._process] 中检查已注册的玩法动作：[code]end_turn[/code]、[code]pause[/code]。[br]
## 仅当 [method is_input_allowed] 放行时才执行对应逻辑。
func _process(_delta: float) -> void:
	# 路径 A：GAMEPLAY 键盘——Input Map 轮询
	if Input.is_action_just_pressed(&"end_turn"):
		if is_input_allowed(ActionType.GAMEPLAY, DeviceType.KEYBOARD):
			print("InputManager: end_turn 动作通过锁判定")
	if Input.is_action_just_pressed(&"pause"):
		if is_input_allowed(ActionType.UI_NAV, DeviceType.KEYBOARD):
			print("InputManager: pause 动作通过锁判定")

## 路径 B：UI_NAV 快捷键——在 GUI 派发前拦截。[br]
## [br]
## [param event] 输入事件。仅处理 ESC 按键按下事件。[br]
## 通过 [method is_input_allowed] 判定后调用 [method Node.accept_event] 阻止进一步传播。
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if is_input_allowed(ActionType.UI_NAV, DeviceType.KEYBOARD):
			print("InputManager: ESC 通过锁判定——已拦截")
			get_viewport().set_input_as_handled()
