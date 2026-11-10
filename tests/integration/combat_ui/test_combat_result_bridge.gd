extends GutTest
## Sprint 18 集成测试：战斗战绩回流到结算场景（[code]combat_result_bridge.gd[/code]
## + [code]CombatResultView[/code] + 结算/战败占位场景）。[br]
## [br][b]链路[/b]：战斗系统 [code]battle_ended[/code] → 接线把载荷折成结算对象并发布
## → 转场后结算场景 [method CombatResultView.last] 读回并展示。[br]
## [br][b]本文件锁定五条[/b]：[br]
##   1. 接线订阅后，[code]battle_ended[/code] 能发布一份可读结算对象；[br]
##   2. 胜负两向都能被结算场景读到（标题 / 剩余 HP / 回合数）；[br]
##   3. 没有战绩数据时场景不崩，状态行明确写「本场无战绩数据」；[br]
##   4. 换源 / 退订后不再发布（战斗容器释放后不能继续往缓存写本场数据）；[br]
##   5. 结算场景的占位契约（标题 / 状态 / 返回按钮 / 返回探索）不因接入战绩而失效。[br]
## [br][b]桩**：战斗系统用 [code]Node[/code] 桩（只需 [code]battle_ended[/code] 信号），
## SceneManager 用记录型桩——不触发真实转场。

const BridgeScript := preload("res://src/ui/combat/shared/combat_result_bridge.gd")
const ViewScript := preload("res://src/feature/combat/combat_result_view.gd")

const RESULT_SCREEN: String = "res://src/ui/result_screen/result_screen.tscn"
const DEFEAT_SCREEN: String = "res://src/ui/defeat_screen/defeat_screen.tscn"

## 桩战斗系统——只有信号，接线侧不关心别的。
class CombatStub extends Node:
	signal battle_ended(result: int, rewards: Dictionary)


## 桩场景管理器——记录导航请求。
class SceneManagerStub extends Node:
	var requests: Array = []
	var current_id: int = 8

	func get_current_scene_id() -> int:
		return current_id

	func request_scene_change(from: int, to: int, type: int) -> bool:
		requests.append({"from": from, "to": to, "type": type})
		return true


var combat: CombatStub = null
var bridge: RefCounted = null
var sm: SceneManagerStub = null


func before_each() -> void:
	combat = CombatStub.new()
	add_child_autofree(combat)
	bridge = BridgeScript.new()
	sm = SceneManagerStub.new()
	add_child_autofree(sm)
	ViewScript.clear()


func after_each() -> void:
	if bridge != null:
		bridge.call(&"unbind")
	bridge = null
	ViewScript.clear()


## 一份完整战绩载荷（[code]CombatBattleRecord.build[/code] 的等价形态）。
func _rewards(outcome: String, result: int, player_hp: int, enemy_hp: int,
		turn: int = 3, entries: int = 5) -> Dictionary:
	return {
		"result": result,
		"record": {
			"result": result,
			"outcome": outcome,
			"turn_count": turn,
			"effect_entries": entries,
			"player": {"count": 1, "alive_count": 1 if player_hp > 0 else 0,
					"remaining_hp": player_hp, "unknown_count": 0, "roster": []},
			"enemy": {"count": 1, "alive_count": 1 if enemy_hp > 0 else 0,
					"remaining_hp": enemy_hp, "unknown_count": 0, "roster": []},
		},
	}


## 实例化占位场景并进树（注入桩 SceneManager）。
func _mount(path: String) -> Control:
	var packed: PackedScene = load(path)
	var screen: Control = packed.instantiate() as Control
	screen.set("scene_manager", sm)
	add_child_autofree(screen)
	return screen


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 接线发布
# ═══════════════════════════════════════════════════════════════════════════════

func test_battle_ended_publishes_result_view() -> void:
	# Arrange
	bridge.call(&"bind", combat)
	# Act
	combat.battle_ended.emit(1, _rewards("victory", 1, 7, 0))
	# Assert
	var view: RefCounted = ViewScript.last()
	assert_not_null(view, "battle_ended 应发布结算对象")
	assert_eq(String(view.get("outcome")), "victory", "outcome 应折为 victory")
	assert_eq(int(view.call(&"player_remaining_hp")), 7, "我方剩余 HP 应为 7")
	assert_true(bool(view.get("has_record")), "应标记为有战绩数据")


## 旧载荷（只有 result，没有 record）→ 不崩、标记无战绩。
func test_payload_without_record_degrades() -> void:
	# Arrange
	bridge.call(&"bind", combat)
	# Act
	combat.battle_ended.emit(2, {"result": 2})
	# Assert
	var view: RefCounted = ViewScript.last()
	assert_not_null(view, "仍应发布一份结算对象")
	assert_false(bool(view.get("has_record")), "has_record=false")
	assert_eq(String(view.get("outcome")), "defeat", "outcome 由 result 推导")
	assert_eq(int(view.call(&"player_remaining_hp")), 0, "缺字段取默认 0，不臆造")


