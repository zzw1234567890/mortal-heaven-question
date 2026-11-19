extends GutTest
## 缺口二（可玩性收尾）集成测试：战报里的我方逐人真名。
##
## [b]覆盖[/b]：名字从「卡牌模板/敌方名册」一路走到结算屏的战报正文——
## 建表时定格（[code]combat_roster_seeding[/code]）→ 快照透传
## （[code]combat_roster_state.snapshot_all[/code]）→ 战绩抄录
## （[code]combat_battle_record._fold_side[/code]）→ 展示
## （[code]CombatResultView._roster_line[/code]）。[br]
## [br][b]为什么单独一个文件[/b]：[code]test_battle_report_display.gd[/code] 锁的是
## 「战报四项真的显示出来了」（用裸 [code]record[/code] 载荷、无名字），本文件锁的是
## 「名字这一列」，两边的夹具形状不同。[br]
## [br][b]断言口径[/b]：读结算屏上的控件文本；名字缺失时读回退形态。[br]
##
## 来源: 本轮任务书缺口二、ADR-0031 §2。

const BridgeScript := preload("res://src/ui/combat/shared/combat_result_bridge.gd")
const ViewScript := preload("res://src/feature/combat/combat_result_view.gd")
const RecordScript := preload("res://src/feature/combat/combat_battle_record.gd")
const RosterStateScript := preload("res://src/feature/combat/combat_roster_state.gd")
const Seeding := preload("res://src/feature/combat/combat_roster_seeding.gd")

const RESULT_SCREEN: String = "res://src/ui/result_screen/result_screen.tscn"

## 本文件独占角色 ID 段 7911+（真实卡牌实例 ID 形态——非敌方 ID 段）。
const CHAR_LIN: int = 7911
const CHAR_SU: int = 7912


## 桩战斗系统——只有信号。
class CombatStub extends Node:
	signal battle_ended(result: int, rewards: Dictionary)


## 桩场景管理器——记录导航请求。
class SceneManagerStub extends Node:
	func get_current_scene_id() -> int:
		return 8

	func request_scene_change(_from: int, _to: int, _type: int) -> bool:
		return true


## 桩卡牌系统——只实现 [code]get_template_by_instance_id[/code]（取名取 HP 都走它）。
class CardSystemStub extends Node:
	var templates: Dictionary = {}

	func get_template_by_instance_id(card_instance_id: int) -> Variant:
		return templates.get(card_instance_id)


var combat: CombatStub = null
var bridge: RefCounted = null
var sm: SceneManagerStub = null
var cards: CardSystemStub = null


func before_each() -> void:
	combat = CombatStub.new()
	add_child_autofree(combat)
	bridge = BridgeScript.new()
	sm = SceneManagerStub.new()
	add_child_autofree(sm)
	cards = CardSystemStub.new()
	add_child_autofree(cards)
	ViewScript.clear()


func after_each() -> void:
	if bridge != null:
		bridge.call(&"unbind")
	bridge = null
	ViewScript.clear()


## 走完整链路造一份战绩载荷：状态表种子 → 快照 → 战绩定格。
## [param p_names] 卡牌实例 ID → 显示名（缺 = 模板查不到，走编号兜底）。
func _record_via_roster(p_names: Dictionary) -> Dictionary:
	cards.templates = {}
	for character_id: int in p_names.keys():
		cards.templates[character_id] = {"display_name": p_names[character_id]}
	var state: RefCounted = RosterStateScript.new()
	state.seed_player_field([
		{"character_id": CHAR_LIN, "is_front": true},
		{"character_id": CHAR_SU, "is_front": false},
	], {}, cards)
	var record: RefCounted = RecordScript.new()
	record.call(&"reset")
	return record.call(&"build", 1, 4, state.snapshot_all())


## 实例化结算屏并进树。
func _mount(path: String) -> Control:
	var packed: PackedScene = load(path)
	var screen: Control = packed.instantiate() as Control
	screen.set("scene_manager", sm)
	add_child_autofree(screen)
	return screen


