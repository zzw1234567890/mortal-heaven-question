extends GutTest
## 转场期间输入锁存续性回归 —— pop_lock('scene_manager') source not found ×8。
##
## [b]缺陷[/b]：Phase 2 里 SceneManager 推入 TRANSITION 锁（scene_manager.gd），
## Phase 3 的 [code]change_scene_to_file[/code] 会触发 [signal SceneTree.tree_changed]，
## 而 [method InputManager._on_tree_changed] 无条件整栈清空——把刚推的转场锁一起抹掉。
## 后果两条：[br]
##   ① [b]真缺陷[/b]：转场窗口内锁栈其实是空的，UI_NAV 输入（ESC）照样通过判定，
##      玩家在场景加载时按 ESC 能打开暂停菜单——TRANSITION 锁「阻止一切输入」
##      的契约在最需要它的那段窗口里失效；[br]
##   ② Phase 4 的 [method InputManager.pop_lock] 找不到条目 → push_warning
##      「source not found in stack」（真机走查捕获 8 条）。
##
## [b]分类[/b]：A 真缺陷（锁栈被转场中途写坏，push 存续不到配对的 pop）。
## 修法：跨场景存续的锁 source（SceneManager 的转场锁）不参与 tree_changed 清栈，
## 由持有方在 Phase 4 自行 pop——push/pop 恢复严格配对。
##
## 先例：tests/integration/audio/test_bus_layout.gd 的真实转场驱动
## （新建 SceneManager 实例 + 注入 mock 依赖 + 真实 .tscn 目标）。

const IM_SCRIPT := preload("res://src/foundation/input_manager.gd")
const LOCK_STACK := preload("res://src/foundation/input_lock_stack.gd")
const SM_SCRIPT := preload("res://src/foundation/scene_manager.gd")
const MockFactory := preload("res://tests/integration/scene_manager/mocks/mock_factory.gd")

## SceneManager 推转场锁时使用的 source 字面量（scene_manager.gd 的
## [code]push_lock(3, &"scene_manager")[/code]）——测试侧的第二份拷贝，
## 由本文件的真实转场用例守住三处一致（scene_manager.gd / 模块常量 / 此处）。
const SM_LOCK_SOURCE: StringName = &"scene_manager"

var im: Node = null


func before_each() -> void:
	GameStateManager.set_input_locks([])
	im = IM_SCRIPT.new()
	im._ready()


func after_each() -> void:
	# 真实转场用例动的是 Autoload 的锁栈——清干净，不给后续用例留残锁
	InputManager.clear_locks()
	GameStateManager.set_input_locks([])
	if im != null:
		im.free()
		im = null


## 收集本用例产生的「pop_lock source not found」警告。[br]
## [br][b]为什么不直接 [method GutTest.assert_push_warning_count] 数 0[/b]：真实转场
## 顺带会触发无关的引擎警告（如 [code]BgmStreamCache[/code] 缺资源映射），
## 计数断言会把它们一起算进来。本缺陷的断言要的是「一条都没有」——
## 按文案精确筛，别的警告不参与。
func _source_not_found_warnings() -> Array:
	var hits: Array = []
	for err: Variant in gut.error_tracker.get_errors_for_test():
		if err.is_push_warning() and err.contains_text("source not found"):
			hits.append(err)
	return hits


# ═══════════════════════════════════════════════════════════════════════════════
# 单元层：tree_changed 清栈的边界
# ═══════════════════════════════════════════════════════════════════════════════

func test_scene_manager_transition_lock_survives_tree_changed() -> void:
	## 红用例：转场锁跨 tree_changed 存续——它本就要活到 Phase 4 的 pop。
	# Arrange —— 模拟 Phase 2 推锁
	im.push_lock(IM_SCRIPT.LockType.TRANSITION, SM_LOCK_SOURCE)
	assert_eq(im._lock_stack.size(), 1, "前置：TRANSITION 锁已入栈")

	# Act —— 模拟 Phase 3 的 change_scene_to_file 触发 tree_changed
	im._on_tree_changed()

	# Assert
	assert_true(im.has_lock(SM_LOCK_SOURCE),
			"转场锁应在 tree_changed 后继续存续——否则转场窗口内输入无人把守")
	assert_eq(im._lock_stack.size(), 1, "转场锁未被清，栈深仍为 1")


