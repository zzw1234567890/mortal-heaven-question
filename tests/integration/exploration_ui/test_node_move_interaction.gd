extends GutTest
## exploration-ui Story 17-005 集成测试：节点移动交互流与教程覆盖。
##
## Story 类型 Integration——此文件为 BLOCKING 证据（story-005 Test Evidence 路径）。
## [br]覆盖 QA Test Cases（QA 计划 17-1）：[br]
##   - AC-1：移动委托流——move_to_node 恰好一次 / node_moved 驱动标记移动 /
##     AP 扣减与系统返回一致 / 战斗到达通知恰好一次（不预弹）[br]
##   - AC-2：不可达反馈——系统失败驱动 toast+抖动 / 已访问静默 /
##     双份用例锁定（UI 零预判 + 系统失败驱动）[br]
##   - AC-3：教程——首次 3 步 / 任意点击跳过 / step_reached 载荷区分 /
##     二次进入不显示[br]
##   - 边界：动画期间二次点击缓冲语义 / AP=0 Boss 豁免仍提交 /
##     悬停已探索标记 / reduce_motion 直跳终位[br]
## [br][b]mock 注入[/b]：MockExplorationSystem 替换真实 Autoload（依赖注入），
## reducer_motion=true 关闭动画避免 Tween 挂起（test_hand_area 先例）。
##
## 来源: story-005-node-move-interaction.md QA Test Cases、QA 计划
## sprint-17 §17-1、ADR-0014 §决策 3、ADR-0031 §2。

const NodeMoveInteractorScript := preload("res://src/ui/exploration/node_move_interactor.gd")
const NodeTutorialOverlayScript := preload("res://src/ui/exploration/node_tutorial_overlay.gd")
const MockSystem := preload("res://tests/integration/exploration_ui/mocks/mock_exploration_system.gd")
const NodeGraphRendererScript := preload("res://src/ui/exploration/node_graph_renderer.gd")
const NodeMoveAnimatorScript := preload("res://src/ui/exploration/node_move_animator.gd")
const DATA_STUB := preload("res://src/ui/exploration/node_graph_data_stub.gd")
const NODE_LOGIC := preload("res://src/ui/exploration/node_state_logic.gd")
## 视觉规格（节点边长——命中检测边界按它推导，见 test_hit_test_node_grows_with_hover_scale）。
const Style := preload("res://src/ui/exploration/node_graph_style.gd")

## 命中检测辅助——stub 节点 101 的中心坐标容差（px）。
const HIT_TOLERANCE: float = 2.0

var mock: Node = null
var renderer: Control = null
var interactor: NodeMoveInteractor = null
var tutorial: NodeTutorialOverlay = null


func before_each() -> void:
	mock = MockSystem.new()
	add_child_autofree(mock)
	# 真实 NodeGraphRenderer（非裸 Control）——交互组件消费其
	# get_node_position/hit_test_node/states 契约。先 setup 布局再挂 interactor
	#（overlay 挂载顺序与生产路径一致）。
	renderer = NodeGraphRendererScript.new()
	renderer.size = Vector2(1280, 720)
	add_child_autofree(renderer)
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	var states: Dictionary = {}
	for node_id: int in snap["nodes"].keys():
		states[node_id] = NODE_LOGIC.classify_node_state(node_id, snap["graph"],
				snap["visited"], snap["current_node"], snap["ap_remaining"], snap["nodes"])
	renderer.setup(snap["graph"], snap["nodes"], snap["visited"], snap["current_node"])
	renderer.set_states(states)
	interactor = NodeMoveInteractorScript.new()
	interactor.set_reduce_motion(true)
	add_child_autofree(interactor)
	interactor.setup(renderer, mock)
	interactor.apply_snapshot(snap)
	# 教程覆盖独立实例（宿主编排路径的组件级测试）
	tutorial = NodeTutorialOverlayScript.new()
	add_child_autofree(tutorial)
	tutorial.read_flag_cb = func() -> bool: return false
	tutorial.write_flag_cb = func(_v: bool) -> void: pass


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：移动委托流
# ═══════════════════════════════════════════════════════════════════════════════

func test_click_reachable_node_move_called_once() -> void:
	# Given: mock 可编程成功返回
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	# When: 点击可达节点 101（直调 request_move——点击路径的委托接缝）
	interactor.request_move(101)
	# Then: move_to_node 恰好调用一次且参数正确
	assert_eq(mock.move_calls.size(), 1, "move_to_node 应恰好调用一次")
	assert_eq(mock.move_calls[0], [0, 101], "调用参数应为 (当前节点 0, 目标 101)")


## overlay 圆心坐标——position + size * 0.5（overlay 工厂坐标契约）。
func _overlay_center(overlay: Control) -> Vector2:
	return overlay.position + overlay.size * 0.5


