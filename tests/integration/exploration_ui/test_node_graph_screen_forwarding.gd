extends GutTest
## exploration-ui S17-005 集成测试：NodeGraphScreen 对外接线（代码审查 H1/H3）。
##
## [b]覆盖[/b]：屏幕层是交互组件与后续 story（006/007 弹窗、HUD 通知）之间的
## 唯一公开契约。本文件锁定三条此前无断言的接线：[br]
##   - 到达通知转发：`interactor.combat/boss/node_interaction_*_forwarded` →
##     `screen.*_forwarded`（H3——消费方不再依赖私有成员 `_move_interactor`）
##   - 移动失败反馈转发：`screen.move_feedback_forwarded`（H1——toast 的延后接线
##     入口，见 story Test Evidence 的延后义务）[br]
##   - 键盘焦点：`keyboard_focus_changed` → `renderer.set_focused_node`（A3 焦点环）
##
## [b]为何需要独立文件[/b]：`test_node_graph_render.gd`（S16-3）验证渲染与六态，
## 不涉及交互组件；`test_node_move_interaction.gd`（S17-005）以组件为宿主、不经
## 屏幕。屏幕层的转发是两者之间的缝隙——H3 指出的正是这段无覆盖。
##
## 来源: story-005-node-move-interaction.md AC-1/AC-9、S17-005 代码审查 H1/H3。

const NodeGraphScreenScene: PackedScene = preload("res://src/ui/exploration/node_graph_screen.tscn")
const DATA_STUB := preload("res://src/ui/exploration/node_graph_data_stub.gd")
const MockSystem := preload("res://tests/integration/exploration_ui/mocks/mock_exploration_system.gd")

var screen: Control = null
var mock: Node = null


func before_each() -> void:
	mock = MockSystem.new()
	add_child_autofree(mock)
	screen = NodeGraphScreenScene.instantiate()
	screen.animate = false
	# 注入必须在 add_child 之前——_ready 读取 exploration_system 建立交互组件
	screen.exploration_system = mock
	add_child_autofree(screen)
	screen._on_map_generated(&"qing_yun_jian_zong", DATA_STUB.stub_snapshot())
	# 关闭动画（reduce_motion 直跳终位）——到达通知在移动完成时同步转发，
	# 避免 Tween 挂起导致断言时机不确定（test_node_move_interaction 先例）。
	_interactor().set_reduce_motion(true)


## 屏幕下的交互组件（生产路径中的子节点名）。
func _interactor() -> Node:
	return screen.get_node_or_null(NodePath("NodeMoveInteractor"))


## 屏幕下的弹窗宿主（S17-006 挂载点）。
func _popup_host() -> Node:
	return screen.get_node_or_null(NodePath("NodeInteractionPopupHost"))


# ═══════════════════════════════════════════════════════════════════════════════
# H3：到达通知 —— 屏幕层公开信号
# ═══════════════════════════════════════════════════════════════════════════════

func test_interactor_mounted_on_screen() -> void:
	# 前置契约：交互组件由屏幕挂载（H3 转发的前提）
	assert_not_null(_interactor(), "屏幕 _ready 应挂载 NodeMoveInteractor")


func test_screen_forwards_combat_arrival() -> void:
	# Given: 战斗节点到达（mock 自动发射 combat_node_reached）
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	var received: Array = []
	screen.combat_arrival_forwarded.connect(
			func(roster: Array, ctype: StringName) -> void: received.append(ctype))
	# When: 经交互组件提交移动
	_interactor().request_move(101)
	# Then: 屏幕层公开信号转发（006 消费点无需触碰私有成员）
	assert_eq(received.size(), 1, "屏幕应转发战斗到达通知恰好一次")
	assert_eq(received[0], &"combat", "战斗类型应透传")


func test_screen_forwards_boss_arrival() -> void:
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	mock.arrival_signal = &"boss_node_reached"
	var received: Array = []
	screen.boss_arrival_forwarded.connect(func(data: Dictionary) -> void: received.append(data))
	_interactor().request_move(500)
	assert_eq(received.size(), 1, "屏幕应转发 Boss 到达通知恰好一次")


func test_screen_forwards_node_interaction() -> void:
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	mock.arrival_signal = &"node_interaction_triggered"
	var received: Array = []
	screen.node_interaction_forwarded.connect(
			func(node_id: int, itype: StringName, _payload: Dictionary) -> void:
				received.append([node_id, itype]))
	_interactor().request_move(201)
	assert_eq(received.size(), 1, "屏幕应转发交互节点到达恰好一次")
	assert_eq(received[0][0], 201, "节点 ID 应透传")
	assert_eq(received[0][1], &"shop", "交互类型应透传")


# ═══════════════════════════════════════════════════════════════════════════════
# H1：移动失败反馈 —— 延后接线的公开入口
# ═══════════════════════════════════════════════════════════════════════════════

