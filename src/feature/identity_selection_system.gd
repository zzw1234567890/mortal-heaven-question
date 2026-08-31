extends Node
## IdentitySelectionSystem —— 开局身份选择系统 Autoload（ADR-0022 #21）。
##
## Feature 层 Autoload。持有 6 个身份模板的 const Dictionary + 查询 API。[br]
## 身份选择是每局游戏的第一个决策点——6 种预设身份（5 默认 + 1 轮回解锁），[br]
## 每种绑定固定初始卡组、两名初始角色、专属天赋和初始灵石。[br]
## 不持有运行时可变状态——身份选择完成后所有状态存 GSM。[br]
## [br][b]Story 6-1 范围[/b]：身份模板表 + get_available_identities + get_identity_preview。[br]
## [b]已注册进 project.godot[/b]——Autoload（IdentitySelectionSystem）。[br]
## [br]来源: ADR-0022 §关键接口 / GDD identity-selection-system.md §1-2。


# === 信号（Cat 2b）=============================================================

## 身份选择完成信号——apply_identity() 全部初始状态写入后发射（Story 6-2 实现）。[br]
## [br][param identity_id] 已选择的身份 ID。[br]
## [br]来源: ADR-0022 §信号定义。
signal identity_selected(identity_id: StringName)


# === 身份模板表（const Dictionary——编译时常量，运行时只读）=====================