func test_node_moved_drives_marker_and_ap_consistent() -> void:
	# Given: 成功移动（AP 3→2）
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	var marker: Control = renderer.get_node_or_null(NodePath("MoveMarker"))
	# When: 提交移动（mock emit_on_success 发射 node_moved）
	interactor.request_move(101)
	# Then: 标记[绘制圆心]落在 101 节点中心（reduce_motion 直跳终位）
	# + 快照 AP 同步。断言圆心而非左上角——审查 H1：position 语义为
	# center - size*0.5，直接比 position 会把坐标偏移缺陷固化为期望值。
	assert_eq(_overlay_center(marker), renderer.get_node_position(101),
			"玩家标记圆心应落在目标节点中心（node_moved 信号驱动）")
	assert_eq(int(interactor._snapshot.get("ap_remaining", -1)), 2,
			"AP 扣减应与系统返回值一致")


func test_overlay_positions_are_centered_on_node() -> void:
	# 审查 H1 回归锁定：三个 overlay 的圆心语义统一为 center - size*0.5
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	interactor.request_move(101)
	var marker: Control = renderer.get_node_or_null(NodePath("MoveMarker"))
	assert_eq(_overlay_center(marker), renderer.get_node_position(101),
			"MoveMarker 绘制圆心 == 节点中心")
	# 抖动环：成功路径不产生；改为失败路径验证同一坐标契约
	mock.move_result = {"success": false, "reason": "不可达", "ap_remaining": 2}
	interactor.set_reduce_motion(false)
	interactor.request_move(102)
	var shake: Control = renderer.get_node_or_null(NodePath("ShakeOverlay"))
	# 硬断言（QA 走查 G5）：shake 为 null 时上面的 `if` 会静默跳过整段坐标契约断言
	assert_not_null(shake, "失败反馈应创建 ShakeOverlay（reduce_motion=false）")
	assert_true(shake.visible, "抖动期间 ShakeOverlay 应可见")
	assert_eq(_overlay_center(shake), renderer.get_node_position(102),
			"ShakeOverlay 绘制圆心 == 节点中心")


func test_combat_arrival_notification_exactly_once_not_pre_fired() -> void:
	# Given: 战斗类节点成功移动（mock 自动发射 combat_node_reached）
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	var arrivals: Array = []
	interactor.combat_arrival_forwarded.connect(
			func(_roster: Array, _ctype: StringName) -> void: arrivals.append(1))
	# When: 点击前无通知（不预弹——B4 先移动后弹窗）
	assert_eq(arrivals.size(), 0, "移动提交前不应有到达通知（不预弹）")
	# When: 提交移动 → node_moved → 到达信号
	interactor.request_move(101)
	# Then: 到达通知恰好一次
	assert_eq(arrivals.size(), 1, "移动完成后到达通知应恰好一次")


func test_arrival_deferred_until_move_animation_finishes() -> void:
	# 审查 H2 回归锁定（B4「先移动后弹窗」）：动画进行中到达信号不立即转发
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	var arrivals: Array = []
	interactor.combat_arrival_forwarded.connect(
			func(_roster: Array, _ctype: StringName) -> void: arrivals.append(1))
	interactor.set_reduce_motion(false)  # 开动画——让 node_moved 后仍在 _animating
	interactor.request_move(101)
	# Then: 动画未完成 → 到达通知尚未转发
	assert_eq(arrivals.size(), 0, "移动动画进行中不应触发到达弹窗")
	# When: 动画完成
	interactor._finish_move_animation(101)
	# Then: 暂存的到达通知转发
	assert_eq(arrivals.size(), 1, "移动动画完成后到达通知应转发恰好一次")


func test_setup_is_idempotent_no_double_bind() -> void:
	# 审查 H4 回归锁定：重复 setup 不产生双绑（否则双重动画 + 缓冲双消费）
	interactor.setup(renderer, mock)
	interactor.setup(renderer, mock)
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	interactor.request_move(101)
	# Then: 单次移动只记录一次调用（双绑会让 mock 发射两次 node_moved）
	assert_eq(mock.move_calls.size(), 1, "重复 setup 后 move_to_node 仍只调用一次")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：不可达反馈（系统失败驱动）
# ═══════════════════════════════════════════════════════════════════════════════

