extends GutTest
## 结算 / 战败屏的两条玩家视角回归（真机试玩走查修复）。[br]
## [br][b]背景一（焦点）[/b]：占位场景 [code]placeholder_scene.gd[/code] 的
## [method _build] 里没有一处 [code]grab_focus[/code]——整屏的焦点停在
## [code]none[/code]。键盘玩家打完一场仗进结算屏，Tab 之前按回车什么都不发生，
## 唯一的出路是用鼠标点「返回」。真机试玩走查在 [code]result[/code] 一步上复现
## （结构化记录里 [code]focus=none[/code]）。[br]
## [br][b]背景二（文案）[/b]：[code]summary_lines()[/code] 的首行曾是
## 「结局: 战斗胜利 (result=1)」——这一份文案直接进玩家可见的摘要标签，那个
## [code]result=[/code] 是开发者字段，玩家读不懂（结算屏截图实拍）。[br]
## [br][b]装置[/b]：真实 [code]result_screen.tscn[/code] / [code]defeat_screen.tscn[/code]
## + 记录型 SceneManager 桩（同 [code]test_combat_result_bridge.gd[/code] 口径）。
##
## 来源: .claude/rules/ui-code.md（双输入）、ADR-0031 §2、
## production/qa/evidence（真机试玩走查）。

const ViewScript := preload("res://src/feature/combat/combat_result_view.gd")
const BridgeScript := preload("res://src/ui/combat/shared/combat_result_bridge.gd")
const CombatScript := preload("res://src/feature/combat_system.gd")

const RESULT_SCREEN: String = "res://src/ui/result_screen/result_screen.tscn"
const DEFEAT_SCREEN: String = "res://src/ui/defeat_screen/defeat_screen.tscn"


## 桩战斗系统——只有信号。
class CombatStub:
	extends Node
	signal battle_ended(result: int, rewards: Dictionary)


## 桩场景管理器——记录导航请求（本组用例不触发真实转场）。
class SceneManagerStub:
	extends Node

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


## 一份可读的战绩载荷（[code]CombatBattleRecord.build[/code] 的等价形态）。
func _rewards(outcome: String, result: int, player_hp: int) -> Dictionary:
	return {
		"result": result,
		"record": {
			"result": result,
			"outcome": outcome,
			"turn_count": 4,
			"effect_entries": 2,
			"player": {"count": 1, "alive_count": 1, "remaining_hp": player_hp,
					"unknown_count": 0, "roster": []},
			"enemy": {"count": 1, "alive_count": 0, "remaining_hp": 0,
					"unknown_count": 0, "roster": []},
		},
	}


## 发布一份战绩并挂载占位场景。
func _mount_with(path: String, outcome: String, result: int) -> Control:
	bridge.call(&"bind", combat)
	combat.battle_ended.emit(result, _rewards(outcome, result, 7))
	var packed: PackedScene = load(path)
	var screen: Control = packed.instantiate() as Control
	screen.set("scene_manager", sm)
	add_child_autofree(screen)
	return screen


# ═══════════════════════════════════════════════════════════════════════════════
# 焦点：进屏即有可操作点
# ═══════════════════════════════════════════════════════════════════════════════

## 结算屏落地后返回按钮应有焦点——键盘玩家进屏就能按回车离开。[br]
## [br][b]修复前恒红[/b]：整屏焦点停在 [code]null[/code]。
func test_result_screen_grabs_focus_on_return_button() -> void:
	# Act
	var screen: Control = _mount_with(RESULT_SCREEN, "victory",
			CombatScript.CombatResult.VICTORY)
	await get_tree().process_frame
	# Assert
	var button: Button = screen.get("return_button") as Button
	assert_not_null(button, "结算屏应有返回按钮")
	assert_eq(get_viewport().gui_get_focus_owner(), button,
			"结算屏落地后焦点应在返回按钮上（键盘玩家无需先 Tab）")


## 战败屏同样落地即抓焦点（两个屏共用同一份基类，行为必须一致）。
func test_defeat_screen_grabs_focus_on_return_button() -> void:
	# Act
	var screen: Control = _mount_with(DEFEAT_SCREEN, "defeat",
			CombatScript.CombatResult.DEFEAT)
	await get_tree().process_frame
	# Assert
	var button: Button = screen.get("return_button") as Button
	assert_eq(get_viewport().gui_get_focus_owner(), button,
			"战败屏落地后焦点也应在返回按钮上")


## 焦点己被别处持有时不抢（视口已有焦点拥有者 → 本屏不越权）。[br]
## [br][b]为什么要有这条[/b]：抓焦点是无条件写全局状态的行为，加一条守卫防止
## 「弹窗正在接管输入时被结算屏抢走」这类越权。
func test_result_screen_does_not_steal_existing_focus() -> void:
	# Arrange——先给一个外部控件焦点
	var outsider := Button.new()
	add_child_autofree(outsider)
	outsider.grab_focus()
	# Act
	var screen: Control = _mount_with(RESULT_SCREEN, "victory",
			CombatScript.CombatResult.VICTORY)
	await get_tree().process_frame
	# Assert
	assert_eq(get_viewport().gui_get_focus_owner(), outsider,
			"已有焦点拥有者时结算屏不应抢走焦点")
	assert_not_null(screen.get("return_button"), "返回按钮仍应建出来")


# ═══════════════════════════════════════════════════════════════════════════════
# 文案：玩家可见摘要里不留开发者字段
# ═══════════════════════════════════════════════════════════════════════════════

## 摘要首行只有结局名——不得带 [code]result=[/code] 这种开发者字段。[br]
## [br][b]修复前恒红[/b]：首行是「结局: 战斗胜利 (result=1)」。
func test_summary_first_line_has_no_developer_field() -> void:
	# Arrange
	var view: RefCounted = ViewScript.from_battle_ended(
			CombatScript.CombatResult.VICTORY,
			_rewards("victory", CombatScript.CombatResult.VICTORY, 7))
	# Act
	var lines: PackedStringArray = view.call(&"summary_lines")
	# Assert
	assert_gt(lines.size(), 0, "摘要至少应有一行")
	assert_eq(lines[0], "结局: 战斗胜利", "首行应只有结局名")
	assert_false(lines[0].contains("result="), "首行不得含开发者字段 result=")


## 玩家可见的摘要整段不含 [code]result=[/code]（不止首行）。
func test_summary_never_leaks_result_field() -> void:
	# Arrange
	var view: RefCounted = ViewScript.from_battle_ended(
			CombatScript.CombatResult.DEFEAT,
			_rewards("defeat", CombatScript.CombatResult.DEFEAT, 0))
	# Act
	var joined: String = "\n".join(view.call(&"summary_lines"))
	# Assert
	assert_false(joined.contains("result="), "摘要整段不应出现开发者字段")


## 枚举值仍可从结算对象直读——去掉文案里的枚举不等于丢掉数据。[br]
## [br][b]为什么要有这条[/b]：证明上面的修复是「文案少打一个字段」，
## 而不是「把结局信息弄丢了」（[member result] 与 [method is_victory] 都还在）。
func test_result_enum_still_readable_off_the_view() -> void:
	# Arrange
	var view: RefCounted = ViewScript.from_battle_ended(
			CombatScript.CombatResult.VICTORY,
			_rewards("victory", CombatScript.CombatResult.VICTORY, 7))
	# Assert
	assert_eq(int(view.get("result")), CombatScript.CombatResult.VICTORY,
			"result 枚举应仍可从结算对象直读")
	assert_true(bool(view.call(&"is_victory")), "is_victory 仍应成立")