## 6 个开局身份模板——单一真理来源（ADR-0022）。[br]
## 键 = 身份 ID（StringName），值 = 模板 Dictionary。[br]
## [br]来源: GDD identity-selection-system.md §2 六种身份详细定义。
const IDENTITY_TEMPLATES: Dictionary = {
	# ① 青云剑宗·外门弟子——续航型，新手推荐
	&"azure_sword_disciple": {
		"name": "青云剑宗·外门弟子",
		"description": "青云剑宗记名弟子，资质平庸但心志坚韧，擅长稳扎稳打、步步为营的战术",
		"flavor_text": "你出身贫寒，被三叔推荐拜入青云剑宗外门，后被墨渊收为弟子传授枯木逢春诀。与你一同入门的好友苏剑鸣天赋异禀、武艺过人，两人在青云剑宗的艰难修行中结下了生死之交……",
		"style_tag": "续航",
		"recommended_for_new_player": true,
		"playstyle_hint": "防御续航型，适合新手稳扎稳打",
		"initial_deck": {
			"cards": [
				{"card_id": "ku_mu_feng_chun_jue", "count": 1},
				{"card_id": "yan_yun_bu", "count": 1},
				{"card_id": "ying_ci", "count": 1},
				{"card_id": "basic_attack", "count": 2},
				{"card_id": "jian_yi_hu_dun", "count": 2},
			],
			"character_slots": [
				{"card_id": "lin_yuan", "slot_index": 1},
				{"card_id": "su_jian_ming", "slot_index": 2},
			],
		},
		"initial_resources": {"ling_shi": 15},
		"talent": {
			"id": "ling_shi_boost",
			"name": "财源广进",
			"description": "探索地图时灵石掉落量+15%",
			"magnitude": 15,
		},
		"character_details": [
			{"card_id": "lin_yuan", "display_name": "林渊", "level": 1},
			{"card_id": "su_jian_ming", "display_name": "苏剑鸣", "level": 1},
		],
		"unlock_condition": {"default_unlocked": true, "require_talent": ""},
	},
	# ② 血海殿遗孤——快攻型
	&"blood_sea_orphan": {
		"name": "血海殿遗孤",
		"description": "出身血海殿魔道世家，在苍玄正魔大战中家族败落，带着家传秘术流亡他乡，信奉先下手为强的生存哲学",
		"flavor_text": "血海殿在苍玄正魔大战中节节败退那年，你的家族被卷入内斗和外敌的双重漩涡。父亲临死前将家传万魂幡塞到你手中：「活下去，别让血海殿的血仇无人知晓。」你擦干眼泪，踏上了以杀证道的复仇之路……",
		"style_tag": "快攻",
		"recommended_for_new_player": false,
		"playstyle_hint": "快攻侵略型，靠抢先击杀控制节奏",
		"initial_deck": {
			"cards": [
				{"card_id": "wan_hun_fan", "count": 1},
				{"card_id": "you_ying_bu", "count": 1},
				{"card_id": "sha_qi_zhan", "count": 2},
				{"card_id": "xue_sha_zhang", "count": 1},
				{"card_id": "basic_attack", "count": 2},
			],
			"character_slots": [
				{"card_id": "yin_ruo_han", "slot_index": 1},
				{"card_id": "tu_ye", "slot_index": 2},
			],
		},
		"initial_resources": {"ling_shi": 10},
		"talent": {
			"id": "first_strike_extra_cost",
			"name": "杀意沸腾",
			"description": "战斗首回合+1额外费用",
			"magnitude": 1,
		},
		"character_details": [
			{"card_id": "yin_ruo_han", "display_name": "殷若寒", "level": 1},
			{"card_id": "tu_ye", "display_name": "屠夜", "level": 1},
		],
		"unlock_condition": {"default_unlocked": true, "require_talent": ""},
	},
	# ③ 碎星群岛散修——灵活型
	&"star_isles_wanderer": {
		"name": "碎星群岛散修",
		"description": "在碎星群岛摸爬滚打多年的散修，没有门派靠山，靠的是一身灵活多变的本事和发现机缘的敏锐嗅觉",
		"flavor_text": "你在碎星群岛的岛屿间漂泊多年，见过无数修士为了一点资源争得你死我活。你学到的只有一件事：活着的散修才是好散修。今天你听说东域某个遗迹即将开启，决定去看看……",
		"style_tag": "灵活",
		"recommended_for_new_player": false,
		"playstyle_hint": "灵活多变型，经济和发展潜力最大",
		"initial_deck": {
			"cards": [
				{"card_id": "huan_hua_mi_zong_bu", "count": 1},
				{"card_id": "yin_po_ning_hun_shu", "count": 1},
				{"card_id": "jian_bo_zhan", "count": 2},
				{"card_id": "xun_bao_fu", "count": 1},
				{"card_id": "basic_attack", "count": 2},
			],
			"character_slots": [
				{"card_id": "xi_yin", "slot_index": 1},
				{"card_id": "mu_yao", "slot_index": 2},
			],
		},
		"initial_resources": {"ling_shi": 18},
		"talent": {
			"id": "re_forge_opportunity",
			"name": "星海机缘",
			"description": "每张地图首次事件可选择「重投」（重新随机一次事件结果，限1次/图）",
			"magnitude": 1,
		},
		"character_details": [
			{"card_id": "xi_yin", "display_name": "汐音", "level": 1},
			{"card_id": "mu_yao", "display_name": "沐瑶", "level": 1},
		],
		"unlock_condition": {"default_unlocked": true, "require_talent": ""},
	},
	# ④ 玄冰宫弟子——控制型
	&"frost_palace_disciple": {
		"name": "玄冰宫弟子",
		"description": "正道大宗玄冰宫的嫡传弟子，修炼寒玉轮回功，擅长冰系法术和防御阵型",
		"flavor_text": "玄冰宫作为苍玄正道七宗之一，对弟子的要求极高。你与师姐凌霜月自幼一起修习寒玉轮回功，两人在宗门内以防守稳健著称。这日宗门令你与凌霜月一同下山历练，斩妖除魔……",
		"style_tag": "控制",
		"recommended_for_new_player": false,
		"playstyle_hint": "控制型，冰系减速+冰冻让敌人行动效率大幅降低",
		"initial_deck": {
			"cards": [
				{"card_id": "han_yu_lun_hui_gong", "count": 1},
				{"card_id": "shuang_po_jian_jue", "count": 1},
				{"card_id": "bing_leng_ci", "count": 2},
				{"card_id": "jin_zhong_fu", "count": 1},
				{"card_id": "basic_attack", "count": 2},
			],
			"character_slots": [
				{"card_id": "ling_shuang_yue", "slot_index": 1},
				{"card_id": "jiang_xue", "slot_index": 2},
			],
		},
		"initial_resources": {"ling_shi": 15},
		"talent": {
			"id": "frost_guard_shield",
			"name": "寒冰庇护",
			"description": "每次进入战斗时，全体友方获得「护盾2」（吸收2点伤害后消失）",
			"magnitude": 2,
		},
		"character_details": [
			{"card_id": "ling_shuang_yue", "display_name": "凌霜月", "level": 1},
			{"card_id": "jiang_xue", "display_name": "姜雪", "level": 1},
		],
		"unlock_condition": {"default_unlocked": true, "require_talent": ""},
	},
	# ⑤ 丹霞谷弟子——辅助型
	&"crimson_valley_disciple": {
		"name": "丹霞谷弟子",
		"description": "丹霞谷外门弟子，师从李元化一脉，擅长丹药炼制和辅助功法，以稳健的团队作战著称",
		"flavor_text": "丹霞谷在苍玄正道七宗中以丹道闻名。你虽只是外门弟子，但在炼丹一道上颇有心德。这一日你领了师门任务，与师姐方灵素一同下山历练……",
		"style_tag": "辅助",
		"recommended_for_new_player": false,
		"playstyle_hint": "丹药辅助型，可控回复+防御叠加",
		"initial_deck": {
			"cards": [
				{"card_id": "san_yuan_ju_qi_gong", "count": 1},
				{"card_id": "dan_xia_jian_qi", "count": 1},
				{"card_id": "zhu_ji_dan", "count": 1},
				{"card_id": "basic_attack", "count": 2},
				{"card_id": "pei_yuan_dan", "count": 2},
			],
			"character_slots": [
				{"card_id": "fang_ling_su", "slot_index": 1},
				{"card_id": "shi_yan", "slot_index": 2},
			],
		},
		"initial_resources": {"ling_shi": 14},
		"talent": {
			"id": "alchemy_affinity",
			"name": "丹心妙手",
			"description": "丹药卡在商店和战利品中出现概率+20%（相对加成）；丹药卡使用效果+10%",
			"magnitude": 20,
		},
		"character_details": [
			{"card_id": "fang_ling_su", "display_name": "方灵素", "level": 1},
			{"card_id": "shi_yan", "display_name": "石岩", "level": 1},
		],
		"unlock_condition": {"default_unlocked": true, "require_talent": ""},
	},
	# ⑥ 阵道双杰——运营型，轮回解锁
	&"formation_duo": {
		"name": "阵道双杰",
		"description": "一对痴迷阵法的年轻道侣，虽修为不高但在阵道上天赋异禀，能以精妙的阵法弥补修为差距",
		"flavor_text": "你与道侣慕星河痴迷于天下各种古阵法的研究。两人联手破解过不止一座上古遗迹的守护大阵。这次听说东域深处有一座完整的上古遗迹，你们对视一眼——「走？」「走！」",
		"style_tag": "运营",
		"recommended_for_new_player": false,
		"playstyle_hint": "运营型，阵法减费+万象阵典让2人当4人用",
		"initial_deck": {
			"cards": [
				{"card_id": "wan_xiang_zhen_dian", "count": 1},
				{"card_id": "qi_xing_kun_long_zhen", "count": 1},
				{"card_id": "yin_yang_shou_yu_zhen", "count": 1},
				{"card_id": "jin_qian_biao", "count": 2},
				{"card_id": "basic_attack", "count": 1},
			],
			"character_slots": [
				{"card_id": "mu_xing_he", "slot_index": 1},
				{"card_id": "yun_su_xin", "slot_index": 2},
			],
		},
		"initial_resources": {"ling_shi": 25},
		"talent": {
			"id": "formation_master",
			"name": "阵法精通",
			"description": "阵法激活所需人数条件-1（对任何阵法均有效）",
			"magnitude": 1,
		},
		"character_details": [
			{"card_id": "mu_xing_he", "display_name": "慕星河", "level": 1},
			{"card_id": "yun_su_xin", "display_name": "云素心", "level": 1},
		],
		"unlock_condition": {"default_unlocked": false, "require_talent": "cang_xuan_walker"},
	},
}


