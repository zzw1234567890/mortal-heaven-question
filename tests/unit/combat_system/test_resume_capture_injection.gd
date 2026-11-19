extends GutTest
## 续战快照[b]取数注入面[/b]的验收（[code]combat_resume_capture[/code] 的
## [code]combat[/code] / [code]cost[/code] 两个句柄）。[br]
## [br][b]补的断链[/b]：抓取侧从「战斗系统 + 费用系统」现读阶段 / 回合 / 当前费 / 上限，
## 但此前只有端到端那条用例覆盖过它——而端到端的数由真实系统自己给，注入句柄那条
## [b]分支一行都没跑过[/b]。注入面是测试与「换掉其中一个来源」的唯一入口
## （类文档「为 null 时回退 Autoload」），它坏了症状很隐蔽：读档回来费用是满的、
## 回合是第 1 回合，而所有端到端用例仍然全绿。[br]
## [br][b]为什么要「注入非出厂值」[/b]：拿出厂值（回合 1 / 费用满）去验，回退路径与
## 正确路径给出同一个数——断言证明不了注入真的生效。这里注入的四个数（回合 7 ·
## 阶段 4 · 当前费 1 · 上限 5）两两不同，且都与出厂值不同。[br]
## [br][b]覆盖[/b]：[br]
##   1. 注入的回合 / 阶段 / 当前费 / 上限逐项落进快照；[br]
##   2. 快照读回来喂给 [code]restore_battle_state[/code]，[code]CostSystem[/code]
##      真的收到同一对费用值（写侧注入 → 读侧落地的整个闭环）；[br]
##   3. 注入句柄缺席时回退 Autoload（不静默取 0——那会让费用变成 0 费）。[br]
## [br]本文件独占角色 ID 段 8881+。[br]
## [br]来源: ADR-0002 §存档容器、ADR-0008 §GSM 边界、本轮「续战快照的取数注入面」。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const CaptureScript := preload("res://src/feature/combat/combat_resume_capture.gd")
const PayloadScript := preload("res://src/feature/combat/battle_resume_payload.gd")
const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")

const CHAR_A: int = 8881
const NODE_ID: int = 782
## 注入值——四个都与出厂值（回合 1 / 阶段 0 / 费 0）不同，且两两不同。
const INJECT_TURN: int = 7
const INJECT_PHASE: int = 4
const INJECT_COST: int = 1
const INJECT_MAX_COST: int = 5


## 战斗系统替身——提供抓取侧要读的各路取数。[br]
## [br][b]为什么名册那几块要一起给[/b]：载荷的完整性判据要求敌我名册都非空
## （[method PayloadScript.is_resumable_payload]），缺了就抓不出快照——那时本文件
## 验的就不是费用注入面，而是「名册为空不给写」那条守卫。[br]
## [br][b]为什么复用既有替身[/b]：本文件要验的是「注入的这个句柄有没有被读到」，
## 替身只要如实报数即可；换一套记账型替身会把断言对象换成记账动作。
class CombatProbe:
	extends Node

	var phase: int = INJECT_PHASE
	var turn: int = INJECT_TURN

	func is_battle_active() -> bool:
		return true

	func get_current_phase() -> int:
		return phase

	func get_turn_number() -> int:
		return turn

	## 本场敌方名册（一条即可——内容与本文件验的费用/进度无关）。
	func get_battle_enemy_roster() -> Array:
		return [{"template_id": "san_xiu", "current_hp": 6, "max_hp": 16,
			"field_position": 0, "is_alive": true}]

	## 本场开战配置（载荷按白名单折叠——名单里有模板 ID 即可）。
	func get_battle_config() -> Dictionary:
		return {"character_ids": [CHAR_A], "enemy_template_ids": [&"san_xiu"],
			"enemy_level": 2, "rewards": {}}

	## 状态表（我方 HP 的取数来源）——只有一名角色。
	func get_roster_state() -> RefCounted:
		return RosterProbe.new()


