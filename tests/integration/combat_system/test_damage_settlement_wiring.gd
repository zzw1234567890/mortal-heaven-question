extends GutTest
## Sprint 18 集成测试：伤害落库 → 阵亡信号 → 阵位清空（DEBT-CBT-018-1）。
##
## 覆盖三处补链：[br]
##   1. [code]_resolve_attack_queue[/code] 结算后把 [code]current_hp[/code] /
##      [code]is_alive[/code] 回写防御方（敌方 [code]EnemyBattleState[/code] /
##      阵容 Dictionary）；[br]
##   2. [code]play_card[/code] 效果结算同样落库（[code]combat_card_resolver[/code]
##      的阵亡检查不再是 raw is_kill 透传）；[br]
##   3. 我方 HP 归零 → [code]character_died(side=0)[/code] → 战斗侧自动
##      [code]DeploymentSystem.remove_character()[/code] 清位。[br]
## [br]测试策略（先例 test_battle_end_check_wiring.gd）：[code]CS_SCRIPT.new()[/code] +
## [code]set_auto_advance(false)[/code] + [code]set_scene_change(false)[/code]；
## 真实 DeploymentSystem / BindingManager / CardSystem Autoload 参与。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")

var cs: Node = null
var _release_ids: Array = []
var _ai_roster_before: Array = []


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	_release_ids.clear()
	_ai_roster_before = AISystem.get_enemy_roster().duplicate()


func after_each() -> void:
	if cs != null:
		cs.free()
		cs = null
	for cid: int in _release_ids:
		DeploymentSystem.remove_character(cid)
	_release_ids.clear()
	CostSystem.clear_for_battle_end()
	InputManager.clear_locks(&"combat_system")
	AISystem.set_enemy_roster(_ai_roster_before)
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false


## 上场一名角色并登记清理。
func _deploy_character(character_id: int) -> bool:
	var ok: bool = DeploymentSystem.setup_field([character_id], {})
	if ok:
		_release_ids.append(character_id)
	return ok


## 该角色是否仍在阵位上。
func _on_field(character_id: int) -> bool:
	return DeploymentSystem.get_character_slot(character_id) != -1


## 注入手牌（0 费卡）。
func _setup_hand(card_instance_id: int) -> void:
	cs.call("set_card_instances", {card_instance_id: {
		"card_instance_id": card_instance_id, "cost": 0, "template_id": "test_card",
	}})
	cs.call("set_hand", [{"card_instance_id": card_instance_id, "cost": 0,
			"template_id": "test_card"}])
	cs.call("advance_phase")  # PREPARATION → DRAW
	cs.call("advance_phase")  # DRAW → PLAY


# ═══════════════════════════════════════════════════════════════════════════════
# 攻击结算 HP 回写（EnemyBattleState 对象）
# ═══════════════════════════════════════════════════════════════════════════════

func test_attack_resolution_writes_back_enemy_hp() -> void:
	# Arrange——敌方 EnemyBattleState（对象条目）+ 攻击队列
	var enemy := EnemyBattleState.new()
	enemy.current_hp = 10
	enemy.max_hp = 10
	enemy.is_alive = true
	cs.call("battle_start", {"enemy_roster": [enemy], "character_ids": []})
	cs.call("set_attack_queue", [{
		"attacker_id": 1, "target_id": 100000,
		"attacker_atk": 5, "target_def": 2,
		"attacker_realm": 1, "defender_realm": 1, "target_hp": 10,
	}])
	# Act
	cs.call("_resolve_attack_queue")
	# Assert——damage=max(1,5-2)=3 → 10-3=7
	assert_eq(enemy.current_hp, 7, "防御方 current_hp 应回写为 7")
	assert_true(enemy.is_alive, "未归零仍存活")


## DEBT-CBT-018-8：队列条目带防御方百分比减伤时，落库的伤害按乘算扣减（GDD §公式）。
func test_attack_resolution_applies_damage_reduction_from_queue() -> void:
	# Arrange——ATK 10 / DEF 0 → 10；防御方减伤 10% → floor(10×0.9)=9
	var enemy := EnemyBattleState.new()
	enemy.current_hp = 10
	enemy.max_hp = 10
	enemy.is_alive = true
	cs.call("battle_start", {"enemy_roster": [enemy], "character_ids": []})
	cs.call("set_attack_queue", [{
		"attacker_id": 1, "target_id": 100000,
		"attacker_atk": 10, "target_def": 0,
		"attacker_realm": 1, "defender_realm": 1, "target_hp": 10,
		"damage_reduction_pcts": [10],
	}])
	# Act
	cs.call("_resolve_attack_queue")
	# Assert——10-9=1
	assert_eq(enemy.current_hp, 1, "减伤 10% 后应扣 9 点（10 → 1）")