func test_other_sources_still_cleared_by_tree_changed() -> void:
	## 守卫：既有语义不退化——非跨场景锁照旧被 tree_changed 清干净
	## （旧场景遗留的对话/动画/模态锁必须清，否则下一场景开局输入被吞）。
	# Arrange
	im.push_lock(IM_SCRIPT.LockType.DIALOGUE, &"dialogue_system")
	im.push_lock(IM_SCRIPT.LockType.ANIMATION, &"combat_system")
	im.push_lock(IM_SCRIPT.LockType.MODAL, &"settings_menu")
	assert_eq(im._lock_stack.size(), 3, "前置：三个遗留锁")

	# Act
	im._on_tree_changed()

	# Assert
	assert_eq(im._lock_stack.size(), 0, "非跨场景锁应全部被清除")
	assert_false(im.has_lock(&"combat_system"), "combat_system 的锁不应残留")


func test_transition_lock_survives_while_orphans_are_cleared() -> void:
	## 混合场景：转场锁 + 旧场景遗留锁共存——只清遗留的那把。
	# Arrange
	im.push_lock(IM_SCRIPT.LockType.MODAL, &"inventory_panel")
	im.push_lock(IM_SCRIPT.LockType.TRANSITION, SM_LOCK_SOURCE)

	# Act
	im._on_tree_changed()

	# Assert
	assert_eq(im._lock_stack.size(), 1, "只应留下转场锁")
	assert_true(im.has_lock(SM_LOCK_SOURCE), "留下的是转场锁")
	assert_false(im.has_lock(&"inventory_panel"), "遗留的模态锁已清")


func test_pop_after_tree_changed_finds_lock_without_warning() -> void:
	## 红用例（②号症状）：Phase 4 的 pop 必须找到 Phase 2 推的条目——
	## 找不到就会 push_warning「source not found in stack」。
	# Arrange
	im.push_lock(IM_SCRIPT.LockType.TRANSITION, SM_LOCK_SOURCE)
	im._on_tree_changed()

	# Act —— Phase 4 解锁
	im.pop_lock(SM_LOCK_SOURCE)

	# Assert
	assert_eq(im._lock_stack.size(), 0, "pop 后栈应为空")
	assert_push_warning_count(0,
			"push/tree_changed/pop 全链不应产生任何 push_warning（source not found）")
	var locks: Array = GameStateManager.get_state("session.input_locks")
	assert_eq(locks.size(), 0, "GSM 镜像也应同步为空")


func test_lock_stack_source_constant_is_pinned() -> void:
	## 守卫：模块认定的跨场景 source 与 SceneManager 推锁用的字面量一致。
	# Variant 派发——preload 常量上的 get_script_constant_map() 会被静态解析器
	# 判为「在类上直接调非静态方法」，经 Variant 才能运行时调用。
	var script: Variant = LOCK_STACK
	var consts: Dictionary = script.get_script_constant_map()
	assert_true(consts.has("SCENE_TRANSITION_SOURCE"),
			"input_lock_stack 应声明跨场景 source 常量 SCENE_TRANSITION_SOURCE")
	assert_eq(consts.get("SCENE_TRANSITION_SOURCE"), SM_LOCK_SOURCE,
			"input_lock_stack 的跨场景 source 常量须与 SceneManager 推锁字面量一致")


# ═══════════════════════════════════════════════════════════════════════════════
# 集成层：真实转场（真实 change_scene_to_file → 真实 tree_changed）
# ═══════════════════════════════════════════════════════════════════════════════