## 布阵替身——本文件不验阵位，但没有阵位快照时载荷判为残缺（[code]payload_reason[/code]
## 返回「战斗记录不完整」），抓取会走守卫分支而不写快照。[br]
## [br][b]为什么注入而不是真布阵[/b]：阵位块是被测费用面的邻居，注入一个固定的一人阵位
## 让本文件的断言只盯着费用/进度那四个数。
class DeploymentProbe:
	extends Node

	func get_field() -> Array:
		return [{"slot_index": 0, "character_id": CHAR_A, "is_front": true,
			"state": 1, "deploy_turn": 1}]


## 状态表替身——我方 HP 表 + 空 debuff 管理器。
class RosterProbe:
	extends RefCounted

	func snapshot_all() -> Array:
		return [{"character_id": CHAR_A, "side": 0, "current_hp": 9, "max_hp": 12,
			"is_alive": true}]

	func get_debuff_manager() -> Variant:
		return null


## 费用系统替身——如实报出注入的两个费用值。
class CostProbe:
	extends Node

	var current: int = INJECT_COST
	var max_cost: int = INJECT_MAX_COST

	func get_current_cost() -> int:
		return current

	func get_max_cost() -> int:
		return max_cost


## GSM 替身——只记续战段的写入。
class GsmProbe:
	extends Node

	var battle_resume: Dictionary = {}

	func _set_battle_resume(resume: Dictionary) -> void:
		gsm_writes += 1
		battle_resume = resume.duplicate(true)

	var gsm_writes: int = 0


var combat: CombatProbe = null
var deployment: DeploymentProbe = null
var cost: CostProbe = null
var gsm: GsmProbe = null
var cs: Node = null


func before_each() -> void:
	ContextScript.clear()
	CostSystem.clear_for_battle_end()
	DeploymentSystem._reset_field()
	combat = CombatProbe.new()
	deployment = DeploymentProbe.new()
	cost = CostProbe.new()
	gsm = GsmProbe.new()
	add_child_autofree(combat)
	add_child_autofree(deployment)
	add_child_autofree(cost)
	add_child_autofree(gsm)
	ContextScript.publish({
		ContextScript.KEY_NODE_ID: NODE_ID,
		ContextScript.KEY_COMBAT_TYPE: "boss",
		ContextScript.KEY_TEMPLATE_IDS: [&"san_xiu"],
		ContextScript.KEY_ENEMY_LEVEL: 2,
		ContextScript.KEY_REWARDS: {},
		ContextScript.KEY_PLAYER_ROSTER: [CHAR_A],
	})


func after_each() -> void:
	ContextScript.clear()
	CostSystem.clear_for_battle_end()
	DeploymentSystem._reset_field()
	InputManager.clear_locks(&"combat_system")
	if cs != null:
		cs.free()
		cs = null


## 抓一次快照（注入四个句柄——[code]deployment[/code] 也注入，让本文件的断言只盯着
## 费用/进度那四个数）。
func capture() -> Dictionary:
	var capture_ref: RefCounted = CaptureScript.new()
	capture_ref.combat = combat
	capture_ref.deployment = deployment
	capture_ref.cost = cost
	capture_ref.gsm = gsm
	var outcome: Dictionary = capture_ref.call(&"capture", 4)
	assert_true(bool(outcome.get("written", false)),
			"前置：抓快照应成功（原因：%s）" % outcome.get("reason", ""))
	return gsm.battle_resume


## 一场真实战斗——读侧的落地对象（[method restore_battle_state] 要落在活跃战斗上）。
func start_real_battle() -> Node:
	DeploymentSystem.setup_field([CHAR_A], {CHAR_A: true})
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	add_child_autofree(cs)
	cs.call("battle_start", {
		"character_ids": [CHAR_A],
		"enemy_roster": AISystem.create_enemy_roster([&"san_xiu"], 1, 2),
		"enemy_template_ids": [&"san_xiu"],
		"enemy_level": 2,
		"rewards": {},
		"player_stats": {CHAR_A: {"current_hp": 12, "max_hp": 12}},
	})
	return cs


# ═══════════════════════════════════════════════════════════════════════════════
# 写侧：注入的值真的进了快照
# ═══════════════════════════════════════════════════════════════════════════════

