# VERTICAL SLICE - NOT FOR PRODUCTION
# Date: 2026-07-28
##
## 战斗编排器 —— 流程控制 + 回合管理 + 渡劫突破 + 绑定效果。

class_name VSBattleController
extends Node

enum BattlePhase { PREPARATION, PLAY, ENEMY, CHECK }
enum TargetSelectionMode { NONE, SELECTING_HEAL, SELECTING_SHIELD, SELECTING_BIND }

@onready var player_state: VSPlayerState = %PlayerState
@onready var enemy_ai: VSEnemyAI = %EnemyAI
@onready var deployment: VSDeploymentState = %DeploymentState
@onready var hud: VSBattleHUD = %BattleHUD

var _phase: BattlePhase = BattlePhase.PREPARATION
var _hand: Array[Dictionary] = []
var _over: bool = false
var _exec: VSCardExecutor
var _reward: VSRewardScreen
var _trib: bool = false


func _ready() -> void:
	player_state.setup()
	_exec = VSCardExecutor.new()
	_exec.setup(player_state, enemy_ai, deployment, hud, _hand, get_tree())
	_exec.card_consumed.connect(_on_card_consumed)
	_exec.enemy_all_dead.connect(_on_card_enemy_death)

	hud.setup(player_state, enemy_ai, deployment)
	hud.end_turn_button.pressed.connect(_on_end_turn)
	hud.return_button.pressed.connect(_on_return)
	hud.character_slot_clicked.connect(_on_slot_click)
	hud.breakthrough_button_pressed.connect(_on_breakthrough)
	deployment.bound_effect_triggered.connect(_on_bound_effect)
	_start_select()


func _start_select() -> void:
	var s := VSCharacterSelectionScreen.new(); add_child(s)
	s.characters_selected.connect(_on_characters_selected)


func _on_characters_selected(ids: Array[String]) -> void:
	var s = get_node_or_null("VSCharacterSelectionScreen")
	if s: s.queue_free()
	for i in ids.size():
		var d: Dictionary = VSCharacterData.CHARACTERS[ids[i]]
		deployment.deploy_character(i, ids[i], d["max_hp"], d["attack"])
	var n: int = 3 if player_state.realm_level >= VSRealmData.RealmLevel.FOUNDATION else 2
	enemy_ai.deploy_random(n, player_state.realm_level)
	hud.update_enemy_display(enemy_ai)
	_start_turn()


## === 回合 =======================================================================

func _start_turn() -> void:
	if _over: return
	_phase = BattlePhase.PREPARATION; player_state.start_turn(); _draw()
	_trigger_all_binds()
	_phase = BattlePhase.PLAY
	hud.set_turn_label("第 %d 回合 · %s" % [player_state.turn_number, VSRealmData.get_realm_name(player_state.realm_level)])


func _draw() -> void:
	_hand.clear()
	for c in hud.hand_container.get_children(): c.queue_free()
	var r := RandomNumberGenerator.new(); r.randomize()
	for _i in range(3):
		var cid := VSCardData.STARTING_DECK[r.randi_range(0, VSCardData.STARTING_DECK.size() - 1)]
		var d: Dictionary = VSCardData.CARDS[cid].duplicate()
		d["id"] = cid
		_hand.append(d)
	_render_hand()


func _render_hand() -> void:
	for d in _hand:
		var w := VSCardWidget.new(); w.setup(d)
		w.set_can_play(player_state.can_afford(d.get("cost", 0)))
		w.card_played.connect(_on_card_played)
		hud.hand_container.add_child(w)


func _on_card_played(cid: String) -> void:
	_exec.try_play(cid, _phase)


func _on_card_consumed() -> void:
	_refresh()


func _on_card_enemy_death() -> void:
	_over = true
	await get_tree().create_timer(0.3).timeout
	if _trib:
		_on_trib_win()
	else:
		_show_reward()


func _on_slot_click(slot: int) -> void:
	_exec.on_slot_click(slot); _refresh()


func _refresh() -> void:
	var ks := hud.hand_container.get_children()
	for i in range(mini(ks.size(), _hand.size())):
		var w := ks[i] as VSCardWidget
		if w: w.set_can_play(player_state.can_afford(_hand[i].get("cost", 0)))


func _on_end_turn() -> void:
	if _phase != BattlePhase.PLAY or _over: return
	if _exec.get_targ_mode() != 0: return
	_phase = BattlePhase.ENEMY; hud.set_turn_label("敌方回合…"); hud.end_turn_button.disabled = true
	for c in hud.hand_container.get_children(): c.queue_free()
	_hand.clear()
	await _ally_attack()
	if _over: return
	await _enemy_turn()
	if _over: return
	_phase = BattlePhase.CHECK; _start_turn()


## === 自动战斗 ===================================================================

func _ally_attack() -> void:
	var sl := deployment.get_alive_characters(); sl.sort()
	if sl.is_empty(): return
	for s in sl:
		if _over: return
		var atk: int = deployment.get_character(s).get("attack", 0)
		if atk <= 0: continue
		var an: String = deployment.get_character_name(s)
		var el := enemy_ai.get_front_row_alive()
		if el.is_empty(): el = enemy_ai.get_back_row_alive()
		if el.is_empty(): return
		var t: int = el[randi() % el.size()]
		enemy_ai.take_damage(t, atk)
		hud.log_action(an, "攻击", enemy_ai.get_enemy_name(t), atk)
		if enemy_ai.is_all_dead():
			_over = true
			await get_tree().create_timer(0.3).timeout
			if _trib:
				_on_trib_win()
			else:
				_show_reward()
			return
		await get_tree().create_timer(0.3).timeout


