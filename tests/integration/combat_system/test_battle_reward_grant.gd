extends GutTest
## 战斗奖励真正到账——探索→战斗→结算→回探索这条链的收尾。[br]
## [br][b]覆盖[/b]：[br]
##   1. 固定奖励 RNG 下，灵石 + 修为按开战上下文的掉落写入玩家数据；[br]
##   2. 卡牌按 [code]chance[/code] 掷骰：命中入收藏、未命中只出现在
##      [code]cards_missed[/code]；[br]
##   3. 同一场重复 [method CombatSystem.battle_end] 不重复发放（幂等）；[br]
##   4. 战败/撤退不发奖（只带 retain_ratio）。[br]
## [br][b]用真实 Autoload[/b]：ResourceSystem / CultivationSystem / CardSystem / GSM
## 都是被测链路的参与者——本文件的断言正是「玩家数据变了」。[br]
## [br][b]种子口径[/b]：显式 [code]set_reward_rng_seed()[/code]——同种子同结果，
## 断言用「区间内」而非写死数值（写死会随 Godot 版本变化碎掉）。[br]
## [br]本文件独占角色 ID 段 8801+、卡牌实例 ID 由 CardSystem 分配。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")

const CHAR_HERO: int = 8801
const CHAR_ENEMY: int = 8802
const CARD_TEMPLATE: StringName = &"pei_yuan_dan"

var cs: Node = null
var _release_ids: Array = []
var _player_before: Dictionary = {}
var _collection_before: Dictionary = {}
var _ai_roster_before: Array = []
var _db_before: Dictionary = {}
var _validation_before: bool = false


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	cs.call("reset_reward_rng")
	cs.call("set_reward_rng_seed", 20240101)
	_clear_gsm_battle()
	_player_before = (GameStateManager.player as Dictionary).duplicate(true)
	_collection_before = (GameStateManager.collection as Dictionary).duplicate(true)
	_ai_roster_before = AISystem.get_enemy_roster().duplicate()
	_release_ids.clear()
	# GSM 的校验模板库只认第一次 enable_validation（跨套件共享）——别的套件可能已
	# 灌入桩模板，导致本文件要发的卡被判「无效 template_id」。这里临时补齐目标模板，
	# 走真实 add_card_to_collection 路径（不绕过生产 API），收尾原样还原。
	_db_before = GameStateManager.get("_card_template_database").duplicate(true)
	_validation_before = bool(GameStateManager.validation_enabled)
	var database: Dictionary = _db_before
	database[str(CARD_TEMPLATE)] = database.get(str(CARD_TEMPLATE), {})
	GameStateManager.set("_card_template_database", database)
	GameStateManager.validation_enabled = true


func after_each() -> void:
	if cs != null:
		cs.free()
		cs = null
	for cid: int in _release_ids:
		DeploymentSystem.remove_character(cid)
	_release_ids.clear()
	InputManager.clear_locks(&"combat_system")
	GameStateManager.player = _player_before
	GameStateManager.collection = _collection_before
	GameStateManager.set("_card_template_database", _db_before)
	GameStateManager.validation_enabled = _validation_before
	AISystem.set_enemy_roster(_ai_roster_before)
	_clear_gsm_battle()


func _clear_gsm_battle() -> void:
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false


## 开战——带探索侧掉落配置；我方 1 人、敌方 1 人（只为触发正常结算路径）。
func _start(p_rewards: Dictionary) -> void:
	if DeploymentSystem.setup_field([CHAR_HERO], {}):
		_release_ids.append(CHAR_HERO)
	cs.call("battle_start", {
		"enemy_roster": [{"character_id": CHAR_ENEMY, "current_hp": 5,
				"max_hp": 5, "attack": 0, "is_alive": true}],
		"character_ids": [CHAR_HERO],
		"player_stats": {CHAR_HERO: {"current_hp": 10, "max_hp": 10}},
		"rewards": p_rewards,
	})


