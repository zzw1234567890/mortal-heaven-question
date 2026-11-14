extends GutTest
## InventoryScreensFixture —— 背包 / 角色状态界面的共享装置（真实 Autoload + 真实存档）。[br]
## [br][b]为什么用真实 Autoload 而不是桩[/b]：这两个界面要证明的正是「读真实存档、
## 看得见探索里攒的东西」——用桩断言等于断言自己造的假数据。存取链路
## （[code]ResourceSystem.add_resource[/code] / [code]CardSystem.create_instance[/code]
## / [code]GSM.add_card_to_collection[/code] / [code]CombatHpCarryover.write_back[/code]）
## 全程真跑，与探索/商店/炼制各轮的集成用例同一取舍。[br]
## [br][b]原名不符 [code]test_[/code] 前缀[/b]：GUT 不把它当用例收集，只作基类
## （先例 [code]shop_rest_node_fixture.gd[/code]）。[br]
## [br][b]快照还原[/b]：[code]player[/code] / [code]collection[/code] / [code]deck[/code]
## 三个域在 [method before_each] 深拷贝、[method after_each] 原样写回——GSM 是全进程
## 单例，不还原会让后续用例互相污染。[br]
## [br][b]异步模板就位[/b]：[code]CardSystem._ready[/code] 用
## [code]load_threaded_request[/code] 分批加载模板，GUT 下的帧驱动不保证——用
## [code]card_template_primer.gd[/code] 同步推进（该助手已被商店/炼制/打坐各用例共用）。
##
## 来源: 先例 [code]tests/integration/exploration_ui/shop_rest_node_fixture.gd[/code]、
## [code]tests/integration/exploration_ui/card_template_primer.gd[/code]。

const HostScript := preload("res://src/ui/inventory/inventory_screens_host.gd")
const InventoryModelScript := preload("res://src/feature/inventory/inventory_model.gd")
const StatusModelScript := preload("res://src/feature/inventory/character_status_model.gd")
const Catalog := preload("res://src/feature/inventory/inventory_catalog.gd")
const ItemsScript := preload("res://src/feature/exploration/exploration_shop_inventory.gd")
const PrimerScript := preload("res://tests/integration/exploration_ui/card_template_primer.gd")

## 具名丹药 / 法宝模板（[code]assets/cards/templates/[/code] 里已落盘的八个之二）——
## 用真实模板而非临时造资源：界面读的正是真实注册表。
const PILL_ID: StringName = &"pill_yu_ling_dan"       # 玉灵丹 · PILL · 紫
const PILL_ID_2: StringName = &"pill_jiu_zhuan_jin_dan" # 九转金丹 · PILL · 暗金
const ARTIFACT_ID: StringName = &"artifact_zhong_pin_fa_qi"  # 中品法器 · ARTIFACT · 紫
const ARTIFACT_ID_2: StringName = &"artifact_shang_pin_fa_qi"  # 上品法器 · ARTIFACT · 金
const CHARACTER_ID: StringName = &"lin_yuan"           # 林渊 · CHARACTER · 生命 10

## 角色实例 ID（[code]GSM.allocate_card_id[/code] 从 1 起发号——用例自持高位号段，
## 与真实分配互不打架）。
const CHAR_INSTANCE_A: int = 8801
const CHAR_INSTANCE_B: int = 8802

var host: Control = null
var _player_before: Dictionary = {}
var _collection_before: Dictionary = {}
var _deck_before: Dictionary = {}
## 校验数据库与开关的原始值（[method prepare_card_validation] 会改它们——
## 不还原会把「校验开启」泄漏给后续用例）。
var _db_before: Dictionary = {}
var _validation_before: bool = false


