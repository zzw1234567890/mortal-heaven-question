extends GutTest
## 六身份开局落地的端到端验收（真实 Autoload：IdentitySelectionSystem +
## CardSystem + ResourceSystem + DeckEditingSystem + ProgressionSystem）。
##
## [b]为什么需要[/b]：身份选择此前只有单元测试（mock 卡牌/资源系统），
## 「选了身份之后卡组与起始资源到底有没有真落进存档」没有任何断言。
## 本文件对[b]六个身份逐个[/b]跑 [code]apply_identity[/code]，再从 GSM 读回：
##   · [code]deck.current_deck[/code] 的模板序列 == 身份表定义的卡组（含张数）；[br]
##   · [code]deck.slots[/code] 的角色模板 == 身份表定义的角色位，其余为空；[br]
##   · 初始灵石 == 身份表 [code]initial_resources.ling_shi[/code]；[br]
##   · [code]player.talent_map[/code] 注册了该身份的专属天赋；[br]
##   · [code]narrative.story_flags.opening_text[/code] 写入该身份的叙事文本。[br]
##
## [b]卡组序列用身份表推导[/b]——不硬编码清单，身份表改了这里自动跟随。
##
## [b]阵道双杰[/b]单独一组：先验证「无天赋 → 未解锁 → apply 失败且存档不变」，
## 再验证「买下真实轮回天赋 resource_4（苍玄行者）→ 可开局 → 卡组落地」——
## 这正是「其余身份选了也玩不起来」的那条断链。
##
## 来源: ADR-0022 §apply_identity、GDD identity-selection-system.md §3 身份选择流程。

const ISS_PATH: String = "/root/IdentitySelectionSystem"
const Templates := preload("res://src/feature/identity/identity_templates.gd")
const RTS := preload("res://src/feature/reincarnation_talent_system.gd")
const PrimerScript := preload("res://tests/integration/exploration_ui/card_template_primer.gd")

var isys: Node = null
var gsm: Node = null
var _player_before: Dictionary = {}
var _deck_before: Dictionary = {}
var _collection_before: Dictionary = {}
var _narrative_before: Dictionary = {}
var _next_card_id_before: int = 1
var _db_before: Dictionary = {}
var _validation_before: bool = false
var _talents_before: Dictionary = {}
var _talent_defs_before: Dictionary = {}
var _signal_received: Array = []


func before_all() -> void:
	isys = (Engine.get_main_loop() as SceneTree).root.get_node_or_null(ISS_PATH)
	assert_not_null(isys, "前置：IdentitySelectionSystem Autoload 应已注册")
	# 让六身份引用的模板全部就位（CardSystem 异步加载——同步推进到可查）。
	for id: StringName in Templates.IDENTITY_TEMPLATES:
		for card_id: StringName in _referenced_ids(Templates.IDENTITY_TEMPLATES[id]):
			PrimerScript.prime(CardSystem, card_id)


func before_each() -> void:
	gsm = GameStateManager
	_player_before = (gsm.player as Dictionary).duplicate(true)
	_deck_before = (gsm.deck as Dictionary).duplicate(true)
	_collection_before = (gsm.collection as Dictionary).duplicate(true)
	_narrative_before = (gsm.narrative as Dictionary).duplicate(true)
	_next_card_id_before = int(gsm.get("_next_card_instance_id"))
	_db_before = (gsm.get("_card_template_database") as Dictionary).duplicate(true)
	_validation_before = bool(gsm.validation_enabled)
	_talents_before = (ProgressionSystem.get("_talents") as Dictionary).duplicate(true)
	_talent_defs_before = (ProgressionSystem.get("_talent_defs") as Dictionary).duplicate(true)
	_prepare_card_validation()
	_reset_gsm()
	_signal_received.clear()
	isys.identity_selected.connect(_on_identity_selected)