## 结束并取回 battle_ended 载荷。
func _finish(p_result: int = CS_SCRIPT.CombatResult.VICTORY) -> Dictionary:
	var captured: Dictionary = {}
	var handler: Callable = func(_r: int, rewards: Dictionary) -> void:
		captured["rewards"] = rewards.duplicate(true)
	cs.connect("battle_ended", handler)
	cs.call("battle_end", p_result)
	cs.disconnect("battle_ended", handler)
	return captured.get("rewards", {})


func _lingshi() -> int:
	return ResourceSystem.get_resource(&"ling_shi")


func _cultivation() -> int:
	return int(GameStateManager.player.cultivation)


func _owned_count() -> int:
	return (GameStateManager.collection.owned_cards as Array).size()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 灵石 + 修为到账
# ═══════════════════════════════════════════════════════════════════════════════

func test_victory_grants_lingshi_within_configured_range() -> void:
	# Arrange
	var before: int = _lingshi()
	_start({"lingshi_min": 10, "lingshi_max": 20, "cultivation": 0, "cards": []})
	# Act
	var rewards: Dictionary = _finish()
	# Assert——区间内且有随机性；余额同步增加
	var gained: int = int(rewards.get("lingshi", -1))
	assert_true(gained >= 10 and gained <= 20,
			"灵石实得应落在配置区间 [10, 20]（实际 %d）" % gained)
	assert_eq(_lingshi(), before + gained, "玩家灵石余额应增加实得值")
	assert_eq(int(rewards.get("lingshi_min")), 10, "载荷带区间下限（界面可解释）")
	assert_eq(int(rewards.get("lingshi_max")), 20, "载荷带区间上限")
	assert_true(bool(rewards.get("lingshi_granted")), "发放成功标记")


func test_victory_grants_cultivation() -> void:
	# Arrange
	var before: int = _cultivation()
	_start({"lingshi": 0, "cultivation": 7, "cards": []})
	# Act
	var rewards: Dictionary = _finish()
	# Assert
	assert_eq(int(rewards.get("cultivation", 0)), 7, "修为取配置值（不掷骰）")
	assert_eq(_cultivation(), before + 7, "玩家修为应增加 7")
	assert_true(bool(rewards.get("cultivation_granted")), "修为发放成功标记")


func test_fixed_lingshi_is_granted_exactly() -> void:
	var before: int = _lingshi()
	_start({"lingshi": 13, "cultivation": 0, "cards": []})
	var rewards: Dictionary = _finish()
	assert_eq(int(rewards.get("lingshi", 0)), 13, "定值掉落原样发放")
	assert_eq(_lingshi(), before + 13, "余额增加 13")


func test_empty_rewards_config_grants_nothing() -> void:
	var lingshi_before: int = _lingshi()
	var cult_before: int = _cultivation()
	_start({})
	var rewards: Dictionary = _finish()
	assert_eq(_lingshi(), lingshi_before, "无掉落配置时灵石不变")
	assert_eq(_cultivation(), cult_before, "无掉落配置时修为不变")
	assert_eq(int(rewards.get("lingshi", 0)), 0, "载荷灵石为 0")
	assert_eq(rewards.get("cards", []), [], "载荷卡牌为空")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 卡牌：命中入收藏 / 未命中只记录
# ═══════════════════════════════════════════════════════════════════════════════

func test_guaranteed_card_enters_collection() -> void:
	# Arrange——100% 概率（不消耗随机数，结果确定）
	var before: int = _owned_count()
	_start({"lingshi": 0, "cultivation": 0,
			"cards": [{"card_id": str(CARD_TEMPLATE), "chance": 1.0}]})
	# Act
	var rewards: Dictionary = _finish()
	# Assert——收藏增加一张，载荷带名称/稀有度
	assert_eq(_owned_count(), before + 1, "命中的卡牌应写入收藏")
	var cards: Array = rewards.get("cards", [])
	assert_eq(cards.size(), 1, "载荷 cards 只含到手卡牌")
	assert_eq(str(cards[0].get("card_id", "")), str(CARD_TEMPLATE), "卡牌 ID 正确")
	assert_eq(str(cards[0].get("name", "")), "培元丹", "载荷带卡牌名称（界面直接显示）")
	assert_eq(str(cards[0].get("rarity", "")), "白", "载荷带中文稀有度")
	var owned: Array = GameStateManager.collection.owned_cards
	var found: bool = false
	for entry: Dictionary in owned:
		if str(entry.get("template_id", "")) == str(CARD_TEMPLATE):
			found = true
	assert_true(found, "收藏条目应含该模板 ID")