# === 内部状态 ====================================================================

## 可注入 ProgressionSystem 引用——测试时设置，绕过 Autoload 查找（同 TribulationSystem _combat_override 模式）。
var _progression_override: Node = null

## 可注入 CardSystem 引用——测试时设置，绕过 Autoload 查找。
var _card_override: Node = null

## 可注入 ResourceSystem 引用——测试时设置，绕过 Autoload 查找。
var _resource_override: Node = null

## 可注入 DeckEditingSystem 引用——测试时设置，绕过 Autoload 查找。
var _deck_override: Node = null


# === 查询 API ====================================================================

## 查询可用身份列表——结合轮回天赋解锁状态。[br]
## [br][b]返回[/b]: Array[Dictionary]，每个条目含：[br]
## [code]{identity_id, name, description, style_tag, initial_ling_shi,[br]
##   talent_name, talent_desc, character_display_names, is_unlocked, is_recommended}[/code][br]
## [br][b]ProgressionSystem 不可用时[/b]: 5 个默认身份解锁，阵道双杰锁定。[br]
## [br]来源: ADR-0022 §get_available_identities + GDD §7 身份影响范围。
func get_available_identities() -> Array[Dictionary]:
	var unlocked: Array[String] = _get_unlocked_talents()
	var result: Array[Dictionary] = []

	for id: StringName in IDENTITY_TEMPLATES:
		var tmpl: Dictionary = IDENTITY_TEMPLATES[id]
		var cond: Dictionary = tmpl["unlock_condition"]

		var is_unlocked: bool = cond.get("default_unlocked", true)
		if not is_unlocked:
			var required: String = str(cond.get("require_talent", ""))
			if required != "" and required in unlocked:
				is_unlocked = true

		var entry: Dictionary = {
			"identity_id": id,
			"name": tmpl["name"],
			"description": tmpl["description"],
			"style_tag": tmpl["style_tag"],
			"initial_ling_shi": tmpl["initial_resources"]["ling_shi"],
			"talent_name": tmpl["talent"]["name"],
			"talent_desc": tmpl["talent"]["description"],
			"character_display_names": _get_character_names(tmpl),
			"is_unlocked": is_unlocked,
			"is_recommended": tmpl.get("recommended_for_new_player", false),
		}
		result.append(entry)

	return result


