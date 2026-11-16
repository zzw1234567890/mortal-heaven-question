extends GutTest
## 身份解锁条件与开局就绪度单元测试（IdentityUnlock 纯函数子模块）。
##
## [b]为什么需要[/b]：身份表里「阵道双杰」的解锁条件是 [code]require_talent[/code] 一个天赋 ID，
## 而真正会被玩家买到的 L4 天赋（[code]resource_4[/code]「苍玄行者」）声明的是
## [code]identity_unlock[/code] 效果——两处口径对不上时，该身份永远锁着，
## 界面看得见却永远开不了局。本文件锁住「两条解锁来源都认」。
##
## [b]就绪度[/b]：解锁 ≠ 可玩。卡组引用的模板缺一张，[code]apply_identity[/code] 就会
## 中途失败回滚——开局前必须先问「模板齐不齐」。
##
## 来源: ADR-0022 §get_available_identities、GDD reincarnation-talent-system.md §5 效果分发、
## GDD identity-selection-system.md §7。

const Unlock := preload("res://src/feature/identity/identity_unlock.gd")
const Templates := preload("res://src/feature/identity/identity_templates.gd")
const RTS := preload("res://src/feature/reincarnation_talent_system.gd")

## 全部模板都在的探测器——用于把「模板齐备性」从断言里隔离出去。
static func _all_templates(_card_id: StringName) -> bool:
	return true


## 全部模板都不在的探测器。
static func _no_templates(_card_id: StringName) -> bool:
	return false


func _formation_duo() -> Dictionary:
	return Templates.IDENTITY_TEMPLATES[&"formation_duo"]


func _azure() -> Dictionary:
	return Templates.IDENTITY_TEMPLATES[&"azure_sword_disciple"]


# ═══════════════════════════════════════════════════════════════════════════════
# 解锁来源 ①：身份表 require_talent
# ═══════════════════════════════════════════════════════════════════════════════

func test_default_unlocked_identity_is_unlocked_with_no_talents() -> void:
	# Act
	var result: bool = Unlock.is_unlocked(_azure()["unlock_condition"],
			&"azure_sword_disciple", [])

	# Assert
	assert_true(result, "default_unlocked=true 的身份无需任何天赋即解锁")


func test_formation_duo_locked_with_no_talents() -> void:
	# Act
	var result: bool = Unlock.is_unlocked(_formation_duo()["unlock_condition"],
			&"formation_duo", [])

	# Assert
	assert_false(result, "阵道双杰在无天赋时应锁定")


func test_legacy_require_talent_key_still_unlocks() -> void:
	## 旧口径（身份表字面量 cang_xuan_walker）必须继续生效——既有 AC-005/006 锁着它。
	# Act
	var result: bool = Unlock.is_unlocked(_formation_duo()["unlock_condition"],
			&"formation_duo", ["cang_xuan_walker"])

	# Assert
	assert_true(result, "require_talent 命中时身份应解锁")


# ═══════════════════════════════════════════════════════════════════════════════
# 解锁来源 ②：轮回天赋 identity_unlock 效果
# ═══════════════════════════════════════════════════════════════════════════════

func test_real_reincarnation_talent_unlocks_formation_duo() -> void:
	## 回归测试（本 bug 的直接守卫）：玩家真正能买到的 L4 天赋 resource_4
	## （苍玄行者）必须解锁阵道双杰——否则「选了也玩不起来」。
	# Arrange
	var def: Dictionary = RTS.TALENT_TREE["resource_4"]
	assert_eq(str(def["effect"]["type"]), "identity_unlock",
			"前置：resource_4 应是身份解锁类天赋（否则本用例空转）")

	# Act
	var result: bool = Unlock.is_unlocked(_formation_duo()["unlock_condition"],
			&"formation_duo", ["resource_4"])

	# Assert
	assert_true(result, "拥有 resource_4（苍玄行者）时阵道双杰应解锁")


func test_talent_effect_value_matches_identity_id() -> void:
	## 天赋效果的 value 必须就是身份 ID——写错（如 array_master）会让效果永远不命中。
	for talent_id: String in RTS.TALENT_TREE:
		var effect: Dictionary = RTS.TALENT_TREE[talent_id].get("effect", {})
		if str(effect.get("type", "")) != Unlock.TALENT_EFFECT_IDENTITY_UNLOCK:
			continue
		var target: StringName = StringName(str(effect.get("value", "")))
		assert_true(Templates.IDENTITY_TEMPLATES.has(target),
				"天赋 %s 声明的 identity_unlock 目标 '%s' 应是身份表里的 ID" % [talent_id, target])


func test_unrelated_talent_does_not_unlock() -> void:
	# Act
	var result: bool = Unlock.is_unlocked(_formation_duo()["unlock_condition"],
			&"formation_duo", ["cultivation_4", "card_4"])

	# Assert
	assert_false(result, "非身份解锁类天赋不得解锁阵道双杰")