func test_zero_chance_card_is_not_granted() -> void:
	# Arrange——0% 概率：恒未命中
	var before: int = _owned_count()
	_start({"lingshi": 0, "cultivation": 0,
			"cards": [{"card_id": str(CARD_TEMPLATE), "chance": 0.0}]})
	# Act
	var rewards: Dictionary = _finish()
	# Assert——收藏不变，未命中写进 cards_missed（界面要能说明「没抽到」）
	assert_eq(_owned_count(), before, "未命中的卡牌不入收藏")
	assert_eq(rewards.get("cards", []), [], "载荷 cards 为空")
	var missed: Array = rewards.get("cards_missed", [])
	assert_eq(missed.size(), 1, "未命中条目应被记录")
	assert_eq(str(missed[0].get("card_id", "")), str(CARD_TEMPLATE), "未命中卡牌 ID")
	assert_eq(str(missed[0].get("name", "")), "培元丹", "未命中条目也带展示名")


func test_unknown_card_template_is_reported_not_crashing() -> void:
	# Arrange——配置了一张不存在的卡
	var before: int = _owned_count()
	_start({"lingshi": 0, "cultivation": 0,
			"cards": [{"card_id": "no_such_card", "chance": 1.0}]})
	# Act
	var rewards: Dictionary = _finish()
	# Assert——记入 cards_failed，不写收藏、不炸
	assert_eq(_owned_count(), before, "未知模板不入收藏")
	var failed: Array = rewards.get("cards_failed", [])
	assert_eq(failed.size(), 1, "未知模板应记入发放失败")
	assert_string_contains(str(failed[0].get("reason", "")), "未知卡牌", "失败原因可读")


func test_card_collection_entry_is_serialized() -> void:
	# 收藏条目形状必须与 CardSerializer 一致（读档/UI 都按这个形状读）
	_start({"lingshi": 0, "cultivation": 0,
			"cards": [{"card_id": str(CARD_TEMPLATE), "chance": 1.0}]})
	_finish()
	var owned: Array = GameStateManager.collection.owned_cards
	var entry: Dictionary = owned[owned.size() - 1]
	for key: String in ["card_instance_id", "template_id", "level", "inscriptions",
			"breakthrough_layers", "binding_target_id", "acquired_chapter",
			"acquired_event_id", "acquired_method"]:
		assert_true(entry.has(key), "收藏条目应含字段 %s" % key)
	assert_true(int(entry.get("card_instance_id", 0)) > 0, "实例 ID 由系统分配")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 幂等：重复结算不重复发放
# ═══════════════════════════════════════════════════════════════════════════════

func test_repeated_battle_end_does_not_grant_twice() -> void:
	# Arrange——第一场胜利（定值，便于精确断言）
	var before: int = _lingshi()
	var cult_before: int = _cultivation()
	var owned_before: int = _owned_count()
	_start({"lingshi": 25, "cultivation": 4,
			"cards": [{"card_id": str(CARD_TEMPLATE), "chance": 1.0}]})
	_finish()
	var lingshi_after_first: int = _lingshi()
	var cult_after_first: int = _cultivation()
	var owned_after_first: int = _owned_count()
	assert_eq(lingshi_after_first, before + 25, "前置：第一场已发放灵石")
	assert_eq(owned_after_first, owned_before + 1, "前置：第一场已发放卡牌")
	# Act——同一场再结算一次（重复 battle_end）
	cs.call("battle_end", CS_SCRIPT.CombatResult.VICTORY)
	# Assert——三项都不再变化
	assert_eq(_lingshi(), lingshi_after_first, "重复结算不得再发灵石")
	assert_eq(_cultivation(), cult_after_first, "重复结算不得再发修为")
	assert_eq(_owned_count(), owned_after_first, "重复结算不得再发卡牌")