func test_unbind_stops_publishing() -> void:
	# Arrange——先发布一次，再退订
	bridge.call(&"bind", combat)
	combat.battle_ended.emit(1, _rewards("victory", 1, 5, 0))
	var first: RefCounted = ViewScript.last()
	# Act——退订后再发一次
	bridge.call(&"unbind")
	combat.battle_ended.emit(2, _rewards("defeat", 2, 0, 3))
	# Assert——缓存仍是第一份（第二份没有被发布）
	assert_eq(ViewScript.last(), first, "退订后不应再发布")


func test_rebind_swaps_source() -> void:
	# Arrange——接到 A 并发布一次
	bridge.call(&"bind", combat)
	combat.battle_ended.emit(1, _rewards("victory", 1, 9, 0))
	# Act——换到另一个源
	var other: CombatStub = CombatStub.new()
	add_child_autofree(other)
	bridge.call(&"bind", other)
	combat.battle_ended.emit(2, _rewards("defeat", 2, 0, 1))  # 旧源不应再生效
	var after_old: RefCounted = ViewScript.last()
	other.battle_ended.emit(1, _rewards("victory", 1, 4, 0))  # 新源生效
	# Assert
	assert_eq(int(after_old.call(&"player_remaining_hp")), 9, "旧源已被断开")
	assert_eq(int(ViewScript.last().call(&"player_remaining_hp")), 4, "新源应接管发布")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 结算场景读到胜负两向
# ═══════════════════════════════════════════════════════════════════════════════

func test_result_screen_shows_victory_record() -> void:
	# Arrange——先发布胜利战绩，再转场进场景
	bridge.call(&"bind", combat)
	combat.battle_ended.emit(1, _rewards("victory", 1, 12, 0, 4, 8))
	# Act
	var screen: Control = _mount(RESULT_SCREEN)
	# Assert
	var title: Label = screen.get("title_label") as Label
	assert_eq(title.text, "战斗胜利", "标题应取战绩结局")
	assert_not_null(screen.get("brief_label"), "应展示战绩摘要")
	var brief: String = (screen.get("brief_label") as Label).text
	assert_true(brief.contains("回合数: 4"), "摘要应含回合数")
	assert_true(brief.contains("触发效果条目: 8"), "摘要应含效果条目数")
	assert_true(brief.contains("剩余 HP 12"), "摘要应含我方剩余 HP")


func test_defeat_screen_shows_defeat_record() -> void:
	# Arrange
	bridge.call(&"bind", combat)
	combat.battle_ended.emit(2, _rewards("defeat", 2, 0, 16, 2, 3))
	# Act
	var screen: Control = _mount(DEFEAT_SCREEN)
	# Assert
	var title: Label = screen.get("title_label") as Label
	assert_eq(title.text, "战斗失败", "战败场景同样取战绩结局")
	var brief: String = (screen.get("brief_label") as Label).text
	assert_true(brief.contains("敌方: 存活 1/1，剩余 HP 16"), "摘要应含敌方剩余 HP")


## 没有战绩数据时：状态行明确告知，场景照常可用。
func test_screen_without_record_keeps_placeholder_contract() -> void:
	# Arrange——缓存为空（直接跳进场景）
	# Act
	var screen: Control = _mount(RESULT_SCREEN)
	# Assert
	assert_null(screen.get("brief_label"), "无数据时不建摘要")
	var status: Label = screen.get("status_label") as Label
	assert_eq(status.text, "本场无战绩数据", "状态行应明确告知无战绩")
	var title: Label = screen.get("title_label") as Label
	assert_eq(title.text, "战斗结算", "标题回退占位文案")
	assert_not_null(screen.get("return_button"), "返回按钮仍在")
	assert_eq((screen.get("return_button") as Button).text, "返回探索")


## 占位契约不回退：有战绩时标题/状态/返回按钮/导航照样成立。
func test_screen_keeps_navigation_with_record() -> void:
	# Arrange
	bridge.call(&"bind", combat)
	combat.battle_ended.emit(1, _rewards("victory", 1, 5, 0))
	sm.current_id = 8
	var screen: Control = _mount(RESULT_SCREEN)
	var button: Button = screen.get("return_button") as Button
	# Act
	button.emit_signal("pressed")
	# Assert
	var status: Label = screen.get("status_label") as Label
	assert_eq(status.text, "战绩已记录", "有战绩时状态行改为「已记录」")
	assert_eq(sm.requests.size(), 1, "返回仍应发出一次转场请求")
	assert_eq(int(sm.requests[0]["to"]), 3, "目标仍为 EXPLORATION")
	assert_eq(int(sm.requests[0]["type"]), 4, "转场类型仍为 COMBAT_TO_EXPLORE")


## 摘要排在返回按钮之前——键盘/手柄焦点先读数据再离开。
func test_brief_is_before_return_button() -> void:
	# Arrange
	bridge.call(&"bind", combat)
	combat.battle_ended.emit(1, _rewards("victory", 1, 5, 0))
	var screen: Control = _mount(RESULT_SCREEN)
	# Assert
	var brief: Label = screen.get("brief_label") as Label
	var button: Button = screen.get("return_button") as Button
	assert_lt(brief.get_index(), button.get_index(), "摘要应排在返回按钮之前")
