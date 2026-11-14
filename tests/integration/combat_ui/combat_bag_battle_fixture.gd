extends GutTest
## CombatBagBattleFixture —— 战斗内行囊的[b]集成[/b]装置（真实战斗系统 + 真实存档）。[br]
## [br][b]为什么必须有一份真跑的装置[/b]：单元装置证明的是「各半边算得对」，
## 而本轮有四件事只有真跑一场战斗才看得见——[br]
##   1. 面板真的挂在战场根上、入口按钮真的接上了（装配点漏接只会静默降级）；[br]
##   2. 打开行囊真的把出牌输入层关掉了（冻结走的是交互层的普通字段）；[br]
##   3. 用药扣的灵力与出牌扣的是同一本账（[code]CostSystem[/code] 单例）；[br]
##   4. 用完之后回合还能照常推进（「只花灵力、不推进回合」那条口径）。[br]
## [br][b]战斗系统用独立实例[/b]（[code]CS_SCRIPT.new()[/code]，不污染 Autoload），
## 其余依赖（存档 / 卡牌 / 费用 / 阵位 / AI）照常使用真实 Autoload；GSM 的
## [code]player[/code] / [code]deck[/code] / [code]collection[/code] 三域在
## [method setup] 快照、[method teardown] 还原（GSM 是全进程单例）。[br]
## [br][b]原名不符 [code]test_[/code] 前缀[/b]：GUT 不把它当用例收集，只作基类
## （先例 [code]full_battle_fixture.gd[/code]）。
##
## 来源: 本轮任务书第 1-4 条、先例
## [code]tests/integration/combat_ui/full_battle_fixture.gd[/code]（真实场景 + 真实 Autoload）。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const CombatRootScene: PackedScene = preload("res://src/ui/combat/layout/CombatRoot.tscn")
const BagScript := preload("res://src/feature/combat/combat_scene_bag.gd")
const InteractionScript := preload("res://src/feature/combat/combat_scene_interaction.gd")
const SeedScript := preload("res://tests/integration/combat_ui/full_battle_seed.gd")
const PrimerScript := preload("res://tests/integration/exploration_ui/card_template_primer.gd")

## 上场角色的模板（炼气期角色卡，生命 10）。
const CHAR_TEMPLATE: StringName = &"lin_yuan"
## 本轮点名的两枚实物：回春丹（治疗 4，单体）/ 基础法器（攻击 +3）。
const PILL_HEAL: StringName = &"pill_hui_chun_dan"
const ARTIFACT_BUFF: StringName = &"artifact_ji_chu_fa_qi"

## 上场角色的血量（留出 5 点缺口，用药才有意义）。
const CHAR_HP: int = 5
const CHAR_MAX_HP: int = 10
## 敌方 ID（不与其它测试文件撞车）。
const ENEMY_ID: int = 8620


var cs: Node = null
var layout: Control = null
var bag: RefCounted = null
var interaction: RefCounted = null
var char_id: int = -1

var _host: Control = null
var _player_before: Dictionary = {}
var _deck_before: Dictionary = {}
var _collection_before: Dictionary = {}
var _roster_before: Array = []


## 前置——种子数据 → 开战 → 装配（行囊最后挂，与其他各组同一次接线）。[br]
## [br][param p_with_pill] 是否往收藏里放一枚回春丹（空行囊的用例传 false）。[br]
## [br][param p_with_artifact] 是否放一件基础法器。
func setup(p_with_pill: bool = true, p_with_artifact: bool = false) -> void:
	_snapshot_gsm()
	assert_true(SeedScript.ensure_templates(), "前置：卡牌模板应已加载")
	assert_true(PrimerScript.prime(CardSystem, PILL_HEAL), "前置：回春丹模板应就位")
	char_id = SeedScript.make_card(CHAR_TEMPLATE)
	if p_with_pill:
		SeedScript.make_card(PILL_HEAL)
	if p_with_artifact:
		SeedScript.make_card(ARTIFACT_BUFF)
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	cs.set("resolve_cb", Callable(func(_card: Variant, _targets: Array) -> Array:
		return []))
	_start_battle()
	_mount_layout()
	_advance_to_play()