func test_repeated_battle_end_reports_grant_skipped() -> void:
	_start({"lingshi": 5, "cultivation": 1, "cards": []})
	_finish()
	var rewards: Dictionary = _finish()
	assert_true(bool(rewards.get("grant_skipped", false)),
			"重复结算的载荷应标记 grant_skipped（界面可据此不重复提示）")
	assert_false(rewards.has("lingshi"), "跳过时不带奖励字段（不是「0 奖励」而是「没结算」）")
	assert_false(rewards.has("cards"), "跳过时也不带卡牌字段")


func test_next_battle_grants_again() -> void:
	# 幂等守卫按「开战配置身份」——换一场必须照常发奖
	var before: int = _lingshi()
	_start({"lingshi": 5, "cultivation": 0, "cards": []})
	_finish()
	var after_first: int = _lingshi()
	assert_eq(after_first, before + 5, "前置：第一场已发放")
	_start({"lingshi": 6, "cultivation": 0, "cards": []})
	_finish()
	assert_eq(_lingshi(), after_first + 6, "第二场应照常发放（不是同一场）")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 战败 / 撤退不发奖
# ═══════════════════════════════════════════════════════════════════════════════

func test_defeat_grants_no_rewards() -> void:
	var lingshi_before: int = _lingshi()
	var cult_before: int = _cultivation()
	_start({"lingshi": 50, "cultivation": 20,
			"cards": [{"card_id": str(CARD_TEMPLATE), "chance": 1.0}]})
	var rewards: Dictionary = _finish(CS_SCRIPT.CombatResult.DEFEAT)
	assert_eq(_lingshi(), lingshi_before, "战败不发灵石")
	assert_eq(_cultivation(), cult_before, "战败不发修为")
	assert_false(rewards.has("cards"), "战败载荷不带卡牌")
	assert_almost_eq(float(rewards.get("retain_ratio", 0.0)), 0.5, 0.001,
			"战败载荷带 50% 保留比例（既有契约不变）")


func test_retreat_grants_no_rewards() -> void:
	var lingshi_before: int = _lingshi()
	_start({"lingshi": 50, "cultivation": 20, "cards": []})
	var rewards: Dictionary = _finish(CS_SCRIPT.CombatResult.RETREAT)
	assert_eq(_lingshi(), lingshi_before, "撤退不发灵石")
	assert_almost_eq(float(rewards.get("retain_ratio", 0.0)), 0.5, 0.001,
			"撤退载荷带 50% 保留比例")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 结果视图 / 回探索提示（同一条链路的展示侧）
# ═══════════════════════════════════════════════════════════════════════════════

func test_result_view_publishes_reward_summary_and_notice() -> void:
	# Arrange
	var ViewScript := preload("res://src/feature/combat/combat_result_view.gd")
	ViewScript.clear()
	var bridge: RefCounted = preload(
			"res://src/ui/combat/shared/combat_result_bridge.gd").new()
	bridge.call("bind", cs)
	_start({"lingshi": 13, "cultivation": 2,
			"cards": [{"card_id": str(CARD_TEMPLATE), "chance": 1.0}]})
	# Act
	cs.call("battle_end", CS_SCRIPT.CombatResult.VICTORY)
	# Assert——结算对象与回探索提示都读得到实得奖励
	var view: RefCounted = ViewScript.last()
	assert_not_null(view, "胜利后应发布结算对象")
	var lines: Array = view.call("reward_lines")
	assert_true(lines.has("灵石 +13"), "结算场景应展示实得灵石")
	assert_true(lines.has("修为 +2"), "结算场景应展示修为")
	assert_true(lines.has("获得卡牌：培元丹（白·丹药）"), "结算场景应展示到手卡牌")
	var notice: String = str(ViewScript.take_pending_notice())
	assert_string_contains(notice, "灵石 +13", "回探索提示含灵石")
	assert_string_contains(notice, "培元丹", "回探索提示含到手卡牌")
	assert_eq(str(ViewScript.take_pending_notice()), "", "提示一次性——取后即清")
	bridge.call("unbind")
	ViewScript.clear()
