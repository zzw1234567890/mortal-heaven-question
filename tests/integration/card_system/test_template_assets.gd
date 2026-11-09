extends GutTest
## 卡牌模板资产验收测试：真实模板目录（[code]assets/cards/templates/[/code]）对全部 6 个身份可用。[br]
## [br][b]背景[/b]：DEBT-CBT-018-5 修复「模板目录不存在 → 角色卡 HP 0/0」时只落了身份①的 7 张；
## DEBT-CBT-018-6 补齐其余 5 个身份的 30 张（模板总数 37）。本文件锁住四件事：[br]
##   1. 真实目录能加载出全部模板，且未进降级态（目录/字段坏了会先在这里红）；[br]
##   2. 逐张字段自洽（类型/稀有度/费用；角色卡 HP·ATK 为正、阵营标签已注册；[br]
##      [code]effect_type[/code] 非空时 [code]effect_value[/code] 必为正）；[br]
##   3. [b]六个身份[/b]的开局卡组引用的 [code]card_id[/code] 全部有模板（逐身份断言，不硬编码清单
##      ——从 [code]identity_templates.gd[/code] 推导，身份表改了这里自动跟随）；[br]
##   4. 角色卡数值与 GDD 一致，且能经 [code]CombatRosterState[/code] /
##      [code]CombatActorReader[/code] 读成真实数值（不再是 0/0）。[br]
## [br][b]数值唯一真理来源[/b]：[code]design/gdd/identity-selection-system.md[/code] §①~§⑥ 的
## 「初始角色」表与「初始卡牌详情」表。`card-system-design.md` 与之冲突，按 DEBT-CBT-018-7 只登记不采用。[br]
## [br]用独立实例而非 Autoload——其它测试会对 [code]/root/CardSystem[/code] 注入夹具，共用会互相污染。

const CS_SCRIPT: GDScript = preload("res://src/core/card_system/card_system.gd")
const CardTemplateClass: GDScript = preload("res://src/core/card_system/card_template.gd")
const IdentityTemplates: GDScript = preload("res://src/feature/identity/identity_templates.gd")
const RosterState: GDScript = preload("res://src/feature/combat/combat_roster_state.gd")
const ActorReader: GDScript = preload("res://src/ui/combat/layout/combat_actor_reader.gd")
## 阵营注册表——角色卡的 faction_tags 必须是已注册标签（拼错会让阵法/流派判定静默失效）。
const FactionSystemScript: GDScript = preload("res://src/core/faction_system.gd")

## 全部 12 名初始角色的 HP/ATK——GDD identity-selection-system.md §①~§⑥「初始角色」表逐字抄录。
const EXPECTED_CHARACTER_STATS: Dictionary = {
	# ① 青云剑宗·外门弟子
	&"lin_yuan": {"hp": 10, "attack": 2},
	&"su_jian_ming": {"hp": 7, "attack": 4},
	# ② 血海殿遗孤
	&"yin_ruo_han": {"hp": 9, "attack": 3},
	&"tu_ye": {"hp": 8, "attack": 4},
	# ③ 碎星群岛散修
	&"xi_yin": {"hp": 9, "attack": 3},
	&"mu_yao": {"hp": 8, "attack": 3},
	# ④ 玄冰宫弟子
	&"ling_shuang_yue": {"hp": 10, "attack": 3},
	&"jiang_xue": {"hp": 9, "attack": 2},
	# ⑤ 丹霞谷弟子
	&"fang_ling_su": {"hp": 9, "attack": 3},
	&"shi_yan": {"hp": 10, "attack": 2},
	# ⑥ 阵道双杰
	&"mu_xing_he": {"hp": 9, "attack": 3},
	&"yun_su_xin": {"hp": 8, "attack": 2},
}

