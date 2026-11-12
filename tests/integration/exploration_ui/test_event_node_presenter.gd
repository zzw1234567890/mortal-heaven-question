extends GutTest
## 事件节点弹出通道验收——EventNodePresenter + EventPanelScreen 的两段式流程。
##
## 用真实 ExplorationSystem Autoload 的 event_node_reached 信号驱动：
## 收到信号 → 弹出面板（标题/正文/选项齐备）→ 点选项 → 结算并切成结果段。
## 结算依赖走真实 Autoload，因此断言落在「面板文案 + last_result」上。

const PresenterScript := preload("res://src/ui/exploration/event_node_presenter.gd")
const PanelScript := preload("res://src/ui/event_panel/event_panel_screen.gd")

var _host: Control = null
var _presenter: RefCounted = null
var _exploration: Node = null


func before_each() -> void:
	_host = Control.new()
	_host.name = "FakeNodeGraphScreen"
	add_child_autofree(_host)
	_exploration = get_node_or_null(NodePath("/root/ExplorationSystem"))
	_presenter = PresenterScript.new()


func after_each() -> void:
	if _exploration != null and _presenter != null:
		var handler := Callable(_presenter, &"_on_event_node_reached")
		if _exploration.is_connected(&"event_node_reached", handler):
			_exploration.disconnect(&"event_node_reached", handler)


# === 接线 =====================================================================

func test_attach_loads_event_registry() -> void:
	assert_not_null(_exploration, "ExplorationSystem 应为 Autoload")
	_presenter.call(&"attach", _exploration, _host)
	assert_gt(int(_presenter.call(&"event_count")), 0, "事件表应已加载")


func test_signal_opens_panel_with_event_content() -> void:
	_presenter.call(&"attach", _exploration, _host)
	_exploration.emit_signal(&"event_node_reached", [], 1)
	var panel: Variant = _host.get_node_or_null(NodePath("EventPanel"))
	assert_not_null(panel, "收到事件信号应弹出面板")
	assert_false(str(panel.call(&"displayed_event_id")).is_empty(),
			"面板应绑定事件 id")
	var title: Node = panel.find_child("TitleLabel", true, false)
	assert_not_null(title, "面板应有标题标签")
	assert_false(str((title as Label).text).is_empty(), "标题不应为空")


func test_choosing_option_settles_and_shows_result() -> void:
	_presenter.call(&"attach", _exploration, _host)
	_exploration.emit_signal(&"event_node_reached", [], 1)
	var panel: Variant = _host.get_node_or_null(NodePath("EventPanel"))
	assert_not_null(panel)
	assert_gt(int(panel.call(&"option_count")), 0, "应有可点选项")
	panel.call(&"press_option", 0)
	var result: Dictionary = _presenter.call(&"last_result")
	assert_true(bool(result.get("ok")), "选项应结算成功")
	assert_false(str(result.get("result_text")).is_empty(), "应带回结果文案")
	# 结果段：只剩「离开」一个按钮。
	var option_box: Node = panel.find_child("OptionBox", true, false)
	assert_not_null(option_box)
	assert_eq(option_box.get_child_count(), 1, "结果段只留离开按钮")
	assert_eq(str((option_box.get_child(0) as Button).name), "LeaveButton")


func test_no_panel_before_signal() -> void:
	_presenter.call(&"attach", _exploration, _host)
	assert_null(_host.get_node_or_null(NodePath("EventPanel")),
			"信号未到时不应有面板")
	assert_false(bool(_presenter.call(&"is_panel_open")))


# === 面板本身 ==================================================================

func test_panel_present_renders_options() -> void:
	var panel: Control = PanelScript.new()
	add_child_autofree(panel)
	var def: Variant = _first_event()
	assert_not_null(def)
	panel.call(&"present", def)
	var options: Array = def.get(&"options")
	assert_eq(panel.call(&"option_count"), options.size(),
			"选项按钮数应与资源一致")
	assert_eq(str(panel.call(&"displayed_event_id")), str(def.get(&"event_id")))


func test_panel_option_signal_carries_index() -> void:
	var panel: Control = PanelScript.new()
	add_child_autofree(panel)
	panel.call(&"present", _first_event())
	watch_signals(panel)
	panel.call(&"press_option", 1)
	assert_signal_emitted_with_parameters(panel, &"option_chosen",
			[panel.call(&"displayed_event_id"), 1])


func _first_event() -> Variant:
	var system := preload("res://src/feature/exploration_event_system.gd").new()
	system.call(&"load_events")
	var ids: Array = system.call(&"event_ids")
	ids.sort()
	if ids.is_empty():
		return null
	return system.call(&"get_event", String(ids[0]))