## 获取完整身份预览——供 UI 预览面板使用。[br]
## [br][param identity_id] 身份 ID。[br]
## [br][b]返回[/b]: 完整模板 Dictionary（含所有字段），无效 ID 返回空字典。[br]
## [br]来源: ADR-0022 §get_identity_preview。
func get_identity_preview(identity_id: StringName) -> Dictionary:
	var tmpl: Dictionary = IDENTITY_TEMPLATES.get(identity_id, {})
	if tmpl.is_empty():
		return {}

	return {
		"identity_id": identity_id,
		"name": tmpl["name"],
		"description": tmpl["description"],
		"flavor_text": tmpl["flavor_text"],
		"style_tag": tmpl["style_tag"],
		"initial_deck_cards": tmpl["initial_deck"]["cards"],
		"character_slots": tmpl["initial_deck"]["character_slots"],
		"character_details": tmpl["character_details"],
		"initial_ling_shi": tmpl["initial_resources"]["ling_shi"],
		"talent": tmpl["talent"],
		"unlock_condition": tmpl["unlock_condition"],
		"playstyle_hint": tmpl.get("playstyle_hint", ""),
	}


# === 工具方法（Story 6-3 占位——Story 6-2/6-3 实现）===========================

## 检查是否已选择身份——读 GSM.player.identity_id。[br]
## [br][b]返回[/b]: true 已选择，false 未选择。[br]
## [br]来源: ADR-0022 §is_identity_selected。
func is_identity_selected() -> bool:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return false
	return not str(gsm.player.identity_id).is_empty()


## 获取当前已选身份 ID——读 GSM.player.identity_id。[br]
## [br][b]返回[/b]: StringName 身份 ID，未选择时返回空 StringName。[br]
## [br]来源: ADR-0022 §get_current_identity。
func get_current_identity() -> StringName:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return &""
	return StringName(gsm.player.identity_id)


## 查询身份天赋值——从 GSM.player.talent_map 查（apply_identity 写入）。[br]
## [br][param talent_id] 天赋 ID。[br]
## [br][b]返回[/b]: 天赋 magnitude 值，未注册返回 0。[br]
## [br]来源: ADR-0022 §get_identity_talent_value + GDD §公式#1 天赋效果注册。
func get_identity_talent_value(talent_id: StringName) -> int:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return 0
	var talent_map: Dictionary = gsm.player.get("talent_map", {})
	return int(talent_map.get(talent_id, 0))


