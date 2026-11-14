extends RefCounted
## InventoryInputLock —— 全覆盖层面板的输入锁持有者（申请 / 释放 / 兜底）。[br]
## [br][b]为什么单独一处[/b]：[code]inventory_screens_host.gd[/code] 已贴 300 行软上限，
## 而「锁怎么申请、什么时候该释放」与「挂哪几页、怎么切页」是两件事。抽走后宿主只留
## 一句 [code]_lock.call(&"acquire")[/code] / [code]release[/code]。[br]
## [br][b]为什么要 [method has_lock] 再 pop[/b]：[code]InputManager[/code] 连接了
## [code]SceneTree.tree_changed[/code] 并在回调里清空整个锁栈，而宿主每次刷新增删行
## 都会触发一次 [code]tree_changed[/code]——锁可能已被外部清掉，此时再 pop 只会得到
## 一条「source not found」的 push_warning 噪声。查询是只读的，代价可忽略。[br]
## [br][b]枚举值从 InputManager 自己的常量取[/b]（[code]manager.LockType.MODAL[/code]），
## 不 preload 它的脚本来抄一份——锁类型的真理来源只有一处。[br]
## [br][b]InputManager 缺失时全部静默跳过[/b]（剥离 Autoload 的测试环境）：锁是收敛
## Esc 语义的加固，不是界面能否工作的前提。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只持「本层有没有拿着锁」这一个瞬态交互标志
## （§2.1 豁免），不碰任何玩法数据。
##
## 来源: ADR-0031 §2、.claude/rules/ui-code.md、
## 先例 [code]settings_panel.gd[/code]（主菜单覆盖层 + 输入锁）。

## 注入的 InputManager（null 时按 Autoload 查找）。
var input_manager: Node = null
## 锁来源标识——同一把锁在同一时刻只该有一个持有者。
var source: StringName = &""
## 本层当前是否持锁（幂等 push 与安全 pop 都看它）。
var _held: bool = false


## 构造——[param p_source] 是 [code]InputManager.pop_lock[/code] 的定位键。
func _init(p_source: StringName = &"", p_input_manager: Node = null) -> void:
	source = p_source
	input_manager = p_input_manager


## 注入 InputManager（生产路径：装配处把 Autoload 交进来）。
func set_input_manager(p_input_manager: Node) -> void:
	input_manager = p_input_manager


## 申请输入锁（幂等——重复 open 不会叠两把）。[br]
## [br][b]返回[/b]：本次是否真的推入了一把（已持有 / 系统缺失时为 false）。
func acquire() -> bool:
	if _held:
		return false
	var manager: Node = _resolve_manager()
	if manager == null or not manager.has_method(&"push_lock"):
		return false
	var lock_type: Variant = manager.get(&"LockType")
	if lock_type == null:
		return false
	manager.call(&"push_lock", lock_type.MODAL, source)
	_held = true
	return true


## 释放输入锁（未持有时为空操作——退场兜底再调一次也安全）。[br]
## [br][b]返回[/b]：本次是否真的弹出了一把（未持有 / 已被外部清掉时为 false）。
func release() -> bool:
	if not _held:
		return false
	_held = false
	var manager: Node = _resolve_manager()
	if manager == null or not manager.has_method(&"pop_lock"):
		return false
	if manager.has_method(&"has_lock") and not bool(manager.call(&"has_lock", source)):
		return false
	manager.call(&"pop_lock", source)
	return true


## 本层当前是否持锁（测试断言用——不只读内部字段）。
func is_held() -> bool:
	return _held


## InputManager——注入优先，否则 Autoload 查找。
func _resolve_manager() -> Node:
	if input_manager != null:
		return input_manager
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath("InputManager"))
