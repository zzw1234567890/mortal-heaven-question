extends "res://tests/integration/exploration_ui/one_run_battle_fixture.gd"
## OneRunCombatFixture —— 一周目冒烟里「真的把这一仗打完」那一段的装置。[br]
## [br][b]为什么再拆一层[/b]：[code]one_run_battle_fixture.gd[/code] 装的是「走到
## Boss、发布开战上下文」；「挂战斗场景 → 备战 → 真实出牌打到全灭 → 结算回写」
## 是另一组动作，只有通关方向的两条用例需要，且加起来会把上一层推过 300 行
## （.claude/docs/coding-standards.md）。[br]
## [br][b]走真实链路[/b]：挂真实 [code]combat_scene.tscn[/code]（其 [code]_ready[/code]
## 从跨场景缓存取走探索侧发布的上下文——这一步才是「探索→战斗」的接缝），
## 备战面板确认走生产按钮，出牌走真实鼠标命中测试
## （[code]CombatInputLayer._handle_button[/code]），结算走真实结算屏的返回入口。[br]
## [br][b]战斗系统用独立实例[/b]：同 [code]full_battle_fixture.gd[/code] 口径——
## 被测的是真实 [code]CombatSystem[/code] 代码，但不用 Autoload 单例，避免跨用例
## 串场；场景的三个依赖（卡组 / 布阵 / 转场）都走真实 Autoload 与桩场景管理器。[br]
##
## 来源: design/gdd/combat-system.md §2、exploration-system.md §5、
## ADR-0005、ADR-0014 §决策 3/5、ADR-0031 §2。

## 真实战斗场景（含备战面板 / 战场四区 / 结算宿主）。
const CombatScenePath: String = "res://src/feature/combat/combat_scene.tscn"
## 独立战斗系统实例（真实类，非 Autoload——见文件头）。
const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
## 真实鼠标点击驱动（手牌 / 敌方角色卡的命中测试）。
const ClickDriverScript := preload("res://tests/integration/combat_ui/full_battle_click_driver.gd")
## 结算屏脚本（[code]_on_return_pressed[/code] 是胜利收尾的生产入口）。
const ResultScreenScript := preload("res://src/ui/result_screen/result_screen.gd")

## 胜利结果码（[code]CombatSystem.CombatResult.VICTORY[/code]）。
const RESULT_VICTORY: int = 1
## 伤害牌模板 ID（初始卡组里只有它打得动敌人——其余是护盾/增益/位移）。
const BASIC_ATTACK: StringName = &"basic_attack"
## 单场最多推进的回合数（防挂死）。
const MAX_TURNS: int = 16

var cs: Node = null
var combat_screen: Control = null
var result_screen: Control = null
var battle_events: Array = []

var _combat_host: Control = null
var _clicks: RefCounted = null

## 敌方名册开测前快照（打完必须还原——见 [method after_each]）。
var _enemy_roster_before: Array = []
## 上场角色 ID（打完逐个撤出阵位——见 [method after_each]）。
var _deployed_ids: Array = []
## GSM battle 域开测前快照（打完还原——见 [method after_each]）。
var _battle_domain_before: Dictionary = {}
## 开测时 battle 域是否本就存在（决定还原成快照还是 null）。
var _had_battle_domain: bool = false


func before_each() -> void:
	super()
	_enemy_roster_before = _ai_system_roster()
	_had_battle_domain = gsm != null and gsm.battle is Dictionary
	_battle_domain_before = (gsm.battle as Dictionary).duplicate(true) \
			if _had_battle_domain else {}


## 清理——先释放场景与战斗实例，再还原被这一仗改过的共享单例。[br]
## [br][b]为什么必须还原 AISystem 名册与 DeploymentSystem 阵位[/b]：这两个是
## Autoload，名册里留着「已全灭」的敌人、阵位里留着上场角色，下一条用例
## [code]battle_start[/code] 后会在 END 阶段立刻判出胜负并结束战斗；若那条用例
## 靠「推进回合数」等待（如 [code]test_pause_combat_state_preserved[/code] 的
## [code]_advance_to_turn[/code]），等待条件永不成立——整个套件挂死。
## 清理清单与 [code]full_battle_fixture.gd:195-224[/code] 同口径。
func after_each() -> void:
	# 手牌区刷新走 queue_free——先放一帧，免得 GUT 把退掉的卡节点记成孤儿。
	await get_tree().process_frame
	if _combat_host != null and is_instance_valid(_combat_host):
		_combat_host.free()
	_combat_host = null
	combat_screen = null
	result_screen = null
	if cs != null:
		cs.free()
		cs = null
	_release_shared_state()
	await super()


