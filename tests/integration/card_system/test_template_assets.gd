extends GutTest
## DEBT-CBT-018-5 验收测试：真实卡牌模板资产（[code]assets/cards/templates/[/code]）。[br]
## [br][b]背景[/b]：此前模板目录不存在 → CardSystem 降级为空模板集 →
## [code]CombatRosterState[/code] 读不到 [code]base_hp[/code] 标记 [code]known=false[/code] →
## 战斗 UI 角色卡显示「HP 0/0 ATK 0」。本文件锁住三件事：[br]
##   1. 真实目录能加载出模板，且未进降级态（目录/字段坏了会先在这里红）；[br]
##   2. 每张模板字段自洽（类型/稀有度/费用；角色卡 HP·ATK 为正；[br]
##      [code]effect_type[/code] 非空时 [code]effect_value[/code] 必为正）；[br]
##   3. 身份①开局卡组引用的 [code]card_id[/code] 全部有模板，且角色卡
##      [code]base_hp[/code] 能经 [code]CombatRosterState[/code] /
##      [code]CombatActorReader[/code] 读成真实数值（不再是 0/0）。[br]
## [br][b]数值来源[/b]：[code]design/gdd/identity-selection-system.md[/code]
## §① 青云剑宗·外门弟子（林渊 10/2、苏剑鸣 7/4）。[br]
## [br][b]为何用独立实例而非 Autoload[/b]：其它测试会对 [code]/root/CardSystem[/code]
## 的 [code]templates[/code]/[code]field_characters[/code] 注入夹具，共用实例会互相污染。[br]
## NOTE: 本文件走真实磁盘加载，属集成测试——不依赖任何注入模板。

const CS_SCRIPT: GDScript = preload("res://src/core/card_system/card_system.gd")
const CardTemplateClass: GDScript = preload("res://src/core/card_system/card_template.gd")
const IdentityTemplates: GDScript = preload("res://src/feature/identity/identity_templates.gd")
const RosterState: GDScript = preload("res://src/feature/combat/combat_roster_state.gd")
const ActorReader: GDScript = preload("res://src/ui/combat/layout/combat_actor_reader.gd")

## 身份①（青云剑宗·外门弟子）——身份表单一真理来源（ADR-0022）。
const IDENTITY_ONE: StringName = &"azure_sword_disciple"

