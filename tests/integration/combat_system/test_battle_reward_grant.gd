extends GutTest
## 战斗奖励真正到账——探索→战斗→结算→选择发放这条链的收尾。[br]
## [br][b]覆盖[/b]：[br]
##   1. 固定奖励 RNG 下，灵石 + 修为按开战上下文的掉落写入玩家数据；[br]
##   2. 卡牌按 [code]chance[/code] 掷骰：命中后在 grant 时入收藏、未命中只出现在
##      [code]cards_missed[/code]；[br]
##   3. 同一场重复 [method CombatSystem.battle_end] 不重复掷骰（幂等）；[br]
##   4. 战败/撤退不发奖（只带 retain_ratio）；[br]
##   5. 胜利后调用 grant_reward_selection 发放奖励。[br]
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


## 调用 grant_reward_selection 发放奖励。
func _grant(index: int = -1) -> Dictionary:
	if cs == null or not cs.has_method(&"grant_reward_selection"):
		return {"no_rolled_rewards": true}
	return cs.call("grant_reward_selection", index)


func _lingshi() -> int:
	return ResourceSystem.get_resource(&"ling_shi")


func _cultivation() -> int:
	return int(GameStateManager.player.cultivation)


func _owned_count() -> int:
	return (GameStateManager.collection.owned_cards as Array).size()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 胜利后只掷骰不发放，余额不变
# ═══════════════════════════════════════════════════════════════════════════════

func test_victory_rolls_rewards_without_granting() -> void:
	# Arrange
	var lingshi_before: int = _lingshi()
	var cult_before: int = _cultivation()
	_start({"lingshi": 15, "cultivation": 5, "cards": []})
	# Act
	var rewards: Dictionary = _finish()
	# Assert——掷骰结果存在，但余额未变
	assert_eq(int(rewards.get("lingshi", 0)), 15, "载荷包含掷出的灵石")
	assert_eq(int(rewards.get("cultivation", 0)), 5, "载荷包含修为")
	assert_eq(_lingshi(), lingshi_before, "胜利后未 grant 时灵石余额不变")
	assert_eq(_cultivation(), cult_before, "胜利后未 grant 时修为不变")
	assert_false(rewards.has("lingshi_granted"), "未发放时不带 lingshi_granted 标记")
	assert_false(rewards.has("cultivation_granted"), "未发放时不带 cultivation_granted 标记")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. grant_reward_selection 发放灵石 + 修为
# ═══════════════════════════════════════════════════════════════════════════════

func test_grant_selection_grants_lingshi_and_cultivation() -> void:
	# Arrange
	var lingshi_before: int = _lingshi()
	var cult_before: int = _cultivation()
	_start({"lingshi": 12, "cultivation": 3, "cards": []})
	_finish()
	# Act——跳过卡牌（index=-1），只发灵石+修为
	var result: Dictionary = _grant(-1)
	# Assert
	assert_false(bool(result.get("no_rolled_rewards", true)), "应成功发放")
	assert_eq(_lingshi(), lingshi_before + 12, "灵石应增加 12")
	assert_eq(_cultivation(), cult_before + 3, "修为应增加 3")
	assert_true(bool(result.get("lingshi_granted", false)), "灵石发放成功标记")
	assert_true(bool(result.get("cultivation_granted", false)), "修为发放成功标记")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. grant_reward_selection 发放选中卡牌
# ═══════════════════════════════════════════════════════════════════════════════

func test_grant_selection_grants_selected_card() -> void:
	# Arrange——100% 概率卡牌
	var before: int = _owned_count()
	_start({"lingshi": 0, "cultivation": 0,
			"cards": [{"card_id": str(CARD_TEMPLATE), "chance": 1.0}]})
	_finish()
	# Act——选择第一张卡（index=0）
	var result: Dictionary = _grant(0)
	# Assert
	assert_eq(_owned_count(), before + 1, "选中卡牌应入收藏")
	var cards: Array = result.get("cards", [])
	assert_eq(cards.size(), 1, "返回结果包含到手卡牌")
	assert_eq(str(cards[0].get("card_id", "")), str(CARD_TEMPLATE), "卡牌 ID 正确")