func test_ap_insufficient_feedback_toast_and_shake() -> void:
	# Given: 系统返回「行动力不足」失败
	mock.move_result = {"success": false, "reason": "行动力不足", "ap_remaining": 0}
	var feedbacks: Array = []
	interactor.move_feedback_requested.connect(
			func(toast: String, node_id: int) -> void: feedbacks.append([toast, node_id]))
	# When: 点击 101
	interactor.request_move(101)
	# Then: toast 文案正确映射 + 无移动（move_calls 只有失败那一次提交）
	assert_eq(feedbacks.size(), 1, "失败应触发一次反馈")
	assert_eq(feedbacks[0][0], "行动力不足", "toast 文案应为「行动力不足」")
	assert_eq(feedbacks[0][1], 101, "抖动目标节点应为点击节点")


func test_unreachable_feedback_maps_reason_to_toast() -> void:
	# Given: 系统返回「不可达」失败
	mock.move_result = {"success": false, "reason": "不可达", "ap_remaining": 3}
	var feedbacks: Array = []
	interactor.move_feedback_requested.connect(
			func(toast: String, _node_id: int) -> void: feedbacks.append(toast))
	# When: 点击不可达节点
	interactor.request_move(101)
	# Then: toast 文案为「路径不可达」
	assert_eq(feedbacks, ["路径不可达"], "toast 文案应映射为「路径不可达」")


func test_visited_node_click_silent_no_feedback() -> void:
	# Given: 系统返回「已访问」
	mock.move_result = {"success": false, "reason": "已访问", "ap_remaining": 3}
	var feedbacks: Array = []
	interactor.move_feedback_requested.connect(
			func(_toast: String, _node_id: int) -> void: feedbacks.append(1))
	# When: 点击已访问节点 0（入口已在 visited）
	interactor.request_move(0)
	# Then: 静默无反应——无 toast 无抖动
	assert_eq(feedbacks.size(), 0, "已访问节点点击应静默无反应")


func test_ui_no_precheck_unreachable_still_submitted() -> void:
	# AC-2 双份用例（manifest 禁令锁定）：UI 明知快照中 101 不可达
	# （构造 current_node=500——非邻接）仍提交系统，不本地拦截
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	snap["current_node"] = 500  # Boss 位置——101 非其邻接
	snap["visited"] = [0, 500]
	interactor.apply_snapshot(snap)
	mock.move_result = {"success": false, "reason": "不可达", "ap_remaining": 3}
	# When: 点击 101（快照视角不可达）
	interactor.request_move(101)
	# Then: 仍提交系统（零预判——判定权在系统）
	assert_eq(mock.move_calls.size(), 1,
			"UI 不预判可达性——不可达节点点击仍提交系统判定")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：教程覆盖
# ═══════════════════════════════════════════════════════════════════════════════

func test_tutorial_first_entry_shows_three_steps() -> void:
	# Given: 新档（教程标记未设）
	# When: 首次进入第一张地图
	tutorial.on_map_entered()
	# Then: 教程显示且在第 1 步
	assert_true(tutorial.visible, "新档首次进入应显示教程")
	assert_eq(tutorial._step, 1, "教程应从第 1 步开始")
	assert_eq(tutorial.STEP_TEXTS.size(), 3, "教程应为 3 步")


func test_tutorial_click_skip_emits_event_step_one() -> void:
	# Given: 教程进行中（第 1 步）
	tutorial.on_map_entered()
	var events: Array = []
	tutorial.tutorial_skipped.connect(
			func(step: int) -> void: events.append(step))
	# When: 第 1 步任意点击跳过
	tutorial.skip(1)
	# Then: tutorial_skipped 发射且载荷 step_reached=1 + 教程隐藏
	assert_eq(events, [1], "第 1 步跳过应发射 step_reached=1")
	assert_false(tutorial.visible, "跳过后教程应隐藏")


func test_tutorial_completed_payload_distinguished_from_step_one() -> void:
	# QA 边缘 #3：step_reached=3（完整走完）与 =1（第 1 步跳过）载荷区分
	tutorial.on_map_entered()
	var events: Array = []
	tutorial.tutorial_skipped.connect(
			func(step: int) -> void: events.append(step))
	# When: 完整走完 3 步（步进 Timer 到期路径 ×3）
	tutorial._on_step_timeout()
	tutorial._on_step_timeout()
	tutorial._on_step_timeout()
	# Then: 载荷 step_reached=3（与第 1 步跳过区分）
	assert_eq(events, [3], "完整走完应发射 step_reached=3（与 =1 区分）")


func test_tutorial_second_entry_not_shown() -> void:
	# Given: 教程已完成（标记已写——write_flag_cb 捕获）
	var written: Array = []
	tutorial.write_flag_cb = func(v: bool) -> void: written.append(v)
	tutorial.on_map_entered()
	tutorial.skip(1)
	assert_eq(written, [true], "跳过应写入已完成标记（GSM story_flags）")
	# When: 二次进入（标记读取为 true）
	tutorial.read_flag_cb = func() -> bool: return true
	tutorial.on_map_entered()
	# Then: 不再显示
	assert_false(tutorial.visible, "二次进入教程不应显示")