func before_each() -> void:
	_player_before = (GameStateManager.player as Dictionary).duplicate(true)
	_collection_before = (GameStateManager.collection as Dictionary).duplicate(true)
	_deck_before = (GameStateManager.deck as Dictionary).duplicate(true)
	_db_before = (GameStateManager.get("_card_template_database") as Dictionary).duplicate(true)
	_validation_before = bool(GameStateManager.validation_enabled)
	_reset_player_domains()
	# 卡牌模板与校验必须先就位：界面读的「丹药/法宝/角色」全部要经过
	# CardSystem 的模板注册表（未就位时界面会静默少显示几行，断言随之失真）。
	prepare_card_validation()
	host = HostScript.new()
	host.inventory_model = InventoryModelScript.new(
			GameStateManager, CardSystem)
	host.status_model = StatusModelScript.new(GameStateManager, RealmSystem)
	# 角色状态模型的名册/HP 依赖也要接上真实系统（生产由主菜单装配，这里等价接线）
	host.status_model.deployment_system = DeploymentSystem
	add_child_autofree(host)


func after_each() -> void:
	if host != null and is_instance_valid(host) and host.visible:
		host.close()
	if host != null and is_instance_valid(host):
		(host.status_model as RefCounted).deployment_system = null
	_restore(GameStateManager, "player", _player_before)
	_restore(GameStateManager, "collection", _collection_before)
	_restore(GameStateManager, "deck", _deck_before)
	GameStateManager.set("_card_template_database", _db_before)
	GameStateManager.validation_enabled = _validation_before


# ═══════════════════════════════════════════════════════════════════════════════
# 存档的读写小工具（全部走真实入口）
# ═══════════════════════════════════════════════════════════════════════════════

## 重置三个域为干净初值（每用例从确定的起点开始——测试不得依赖执行顺序）。
func _reset_player_domains() -> void:
	GameStateManager.player = {
		"realm": 1, "cultivation": 0, "max_cultivation": 1000,
		"cultivation_full": false, "is_fallen": false, "overflow_pool": 0,
		"resources": {"ling_shi": 0,
			"ling_cai": {"low": 0, "medium": 0, "high": 0, "top": 0},
			"dan_yao_sui_pian": 0},
		"identity_id": "", "talents": [], "talent_map": {},
		"unavailable_characters": {}, "character_hp": {},
		"tribulation_state": 0, "consecutive_tribulation_failures": 0,
	}
	GameStateManager.collection = {"owned_cards": [], "total_count": 0}
	GameStateManager.deck = {"current_deck": [], "slots": [null, null, null,
			null, null, null], "change_log": [], "session_remove_count": 0,
			"deck_limit_modifier": 0}
	# 阵亡名单也归零：DeploymentSystem 是 Autoload，它的 _unavailable_characters
	# 不随 GSM 域还原，上一个用例标过的角色会漏到下一个用例（「只标阵亡那一个」
	# 这类断言会因此看到多余标记）。load_unavailable_from_gsm({}) 是它的清空入口。
	DeploymentSystem.load_unavailable_from_gsm({})


## 深拷贝写回某域（GSM 是 Autoload 单例——还原必须是替换而非原地改）。
func _restore(p_gsm: Node, p_domain: String, p_value: Dictionary) -> void:
	p_gsm.set(p_domain, p_value.duplicate(true))


## 让若干模板进入 [`CardSystem`] 注册表（异步加载的同步推进）。
## [br][b]返回[/b]：是否全部就位——用例据此断言「模板环境确实备好了」，
## 而不是在模板缺失时静默跑出一条假的通过路径。
func prime_templates(p_ids: Array) -> bool:
	var all_ready: bool = true
	for id: StringName in p_ids:
		if not PrimerScript.prime(CardSystem, id):
			all_ready = false
	return all_ready


## 摆放若干灵材（走真实 [code]ResourceSystem[/code] 写入口）。
func give_ling_cai(p_low: int, p_medium: int, p_high: int, p_top: int) -> void:
	var amounts: Array = [p_low, p_medium, p_high, p_top]
	for index: int in range(amounts.size()):
		var amount: int = amounts[index]
		if amount > 0:
			ResourceSystem.add_resource(&"ling_cai", amount, index + 1)


