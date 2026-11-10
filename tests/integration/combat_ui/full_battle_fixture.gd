extends GutTest
## FullBattleFixture —— 「一场完整战斗」端到端夹具（2026-11-10 验收）。[br]
## [br][b]覆盖路径[/b]：真实 [code]combat_scene.tscn[/code] → 备战面板确认 → 开战
## → 鼠标点击出牌（[code]CombatInputLayer._handle_button[/code] 命中测试）→
## 「结束出牌」按钮 → 敌方行动 → 回合循环 → 全灭 → [code]battle_ended[/code]
## → 结算场景。[br]
## [br][b]测试策略[/b]：独立 [code]CS_SCRIPT.new()[/code] 实例（不污染 Autoload），
## 但场景依赖的真实 Autoload（CardSystem / DeckEditingSystem / DeploymentSystem /
## AISystem / CostSystem）照常使用；GSM 的 player/deck/collection 在 setup 时快照、
## teardown 时还原。[br]
## [br][b]为什么不用桩战斗系统[/b]：要验证的正是「真实系统 + 真实场景」接缝。
## 用法：子类 [code]before_each[/code] 调 [method setup]、[code]after_each[/code] 调 [method teardown]。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const CombatScenePath: String = "res://src/feature/combat/combat_scene.tscn"
const EncounterScript := preload("res://assets/enemies/enemy_encounter.gd")
const ViewScript := preload("res://src/feature/combat/combat_result_view.gd")
const RESULT_SCREEN: String = "res://src/ui/result_screen/result_screen.tscn"
const DEFEAT_SCREEN: String = "res://src/ui/defeat_screen/defeat_screen.tscn"
const ClickDriverScript := preload("res://tests/integration/combat_ui/full_battle_click_driver.gd")
const SeedScript := preload("res://tests/integration/combat_ui/full_battle_seed.gd")

## 测试卡组：6 张基础攻击（0 费，ATK×100%）+ 1 张 1 费非伤害卡（留在手里
## 保证手牌非空——否则空手牌会自动推进出牌阶段，结束出牌按钮就没有机会被验证）。
const BASIC_ATTACK: StringName = &"basic_attack"
const HOLD_CARD: StringName = &"jian_yi_hu_dun"
const BASIC_COUNT: int = 6
const CHAR_TEMPLATES: Array[StringName] = [&"lin_yuan", &"su_jian_ming"]


var cs: Node = null
var scene: Control = null
var _host: Control = null
var sm: Variant = null
var char_ids: Array = []
var battle_events: Array = []
var enemy_actions: Array = []
var _player_before: Dictionary = {}
var _deck_before: Dictionary = {}
var _collection_before: Dictionary = {}
var _roster_before: Array = []
var _clicks: RefCounted = null


## 开战前置——卡组 / 角色 / 场景装配。测试体自行 [code]confirm_deploy()[/code]。
func setup(p_defeat: bool = false) -> void:
	ViewScript.clear()
	_clicks = ClickDriverScript.new()
	_clicks.call("setup", Callable(self, "_root"))
	_snapshot_gsm()
	_seed_deck_and_characters()
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", true)
	cs.set("resolve_cb", Callable(func(_card, _targets) -> Array: return []))
	sm = ClickDriverScript.SceneManagerStub.new()
	add_child(sm)
	cs.call("set_scene_manager", sm)
	battle_events = []
	enemy_actions = []
	cs.connect("battle_ended", func(result: int, rewards: Dictionary) -> void:
		battle_events.append({"result": result, "rewards": rewards}))
	cs.connect("enemy_action_resolved", func(payload: Dictionary) -> void:
		enemy_actions.append(payload))
	_mount_scene(p_defeat)


## 确认出战——走备战面板的真实选择与按钮路径（不直接调 battle_start）。
func confirm_deploy() -> void:
	var deploy: Variant = _root().get("deploy_panel")
	assert_eq(int(deploy.call("get_cards").size()), char_ids.size(),
			"前置：备战面板应读到 %d 名角色的名册" % char_ids.size())
	for cid: int in char_ids:
		assert_true(bool(deploy.call("toggle_selection", cid)), "点选角色 %d" % cid)
	var button: Button = deploy.get("confirm_button") as Button
	assert_false(button.disabled, "前置：已选满且名额足够，确认按钮应可用")
	button.emit_signal("pressed")
	assert_true(bool(cs.call("is_battle_active")), "确认出战应真的开战")