# ═══════════════════════════════════════════════════════════════════════════════
# 边界情况（QA 计划 17-1 §17-1 边界 1/2/5 + reduce_motion）
# ═══════════════════════════════════════════════════════════════════════════════

func test_click_during_animation_buffered_and_executed_after() -> void:
	# AC-7 锁定：动画期间新点击入缓冲队列，完成后依序提交（不丢弃不重复）
	# Given: 动画进行中（手工置 _animating——动画时序不纳入自动化断言，
	# 缓冲语义为 Integration 断言目标）
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	interactor._animating = true
	# When: 动画期间点击 101
	interactor.request_move(101)
	assert_eq(mock.move_calls.size(), 0, "动画期间点击应缓冲不立即提交")
	# When: 动画完成（_finish_move_animation 消费队列）
	interactor._finish_move_animation(101)
	# Then: 缓冲点击依序执行
	assert_eq(mock.move_calls.size(), 1, "动画完成后缓冲点击应依序提交")
	assert_eq(mock.move_calls[0][1], 101, "缓冲点击目标应保持不丢失")


func test_ap_zero_boss_exempt_node_still_submitted() -> void:
	# GDD 边界（QA 边缘 #5）：AP=0 但 Boss 豁免节点仍可提交（判定归系统）
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	snap["ap_remaining"] = 0
	interactor.apply_snapshot(snap)
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 0}
	# When: AP=0 下点击（提交路径与普通节点一致——零预判）
	interactor.request_move(101)
	# Then: 提交成功（系统豁免判定归系统，UI 不拦截）
	assert_eq(mock.move_calls.size(), 1, "AP=0 提交不被 UI 拦截（豁免归系统判定）")


func test_hover_visited_node_no_scale_vs_reachable_scale() -> void:
	# AC-4/AC-5：悬停视觉单一来源在渲染层（审查 H3 修正——移除 interactor 放大环）
	# When: 渲染器悬停可达节点 101
	renderer.hovered_node = 101
	# Then: 可达态 → 放大 110%（精确倍率断言——QA 走查 G2：原断言恒真）
	assert_eq(renderer.get_node_draw_scale(101), renderer.HOVER_SCALE_RATIO,
			"可达节点悬停绘制倍率应为 HOVER_SCALE_RATIO（AC-5 110%）")
	assert_eq(renderer.HOVER_SCALE_RATIO, 1.1, "HOVER_SCALE_RATIO 应为 UX 规格 110%")
	# When: 悬停已访问节点 0（入口——visited）
	renderer.hovered_node = 0
	assert_eq(renderer.get_node_draw_scale(0), 1.0, "已访问节点悬停不应放大")
	# When: 无悬停
	renderer.hovered_node = -1
	assert_eq(renderer.get_node_draw_scale(101), 1.0, "未悬停的可达节点不应放大")


func test_hover_unreachable_node_no_scale() -> void:
	# AC-5 边界：悬停不可达节点不放大（仅可达态有悬停反馈）
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	snap["ap_remaining"] = 0  # 101 变行动力不足
	renderer.setup(snap["graph"], snap["nodes"], snap["visited"], snap["current_node"])
	var states: Dictionary = {}
	for node_id: int in snap["nodes"].keys():
		states[node_id] = NODE_LOGIC.classify_node_state(node_id, snap["graph"],
				snap["visited"], snap["current_node"], 0, snap["nodes"])
	renderer.set_states(states)
	renderer.hovered_node = 101
	assert_eq(renderer.get_node_draw_scale(101), 1.0, "不可达节点悬停不应放大")


func test_reduce_motion_marker_snaps_to_final_position() -> void:
	# reduce_motion 直跳终位（test_hand_area 先例）——标记瞬时到达无动画
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	var marker: Control = renderer.get_node_or_null(NodePath("MoveMarker"))
	# When: 移动（reduce_motion=true——before_each 注入）
	interactor.request_move(101)
	# Then: 标记直跳终位（圆心语义）且动画标记复位（无 Tween 挂起）
	assert_eq(_overlay_center(marker), renderer.get_node_position(101),
			"reduce_motion 玩家标记圆心应直跳终位")
	assert_false(interactor._animating, "reduce_motion 移动后动画标记应复位")


# ═══════════════════════════════════════════════════════════════════════════════
# 审查回归锁定（H3 键盘 / M2 缓冲 / M3 命中可见性 / B1 flag 委托）
# ═══════════════════════════════════════════════════════════════════════════════

