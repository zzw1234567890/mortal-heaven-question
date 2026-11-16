extends GutTest
## 六身份起始卡组「成型度」验收：张数落在 GDD 调优区间 + 结构齐备 + 模板真实存在。
##
## [b]背景[/b]：DEBT-CBT-018-6 补齐了其余 5 个身份的卡牌模板，但「补了模板」不等于
## 「这套卡组能打」——一张普攻不带、或张数掉到 3 张，模板再全也开不了局。
## 本文件按 GDD identity-selection-system.md §调优旋钮「初始卡牌总张数 6-8 张
## （可接受 5-12）」与 §2 各身份「初始卡牌详情」表，对[b]全部 6 个身份[/b]断言：
##   · 总张数落在 6~8（策划区间，超出即调优报警）；
##   · 必带基础攻击（否则开局无牌可打）；
##   · 除普攻外至少还有一张非角色卡（核心技能 / 身份特色牌）；
##   · 卡组引用的 card_id 在真实模板目录里逐张存在（模板缺失＝开局中途失败）；
##   · 角色位恰好 2 个、slot_index 为 1 和 2。
##
## [b]不硬编码清单[/b]——张数与结构从 [code]identity_templates.gd[/code] 推导，
## 身份表改了这里自动跟随；「该有的牌有没有」由必带项断言保证。
##
## 来源: GDD identity-selection-system.md §2/§调优旋钮、
## ADR-0022 §get_available_identities、DEBT-CBT-018-6。

const Templates := preload("res://src/feature/identity/identity_templates.gd")
const CS_SCRIPT: GDScript = preload("res://src/core/card_system/card_system.gd")

## GDD §调优旋钮：初始卡牌总张数目标区间。
const DECK_MIN: int = 6
const DECK_MAX: int = 8
## 每个身份的角色位数（GDD §2 各身份「初始角色」表均为 2 名）。
const CHARACTER_COUNT: int = 2

var cs: Node = null


func before_all() -> void:
	# 真实模板目录——用独立实例而非 Autoload（其它测试会往 /root/CardSystem 注入夹具）。
	cs = CS_SCRIPT.new()
	cs._load_templates_from(CS_SCRIPT.DEFAULT_TEMPLATE_PATH)
	for _attempt: int in range(3):
		if cs._pending_paths.is_empty():
			break
		for _frame: int in range(100):
			cs._process(0.016)
			if cs._pending_paths.is_empty():
				break
			OS.delay_msec(4)
	assert_true(cs._pending_paths.is_empty(), "真实模板应在 3 轮 × 100 帧内加载完成")


func after_all() -> void:
	if cs != null:
		cs.free()
		cs = null


# ═══════════════════════════════════════════════════════════════════════════════
# 张数落在策划区间
# ═══════════════════════════════════════════════════════════════════════════════

func test_every_identity_deck_total_is_within_tuning_band() -> void:
	for id: StringName in Templates.IDENTITY_TEMPLATES:
		var total: int = _deck_total(Templates.IDENTITY_TEMPLATES[id])
		assert_true(total >= DECK_MIN and total <= DECK_MAX,
				"身份 %s 的初始卡组总张数 %d 应落在 GDD 调优区间 %d-%d"
				% [id, total, DECK_MIN, DECK_MAX])


func test_six_identities_have_distinct_deck_shapes() -> void:
	## 六个身份都要有卡组（不是空壳），且不全都长一个样——「身份可选」的前提是
	## 每个身份确实带来不同的开局牌。
	var shapes: Dictionary = {}
	for id: StringName in Templates.IDENTITY_TEMPLATES:
		var total: int = _deck_total(Templates.IDENTITY_TEMPLATES[id])
		assert_true(total > 0, "身份 %s 不应有空卡组" % id)
		shapes[_deck_signature(Templates.IDENTITY_TEMPLATES[id])] = true
	assert_true(shapes.size() >= 3,
			"六个身份的卡组至少应有 3 种不同构成（实际 %d 种）" % shapes.size())


# ═══════════════════════════════════════════════════════════════════════════════
# 结构齐备：普攻 + 核心牌 + 角色位
# ═══════════════════════════════════════════════════════════════════════════════