## 身份①两名角色的期望数值——GDD identity-selection-system.md §①（HP/ATK）。
const EXPECTED_CHARACTER_STATS: Dictionary = {
	&"lin_yuan": {"hp": 10, "attack": 2},
	&"su_jian_ming": {"hp": 7, "attack": 4},
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


# ============================================================================
# 1. 真实目录可加载、不降级
# ============================================================================

func test_real_template_directory_loads_without_degrading() -> void:
	assert_false(cs.is_degraded, "真实模板目录不应降级（原因：%s）" % cs.degraded_reason)
	assert_eq(cs.degraded_reason, "", "未降级时 degraded_reason 应为空")
	assert_true(cs.templates.size() >= 3,
		"至少 3 张模板（实际 %d）——身份①需要 2 张角色 + 若干功法/符箓" % cs.templates.size())
	assert_true(cs.templates.has(&"lin_yuan"), "应加载出角色模板 lin_yuan")
	assert_true(cs.templates.has(&"su_jian_ming"), "应加载出角色模板 su_jian_ming")


# ============================================================================
# 2. 字段自洽
# ============================================================================

func test_all_loaded_templates_have_valid_fields() -> void:
	var ids: Array = cs.templates.keys()
	assert_true(ids.size() >= 3, "至少要有一组可用模板才能校验字段")
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
		elif not String(tpl.effect_type).is_empty():
			# effect_type 与 effect_value 是一对——有类型无数值 = 播了等于没播。
			assert_true(tpl.effect_value > 0,
				"%s 声明了 effect_type '%s'，effect_value 应 > 0（实际 %d）"
				% [id, tpl.effect_type, tpl.effect_value])


func test_character_templates_match_identity_one_stats() -> void:
	for id: StringName in EXPECTED_CHARACTER_STATS.keys():
		var tpl: CardTemplateClass = cs.get_template(id)
		assert_not_null(tpl, "应存在角色卡模板 %s" % id)
		if tpl == null:
			continue
		assert_eq(tpl.type, CardTemplateClass.CardType.CHARACTER, "%s 应为角色卡" % id)
		assert_eq(tpl.base_hp, int(EXPECTED_CHARACTER_STATS[id]["hp"]),
			"%s 的 base_hp 应与 GDD 一致" % id)
		assert_eq(tpl.base_attack, int(EXPECTED_CHARACTER_STATS[id]["attack"]),
			"%s 的 base_attack 应与 GDD 一致" % id)


# ============================================================================
# 3. 身份①开局卡组全覆盖
# ============================================================================

func test_identity_one_initial_deck_has_all_templates() -> void:
	var missing: Array = []
	for id: StringName in _identity_one_card_ids():
		if not cs.templates.has(id):
			missing.append(id)
	assert_eq(missing, [], "身份①开局卡组引用的 card_id 应全部有模板（缺失：%s）" % str(missing))


## 从身份表推导身份①的开局卡组 card_id（卡组 + 角色位）——不硬编码清单，
## 身份表改了这里自动跟随。
func _identity_one_card_ids() -> Array:
	var ids: Array = []
	var tpl: Dictionary = IdentityTemplates.IDENTITY_TEMPLATES[IDENTITY_ONE]
	var deck: Dictionary = tpl["initial_deck"]
	for entry: Dictionary in deck["cards"]:
		ids.append(StringName(entry["card_id"]))
	for entry: Dictionary in deck["character_slots"]:
		ids.append(StringName(entry["card_id"]))
	assert_true(ids.size() > 0, "身份①应有开局卡组（否则本用例空转）")
	return ids


# ============================================================================
# 4. 角色 base_hp 不再为 0——模板 → 落库 → 读取契约 端到端
# ============================================================================

func test_roster_state_seeds_player_hp_from_real_template() -> void:
	var inst: CardInstance = cs.create_instance(&"lin_yuan")
	assert_not_null(inst, "create_instance 应返回实例")
	if inst == null:
		return
	cs.field_characters.append(inst)  # 模拟 DeploymentSystem 上场

	var roster = RosterState.new()
	roster.seed_player_field([{"character_id": inst.card_instance_id, "is_front": true}], {}, cs)

	var expected_hp: int = int(EXPECTED_CHARACTER_STATS[&"lin_yuan"]["hp"])
	assert_true(roster.is_known(inst.card_instance_id),
		"角色 HP 应为已知——模板缺失时 known=false，这正是「HP 0/0」的根因")
	assert_eq(roster.get_hp(inst.card_instance_id),
		{"current": expected_hp, "max": expected_hp}, "落库后应读到模板 base_hp")


func test_actor_reader_reads_real_template_stats() -> void:
	var inst: CardInstance = cs.create_instance(&"su_jian_ming")
	assert_not_null(inst, "create_instance 应返回实例")
	if inst == null:
		return
	cs.field_characters.append(inst)

	var reader = ActorReader.new()
	reader.setup(null, null, cs)  # 只测模板回退路径——不接战斗/部署系统
	assert_eq(reader.base_hp(inst.card_instance_id),
		int(EXPECTED_CHARACTER_STATS[&"su_jian_ming"]["hp"]),
		"UI 侧读到的 HP 应为模板真实值（不再是 0）")
	assert_eq(reader.attack(inst.card_instance_id),
		int(EXPECTED_CHARACTER_STATS[&"su_jian_ming"]["attack"]),
		"UI 侧读到的 ATK 应为模板真实值（不再是 0）")