func after_each() -> void:
	if isys.identity_selected.is_connected(_on_identity_selected):
		isys.identity_selected.disconnect(_on_identity_selected)
	gsm.player = _player_before
	gsm.deck = _deck_before
	gsm.collection = _collection_before
	gsm.narrative = _narrative_before
	gsm.set("_next_card_instance_id", _next_card_id_before)
	gsm.set("_card_template_database", _db_before)
	gsm.validation_enabled = _validation_before
	ProgressionSystem.set("_talents", _talents_before)
	ProgressionSystem.set("_talent_defs", _talent_defs_before)
	_signal_received.clear()


func _on_identity_selected(identity_id: StringName) -> void:
	_signal_received.append(identity_id)


# ═══════════════════════════════════════════════════════════════════════════════
# 六身份逐个落地
# ═══════════════════════════════════════════════════════════════════════════════

func test_each_identity_lands_deck_slots_resources_and_talent() -> void:
	for identity_id: StringName in Templates.IDENTITY_TEMPLATES:
		var tmpl: Dictionary = Templates.IDENTITY_TEMPLATES[identity_id]
		_grant_unlock_for(identity_id, tmpl)
		_reset_gsm()

		# Act
		var applied: bool = isys.apply_identity(identity_id)

		# Assert
		assert_true(applied, "身份 %s 应能开局（解锁 + 模板齐备）" % identity_id)
		if not applied:
			continue
		assert_eq(str(gsm.player.identity_id), str(identity_id),
				"身份 %s 应写入 GSM.player.identity_id" % identity_id)
		_assert_deck_matches(identity_id, tmpl)
		_assert_slots_match(identity_id, tmpl)
		assert_eq(int(gsm.player.resources.ling_shi),
				int(tmpl["initial_resources"]["ling_shi"]),
				"身份 %s 的初始灵石应符合身份表" % identity_id)
		var talent_map: Dictionary = gsm.player.get("talent_map", {})
		var talent_id: String = str(tmpl["talent"]["id"])
		assert_eq(int(talent_map.get(talent_id, -1)), int(tmpl["talent"]["magnitude"]),
				"身份 %s 应注册专属天赋 %s" % [identity_id, talent_id])
		assert_eq(str(gsm.narrative.story_flags.get("opening_text", "")),
				str(tmpl["flavor_text"]), "身份 %s 应写入开局叙事文本" % identity_id)
		assert_eq(_signal_received, [identity_id],
				"身份 %s 应恰好发射一次 identity_selected" % identity_id)
		_signal_received.clear()


## 卡组：张数 + 模板序列都按身份表核对（序列错＝卡组顺序错，同样算没落地）。
func _assert_deck_matches(identity_id: StringName, tmpl: Dictionary) -> void:
	var expected: Array[String] = []
	for entry: Dictionary in tmpl["initial_deck"]["cards"]:
		for _i: int in range(int(entry["count"])):
			expected.append(str(entry["card_id"]))
	var actual: Array[String] = []
	for instance_id: Variant in gsm.deck.current_deck:
		actual.append(_template_of(int(instance_id)))
	assert_eq(actual, expected, "身份 %s 的初始卡组序列应与身份表一致" % identity_id)


## 角色位：位 1/2 为身份表的角色卡，位 3-6 为空。
func _assert_slots_match(identity_id: StringName, tmpl: Dictionary) -> void:
	var slots: Array = gsm.deck.slots
	assert_eq(slots.size(), 6, "身份 %s 的 slots 应有 6 格" % identity_id)
	for entry: Dictionary in tmpl["initial_deck"]["character_slots"]:
		var index: int = int(entry["slot_index"]) - 1
		assert_not_null(slots[index], "身份 %s 的位 %d 应有角色" % [identity_id, index + 1])
		if slots[index] != null:
			assert_eq(_template_of(int(slots[index])), str(entry["card_id"]),
					"身份 %s 的位 %d 角色模板应符合身份表" % [identity_id, index + 1])
	for i: int in range(tmpl["initial_deck"]["character_slots"].size(), 6):
		assert_null(slots[i], "身份 %s 的位 %d 应为空" % [identity_id, i + 1])


