# VERTICAL SLICE - NOT FOR PRODUCTION
# Date: 2026-07-28
##
## 卡牌执行器 —— 目标选择 + 效果执行 + 伤害路由 + 手牌管理。
## 从 battle_controller.gd 拆分，用 Callable 回调解耦。

class_name VSCardExecutor
extends RefCounted

signal card_consumed()  ## 卡牌消耗完毕 —— battle_controller 刷新费用显示
signal enemy_all_dead()  ## 敌方全灭 —— battle_controller 路由胜负

var _ps: VSPlayerState
var _ea: VSEnemyAI
var _dep: VSDeploymentState
var _hud: VSBattleHUD
var _hand: Array[Dictionary]
var _tree: SceneTree
var _targ_mode: int = 0
var _pending: Dictionary = {}


func setup(ps: VSPlayerState, ea: VSEnemyAI, dep: VSDeploymentState, hud: VSBattleHUD, hand: Array[Dictionary], tree: SceneTree) -> void:
	_ps = ps; _ea = ea; _dep = dep; _hud = hud; _hand = hand; _tree = tree


## === 卡牌打出入口 ===============================================================

func try_play(card_id: String, phase: int) -> bool:
	if phase != 1 or _targ_mode != 0:  ## PLAY
		return false
	var d := _find_card(card_id)
	if d.is_empty() or not _ps.can_afford(d.get("cost", 0)):
		return false

	var et: String = d.get("type", "")
	var tg: String = d.get("target", "enemy")

	if tg == "self":
		_execute(d, -1); return true
	if et in ["heal", "shield"] and tg == "ally":
		_pending = d; _targ_mode = 1 if et == "heal" else 2
		_hud.enter_target_selection_mode("选择治疗目标" if et == "heal" else "选择护盾目标")
		return false
	if et == "binding" and tg == "ally":
		_pending = d; _targ_mode = 3
		_hud.enter_target_selection_mode("选择绑定目标")
		return false
	_execute(d, -1); return true


func on_slot_click(slot: int) -> void:
	if _targ_mode == 0: return
	if not _dep.get_character(slot).get("is_alive", false): return
	_execute(_pending, slot)
	_targ_mode = 0; _pending = {}; _hud.exit_target_selection_mode()


func get_targ_mode() -> int:
	return _targ_mode


func _find_card(cid: String) -> Dictionary:
	for c in _hand:
		if c.get("id") == cid: return c
	return {}


## === 效果执行 ===================================================================

func _execute(d: Dictionary, slot: int) -> void:
	var cost: int = d.get("cost", 0)
	_ps.spend_mana(cost)
	var et: String = d.get("type", ""); var val: int = d.get("value", 0); var tg: String = d.get("target", "")

	if et == "mana":
		var om: int = _ps.get_current_mana()
		_ps.cost_system._current_cost += val
		_hud.log_action(d["name"], "回复灵力", "自身", val)
		_ps.cost_changed.emit(om, _ps.get_current_mana())
		_remove(d); card_consumed.emit(); return

	var mul: float = 1.0
	if et == "damage" and not tg in ["ally", "self"]:
		mul = VSRealmData.get_suppression(_ps.realm_level, _ea.get_realm_level())

	match et:
		"damage":
			var dm: int = int(ceil(val * mul))
			match tg:
				"enemy":       _dmg_random(d, dm, mul)
				"enemy_front": _dmg_front(d, dm)
				"enemy_all":   _dmg_all(d, dm)
		"heal":
			if slot >= 0:
				_dep.heal_character(slot, val)
				_hud.log_action(d["name"], "治疗", _dep.get_character_name(slot), val)
		"shield":
			if slot >= 0:
				_dep.add_shield(slot, val)
				_hud.log_action(d["name"], "护盾", _dep.get_character_name(slot), val)
		"binding":
			_bind_card(d, slot, cost)

	_remove(d); card_consumed.emit()


func _bind_card(d: Dictionary, slot: int, cost: int) -> void:
	if slot < 0: return
	if _dep.bind_card(slot, d):
		_hud.log_action(d["name"], "绑定", _dep.get_character_name(slot), 0)
	else:
		_ps.cost_system._current_cost += cost
		_hud.action_log.append_text("[color=orange]绑定失败：%s 的绑定槽已满（最多 %d 张）[/color]\n" % [
			_dep.get_character_name(slot), VSDeploymentState.MAX_BOUND_CARDS])


## === 伤害路由 ====================================================================

func _dmg_random(d: Dictionary, dm: int, mul: float) -> void:
	var al := _find_e()
	if al.is_empty(): return
	var t: int = al[randi() % al.size()]
	_ea.take_damage(t, dm)
	var act: String = "造成伤害"
	if mul != 1.0:
		act = "造成伤害(x%.1f压制)" % mul
	_hud.log_action(d["name"], act, _ea.get_enemy_name(t), dm)
	_check_e()


func _dmg_front(d: Dictionary, dm: int) -> void:
	var fr := _ea.get_front_row_alive()
	if fr.is_empty(): fr = _ea.get_back_row_alive()
	if fr.is_empty(): return
	var t: int = fr[randi() % fr.size()]
	_ea.take_damage(t, dm)
	_hud.log_action(d["name"], "前排重击", _ea.get_enemy_name(t), dm)
	_check_e()


func _dmg_all(d: Dictionary, dm: int) -> void:
	for t in _ea.get_all_alive():
		_ea.take_damage(t, dm)
		_hud.log_action(d["name"], "范围灼烧", _ea.get_enemy_name(t), dm)
		if not _ea.is_all_dead():
			await _tree.create_timer(0.15).timeout
	_check_e()


func _find_e() -> Array[int]:
	var al := _ea.get_front_row_alive()
	if al.is_empty(): al = _ea.get_back_row_alive()
	return al


func _check_e() -> void:
	if _ea.is_all_dead():
		enemy_all_dead.emit()


## === 手牌管理 ====================================================================

func _remove(d: Dictionary) -> void:
	var r: int = -1
	for i in range(_hand.size()):
		if _hand[i].get("id") == d.get("id"): r = i; break
	if r >= 0:
		_hand.remove_at(r)
		if r < _hud.hand_container.get_child_count():
			_hud.hand_container.get_child(r).queue_free()
	var kids := _hud.hand_container.get_children()
	for i in range(mini(kids.size(), _hand.size())):
		var w := kids[i] as VSCardWidget
		if w: w.set_can_play(_ps.can_afford(_hand[i].get("cost", 0)))
