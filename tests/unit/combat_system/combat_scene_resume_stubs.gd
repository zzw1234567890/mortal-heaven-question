extends RefCounted
## CombatSceneResumeStubs —— 读档续战用例的[b]替身集[/b]（与装置分家）。[br]
## [br][b]为什么单独一处[/b]：替身本体（记账面 + 形状）与「怎么铺一份存档段、铺哪些
## 常量」是两件事，且两者合起来已过 300 行软上限（.claude/docs/coding-standards.md）；
## 分家后装置文件只剩「铺场景」，读起来就是一份 setup 清单。[br]
## [br][b]用法[/b]：装置 [code]const Stubs := preload(本文件)[/code]，
## 经 [code]Stubs.CombatStub.new()[/code] 取用（GDScript 4 的内嵌类访问口径）。[br]
## [br][b]为什么全用替身[/b]：本组用例要验的是「先调谁后调谁、取哪个数」——跑一场真实
## 战斗既拿不到这条流水，还会把编排的错和战斗系统的错混在一起。[br]
## [br]来源: ADR-0008 §GSM 边界、本轮「牌面与 debuff 进存档」。

## 真实 debuff 管理器（替身不必模仿它的状态机——它是独立单测覆盖的对象）。
const DebuffManagerScript := preload("res://src/feature/combat/combat_debuff_manager.gd")


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
	## 接管进来的三堆牌（[method restore_piles] 落库）。
	var hand: Array = []
	var draw_pile: Array = []
	var discard_pile: Array = []
	## 状态表替身（debuff 管理器挂在这里——与生产同一条取数路径）。
	var roster: RefCounted = null

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

	func restore_piles(p_hand: Array, p_draw: Array, p_discard: Array) -> void:
		calls.append("restore_piles")
		hand = p_hand.duplicate()
		draw_pile = p_draw.duplicate()
		discard_pile = p_discard.duplicate()

	func get_roster_state() -> RefCounted:
		return roster


## 半截接线的战斗系统替身——只有旧方法面，没有 [method restore_piles]。[br]
## [br][b]为什么要单独一个[/b]：生产里存在过「只有 init_deck 没有接管」的实现形态，
## 续战必须在那样的系统上降级而不是崩——本替身把那一形态钉在用例里。
class PilelessCombatStub:
	extends Node

	var calls: Array = []

	func battle_start(_p_config: Dictionary) -> void:
		calls.append("battle_start")

	func set_auto_advance(_p_enabled: bool) -> void:
		calls.append("auto")

	func restore_battle_state(_t: int, _p: int, _c: int, _m: int) -> bool:
		calls.append("restore")
		return true

	func resume_auto_advance() -> void:
		calls.append("resume_auto")

	func get_roster_state() -> RefCounted:
		return null


## 状态表替身——只提供 [method get_debuff_manager]（真实管理器，不进树）。[br]
## [br][b]为什么用真管理器而不是再写一个替身[/b]：debuff 的层数 / 剩余回合 / 数值
## 语义就是被测内容，拿替身记账等于把断言对象换成了记账动作。
class RosterStub:
	extends RefCounted

	var debuff: RefCounted = null

	func _init() -> void:
		debuff = DebuffManagerScript.new()

	func get_debuff_manager() -> RefCounted:
		return debuff


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