## 还原战斗这一仗写过的 Autoload / GSM 域。
func _release_shared_state() -> void:
	for cid: Variant in _deployed_ids:
		var ds: Node = get_node_or_null(NodePath("/root/DeploymentSystem"))
		if ds != null:
			ds.call(&"remove_character", int(cid))
	_deployed_ids.clear()
	var cost: Node = get_node_or_null(NodePath("/root/CostSystem"))
	if cost != null:
		cost.call(&"clear_for_battle_end")
	var im: Node = get_node_or_null(NodePath("/root/InputManager"))
	if im != null:
		im.call(&"clear_locks", &"combat_system")
	var ai: Node = get_node_or_null(NodePath("/root/AISystem"))
	if ai != null and ai.has_method(&"set_enemy_roster"):
		ai.call(&"set_enemy_roster", _enemy_roster_before.duplicate(true))
	if gsm != null:
		gsm.battle = _battle_domain_before if _had_battle_domain else null


## AISystem 当前敌方名册（缺该 Autoload 时为空数组）。
func _ai_system_roster() -> Array:
	var ai: Node = get_node_or_null(NodePath("/root/AISystem"))
	if ai == null or not ai.has_method(&"get_enemy_roster"):
		return []
	var raw: Variant = ai.call(&"get_enemy_roster")
	return (raw as Array).duplicate(true) if raw is Array else []


# ═══════════════════════════════════════════════════════════════════════════════
# 挂战斗场景 → 备战
# ═══════════════════════════════════════════════════════════════════════════════

## 挂真实战斗场景并确认出战。[br]
## [br][b]不注入开战上下文[/b]：场景 [code]_ready[/code] 走
## [code]CombatLaunchContext.take()[/code]——取的正是 [method confirm_popup]
## 刚发布的那一份。注入 [code]launch_context_override[/code] 会把这条接缝短路。
func mount_combat_and_deploy() -> void:
	_clicks = ClickDriverScript.new()
	_clicks.call(&"setup", Callable(self, &"_combat_root"))
	cs = CS_SCRIPT.new()
	cs.call(&"set_auto_advance", false)
	cs.call(&"set_scene_change", true)
	cs.call(&"set_scene_manager", mock_sm)
	cs.connect(&"battle_ended", func(result: int, rewards: Dictionary) -> void:
		battle_events.append({"result": result, "rewards": rewards}))
	combat_screen = (load(CombatScenePath) as PackedScene).instantiate() as Control
	combat_screen.set(&"combat_system", cs)
	combat_screen.set(&"deck_system", get_node_or_null(NodePath("/root/DeckEditingSystem")))
	combat_screen.set(&"deployment_system", get_node_or_null(NodePath("/root/DeploymentSystem")))
	combat_screen.set(&"scene_manager", mock_sm)
	combat_screen.set(&"reduce_motion_override", true)
	# 尺寸确定的宿主承载全屏锚点场景（父级给尺寸，避免 _ready 后改 size 的引擎告警）
	_combat_host = Control.new()
	_combat_host.size = Vector2(1280.0, 720.0)
	add_child_autofree(_combat_host)
	_combat_host.add_child(combat_screen)
	assert_eq(str(combat_screen.get(&"launch_failure")), "",
			"前置：探索侧上下文应齐备（否则这一仗打不起来）")
	_confirm_deploy()
	_deployed_ids = _field_character_ids()


## 当前阵位上的角色 ID（供战后撤出——阵位是共享 Autoload，不清会串到下一条用例）。
func _field_character_ids() -> Array:
	var ds: Node = get_node_or_null(NodePath("/root/DeploymentSystem"))
	if ds == null:
		return []
	var out: Array = []
	for entry: Variant in ds.call(&"get_field"):
		if entry is Dictionary:
			var cid: int = int((entry as Dictionary).get("character_id", -1))
			if cid >= 0:
				out.append(cid)
	return out


## 备战面板确认——走真实按钮（预选已由开战上下文下发）。
func _confirm_deploy() -> void:
	var deploy: Variant = _combat_root().get(&"deploy_panel")
	assert_not_null(deploy, "前置：备战面板应已挂载")
	var button: Button = deploy.get(&"confirm_button") as Button
	assert_false(button.disabled, "前置：出战场容已预选满，确认按钮可用")
	button.emit_signal(&"pressed")
	assert_true(bool(cs.call(&"is_battle_active")), "确认出战应真的开战")


# ═══════════════════════════════════════════════════════════════════════════════
# 打到全灭
# ═══════════════════════════════════════════════════════════════════════════════

## 打完这一场（真实点击出牌 + 结束出牌 + 回合循环），返回进行的回合数。
func run_battle_to_end() -> int:
	var turns: int = 0
	while bool(cs.call(&"is_battle_active")) and turns < MAX_TURNS:
		if not _drive_to_play():
			break
		if turns > 0:
			_play_all_attacks()
		_end_turn()
		turns += 1
	return turns


