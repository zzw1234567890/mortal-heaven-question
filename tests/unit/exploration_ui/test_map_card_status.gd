extends GutTest
## MapCard —— 通关状态与「下一张」推荐标记的渲染判据（控件级，无需场景）。[br]
## [br][b]本文件补的断链[/b]：卡片的「⭐首次通关」分支读的是条目里的
## [code]is_first_clear[/code]，而组装条目的 [code]ExplorationMapList._entry_for[/code]
## 从来没产出过这个键——那一格是[b]死代码[/b]；也没有任何字段记录通关次数，
## 于是「通关一次」与「刷了十次」在界面上完全一样（都只写「已通关」）。[br]
## [br][b]覆盖[/b]：[br]
##   1. 三态状态行——未通关 / ⭐首次通关 / 已通关·第 N 次；[br]
##   2. 已通关卡的重复挑战说明（「可重复挑战·仅基础奖励」）——不给这句话，玩家会
##      以为再打一次还能再拿首通彩头；[br]
##   3. 推荐标记——点亮时卡面出「▶ 推荐下一张」且边框换成金色，熄灭时两者都复原
##      （色盲玩家不靠颜色也能分辨，.claude/rules/ui-code.md）。[br]
## [br][b]为什么是控件级而不是纯函数[/b]：这三条判据落在 [code]MapCard[/code] 的
## 渲染方法上（[code]_status_text[/code] / [code]repeat_hint_text[/code] /
## [code]set_recommended[/code]），脱开控件就没有「卡面写了什么」可言；卡片是纯
## [Panel]，[code]new()[/code] 即可建，不需要场景与 Autoload。[br]
##
## 来源: design/gdd/exploration-ui-system.md §1 地图选择界面（⭐ 首通标记 / 卡片状态）
## 与 §7 通关结算（非首次不给首通奖励）、ADR-0031 §2、.claude/rules/ui-code.md。

const MapCardScript := preload("res://src/ui/exploration/map_card.gd")

var _card: Panel = null


func after_each() -> void:
	if _card != null and is_instance_valid(_card):
		_card.free()
	_card = null


## 按条目建一张卡（并入树——[method set_recommended] 会写主题样式，树外也能写，
## 但入树更贴近生产）。
func _card_of(p_entry: Dictionary) -> Panel:
	_card = MapCardScript.new()
	_card.call(&"setup", p_entry)
	add_child_autofree(_card)
	return _card


