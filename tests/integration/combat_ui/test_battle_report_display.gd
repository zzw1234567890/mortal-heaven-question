extends GutTest
## 缺口三（可玩性收尾）集成测试：结算屏的「战报」区。
##
## [b]覆盖[/b]：本场回合数 / 我方剩余 HP 逐人 / 造成伤害 / 击杀数——四项从既有
## 战绩记录（[code]CombatBattleRecord.build[/code][b]新增的两个字段[/b]）一路读到
## 结算屏上的「【战报】」区块。[br]
## [br][b]为什么单独一个文件[/b]：[code]test_combat_result_bridge.gd[/code] 锁的
## 是「回流链路 + 占位契约」，本文件锁的是「战报这四项真的显示出来了」。[br]
## [br][b]断言口径[/b]：读结算屏上的控件文本与节点存在性——不靠信号回调。[br]
##
## 来源: 本轮任务书缺口三、ADR-0031 §2。

const BridgeScript := preload("res://src/ui/combat/shared/combat_result_bridge.gd")
const ViewScript := preload("res://src/feature/combat/combat_result_view.gd")

const RESULT_SCREEN: String = "res://src/ui/result_screen/result_screen.tscn"
const DEFEAT_SCREEN: String = "res://src/ui/defeat_screen/defeat_screen.tscn"

## 桩战斗系统——只有信号。
class CombatStub extends Node:
	signal battle_ended(result: int, rewards: Dictionary)


## 桩场景管理器——记录导航请求。
class SceneManagerStub extends Node:
	func get_current_scene_id() -> int:
		return 8

	func request_scene_change(_from: int, _to: int, _type: int) -> bool:
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


## 一份带战报字段的战绩载荷（[code]CombatBattleRecord.build[/code] 的等价形态）。
func _rewards_with_report(damage: int, kills: int) -> Dictionary:
	return {
		"result": 1,
		"record": {
			"result": 1,
			"outcome": "victory",
			"turn_count": 6,
			"effect_entries": 9,
			"player": {"count": 2, "alive_count": 2, "remaining_hp": 18,
					"unknown_count": 0, "roster": [
						{"character_id": 11, "current_hp": 12, "max_hp": 20,
								"is_alive": true, "known": true},
						{"character_id": 12, "current_hp": 6, "max_hp": 15,
								"is_alive": true, "known": true},
					]},
			"enemy": {"count": 1, "alive_count": 0, "remaining_hp": 0,
					"unknown_count": 0, "roster": []},
			"damage_dealt": {"player": damage, "enemy": 7},
			"kills": {"player": kills, "enemy": 0},
		},
	}


## 实例化结算屏并进树。
func _mount(path: String) -> Control:
	var packed: PackedScene = load(path)
	var screen: Control = packed.instantiate() as Control
	screen.set("scene_manager", sm)
	add_child_autofree(screen)
	return screen


## 取战报正文（无区块时返回空串——便于断言「没建」）。
func _report_text(screen: Control) -> String:
	var label: Variant = screen.get("report_label")
	return "" if label == null else (label as Label).text


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 战报区真的建出来了，四项内容都在
# ═══════════════════════════════════════════════════════════════════════════════

## 胜利结算屏：标题 + 回合数 + 我方逐人 HP + 伤害 + 击杀，逐项读得到。
func test_settlement_screen_shows_battle_report_block() -> void:
	# Arrange
	bridge.call(&"bind", combat)
	combat.battle_ended.emit(1, _rewards_with_report(41, 2))
	# Act
	var screen: Control = _mount(RESULT_SCREEN)
	# Assert —— 区块标题
	var title: Label = screen.get("report_title_label") as Label
	assert_not_null(title, "结算屏应建出「战报」区块标题")
	assert_eq(title.text, "【战报】", "区块标题文案")
	# Assert —— 正文四项
	var report: String = _report_text(screen)
	assert_true(report.contains("本场回合数: 6"), "战报应含本场回合数，实际：%s" % report)
	assert_true(report.contains("角色 #11: 12/20"),
			"战报应逐人列出我方剩余 HP，实际：%s" % report)
	assert_true(report.contains("角色 #12: 6/15"), "第二个我方角色也要列出")
	assert_true(report.contains("我方造成伤害: 41（击杀 2）"),
			"战报应含我方造成伤害与击杀数，实际：%s" % report)
	assert_true(report.contains("敌方造成伤害: 7（击杀 0）"),
			"战报也应含敌方那一段，实际：%s" % report)


## 战败屏同样有战报（两个场景共用口径，不是只给胜利开小灶）。
func test_defeat_screen_also_shows_battle_report() -> void:
	# Arrange
	bridge.call(&"bind", combat)
	combat.battle_ended.emit(1, _rewards_with_report(23, 1))
	# Act
	var screen: Control = _mount(DEFEAT_SCREEN)
	# Assert
	assert_not_null(screen.get("report_label"), "战败屏也应建出战报正文")
	assert_true(_report_text(screen).contains("我方造成伤害: 23（击杀 1）"),
			"战败屏战报的伤害与击杀应与记录一致")