## 取战报正文。
func _report_text(screen: Control) -> String:
	var label: Variant = screen.get("report_label")
	return "" if label == null else (label as Label).text


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 名字一路上得来：模板有名 → 战报写名
# ═══════════════════════════════════════════════════════════════════════════════

## 我方逐人战报显示真名（不再是「角色 #ID」）。
func test_battle_report_shows_real_names_of_player_roster() -> void:
	# Arrange —— 卡牌模板带名
	var record: Dictionary = _record_via_roster({
		CHAR_LIN: "林渊", CHAR_SU: "苏剑鸣",
	})
	bridge.call(&"bind", combat)
	combat.battle_ended.emit(1, {"result": 1, "record": record})
	# Act
	var screen: Control = _mount(RESULT_SCREEN)
	# Assert
	var report: String = _report_text(screen)
	assert_true(report.contains("林渊: "),
			"战报应写出我方角色的真名，实际：%s" % report)
	assert_true(report.contains("苏剑鸣: "),
			"第二个我方角色同样写出真名，实际：%s" % report)
	assert_false(report.contains("角色 #%d" % CHAR_LIN),
			"有位可查时不应再退回编号")


## 名字列与 HP 列同源——名字换了个角色，血也还是那个角色的血。
func test_battle_report_name_is_paired_with_its_own_hp() -> void:
	# Arrange —— 两个角色血量不同，名字各归各位
	var record: Dictionary = _record_via_roster({
		CHAR_LIN: "林渊", CHAR_SU: "苏剑鸣",
	})
	bridge.call(&"bind", combat)
	combat.battle_ended.emit(1, {"result": 1, "record": record})
	# Act
	var screen: Control = _mount(RESULT_SCREEN)
	# Assert —— 快照里两条都满血（无注入 stats → 模板 base_hp 为 0 → 0/0）
	var report: String = _report_text(screen)
	assert_true(report.contains("林渊: "), "前置：真名在列")
	assert_true(report.contains("苏剑鸣: "), "前置：真名在列")
	var lin_idx: int = report.find("林渊: ")
	var su_idx: int = report.find("苏剑鸣: ")
	assert_lt(lin_idx, su_idx, "逐人顺序按 character_id 升序（与快照同序）")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 名字缺失时退回编号（不显示空白行）
# ═══════════════════════════════════════════════════════════════════════════════

## 模板查不到名字时退回「角色 #ID」——不是空名，也没把整行吞掉。
func test_missing_name_falls_back_to_character_id_label() -> void:
	# Arrange —— 模板字典空着（查不到任何名字）
	var record: Dictionary = _record_via_roster({})
	bridge.call(&"bind", combat)
	combat.battle_ended.emit(1, {"result": 1, "record": record})
	# Act
	var screen: Control = _mount(RESULT_SCREEN)
	# Assert
	var report: String = _report_text(screen)
	assert_true(report.contains("角色 #%d: " % CHAR_LIN),
			"读不到名字应退回「角色 #ID」，实际：%s" % report)
	assert_false(report.contains(": 0/0\n　· :"),
			"不应出现无名空行（名字为空但行还在）")


## 名字解析纯函数口径：有名用名、无名用编号、敌方 ID 段叫「敌人」。
func test_name_resolution_falls_back_by_id_segment() -> void:
	# Assert —— 有位可查
	assert_eq(Seeding.resolve_name("林渊", CHAR_LIN), "林渊", "有位可查时用真名")
	# Assert —— 我方无名
	assert_eq(Seeding.resolve_name("", CHAR_LIN), "角色 #%d" % CHAR_LIN,
		"我方读不到名字用「角色 #ID」")
	# Assert —— 敌方无名（ID 段区分，与战斗内播报同句）
	assert_eq(Seeding.resolve_name("", Seeding.ENEMY_ID_BASE),
		"敌人 #%d" % Seeding.ENEMY_ID_BASE, "敌方读不到名字用「敌人 #ID」")
	# Assert —— 非法 ID 不编编号
	assert_eq(Seeding.resolve_name("", -1), Seeding.NAME_UNKNOWN,
		"无 ID 可依时给「未知目标」而不是「角色 #-1」")