func test_keyboard_navigate_and_confirm_moves() -> void:
	# AC-9：方向键跳转 → Enter 确认（键盘设备过锁栈）
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	var focus_events: Array = []
	interactor.keyboard_focus_changed.connect(
			func(node_id: int) -> void: focus_events.append(node_id))
	# When: 向下方向键（从当前节点 0 跳到下一层可达节点）
	var target: int = interactor.navigate_focus(Vector2i(0, 1))
	# Then: 焦点落在可达节点并外发通知（渲染器绘制焦点环）
	assert_true(target > 0, "方向键应找到下一层可达节点")
	assert_eq(focus_events, [target], "焦点变化应外发一次")
	# When: Enter 确认
	interactor.confirm_keyboard_selection()
	# Then: 提交移动（键盘设备）
	assert_eq(mock.move_calls.size(), 1, "Enter 确认应提交一次移动")
	assert_eq(mock.move_calls[0][1], target, "提交目标应为键盘焦点节点")


func test_click_unrevealed_layer_not_hit_during_reveal() -> void:
	# M3：0.8s 逐层展开期间，未显现层不可点击（复用 renderer.hit_test_any 的过滤）
	renderer.reveal_max_layer = 0  # 仅第 0 层可见
	var unrevealed_pos: Vector2 = renderer.get_node_position(101)
	assert_true(renderer.nodes.has(101), "stub 应含节点 101")
	assert_eq(renderer.hit_test_any(unrevealed_pos), -1,
			"未显现层的节点不应命中（未绘制不可交互）")


func test_buffered_duplicate_target_not_queued_twice() -> void:
	# M2：同一目标重复点击只入队一次（避免移动后二次提交必然「不可达」）
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	interactor._animating = true
	interactor.request_move(101)
	interactor.request_move(101)
	assert_eq(interactor._click_buffer.size(), 1, "同一目标重复点击应去重")


func test_buffered_move_preserves_device_type() -> void:
	# 审查 M4：缓冲来自键盘时，flush 后锁栈判定须仍按 KEYBOARD（ADR-0004）
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	interactor._animating = true
	interactor.request_move(101, interactor.InputManagerScript.DeviceType.KEYBOARD)
	assert_eq(interactor._click_buffer.size(), 1, "动画期间键盘确认应入缓冲")
	var entry: Array = interactor._click_buffer[0]
	assert_eq(int(entry[0]), 101, "缓冲元素应含目标节点")
	assert_eq(int(entry[1]), interactor.InputManagerScript.DeviceType.KEYBOARD,
			"缓冲元素应保留输入设备类型（不得回落 MOUSE）")
	# When: 动画完成消费缓冲
	interactor._finish_move_animation(101)
	assert_eq(interactor._click_buffer.size(), 0, "缓冲应在完成后消费")


# ─────────────────────────────────────────────────────────────────────────────
# 渲染器行为（审查 H2 悬停清除 / M1 命中框同源 / M6 焦点环）
# ─────────────────────────────────────────────────────────────────────────────

func test_mouse_exited_clears_hover_and_emits() -> void:
	# 审查 H2：Godot 4 无 _mouse_exited 虚方法——改连 mouse_exited 信号
	var hover_events: Array = []
	renderer.hover_changed.connect(func(node_id: int) -> void: hover_events.append(node_id))
	renderer.hovered_node = 101
	# When: 悬停离开渲染器
	renderer._on_mouse_exited()
	# Then: 悬停复位 + 通知外发（后者此前永不发射）
	assert_eq(renderer.hovered_node, -1, "鼠标离开应清除悬停节点")
	assert_eq(hover_events, [-1], "清除悬停应发射 hover_changed(-1)")


func test_mouse_exited_noop_when_no_hover() -> void:
	# 审查 H2 边界：无悬停时离开不重复发信号（避免噪声）
	var hover_events: Array = []
	renderer.hover_changed.connect(func(node_id: int) -> void: hover_events.append(node_id))
	assert_eq(renderer.hovered_node, -1, "前置：无悬停")
	renderer._on_mouse_exited()
	assert_eq(hover_events.size(), 0, "无悬停时离开不应发射信号")