# === apply_identity 原子操作（Story 6-2）=========================================

## 应用身份——编排多系统写入的原子操作。[br]
## [br][param identity_id] 身份 ID。[br]
## [br][b]返回[/b]: [code]true[/code] 成功，[code]false[/code] 失败（GSM 不变或已回滚）。[br]
## [br][b]流程[/b]（ADR-0022 §apply_identity 8 步原子操作）:[br]
##   ① 验证 identity_id 有效 + 已解锁[br]
##   ② 验证所有 card_id 在 CardSystem.templates 中存在[br]
##   ③ 写入 GSM.player.identity_id[br]
##   ④ 设置初始灵石——通过 ResourceSystem（ADR-0019 强制契约）[br]
##   ⑤ 创建初始卡牌实例——通过 CardSystem + DeckEditingSystem[br]
##   ⑥ 创建初始角色实例——写入 deck.slots[br]
##   ⑦ 注册身份天赋——写入 GSM talent_map[br]
##   ⑧ 写入开局叙事文本 + 发射 identity_selected 信号[br]
## [br][b]回滚[/b]: ResourceSystem 失败时回滚 identity_id 为空字符串。[br]
## [br]来源: ADR-0022 §apply_identity + GDD §3 身份选择流程。
func apply_identity(identity_id: StringName) -> bool:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_error("IdentitySelectionSystem.apply_identity: GSM 不可用")
		return false

	# ① 前置校验——identity_id 有效
	var tmpl: Dictionary = IDENTITY_TEMPLATES.get(identity_id, {})
	if tmpl.is_empty():
		push_error("IdentitySelectionSystem.apply_identity: 未知 identity_id '%s'" % identity_id)
		return false

	# 校验解锁状态
	var available: Array[Dictionary] = get_available_identities()
	var is_unlocked: bool = false
	for entry: Dictionary in available:
		if entry["identity_id"] == identity_id and entry["is_unlocked"]:
			is_unlocked = true
			break
	if not is_unlocked:
		push_error("IdentitySelectionSystem.apply_identity: 身份 '%s' 未解锁" % identity_id)
		return false

	# ② 校验所有卡牌模板有效性——通过 CardSystem
	var card_sys: Node = _get_card_system()
	if card_sys == null or not card_sys.has_method("has_template"):
		push_error("IdentitySelectionSystem.apply_identity: CardSystem 不可用")
		return false
	for card_entry: Dictionary in tmpl["initial_deck"]["cards"]:
		var card_id: String = str(card_entry["card_id"])
		if not card_sys.has_template(StringName(card_id)):
			push_error("IdentitySelectionSystem.apply_identity: 卡牌模板缺失 '%s'" % card_id)
			return false
	for char_entry: Dictionary in tmpl["initial_deck"]["character_slots"]:
		var char_id: String = str(char_entry["card_id"])
		if not card_sys.has_template(StringName(char_id)):
			push_error("IdentitySelectionSystem.apply_identity: 角色模板缺失 '%s'" % char_id)
			return false

	# ③ 写入 GSM.player.identity_id（先写以满足"选择身份"语义）
	gsm.set_identity(identity_id)

	# ④ 设置初始灵石——通过 ResourceSystem（ADR-0019 强制契约）
	var ling_shi: int = int(tmpl["initial_resources"]["ling_shi"])
	var res_sys: Node = _get_resource_system()
	if res_sys == null or not res_sys.has_method("add_resource"):
		push_error("IdentitySelectionSystem.apply_identity: ResourceSystem 不可用")
		_rollback_identity(gsm)
		return false
	if not res_sys.add_resource(&"ling_shi", ling_shi):
		push_error("IdentitySelectionSystem.apply_identity: 设置初始灵石失败")
		_rollback_identity(gsm)
		return false

	# ⑤ 创建初始卡牌实例——通过 CardSystem + DeckEditingSystem
	_create_initial_cards(tmpl["initial_deck"]["cards"])

	# ⑥ 创建初始角色实例——写入 deck.slots
	_create_initial_characters(tmpl["initial_deck"]["character_slots"])

	# ⑦ 注册身份天赋——写入 GSM talent_map
	var talent_def: Dictionary = tmpl["talent"]
	gsm.set_talent(StringName(talent_def["id"]), int(talent_def["magnitude"]))

	# ⑧ 写入开局叙事文本 + 发射 identity_selected 信号
	gsm.set_narrative_flag(&"opening_text", tmpl["flavor_text"])
	_emit_safe(&"identity_selected", [identity_id])

	return true


