extends GutTest
## ResumePlayableFixture —— 「续战读档前/后可出牌数」用例的共享装置。[br]
## [br][b]为什么单独一处[/b]：用例文件要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「怎么摆一场真仗、怎么抓快照、怎么按续战顺序
## 重建」与「断言什么数相等」是两件事（同 [code]combat_scene_resume_fixture.gd[/code] 先例）。[br]
## [br][b]用法[/b]：子类 [code]extends "res://…/resume_playable_fixture.gd"[/code]，
## 只写 [code]test_*[/code] 方法；[code]before_each[/code] / [code]after_each[/code]
## 由本夹具提供，子类若要扩展需先 [code]super()[/code]。[br]
## [br][b]文件前缀[/b]：本文件不以 [code]test_[/code] 开头——GUT 按前缀收集，它只作为
## 基类被继承，不会被当作用例文件单独执行。[br]
## [br][b]子类不要重复声明本夹具的成员[/b]：GDScript 里子类重复声明同名成员是解析错误，
## 整个子类文件会被 GUT 静默忽略
## （[code]Ignoring script … because it does not extend GutTest[/code]），用例一条都不跑。[br]
## [br][b]为什么用真 CombatSystem 而不是替身[/b]：本组要验的数（还能出几张）由
## 「阶段 + 费用 + 手牌」三者共同决定，而这三者恰恰是重建链要接的东西——替身会把
## 「接没接上」这件事一起替掉，断言就成了自说自话。[br]
## [br]来源: ADR-0008 §GSM 边界 §阶段状态机、ADR-0031 §Logic 内核、
## 本轮「续战读档后本回合可出牌数漂移」。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const CaptureScript := preload("res://src/feature/combat/combat_resume_capture.gd")
const PayloadScript := preload("res://src/feature/combat/battle_resume_payload.gd")
const CardsScript := preload("res://src/feature/combat/battle_resume_cards.gd")
const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")

## 用例角色 ID 段（远离其它套件，防串场）。
const CHAR_A: int = 8871
## 来源节点 ID（读档回到战斗靠它认路）。
const NODE_ID: int = 781
## 敌人模板（[code]assets/enemies/[/code] 下的真实资源）。
const TEMPLATE: StringName = &"san_xiu"
## 卡组与卡面——全部 1 费，好让「费花光」与「出不动」是同一件事。
const CARD_IDS: Array[int] = [4101, 4102, 4103, 4104, 4105, 4106, 4107]
const CARD_COST: int = 1
## 满血我方（12 点，够挨几下不进入胜负判定）。
const PLAYER_HP: int = 12


## 战斗系统替身账本——只记 GSM 写入面（抓快照的落点）。
class ProbeGsm:
	extends Node

	var battle_resume: Dictionary = {}

	func serialize() -> Dictionary:
		return {"game_state": {}}

	func _set_battle_resume(resume: Dictionary) -> void:
		battle_resume = resume.duplicate(true)


var cs: Node = null


func before_each() -> void:
	_reset_world()


func after_each() -> void:
	_reset_world()
	if cs != null:
		cs.free()
		cs = null


## 世界归零——Autoload 跨套件共享，不还原会污染后续用例。[br]
## [br][b]解锁动画锁[/b]：阶段 4/5 会推 ANIMATION 锁，中途结束的用例会把它留在地上。
func _reset_world() -> void:
	ContextScript.clear()
	CostSystem.clear_for_battle_end()
	DeploymentSystem._reset_field()
	InputManager.clear_locks(&"combat_system")


## 开一场状态确定的仗（我方一名、敌方一名真实模板）。[br]
## [br][b]自动推进与场景切换都关掉[/b]：本组要手动把仗推到指定阶段，让它们各自跑
## 会把阶段推到一个不由用例决定的格子上。
func start_battle() -> Node:
	DeploymentSystem.setup_field([CHAR_A], {CHAR_A: true})
	ContextScript.publish({
		ContextScript.KEY_NODE_ID: NODE_ID,
		ContextScript.KEY_COMBAT_TYPE: "boss",
		ContextScript.KEY_TEMPLATE_IDS: [TEMPLATE],
		ContextScript.KEY_ENEMY_LEVEL: 2,
		ContextScript.KEY_REWARDS: {},
		ContextScript.KEY_PLAYER_ROSTER: [CHAR_A],
	})
	cs = _new_combat()
	cs.call("battle_start", config())
	return cs