func test_injected_progress_lands_in_snapshot_verbatim() -> void:
	# Act
	var payload: Dictionary = capture()
	# Assert——四项逐项等于注入值
	assert_eq(int(payload[PayloadScript.KEY_TURN]), INJECT_TURN,
			"回合应取注入句柄的值（回退到出厂值 1 会让这条红）")
	assert_eq(int(payload[PayloadScript.KEY_PHASE]), INJECT_PHASE,
			"阶段应取注入句柄的值")
	assert_eq(int(payload[PayloadScript.KEY_CURRENT_COST]), INJECT_COST,
			"当前费用应取注入的费用系统（回退到真实 Autoload 会拿到别的数）")
	assert_eq(int(payload[PayloadScript.KEY_MAX_COST]), INJECT_MAX_COST,
			"费用上限同上")
	# Assert——四个数两两不同（否则「取对了」与「取错了」可能撞出同一个值）
	assert_ne(INJECT_TURN, INJECT_PHASE, "前置：注入的四个数两两不同")
	assert_ne(INJECT_COST, INJECT_MAX_COST, "前置：当前费与上限不同")


## 换一组注入值，快照跟着变——证明它读的是句柄而不是身边某个常量。[br]
## [br][b]为什么要第二条[/b]：第一条只证明「这四个数进了快照」，一条写死的实现
## （把常数直接塞进载荷）同样能过；换一组值再走一遍才排得掉那种可能。
func test_snapshot_follows_injected_values_not_constants() -> void:
	# Arrange——换成另一组（同样非出厂值）
	combat.turn = 12
	combat.phase = 2
	cost.current = 0
	cost.max_cost = 6
	# Act
	var payload: Dictionary = capture()
	# Assert
	assert_eq(int(payload[PayloadScript.KEY_TURN]), 12, "回合应跟着注入值走")
	assert_eq(int(payload[PayloadScript.KEY_PHASE]), 2, "阶段应跟着注入值走")
	assert_eq(int(payload[PayloadScript.KEY_CURRENT_COST]), 0, "当前费用应跟着注入值走")
	assert_eq(int(payload[PayloadScript.KEY_MAX_COST]), 6, "费用上限应跟着注入值走")


# ═══════════════════════════════════════════════════════════════════════════════
# 读侧：同一对费用值真的落到 CostSystem
# ═══════════════════════════════════════════════════════════════════════════════

## 写侧注入 → 快照 → 读侧落地：整个闭环里费用与回合是同一对数。[br]
## [br][b]断言的是 [code]CostSystem[/code] 自己报出来的值[/b]，不是「调用发生过」——
## 调用发生了但传错参数的实现一样能让记账型断言变绿。
func test_restore_feeds_same_cost_into_cost_system() -> void:
	# Arrange——写侧注入并抓快照
	var payload: Dictionary = capture()
	# 清掉写侧注入的费用替身留下的痕迹（读侧要用真实 CostSystem）
	CostSystem.clear_for_battle_end()
	# Act——读侧按续战顺序重建：开战 → 落位（顺序见 combat_scene_resume.gd）
	start_real_battle()
	# 开战会把费用拉满（上限由境界给），先确认它不是注入值——否则下面的断言证明不了落位
	assert_ne(CostSystem.get_max_cost(), INJECT_MAX_COST,
			"前置：开战刚拉满的费用上限不等于注入值（练气期上限是 2）")
	assert_true(bool(cs.call("restore_battle_state",
			int(payload[PayloadScript.KEY_TURN]),
			int(payload[PayloadScript.KEY_PHASE]),
			int(payload[PayloadScript.KEY_CURRENT_COST]),
			int(payload[PayloadScript.KEY_MAX_COST]))), "前置：落位成功")
	# Assert——CostSystem 收到的是快照里那一对
	assert_eq(CostSystem.get_current_cost(), INJECT_COST,
			"CostSystem 的当前费用应等于快照值（写侧注入的数一路传到这里）")
	assert_eq(CostSystem.get_max_cost(), INJECT_MAX_COST,
			"CostSystem 的费用上限应等于快照值")
	# Assert——回合也一并落到战斗系统（同一批落位参数）
	assert_eq(int(cs.call("get_turn_number")), INJECT_TURN, "回合应落到战斗系统")
	assert_eq(int(cs.call("get_current_phase")), INJECT_PHASE, "阶段应落到战斗系统")