## 创建初始卡牌实例——通过 CardSystem.create_instance + DeckEditingSystem.add_cards_to_deck。[br]
## [br][param cards_def] 卡牌定义数组 [{card_id, count}]。[br]
## [br]来源: ADR-0022 §apply_identity ⑤。
func _create_initial_cards(cards_def: Array) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return
	var card_sys: Node = _get_card_system()
	if card_sys == null or not card_sys.has_method("create_instance"):
		return
	var deck_sys: Node = _get_deck_editing_system()

	var card_instance_ids: Array = []
	for card_entry: Dictionary in cards_def:
		var card_id: String = str(card_entry["card_id"])
		var count: int = int(card_entry["count"])
		for _i: int in range(count):
			var inst = card_sys.create_instance(StringName(card_id))
			if inst != null:
				var inst_id: int = inst.get("card_instance_id") if "card_instance_id" in inst else int(inst.card_instance_id)
				# 写入收藏
				if gsm.has_method("add_card_to_collection"):
					var inst_dict: Dictionary = {
						"card_instance_id": inst_id,
						"template_id": card_id,
						"level": 1,
						"inscriptions": [],
						"breakthrough_layers": 0,
						"binding_target_id": &"",
						"acquired_chapter": 0,
						"acquired_event_id": &"",
						"acquired_method": 0,
					}
					gsm.add_card_to_collection(inst_dict)
				card_instance_ids.append(inst_id)

	# 写入 deck.current_deck——通过 DeckEditingSystem.initialize_initial_deck
	if deck_sys != null and deck_sys.has_method("initialize_initial_deck"):
		deck_sys.initialize_initial_deck(card_instance_ids)
		# initialize_initial_deck 已重置 slots，角色位在 ⑥ 中写入


## 创建初始角色实例——写入 deck.slots。[br]
## [br][param char_slots_def] 角色位数组 [{card_id, slot_index}]。[br]
## [br]来源: ADR-0022 §apply_identity ⑥。
func _create_initial_characters(char_slots_def: Array) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return
	var card_sys: Node = _get_card_system()
	if card_sys == null or not card_sys.has_method("create_instance"):
		return

	# 读取当前 slots（initialize_initial_deck 已重置为 [null×6]）
	var slots: Array = gsm.deck.get("slots", [null, null, null, null, null, null]).duplicate()
	for char_entry: Dictionary in char_slots_def:
		var char_id: String = str(char_entry["card_id"])
		var slot_idx: int = int(char_entry["slot_index"])
		var inst = card_sys.create_instance(StringName(char_id))
		if inst != null:
			var inst_id: int = inst.get("card_instance_id") if "card_instance_id" in inst else int(inst.card_instance_id)
			# 写入收藏
			if gsm.has_method("add_card_to_collection"):
				var inst_dict: Dictionary = {
					"card_instance_id": inst_id,
					"template_id": char_id,
					"level": 1,
					"inscriptions": [],
					"breakthrough_layers": 0,
					"binding_target_id": &"",
					"acquired_chapter": 0,
					"acquired_event_id": &"",
					"acquired_method": 0,
				}
				gsm.add_card_to_collection(inst_dict)
			# 写入 slot（slot_index 从 1 开始 → 数组索引 0 开始）
			if slot_idx >= 1 and slot_idx <= slots.size():
				slots[slot_idx - 1] = inst_id

	# 通过 GSM 第二层原子写入 slots
	if gsm.has_method("_set_deck_slots"):
		gsm._set_deck_slots(slots)


## 获取 CardSystem 引用——优先使用注入的覆盖引用，否则通过 SceneTree Autoload 查找。[br]
## [br][b]返回[/b]: CardSystem 节点或 null（未注册时）。
func _get_card_system() -> Node:
	if _card_override != null and is_instance_valid(_card_override):
		return _card_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/CardSystem")


