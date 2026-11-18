extends GutTest
## CombatSceneResumeFixture —— 读档续战编排用例的共享装置。[br]
## [br][b]为什么单独一处[/b]：用例文件要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「怎么摆一套替身、怎么造一份可续战的存档段」
## 与「断言什么顺序、什么取数口径」是两件事（同 [code]pause_menu_fixture.gd[/code] 先例）。[br]
## [br][b]用法[/b]：子类 [code]extends "res://…/combat_scene_resume_fixture.gd"[/code]，
## 只写 [code]test_*[/code] 方法；[code]before_each[/code] / [code]after_each[/code]
## 由本夹具提供，子类若要扩展需先 [code]super()[/code]。[br]
## [br][b]文件前缀[/b]：本文件不以 [code]test_[/code] 开头——GUT 按前缀收集，它只作为
## 基类被继承，不会被当作用例文件单独执行。[br]
## [br][b]四个替身全部由本夹具提供[/b]（战斗 / 布阵 / AI / 战场根 + 出牌交互）——
## 子类重复声明同名成员在 GDScript 里是解析错误，整个子类文件会被 GUT 静默忽略
## （[code]Ignoring script … because it does not extend GutTest[/code]），用例一条都不跑。[br]
## [br][b]为什么全用替身[/b]：本组用例要验的是「先调谁后调谁、取哪个数」——跑一场真实
## 战斗既拿不到这条流水，还会把编排的错和战斗系统的错混在一起。[br]
## [br]来源: ADR-0008 §GSM 边界、ADR-0017 §EnemyFactory、
## 本轮「战斗中存档 → 读档回到战斗」（B 项）。

## 贡献者：被测模块与它依赖的三个形状模块。
const ResumeSceneScript := preload("res://src/feature/combat/combat_scene_resume.gd")
const IntentScript := preload("res://src/feature/combat/battle_resume_intent.gd")
const PayloadScript := preload("res://src/feature/combat/battle_resume_payload.gd")
const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")

## 用例角色 ID 段（远离其它套件，防串场）。
const CHAR_A: int = 8851
const CHAR_B: int = 8852
## 来源节点 ID（读档回到战斗靠它认路）。
const NODE_ID: int = 775
## 敌人模板（替身表里的键——不读真实 [code]assets/enemies/[/code]）。
const TEMPLATE: String = "san_xiu"
## 落位状态：第 6 回合 · 攻击声明阶段 · 费用 1/4（都不是出厂值——重置与没存都会被抓出来）。
const TURN: int = 6
const PHASE: int = 3
const COST: int = 1
const MAX_COST: int = 4
## 敌方残血（重建出来的替身默认满血 99——覆盖有没有生效一眼可见）。
const ENEMY_HP: int = 6


## 战斗系统替身——记账每一步（顺序断言面）并如实作答。[br]
## [br][b]为什么手写而不是用 mock 库[/b]：本组用例要断言的正是「先调谁后调谁」，
## 记账顺序本身就是被测对象。
class CombatStub:
	extends Node

	## 调用流水（按发生顺序）——顺序断言的唯一证据。
	var calls: Array = []
	var config: Dictionary = {}
	var turn: int = -1
	var phase: int = -1
	var cost: int = -1
	var max_cost: int = -1
	var deck: Array = []
	## 自动推进开关的当前值（[method set_auto_advance] 改写它）。
	var auto_advance: bool = true

	func battle_start(p_config: Dictionary) -> void:
		calls.append("battle_start")
		config = p_config.duplicate(true)

	func set_auto_advance(enabled: bool) -> void:
		calls.append("auto=%s" % enabled)
		auto_advance = enabled

	func restore_battle_state(p_turn: int, p_phase: int, p_current: int,
			p_max: int) -> bool:
		calls.append("restore")
		turn = p_turn
		phase = p_phase
		cost = p_current
		max_cost = p_max
		return true

	func resume_auto_advance() -> void:
		calls.append("resume_auto")

	func init_deck(p_cards: Array) -> void:
		calls.append("init_deck")
		deck = p_cards.duplicate()


## 布阵替身——记账 [method setup_field] 的阵容与 layout。
class DeploymentStub:
	extends Node

	var setups: Array = []
	var accepted: bool = true

	func setup_field(p_ids: Array, p_layout: Dictionary = {}) -> bool:
		setups.append({"ids": p_ids.duplicate(), "layout": p_layout.duplicate(true)})
		return accepted


## AI 替身——模板表可配（键为模板 ID 字符串），记账写回的敌方名册。
class AiStub:
	extends Node

	var templates: Dictionary = {}
	var roster_written: Array = []

	func get_template(p_id: StringName) -> Variant:
		return templates.get(str(p_id))

	func create_state(p_template: Variant) -> Variant:
		return StateStub.new(str(p_template))

	func set_enemy_roster(p_roster: Array) -> void:
		roster_written = p_roster.duplicate()