## 全部 25 张非角色卡牌的 类型/稀有度/费用——GDD 各身份「初始卡牌详情」表的
## 「类型·稀有度·费用」列。类型取 CardTemplate.CardType 枚举（0..5），
## 稀有度取 Rarity（白=1 蓝=2 紫=3）。角色卡数值见 EXPECTED_CHARACTER_STATS。
## [br]注：[code]basic_attack[/code] 的 GDD 类型是「普通」——CardType 无此枚举，
## 暂取 TALISMAN(5)，待 ADR 追加（DEBT-CBT-018-8）。
const EXPECTED_CARD_FIELDS: Dictionary = {
	# ① 青云剑宗·外门弟子
	&"ku_mu_feng_chun_jue": {"type": 1, "rarity": 2, "cost": 1},
	&"yan_yun_bu": {"type": 1, "rarity": 2, "cost": 1},
	&"ying_ci": {"type": 1, "rarity": 1, "cost": 1},
	&"basic_attack": {"type": 5, "rarity": 1, "cost": 0},
	&"jian_yi_hu_dun": {"type": 5, "rarity": 1, "cost": 1},
	# ② 血海殿遗孤
	&"wan_hun_fan": {"type": 1, "rarity": 2, "cost": 2},
	&"you_ying_bu": {"type": 1, "rarity": 2, "cost": 2},
	&"sha_qi_zhan": {"type": 5, "rarity": 1, "cost": 1},
	&"xue_sha_zhang": {"type": 5, "rarity": 1, "cost": 1},
	# ③ 碎星群岛散修
	&"huan_hua_mi_zong_bu": {"type": 1, "rarity": 2, "cost": 2},
	&"yin_po_ning_hun_shu": {"type": 1, "rarity": 2, "cost": 2},
	&"jian_bo_zhan": {"type": 5, "rarity": 1, "cost": 1},
	&"xun_bao_fu": {"type": 5, "rarity": 2, "cost": 1},
	# ④ 玄冰宫弟子
	&"han_yu_lun_hui_gong": {"type": 1, "rarity": 2, "cost": 2},
	&"shuang_po_jian_jue": {"type": 1, "rarity": 2, "cost": 2},
	&"bing_leng_ci": {"type": 5, "rarity": 1, "cost": 1},
	&"jin_zhong_fu": {"type": 5, "rarity": 1, "cost": 1},
	# ⑤ 丹霞谷弟子
	&"san_yuan_ju_qi_gong": {"type": 1, "rarity": 2, "cost": 2},
	&"dan_xia_jian_qi": {"type": 5, "rarity": 2, "cost": 1},
	&"zhu_ji_dan": {"type": 4, "rarity": 2, "cost": 1},
	&"pei_yuan_dan": {"type": 4, "rarity": 1, "cost": 1},
	# ⑥ 阵道双杰
	&"wan_xiang_zhen_dian": {"type": 1, "rarity": 3, "cost": 2},
	&"qi_xing_kun_long_zhen": {"type": 1, "rarity": 2, "cost": 2},
	&"yin_yang_shou_yu_zhen": {"type": 3, "rarity": 1, "cost": 1},
	&"jin_qian_biao": {"type": 5, "rarity": 1, "cost": 0},
}

## 卡牌类型合法区间（CardTemplate.CardType：CHARACTER=0 … TALISMAN=5）。
const CARD_TYPE_MIN: int = 0
const CARD_TYPE_MAX: int = 5
## 稀有度合法区间（CardTemplate.Rarity：WHITE=1 … DARK_GOLD=5，1-based）。
const RARITY_MIN: int = 1
const RARITY_MAX: int = 5

var cs: Node = null

## GSM 校验态快照——本文件走真实加载会触发 [method GameStateManager.enable_validation]，
## 而 GSM 是 Autoload 单例（跨测试文件存活）。after_all 原样还原，避免污染
## 其它文件的「启动时为跳过模式」断言。
var _gsm_validation_before: bool = false
var _gsm_database_before: Dictionary = {}


func before_all() -> void:
	_gsm_validation_before = GameStateManager.validation_enabled
	_gsm_database_before = GameStateManager._card_template_database
	cs = CS_SCRIPT.new()
	cs._load_templates_from(CS_SCRIPT.DEFAULT_TEMPLATE_PATH)
	_drive_loading_to_completion()


func after_all() -> void:
	if cs != null:
		cs.free()
		cs = null
	GameStateManager.validation_enabled = _gsm_validation_before
	GameStateManager._card_template_database = _gsm_database_before


func after_each() -> void:
	# 场上角色列表是测试注入的（模拟 DeploymentSystem 上场）——逐例清空，
	# 避免上一条用例的实例 ID 泄漏到下一条。
	if cs != null:
		cs.field_characters.clear()


## 推进异步加载至完成——重试驱动（同 test_card_system_loading.gd 的 TD-014 修复）。[br]
## 测试实例未加入 SceneTree，[method Node.set_process] 是 no-op，故手动喂帧；
## 后台加载线程需要 CPU 时间片，每帧 [method OS.delay_msec] 让出主线程。
func _drive_loading_to_completion() -> void:
	for _attempt: int in range(3):
		if cs._pending_paths.is_empty():
			break
		for _frame: int in range(100):
			cs._process(0.016)
			if cs._pending_paths.is_empty():
				break
			OS.delay_msec(4)
	assert_true(cs._pending_paths.is_empty(),
		"真实模板应在 3 轮 × 100 帧内加载完成（失败即实现/资产问题）")


