extends RefCounted
## GameStateManager.GSMSignalRouter —— 信号缓冲 + 订阅路由（提取自 game_state_manager.gd）。
##
## 持有对 GSM 父节点的引用，提供帧内变更缓冲、帧末刷新、域信号路由，
## 以及第三层 subscribe/unsubscribe 白名单订阅 API。
##
## [b]提取原因[/b]：game_state_manager.gd 1080 行 → 拆分（Story 3-9 技术债，Sprint 1 回顾行动项 #2）。
##
## 来源: ADR-0001 §第二层帧末缓冲 + §第三层信号订阅 + ADR-0007 §信号分类。

## 指向 GSM 父节点的引用。
var _gsm: Node = null


## 绑定 GSM 父节点引用。
func init(gsm: Node) -> void:
	_gsm = gsm


## 将单一路径变更写入帧内缓冲，并调度帧末刷新。[br]
## [br]同路径多次写入：保留首次 old，更新末次 new。
func _buffer_change(path: String, old_val: Variant, new_val: Variant) -> void:
	if _gsm._emitting_in_progress:
		push_warning("GSM: 递归写入检测——在信号回调中再次写入 %s" % path)
	if _gsm._pending_changes.has(path):
		_gsm._pending_changes[path]["new"] = new_val
	else:
		_gsm._pending_changes[path] = {"old": old_val, "new": new_val}
	_schedule_flush()


## 调度帧末刷新——同一帧多次调用只排一次 call_deferred。
func _schedule_flush() -> void:
	if not _gsm._flush_scheduled:
		_gsm._flush_scheduled = true
		_gsm.call_deferred("_do_flush")


## call_deferred 入口——重置调度标志并执行刷新。
func _do_flush() -> void:
	_gsm._flush_scheduled = false
	_flush_pending_changes()


## 帧末刷新所有缓冲的变更：发射域信号 + batch_updated。
func _flush_pending_changes() -> void:
	if _gsm._pending_changes.is_empty():
		return
	_gsm._emitting_in_progress = true

	var changes: Dictionary = _gsm._pending_changes.duplicate(true)
	_gsm._pending_changes.clear()

	# 单条变更 → 发射对应域信号；多条变更 → 仅 batch_updated
	if changes.size() == 1:
		var path: String = changes.keys()[0]
		var data: Dictionary = changes[path]
		_emit_domain_signal(path, data)

	# batch_updated 始终发射——消费者也可通过路径前缀过滤
	_gsm.batch_updated.emit(changes)
	_gsm._emitting_in_progress = false


## 根据路径自动路由到对应域信号。
func _emit_domain_signal(path: String, data: Dictionary) -> void:
	var old_val: Variant = data["old"]
	var new_val: Variant = data["new"]
	var delta: int = new_val - old_val if (old_val is int and new_val is int) else 0

	if path == "player.realm":
		_gsm.realm_changed.emit(old_val, new_val)
	elif path == "player.cultivation":
		_gsm.cultivation_changed.emit(delta, new_val, _gsm.player.max_cultivation)
	elif path == "player.cultivation_full":
		if new_val == true:
			_gsm.cultivation_full.emit(new_val, _gsm.player.max_cultivation)
	elif path.begins_with("player.resources."):
		var res_type: StringName = StringName(path.get_slice(".", 2))
		_gsm.resource_changed.emit(res_type, delta, new_val)
	elif path == "exploration.action_points":
		# max_val=0：AP 上限由 ExplorationSystem 管理（ADR-0014），GSM 不跟踪
		_gsm.action_points_changed.emit(delta, new_val, 0)


## 订阅指定 GSM 信号。[br]
## [br][param event_name] 必须存在于 [constant GameStateManager.VALID_SIGNALS] 列表中，无效时 [method @GDScript.push_error]。[br]
## [br][param callback] 信号发射时调用的 [Callable]。
func subscribe(event_name: StringName, callback: Callable) -> void:
	match event_name:
		&"gsm_initialized": _gsm.gsm_initialized.connect(callback)
		&"realm_changed": _gsm.realm_changed.connect(callback)
		&"cultivation_changed": _gsm.cultivation_changed.connect(callback)
		&"cultivation_full": _gsm.cultivation_full.connect(callback)
		&"resource_changed": _gsm.resource_changed.connect(callback)
		&"action_points_changed": _gsm.action_points_changed.connect(callback)
		&"deck_modified": _gsm.deck_modified.connect(callback)
		&"battle_started": _gsm.battle_started.connect(callback)
		&"battle_ended": _gsm.battle_ended.connect(callback)
		&"scene_changed": _gsm.scene_changed.connect(callback)
		&"card_collection_changed": _gsm.card_collection_changed.connect(callback)
		&"progression_reset": _gsm.progression_reset.connect(callback)
		&"batch_updated": _gsm.batch_updated.connect(callback)
		&"card_validation_ready": _gsm.card_validation_ready.connect(callback)
		_:
			push_error("GSM.subscribe: 无效信号名 '%s'" % event_name)


## 取消订阅指定 GSM 信号。未找到或未连接时不报错（安全取消）。
func unsubscribe(event_name: StringName, callback: Callable) -> void:
	match event_name:
		&"gsm_initialized":
			if _gsm.gsm_initialized.is_connected(callback): _gsm.gsm_initialized.disconnect(callback)
		&"realm_changed":
			if _gsm.realm_changed.is_connected(callback): _gsm.realm_changed.disconnect(callback)
		&"cultivation_changed":
			if _gsm.cultivation_changed.is_connected(callback): _gsm.cultivation_changed.disconnect(callback)
		&"cultivation_full":
			if _gsm.cultivation_full.is_connected(callback): _gsm.cultivation_full.disconnect(callback)
		&"resource_changed":
			if _gsm.resource_changed.is_connected(callback): _gsm.resource_changed.disconnect(callback)
		&"action_points_changed":
			if _gsm.action_points_changed.is_connected(callback): _gsm.action_points_changed.disconnect(callback)
		&"deck_modified":
			if _gsm.deck_modified.is_connected(callback): _gsm.deck_modified.disconnect(callback)
		&"battle_started":
			if _gsm.battle_started.is_connected(callback): _gsm.battle_started.disconnect(callback)
		&"battle_ended":
			if _gsm.battle_ended.is_connected(callback): _gsm.battle_ended.disconnect(callback)
		&"scene_changed":
			if _gsm.scene_changed.is_connected(callback): _gsm.scene_changed.disconnect(callback)
		&"card_collection_changed":
			if _gsm.card_collection_changed.is_connected(callback): _gsm.card_collection_changed.disconnect(callback)
		&"progression_reset":
			if _gsm.progression_reset.is_connected(callback): _gsm.progression_reset.disconnect(callback)
		&"batch_updated":
			if _gsm.batch_updated.is_connected(callback): _gsm.batch_updated.disconnect(callback)
		&"card_validation_ready":
			if _gsm.card_validation_ready.is_connected(callback): _gsm.card_validation_ready.disconnect(callback)
		_:  # 未知信号名——静默忽略
			pass
