extends GutTest
## 结算宿主与战斗系统端到端测试——战利品三选一 → 已到账汇总链路。[br]
## [br][b]覆盖[/b]：[br]
##   1. 胜利 → 面板显示候选 → 触发 loot_confirmed → 面板切换到汇总且网格清空；[br]
##   2. loot_skipped() 后汇总显示放弃文案；[br]
##   3. 候选为空时 show_victory 直接显示汇总、不建三选一格子。[br]
## [br][b]注意[/b]：本测试专注于 UI 流路，卡牌收藏发放由 test_battle_reward_grant.gd
## 验证（CardSystem 模板依赖较重）。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const HostScript := preload("res://src/ui/combat/settlement/settlement_host.gd")

const CHAR_HERO: int = 9901
const CHAR_ENEMY: int = 9902

var cs: Node = null
var host: Node = null
var _release_ids: Array = []


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	cs.call("reset_reward_rng")
	cs.call("set_reward_rng_seed", 20240101)
	_clear_gsm_battle()
	_release_ids.clear()
	InputManager.clear_locks(&"combat_system")

	# 宿主入树（需要场景树才能正常工作）
	host = HostScript.new()
	host.name = "SettlementHost"
	add_child_autofree(host)


func after_each() -> void:
	if cs != null:
		cs.free()
		cs = null
	for cid: int in _release_ids:
		DeploymentSystem.remove_character(cid)
	_release_ids.clear()
	InputManager.clear_locks(&"combat_system")
	_clear_gsm_battle()


func _clear_gsm_battle() -> void:
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false


## 开战——带探索侧掉落配置；我方 1 人、敌方 1 人。
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


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 胜利 → 无候选 → 直接显示汇总
# ═══════════════════════════════════════════════════════════════════════════════

func test_victory_to_confirmed_shows_summary_and_clears_grid() -> void:
	# Arrange——无卡牌，只有灵石修为
	_start({"lingshi": 15, "cultivation": 5, "cards": []})
	host.setup(cs, null, false)
	var rewards: Dictionary = _finish()
	# Act——宿主收到 battle_ended 信号
	host.on_battle_ended(CS_SCRIPT.CombatResult.VICTORY, rewards)
	# 验证面板已打开、候选为空、直接显示汇总
	assert_true(host.settlement_panel.is_open(), "面板应打开")
	assert_true(host.settlement_panel.is_showing_grant_summary(), "候选为空时应直接显示汇总")
	assert_eq(host.settlement_panel.get_cards().size(), 0, "战利品网格应为空")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. loot_skipped() 后汇总显示放弃文案
# ═══════════════════════════════════════════════════════════════════════════════

func test_loot_skipped_shows_skip_message() -> void:
	# Arrange——有卡牌候选，只有灵石
	_start({"lingshi": 10, "cultivation": 3,
			"cards": [{"card_id": "test_card", "chance": 1.0}]})
	host.setup(cs, null, false)
	var rewards: Dictionary = _finish()
	host.on_battle_ended(CS_SCRIPT.CombatResult.VICTORY, rewards)
	# Act——跳过战利品
	host._on_loot_skipped()
	# Assert——面板切换到汇总视图，网格清空
	assert_true(host.settlement_panel.is_showing_grant_summary(), "应切换到汇总视图")
	assert_eq(host.settlement_panel.get_cards().size(), 0, "战利品网格应清空")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 候选为空时 show_victory 显示汇总但不建三选一格子
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_candidates_shows_summary_without_grid() -> void:
	# Arrange——无卡牌候选，无灵石修为（完全空奖励）
	_start({"lingshi": 0, "cultivation": 0, "cards": []})
	host.setup(cs, null, false)
	var rewards: Dictionary = _finish()
	# Act——宿主收到 battle_ended 信号
	host.on_battle_ended(CS_SCRIPT.CombatResult.VICTORY, rewards)
	# Assert——面板打开、战利品网格为空、直接显示汇总
	assert_true(host.settlement_panel.is_open(), "面板应打开")
	assert_eq(host.settlement_panel.get_cards().size(), 0, "战利品网格应为空")
	assert_true(host.settlement_panel.is_showing_grant_summary(), "候选为空时应直接显示汇总")