## 敌态替身——只带重建后要被覆盖的那几个字段（默认值与存档值刻意不同）。
class StateStub:
	extends RefCounted

	var template_id: String = ""
	var current_hp: int = 99
	var max_hp: int = 99
	var is_alive: bool = true
	var field_position: int = -1

	func _init(p_template_id: String) -> void:
		template_id = p_template_id


## 战场根替身——记账建卡调用。[br]
## [br][b]extends Control 而不是 RefCounted[/b]：[code]start[/code] 的战场根参数是带类型的
## [Control]（生产的 [code]CombatRoot[/code] 就是），替身不满足类型会在调用那一刻直接报错
## ——而那会掩盖本组用例真正要验的顺序断言。
class RootStub:
	extends Control

	var built: Array = []

	func build_battle_roster(p_ids: Array) -> void:
		built = p_ids.duplicate()


## 出牌交互替身——记账放行。
class InteractionStub:
	extends RefCounted

	var enabled: int = 0

	func enable() -> void:
		enabled += 1


var combat: CombatStub = null
var deployment: DeploymentStub = null
var ai: AiStub = null
var root: RootStub = null
var interaction: InteractionStub = null
var resume: RefCounted = null


func before_each() -> void:
	IntentScript.clear()
	ContextScript.clear()
	combat = CombatStub.new()
	deployment = DeploymentStub.new()
	ai = AiStub.new()
	ai.templates[TEMPLATE] = {"id": TEMPLATE}
	add_child_autofree(combat)
	add_child_autofree(deployment)
	add_child_autofree(ai)
	root = RootStub.new()
	add_child_autofree(root)  # Control 也要进树回收（否则收尾报孤儿）
	interaction = InteractionStub.new()
	resume = ResumeSceneScript.new()


func after_each() -> void:
	IntentScript.clear()
	ContextScript.clear()


## 依赖包（[code]start[/code] 的三份取数来源；卡组按「本组不验抽牌」留空）。
func deps() -> Dictionary:
	return {"ai": ai, "deployment": deployment, "deck": null}


## 一份可续战的存档段（形状与 [code]battle_resume_payload.build[/code] 的产出同一口径）。[br]
## [br][b]为什么用常量键而不是裸字符串[/b]：键名一旦漂移，本文件会跟着漂——那就证明不了
## 读侧与写侧是同一份口径。
func payload() -> Dictionary:
	return {
		PayloadScript.KEY_IS_ACTIVE: true,
		PayloadScript.KEY_SCENE_ID: 4,
		PayloadScript.KEY_PHASE: PHASE,
		PayloadScript.KEY_TURN: TURN,
		PayloadScript.KEY_CURRENT_COST: COST,
		PayloadScript.KEY_MAX_COST: MAX_COST,
		PayloadScript.KEY_ORIGIN_NODE_ID: NODE_ID,
		PayloadScript.KEY_ORIGIN_COMBAT_TYPE: "boss",
		PayloadScript.KEY_PLAYER_ROSTER: [
			{PayloadScript.KEY_CHARACTER_ID: CHAR_A, PayloadScript.KEY_CURRENT_HP: 4,
				PayloadScript.KEY_MAX_HP: 12, PayloadScript.KEY_IS_ALIVE: true,
				PayloadScript.KEY_SLOT_INDEX: 0, PayloadScript.KEY_IS_FRONT: true},
			{PayloadScript.KEY_CHARACTER_ID: CHAR_B, PayloadScript.KEY_CURRENT_HP: 5,
				PayloadScript.KEY_MAX_HP: 9, PayloadScript.KEY_IS_ALIVE: true,
				PayloadScript.KEY_SLOT_INDEX: 3, PayloadScript.KEY_IS_FRONT: false},
		],
		PayloadScript.KEY_ENEMY_ROSTER: [
			{PayloadScript.KEY_CHARACTER_ID: 100000,
				PayloadScript.KEY_TEMPLATE_ID: TEMPLATE,
				PayloadScript.KEY_CURRENT_HP: ENEMY_HP,
				PayloadScript.KEY_MAX_HP: 16, PayloadScript.KEY_IS_ALIVE: true,
				PayloadScript.KEY_SLOT_INDEX: 0, PayloadScript.KEY_IS_FRONT: true},
		],
		PayloadScript.KEY_CONFIG: {
			"character_ids": [CHAR_A, CHAR_B],
			"enemy_template_ids": [TEMPLATE],
			"enemy_level": 2,
			"rewards": {"lingshi": 30},
		},
	}