## 战报排在返回按钮之前——阅读顺序与焦点顺序一致。
func test_battle_report_is_before_return_button() -> void:
	# Arrange
	bridge.call(&"bind", combat)
	combat.battle_ended.emit(1, _rewards_with_report(10, 1))
	# Act
	var screen: Control = _mount(RESULT_SCREEN)
	# Assert
	var report: Label = screen.get("report_label") as Label
	var button: Button = screen.get("return_button") as Button
	assert_not_null(report, "战报正文应存在")
	assert_lt(report.get_index(), button.get_index(), "战报应排在返回按钮之前")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 降级：没有战绩数据时不建区块（不显示一排 0）
# ═══════════════════════════════════════════════════════════════════════════════

## 直接跳进结算屏（无战绩）：战报区整体不建，占位契约照旧。
func test_no_record_builds_no_report_block() -> void:
	# Act
	var screen: Control = _mount(RESULT_SCREEN)
	# Assert
	assert_null(screen.get("report_title_label"), "无战绩时不建战报标题")
	assert_null(screen.get("report_label"), "无战绩时不建战报正文")
	assert_eq((screen.get("status_label") as Label).text, "本场无战绩数据",
			"状态行仍应明确告知无战绩")


## 旧载荷（record 里没有 damage_dealt / kills）：不崩，伤害与击杀按 0 显示。
func test_legacy_record_without_report_fields_degrades_to_zero() -> void:
	# Arrange —— 只有老字段的 record
	bridge.call(&"bind", combat)
	combat.battle_ended.emit(1, {
		"result": 1,
		"record": {
			"result": 1, "outcome": "victory", "turn_count": 2,
			"effect_entries": 1,
			"player": {"count": 1, "alive_count": 1, "remaining_hp": 5,
					"unknown_count": 0, "roster": []},
			"enemy": {"count": 0, "alive_count": 0, "remaining_hp": 0,
					"unknown_count": 0, "roster": []},
		},
	})
	# Act
	var screen: Control = _mount(RESULT_SCREEN)
	# Assert
	var report: String = _report_text(screen)
	assert_true(report.contains("本场回合数: 2"), "老载荷仍应有回合数")
	assert_true(report.contains("我方造成伤害: 0（击杀 0）"),
			"缺字段按 0 显示而不是崩溃，实际：%s" % report)


## 我方名册里读不到 HP 的角色：标「状态未知」，不编造数字。
func test_unknown_roster_entry_is_labeled_not_fabricated() -> void:
	# Arrange —— roster 一条 known=false
	bridge.call(&"bind", combat)
	combat.battle_ended.emit(1, {
		"result": 1,
		"record": {
			"result": 1, "outcome": "victory", "turn_count": 3,
			"effect_entries": 2,
			"player": {"count": 1, "alive_count": 0, "remaining_hp": 0,
					"unknown_count": 1, "roster": [
						{"character_id": 77, "current_hp": 0, "max_hp": 0,
								"is_alive": false, "known": false}]},
			"enemy": {"count": 0, "alive_count": 0, "remaining_hp": 0,
					"unknown_count": 0, "roster": []},
			"damage_dealt": {"player": 3, "enemy": 0},
			"kills": {"player": 0, "enemy": 0},
		},
	})
	# Act
	var screen: Control = _mount(RESULT_SCREEN)
	# Assert
	var report: String = _report_text(screen)
	assert_true(report.contains("角色 #77: 状态未知"),
			"读不到 HP 的角色应标「状态未知」，实际：%s" % report)
	assert_false(report.contains("角色 #77: 0/0"), "不得把 0/0 冒充成真实血量")


## 阵亡的我方角色：血旁边标「已阵亡」——战报也要看得出谁没了。
func test_defeated_roster_entry_is_marked() -> void:
	# Arrange
	bridge.call(&"bind", combat)
	combat.battle_ended.emit(2, {
		"result": 2,
		"record": {
			"result": 2, "outcome": "defeat", "turn_count": 4,
			"effect_entries": 3,
			"player": {"count": 1, "alive_count": 0, "remaining_hp": 0,
					"unknown_count": 0, "roster": [
						{"character_id": 5, "current_hp": 0, "max_hp": 30,
								"is_alive": false, "known": true}]},
			"enemy": {"count": 1, "alive_count": 1, "remaining_hp": 9,
					"unknown_count": 0, "roster": []},
			"damage_dealt": {"player": 11, "enemy": 30},
			"kills": {"player": 0, "enemy": 1},
		},
	})
	# Act
	var screen: Control = _mount(DEFEAT_SCREEN)
	# Assert
	var report: String = _report_text(screen)
	assert_true(report.contains("角色 #5: 0/30（已阵亡）"),
			"阵亡角色应标出「已阵亡」，实际：%s" % report)
	assert_true(report.contains("敌方造成伤害: 30（击杀 1）"),
			"击杀记在击杀者头上（我方被打死 1 人 → 敌方击杀 1）")