## 推进到玩家出牌阶段（阶段 2）；战斗中途结束则返回 false。
func drive_to_play() -> bool:
	for _i: int in range(10):
		if not bool(cs.call("is_battle_active")):
			return false
		if int(cs.call("get_current_phase")) == 2:
			return true
		_advance_with_confirm()
	return int(cs.call("get_current_phase")) == 2


## 用真实点击路径连续打出手牌里的基础攻击；返回成功打出的张数。
func play_basic_attacks() -> int:
	var played: int = 0
	for _guard: int in range(40):
		if not bool(cs.call("is_battle_active")):
			break
		if int(cs.call("get_current_phase")) != 2:
			break
		var index: int = _first_basic_index()
		var enemy_id: int = _first_alive_enemy()
		if index < 0 or enemy_id < 0:
			break
		var hand_before: int = int(cs.call("get_hand").size())
		_clicks.call("click", _clicks.call("hand_card_pos", index))
		_clicks.call("click", _clicks.call("enemy_card_pos", enemy_id))
		if int(cs.call("get_hand").size()) >= hand_before:
			break  # 未打出去——避免无限循环
		played += 1
	return played


## 结束当前玩家回合：阶段 2 点「结束出牌」按钮 → 确认攻击声明 → 推进到
## 下一回合的出牌阶段或战斗结束。
func finish_turn() -> void:
	if int(cs.call("get_current_phase")) == 2:
		assert_true(press_end_turn_button(), "结束出牌按钮应把阶段 2 推进到 3")
	if int(cs.call("get_current_phase")) == 3:
		cs.call("confirm_attack_targets")
	for _i: int in range(16):
		if not bool(cs.call("is_battle_active")):
			return
		if int(cs.call("get_current_phase")) == 2:
			return
		_advance_with_confirm()


## 跑完整场：第 1 回合先点「结束出牌」证明按钮可用，其后每回合打出全部基础攻击。
## 返回实际进行的回合数（上限防挂死）。[br]
## [br][b]第 1 回合不先出牌[/b]：按钮验证不依赖手牌内容；也顺带覆盖「玩家整回合
## 不出牌直接结束」的路径。
func run_full_battle(p_max_turns: int = 12) -> int:
	var turns: int = 0
	while bool(cs.call("is_battle_active")) and turns < p_max_turns:
		if not drive_to_play():
			break
		if turns > 0:
			play_basic_attacks()
		finish_turn()
		turns += 1
	return turns


## 「结束出牌」按钮（生产节点）——返回按下后是否进入攻击声明阶段。
func press_end_turn_button() -> bool:
	var bar: Variant = _root().get("combat_bottombar")
	var end_turn: Variant = bar.get("end_turn_button")
	var button: Button = end_turn.get("button") as Button
	button.emit_signal("pressed")
	return int(cs.call("get_current_phase")) == 3


## 读取 [signal CombatSystem.battle_ended] 的战绩（无事件返回空字典）。
func battle_record() -> Dictionary:
	if battle_events.is_empty():
		return {}
	var rewards: Dictionary = battle_events[0].get("rewards", {})
	var record: Variant = rewards.get("record", {})
	return record if record is Dictionary else {}


## 我方当前 HP 总和（战斗结束前调用——结束后状态表已清空）。
func player_hp_total() -> int:
	var total: int = 0
	for cid: int in char_ids:
		total += int(cs.call("get_character_hp", cid).get("current", 0))
	return total


## 挂载结算/战败场景（消费 CombatResultView 的真实场景）。
func mount_result_screen(p_path: String) -> Control:
	var packed: PackedScene = load(p_path)
	var screen: Control = packed.instantiate() as Control
	add_child_autofree(screen)
	return screen


## 清理——先释放场景（断开信号），再释放战斗实例，最后还原 GSV 三域 + 阵位。
func teardown() -> void:
	# 手牌区每次刷新会用 queue_free 退掉旧卡节点——先放一帧让它们真正释放，
	# 再进行场景销毁与断言清理（否则 GUT 会把它们记成孤儿）。
	await get_tree().process_frame
	if scene != null and is_instance_valid(scene):
		scene.free()
		scene = null
	if _host != null and is_instance_valid(_host):
		_host.free()
		_host = null
	if sm != null and is_instance_valid(sm):
		sm.free()
		sm = null
	if cs != null:
		cs.free()
		cs = null
	for cid: int in char_ids:
		DeploymentSystem.remove_character(cid)
	char_ids.clear()
	CostSystem.clear_for_battle_end()
	InputManager.clear_locks(&"combat_system")
	AISystem.set_enemy_roster(_roster_before)
	GameStateManager.player = _player_before
	GameStateManager.deck = _deck_before
	GameStateManager.collection = _collection_before
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	ViewScript.clear()


