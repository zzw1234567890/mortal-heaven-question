extends GutTest
## Sprint 18 场景补链回归：占位场景（坊市/结算/战败/养成）。[br]
## 事件面板与[b]卡组编辑[/b]已交付真实脚本——两者的 .tscn 不再挂
## [code]PlaceholderScene[/code]，由文末专项测试锁定挂载（路径保留，
## SceneManager 自检不红）。
##
## [b]背景[/b]（gate-check 2026-11-08 §B1）：这些 SCENE_PATHS 注册路径此前无资产，
## 任何指向它们的转场都落到「目标场景缺失 → 回退 MAIN_MENU」。本文件验证：[br]
##   1. 每个占位场景都可实例化且标题/状态/返回按钮齐备；[br]
##   2. 「返回」经 SceneManager 发出该屏[b]目的地[/b]的请求（ADR-0005 唯一入口）。[br]
##
## [b]「返回」的目的地分两类（2026-11-17）[/b]：战败屏回[b]主菜单[/b]（本局已结束
## ——design/ux/pause-menu.md §Events Fired「玩家点击「返回」→ 回到主菜单」、
## design/gdd/audio-system.md §9 把「战败→任意非主菜单状态」列为 N/A 转换），
## 其余三屏（坊市 / 胜利结算 / 养成）回[b]探索[/b]（继续玩下去）。
## 判据收在 [code]battle_record_exit.gd[/code]，本文件按屏逐条钉住它的产出。
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


## 路径 → 期望 SceneID（仍为占位的场景 .tscn 的 screen_id 配置——
## event_panel.tscn / deck_editing.tscn 已换真实脚本，不在此表）。
const CASES: Dictionary = {
	"res://src/feature/shop/shop_scene.tscn": 6,
	"res://src/ui/result_screen/result_screen.tscn": 8,
	"res://src/ui/defeat_screen/defeat_screen.tscn": 9,
	"res://src/feature/cultivation/cultivation_scene.tscn": 10,
}

## SceneID → 本屏「返回」的期望（文案 / 目标 SceneID / 转场类型）。
## [br][b]逐屏写死而不是算出来[/b]：本文件是结算屏出口口径的回归网——若哪天有人把
## [code]BattleRecordExit[/code] 改成「所有屏都回主菜单」，期望值跟着实现一起变的
## 测试不会红。这里的字面值就是规格（design/ux/pause-menu.md §Events Fired、
## design/gdd/audio-system.md §9）。
const EXITS: Dictionary = {
	6: {"text": "返回探索", "to": 3, "type": 4},
	8: {"text": "返回探索", "to": 3, "type": 4},
	9: {"text": "返回主菜单", "to": 0, "type": 2},
	10: {"text": "返回探索", "to": 3, "type": 4},
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
		var screen_id: int = int(CASES[path])
		# Then: 标题非空 + 状态提示 + 可点返回按钮 + 本屏明确的去向文案
		var title: Label = screen.get("title_label") as Label
		var button: Button = screen.get("return_button") as Button
		assert_not_null(title, "%s 应有标题标签" % path)
		assert_true(title.text.length() > 0, "%s 标题不应为空" % path)
		assert_not_null(button, "%s 应有返回按钮" % path)
		assert_eq(button.text, str(EXITS[screen_id]["text"]),
				"%s 返回按钮文案应为「%s」" % [path, str(EXITS[screen_id]["text"])])
		assert_ne(button.text, "返回", "%s 不得只写含糊的「返回」" % path)
		screen.queue_free()


func test_placeholder_return_requests_its_own_destination() -> void:
	for path: String in CASES.keys():
		# Arrange: 假设玩家已在该场景（current_scene_id = 该场景 ID）
		sm.requests.clear()
		sm.current_id = int(CASES[path])
		var screen_id: int = int(CASES[path])
		var screen: Control = _mount(path)
		var button: Button = screen.get("return_button") as Button
		# Act
		button.emit_signal("pressed")
		# Assert: 一次请求，from=当前场景 ID，to / type 取本屏期望
		assert_eq(sm.requests.size(), 1, "%s 返回应发出一次转场请求" % path)
		assert_eq(int(sm.requests[0]["from"]), screen_id, "%s 的 from 应取当前场景 ID" % path)
		assert_eq(int(sm.requests[0]["to"]), int(EXITS[screen_id]["to"]),
				"%s 目标应为 %d" % [path, int(EXITS[screen_id]["to"])])
		assert_eq(int(sm.requests[0]["type"]), int(EXITS[screen_id]["type"]),
				"%s 转场类型应为 %d" % [path, int(EXITS[screen_id]["type"])])
		screen.queue_free()


func test_placeholder_scene_has_no_process_polling() -> void:
	## ADR-0031 §3 零轮询：占位场景不重写 _process。
	var script: Script = load("res://src/ui/shared/placeholder_scene.gd")
	var source: String = script.source_code
	assert_false(source.contains("func _process("), "占位场景不应有 _process()")


## 事件面板场景已换挂真实 EventPanelScreen（Sprint 18 事件节点走探索层
## overlay）——不再是占位场景；路径保留让 SceneManager 自检不红。
func test_event_panel_scene_mounts_real_screen_script() -> void:
	var packed: PackedScene = load("res://src/ui/event_panel/event_panel.tscn")
	var screen: Control = packed.instantiate() as Control
	add_child_autofree(screen)
	assert_not_null(screen, "event_panel.tscn 应可实例化")
	assert_eq(screen.get_script().resource_path,
			"res://src/ui/event_panel/event_panel_screen.gd",
			"事件面板场景应挂真实 EventPanelScreen 脚本")
	assert_false("screen_id" in screen, "真实脚本不应再暴露占位 screen_id")
	assert_true(screen.has_signal(&"option_chosen"),
			"真实脚本应声明 option_chosen 信号")


## 卡组编辑场景已换挂真实 DeckEditingScreen（本轮交付）——不再是占位场景。[br]
## [br][b]为什么单测一条[/b]：[code]SceneManager.SCENE_PATHS[/code] 里那条路径此前
## 指向占位骨架，玩家因此无处改卡组。这一个断言钉住「路径后面真的是编辑界面」——
## 若哪天有人把 .tscn 换回占位（或脚本路径写错），本用例红。
func test_deck_editing_scene_mounts_real_screen_script() -> void:
	var packed: PackedScene = load("res://src/ui/deck_editing/deck_editing.tscn")
	var screen: Control = packed.instantiate() as Control
	add_child_autofree(screen)
	assert_not_null(screen, "deck_editing.tscn 应可实例化")
	assert_eq(screen.get_script().resource_path,
			"res://src/ui/deck_editing/deck_editing_screen.gd",
			"卡组编辑场景应挂真实 DeckEditingScreen 脚本")
	assert_false("screen_id" in screen, "真实脚本不应再暴露占位 screen_id")
	assert_true(screen.has_method(&"refresh"), "真实脚本应具备刷新入口")
	# 两栏骨架应在挂载时就建好（不是运行时才懒加载）
	assert_true(screen.has_method(&"collection_count") and screen.has_method(&"deck_count"),
			"真实脚本应暴露两栏读数口")