func test_attack_resolution_marks_enemy_dead_once() -> void:
	# Arrange——HP 3，一击致死
	var enemy := EnemyBattleState.new()
	enemy.current_hp = 3
	enemy.max_hp = 10
	enemy.is_alive = true
	cs.call("battle_start", {"enemy_roster": [enemy], "character_ids": []})
	cs.call("set_attack_queue", [{
		"attacker_id": 1, "target_id": 100000,
		"attacker_atk": 5, "target_def": 2,
		"attacker_realm": 1, "defender_realm": 1, "target_hp": 3,
	}])
	var deaths: Array = []
	cs.connect("character_died", func(char_id: int, side: int, _ids: Array) -> void:
		deaths.append({"id": char_id, "side": side}))
	# Act——同一目标再挨一次（已阵亡，不应重复广播）
	cs.call("_resolve_attack_queue")
	cs.call("_resolve_attack_queue")
	# Assert
	assert_eq(enemy.current_hp, 0, "HP 应夹到 0")
	assert_false(enemy.is_alive, "is_alive 应回写 false")
	assert_eq(deaths.size(), 1, "character_died 只发一次（幂等）")
	assert_eq(deaths[0]["side"], 1, "敌方 side=1")


## 敌方阵容为 Dictionary 桩时——原地改键，END 判定可见。
func test_attack_resolution_writes_back_enemy_dictionary() -> void:
	var enemy: Dictionary = {"character_id": 900, "current_hp": 5, "max_hp": 5, "is_alive": true}
	cs.call("battle_start", {"enemy_roster": [enemy], "character_ids": []})
	cs.call("set_attack_queue", [{
		"attacker_id": 1, "target_id": 900,
		"attacker_atk": 9, "target_def": 0,
		"attacker_realm": 1, "defender_realm": 1, "target_hp": 5,
	}])
	# Act
	cs.call("_resolve_attack_queue")
	# Assert
	assert_eq(int(enemy["current_hp"]), 0, "Dictionary 条目 current_hp 应原地归零")
	assert_false(bool(enemy["is_alive"]), "Dictionary 条目 is_alive 应原地置 false")


# ═══════════════════════════════════════════════════════════════════════════════
# 我方阵亡 → 自动清位
# ═══════════════════════════════════════════════════════════════════════════════

func test_player_death_clears_deployment_slot() -> void:
	# Arrange——角色上场 + 注入 10 HP
	assert_true(_deploy_character(101), "前置：角色上场成功")
	cs.call("battle_start", {
		"enemy_roster": [{"is_alive": true}],
		"character_ids": [101],
		"player_stats": {101: {"current_hp": 10, "max_hp": 10}},
	})
	assert_true(_on_field(101), "前置：角色在阵位上")
	_setup_hand(1)
	cs.set("resolve_cb", Callable(func(_card, _targets) -> Array:
		return [{"target_id": 101, "damage": 10, "side": 0}]))
	# Act
	assert_true(cs.call("play_card", 1, []), "出牌成功")
	# Assert——HP 归零 → character_died → 自动清位
	assert_eq(int(cs.call("get_character_hp", 101)["current"]), 0, "我方 HP 应落库为 0")
	assert_false(_on_field(101), "阵亡后阵位应被自动清空")
	_release_ids.clear()  # 已被清位，after_each 无需再清


func test_enemy_death_does_not_clear_player_field() -> void:
	# Arrange——敌方被打死，我方阵位不受影响
	assert_true(_deploy_character(102), "前置：角色上场成功")
	cs.call("battle_start", {"enemy_roster": [{"is_alive": true}], "character_ids": [102]})
	_setup_hand(2)
	cs.set("resolve_cb", Callable(func(_card, _targets) -> Array:
		return [{"target_id": 100000, "damage": 999, "side": 1}]))
	# Act
	cs.call("play_card", 2, [])
	# Assert
	assert_true(_on_field(102), "我方阵位不应被敌方阵亡波及")


# ═══════════════════════════════════════════════════════════════════════════════
# 信息不足 / 治疗 / 读契约
# ═══════════════════════════════════════════════════════════════════════════════

func test_damage_without_hp_data_does_not_fabricate_death() -> void:
	# Arrange——未上场的角色无 HP 记录，仅 is_kill 声明
	cs.call("battle_start", {"enemy_roster": [{"is_alive": true}], "character_ids": []})
	_setup_hand(3)
	cs.set("resolve_cb", Callable(func(_card, _targets) -> Array:
		return [{"target_id": 777, "damage": 5, "side": 1, "is_kill": false}]))
	var deaths: Array = []
	cs.connect("character_died", func(char_id: int, _side: int, _ids: Array) -> void:
		deaths.append(char_id))
	# Act
	cs.call("play_card", 3, [])
	# Assert——无 HP 数据且 is_kill=false → 不发阵亡信号、不臆造 HP
	assert_eq(int(cs.call("get_character_hp", 777)["current"]), 0, "未知角色 HP 读 0")
	assert_eq(deaths.size(), 0, "信息不足时不发 character_died")