# ---- 1. 真实目录可加载、不降级 ----

func test_real_template_directory_loads_without_degrading() -> void:
	assert_false(cs.is_degraded, "真实模板目录不应降级（原因：%s）" % cs.degraded_reason)
	assert_eq(cs.degraded_reason, "", "未降级时 degraded_reason 应为空")
	var expected_total: int = EXPECTED_CARD_FIELDS.size() + EXPECTED_CHARACTER_STATS.size()
	# 只用 ≥（不锁死总数）——卡库按 GDD 还要扩到 215 张，精确计数会在每次加卡时误红；
	# 「该有的有没有」由下面两条逐张断言保证。
	assert_true(cs.templates.size() >= expected_total,
		"模板数应 ≥ %d（6 身份开局卡组并集），实际 %d" % [expected_total, cs.templates.size()])


# ---- 2. 字段自洽 ----

func test_all_loaded_templates_have_valid_fields() -> void:
	var ids: Array = cs.templates.keys()
	assert_true(ids.size() > 0, "至少要有一组可用模板才能校验字段")
	for id: StringName in ids:
		var tpl: CardTemplateClass = cs.templates[id]
		assert_eq(tpl.card_id, id, "注册键应与 card_id 一致（%s）" % id)
		assert_false(tpl.name.strip_edges().is_empty(), "%s 应有卡牌名称" % id)
		assert_true(tpl.type >= CARD_TYPE_MIN and tpl.type <= CARD_TYPE_MAX,
			"%s 的 type 应在 %d..%d（实际 %d）" % [id, CARD_TYPE_MIN, CARD_TYPE_MAX, tpl.type])
		assert_true(tpl.rarity >= RARITY_MIN and tpl.rarity <= RARITY_MAX,
			"%s 的 rarity 应在 %d..%d（实际 %d）" % [id, RARITY_MIN, RARITY_MAX, tpl.rarity])
		assert_true(tpl.cost >= 0, "%s 的 cost 不应为负（实际 %d）" % [id, tpl.cost])
		if tpl.type == CardTemplateClass.CardType.CHARACTER:
			assert_true(tpl.base_hp > 0,
				"%s 是角色卡，base_hp 应 > 0（为 0 会让战斗内 HP 读成 0/0）" % id)
			assert_true(tpl.base_attack > 0, "%s 是角色卡，base_attack 应 > 0" % id)
			assert_true(tpl.faction_tags.size() > 0,
				"%s 是角色卡，应有至少 1 个阵营标签（阵法/流派判定依赖）" % id)
		elif not String(tpl.effect_type).is_empty():
			# effect_type 与 effect_value 是一对——有类型无数值 = 播了等于没播。
			assert_true(tpl.effect_value > 0,
				"%s 声明了 effect_type '%s'，effect_value 应 > 0（实际 %d）"
				% [id, tpl.effect_type, tpl.effect_value])


## 角色卡阵营标签必须已注册在 FactionSystem.FACTION_LIBRARY——拼错（如 xuehaidian vs
## xuehai_temple）不会崩，只会让阵法阵营条件与流派判定静默失灵，故在资产层锁死。
func test_character_faction_tags_are_registered() -> void:
	var library: Dictionary = FactionSystemScript.FACTION_LIBRARY
	for id: StringName in EXPECTED_CHARACTER_STATS.keys():
		var tpl: CardTemplateClass = cs.get_template(id)
		if tpl == null:
			continue
		for tag: StringName in tpl.faction_tags:
			assert_true(library.has(tag),
				"%s 的阵营标签 '%s' 未在 FactionSystem.FACTION_LIBRARY 注册" % [id, tag])


# ---- 3. 数值与 GDD 一致（角色 12 张 + 非角色 25 张） ----

func test_character_templates_match_gdd_stats() -> void:
	for id: StringName in EXPECTED_CHARACTER_STATS.keys():
		var tpl: CardTemplateClass = cs.get_template(id)
		assert_not_null(tpl, "应存在角色卡模板 %s" % id)
		if tpl == null:
			continue
		assert_eq(tpl.type, CardTemplateClass.CardType.CHARACTER, "%s 应为角色卡" % id)
		assert_eq(tpl.base_hp, int(EXPECTED_CHARACTER_STATS[id]["hp"]),
			"%s 的 base_hp 应与 GDD identity-selection 一致" % id)
		assert_eq(tpl.base_attack, int(EXPECTED_CHARACTER_STATS[id]["attack"]),
			"%s 的 base_attack 应与 GDD identity-selection 一致" % id)