## 开战配置——敌方走真实 [code]AISystem.create_enemy_roster[/code]（不是手捏字典：
## 重建侧要靠它认模板）。[br]
## [br][param p_stats] 我方 HP 种子；缺省按 [constant PLAYER_HP] 满血。[br]
## [br][b]为什么 HP 种子要能覆盖[/b]：续战开战的 HP 取[b]存档值[/b]而不是满血
## （生产侧 [code]combat_scene_resume._config[/code] 用的是
## [code]PayloadScript.player_stats[/code]）——不覆盖的话，重建出来的我方血量永远
## 是满的，读档后「看得见的盘面」就会比存档那一刻好看。
func config(p_stats: Dictionary = {}) -> Dictionary:
	var stats: Dictionary = p_stats if not p_stats.is_empty() \
			else {CHAR_A: {"current_hp": PLAYER_HP, "max_hp": PLAYER_HP}}
	return {
		"character_ids": [CHAR_A],
		"enemy_roster": AISystem.create_enemy_roster([TEMPLATE], 1, 2),
		"enemy_template_ids": [TEMPLATE],
		"enemy_level": 2,
		"rewards": {},
		"player_stats": stats,
	}


## 一场新仗的战斗系统（不自动推进、不切场景、卡面就绪）。[br]
## [br][b]效果回调留空[/b]：本组验的是「还能出几张」，出牌真的打到谁身上与它无关——
## 空回调让出牌只走「扣费 + 弃牌」两条真实落库路径。
func _new_combat() -> Node:
	var fresh: Node = CS_SCRIPT.new()
	fresh.call("set_auto_advance", false)
	fresh.call("set_scene_change", false)
	add_child_autofree(fresh)
	fresh.call("init_deck", CARD_IDS.duplicate())
	fresh.call("set_card_instances", _instances())
	fresh.set("resolve_cb", Callable(func(_card: Variant, _targets: Array) -> Array:
		return []))
	return fresh


## 卡面表——每张 1 费（费用刻意不是 0：0 费卡不受费用约束，花光费也就证明不了什么）。
func _instances() -> Dictionary:
	var out: Dictionary = {}
	for cid: int in CARD_IDS:
		out[cid] = {"card_instance_id": cid, "cost": CARD_COST, "template_id": "t_%d" % cid}
	return out


## 把一场仗推到指定阶段（用生产 API，不戳私有字段）。[br]
## [br][b]为什么不用 [code]advance_phase[/code] 直推[/b]：玩家主动阶段的转换是有前置
## 条件的（[code]combat_phase_manager.validate_transition[/code]），直推会被拒——
## 走玩家自己那两个按钮才是真实路径。
func drive_to(p_target_phase: int) -> void:
	var guard: int = 0
	while int(cs.call("get_current_phase")) != p_target_phase and guard < 12:
		guard += 1
		var phase: int = int(cs.call("get_current_phase"))
		if phase == 2:
			cs.call("confirm_end_turn")
		elif phase == 3:
			cs.call("confirm_attack_targets")
		else:
			cs.call("advance_phase")


## 本回合还能出几张牌——[b]阶段/费用/手牌三者共同决定[/b]。[br]
## [br][b]非出牌阶段返回 0[/b]：出牌守卫在 [code]combat_card_resolver.gd:55[/code]，
## 阶段不对时一张也出不去（这就是「存档在攻击声明阶段」这件事本身的代价）。
func playable_count(p_combat: Node) -> int:
	if int(p_combat.call("get_current_phase")) != 2:
		return 0
	return affordable_in_hand(p_combat)


## 手牌里打得起的张数（不看阶段——「阶段对不对」由调用方另行断言）。[br]
## [br][b]为什么要拆出这一半[/b]：读档后的阶段断言与「这几张还打得起吗」是两件事，
## 分开后一条红了能直接指出是哪半边出了问题。
func affordable_in_hand(p_combat: Node) -> int:
	var n: int = 0
	for entry: Variant in p_combat.call("get_hand"):
		if _affordable(p_combat, entry):
			n += 1
	return n


## 这一张打得起吗——[b]与 [code]play_card_detailed[/code] 逐位同一条判据[/b]：[br]
##   1. 按卡牌实例 ID 取实例（[code]combat_card_resolver._get_card_instance[/code]）；[br]
##   2. 按生产口径读它的费用（[code]_get_card_cost[/code]）；[br]
##   3. 问 [code]CostSystem.can_afford[/code]。[br]
## [br][b]为什么不能拿手牌条目直接读费用[/b]：手牌里那几条是牌堆数组的[b]元素本身[/b]
## （生产路径上就是卡牌实例 ID 的整数），它们身上没有 [code]cost[/code] 字段——
## 直接读会落到「认不出的格式，按 0 费处理」，于是每张都「打得起」，而真实的
## [code]play_card[/code] 是先去实例表换出带费用的卡面再判定的。两处口径不一致，
## 量出来的可出张数就不是玩家真正能出的张数。[br]
## [br]取不到实例（表里没这张卡）时按打不起处理——真实出牌也会被卡牌获取那一步拒掉。
func _affordable(p_combat: Node, p_card: Variant) -> bool:
	if p_combat == null:
		return false
	var card: Variant = p_combat.call(&"_get_card_instance", card_id_of(p_card))
	if card == null:
		return false
	var cost: int = int(p_combat.call(&"_get_card_cost", card))
	return CostSystem.can_afford(cost)