func test_healing_caps_at_max_hp() -> void:
	# Arrange——我方 5/10，负伤害治疗
	assert_true(_deploy_character(103), "前置：角色上场成功")
	cs.call("battle_start", {
		"enemy_roster": [{"is_alive": true}],
		"character_ids": [103],
		"player_stats": {103: {"current_hp": 5, "max_hp": 10}},
	})
	# Act——治疗 100 点
	var state: RefCounted = cs.call("_get_roster_state")
	var outcome: Dictionary = state.call("apply_damage", 103, -100)
	# Assert
	assert_eq(int(outcome["current_hp"]), 10, "治疗不应超过 max_hp")
	assert_false(bool(outcome["died"]), "治疗不会判死")
	assert_eq(int(cs.call("get_character_hp", 103)["max"]), 10, "读取契约 current/max")


func test_character_hp_reader_contract() -> void:
	# Arrange
	assert_true(_deploy_character(104), "前置：角色上场成功")
	cs.call("battle_start", {
		"enemy_roster": [{"is_alive": true}],
		"character_ids": [104],
		"player_stats": {104: {"current_hp": 7, "max_hp": 9}},
	})
	# Act
	var hp: Dictionary = cs.call("get_character_hp", 104)
	# Assert——战斗 UI 的 hp_reader_cb 契约
	assert_true(hp.has("current") and hp.has("max"), "应提供 current/max 两键")
	assert_eq(int(hp["current"]), 7, "current=7")
	assert_eq(int(hp["max"]), 9, "max=9")


# ═══════════════════════════════════════════════════════════════════════════════
# character_damaged 广播（Sprint 18 表现层——伤害飘字/HP 条的增量入口）
# ═══════════════════════════════════════════════════════════════════════════════

## 攻击结算落库后广播一次增量——只带伤害值，不带 HP 终值（ADR-0008）。
func test_attack_resolution_emits_character_damaged_payload() -> void:
	# Arrange——敌方 10 HP 吃 3 点伤害
	var enemy := EnemyBattleState.new()
	enemy.current_hp = 10
	enemy.max_hp = 10
	enemy.is_alive = true
	cs.call("battle_start", {"enemy_roster": [enemy], "character_ids": []})
	cs.call("set_attack_queue", [{
		"attacker_id": 1, "target_id": 100000,
		"attacker_atk": 5, "target_def": 2,
		"attacker_realm": 1, "defender_realm": 1, "target_hp": 10,
	}])
	var payloads: Array = []
	cs.connect("character_damaged", func(data: Dictionary) -> void:
		payloads.append(data.duplicate(true)))
	# Act
	cs.call("_resolve_attack_queue")
	# Assert
	assert_eq(payloads.size(), 1, "一次伤害广播一次 character_damaged")
	var payload: Dictionary = payloads[0]
	assert_eq(int(payload["character_id"]), 100000, "载荷带目标 ID")
	assert_eq(int(payload["side"]), 1, "载荷带阵营（敌 side=1）")
	assert_eq(int(payload["damage"]), 3, "载荷只带本次增量 3")
	assert_false(bool(payload["is_kill"]), "未致死 is_kill=false")
	assert_false(payload.has("current_hp"), "载荷不带 HP 终值（消费方现读）")


## 出牌效果伤害与攻击结算走同一个广播出口（表现层无需分辨伤害来源）。
func test_play_card_damage_emits_character_damaged() -> void:
	# Arrange——敌方须有可信 HP（否则落库跳过、不广播）
	cs.call("battle_start", {"enemy_roster": [
		{"current_hp": 20, "max_hp": 20, "is_alive": true}], "character_ids": []})
	_setup_hand(4)
	cs.set("resolve_cb", Callable(func(_card, _targets) -> Array:
		return [{"target_id": 100000, "damage": 6, "side": 1}]))
	var payloads: Array = []
	cs.connect("character_damaged", func(data: Dictionary) -> void:
		payloads.append(data))
	# Act
	cs.call("play_card", 4, [])
	# Assert
	assert_eq(payloads.size(), 1, "出牌伤害同样广播一次")
	assert_eq(int(payloads[0]["damage"]), 6, "增量=出牌效果伤害 6")


## 无可信 HP 的目标不广播（信息不足——UI 不该为未知角色飘字）。
func test_unknown_target_does_not_emit_character_damaged() -> void:
	# Arrange
	cs.call("battle_start", {"enemy_roster": [{"is_alive": true}], "character_ids": []})
	_setup_hand(5)
	cs.set("resolve_cb", Callable(func(_card, _targets) -> Array:
		return [{"target_id": 888, "damage": 5, "side": 1}]))
	var payloads: Array = []
	cs.connect("character_damaged", func(data: Dictionary) -> void:
		payloads.append(data))
	# Act
	cs.call("play_card", 5, [])
	# Assert
	assert_eq(payloads.size(), 0, "无 HP 数据的目标不广播增量")