func _enemy_turn() -> void:
	for sl in enemy_ai.get_all_alive():
		var a := enemy_ai.get_slot_action(sl)
		var en: String = enemy_ai.get_enemy_name(sl)
		var al := deployment.get_front_row_alive()
		if al.is_empty(): al = deployment.get_back_row_alive()
		if al.is_empty():
			_over = true
			await get_tree().create_timer(0.3).timeout
			hud.show_defeat()
			return
		var t: int = al[randi() % al.size()]
		hud.log_action(en, a["name"], deployment.get_character_name(t), a["damage"])
		await get_tree().create_timer(0.4).timeout
		deployment.damage_character(t, a["damage"])
		if deployment.is_all_dead():
			_over = true
			await get_tree().create_timer(0.3).timeout
			if _trib:
				_on_trib_lose()
			else:
				hud.show_defeat()
			return


## === 奖励 =======================================================================

func _show_reward() -> void:
	var r := RandomNumberGenerator.new(); r.randomize()
	var rc: Array[String] = []
	for _i in range(r.randi_range(1, 2)):
		rc.append(VSCardData.STARTING_DECK[r.randi_range(0, VSCardData.STARTING_DECK.size() - 1)])
	_clear_all_binds()
	var rs := VSRewardScreen.new(); _reward = rs; add_child(rs)
	await get_tree().process_frame
	rs.set_rewards(rc, r.randi_range(10, 30), r.randi_range(60, 100))
	rs.reward_collected.connect(_on_reward)


func _on_reward(cul: int) -> void:
	if _reward: _reward.queue_free(); _reward = null
	player_state.cultivation_system.gain_cultivation(cul, "战斗奖励")
	if player_state.cultivation_system.is_breakthrough_ready():
		hud.show_breakthrough_ready()
	else:
		_next_battle()


func _next_battle() -> void:
	_over = false; _phase = BattlePhase.PREPARATION
	enemy_ai.reset_all()
	# 清除旧部署，让玩家重新选择角色
	for i in range(6):
		deployment.remove_character(i)
	hud.reset_display()
	_start_select()

## === 渡劫 =======================================================================

func _on_breakthrough() -> void:
	if not player_state.cultivation_system.is_breakthrough_ready() or _trib: return
	_trib = true; _over = false; _phase = BattlePhase.PREPARATION
	hud.show_tribulation_intro(); await get_tree().create_timer(2.0).timeout
	enemy_ai.reset_all(); enemy_ai.deploy_tribulation(player_state.realm_level)
	hud.update_enemy_display(enemy_ai)
	_heal_team(); hud.set_turn_label("渡劫战 —— 天道考验！")
	hud.hide_breakthrough_button()
	_start_turn()


func _on_trib_win() -> void:
	var nn := player_state.attempt_breakthrough()
	if not nn.is_empty():
		hud.show_breakthrough_success(nn); _trib = false
		await get_tree().create_timer(2.0).timeout; _next_battle()


func _on_trib_lose() -> void:
	_trib = false
	var c: int = player_state.cultivation_system.get_current_cultivation()
	player_state.cultivation_system.consume_progress(int(ceil(float(c) * 0.3)))
	hud.show_tribulation_failed(); await get_tree().create_timer(2.5).timeout
	enemy_ai.reset_all()
	for i in range(6):
		deployment.remove_character(i)
	hud.reset_display()
	_start_select()


func _heal_team() -> void:
	for i in range(6):
		var d := deployment.get_character(i)
		if d.get("is_alive", false):
			var m: int = VSCharacterData.CHARACTERS.get(d.get("character_id", ""), {}).get("max_hp", 0)
			deployment.heal_character(i, m)


func _on_return() -> void:
	get_tree().change_scene_to_file("res://prototypes/cultivation-card-battle-vertical-slice/scenes/main_menu.tscn")


## === 绑定 =======================================================================

func _clear_all_binds() -> void:
	for i in range(6): deployment.clear_bound_cards(i)

func _trigger_all_binds() -> void:
	for i in range(6):
		if deployment.get_character(i).get("is_alive", false):
			deployment.trigger_bound_effects(i)

func _on_bound_effect(slot: int, cid: String, sub: String, val: int) -> void:
	match sub:
		"regen":
			deployment.heal_character(slot, val)
			hud.log_action("绑定·%s" % cid, "回复", deployment.get_character_name(slot), val)
		"burn":
			var al := enemy_ai.get_front_row_alive()
			if al.is_empty(): al = enemy_ai.get_back_row_alive()
			if not al.is_empty():
				var t: int = al[randi() % al.size()]
				enemy_ai.take_damage(t, val)
				hud.log_action("绑定·%s" % cid, "灼烧", enemy_ai.get_enemy_name(t), val)
				if enemy_ai.is_all_dead():
					_over = true
					await get_tree().create_timer(0.3).timeout
					if _trib:
						_on_trib_win()
					else:
						_show_reward()
		"barrier":
			deployment.add_shield(slot, val)
			hud.log_action("绑定·%s" % cid, "护盾", deployment.get_character_name(slot), val)
		"aoe_burn":
			var al := enemy_ai.get_front_row_alive()
			if al.is_empty(): al = enemy_ai.get_back_row_alive()
			if not al.is_empty():
				var t: int = al[randi() % al.size()]
				enemy_ai.take_damage(t, val)
				hud.log_action("绑定·%s" % cid, "雷击", enemy_ai.get_enemy_name(t), val)
				if enemy_ai.is_all_dead():
					_over = true
					await get_tree().create_timer(0.3).timeout
					if _trib:
						_on_trib_win()
					else:
						_show_reward()