func test_card_templates_match_gdd_fields() -> void:
	for id: StringName in EXPECTED_CARD_FIELDS.keys():
		var tpl: CardTemplateClass = cs.get_template(id)
		assert_not_null(tpl, "应存在卡牌模板 %s" % id)
		if tpl == null:
			continue
		var exp: Dictionary = EXPECTED_CARD_FIELDS[id]
		assert_eq(tpl.type, int(exp["type"]), "%s 的 type 应与 GDD 一致" % id)
		assert_eq(tpl.rarity, int(exp["rarity"]), "%s 的 rarity 应与 GDD 一致" % id)
		assert_eq(tpl.cost, int(exp["cost"]), "%s 的 cost 应与 GDD 一致" % id)


# ---- 4. 六个身份开局卡组全覆盖（逐身份断言） ----

func test_all_six_identities_initial_deck_has_all_templates() -> void:
	var identities: Dictionary = IdentityTemplates.IDENTITY_TEMPLATES
	assert_eq(identities.size(), 6, "应有 6 个身份模板（否则本用例覆盖不全）")
	for identity_id: StringName in identities.keys():
		var missing: Array = []
		var card_ids: Array = _identity_card_ids(identities[identity_id])
		assert_true(card_ids.size() > 0, "身份 '%s' 应有开局卡组（否则本用例空转）" % identity_id)
		for id: StringName in card_ids:
			if not cs.templates.has(id):
				missing.append(id)
		assert_eq(missing, [], "身份 '%s' 开局卡组引用的 card_id 应全部有模板（缺失：%s）"
			% [identity_id, str(missing)])


## 从身份表推导某身份的开局卡组 card_id（卡组 + 角色位）——不硬编码清单。
func _identity_card_ids(tpl: Dictionary) -> Array:
	var ids: Array = []
	var deck: Dictionary = tpl["initial_deck"]
	for entry: Dictionary in deck["cards"]:
		ids.append(StringName(entry["card_id"]))
	for entry: Dictionary in deck["character_slots"]:
		ids.append(StringName(entry["card_id"]))
	return ids


# ---- 5. 模板 → 落库 → 读取契约 端到端（全部 12 名初始角色） ----

func test_roster_state_seeds_every_identity_character_from_real_template() -> void:
	for id: StringName in EXPECTED_CHARACTER_STATS.keys():
		var inst: CardInstance = cs.create_instance(id)
		assert_not_null(inst, "create_instance 应返回实例（%s）" % id)
		if inst == null:
			continue
		cs.field_characters.append(inst)  # 模拟 DeploymentSystem 上场
		var roster = RosterState.new()
		roster.seed_player_field([{"character_id": inst.card_instance_id, "is_front": true}], {}, cs)

		var expected_hp: int = int(EXPECTED_CHARACTER_STATS[id]["hp"])
		assert_true(roster.is_known(inst.card_instance_id),
			"%s 的 HP 应为已知——模板缺失时 known=false，这正是「HP 0/0」的根因" % id)
		assert_eq(roster.get_hp(inst.card_instance_id),
			{"current": expected_hp, "max": expected_hp}, "%s 落库后应读到模板 base_hp" % id)

		var reader = ActorReader.new()
		reader.setup(null, null, cs)  # 只测模板回退路径——不接战斗/部署系统
		assert_eq(reader.base_hp(inst.card_instance_id), expected_hp,
			"UI 侧读到的 HP 应为模板真实值（%s）" % id)
		assert_eq(reader.attack(inst.card_instance_id),
			int(EXPECTED_CHARACTER_STATS[id]["attack"]),
			"UI 侧读到的 ATK 应为模板真实值（%s）" % id)


# ---- 6. 类型枚举缺口（DEBT-CBT-018-8）——锁定当前取值，避免被静默「修正」 ----

func test_basic_attack_stays_talisman_pending_adr() -> void:
	# GDD 把基础攻击的类型写作「普通」，CardTemplate.CardType 的 6 个枚举无对应项。
	# 取 TALISMAN(5)（一次性·目标敌方单体，语义最近）——若未来 ADR 追加「普通」枚举，
	# 本断言与 EXPECTED_CARD_FIELDS 一并更新即可。
	# 效果词表相关的回填断言在 test_template_effect_vocabulary.gd。
	var tpl: CardTemplateClass = cs.get_template(&"basic_attack")
	assert_not_null(tpl, "应存在 basic_attack 模板")
	if tpl == null:
		return
	assert_eq(tpl.type, CardTemplateClass.CardType.TALISMAN,
		"basic_attack 暂取 TALISMAN(5)——GDD「普通」类型待 ADR 追加（DEBT-CBT-018-8）")
	assert_eq(tpl.target_type, &"single_enemy", "基础攻击应指向敌方单体")