## 战斗是否以胜利收场（真实 [code]battle_ended[/code] 载荷）。
func battle_won() -> bool:
	return not battle_events.is_empty() \
			and int((battle_events[0] as Dictionary).get("result", 0)) == RESULT_VICTORY


## 把胜利带回探索侧——挂真实结算屏并走「返回探索」按钮（生产收尾入口）。[br]
## [br][b]为什么经结算屏而不是直接调 [code]end_exploration[/code][/b]：Boss 战的
## 本图通关结算挂在结算屏的返回路径上（[code]placeholder_scene.gd:160-172[/code]）；
## 绕过它等于绕过被测的那一跳。
func return_to_exploration() -> void:
	assert_not_null(ViewScript.last(), "前置：战斗结束应发布结算对象（结算屏据此夺定胜负）")
	result_screen = ResultScreenScript.new()
	result_screen.set(&"screen_id", 8)  # SceneID.RESULT_SCREEN
	result_screen.set(&"scene_manager", mock_sm)
	add_child_autofree(result_screen)
	result_screen.call(&"_on_return_pressed")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部（战斗推进）
# ═══════════════════════════════════════════════════════════════════════════════

func _combat_root() -> Variant:
	return combat_screen.get(&"combat_root")


## 推进到玩家出牌阶段（阶段 2）；战斗中途结束则返回 false。
func _drive_to_play() -> bool:
	for _i: int in range(10):
		if not bool(cs.call(&"is_battle_active")):
			return false
		if int(cs.call(&"get_current_phase")) == 2:
			return true
		_advance_with_confirm()
	return int(cs.call(&"get_current_phase")) == 2


## 打出全部可打的伤害牌（点手牌 → 点敌人，真实命中测试）。
func _play_all_attacks() -> void:
	for _guard: int in range(40):
		if not bool(cs.call(&"is_battle_active")) \
				or int(cs.call(&"get_current_phase")) != 2:
			return
		var index: int = _first_damage_card_index()
		var enemy_id: int = _first_alive_enemy()
		if index < 0 or enemy_id < 0:
			return
		var hand_before: int = int(cs.call(&"get_hand").size())
		_clicks.call(&"click", _clicks.call(&"hand_card_pos", index))
		_clicks.call(&"click", _clicks.call(&"enemy_card_pos", enemy_id))
		if int(cs.call(&"get_hand").size()) >= hand_before:
			return  # 没打出去——再点也是同一张


## 结束玩家回合并把回合推进到下一轮出牌（或战斗结束）。
func _end_turn() -> void:
	if int(cs.call(&"get_current_phase")) == 2:
		_press_end_turn()
	if int(cs.call(&"get_current_phase")) == 3:
		cs.call(&"confirm_attack_targets")
	for _i: int in range(16):
		if not bool(cs.call(&"is_battle_active")):
			return
		if int(cs.call(&"get_current_phase")) == 2:
			return
		_advance_with_confirm()


## 「结束出牌」按钮（生产节点）。
func _press_end_turn() -> void:
	var bar: Variant = _combat_root().get(&"combat_bottombar")
	var end_turn: Variant = bar.get(&"end_turn_button")
	(end_turn.get(&"button") as Button).emit_signal(&"pressed")


## 推进一步；条件阶段被拒时补上玩家确认标志（与既有回合夹具同口径）。
func _advance_with_confirm() -> void:
	if not bool(cs.call(&"advance_phase")):
		cs.set(&"_player_confirmed_end", true)
		cs.set(&"_player_confirmed_attack_skip", true)
		cs.call(&"advance_phase")


## 手牌里第一张基础攻击的索引（伤害牌——其余是护盾/增益，打不出伤害）。
func _first_damage_card_index() -> int:
	var raw: Variant = _combat_root().call(&"interaction").call(&"hand_snapshot")
	var snapshot: Array = raw if raw is Array else []
	for i: int in range(snapshot.size()):
		var cid: int = int((snapshot[i] as Dictionary).get("card_instance_id", -1))
		var template: Variant = CardSystem.call(&"get_template_by_instance_id", cid)
		if template != null and StringName(str(template.get(&"card_id"))) == BASIC_ATTACK:
			return i
	return -1


## 首个存活敌方 ID（交互层候选池——与命中测试同源）。
func _first_alive_enemy() -> int:
	for entry: Variant in _combat_root().call(&"interaction").call(&"enemy_candidates"):
		if entry is Dictionary and bool((entry as Dictionary).get(&"is_alive", false)):
			return int((entry as Dictionary).get(&"character_id", -1))
	return -1
