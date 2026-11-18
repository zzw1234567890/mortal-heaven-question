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
## [br][b]替身本体在 [code]combat_scene_resume_stubs.gd[/code][/b]（六个替身分家到
## 单独一处，两份文件各自守在 300 行软上限内）——本文件只负责「摆一套舞台 + 造一份
## 可续战的存档段」。[br]
## [br][b]子类不要重复声明本夹具的成员[/b]：GDScript 里子类重复声明同名成员是解析错误，
## 整个子类文件会被 GUT 静默忽略
## （[code]Ignoring script … because it does not extend GutTest[/code]），用例一条都不跑。[br]
## [br][b]为什么全用替身[/b]：本组用例要验的是「先调谁后调谁、取哪个数」——跑一场真实
## 战斗既拿不到这条流水，还会把编排的错和战斗系统的错混在一起。[br]
## [br]来源: ADR-0008 §GSM 边界、ADR-0017 §EnemyFactory、
## 本轮「战斗中存档 → 读档回到战斗」（B 项）。

## 贡献者：被测模块与它依赖的几个形状模块。
const ResumeSceneScript := preload("res://src/feature/combat/combat_scene_resume.gd")
## 替身集（记账面与形状——与「怎么铺场景」分家）。
const Stubs := preload("res://tests/unit/combat_system/combat_scene_resume_stubs.gd")
const IntentScript := preload("res://src/feature/combat/battle_resume_intent.gd")
const PayloadScript := preload("res://src/feature/combat/battle_resume_payload.gd")
const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")
## 牌面 / debuff 两段的形状模块（本夹具不重写一份键名——两处各写一遍必然漂移）。
const CardsScript := preload("res://src/feature/combat/battle_resume_cards.gd")
const DebuffsScript := preload("res://src/feature/combat/battle_resume_debuffs.gd")
## 真实 debuff 管理器（替身不必模仿它的状态机——它是独立单测覆盖的对象）。
const DebuffManagerScript := preload("res://src/feature/combat/combat_debuff_manager.gd")

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
## 三堆牌（顺序刻意打乱——顺序错了「顺序也一致」这条断言才会红）。
const HAND_IDS: Array[int] = [9011, 9012]
const DRAW_IDS: Array[int] = [9001, 9002, 9003]
const DISCARD_IDS: Array[int] = [9004]
## 存档里挂着的一条 debuff（目标 / 类型 / 剩余回合 / 数值 / 来源都不是出厂值）。
const DEBUFF_TARGET: int = 100000
const DEBUFF_DURATION: int = 2
const DEBUFF_AMOUNT: int = 3


var combat: Stubs.CombatStub = null
var deployment: Stubs.DeploymentStub = null
var ai: Stubs.AiStub = null
var root: Stubs.RootStub = null
var interaction: Stubs.InteractionStub = null
var resume: RefCounted = null


func before_each() -> void:
	IntentScript.clear()
	ContextScript.clear()
	combat = Stubs.CombatStub.new()
	combat.roster = Stubs.RosterStub.new()
	deployment = Stubs.DeploymentStub.new()
	ai = Stubs.AiStub.new()
	ai.templates[TEMPLATE] = {"id": TEMPLATE}
	add_child_autofree(combat)
	add_child_autofree(deployment)
	add_child_autofree(ai)
	root = Stubs.RootStub.new()
	add_child_autofree(root)  # Control 也要进树回收（否则收尾报孤儿）
	interaction = Stubs.InteractionStub.new()
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
		CardsScript.KEY_CARDS: {
			CardsScript.KEY_HAND: _card_entries(HAND_IDS),
			CardsScript.KEY_DRAW_PILE: _card_entries(DRAW_IDS),
			CardsScript.KEY_DISCARD_PILE: _card_entries(DISCARD_IDS),
		},
		DebuffsScript.KEY_DEBUFFS: [{
			DebuffsScript.KEY_TARGET_ID: DEBUFF_TARGET,
			DebuffsScript.KEY_TYPE: DebuffManagerScript.TYPE_ATK,
			DebuffsScript.KEY_DURATION: DEBUFF_DURATION,
			DebuffsScript.KEY_AMOUNT: DEBUFF_AMOUNT,
			DebuffsScript.KEY_SOURCE_ID: CHAR_A,
		}],
	}


## 一堆牌的存档条目（形状与写侧折叠的产出同一口径）。[br]
## [br][b]等级刻意不全为 1[/b]：升级与否要能被读侧区分——全 1 的话
## 「等级也一致」这条断言证明不了任何事。
func _card_entries(p_ids: Array) -> Array:
	var out: Array = []
	for idx: int in range(p_ids.size()):
		var cid: int = int(p_ids[idx])
		out.append({
			CardsScript.KEY_CARD_INSTANCE_ID: cid,
			CardsScript.KEY_TEMPLATE_ID: "card_%d" % cid,
			CardsScript.KEY_LEVEL: 1 if idx == 0 else 2,
		})
	return out
