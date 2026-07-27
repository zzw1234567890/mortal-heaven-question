# VERTICAL SLICE - NOT FOR PRODUCTION
# Date: 2026-07-27
##
## 战斗编排器 —— 双方 6 阵位卡牌对战。
## 状态机：PREPARATION → PLAY → ENEMY → CHECK → (循环)
## 角色选择 → 角色部署 + 敌方部署 → 回合循环
## 每回合抽 3 张卡，玩家打出任意数量后点"结束回合"

class_name VSBattleController
extends Node

enum BattlePhase { PREPARATION, PLAY, ENEMY, CHECK }

enum TargetSelectionMode { NONE, SELECTING_HEAL, SELECTING_SHIELD }

@onready var player_state: VSPlayerState = %PlayerState
@onready var enemy_ai: VSEnemyAI = %EnemyAI
@onready var deployment: VSDeploymentState = %DeploymentState
@onready var hud: VSBattleHUD = %BattleHUD

var _current_phase: BattlePhase = BattlePhase.PREPARATION
var _hand_cards: Array[Dictionary] = []
var _hand_size: int = 3
var _battle_over: bool = false

var _target_selection_mode: TargetSelectionMode = TargetSelectionMode.NONE
var _pending_card: Dictionary = {}


func _ready() -> void:
	hud.setup(player_state, enemy_ai, deployment)
	hud.end_turn_button.pressed.connect(_on_end_turn_pressed)
	hud.return_button.pressed.connect(_on_return_to_menu_pressed)
	hud.character_slot_clicked.connect(_on_ally_slot_clicked)

	_start_character_selection()


func _start_character_selection() -> void:
	var sel := VSCharacterSelectionScreen.new()
	add_child(sel)
	sel.characters_selected.connect(_on_characters_selected)


func _on_characters_selected(character_ids: Array[String]) -> void:
	# 关闭选择界面
	var sel = get_node_or_null("VSCharacterSelectionScreen")
	if sel:
		sel.queue_free()

	# 部署玩家角色
	for i in range(character_ids.size()):
		var cd: Dictionary = VSCharacterData.CHARACTERS[character_ids[i]]
		deployment.deploy_character(i, character_ids[i], cd["max_hp"], cd["attack"])

	# 部署敌方角色（数量 = 玩家数量）
	enemy_ai.deploy_random(character_ids.size())

	# 通知 HUD 刷新敌方显示
	for i in range(6):
		var es: Dictionary = enemy_ai.get_slot(i)
		if es.get("character_id", "") != "":
			hud._on_enemy_hp_changed(i, 0, es["current_hp"])

	_start_turn()


func _start_turn() -> void:
	if _battle_over:
		return

	_current_phase = BattlePhase.PREPARATION
	player_state.start_turn()
	_draw_hand()

	_current_phase = BattlePhase.PLAY
	hud.set_turn_label("第 %d 回合" % player_state.turn_number)


func _draw_hand() -> void:
	_hand_cards.clear()
	for child in hud.hand_container.get_children():
		child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in range(_hand_size):
		var idx := rng.randi_range(0, VSCardData.STARTING_DECK.size() - 1)
		var cid: String = VSCardData.STARTING_DECK[idx]
		var cd: Dictionary = VSCardData.CARDS[cid].duplicate()
		cd["id"] = cid
		_hand_cards.append(cd)
	_render_hand()


func _render_hand() -> void:
	for card in _hand_cards:
		var w := VSCardWidget.new()
		w.setup(card)
		w.set_can_play(player_state.can_afford(card.get("cost", 0)))
		w.card_played.connect(_on_card_played)
		hud.hand_container.add_child(w)


func _on_card_played(card_id: String) -> void:
	if _current_phase != BattlePhase.PLAY or _battle_over:
		return
	if _target_selection_mode != TargetSelectionMode.NONE:
		return

	var card_def: Dictionary = {}
	var _idx: int = -1
	for i in range(_hand_cards.size()):
		if _hand_cards[i].get("id") == card_id:
			card_def = _hand_cards[i]
			_idx = i
			break
	if card_def.is_empty():
		return

	var cost: int = card_def.get("cost", 0)
	if not player_state.can_afford(cost):
		return

	var etype: String = card_def.get("type", "")
	var target: String = card_def.get("target", "enemy")

	if etype == "heal" or etype == "shield":
		if target == "ally":
			_pending_card = card_def
			if etype == "heal":
				_target_selection_mode = TargetSelectionMode.SELECTING_HEAL
				hud.enter_target_selection_mode("选择治疗目标")
			else:
				_target_selection_mode = TargetSelectionMode.SELECTING_SHIELD
				hud.enter_target_selection_mode("选择护盾目标")
			return

	_execute_card_effect(card_def, -1)


func _on_ally_slot_clicked(slot_index: int) -> void:
	if _target_selection_mode == TargetSelectionMode.NONE:
		return
	var cd: Dictionary = deployment.get_character(slot_index)
	if not cd.get("is_alive", false):
		return
	_execute_card_effect(_pending_card, slot_index)
	_target_selection_mode = TargetSelectionMode.NONE
	_pending_card = {}
	hud.exit_target_selection_mode()