# ═══════════════════════════════════════════════════════════════════════════════
# 阵道双杰：锁 → 解锁 → 真能开局（本轮修复的断链）
# ═══════════════════════════════════════════════════════════════════════════════

func test_formation_duo_blocked_until_real_talent_granted() -> void:
	# Arrange —— 无任何轮回天赋
	_reset_gsm()
	var entry: Dictionary = _entry_of(&"formation_duo")

	# Assert —— 未解锁 → 不就绪 → 开局被拦
	assert_false(bool(entry["is_unlocked"]), "无天赋时阵道双杰应未解锁")
	assert_false(bool(entry["is_ready"]), "未解锁时阵道双杰不应就绪")
	assert_false(isys.apply_identity(&"formation_duo"),
			"未解锁身份 apply_identity 应返回 false")
	assert_eq(str(gsm.player.identity_id), "", "被拦时 identity_id 不应被写入")
	assert_eq(gsm.deck.current_deck, [], "被拦时卡组不应被写入")


func test_formation_duo_playable_after_real_talent_granted() -> void:
	# Arrange —— 买下真实 L4 天赋「苍玄行者」（resource_4，效果 = 解锁 formation_duo）
	_grant_talent(&"resource_4")
	var entry: Dictionary = _entry_of(&"formation_duo")
	assert_true(bool(entry["is_unlocked"]), "拥有 resource_4 后阵道双杰应解锁")
	assert_true(bool(entry["is_ready"]), "解锁且模板齐备后阵道双杰应就绪")

	# Act
	var applied: bool = isys.apply_identity(&"formation_duo")

	# Assert
	assert_true(applied, "阵道双杰应能开局")
	assert_eq(str(gsm.player.identity_id), "formation_duo", "identity_id 应为阵道双杰")
	var tmpl: Dictionary = Templates.IDENTITY_TEMPLATES[&"formation_duo"]
	_assert_deck_matches(&"formation_duo", tmpl)
	_assert_slots_match(&"formation_duo", tmpl)
	assert_eq(int(gsm.player.resources.ling_shi), 25, "阵道双杰初始灵石应为 25")


func test_unrelated_talent_does_not_open_formation_duo() -> void:
	# Arrange —— 解锁一个非身份类天赋
	_grant_talent(&"cultivation_1")

	# Act
	var entry: Dictionary = _entry_of(&"formation_duo")

	# Assert
	assert_false(bool(entry["is_unlocked"]), "非身份解锁类天赋不得解锁阵道双杰")
	assert_false(isys.apply_identity(&"formation_duo"), "仍应禁止开局")


# ═══════════════════════════════════════════════════════════════════════════════
# 就绪度用真实 CardSystem 口径
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_six_entries_are_ready_against_real_card_system() -> void:
	# Arrange —— 让阵道双杰的解锁条件也满足
	_grant_talent(&"resource_4")

	# Act
	var entries: Array = isys.get_available_identities()

	# Assert
	assert_eq(entries.size(), 6, "应返回 6 条身份条目")
	for entry: Dictionary in entries:
		assert_true(bool(entry["is_ready"]),
				"身份 %s 在真实模板目录下应就绪（block_reason=%s）"
				% [entry["identity_id"], entry.get("block_reason", "")])


func test_legacy_talent_key_still_unlocks_via_public_api() -> void:
	## 既有 AC-005/006 锁的是字面量 cang_xuan_walker——公开 API 必须继续认它。
	# Act
	_grant_talent(&"cang_xuan_walker")

	# Assert
	assert_true(bool(_entry_of(&"formation_duo")["is_unlocked"]),
			"旧口径 require_talent 命中时仍应解锁")


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

