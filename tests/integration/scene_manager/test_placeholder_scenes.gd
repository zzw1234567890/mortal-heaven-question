extends GutTest
## Sprint 18 场景补链回归：占位场景（卡组编辑/坊市/事件/结算/战败/养成）。
##
## [b]背景[/b]（gate-check 2026-11-08 §B1）：这 6 条 SCENE_PATHS 注册路径此前无资产，
## 任何指向它们的转场都落到「目标场景缺失 → 回退 MAIN_MENU」。本文件验证：[br]
##   1. 每个占位场景都可实例化且标题/状态/返回按钮齐备；[br]
##   2. 「返回探索」经 SceneManager 发出 EXPLORATION 请求（ADR-0005 唯一入口）。
##
## SceneManager 以桩替代——不触发真实转场。

## 桩场景管理器——记录导航请求。
class SceneManagerStub extends Node:
	var requests: Array = []
	var current_id: int = 0

	func get_current_scene_id() -> int:
		return current_id

	func request_scene_change(from: int, to: int, type: int) -> bool:
		requests.append({"from": from, "to": to, "type": type})
		return true


## 路径 → 期望 SceneID（占位场景 .tscn 的 screen_id 配置）。
const CASES: Dictionary = {
	"res://src/ui/deck_editing/deck_editing.tscn": 2,
	"res://src/feature/shop/shop_scene.tscn": 6,
	"res://src/ui/event_panel/event_panel.tscn": 7,
	"res://src/ui/result_screen/result_screen.tscn": 8,
	"res://src/ui/defeat_screen/defeat_screen.tscn": 9,
	"res://src/feature/cultivation/cultivation_scene.tscn": 10,
}

var sm: SceneManagerStub = null


func before_each() -> void:
	sm = SceneManagerStub.new()
	add_child_autofree(sm)


func after_each() -> void:
	sm = null


## 实例化占位场景并注入桩 SceneManager（进树前注入——`_ready` 已构建界面）。
func _mount(path: String) -> Control:
	var packed: PackedScene = load(path)
	var screen: Control = packed.instantiate() as Control
	screen.set("scene_manager", sm)
	add_child_autofree(screen)
	return screen


func test_placeholder_scenes_instantiate_with_screen_id() -> void:
	for path: String in CASES.keys():
		var screen: Control = _mount(path)
		assert_not_null(screen, "%s 应可实例化" % path)
		assert_eq(int(screen.get("screen_id")), int(CASES[path]),
				"%s 的 screen_id 应为 %d" % [path, int(CASES[path])])
		screen.queue_free()


func test_placeholder_scene_has_title_status_and_return_button() -> void:
	for path: String in CASES.keys():
		var screen: Control = _mount(path)
		# Then: 标题非空 + 状态提示 + 可点返回按钮
		var title: Label = screen.get("title_label") as Label
		var button: Button = screen.get("return_button") as Button
		assert_not_null(title, "%s 应有标题标签" % path)
		assert_true(title.text.length() > 0, "%s 标题不应为空" % path)
		assert_not_null(button, "%s 应有返回按钮" % path)
		assert_eq(button.text, "返回探索", "%s 返回按钮文案应为「返回探索」" % path)
		screen.queue_free()


func test_placeholder_return_requests_exploration_via_scene_manager() -> void:
	for path: String in CASES.keys():
		# Arrange: 假设玩家已在该场景（current_scene_id = 该场景 ID）
		sm.requests.clear()
		sm.current_id = int(CASES[path])
		var screen: Control = _mount(path)
		var button: Button = screen.get("return_button") as Button
		# Act
		button.emit_signal("pressed")
		# Assert: 一次请求，from=当前场景 ID，to=EXPLORATION
		assert_eq(sm.requests.size(), 1, "%s 返回应发出一次转场请求" % path)
		assert_eq(int(sm.requests[0]["from"]), int(CASES[path]),
				"%s 的 from 应取当前场景 ID" % path)
		assert_eq(int(sm.requests[0]["to"]), 3, "%s 目标应为 EXPLORATION" % path)
		assert_eq(int(sm.requests[0]["type"]), 4,
				"%s 转场类型应为 COMBAT_TO_EXPLORE" % path)
		screen.queue_free()


func test_placeholder_scene_has_no_process_polling() -> void:
	## ADR-0031 §3 零轮询：占位场景不重写 _process。
	var script: Script = load("res://src/ui/shared/placeholder_scene.gd")
	var source: String = script.source_code
	assert_false(source.contains("func _process("), "占位场景不应有 _process()")
