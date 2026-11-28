extends GutTest
## 缺口一（可玩性收尾）集成测试：敌方单位在战场卡上看得见血。
##
## [b]覆盖[/b]：[code]ActorStageRoster[/code] 建卡 → 卡上 HP 数字/血条/名 → 受伤
## 后刷新 → 阵亡有独立视觉（灰化 + 「已阵亡」戳记）。[br]
## [br][b]为什么不驱动真实战斗[/b]：本轮验证的是「取数链路 + 卡面呈现」这两段——
## 名册条目由 stub 取数入口给出（形状与 [code]CombatActorReader[/code] 一致），
## 卡上读到的数字因此可以逐项对照。[br]
## [br][b]断言口径[/b]：读控件文本 / 属性 / 节点存在性——不靠信号回调，
## 玩家看到的确实是这些字符串与可见性。[br]
##
## 来源: 本轮任务书缺口一、ADR-0031 §2、design/gdd/ai-system.md §敌方信息栏。

const CardScript: GDScript = preload("res://src/ui/combat/layout/character_status_card.gd")
const RosterScript: GDScript = preload("res://src/ui/combat/layout/actor_stage_roster.gd")
const DefeatMarker: GDScript = preload("res://src/ui/combat/layout/combat_card_defeat_marker.gd")
const StubReader: GDScript = preload("res://tests/integration/combat_ui/mocks/stub_actor_reader.gd")

## 本文件独占角色 ID 段。
const ENEMY_A: int = 910001
const ENEMY_B: int = 910002
const ALLY_A: int = 910101

var container: Control = null
var reader: RefCounted = null
var roster: RefCounted = null


func before_each() -> void:
	container = Control.new()
	add_child_autofree(container)
	reader = StubReader.new()
	roster = RosterScript.new(reader)


## 建卡（走真实名册路径——建卡里就把 HP/ATK/名写进卡）。
func _build_enemy(character_id: int) -> Control:
	reader.hp_map[character_id] = {"current": 12, "max": 20}
	reader.name_map[character_id] = "黑风寨匪徒"
	reader.atk_map[character_id] = 7
	roster.build_side([{"character_id": character_id, "is_front": true}],
			container, roster.enemy_cards)
	return roster.get_card(character_id)


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 敌方卡上真的有 HP 数字与血条（数据只来自取数入口 → CombatRosterState）
# ═══════════════════════════════════════════════════════════════════════════════

## 敌方卡：数字 = 名册当前/上限；血条比例 = current/max。
func test_enemy_card_shows_hp_number_and_bar_from_roster() -> void:
	# Arrange + Act
	var card: Control = _build_enemy(ENEMY_A)
	# Assert —— 数字
	var stat: Label = card.get_node_or_null("StatLabel")
	assert_not_null(stat, "敌方卡应有 StatLabel（HP 数字）")
	assert_true(stat.text.contains("12/20"),
			"敌方卡应显示名册的 current/max，实际：%s" % stat.text)
	# Assert —— 血条比例（受伤前满比例之外的比例判定在下一用例）
	assert_eq(card.current_hp, 12, "卡上 HP 快照应等于名册当前值")
	assert_eq(card.max_hp, 20, "卡上 HP 上限应等于名册上限")


## 敌方卡：名册多只敌人各建各的卡，名字与 HP 不串味。
func test_enemy_cards_keep_their_own_name_and_hp() -> void:
	# Arrange —— 两只敌人，不同名不同血
	var card_a: Control = _build_enemy(ENEMY_A)
	reader.hp_map[ENEMY_B] = {"current": 3, "max": 8}
	reader.name_map[ENEMY_B] = "巡山小妖"
	reader.atk_map[ENEMY_B] = 2
	# Act
	roster.build_side([{"character_id": ENEMY_B, "is_front": false}],
			container, roster.enemy_cards)
	var card_b: Control = roster.get_card(ENEMY_B)
	# Assert
	var name_a: Label = card_a.get_node_or_null("NameLabel")
	var name_b: Label = card_b.get_node_or_null("NameLabel")
	assert_not_null(name_a, "敌方卡应有 NameLabel（可分辨谁是谁）")
	assert_not_null(name_b, "第二只敌人也应有名牌")
	assert_eq(name_a.text, "黑风寨匪徒", "第一只敌人的名牌")
	assert_eq(name_b.text, "巡山小妖", "第二只敌人的名牌（不串味）")
	assert_true(card_b.get_node("StatLabel").text.contains("3/8"),
			"第二只敌人的血量应各算各的，实际：%s"
			% card_b.get_node("StatLabel").text)


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 受伤后刷新（结算帧写入卡 → 数字与血条同步）
# ═══════════════════════════════════════════════════════════════════════════════