## 收尾——先退订接线（信号源含常驻 Autoload），再释放场景与战斗实例，
## 最后还原存档三域与阵位。
## [br][b]为什么必须先退订[/b]：[code]CostSystem[/code] 是常驻 Autoload，
## 它的 [signal CostSystem.cost_changed] 会在下一场战斗的 [code]init_for_battle[/code]
## 时发射；留着上一轮的接收者就会让旧场景句柄（已 free）被回调到——
## 表现为「别的用例里报 Cannot call method 'get' on a previously freed instance」。
func teardown() -> void:
	await get_tree().process_frame
	if bag != null:
		bag.call(&"unbind")
		bag = null
	if interaction != null:
		interaction.call(&"unbind")
		interaction = null
	if _host != null and is_instance_valid(_host):
		_host.free()
		_host = null
	layout = null
	if cs != null:
		cs.free()
		cs = null
	if char_id > 0:
		DeploymentSystem.remove_character(char_id)
		char_id = -1
	CostSystem.clear_for_battle_end()
	InputManager.clear_locks(&"combat_system")
	AISystem.set_enemy_roster(_roster_before)
	GameStateManager.player = _player_before
	GameStateManager.deck = _deck_before
	GameStateManager.collection = _collection_before
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false


# ═══════════════════════════════════════════════════════════════════════════════
# 测试体用得到的动作（全部走真实入口——不直调系统凑结果）
# ═══════════════════════════════════════════════════════════════════════════════

## 点底部条的「行囊」入口按钮（生产路径的唯一开合入口）。
func press_bag_button() -> void:
	var bar: Variant = layout.get(&"combat_bottombar")
	var icon: Variant = bar.get("bag_button")
	(icon.get("button") as Button).emit_signal(&"pressed")


## 行囊面板（场景装配时挂上的那个）。
func panel() -> Control:
	return bag.get("host").get("panel")


## 行囊面板是否开着。
func is_bag_open() -> bool:
	return bool(bag.call(&"is_open"))


## 出牌输入层是否放行（冻结若无实效，玩家仍能隔面板点穿出牌）。
func input_enabled() -> bool:
	var layer: Variant = layout.call(&"interaction").call(&"get_input_layer")
	return layer != null and bool(layer.call(&"is_enabled"))


## 确认面板的第 [param p_index] 行（走面板自己的出口）。
func press_row(p_index: int) -> void:
	panel().call(&"press_row", p_index)


## 某模板当前持有数（存档侧实证——界面少一行只是表象）。
func owned_count(p_template_id: StringName) -> int:
	var count: int = 0
	for raw: Variant in (GameStateManager.collection["owned_cards"] as Array):
		if raw is Dictionary and str((raw as Dictionary).get("template_id", "")) \
				== str(p_template_id):
			count += 1
	return count


## 当前 HP（战斗内唯一真理来源 = 战斗状态表）。
func hp_now() -> int:
	return int(cs.call("get_character_hp", char_id)["current"])


## 把灵力花光（造「灵力不足」的场景——走真实扣费入口）。
func drain_cost() -> void:
	CostSystem.spend(CostSystem.get_current_cost())


## 第一条可用 / 不可用条目的下标（找不到返回 -1）。
func row_index(p_usable: bool) -> int:
	var count: int = int(panel().call(&"entry_count"))
	for index: int in range(count):
		if bool(panel().call(&"is_row_disabled", index)) != p_usable:
			return index
	return -1


## 往收藏里再放一张（用例中途改变持有物时用——走真实卡实例创建）。[br]
## [br][b]为什么不用重新 [method setup][/b]：那会再挂一次场景与战斗系统，
## 上一个实例的句柄全部失联（孤儿节点+信号残留），用例之间开始互相污染。
func give(p_template_id: StringName) -> int:
	assert_true(PrimerScript.prime(CardSystem, p_template_id),
			"前置：%s 模板应就位" % str(p_template_id))
	return SeedScript.make_card(p_template_id)


## 把某模板的实例全部移出收藏（造空行囊用——走真实存档域）。[br]
## [br]不移 [code]deck[/code] 的角色位：本装置的角色卡与丹药是两个模板。
func take_all(p_template_id: StringName) -> void:
	var kept: Array = []
	for raw: Variant in (GameStateManager.collection["owned_cards"] as Array):
		if raw is Dictionary and str((raw as Dictionary).get("template_id", "")) \
				== str(p_template_id):
			continue
		kept.append(raw)
	GameStateManager.collection["owned_cards"] = kept
	GameStateManager.collection["total_count"] = kept.size()