## 一份最小地图条目（只填卡片读的字段）。
func _entry(p_overrides: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = {
		"map_id": &"qing_yun_jian_zong", "name": "青云剑宗", "difficulty": 1,
		"is_cleared": false, "clear_count": 0, "is_unlocked": true,
		"reentry_allowed": true, "reentry_total": 0, "is_permanent_free": true,
	}
	for key: Variant in p_overrides.keys():
		entry[key] = p_overrides[key]
	return entry


## 卡面状态行文本（[method MapCard._status_text] 是私有的——按标签文本找，
## 不调私有方法，渲染结果才是玩家看得见的东西）。
func _status_text_of(p_card: Panel) -> String:
	for label: Node in _labels_of(p_card):
		var text: String = (label as Label).text
		if text in ["未通关", "⭐首次通关"] or text.begins_with("已通关"):
			return text
	return ""


## 卡面所有标签（深度优先——卡片内部结构是构建细节，不写死路径）。
func _labels_of(p_node: Node) -> Array:
	var out: Array = []
	for child: Node in p_node.get_children():
		if child is Label:
			out.append(child)
		out.append_array(_labels_of(child))
	return out


## 卡面某段文本是否出现（[param p_needle] 子串匹配）。
func _card_has_text(p_card: Panel, p_needle: String) -> bool:
	for label: Node in _labels_of(p_card):
		if str((label as Label).text).contains(p_needle):
			return true
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 状态行三态
# ═══════════════════════════════════════════════════════════════════════════════

func test_uncleared_card_shows_uncleared() -> void:
	var card: Panel = _card_of(_entry())
	assert_eq(_status_text_of(card), "未通关", "未通关卡应写「未通关」")


func test_first_clear_card_shows_star_marker() -> void:
	var card: Panel = _card_of(_entry({"is_cleared": true, "clear_count": 1}))
	assert_eq(_status_text_of(card), "⭐首次通关",
			"只通过一次的图应带 ⭐ 首通标记（GDD §1）")


func test_repeated_clear_card_shows_count() -> void:
	var card: Panel = _card_of(_entry({"is_cleared": true, "clear_count": 3}))
	assert_eq(_status_text_of(card), "已通关·第3次",
			"刷过的图应写清是第几次——否则与首通无从区分")


func test_cleared_card_without_count_falls_back_to_cleared() -> void:
	## 旧载荷（条目不带 clear_count）既不能说「⭐首次通关」（那是编造一个「你是首通」
	## 的说法），也不能说「第 0 次」（读不通）——退回原来那三个字。
	var card: Panel = _card_of(_entry({"is_cleared": true}))
	assert_eq(_status_text_of(card), "已通关",
			"缺次数时按「已通关」处理——不显示「第 0 次」这类读不通的字")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 重复挑战说明
# ═══════════════════════════════════════════════════════════════════════════════

func test_cleared_card_explains_repeat_reward() -> void:
	var card: Panel = _card_of(_entry({"is_cleared": true, "clear_count": 2}))
	assert_true(_card_has_text(card, "可重复挑战"),
			"已通关卡应写明「可重复挑战·仅基础奖励」")
	assert_true(_card_has_text(card, "仅基础奖励"),
			"说明必须点名只有基础奖励（GDD §7：非首次不给首通奖励）")


func test_uncleared_card_has_no_repeat_hint() -> void:
	var card: Panel = _card_of(_entry())
	assert_false(_card_has_text(card, "可重复挑战"),
			"未通关卡不该谈重复挑战（还没通过一次）")


func test_non_reenterable_cleared_card_still_explains_reward() -> void:
	## 苍玄古战场不可重入——它连「重复挑战」都点不了，但卡面状态仍是「已通关」，
	## 说明行照给（费用行另写「已通关·不可重入」）。
	var card: Panel = _card_of(_entry({"map_id": &"cang_xuan_gu_zhan_chang",
			"name": "苍玄古战场", "is_cleared": true, "clear_count": 1,
			"reentry_allowed": false}))
	assert_true(_card_has_text(card, "已通关·不可重入"), "不可重入卡应写明无重入入口")
	assert_true(_card_has_text(card, "仅基础奖励"), "通关状态说明与重入资格是两件事")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 「下一张」推荐标记
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_is_not_recommended_by_default() -> void:
	var card: Panel = _card_of(_entry())
	assert_false(bool(card.call(&"is_recommended")), "默认不推荐任何一张")
	assert_false(_card_has_text(card, "推荐下一张"), "默认不该出现推荐语")


func test_set_recommended_marks_card_in_two_channels() -> void:
	# Arrange
	var card: Panel = _card_of(_entry())
	# Act
	card.call(&"set_recommended", true)
	# Assert——文字 + 边框双通道（色盲可读）
	assert_true(bool(card.call(&"is_recommended")), "点亮后应处于推荐态")
	assert_true(_card_has_text(card, "推荐下一张"), "推荐卡应有文字标记")
	var style: StyleBox = card.get_theme_stylebox(&"panel")
	assert_true(style is StyleBoxFlat, "推荐卡应有可读的样式盒")
	assert_eq((style as StyleBoxFlat).border_color, MapCardScript.RECOMMEND_BORDER_COLOR,
			"推荐卡边框应换成金色档")


func test_set_recommended_false_restores_normal_border() -> void:
	# Arrange——先点亮
	var card: Panel = _card_of(_entry())
	card.call(&"set_recommended", true)
	# Act——熄灭（换推荐目标时必须能复原，否则会留下两张「推荐」卡）
	card.call(&"set_recommended", false)
	# Assert
	assert_false(bool(card.call(&"is_recommended")), "熄灭后不应仍是推荐态")
	assert_false(_card_has_text(card, "推荐下一张"), "推荐语应清空")
	var style: StyleBox = card.get_theme_stylebox(&"panel")
	assert_eq((style as StyleBoxFlat).border_color, MapCardScript.NORMAL_BORDER_COLOR,
			"边框应恢复常态色")


func test_recommend_is_idempotent() -> void:
	# Arrange
	var card: Panel = _card_of(_entry())
	# Act——重复点亮 / 重复熄灭不叠加
	card.call(&"set_recommended", true)
	card.call(&"set_recommended", true)
	var twice: bool = bool(card.call(&"is_recommended"))
	card.call(&"set_recommended", false)
	card.call(&"set_recommended", false)
	# Assert
	assert_true(twice, "重复点亮仍是推荐态")
	assert_false(bool(card.call(&"is_recommended")), "重复熄灭仍是常态")