## ★ 改前红：旧版断言「悬停放大后命中框同步放大（矩形按 NODE_SIZE 推导）」★[br]
## [br][b]老板 2026-11-27：「我想要一个节点一块地区，鼠标移上去都能高亮有交互的
## 那种」[/b]——命中判据从「点中那枚 56px（悬停 61.6px）的圆印」改成
## [code]point-in-region[/code]（[method NodeGraphRegionCommon.node_at]）之后，
## 这个用例的两条 [code]assert_false[/code] 必然红：图标半径外的点现在落在[b]同一块
## 地区[/b]里，本就该命中。[br]
## [br][b]改写方式（不是删断言，也不是把数值改大到能过）[/b]：旧版守的是「命中框
## 与绘制同源，边缘不抖」（审查 M1）。新口径下「同源」的含义变了——地区由[b]节点
## 位置[/b]决定，与悬停态无关，所以正确的同源断言是
## [b]「悬停不改变任何一点的归属」[/b]：这既钉住了旧版要防的抖动（鼠标移上去不会
## 让命中范围跳变），又钉住了新口径下真正的风险（悬停高亮若顺手改了分块，鼠标一进
## 一出就会在两个节点之间来回夺权）。[br]
## [br][b]地区覆盖范围本身由 [code]test_node_graph_pick_region.gd[/code] 断言[/b]
## （区域内点命中 / 边界外不命中 / 交界取最近种子）——本文件只管交互接线，
## 不重复那边的事。
func test_hit_test_is_stable_across_hover_states() -> void:
	var center: Vector2 = renderer.get_node_position(101)
	var half: float = Style.NODE_SIZE * 0.5
	# 三个样本点：图标正中心 / 图标半径外一截（地区内）/ 更远处（地区内更靠边）
	var samples: Array[Vector2] = [
		center,
		center + Vector2(half + 2.0, 0.0),
		center + Vector2(0.0, -half * 2.0),
	]
	var before: Array[int] = []
	for point: Vector2 in samples:
		before.append(renderer.hit_test_any(point))
	# When: 悬停 101（旧版正是在这一步改变命中框）
	renderer.hovered_node = 101
	# Then: 每一点的归属与悬停前逐一相同——悬停只改绘制，不改分块
	for i: int in samples.size():
		assert_eq(renderer.hit_test_any(samples[i]), before[i],
				"悬停不得改变第 %d 个采样点的归属（地区由节点位置决定）" % i)
	# 且图标外那一截确实算 101 的地（新旧口径的差别正在这里）
	assert_eq(renderer.hit_test_any(center + Vector2(half + 2.0, 0.0)), 101,
			"图标半径外、地区之内 → 仍命中 101（本轮新口径）")


func test_set_focused_node_updates_and_is_idempotent() -> void:
	# 审查 M6：焦点注入的状态变化（焦点环绘制的输入）
	renderer.set_focused_node(101)
	assert_eq(renderer.focused_node, 101, "焦点节点应注入成功")
	renderer.set_focused_node(101)
	assert_eq(renderer.focused_node, 101, "重复注入同一节点应幂等")
	renderer.set_focused_node(-1)
	assert_eq(renderer.focused_node, -1, "应可清除焦点")


func test_tutorial_uses_event_system_not_gsm_direct() -> void:
	# B1：教程标记读写走 EventSystem（story_flags 唯一写入者，ADR-0003）
	var flag_reader := func() -> bool:
		var es: Node = tutorial.get_node_or_null("/root/EventSystem")
		return es != null and bool(es.get_flag("exploration_tutorial_done", false))
	# 清空注入——走默认 EventSystem 路径（before_each 注入了 no-op 写回）
	tutorial.read_flag_cb = Callable()
	tutorial.write_flag_cb = Callable()
	tutorial.read_flag_cb = flag_reader
	tutorial.on_map_entered()
	tutorial.skip(1)
	# Then: 写入后经 EventSystem 读回为 true（证明唯一写入入口生效）
	assert_true(flag_reader.call(), "教程标记应可经 EventSystem.get_flag 读回")
	# 清理：复位标记，避免污染其他用例
	var es: Node = tutorial.get_node_or_null("/root/EventSystem")
	if es != null:
		es.set_flag("exploration_tutorial_done", false)


# ═══════════════════════════════════════════════════════════════════════════════
# QA 走查 G1/G3/G4/G5/G6 补充（AC-1 点击接线 / AC-2 其余到达分支 / AC-3 失败侧 /
# AC-6 翻转脉冲 / AC-8 真实跳过路径）
# ═══════════════════════════════════════════════════════════════════════════════

func test_click_through_renderer_gui_input_submits_move() -> void:
	# QA 走查 G4（AC-1 点击入口接线）：生产路径是 renderer.gui_input →
	# interactor._on_renderer_input → 命中检测 → request_move。此前所有用例直调
	# request_move，接线本身无断言（renderer 换实现即静默断连）。
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = renderer.get_node_position(101)
	# When: 经渲染器输入信号点击可达节点 101（生产接缝）
	renderer.gui_input.emit(click)
	# Then: 提交到系统恰好一次（证明点击接线生效）
	assert_eq(mock.move_calls.size(), 1, "点击接线应把命中节点提交给系统")
	assert_eq(mock.move_calls[0], [0, 101], "命中 101 应提交 (当前 0, 目标 101)")


