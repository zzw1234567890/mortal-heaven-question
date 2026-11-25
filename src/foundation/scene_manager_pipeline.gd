## SceneManager 转场管线面（继承链第 3 段）——[b]请求入口 + 信号发射包装 + 异步管线[/b]。
##
## [b]本层职责[/b]：5 阶段异步转换管线里「与场景树无关」的那一半。[br]
##   · 入口与守卫——[method request_scene_change]：Phase 1 并发守卫与 ID 存在性校验 →
##     Phase 2 推 TRANSITION 锁 + 自动存档 + 发 [signal pre_transition]；[br]
##   · 信号发射包装——[method _emit_pre_transition] / [method _emit_post_transition]
##     （经 ADR-0007 信号链深度追踪路由，GSM 侧不可用时回退直接 [code]emit[/code]）；[br]
##   · 异步管线四方法——[method _execute_transition] / [method _cleanup_on_error] /
##     [method _inject_loading_context] / [method _execute_post_load]，全部按名委托
##     [code]scene_transition.gd[/code]（两段式 [code]change_scene_to_file[/code]、
##     错误恢复回退主菜单、加载画面上下文注入、Phase 4-5 同步体）。[br]
## [b]为什么是转发而不是让外部直取子模块[/b]：子模块是 Sprint 10 Story 7 从本类切出的
## 实现细节，[method _get_transition] 保持私有；四个同名转发方法同时是[b]测试接缝[/b]
## （[method _execute_post_load] 可绕过 [code]await[/code] 直接驱动 Phase 4-5）。
## [b]不管什么[/b]：不建控件、不做路径自检、不装配。
##
## [b]锁的 push/pop 必须仍在同一条路径上[/b]：Phase 2 在 [method request_scene_change] 里
## [code]push_lock(3, &"scene_manager")[/code]，Phase 4 与错误恢复在
## [method _execute_post_load] / [method _cleanup_on_error] 里 [code]pop_lock[/code]——
## 两段之间隔着 [code]change_scene_to_file[/code] 触发的 [code]tree_changed[/code]，
## 由 [code]input_lock_stack.gd[/code] 的跨场景 source 白名单保住
## （回归：[code]tests/integration/input/test_lock_reentry.gd[/code]）。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  scene_manager_contract.gd [/code] ← 声明面：2 枚举 / 2 信号 / 2 常量表 / 11 实例字段[br]
## [code]  scene_manager_access.gd   [/code] ← 依赖与访问面：注入 / 惰性获取 / 音频门面 / 持久层注册[br]
## [code]  scene_manager_pipeline.gd [/code] ← 转场管线面：请求入口 / 信号发射包装 / 异步管线[br]
## [code]  scene_manager.gd          [/code] ← 本层：装配与出口面（_ready / 查询 / 自检 / 静态工具）[br]
##
## 来源: ADR-0005 §5 阶段异步转换管线、Sprint 10 Story 7（子模块拆分）、
## ADR-0007（信号链深度追踪）。

extends "res://src/foundation/scene_manager_access.gd"

## === 公共 API：转场入口 =============================================================

## 请求场景转换——SceneManager 唯一入口点。
## 返回 [code]false[/code] 的条件：[br]
##   - [member _transitioning] 为 [code]true[/code]（拒绝并发请求）[br]
##   - [param to] 不在 [constant SCENE_PATHS] 中（未注册的场景 ID）[br]
## [br][param from] 与内部 [_current_scene_id] 不匹配时记录警告但不阻止执行。
## [br]返回 [code]true[/code] = 转换已被接受并将异步执行。
func request_scene_change(from: int, to: int, type: TransitionType) -> bool:
	# Phase 1 —— VALIDATE
	if _transitioning:
		push_warning("SceneManager: 拒绝并发转换请求——_transitioning=true")
		return false

	if not SCENE_PATHS.has(to):
		push_error("SceneManager: 未注册的目标场景 ID '%d'" % to)
		return false

	if from != _current_scene_id:
		push_warning("SceneManager: from 不匹配（请求=%d, 内部=%d）——继续执行" % [from, _current_scene_id])

	# Phase 2 —— PRE-TRANSITION
	_transitioning = true
	_transition_type = type

	# 锁输入——TRANSITION 级阻止所有输入（AC-1：null 检查防御性编程）
	var im: Node = _get_im()
	if im != null and im.has_method("push_lock"):
		im.push_lock(3, &"scene_manager")  # LockType.TRANSITION = 3

	# 自动存档——fire-and-forget，不阻塞管线推进（AC-2）
	var sl: Node = _get_save_load()
	if sl != null and sl.has_method("auto_save"):
		sl.auto_save()

	# 发射 pre_transition（Cat 2a——通过 _emit_signal_safe 路由）
	_emit_pre_transition(from, to, type)

	# Phase 3-5 执行
	# 测试模式：跳过异步部分——测试需手动调用 _execute_post_load 验证 Phase 4-5
	if not _test_mode:
		_execute_transition(from, to)
	return true