func _referenced_ids(tmpl: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry: Dictionary in tmpl["initial_deck"]["cards"]:
		ids.append(StringName(str(entry["card_id"])))
	for entry: Dictionary in tmpl["initial_deck"]["character_slots"]:
		ids.append(StringName(str(entry["card_id"])))
	return ids


## 实例 ID → 模板 ID（从收藏读；找不到返回空串，断言里会明显失败）。
func _template_of(instance_id: int) -> String:
	for owned: Dictionary in gsm.collection.owned_cards:
		if int(owned.get("card_instance_id", -1)) == instance_id:
			return str(owned.get("template_id", ""))
	return ""


func _entry_of(identity_id: StringName) -> Dictionary:
	for entry: Dictionary in isys.get_available_identities():
		if entry["identity_id"] == identity_id:
			return entry
	return {}


## 清空与本用例相关的存档域——每轮从零开始，避免上一轮身份残留。
func _reset_gsm() -> void:
	gsm.player.identity_id = ""
	gsm.player.resources.ling_shi = 0
	gsm.player.talents = []
	gsm.player["talent_map"] = {}
	gsm.deck.current_deck = []
	gsm.deck.slots = [null, null, null, null, null, null]
	gsm.deck.change_log = []
	gsm.deck.session_remove_count = 0
	gsm.deck.deck_limit_modifier = 0
	gsm.collection.owned_cards = []
	gsm.collection.total_count = 0
	gsm.narrative.story_flags = {}
	gsm.set("_next_card_instance_id", 1)
	_signal_received.clear()


## 满足该身份的解锁条件，让它能走到「真落地」那一段。[br]
## [br]身份表的 [code]require_talent[/code]（若有）直接授予；[code]default_unlocked=false[/code]
## 且无 [code]require_talent[/code] 的身份（阵道双杰）授予天赋表里那条声明
## [code]identity_unlock[/code] 指向它的真实天赋——即玩家实际能买到的那条。
func _grant_unlock_for(identity_id: StringName, tmpl: Dictionary) -> void:
	var cond: Dictionary = tmpl["unlock_condition"]
	if bool(cond.get("default_unlocked", true)):
		return
	var required: String = str(cond.get("require_talent", ""))
	if not required.is_empty():
		_grant_talent(StringName(required))
		return
	# 留空 → 靠天赋的 identity_unlock 效果解锁
	for talent_id: String in RTS.TALENT_TREE:
		var effect: Dictionary = RTS.TALENT_TREE[talent_id].get("effect", {})
		if str(effect.get("type", "")) != "identity_unlock":
			continue
		if StringName(str(effect.get("value", ""))) == identity_id:
			_grant_talent(StringName(talent_id))
			return
	fail_test("身份 %s 声明 default_unlocked=false，但天赋表里没有解锁它的天赋" % identity_id)


## 授予一个轮回天赋——先注册定义（若尚未注册），再幂等授予。[br]
## [br][b]天赋表里没有的 ID[/b]（如旧口径的 [code]cang_xuan_walker[/code]）：注册一条
## 最小定义。玩家侧的解锁列表本就可能含有历史遗留的 ID，公开 API 认不认它
## 取决于身份表的字面量，而不是取决于天赋表里有没有这一条。
func _grant_talent(talent_id: StringName) -> void:
	var id: String = str(talent_id)
	var defs: Dictionary = ProgressionSystem.get("_talent_defs")
	if not defs.has(id):
		var def: Dictionary = RTS.TALENT_TREE.get(id, {})
		ProgressionSystem.register_talent(id, def if not def.is_empty()
				else {"id": id, "name": id, "cost": 0})
	ProgressionSystem.grant_talent(id)


## 备好卡牌校验——模板进注册表 + GSM 校验开启（同 test_battle_reward_grant 口径）。
func _prepare_card_validation() -> void:
	var database: Dictionary = gsm.get("_card_template_database")
	for id: StringName in CardSystem.templates.keys():
		database[str(id)] = database.get(str(id), {})
	gsm.set("_card_template_database", database)
	gsm.validation_enabled = true