func test_real_transition_holds_lock_until_phase4_then_releases() -> void:
	## 端到端：真实转场全窗口内锁都在（而不是被 tree_changed 抹掉），
	## 结束后干净释放、栈为空、无「source not found」警告。
	# Arrange —— 独立 SceneManager 实例 + 真实 InputManager Autoload
	var sm: Node = SM_SCRIPT.new()
	sm._ready()
	sm._test_mode = false
	var local_gsm: Node = MockFactory.build_gsm()
	var local_sl: Node = MockFactory.build_sl()
	sm.set_dependencies(local_gsm, InputManager, local_sl)
	add_child_autofree(sm)
	InputManager.clear_locks()

	# Act —— 真实转场（MAIN_MENU → LOADING，目标 .tscn 确认存在）
	var ok: bool = sm.request_scene_change(
			SM_SCRIPT.SceneID.MAIN_MENU, SM_SCRIPT.SceneID.LOADING,
			SM_SCRIPT.TransitionType.MENU_TO_GAME)
	assert_true(ok, "真实转场请求应被接受")
	# Phase 2 同步推锁——此刻必须在
	assert_true(InputManager.has_lock(SM_LOCK_SOURCE), "Phase 2 后转场锁应在栈上")

	# 转场窗口内逐帧采样：锁不得消失（tree_changed 已在 Phase 3 触发过）
	var held_through_window: bool = true
	var waited: int = 0
	while sm.is_transitioning() and waited < 60:
		if not InputManager.has_lock(SM_LOCK_SOURCE):
			held_through_window = false
			break
		await get_tree().process_frame
		waited += 1

	# Assert
	assert_false(sm.is_transitioning(),
			"转场应在帧预算内完成（等待 %d 帧）" % waited)
	assert_true(held_through_window,
			"转场窗口内每一帧都应持有 TRANSITION 锁（tree_changed 不得抹掉它）")
	assert_false(InputManager.has_lock(SM_LOCK_SOURCE),
			"Phase 4 应释放转场锁——不得泄漏")
	assert_eq(InputManager.get_lock_stack().size(), 0, "转场结束后锁栈应为空")
	assert_eq(_source_not_found_warnings().size(), 0,
			"真实转场全链不应有「pop_lock source not found」警告——pop 必须找到配对条目")

	# 清理——mock 不在 sm 子树内，须显式释放（bus_layout 先例）
	local_gsm.free()
	local_sl.free()


func test_transition_lock_blocks_ui_nav_input() -> void:
	## 真缺陷的玩家可见面：转场窗口内 ESC（UI_NAV）必须被 TRANSITION 锁挡住。
	# Arrange
	var sm: Node = SM_SCRIPT.new()
	sm._ready()
	sm._test_mode = false
	var local_gsm: Node = MockFactory.build_gsm()
	var local_sl: Node = MockFactory.build_sl()
	sm.set_dependencies(local_gsm, InputManager, local_sl)
	add_child_autofree(sm)
	InputManager.clear_locks()

	# Act
	var ok: bool = sm.request_scene_change(
			SM_SCRIPT.SceneID.MAIN_MENU, SM_SCRIPT.SceneID.LOADING,
			SM_SCRIPT.TransitionType.MENU_TO_GAME)
	assert_true(ok, "真实转场请求应被接受")

	# Assert —— 推锁当帧就应挡输入（Phase 2 → tree_changed 之间那一段最容易漏）
	assert_false(InputManager.is_input_allowed(
			IM_SCRIPT.ActionType.UI_NAV, IM_SCRIPT.DeviceType.KEYBOARD),
			"转场窗口内 UI_NAV（ESC）不应放行")
	assert_eq(InputManager.get_current_lock(), IM_SCRIPT.LockType.TRANSITION,
			"当前最高级锁应为 TRANSITION(3)")

	# 收尾——等转场结束，避免把转场状态留给后续用例
	var waited: int = 0
	while sm.is_transitioning() and waited < 60:
		await get_tree().process_frame
		waited += 1
	local_gsm.free()
	local_sl.free()