# === 内部 =====================================================================

func _root() -> Variant:
	return scene.get("combat_root")


## 场景挂载——注入独立战斗系统 + 真实卡组/阵位/费用数据源。
func _mount_scene(p_defeat: bool) -> void:
	scene = (load(CombatScenePath) as PackedScene).instantiate() as Control
	scene.set("combat_system", cs)
	scene.set("deck_system", _autoload(&"DeckEditingSystem"))
	scene.set("deployment_system", _autoload(&"DeploymentSystem"))
	scene.set("scene_manager", sm)
	scene.set("reduce_motion_override", true)
	if p_defeat:
		var encounter: Resource = EncounterScript.new()
		encounter.set("encounter_id", &"test_mo_xiu")
		var ids: Array[StringName] = [&"mo_xiu"]
		encounter.set("enemy_template_ids", ids)
		scene.set("encounter", encounter)
	# 用尺寸确定的宿主 Control 承载全屏锚点的战斗场景——由父级给尺寸，
	# 避免「_ready 后直接改 size」触发引擎覆写告警。
	_host = Control.new()
	_host.size = Vector2(1280.0, 720.0)
	add_child(_host)
	_host.add_child(scene)


## 卡组与角色种子（真实 CardSystem 实例 + GSM 收藏/卡组/角色位）。
func _seed_deck_and_characters() -> void:
	assert_true(SeedScript.ensure_templates(), "前置：卡牌模板应已加载")
	GameStateManager.player = (GameStateManager.player as Dictionary).duplicate(true)
	GameStateManager.player["realm"] = 1
	GameStateManager.player["character_hp"] = {}
	var seeded: Dictionary = SeedScript.seed(CHAR_TEMPLATES, BASIC_COUNT,
			BASIC_ATTACK, HOLD_CARD)
	char_ids = seeded.get("char_ids", [])
	for cid: int in char_ids:
		assert_gt(cid, 0, "前置：角色卡实例应创建成功")


func _snapshot_gsm() -> void:
	_player_before = (GameStateManager.player as Dictionary).duplicate(true)
	_deck_before = (GameStateManager.deck as Dictionary).duplicate(true)
	_collection_before = (GameStateManager.collection as Dictionary).duplicate(true)
	_roster_before = AISystem.get_enemy_roster().duplicate()


## 推进一步；条件阶段被拒时补上玩家确认标志（与既有回合夹具同口径）。
func _advance_with_confirm() -> void:
	if not bool(cs.call("advance_phase")):
		cs.set("_player_confirmed_end", true)
		cs.set("_player_confirmed_attack_skip", true)
		cs.call("advance_phase")


## 手牌中第一张基础攻击的索引（顺序与手牌区一致）。
func _first_basic_index() -> int:
	var raw: Variant = _root().call("interaction").call("hand_snapshot")
	var snapshot: Array = raw if raw is Array else []
	for i: int in range(snapshot.size()):
		var cid: int = int((snapshot[i] as Dictionary).get("card_instance_id", -1))
		var template: Variant = CardSystem.call("get_template_by_instance_id", cid)
		if template != null and StringName(str(template.get("card_id"))) == BASIC_ATTACK:
			return i
	return -1


## 手牌快照第 [param p_index] 项的卡实例 ID（手牌区顺序与快照一致）。
func _hand_card_id_at(p_index: int) -> int:
	var raw: Variant = _root().call("interaction").call("hand_snapshot")
	if not (raw is Array) or p_index < 0 or p_index >= (raw as Array).size():
		return -1
	return int((raw as Array)[p_index].get("card_instance_id", -1))


## 首个存活敌方 ID（交互层候选池——与命中测试同源）。
func _first_alive_enemy() -> int:
	for entry: Variant in _root().call("interaction").call("enemy_candidates"):
		if entry is Dictionary and bool((entry as Dictionary).get("is_alive", false)):
			return int((entry as Dictionary).get("character_id", -1))
	return -1


func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))