## 受伤后：数字变成新值，血条比例跟着降（不是只更新其中一个）。
func test_enemy_card_refreshes_after_damage() -> void:
	# Arrange
	var card: Control = _build_enemy(ENEMY_A)
	card.set_reduce_motion(true)  # 直落终值——免去 Tween 时序
	# Act —— 名册先落库（这里是 stub 的等价写入），再把终值喂给卡
	reader.hp_map[ENEMY_A] = {"current": 5, "max": 20}
	card.apply_hp(5, 20)
	# Assert
	assert_true(card.get_node("StatLabel").text.contains("5/20"),
			"受伤后数字应刷新，实际：%s" % card.get_node("StatLabel").text)
	assert_almost_eq(card.get_hp_display_ratio_for_test(), 0.25, 0.001,
			"受伤后血条应降到 5/20=0.25")


## 我方卡同样有 HP 数字与名牌（不是只给敌人开小灶）。
func test_ally_card_shows_name_and_hp_too() -> void:
	# Arrange
	reader.hp_map[ALLY_A] = {"current": 30, "max": 40}
	reader.name_map[ALLY_A] = "青云弟子"
	reader.atk_map[ALLY_A] = 9
	# Act
	roster.build_side([{"character_id": ALLY_A, "is_front": true}],
			container, roster.ally_cards)
	var card: Control = roster.get_card(ALLY_A)
	# Assert
	assert_eq(card.get_node("NameLabel").text, "青云弟子", "我方卡也应有名牌")
	assert_true(card.get_node("StatLabel").text.contains("30/40"),
			"我方卡也应有 HP 数字，实际：%s" % card.get_node("StatLabel").text)


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 阵亡有独立视觉（灰化 + 「已阵亡」戳记，且不靠改透明度）
# ═══════════════════════════════════════════════════════════════════════════════

## HP 归零 → 卡进入阵亡态：戳记可见且写着「已阵亡」。
func test_defeated_card_shows_defeat_stamp() -> void:
	# Arrange
	var card: Control = _build_enemy(ENEMY_A)
	var stamp: Label = card.get_node_or_null("DefeatStamp")
	assert_not_null(stamp, "卡上应有阵亡戳记控件")
	assert_false(stamp.visible, "满血时不应显示阵亡戳记")
	# Act
	card.apply_hp(0, 20)
	# Assert
	assert_true(card.is_defeated, "HP 归零应判为阵亡")
	assert_true(stamp.visible, "阵亡时戳记应可见")
	assert_eq(stamp.text, "已阵亡", "戳记文案")


## 阵亡判定不因「读不到数据」触发——0/0 的卡不算阵亡（防首帧集体盖戳）。
func test_unknown_hp_card_is_not_marked_defeated() -> void:
	# Arrange —— 名册读不到该角色（HP 全零）
	var card: Control = CardScript.new()
	add_child_autofree(card)
	# Act
	card.apply_hp(0, 0)
	# Assert
	assert_false(card.is_defeated, "max_hp=0（读不到数据）不应判阵亡")
	assert_false(card.get_node("DefeatStamp").visible, "戳记不应出现")
	assert_false(DefeatMarker.is_defeated(0, 0), "纯函数同口径")


## 阵亡视觉规格：灰化覆盖不透明、戳记底色不透明——不是只靠透明度区分。
func test_defeat_visual_spec_is_solid_overlay_not_alpha_only() -> void:
	# Act
	var spec: Dictionary = DefeatMarker.style(true)
	# Assert
	assert_gt(float(spec["overlay"].a), 0.4, "灰化覆盖应足够实（不是轻微降透明）")
	assert_gt(float(spec["stamp_bg"].a), 0.8, "戳记底色应接近不透明")
	assert_eq(str(spec["text"]), "已阵亡", "规格里的文案与戳记一致")
	assert_gt(float(spec["stamp_height"]), 0.0, "戳记应占有可见高度")
	# 未阵亡时规格应短路为空（绘制侧据此跳过）
	var alive: Dictionary = DefeatMarker.style(false)
	assert_eq(float(alive["overlay"].a), 0.0, "未阵亡不应有灰化")
	assert_eq(str(alive["text"]), "", "未阵亡不应有戳记文案")