func test_every_identity_deck_contains_basic_attack() -> void:
	for id: StringName in Templates.IDENTITY_TEMPLATES:
		var cards: Array = Templates.IDENTITY_TEMPLATES[id]["initial_deck"]["cards"]
		assert_true(_has_card(cards, "basic_attack"),
				"身份 %s 的初始卡组应含基础攻击（否则开局无牌可打）" % id)


func test_every_identity_deck_has_a_non_basic_card() -> void:
	## 除普攻外至少一张核心/特色牌——只剩普攻的卡组谈不上「身份特色」。
	for id: StringName in Templates.IDENTITY_TEMPLATES:
		var cards: Array = Templates.IDENTITY_TEMPLATES[id]["initial_deck"]["cards"]
		var others: int = 0
		for entry: Dictionary in cards:
			if str(entry["card_id"]) != "basic_attack":
				others += 1
		assert_true(others >= 1,
				"身份 %s 除基础攻击外应至少还有 1 种卡（核心技能 / 身份特色牌）" % id)


func test_every_identity_has_exactly_two_character_slots_numbered_one_and_two() -> void:
	for id: StringName in Templates.IDENTITY_TEMPLATES:
		var slots: Array = Templates.IDENTITY_TEMPLATES[id]["initial_deck"]["character_slots"]
		assert_eq(slots.size(), CHARACTER_COUNT,
				"身份 %s 应有 %d 个初始角色位" % [id, CHARACTER_COUNT])
		var indices: Array[int] = []
		for entry: Dictionary in slots:
			indices.append(int(entry["slot_index"]))
		indices.sort()
		assert_eq(indices, [1, 2], "身份 %s 的角色位编号应为 1 与 2" % id)


# ═══════════════════════════════════════════════════════════════════════════════
# 真实模板目录里逐张存在（不降级）
# ═══════════════════════════════════════════════════════════════════════════════

func test_every_referenced_card_id_exists_in_real_template_directory() -> void:
	assert_false(cs.is_degraded, "真实模板目录不应降级（原因：%s）" % cs.degraded_reason)
	for id: StringName in Templates.IDENTITY_TEMPLATES:
		var missing: Array = []
		for card_id: String in _referenced_ids(Templates.IDENTITY_TEMPLATES[id]):
			if cs.get_template(StringName(card_id)) == null:
				missing.append(card_id)
		assert_eq(missing, [], "身份 %s 引用的 card_id 应全部有真实模板（缺失：%s）"
				% [id, str(missing)])


func test_basic_attack_template_is_playable_at_zero_cost() -> void:
	## 普攻是所有身份的地板牌——模板缺失或费用非 0 会让「开局无牌可打」重现。
	var tpl = cs.get_template(&"basic_attack")
	assert_not_null(tpl, "应存在基础攻击模板")
	if tpl == null:
		return
	assert_eq(int(tpl.type), 5, "基础攻击暂取 TALISMAN(5)（DEBT-CBT-018-8）")
	assert_eq(int(tpl.cost), 0, "基础攻击应为 0 费——否则开局可能无牌可打")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部辅助（全部从身份表推导，不硬编码清单）
# ═══════════════════════════════════════════════════════════════════════════════

func _deck_total(tmpl: Dictionary) -> int:
	var total: int = 0
	for entry: Dictionary in tmpl["initial_deck"]["cards"]:
		total += int(entry["count"])
	return total


## 卡组构成签名——「card_id×count」排序后拼接，用于判断两个身份是否同一套牌。
func _deck_signature(tmpl: Dictionary) -> String:
	var parts: Array[String] = []
	for entry: Dictionary in tmpl["initial_deck"]["cards"]:
		parts.append("%s×%d" % [str(entry["card_id"]), int(entry["count"])])
	parts.sort()
	return "|".join(parts)


func _has_card(cards: Array, card_id: String) -> bool:
	for entry: Dictionary in cards:
		if str(entry["card_id"]) == card_id:
			return int(entry["count"]) > 0
	return false


func _referenced_ids(tmpl: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in tmpl["initial_deck"]["cards"]:
		ids.append(str(entry["card_id"]))
	for entry: Dictionary in tmpl["initial_deck"]["character_slots"]:
		ids.append(str(entry["card_id"]))
	return ids