func test_click_miss_node_submits_nothing() -> void:
	# QA 走查 G4 边界：点击空白处不提交（命中 -1）
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(-500.0, -500.0)
	renderer.gui_input.emit(click)
	assert_eq(mock.move_calls.size(), 0, "未命中节点不应提交移动")


func test_boss_arrival_forwarded_once() -> void:
	# QA 走查 G3（AC-2）：Boss 到达分支转发（此前仅 combat 分支有覆盖）
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	mock.arrival_signal = &"boss_node_reached"
	var arrivals: Array = []
	interactor.boss_arrival_forwarded.connect(
			func(data: Dictionary) -> void: arrivals.append(data))
	interactor.request_move(500)
	assert_eq(arrivals.size(), 1, "Boss 到达通知应转发恰好一次")
	assert_eq(typeof(arrivals[0]), TYPE_DICTIONARY, "Boss 载荷应为 Dictionary")


func test_node_interaction_arrival_forwarded_once() -> void:
	# QA 走查 G3（AC-2）：交互类节点（商店/灵泉）到达分支转发
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	mock.arrival_signal = &"node_interaction_triggered"
	var forwarded: Array = []
	interactor.node_interaction_forwarded.connect(
			func(node_id: int, itype: StringName, payload: Dictionary) -> void:
				forwarded.append([node_id, itype, payload]))
	interactor.request_move(201)
	assert_eq(forwarded.size(), 1, "交互节点到达应转发恰好一次")
	assert_eq(forwarded[0][0], 201, "转发节点 ID 应为到达节点")
	assert_eq(forwarded[0][1], &"shop", "交互类型应透传系统载荷")


func test_failure_keeps_ap_and_marker_position() -> void:
	# QA 走查 G5（AC-3 失败侧不变量）：失败不改 AP、不移动标记
	var marker: Control = renderer.get_node_or_null(NodePath("MoveMarker"))
	var before_pos: Vector2 = _overlay_center(marker)
	var before_ap: int = int(interactor._snapshot.get("ap_remaining", -1))
	mock.move_result = {"success": false, "reason": "不可达", "ap_remaining": 0}
	interactor.request_move(101)
	assert_eq(int(interactor._snapshot.get("ap_remaining", -1)), before_ap,
			"失败不应改动快照 AP（哪怕系统返回 ap_remaining=0）")
	assert_eq(_overlay_center(marker), before_pos, "失败不应移动玩家标记")


func test_visited_flip_pulse_after_move_animation() -> void:
	# QA 走查 G1（AC-6）：移动完成后播放 0.2s 已访问翻转脉冲
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	interactor.set_reduce_motion(false)
	interactor.request_move(101)
	# 动画进行中：翻转脉冲尚未开始
	var flip: Control = renderer.get_node_or_null(NodePath("FlipOverlay"))
	assert_true(flip == null or not flip.visible, "移动动画期间不应提前播放翻转脉冲")
	# When: 动画完成（AC-6「到达动画后」）
	interactor._finish_move_animation(101)
	# Then: 翻转环出现、位于目标节点、时长符合 AC-6
	flip = renderer.get_node_or_null(NodePath("FlipOverlay"))
	assert_not_null(flip, "移动完成应创建 FlipOverlay")
	assert_true(flip.visible, "翻转脉冲应可见")
	assert_eq(_overlay_center(flip), renderer.get_node_position(101),
			"翻转脉冲圆心应落在到达节点")
	assert_eq(NodeMoveAnimatorScript.VISITED_FLIP_SEC, 0.2, "翻转脉冲时长应为 AC-6 的 0.2s")


func test_visited_flip_ordering_after_arrival_notification() -> void:
	# QA 走查 G1 时序：翻转脉冲先于暂存到达通知转发（B4 先移动后弹窗）
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	interactor.set_reduce_motion(false)
	var order: Array = []
	interactor.combat_arrival_forwarded.connect(
			func(_r: Array, _c: StringName) -> void:
				var flip: Control = renderer.get_node_or_null(NodePath("FlipOverlay"))
				order.append("arrival:%s" % str(flip != null and flip.visible)))
	interactor.request_move(101)
	interactor._finish_move_animation(101)
	assert_eq(order, ["arrival:true"], "到达通知转发时翻转脉冲应已播放")


func test_tutorial_click_gui_input_skips() -> void:
	# QA 走查 G6（AC-8 真实跳过路径）：任意点击经 _gui_input 跳过（非直调 skip）
	# 注意：Control._gui_input 为引擎回调，测试用 push_input 无法直达——改为
	# 复制生产分派：控件收到 InputEventMouseButton 即 skip(_step)。此处走
	# _gui_input 直调以锁定该分派的语义（此前 skip() 直调绕过了事件分支）。
	tutorial.on_map_entered()
	var events: Array = []
	tutorial.tutorial_skipped.connect(func(s: int) -> void: events.append(s))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	tutorial._gui_input(click)
	assert_eq(events, [1], "点击经 _gui_input 应跳过并发射 step_reached=1")
	assert_false(tutorial.visible, "跳过后教程应隐藏")