## 当前阶段 / 回合号（「用完之后回合还能推进」的断言素材）。
func phase_now() -> int:
	return int(cs.call("get_current_phase"))


func turn_now() -> int:
	return int(cs.call("get_turn_number"))


## 结束出牌——阶段 2 点「结束出牌」按钮（生产节点），返回是否推进到攻击声明。
func press_end_turn() -> bool:
	var bar: Variant = layout.get(&"combat_bottombar")
	var end_turn: Variant = bar.get("end_turn_button")
	(end_turn.get("button") as Button).emit_signal(&"pressed")
	return int(cs.call("get_current_phase")) == 3


## 推进阶段（条件阶段被拒时补上玩家确认标志——同既有回合夹具口径）。
func advance() -> void:
	if not bool(cs.call("advance_phase")):
		cs.set("_player_confirmed_end", true)
		cs.set("_player_confirmed_attack_skip", true)
		cs.call("advance_phase")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：布置与开战
# ═══════════════════════════════════════════════════════════════════════════════

## 开战（真实 battle_start——状态表种子 / 费用激活 / 阵位读取全走生产路径）。
func _start_battle() -> void:
	assert_true(DeploymentSystem.setup_field([char_id], {}), "前置：角色上场成功")
	cs.call("battle_start", {
		"enemy_roster": [{"character_id": ENEMY_ID, "current_hp": 20, "max_hp": 20,
			"attack": 2, "is_alive": true}],
		"character_ids": [char_id],
		"player_stats": {char_id: {"current_hp": CHAR_HP, "max_hp": CHAR_MAX_HP,
			"atk": 3}},
	})


## 挂载真实战场根并接上表现层接线（出牌交互 → 反馈/建卡 → 行囊）。[br]
## [br][b]行囊最后接[/b]：它的面板要盖住手牌区与出牌输入层，顺序反了面板会被压在下面。
func _mount_layout() -> void:
	layout = CombatRootScene.instantiate() as Control
	layout.size = Vector2(1280.0, 720.0)
	_host = Control.new()
	_host.size = Vector2(1280.0, 720.0)
	add_child(_host)
	_host.add_child(layout)
	# 出牌交互（输入层 + 手牌供给）——行囊要借它的开关冻结出牌
	interaction = InteractionScript.new()
	interaction.call(&"wire", layout, cs, CostSystem, true)
	layout.call(&"setup_feedback", cs, DeploymentSystem,
			Callable(cs, &"get_character_hp"), CardSystem, null, true)
	layout.call(&"build_battle_roster", [char_id])
	# 底部条订阅本场战斗的阶段信号（与生产 [code]wire_panels[/code] 同一处接线）——
	# 入口按钮的显隐由真实 [signal CombatSystem.phase_changed] 驱动，非直调
	# [code]apply_phase[/code] 凑出来。必须赶在 [method _advance_to_play] 之前接上，
	# 否则阶段推进发生在无人订阅的时候，按钮会一直停在初始的隐藏态。
	(layout.get(&"combat_bottombar") as Variant).call(&"bind_signals", cs, CostSystem)
	# 行囊——与生产同一条装配链（条目 → 效果 → 结算 → 面板 + 入口 + 冻结）
	bag = BagScript.new().call(&"wire", layout, cs, interaction,
			GameStateManager, CardSystem, CostSystem)


## 推进到出牌阶段（阶段 2）。
func _advance_to_play() -> void:
	for _i: int in range(10):
		if int(cs.call("get_current_phase")) == 2:
			break
		advance()
	assert_eq(int(cs.call("get_current_phase")), 2, "前置：应已进入出牌阶段")
	# 开战由 CombatSceneInteraction.enable 放行输入（行囊只在自己打开时接管）
	interaction.call(&"set_enabled", true)


func _snapshot_gsm() -> void:
	_player_before = (GameStateManager.player as Dictionary).duplicate(true)
	_deck_before = (GameStateManager.deck as Dictionary).duplicate(true)
	_collection_before = (GameStateManager.collection as Dictionary).duplicate(true)
	_roster_before = AISystem.get_enemy_roster().duplicate()
