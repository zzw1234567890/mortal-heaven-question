extends RefCounted
## InputLockStack —— 输入锁栈管理 + GSM 同步子模块（从 input_manager.gd 拆分）。
##
## 持有对 InputManager 父节点的引用，通过它访问 _lock_stack / LockType /
## LockEntry 等状态和类型。
##
## [br]来源: ADR-0005 §输入锁栈。
## [br]Sprint 11 Story 1：从 input_manager.gd 拆分。

## 父节点引用——InputManager Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 推入一个输入锁。调用方应在操作结束时调用 [method pop_lock] 配对移除。[br]
## [br][param type] 锁类型——严格度由 [enum LockType] 定义。[br]
## [br][param source] 调用方标识——必须与 [method pop_lock] 的参数一致。[br]
## [br][param device_mask] 此锁允许的设备位掩码（白名单语义）。默认为全部设备。[br]
## [br][b]边缘情况[/b]: 如果栈中已存在相同 [param source] 的锁条目，记录 [code]push_warning[/code]
##                  并跳过（不增加栈元素）。这是代码 bug 的早期检测——调用方可能丢失了
##                  [method pop_lock] 调用。
func push_lock(type: int, source: StringName, device_mask: int = 7) -> void:
	var lock_stack: Array = _parent.get("_lock_stack")
	# 重复 push 检测——同一 source 重复 push 意味着代码 bug（丢失 pop_lock）
	for entry in lock_stack:
		if entry.source == source:
			push_warning("InputManager: duplicate push_lock(%s) from '%s' —— "
					% [_parent.get("LockType").find_key(type), source]
					+ "可能丢失了 pop_lock() 调用。跳过本次 push。")
			return

	var LockEntryClass: GDScript = _parent.get("LockEntry")
	var entry = LockEntryClass.new()
	entry.type = type
	entry.source = source
	entry.device_mask = device_mask
	lock_stack.append(entry)

	print("InputManager: push %s lock (source: '%s', stack depth: %d)"
			% [_parent.get("LockType").find_key(type), source, lock_stack.size()])

	_sync_to_gsm()


## 弹出一个输入锁。从栈尾向前查找匹配 [param source] 的条目并移除（LIFO 顺序）。[br]
## [br][param source] 调用方标识——必须与 [method push_lock] 的参数一致。[br]
## [br][b]边缘情况[/b]: 如果栈中不存在匹配 [param source] 的条目，记录 [code]push_warning[/code]
##                  但栈不变。调用方可能已通过 [method clear_locks] 移除，或传入了错误的 source。
func pop_lock(source: StringName) -> void:
	var lock_stack: Array = _parent.get("_lock_stack")
	for i in range(lock_stack.size() - 1, -1, -1):
		if lock_stack[i].source == source:
			var removed_type: int = lock_stack[i].type
			lock_stack.remove_at(i)
			print("InputManager: pop %s lock (source: '%s', stack depth: %d)"
					% [_parent.get("LockType").find_key(removed_type), source, lock_stack.size()])
			_sync_to_gsm()
			return

	push_warning("InputManager: pop_lock('%s') called but source not found in stack —— "
			% source + "可能已通过 clear_locks() 移除，或传入了错误的 source。")


## 清除锁栈中的条目。[br]
## [br][param source] 如果为空字符串（默认），则清除全部锁。[br]
##               如果非空，则仅移除 source 匹配的条目。[br]
## [br][b]使用场景[/b]: 场景变更时 SceneManager 调用 [code]clear_locks()[/code]（无参）重置所有锁。
func clear_locks(source: StringName = "") -> void:
	var lock_stack: Array = _parent.get("_lock_stack")
	if source == "":
		var count := lock_stack.size()
		lock_stack.clear()
		if count > 0:
			print("InputManager: clear_locks() — 清除了全部 %d 个锁" % count)
	else:
		var old_size := lock_stack.size()
		_parent.set("_lock_stack", lock_stack.filter(func(e): return e.source != source))
		var removed: int = old_size - _parent.get("_lock_stack").size()
		if removed > 0:
			print("InputManager: clear_locks('%s') — 清除了 %d 个锁，剩余 %d 个"
					% [source, removed, _parent.get("_lock_stack").size()])

	_sync_to_gsm()


## 返回锁栈的完整快照，供调试和诊断使用。[br]
## [br][b]返回值[/b]: [code]Array[Dictionary][/code]——每个字典包含
##             [code]{"type": LockType, "source": StringName, "device_mask": int}[/code]。
##             返回的是快照副本——调用方修改不会影响内部栈。
func get_lock_stack() -> Array[Dictionary]:
	var lock_stack: Array = _parent.get("_lock_stack")
	var snapshot: Array[Dictionary] = []
	for entry in lock_stack:
		snapshot.append({
			"type": entry.type,
			"source": entry.source,
			"device_mask": entry.device_mask,
		})
	return snapshot


## 检查栈中是否存在指定 [param source] 的锁条目。[br]
## [br][b]使用场景[/b]: MODAL 弹窗在处理内部输入前调用 [code]has_lock(&"my_source")[/code]
##             以确认自己仍是活跃的模态拥有者。
func has_lock(source: StringName) -> bool:
	var lock_stack: Array = _parent.get("_lock_stack")
	for entry in lock_stack:
		if entry.source == source:
			return true
	return false


## 场景树变更回调——场景切换时自动清除输入锁。[br]
## [br][b]优化[/b]: 仅当栈非空时清除——避免不必要的 GSM 写入。
func on_tree_changed() -> void:
	var lock_stack: Array = _parent.get("_lock_stack")
	if not lock_stack.is_empty():
		lock_stack.clear()
		_sync_to_gsm()


## 将锁栈序列化写入 GSM.session.input_locks 并通过 batch_updated 信号传播。[br]
## [br]序列化格式：[code]Array[Dictionary][/code]，每元素 [code]{type: int, source: StringName, device_mask: int}[/code]。
## [br][b]GSM 依赖[/b]: 调用 [code]GameStateManager.set_input_locks()[/code]。
func _sync_to_gsm() -> void:
	_parent.call("_sync_to_gsm")
