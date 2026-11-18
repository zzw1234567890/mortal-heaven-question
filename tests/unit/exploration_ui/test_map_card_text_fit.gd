extends GutTest
## 卡面文本的行数与溢出防护 —— 「中文长句不溢出」。[br]
## [br][b]本文件补的缺口[/b]：卡片是 [Panel] 而不是容器，卡面高度由
## [code]custom_minimum_size[/code] 固定（300×232）。此前卡面七行文本全是默认
## [code]AUTOWRAP_OFF[/code] + 不裁切：任何一行宽过盒子都会把内容盒顶宽、把行数
## 顶多，从卡片底下溢出去。[br]
## [br][b]覆盖[/b]：[br]
##   1. 每一行都是单行 + 省略号（[code]clip_text[/code] +
##      [code]OVERRUN_TRIM_ELLIPSIS[/code]）——结构性防御，不是逐句调数据；[br]
##   2. 当前数据下最长的那行（锁定条件「需大乘期 · 需通关归墟·古魔战场」）确实
##      完整显示，不需要省略号；[br]
##   3. 七行（含最长文案）的合计高度仍在卡面内容盒内。[br]
## [br][b]为什么是控件级[/b]：判据落在 [code]MapCard._build[/code] 建出的标签与
## 盒子上；卡片是纯 [Panel]，[code]new()[/code] 即可建，不需要场景与 Autoload。[br]
##
## 来源: design/gdd/exploration-ui-system.md §1 地图选择界面（卡片字段）、
## ADR-0031 §2、.claude/rules/ui-code.md（最小分辨率下也要完整）。

const MapCardScript := preload("res://src/ui/exploration/map_card.gd")

## 探明表里最长的一张图（7 字）与最长的条件行组合。
const LONGEST_NAME: String = "归墟·古魔战场"
## 条件行里会出现的最长组合（境界名 + 前置图名，均由探明表给出）。
const LONGEST_HINT: String = "需大乘期 · 需通关归墟·古魔战场"

var _card: Panel = null


func after_each() -> void:
	if _card != null and is_instance_valid(_card):
		_card.free()
	_card = null


## 按条目建卡（入树——布局才会真的算）。
func _card_of(p_entry: Dictionary) -> Panel:
	_card = MapCardScript.new()
	_card.call(&"setup", p_entry)
	add_child_autofree(_card)
	return _card


## 一份最小条目（只填卡片读的字段）。
func _entry(p_overrides: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = {
		"map_id": &"qing_yun_jian_zong", "name": "青云剑宗", "difficulty": 1,
		"is_cleared": false, "clear_count": 0, "is_unlocked": true,
		"reentry_allowed": true, "reentry_total": 0, "is_permanent_free": true,
	}
	for key: Variant in p_overrides.keys():
		entry[key] = p_overrides[key]
	return entry


## 卡面所有标签（深度优先——内部结构是构建细节，不写死路径）。
func _labels_of(p_node: Node) -> Array:
	var out: Array = []
	for child: Node in p_node.get_children():
		if child is Label:
			out.append(child)
		out.append_array(_labels_of(child))
	return out


## 卡面内容盒（唯一那个 VBoxContainer）。
func _box_of(p_card: Panel) -> VBoxContainer:
	for child: Node in p_card.get_children():
		if child is VBoxContainer:
			return child
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 每一行都单行 + 省略号
# ═══════════════════════════════════════════════════════════════════════════════

func test_every_card_line_is_single_line_with_ellipsis() -> void:
	# Arrange——解锁卡 + 已通关（七行里能出的都出）
	var card: Panel = _card_of(_entry({"is_cleared": true, "clear_count": 3}))
	card.call(&"set_recommended", true)
	var labels: Array = _labels_of(card)
	# Assert——行数够（名称/难度/状态/费用/重复/推荐 六行；锁定行空文本）
	assert_gte(labels.size(), 6, "卡面应有各行标签，实际 %d" % labels.size())
	for raw: Variant in labels:
		var label: Label = raw as Label
		assert_false(label.clip_text == false,
				"卡面标签（%s）应开启 clip_text——否则长文案会把卡片顶破" % label.text)
		assert_eq(label.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS,
				"卡面标签（%s）应配省略号——超长时给读得懂的收尾" % label.text)


func test_card_labels_do_not_autowrap() -> void:
	## 卡片高度写死（[constant MapCard.CARD_MIN_SIZE]），换行会把多出来的那行顶出卡面。
	var card: Panel = _card_of(_entry())
	for raw: Variant in _labels_of(card):
		var label: Label = raw as Label
		assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_OFF,
				"卡面标签（%s）不该换行——多一行高度就直接顶穿卡片" % label.text)


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 最长条件行完整显示
# ═══════════════════════════════════════════════════════════════════════════════

func test_longest_lock_hint_fits_without_ellipsis() -> void:
	# Arrange——锁定卡带上最长组合的条件行
	var card: Panel = _card_of(_entry({"is_unlocked": false, "locked_hint": LONGEST_HINT,
			"name": LONGEST_NAME}))
	# Act——等布局落定
	await get_tree().process_frame
	# Assert——条件行的文本没有宽过它的 rect（宽过就会被省略号截掉，玩家读不全）
	var lock: Label = null
	for raw: Variant in _labels_of(card):
		if str((raw as Label).text) == LONGEST_HINT:
			lock = raw
	assert_not_null(lock, "锁定卡应显示带中文条件的行「%s」" % LONGEST_HINT)
	if lock == null:
		return
	var font: Font = lock.get_theme_font(&"font")
	var need: float = font.get_string_size(LONGEST_HINT, HORIZONTAL_ALIGNMENT_LEFT,
			-1, lock.get_theme_font_size(&"font_size")).x
	assert_lte(need, lock.get_rect().size.x + 0.5,
			"最长条件行需 %.0fpx，行 rect 只有 %.0fpx——会被省略号截掉"
			% [need, lock.get_rect().size.x])


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 内容高度不超卡面
# ═══════════════════════════════════════════════════════════════════════════════

func test_tallest_card_content_fits_inside_panel() -> void:
	# Arrange——行数最多的一档：锁定 + 已通关 + 推荐 同时在场是不可能的（锁定卡
	# 未通关），故取「已通关 + 推荐」（六行，含最长的已通关次数行与推荐行）
	var card: Panel = _card_of(_entry({"name": LONGEST_NAME, "is_cleared": true,
			"clear_count": 10}))
	card.call(&"set_recommended", true)
	await get_tree().process_frame
	# Act——内容盒要的高度 vs 拿到的
	var box: VBoxContainer = _box_of(card)
	assert_not_null(box, "卡面应有内容盒")
	if box == null:
		return
	# Assert——盒子的最小高度不超它自己的高度（超了就是从卡片底下溢出去）
	assert_lte(box.get_combined_minimum_size().y, box.size.y + 0.5,
			"卡面内容需 %.0fpx 高，盒子只有 %.0fpx——会从卡片底下溢出"
			% [box.get_combined_minimum_size().y, box.size.y])