func test_empty_identity_id_never_matches_talent_effect() -> void:
	## 空目标会把「效果未写 value」的天赋误判成命中——必须显式挡掉。
	# Act
	var result: bool = Unlock.unlocked_by_talent_effect(&"", ["resource_4"])

	# Assert
	assert_false(result, "空身份 ID 不得与任何天赋效果匹配")


# ═══════════════════════════════════════════════════════════════════════════════
# 就绪度：解锁 ≠ 可玩
# ═══════════════════════════════════════════════════════════════════════════════

func test_referenced_card_ids_covers_deck_and_character_slots() -> void:
	# Act
	var ids: Array[String] = Unlock.referenced_card_ids(_azure())

	# Assert —— 卡组 5 条（含 basic_attack×2 去重后 1 条）+ 角色位 2 名
	assert_eq(ids.size(), 7, "青云剑宗应引用 7 个不同 card_id（5 卡 + 2 角色）")
	assert_true(ids.has("basic_attack"), "应含卡组中的卡")
	assert_true(ids.has("lin_yuan"), "应含角色位上的角色卡")


func test_readiness_true_when_unlocked_and_all_templates_present() -> void:
	# Act
	var result: Dictionary = Unlock.readiness(_azure(), &"azure_sword_disciple", [],
			_all_templates)

	# Assert
	assert_true(bool(result["is_ready"]), "解锁且模板齐备时应就绪")
	assert_eq(result["block_reason"], Unlock.BLOCK_NONE, "就绪时无阻断原因")
	assert_eq(result["missing_templates"], [], "就绪时无缺失模板")


func test_readiness_false_and_lists_missing_templates() -> void:
	## 卡组里有一张模板缺失 → 不就绪，且缺失清单点名到具体 card_id。
	# Arrange —— 只缺 ying_ci（青云剑宗的影刺）
	var probe := func(card_id: StringName) -> bool: return card_id != &"ying_ci"

	# Act
	var result: Dictionary = Unlock.readiness(_azure(), &"azure_sword_disciple", [],
			probe)

	# Assert
	assert_false(bool(result["is_ready"]), "有模板缺失时不应就绪")
	assert_eq(result["block_reason"], Unlock.BLOCK_TEMPLATES_MISSING, "阻断原因应为模板缺失")
	assert_eq(result["missing_templates"], ["ying_ci"], "缺失清单应点名 ying_ci")


func test_readiness_locked_identity_reports_locked_not_missing() -> void:
	## 未解锁优先于模板缺失——提示文案要指向「去解锁」，不是「资产没做好」。
	# Act
	var result: Dictionary = Unlock.readiness(_formation_duo(), &"formation_duo", [],
			_no_templates)

	# Assert
	assert_false(bool(result["is_unlocked"]), "无天赋时应判未解锁")
	assert_false(bool(result["is_ready"]), "未解锁必然不就绪")
	assert_eq(result["block_reason"], Unlock.BLOCK_LOCKED, "阻断原因应为未解锁")


func test_readiness_unlocked_identity_with_no_templates_is_not_ready() -> void:
	# Act
	var result: Dictionary = Unlock.readiness(_formation_duo(), &"formation_duo",
			["resource_4"], _no_templates)

	# Assert
	assert_true(bool(result["is_unlocked"]), "有 resource_4 时应解锁")
	assert_false(bool(result["is_ready"]), "模板全缺时不应就绪")
	assert_eq(result["block_reason"], Unlock.BLOCK_TEMPLATES_MISSING,
			"已解锁但资产缺失应报模板缺失")


func test_readiness_unknown_identity_reports_unknown() -> void:
	# Act
	var result: Dictionary = Unlock.readiness({}, &"no_such_identity", [], _all_templates)

	# Assert
	assert_false(bool(result["is_ready"]), "身份表查无时不应就绪")
	assert_eq(result["block_reason"], Unlock.BLOCK_UNKNOWN_IDENTITY, "应报身份未知")


func test_readiness_with_invalid_probe_is_not_ready() -> void:
	## 探测 Callable 无效（CardSystem 不可用）＝无法校验 → 拦住，绝不放行。
	# Act
	var result: Dictionary = Unlock.readiness(_azure(), &"azure_sword_disciple", [],
			Callable())

	# Assert
	assert_false(bool(result["is_ready"]), "无法校验模板时不应就绪")
	assert_eq(result["block_reason"], Unlock.BLOCK_TEMPLATES_MISSING,
			"无法校验归入模板缺失（提示暂未开放）")
	assert_eq(result["missing_templates"].size(), 7, "无法校验时列出全部待查 card_id")


func test_all_six_identities_ready_with_full_template_set() -> void:
	## 六身份在「模板全在」前提下都应就绪——含 default_unlocked=false 的阵道双杰
	## 在天赋到位时同样就绪。
	# Arrange
	var unlocked: Array[String] = ["resource_4"]

	# Act + Assert
	for id: StringName in Templates.IDENTITY_TEMPLATES:
		var result: Dictionary = Unlock.readiness(Templates.IDENTITY_TEMPLATES[id], id,
				unlocked, _all_templates)
		assert_true(bool(result["is_ready"]), "身份 %s 在模板齐备 + 天赋到位时应就绪" % id)