## 获取 ResourceSystem 引用——优先使用注入的覆盖引用，否则通过 SceneTree Autoload 查找。[br]
## [br][b]返回[/b]: ResourceSystem 节点或 null（未注册时）。
func _get_resource_system() -> Node:
	if _resource_override != null and is_instance_valid(_resource_override):
		return _resource_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/ResourceSystem")


## 获取 DeckEditingSystem 引用——优先使用注入的覆盖引用，否则通过 SceneTree Autoload 查找。[br]
## [br][b]返回[/b]: DeckEditingSystem 节点或 null（未注册时）。
func _get_deck_editing_system() -> Node:
	if _deck_override != null and is_instance_valid(_deck_override):
		return _deck_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/DeckEditingSystem")


# === 内部辅助 ====================================================================

## 获取身份的角色显示名列表——从 character_details 提取。[br]
## [br][param tmpl] 身份模板 Dictionary。[br]
## [br][b]返回[/b]: Array[String] 角色显示名列表。
func _get_character_names(tmpl: Dictionary) -> Array[String]:
	var names: Array[String] = []
	var details: Array = tmpl.get("character_details", [])
	for detail: Dictionary in details:
		names.append(str(detail.get("display_name", "")))
	return names


## 获取已解锁的轮回天赋列表——从 ProgressionSystem 查询。[br]
## [br][b]ProgressionSystem 不可用时[/b]返回空数组（5 个默认身份仍解锁）。[br]
## [br]来源: ADR-0022 §get_available_identities 依赖 ProgressionSystem。
func _get_unlocked_talents() -> Array[String]:
	var prog: Node = _get_progression_system()
	if prog == null:
		return []
	if not prog.has_method("get_talent_tree_state"):
		return []
	var state: Dictionary = prog.get_talent_tree_state()
	var unlocked: Array = state.get("unlocked", [])
	var result: Array[String] = []
	for t: Variant in unlocked:
		result.append(str(t))
	return result


## 获取 ProgressionSystem 引用——优先使用注入的覆盖引用，否则通过 SceneTree Autoload 查找。[br]
## [br][b]返回[/b]: ProgressionSystem 节点或 null（未注册时）。
func _get_progression_system() -> Node:
	if _progression_override != null and is_instance_valid(_progression_override):
		return _progression_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/ProgressionSystem")


## 获取 GSM 引用——通过 SceneTree Autoload（同 TribulationSystem/DeckEditingSystem 模式）。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


## Cat 2b 信号安全发射——经 GSM._emit_signal_safe 路由（ADR-0007 信号链深度追踪）。[br]
## [br][b]GSM 不可用时回退[/b]到直接 emit_signal + push_warning 告警。[br]
## [br]来源: ADR-0022 §信号分类 / ADR-0007 §_emit_signal_safe（同 TribulationSystem 模式）。
func _emit_safe(signal_name: StringName, args: Array) -> void:
	var gsm = _get_gsm()
	if gsm != null and gsm.has_method("_emit_signal_safe"):
		gsm._emit_signal_safe(self, signal_name, args)
		return
	push_warning("IdentitySelectionSystem: GSM 不可用，%s 信号绕过 _emit_signal_safe 路由" % signal_name)
	var call_args: Array = [signal_name]
	call_args.append_array(args)
	callv("emit_signal", call_args)


## 回滚 identity_id——set_identity 去重导致空字符串无法覆盖已有值。[br]
## [br]GSM.set_identity 内部对相同值去重，已写入的 identity_id 无法用空字符串覆盖[br]
## （因为 old_val != "" 时虽然不等，但写入后 _set_by_path 的路径校验会阻止空值）。[br]
## [br]此方法直接操作 GSM.player.identity_id + buffer_change 绕过去重。[br]
## [br]来源: ADR-0022 §apply_identity 回滚策略。
func _rollback_identity(gsm: Node) -> void:
	var old_val: String = str(gsm.player.identity_id)
	if old_val.is_empty():
		return  # 本来就空，无需回滚
	gsm.player.identity_id = ""
	gsm._buffer_change("player.identity_id", old_val, "")