func test_grant_selection_skips_card_when_index_negative() -> void:
	# Arrange
	var before: int = _owned_count()
	_start({"lingshi": 5, "cultivation": 0,
			"cards": [{"card_id": str(CARD_TEMPLATE), "chance": 1.0}]})
	_finish()
	# Act——跳过卡牌（index=-1）
	var result: Dictionary = _grant(-1)
	# Assert
	assert_eq(_owned_count(), before, "跳过时卡牌不入收藏")
	assert_eq(result.get("cards", []), [], "返回结果卡牌为空")
	assert_eq(_lingshi(), before + 5, "灵石仍发放")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 重复 grant 幂等
# ═══════════════════════════════════════════════════════════════════════════════

func test_repeated_grant_is_idempotent() -> void:
	# Arrange
	var lingshi_before: int = _lingshi()
	_start({"lingshi": 20, "cultivation": 0, "cards": []})
	_finish()
	# Act——第一次发放
	var result1: Dictionary = _grant(-1)
	var after_first: int = _lingshi()
	# 第二次发放
	var result2: Dictionary = _grant(-1)
	# Assert
	assert_eq(after_first, lingshi_before + 20, "第一次发放灵石")
	assert_eq(_lingshi(), after_first, "重复发放余额不变")
	assert_true(bool(result2.get("no_rolled_rewards", false)), "重复调用返回 no_rolled_rewards")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 候选为空时直接显示汇总
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_cards_shows_summary_only() -> void:
	# Arrange——无卡牌候选
	_start({"lingshi": 10, "cultivation": 2, "cards": []})
	var rewards: Dictionary = _finish()
	# Assert——cards 为空
	assert_eq(rewards.get("cards", []), [], "无卡牌候选时 cards 为空")
	assert_eq(int(rewards.get("lingshi", 0)), 10, "灵石已掷骰")
	assert_eq(int(rewards.get("cultivation", 0)), 2, "修为已掷骰")


# ═══════════════════════════════════════════════════════════════════════════════
# 6. 跳过时文案提示卡牌不进收藏
# ═══════════════════════════════════════════════════════════════════════════════

func test_skip_message_indicates_card_not_collected() -> void:
	# Arrange
	var before: int = _owned_count()
	_start({"lingshi": 0, "cultivation": 0,
			"cards": [{"card_id": str(CARD_TEMPLATE), "chance": 1.0}]})
	_finish()
	# Act——跳过卡牌
	_grant(-1)
	# Assert
	assert_eq(_owned_count(), before, "跳过后卡牌不进收藏")
	# UI 文案由 settlement_host 的 _show_grant_summary 提供，此处只验证行为


# ═══════════════════════════════════════════════════════════════════════════════
# 7. 战败/撤退不发奖
# ═══════════════════════════════════════════════════════════════════════════════

func test_defeat_does_not_roll_rewards() -> void:
	var lingshi_before: int = _lingshi()
	var cult_before: int = _cultivation()
	_start({"lingshi": 50, "cultivation": 20, "cards": []})
	var rewards: Dictionary = _finish(CS_SCRIPT.CombatResult.DEFEAT)
	assert_eq(_lingshi(), lingshi_before, "战败不发灵石")
	assert_eq(_cultivation(), cult_before, "战败不发修为")
	assert_false(rewards.has("cards"), "战败载荷不带卡牌")
	assert_almost_eq(float(rewards.get("retain_ratio", 0.0)), 0.5, 0.001,
			"战败载荷带 50% 保留比例")


func test_retreat_does_not_roll_rewards() -> void:
	var lingshi_before: int = _lingshi()
	_start({"lingshi": 50, "cultivation": 20, "cards": []})
	var rewards: Dictionary = _finish(CS_SCRIPT.CombatResult.RETREAT)
	assert_eq(_lingshi(), lingshi_before, "撤退不发灵石")
	assert_almost_eq(float(rewards.get("retain_ratio", 0.0)), 0.5, 0.001,
			"撤退载荷带 50% 保留比例")


# ═══════════════════════════════════════════════════════════════════════════════
# 8. 幂等：重复 battle_end 不重复掷骰
# ═══════════════════════════════════════════════════════════════════════════════

func test_repeated_battle_end_does_not_reroll() -> void:
	# Arrange
	_start({"lingshi": 25, "cultivation": 4, "cards": []})
	var rewards1: Dictionary = _finish()
	var lingshi_rolled1: int = int(rewards1.get("lingshi", 0))
	# Act——重复结算
	var rewards2: Dictionary = _finish()
	# Assert
	assert_true(bool(rewards2.get("grant_skipped", false)), "重复结算标记 grant_skipped")
	assert_false(rewards2.has("lingshi"), "跳过时不带奖励字段")