## === 信号发射包装 ==============================================================

## 发射 [signal pre_transition]——通过 ADR-0007 信号链深度追踪路由。[br]
## 当 GSM._emit_signal_safe 不可用时（单元测试 mock 场景），回退到直接 emit。
func _emit_pre_transition(from: int, to: int, type: TransitionType) -> void:
	var _gsm_script: GDScript = GameStateManager.get_script()
	if _gsm_script.has_method("_emit_signal_safe"):
		_gsm_script._emit_signal_safe(self, &"pre_transition", [from, to, type])
	else:
		pre_transition.emit(from, to, type)


## 发射 [signal post_transition]——通过 ADR-0007 信号链深度追踪路由。
func _emit_post_transition(from: int, to: int) -> void:
	var _gsm_script: GDScript = GameStateManager.get_script()
	if _gsm_script.has_method("_emit_signal_safe"):
		_gsm_script._emit_signal_safe(self, &"post_transition", [from, to])
	else:
		post_transition.emit(from, to)


## === 异步转换管线 ==============================================================

## Phase 3-4-5 异步执行体。[br]
## [br]Phase 3: 加载画面 → 目标场景（两段式 change_scene_to_file）。[br]
## 测试中直接调用 [method _execute_post_load]（同步的 Phase 4-5），无需 mock SceneTree。[br]
## [br]AC-7（Story 004）：[b]优雅降级[/b]——加载画面缺失时跳过加载画面，直接加载目标场景。[br]
## [b]错误恢复[/b]: 目标场景缺失 → 清理状态 + 回退 MAIN_MENU。
func _execute_transition(from: int, to: int) -> void:
	_get_transition()._execute_transition(from, to)


## 错误恢复——统一清理入口。[br]
## 恢复 _transitioning + _transition_type + _phase3_in_progress 到初始状态，
## 并强制释放 TRANSITION 级输入锁，防止死锁和锁泄漏。
func _cleanup_on_error(reason: StringName) -> void:
	_get_transition()._cleanup_on_error(reason)


## 向加载画面场景注入上下文（from, to, type）。[br]
## 提取为独立方法以便测试覆盖。[br]
## 在加载画面场景的 [code]await tree_changed[/code] 之后、
## [code]change_scene_to_file(target)[/code] 之前调用。[br]
## [br][b]AC-2[/b]（Story 004）：上下文传递为同步调用——不依赖 [code]_ready()[/code] 的 await。
func _inject_loading_context(from: int, to: int) -> void:
	_get_transition()._inject_loading_context(from, to)


## Phase 4-5 同步执行体。[br]
## [br][b]生产[/b]: 由 [method _execute_transition] 在 [code]await tree_changed[/code] 成功后调用。[br]
## [b]测试[/b]: 可直接调用——绕过 [code]await[/code] 和 Godot SceneTree 依赖。[br]
## [br]Phase 4: GSM 写入 → 解锁输入 → 发射 [signal post_transition]。[br]
## Phase 5: [_current_scene_id] = [param to], [_transitioning] = false, [_transition_type] = NONE.
func _execute_post_load(from: int, to: int, target_path: String) -> void:
	_get_transition()._execute_post_load(from, to, target_path)