## 造一张收藏卡（走真实 [code]CardSystem.create_instance[/code] +
## [code]GSM.add_card_to_collection[/code]——界面读的就是这张卡）。
## [br][b]先把模板推进注册表[/b]：模板是异步加载的，未就位时 [code]create_instance[/code]
## 返回 null、这张卡根本进不了收藏（界面随后少一行，断言却看不出来是「界面漏读」
## 还是「卡没造出来」）。在这里就地推进，调用方不必逐个记得先 prime。
## [br][b]返回[/b]：实例 ID；模板推不动 / 校验未开启 / 写入被拒时返回 -1。
func give_card(p_template_id: StringName) -> int:
	if not prime_templates([p_template_id]):
		return -1
	var instance: Variant = CardSystem.create_instance(p_template_id)
	if instance == null:
		return -1
	var entry: Dictionary = CardSystem.serialize_instance(instance)
	entry["template_id"] = p_template_id
	if not GameStateManager.add_card_to_collection(entry):
		return -1
	return int(entry.get("card_instance_id", -1))


## 让 GSM 的卡牌引用校验可用（[code]add_card_to_collection[/code] 的前置）。[br]
## [br]真实生产路径由 [code]CardSystem._ready[/code] 完成；GUT 下时序不保证，
## 故显式备好（先例 [code]shop_rest_node_fixture._prepare_card_validation[/code]）：
## 推进异步模板加载 → 把用到的模板 ID 补进校验数据库 → 打开开关。
func prepare_card_validation() -> void:
	PrimerScript.prime(CardSystem, PILL_ID)
	PrimerScript.prime(CardSystem, CHARACTER_ID)
	var database: Dictionary = GameStateManager.get("_card_template_database")
	for id: StringName in [PILL_ID, PILL_ID_2, ARTIFACT_ID, ARTIFACT_ID_2, CHARACTER_ID]:
		database[str(id)] = database.get(str(id), {})
	GameStateManager.set("_card_template_database", database)
	GameStateManager.validation_enabled = true


## 摆放一名角色到角色位并写好它的 HP 账本（走真实
## [code]GSM._set_player_character_hp[/code]）。
## [br][b]返回[/b]：实例 ID（失败 -1）。
func give_character(p_slot: int, p_instance_id: int, p_current_hp: int,
		p_max_hp: int) -> int:
	var instance: Variant = CardSystem.create_instance(CHARACTER_ID)
	if instance == null:
		return -1
	var entry: Dictionary = CardSystem.serialize_instance(instance)
	entry["template_id"] = CHARACTER_ID
	entry["card_instance_id"] = p_instance_id
	var slots: Array = (GameStateManager.deck as Dictionary)["slots"]
	while slots.size() < 6:
		slots.append(null)
	slots[p_slot] = p_instance_id
	# 名册读取器按实例 ID 反查模板，走的是 field_characters + 收藏两条路——
	# 把角色也放进收藏，模板才查得到（与「角色卡也是一种卡」的既有口径一致）。
	GameStateManager.add_card_to_collection(entry)
	GameStateManager._set_player_character_hp(p_instance_id,
			{"current_hp": p_current_hp, "max_hp": p_max_hp})
	return p_instance_id


## 标记一名角色不可用（走真实 [code]DeploymentSystem.mark_unavailable[/code]）。
func mark_dead(p_character_id: int) -> void:
	DeploymentSystem.mark_unavailable(p_character_id,
			{"death_turn": 1, "death_battle_id": "b_test"})


## 打开界面并停在某页（[code]0[/code] 背包 / [code]1[/code] 角色状态）。
func open_page(p_index: int) -> void:
	host.open()
	host.show_page(p_index)


## 背包页。
func inventory_page() -> Control:
	return host.page(0)


## 角色状态页。
func status_page() -> Control:
	return host.page(1)


## 某页的全部行文本。
func rows_of(p_page: Control) -> Array:
	if p_page == inventory_page():
		return p_page.call(&"entry_texts")
	return p_page.call(&"row_texts")


## 造一个按键事件（面板走 [code]_input[/code]，直调即复现引擎同一次派发——
## 先例 [code]test_shop_panel_navigation.gd[/code]）。[br]
## [br]放在装置里而不是各用例文件里：两个用例文件（背包流程 / 角色状态流程）
## 都要用它，各写一份必然漂移。
func key_event(p_code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = p_code
	event.pressed = true
	event.echo = false
	return event