func test_screen_forwards_move_feedback() -> void:
	# Given: 系统返回失败
	mock.move_result = {"success": false, "reason": "行动力不足", "ap_remaining": 0}
	var received: Array = []
	screen.move_feedback_forwarded.connect(
			func(toast: String, node_id: int) -> void: received.append([toast, node_id]))
	# When: 点击（提交后被系统拒绝）
	_interactor().request_move(101)
	# Then: 屏幕层公开 toast 文案——HUD 通知区域接线后由此消费
	assert_eq(received.size(), 1, "屏幕应转发一次移动失败反馈")
	assert_eq(received[0][0], "行动力不足", "toast 文案应透传")
	assert_eq(received[0][1], 101, "抖动目标节点应透传")


# ═══════════════════════════════════════════════════════════════════════════════
# A3：键盘焦点 —— 屏幕转发到渲染器焦点环
# ═══════════════════════════════════════════════════════════════════════════════

func test_screen_forwards_keyboard_focus_to_renderer() -> void:
	# When: 方向键跳转（交互组件选定候选）
	var target: int = _interactor().navigate_focus(Vector2i(0, 1))
	# Then: 渲染器焦点节点同步（焦点环绘制输入）
	assert_true(target > 0, "↓ 应找到下一层可达节点")
	assert_eq(screen.renderer().focused_node, target,
			"屏幕应把键盘焦点转发给渲染器（松石青焦点环）")


func test_map_generated_clears_stale_focus() -> void:
	# 换图时上一张的键盘焦点不得残留
	screen.renderer().set_focused_node(101)
	screen._on_map_generated(&"another_map", DATA_STUB.stub_snapshot())
	assert_eq(screen.renderer().focused_node, -1, "新地图应清除上一张的键盘焦点")


# ═══════════════════════════════════════════════════════════════════════════════
# S17-006：弹窗宿主挂载与接线（屏幕层是唯一装配点）
# ═══════════════════════════════════════════════════════════════════════════════

func test_popup_host_mounted_on_screen() -> void:
	# 弹窗宿主由屏幕挂载（消费屏幕层的到达转发信号）
	assert_not_null(_popup_host(), "屏幕 _ready 应挂载 NodeInteractionPopupHost")


func test_screen_routes_shop_interaction_to_popup_host() -> void:
	# Given: 商店节点到达（mock 发 node_interaction_triggered）
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	mock.arrival_signal = &"node_interaction_triggered"
	# When: 经交互组件提交移动
	_interactor().request_move(201)
	# Then: 弹窗宿主已按分发表打开商店弹窗
	assert_true(_popup_host().is_popup_open(), "屏幕应把商店到达路由到弹窗宿主")
	assert_eq(_popup_host().get_open_kind(), &"shop", "弹窗种类应为商店")


func test_screen_routes_combat_arrival_to_popup_host() -> void:
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	var roster: Array = [{"name": "竹林剑客", "realm": 1}]
	_interactor().combat_arrival_forwarded.emit(roster, &"combat")
	assert_eq(_popup_host().get_open_kind(), &"combat", "战斗到达应打开战斗弹窗")


func test_event_node_arrival_does_not_open_popup() -> void:
	# AC-9 回归：事件节点走 event_node_reached（EventSystem 接管）——
	# 屏幕层不得把它路由成探索 UI 弹窗（防双面板）
	mock.event_node_reached.emit([], 1)
	assert_false(_popup_host().is_popup_open(), "事件节点不得触发探索 UI 弹窗")


func test_popup_open_freezes_keyboard_path_and_close_restores() -> void:
	# 弹窗期间键盘移动路径冻结（鼠标/缩放平移由视口 input_frozen 冻结）
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	mock.arrival_signal = &"node_interaction_triggered"
	_interactor().request_move(201)
	assert_false(_interactor().is_processing_unhandled_key_input(),
			"弹窗期间交互组件不应处理未处理键输入")
	_popup_host().close_popup()
	assert_true(_interactor().is_processing_unhandled_key_input(),
			"关闭弹窗后键盘路径应恢复")


func test_map_generated_pushes_snapshot_to_popup_host() -> void:
	# 渡劫台 AC-7 判定源：屏幕层把渲染快照下发弹窗宿主
	var snapshot: Dictionary = DATA_STUB.stub_snapshot()
	screen._on_map_generated(&"qing_yun_jian_zong", snapshot)
	assert_eq((_popup_host()._snapshot["nodes"] as Dictionary).size(),
			snapshot["nodes"].size(), "快照应下发到弹窗宿主（渡劫判定与锚定坐标源）")


func test_node_moved_pushes_updated_snapshot_to_popup_host() -> void:
	# 移动后 current_node 必须随之下发——否则战斗弹窗会锚在出发节点
	# （LP 审查：on_combat_arrival 用 _snapshot.current_node 定位）。
	assert_eq(int(_popup_host()._snapshot.get("current_node", -1)), 0,
			"前置：初始快照当前节点为入口")
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	_interactor().request_move(101)
	assert_eq(int(_popup_host()._snapshot.get("current_node", -1)), 101,
			"移动完成后宿主快照的当前节点应为到达节点（弹窗锚定坐标正确）")
	assert_eq(int(_popup_host()._snapshot.get("ap_remaining", -1)), 2,
			"行动力应同步为系统返回值")
