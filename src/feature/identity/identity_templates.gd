extends RefCounted
## IdentityTemplates —— 身份模板表子模块（从 identity_selection_system.gd 拆分）。
##
## 纯 const Dictionary 容器——不持有运行时状态。
## 包含 6 个开局身份模板常量（单一真理来源 ADR-0022）。
##
## [br]来源: ADR-0022 §关键接口 / GDD identity-selection-system.md §2。
## [br]Sprint 12 Story 013：从 identity_selection_system.gd 拆分。


# === 身份模板表（const Dictionary——编译时常量，运行时只读）=====================

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


# === 模板查询辅助 ================================================================

## 获取身份的角色显示名列表——从 character_details 提取。
static func get_character_names(tmpl: Dictionary) -> Array[String]:
	var names: Array[String] = []
	var details: Array = tmpl.get("character_details", [])
	for detail: Dictionary in details:
		names.append(str(detail.get("display_name", "")))
	return names