func _execute_card_effect(card_def: Dictionary, target_slot: int) -> void:
	var cost: int = card_def.get("cost", 0)
	player_state.spend_mana(cost)

	var etype: String = card_def.get("type", "")
	var val: int = card_def.get("value", 0)
	var target: String = card_def.get("target", "enemy")

	match etype:
		"damage":
			if target == "enemy":
				# 攻击随机存活的敌方
				var alive := enemy_ai.get_front_row_alive()
				if alive.is_empty():
					alive = enemy_ai.get_back_row_alive()
				if not alive.is_empty():
					var tgt: int = alive[randi() % alive.size()]
					enemy_ai.take_damage(tgt, val)
					hud.log_action(card_def.get("name", ""), "造成伤害", val)
					if enemy_ai.is_all_dead():
						_battle_over = true
						await get_tree().create_timer(0.3).timeout
						_show_reward_screen()
						return
		"heal":
			if target_slot >= 0:
				deployment.heal_character(target_slot, val)
				var cd2: Dictionary = deployment.get_character(target_slot)
				var cn: String = VSCharacterData.CHARACTERS.get(cd2.get("character_id", ""), {}).get("name", "角色")
				hud.log_action(card_def.get("name", ""), "治疗 %s" % cn, val)
		"shield":
			if target_slot >= 0:
				deployment.add_shield(target_slot, val)
				var cd2: Dictionary = deployment.get_character(target_slot)
				var cn: String = VSCharacterData.CHARACTERS.get(cd2.get("character_id", ""), {}).get("name", "角色")
				hud.log_action(card_def.get("name", ""), "%s 获得护盾" % cn, val)

	# 从手牌移除
	var rem: int = -1
	for i in range(_hand_cards.size()):
		if _hand_cards[i].get("id") == card_def.get("id"):
			rem = i
			break
	if rem >= 0:
		_hand_cards.remove_at(rem)
		if rem < hud.hand_container.get_child_count():
			hud.hand_container.get_child(rem).queue_free()
	_refresh_affordability()


func _refresh_affordability() -> void:
	var kids := hud.hand_container.get_children()
	for i in range(mini(kids.size(), _hand_cards.size())):
		var w := kids[i] as VSCardWidget
		if w:
			w.set_can_play(player_state.can_afford(_hand_cards[i].get("cost", 0)))


func _on_end_turn_pressed() -> void:
	if _current_phase != BattlePhase.PLAY or _battle_over:
		return
	if _target_selection_mode != TargetSelectionMode.NONE:
		return

	_current_phase = BattlePhase.ENEMY
	hud.set_turn_label("敌方回合…")
	hud.end_turn_button.disabled = true

	for child in hud.hand_container.get_children():
		child.queue_free()
	_hand_cards.clear()

	await _ally_auto_attack()
	if _battle_over:
		return

	await _enemy_turn()
	if _battle_over:
		return

	_current_phase = BattlePhase.CHECK
	_start_turn()


func _ally_auto_attack() -> void:
	var total_dmg: int = deployment.get_total_attack()
	if total_dmg <= 0:
		return

	# 攻击随机敌方
	var alive := enemy_ai.get_front_row_alive()
	if alive.is_empty():
		alive = enemy_ai.get_back_row_alive()
	if alive.is_empty():
		return

	var tgt: int = alive[randi() % alive.size()]
	enemy_ai.take_damage(tgt, total_dmg)
	hud.log_action("角色自动攻击", "造成伤害", total_dmg)

	if enemy_ai.is_all_dead():
		_battle_over = true
		await get_tree().create_timer(0.3).timeout
		_show_reward_screen()
		return
	await get_tree().create_timer(0.3).timeout


func _enemy_turn() -> void:
	var action: Dictionary = enemy_ai.get_next_action()
	var dmg: int = action.get("damage", 0)
	var aname: String = action.get("name", "")
	hud.log_action(aname, "---", dmg)
	await get_tree().create_timer(0.4).timeout

	# 攻击随机玩家存活角色（优先前排）
	var alive := deployment.get_front_row_alive()
	if alive.is_empty():
		alive = deployment.get_back_row_alive()
	if alive.is_empty():
		_battle_over = true
		await get_tree().create_timer(0.3).timeout
		hud.show_defeat()
		return

	var tgt: int = alive[randi() % alive.size()]
	deployment.damage_character(tgt, dmg)

	if deployment.is_all_dead():
		_battle_over = true
		await get_tree().create_timer(0.3).timeout
		hud.show_defeat()
		return


func _show_reward_screen() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rc: Array[String] = []
	for _i in range(rng.randi_range(1, 2)):
		rc.append(VSCardData.STARTING_DECK[rng.randi_range(0, VSCardData.STARTING_DECK.size() - 1)])
	var rl: int = rng.randi_range(10, 30)

	var rs := VSRewardScreen.new()
	add_child(rs)
	rs.set_rewards(rc, rl)
	rs.reward_collected.connect(_on_reward_collected)


func _on_reward_collected() -> void:
	var rs = get_node_or_null("VSRewardScreen")
	if rs:
		rs.queue_free()
	get_tree().change_scene_to_file("res://prototypes/cultivation-card-battle-vertical-slice/scenes/main_menu.tscn")


func _on_return_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://prototypes/cultivation-card-battle-vertical-slice/scenes/main_menu.tscn")