## 一张手牌的费用（[b]展示面[/b]——按实例表换卡面后读，与 [method _affordable] 同源）。[br]
## [br][b]为什么不能写死 1[/b]：手牌里那几条只是牌堆数组的元素（生产路径上是裸实例 ID），
## 费用记在卡面（[code]_card_instances[/code]）里——按生产口径现读，断言比
## 「我以为的 1 费」结实。[br]
## [br]实例表里没有这张卡时返回 -1（调用方据此判「这张牌认不出来」）。
func card_cost(p_card: Variant) -> int:
	if cs == null:
		return -1
	var card: Variant = cs.call(&"_get_card_instance", card_id_of(p_card))
	if card == null:
		return -1
	return int(cs.call(&"_get_card_cost", card))


## 手牌里的卡牌实例 ID（顺序即手牌顺序）。[br]
## [br][b]为什么不能拿卡组第一张当「要出的那张」[/b]：开局手牌是从洗过的牌堆里发的，
## 卡组第一张多半还在牌堆里。而 [code]play_card[/code] 只按实例表校验卡牌存在
## （[code]combat_card_resolver.gd:62[/code]），[b]不查它在不在手牌[/b]——拿一张不在
## 手上的牌去出，会扣费却不会从手牌里移除，用例就会验到一个假的出牌。
func hand_ids(p_combat: Node) -> Array:
	var out: Array = []
	for entry: Variant in p_combat.call("get_hand"):
		out.append(card_id_of(entry))
	return out


## 手牌条目 → 卡牌实例 ID（字典 / 裸整数两种形态，同 [code]discard_card[/code] 口径）。
func card_id_of(p_card: Variant) -> int:
	if p_card is Dictionary:
		var entry: Dictionary = p_card
		return int(entry.get("card_instance_id", entry.get("instance_id", -1)))
	if p_card is int or p_card is float:
		return int(p_card)
	return -1


## 抓一次快照（存档侧的真实入口，走注入句柄）。[br]
## [br][b]返回[/b]：GSM 替身（[code]battle_resume[/code] 就是存档段）。
func capture_snapshot(p_combat: Node) -> ProbeGsm:
	var gsm: ProbeGsm = ProbeGsm.new()
	add_child_autofree(gsm)
	var capture: RefCounted = CaptureScript.new()
	capture.combat = p_combat
	capture.deployment = DeploymentSystem
	capture.cost = CostSystem
	capture.gsm = gsm
	var outcome: Dictionary = capture.call(&"capture", 4)
	assert_true(bool(outcome.get("written", false)),
			"前置：战斗中抓快照应成功（原因：%s）" % outcome.get("reason", ""))
	return gsm


## 放行自动推进（续战重建的最后一步，[code]combat_scene_resume.start[/code] 的收尾）。[br]
## [br][b]顺序与生产一致[/b]：先 [code]set_auto_advance[/code] 再 [code]resume_auto_advance[/code]
## ——后者负责把下一格排上，而它的判据正是本组用例要验的那一格。
func release_auto_advance(p_combat: Node) -> void:
	p_combat.call("set_auto_advance", true)
	p_combat.call("resume_auto_advance")


## 等若干帧（放行自动推进后的 [code]call_deferred[/code] 链要走完才看得见漂移）。
func await_frames(p_count: int = 10) -> void:
	for i: int in range(p_count):
		await get_tree().process_frame


## 按 [code]combat_scene_resume.start[/code] 的顺序把一份存档段落回一场新仗。[br]
## [br][b]顺序不可换[/b]：开战 → 接管三堆牌 → 落位（见该类文档「重建顺序不可换」）。
## 落位之后自动推进的放行由调用方决定——那正是本组要断言的那一格。[br]
## [br][b]我方 HP 种子取存档值[/b]（[code]PayloadScript.player_stats[/code]）：
## 生产侧的 [code]_config[/code] 就是这么做——拿满血开战再落位的话，
## [code]restore_battle_state[/code] 只补阶段/回合/费用，血会停在满血，
## 「看得见的盘面原样复现」这条就永远不成立。
func rebuild(p_payload: Dictionary) -> Node:
	var fresh: Node = _new_combat()
	fresh.call("battle_start", config(PayloadScript.player_stats(p_payload)))
	fresh.call("restore_piles",
			CardsScript.ids_of(p_payload, CardsScript.KEY_HAND),
			CardsScript.ids_of(p_payload, CardsScript.KEY_DRAW_PILE),
			CardsScript.ids_of(p_payload, CardsScript.KEY_DISCARD_PILE))
	fresh.call("restore_battle_state",
			int(p_payload[PayloadScript.KEY_TURN]),
			int(p_payload[PayloadScript.KEY_PHASE]),
			int(p_payload[PayloadScript.KEY_CURRENT_COST]),
			int(p_payload[PayloadScript.KEY_MAX_COST]))
	return fresh
