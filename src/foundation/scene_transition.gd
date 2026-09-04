extends RefCounted
## SceneTransition —— 场景转换异步管线子模块（从 scene_manager.gd 拆分）。
##
## 持有对 SceneManager 父节点的引用，通过它访问 SCENE_PATHS / SceneID /
## TransitionType / _transitioning / _transition_type / _phase3_in_progress /
## _test_mode / _get_gsm / _get_im / _get_save_load 等状态和方法。
##
## [br]来源: ADR-0005 §5 阶段异步转换管线。
## [br]Sprint 10 Story 7：从 scene_manager.gd 拆分。

## 父节点引用——SceneManager Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## Phase 3-4-5 异步执行体。[br]
## [br]Phase 3: 加载画面 → 目标场景（两段式 change_scene_to_file）。[br]
## 测试中直接调用 [method _execute_post_load]（同步的 Phase 4-5），无需 mock SceneTree。[br]
## [br]AC-7（Story 004）：[b]优雅降级[/b]——加载画面缺失时跳过加载画面，直接加载目标场景。[br]
## [b]错误恢复[/b]: 目标场景缺失 → 清理状态 + 回退 MAIN_MENU。
func _execute_transition(from: int, to: int) -> void:
	# 测试模式：跳过异步场景加载——直接执行 Phase 4-5
	if _parent.get("_test_mode"):
		_execute_post_load(from, to, _parent.get("SCENE_PATHS")[to])
		return

	var scene_paths: Dictionary = _parent.get("SCENE_PATHS")
	var scene_id_loading: int = _parent.get("SceneID").LOADING

	# Phase 3 —— LOAD（两段式：加载画面 → 目标场景）
	var loading_path: String = scene_paths[scene_id_loading]
	var target_path: String = scene_paths[to]

	# Step 1: 切换到加载画面
	var err1: int = _parent.get_tree().change_scene_to_file(loading_path)
	if err1 != OK:
		# AC-7: 优雅降级——加载画面缺失，直接加载目标场景。
		push_error("SceneManager: 无法加载 loading_screen.tscn（err=%d）——跳过加载画面，直接加载目标场景" % err1)
		_parent.set("_phase3_in_progress", true)
	else:
		# 加载画面加载成功——设置标志位（AC-3 步骤 2）
		_parent.set("_phase3_in_progress", true)

		await _parent.get_tree().tree_changed
		# tree_changed 后再检查：若 Phase 3 被外部中断则清理
		if not _parent.get("_phase3_in_progress"):
			return

		# 向加载画面注入上下文（同步调用，AC-2）
		_inject_loading_context(from, to)

	# Step 2: 切换到目标场景（正常路径和降级路径共用）
	var err2: int = _parent.get_tree().change_scene_to_file(target_path)
	if err2 != OK:
		# AC-5: 目标场景不存在——记录错误，尝试回退 MAIN_MENU
		push_error("SceneManager: 目标场景不存在：%s（err=%d）" % [target_path, err2])
		_cleanup_on_error(&"target_scene_missing")
		# 尝试回退到主菜单
		var fallback_ok: bool = _parent.call("request_scene_change", _parent.get("_current_scene_id"), _parent.get("SceneID").MAIN_MENU, _parent.get("TransitionType").GAME_TO_MENU)
		if not fallback_ok:
			push_error("SceneManager: 回退主菜单也失败——手动恢复")
		return

	await _parent.get_tree().tree_changed

	# Phase 4 —— POST-LOAD（双重保底：检查 _phase3_in_progress）
	if not _parent.get("_phase3_in_progress"):
		# AC-6: await 异常中断——tree_changed 到达但标志位已被外部清除
		push_error("SceneManager: Phase 3 异常中断——强制清理")
		_cleanup_on_error(&"phase3_aborted")
		return

	# 防御性校验：确认当前场景路径匹配
	var current: Node = _parent.get_tree().current_scene
	if current == null or current.scene_file_path != target_path:
		push_error("SceneManager: tree_changed 后场景路径不匹配（期望=%s, 实际=%s）" % [
				target_path,
				current.scene_file_path if current != null else "null"])
		_cleanup_on_error(&"path_mismatch")
		return

	_execute_post_load(from, to, target_path)


## 错误恢复——统一清理入口。[br]
## 恢复 _transitioning + _transition_type + _phase3_in_progress 到初始状态，[br]
## 并强制释放 TRANSITION 级输入锁，防止死锁和锁泄漏。
func _cleanup_on_error(reason: StringName) -> void:
	_parent.set("_transitioning", false)
	_parent.set("_transition_type", _parent.get("TransitionType").NONE)
	_parent.set("_phase3_in_progress", false)

	var im: Node = _parent.call("_get_im")
	if im != null and im.has_method("pop_lock"):
		im.pop_lock(&"scene_manager")


## 向加载画面场景注入上下文（from, to, type）。[br]
## 提取为独立方法以便测试覆盖。[br]
## 在加载画面场景的 [code]await tree_changed[/code] 之后、[br]
## [code]change_scene_to_file(target)[/code] 之前调用。[br]
## [br][b]AC-2[/b]（Story 004）：上下文传递为同步调用——不依赖 [code]_ready()[/code] 的 await。
func _inject_loading_context(from: int, to: int) -> void:
	var loading_scene: Node = _parent.get_tree().current_scene
	if loading_scene != null and loading_scene.has_method("set_context"):
		loading_scene.set_context(from, to, _parent.get("_transition_type"))


## Phase 4-5 同步执行体。[br]
## [br][b]生产[/b]: 由 [method _execute_transition] 在 [code]await tree_changed[/code] 成功后调用。[br]
## [b]测试[/b]: 可直接调用——绕过 [code]await[/code] 和 Godot SceneTree 依赖。[br]
## [br]Phase 4: GSM 写入 → 解锁输入 → 发射 [signal post_transition]。[br]
## Phase 5: [_current_scene_id] = [param to], [_transitioning] = false, [_transition_type] = NONE.
func _execute_post_load(from: int, to: int, target_path: String) -> void:
	# Phase 4 —— GSM 写入
	var gsm: Node = _parent.call("_get_gsm")
	if gsm != null and gsm.has_method("set_session_scene"):
		# 通过 GSM 第二层原子方法——触发 batch_updated（生产路径）
		gsm.set_session_scene(to, target_path)
	elif gsm != null and "session" in gsm:
		# 测试 mock 回退——mock 对象无 GSM 缓冲层，直接赋值
		gsm.session.current_scene = target_path
		gsm.session.scene_id = to

	# 解锁输入（AC-3：顺序——GSM 写入 → post_transition → pop_lock）
	var im_ok: Node = _parent.call("_get_im")
	if im_ok != null and im_ok.has_method("pop_lock"):
		im_ok.pop_lock(&"scene_manager")

	# 发射 post_transition（必须在新场景 ready 后、第一个 _process 前）
	_parent.call("_emit_post_transition", from, to)

	# Phase 5 —— FINALIZE
	_parent.set("_current_scene_id", to)
	_parent.set("_transitioning", false)
	_parent.set("_transition_type", _parent.get("TransitionType").NONE)
	_parent.set("_phase3_in_progress", false)