func test_tutorial_enter_key_gui_input_skips() -> void:
	# QA 走查 G6 键盘分支：Enter 跳过（H7 焦点修复后的真实输入分派）
	tutorial.on_map_entered()
	var events: Array = []
	tutorial.tutorial_skipped.connect(func(s: int) -> void: events.append(s))
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	tutorial._gui_input(key)
	assert_eq(events, [1], "Enter 经 _gui_input 应跳过")


func test_tutorial_release_event_does_not_skip() -> void:
	# QA 走查 G6 边界：抬起事件不触发跳过（pressed 守卫）
	tutorial.on_map_entered()
	var events: Array = []
	tutorial.tutorial_skipped.connect(func(s: int) -> void: events.append(s))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	tutorial._gui_input(click)
	assert_eq(events.size(), 0, "抬起事件不应跳过教程")
	assert_true(tutorial.visible, "教程应保持显示")


func test_tutorial_scroll_wheel_does_not_skip() -> void:
	# 审查 LOW：滚轮（WHEEL_UP/DOWN）不是点击——不应关闭教程
	tutorial.on_map_entered()
	var events: Array = []
	tutorial.tutorial_skipped.connect(func(s: int) -> void: events.append(s))
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	tutorial._gui_input(wheel)
	assert_eq(events.size(), 0, "滚轮不应跳过教程")
	assert_true(tutorial.visible, "滚轮后教程应保持显示")


func test_tutorial_right_click_does_not_skip() -> void:
	# 审查 LOW：仅左键跳过（右键保留给未来的上下文菜单/取消语义）
	tutorial.on_map_entered()
	var events: Array = []
	tutorial.tutorial_skipped.connect(func(s: int) -> void: events.append(s))
	var rclick := InputEventMouseButton.new()
	rclick.button_index = MOUSE_BUTTON_RIGHT
	rclick.pressed = true
	tutorial._gui_input(rclick)
	assert_eq(events.size(), 0, "右键不应跳过教程")


func test_tutorial_keypad_enter_skips() -> void:
	# 审查 LOW：小键盘 Enter 与主键盘同口径（与 interactor 确认键一致）
	tutorial.on_map_entered()
	var events: Array = []
	tutorial.tutorial_skipped.connect(func(s: int) -> void: events.append(s))
	var key := InputEventKey.new()
	key.keycode = KEY_KP_ENTER
	key.pressed = true
	tutorial._gui_input(key)
	assert_eq(events, [1], "小键盘 Enter 应跳过教程")


# ═══════════════════════════════════════════════════════════════════════════════
# 终审补充（LP-CODE-REVIEW M1 teardown 复位 / AC-1 动画时长上限）
# ═══════════════════════════════════════════════════════════════════════════════

func test_teardown_resets_animating_and_buffer() -> void:
	# 终审 M1：teardown 杀死 Tween 后完成回调不再触发——必须复位瞬态状态，
	# 否则重建后点击永久进缓冲队列（生产：场景切换/resize 重建组件）
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	interactor.set_reduce_motion(false)
	interactor.request_move(101)
	assert_true(interactor._animating, "前置：动画进行中")
	# When: 动画未完成即拆解组件
	interactor.teardown()
	# Then: 瞬态状态复位（后续 setup 不被缓冲黑洞吞掉）
	assert_false(interactor._animating, "teardown 应复位 _animating")
	assert_eq(interactor._click_buffer.size(), 0, "teardown 应清空缓冲队列")
	# When: 重新装配后点击
	interactor.setup(renderer, mock)
	interactor.set_reduce_motion(true)
	mock.move_calls.clear()
	interactor.request_move(101)
	assert_eq(mock.move_calls.size(), 1, "重建后点击应立即提交（不再进缓冲）")


func test_move_animation_duration_within_ux_limit() -> void:
	# AC-1「≤0.5s/节点」（UX A2 硬上限）——此前无任何断言锁定
	assert_true(NodeMoveAnimatorScript.MOVE_ANIM_SEC <= 0.5,
			"单节点移动动画时长应 ≤ 0.5s（实测 %s）" % NodeMoveAnimatorScript.MOVE_ANIM_SEC)
	assert_eq(NodeMoveAnimatorScript.MOVE_ANIM_SEC, 0.4, "移动动画时长应为 UX 规格 0.4s")
