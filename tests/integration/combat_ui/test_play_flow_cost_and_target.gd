extends GutTest
## 出牌交互闭环集成测试：扣费 / 费用不足拒绝 / 目标默认与显式指定
## （combat-ui-interaction 001）。[br]
## [br][b]背景[/b]：`play_card()` 此前只认施法者，没有目标默认策略，费用不足也只
## 返回 false——三条链路在真实对局里都不完整。[br]
## [br][b]本文件锁定四条语义[/b]（全部走真实 CombatSystem + 真实 CostSystem）：[br]
##   1. 正常出牌 → [b]真的扣费[/b]（灵力从 5 降到 2）且伤害落到指定目标；[br]
##   2. 费用不足 → 拒绝、[b]不扣费[/b]、提示文本非空（不静默失败）；[br]
##   3. 不指定目标 → 默认打[b]首个存活敌人[/b]（跳过阵亡者）；[br]
##   4. 显式指定目标 → 打该目标（覆盖默认）。[br]
## [br]测试策略（同 test_play_bridge_settlement.gd）：`CS_SCRIPT.new()` 独立实例 +
## 真实 DeploymentSystem 阵位 + 真实 CostSystem；卡牌效果注入在卡实例字典里。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const StageScript: GDScript = preload("res://src/ui/combat/layout/combat_actor_stage.gd")
const ControllerScript: GDScript = preload(
		"res://src/ui/combat/shared/combat_play_controller.gd")
const PlayResult: GDScript = preload("res://src/feature/combat/combat_play_result.gd")
const TargetRules: GDScript = preload("res://src/ui/combat/shared/combat_target_rules.gd")
const EntryClass: GDScript = preload("res://src/core/card_system/effect_entry.gd")

## 本文件独立的角色 ID 段——不与其它测试文件夹具冲突。
const CHAR_CASTER: int = 7801
const CHAR_ENEMY_A: int = 7802
const CHAR_ENEMY_B: int = 7803
const CARD_ID: int = 78
## 费用上限（高于卡费，便于制造「付得起」与「付不起」两种场景）。
const COST_CAP: int = 5

var cs: Node = null
var stage: Node = null
var controller: RefCounted = null
var _release_ids: Array = []


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	cs.set("resolve_cb", Callable(func(_card, _targets) -> Array:
		return []))
	stage = StageScript.new()
	add_child_autofree(stage)
	stage.call(&"setup", cs, DeploymentSystem, null, null)
	controller = ControllerScript.new()
	controller.call(&"setup", stage.call(&"get_play_bridge"), null)
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	_release_ids.clear()


func after_each() -> void:
	if cs != null:
		cs.free()
		cs = null
	for cid: int in _release_ids:
		DeploymentSystem.remove_character(cid)
	_release_ids.clear()
	CostSystem.clear_for_battle_end()
	InputManager.clear_locks(&"combat_system")
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false


# ═══════════════════════════════════════════════════════════════════════════════
# 夹具
# ═══════════════════════════════════════════════════════════════════════════════

## 施法者上场 + 开战（默认 8/10 HP、攻击力 3）；敌方两名（A 20 HP、B 20 HP）。[br]
## [br][b]费用上限显式设 5[/b]：RealmSystem 在剥离环境不可用，走默认 2 费会让
## 「扣费」用例的卡费无从设置。
func _start_battle(enemy_a_hp: int = 20, enemy_b_hp: int = 20,
		caster_atk: int = 3) -> void:
	var ok: bool = DeploymentSystem.setup_field([CHAR_CASTER], {})
	assert_true(ok, "前置：施法者上场成功")
	if ok:
		_release_ids.append(CHAR_CASTER)
	cs.call("battle_start", {
		"enemy_roster": [
			{"character_id": CHAR_ENEMY_A, "current_hp": enemy_a_hp,
				"max_hp": 20, "attack": 4, "is_alive": true},
			{"character_id": CHAR_ENEMY_B, "current_hp": enemy_b_hp,
				"max_hp": 20, "attack": 4, "is_alive": true},
		],
		"character_ids": [CHAR_CASTER],
		"player_stats": {CHAR_CASTER: {"current_hp": 8, "max_hp": 10,
				"atk": caster_atk}},
	})
	CostSystem.init_for_battle(COST_CAP)
	cs.call("advance_phase")  # PREPARATION → DRAW
	cs.call("advance_phase")  # DRAW → PLAY


## 效果条目（[code]target[/code] 空 = 未声明）。
func _entry(effect_type: StringName, value: int,
		target: StringName = &"") -> Resource:
	var entry: Resource = EntryClass.new()
	entry.effect_type = effect_type
	entry.value = value
	entry.target = target
	entry.trigger = EntryClass.TRIGGER_ON_PLAY
	return entry


## 注入手牌——卡实例带着 [code]cost[/code] 与 [code]effects[/code] 列表。[br]
## [br][b]始终捎带一张 0 费填充卡[/b]：手牌为空且无费可出时 [code]play_card[/code]
## 会自动 [code]advance_phase[/code]（AC-007），出牌后阶段推进到 PLAY 之外，
## 同一场里就再也出不了第二张——那是生产行为，不该在测试里被意外触发。
const FILLER_ID: int = 79

func _setup_card(cost: int, entries: Array) -> void:
	var card: Dictionary = {
		"card_instance_id": CARD_ID, "cost": cost,
		"template_id": "test_play_flow", "effects": entries,
	}
	var filler: Dictionary = {
		"card_instance_id": FILLER_ID, "cost": 0,
		"template_id": "test_play_flow_filler", "effects": [],
	}
	cs.call("set_card_instances", {CARD_ID: card, FILLER_ID: filler})
	cs.call("set_hand", [card.duplicate(), filler.duplicate()])


## 选中本文件的测试卡。[br]
## [br][param affordable] UI 侧的费用充足性——[b]由调用方告知[/b]，因为交互层的
## 本地预判不查 CostSystem（真实生产里由 `cost_changed` 驱动刷入）。
## 卡费本身写在手牌快照里，由 [method _setup_card] 负责。
func _select(affordable: bool = true) -> void:
	controller.call(&"select_card", CARD_ID, affordable, false)


func _hp(character_id: int) -> int:
	return int(cs.call("get_character_hp", character_id)["current"])


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 正常出牌：真的扣费 + 伤害落目标
# ═══════════════════════════════════════════════════════════════════════════════

## 2 费卡 + 5 灵力 → 出牌后灵力 3，且伤害落到指定目标。[br]
## [br][b]为什么同时断言扣费与伤害[/b]：这两件事此前由完全不同的两段代码负责
## （CostSystem.spend 与效果落库），任一段断链都会让「出牌成功」变成谎报。
func test_successful_play_spends_cost_and_deals_damage() -> void:
	# Arrange——ATK 3 × 100% = 3 伤害
	_start_battle()
	_setup_card(2, [_entry(&"damage_multiplier", 100, &"single_enemy")])
	_select()
	# Act
	var out: Dictionary = controller.call(&"confirm")
	# Assert
	assert_true(PlayResult.is_ok(out), "出牌成功")
	assert_eq(CostSystem.get_current_cost(), COST_CAP - 2, "灵力扣减 2（5 → 3）")
	assert_eq(_hp(CHAR_ENEMY_A), 17, "伤害落到显式目标（20 → 17）")


## 0 费卡 → 出牌成功但灵力不变（0 费始终可出）。
func test_zero_cost_card_spends_nothing() -> void:
	# Arrange
	_start_battle()
	_setup_card(0, [_entry(&"damage_multiplier", 100, &"single_enemy")])
	_select()
	# Act
	var out: Dictionary = controller.call(&"confirm")
	# Assert
	assert_true(PlayResult.is_ok(out), "0 费卡可出")
	assert_eq(CostSystem.get_current_cost(), COST_CAP, "0 费不扣灵力")


## 出牌后手牌移除 + 选中清空（UI 不该继续以为「选着那张卡」）。
func test_successful_play_removes_card_and_clears_selection() -> void:
	# Arrange
	_start_battle()
	_setup_card(0, [_entry(&"damage_multiplier", 100, &"single_enemy")])
	_select()
	# Act
	controller.call(&"confirm")
	# Assert
	assert_eq(int(controller.call(&"get_selected_card_id")), -1, "选中被清空")
	var hand: Array = cs.call("get_hand")
	assert_eq(hand.size(), 1, "打出的卡离开手牌（只剩 0 费填充卡）")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 费用不足：拒绝 + 不扣费 + 有提示（本轮要求的重点）
# ═══════════════════════════════════════════════════════════════════════════════

## 9 费卡 + 5 灵力 → 系统侧拒绝、[b]灵力一分不动[/b]、提示文本非空。[br]
## [br][b]为什么要断言「不扣费」[/b]：ADR-0008 明文要求费用验证不通过时不得扣费；
## 只断言「返回失败」会漏掉「拒绝了但钱已经花了」这种最糟的失败形态。[br]
## [br]本用例[b]绕过交互层的本地预判[/b]（直接调系统 API）——本地预判会提前挡住，
## 那样就测不到系统侧的扣费守卫了。
func test_insufficient_cost_rejected_without_spending() -> void:
	# Arrange
	_start_battle()
	_setup_card(9, [_entry(&"damage_multiplier", 100, &"single_enemy")])
	# Act——直接调系统 API，跳过交互层的本地预判
	var out: Dictionary = cs.call("play_card_detailed", CARD_ID,
			[CHAR_ENEMY_A], CHAR_CASTER)
	# Assert
	assert_false(PlayResult.is_ok(out), "费用不足 → 拒绝")
	assert_eq(out["reason"], PlayResult.REASON_COST_NOT_ENOUGH, "原因：费用不足")
	assert_false(String(out["message"]).is_empty(), "带可显示的提示文本")
	assert_eq(CostSystem.get_current_cost(), COST_CAP, "拒绝时不扣费（仍 5 点）")
	assert_eq(_hp(CHAR_ENEMY_A), 20, "拒绝时效果不结算")
	assert_eq(cs.call("get_hand").size(), 2, "拒绝时卡牌留在手牌")


## 交互层在费用不足时[b]本地挡住[/b]——请求根本不发到系统侧，但仍有提示。[br]
## [br][b]与上一条的分工[/b]：本地挡住是「UI 早知道不行」，系统侧守卫是「即使 UI
## 放行也必须拦」——两层都要有，UI 可以被绕过（AI / 直接 API）。
func test_controller_blocks_unaffordable_before_request() -> void:
	# Arrange——9 费卡，但交互层被告知「付不起」
	_start_battle()
	_setup_card(9, [_entry(&"damage_multiplier", 100, &"single_enemy")])
	_select(false)  # 交互层被告知付不起
	# Act
	var out: Dictionary = controller.call(&"confirm")
	# Assert
	assert_false(PlayResult.is_ok(out), "本地拒绝")
	assert_eq(out["reason"], PlayResult.REASON_COST_NOT_ENOUGH, "原因：费用不足")
	assert_false(String(out["message"]).is_empty(), "本地拒绝也带提示文本")
	assert_eq(CostSystem.get_current_cost(), COST_CAP, "不扣费")


## 费用被花掉后（同回合内）→ 卡变不可出，拒绝且金额不变。
func test_cost_spent_by_previous_play_blocks_second_card() -> void:
	# Arrange——两张 3 费卡，灵力只有 5
	_start_battle()
	_setup_card(3, [_entry(&"damage_multiplier", 100, &"single_enemy")])
	_select()
	assert_true(PlayResult.is_ok(controller.call(&"confirm")), "第一张出牌成功")
	assert_eq(CostSystem.get_current_cost(), 2, "剩 2 点")
	# Act——同一张卡已在手外，直接再调系统 API 试第二张
	_setup_card(3, [_entry(&"damage_multiplier", 100, &"single_enemy")])
	var out: Dictionary = cs.call("play_card_detailed", CARD_ID,
			[CHAR_ENEMY_A], CHAR_CASTER)
	# Assert
	assert_false(PlayResult.is_ok(out), "只剩 2 点，3 费卡出不掉")
	assert_eq(CostSystem.get_current_cost(), 2, "失败不扣费")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 目标默认策略：首个存活敌人
# ═══════════════════════════════════════════════════════════════════════════════

## 不指定目标 → 打候选池[b]第一个[/b]（A）。
func test_default_target_is_first_enemy() -> void:
	# Arrange
	_start_battle()
	_setup_card(0, [_entry(&"damage_multiplier", 100, &"single_enemy")])
	_select()
	# Act——不调 set_targets，直接确认
	var out: Dictionary = controller.call(&"confirm")
	# Assert
	assert_true(PlayResult.is_ok(out), "出牌成功")
	assert_eq(_hp(CHAR_ENEMY_A), 17, "默认打第一个敌人（A：20 → 17）")
	assert_eq(_hp(CHAR_ENEMY_B), 20, "第二个敌人不受影响（B 仍 20）")


## 打不死的第一个目标已阵亡 → 默认跳到下一个存活者。[br]
## [br]这需要真的先把 A 打死（而不是塞一个 is_alive=false 的桩），才验证得了
## 「候选池的存活判定读的是战斗状态表」。
func test_default_target_skips_dead_enemy() -> void:
	# Arrange——A 只有 3 血，一刀打死
	_start_battle(3, 20)
	_setup_card(0, [_entry(&"damage_multiplier", 100, &"single_enemy")])
	_select()
	controller.call(&"confirm")  # 第一刀打死 A（默认目标）
	assert_eq(_hp(CHAR_ENEMY_A), 0, "前置：A 已阵亡")
	# Act——再出一张，默认应跳到 B
	_setup_card(0, [_entry(&"damage_multiplier", 100, &"single_enemy")])
	_select()
	var out: Dictionary = controller.call(&"confirm")
	# Assert
	assert_true(PlayResult.is_ok(out), "第二张出牌成功")
	assert_eq(_hp(CHAR_ENEMY_B), 17, "默认跳过阵亡的 A，打 B（20 → 17）")


## 候选池顺序即名册顺序——桥读到的 ID 与战斗状态表的键一致。[br]
## [br][b]为什么单测这条[/b]：ID 约定（enemy_id_of）若与状态表不同源，
## 候选池读到的永远是 0/0，会把活敌人误判成阵亡、默认目标乱跳。
func test_candidates_match_roster_state_ids() -> void:
	# Arrange——必须先开战（候选池读的是开战定格的敌方名册快照）
	_start_battle()
	# Act
	var candidates: Array = stage.call(&"enemy_candidates")
	# Assert
	assert_eq(candidates.size(), 2, "两名敌人")
	assert_eq(int(candidates[0]["character_id"]), CHAR_ENEMY_A, "顺序即名册顺序")
	assert_true(bool(candidates[0]["is_alive"]), "A 存活")
	assert_eq(int(candidates[0]["current_hp"]), 20, "HP 读自战斗状态表（非 0/0）")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 显式指定目标：覆盖默认
# ═══════════════════════════════════════════════════════════════════════════════

## 显式指定 B → 打 B，A 不受影响（默认策略被覆盖）。
func test_explicit_target_overrides_default() -> void:
	# Arrange
	_start_battle()
	_setup_card(0, [_entry(&"damage_multiplier", 100, &"single_enemy")])
	_select()
	controller.call(&"set_targets", [CHAR_ENEMY_B])
	# Act
	var out: Dictionary = controller.call(&"confirm")
	# Assert
	assert_true(PlayResult.is_ok(out), "出牌成功")
	assert_eq(_hp(CHAR_ENEMY_A), 20, "默认目标（A）未受伤")
	assert_eq(_hp(CHAR_ENEMY_B), 17, "显式目标（B）受伤（20 → 17）")


## 显式指定已阵亡的敌人 → 拒绝出牌（不静默改成默认目标）。[br]
## [br][b]这是「不猜」的关键用例[/b]：玩家点了 A，A 却死了——系统不能替玩家
## 决定改打 B，必须拒绝。
func test_explicit_dead_target_rejected_not_defaulted() -> void:
	# Arrange——先打死 A
	_start_battle(3, 20)
	_setup_card(0, [_entry(&"damage_multiplier", 100, &"single_enemy")])
	_select()
	controller.call(&"confirm")
	assert_eq(_hp(CHAR_ENEMY_A), 0, "前置：A 已阵亡")
	# Act——显式指向已阵亡的 A
	_setup_card(0, [_entry(&"damage_multiplier", 100, &"single_enemy")])
	_select()
	controller.call(&"set_targets", [CHAR_ENEMY_A])
	var out: Dictionary = controller.call(&"confirm")
	# Assert
	assert_false(PlayResult.is_ok(out), "目标已阵亡 → 拒绝（不改成打 B）")
	assert_eq(_hp(CHAR_ENEMY_B), 20, "B 未被误伤")
	assert_eq(cs.call("get_hand").size(), 2, "卡牌留在手牌")


## 显式指定多个存活敌人 → 每个都结算（群攻形态的目标列表）。
func test_explicit_multiple_targets_all_settle() -> void:
	# Arrange
	_start_battle()
	_setup_card(0, [_entry(&"damage_multiplier", 100, &"single_enemy")])
	_select()
	controller.call(&"set_targets", [CHAR_ENEMY_A, CHAR_ENEMY_B])
	# Act
	var out: Dictionary = controller.call(&"confirm")
	# Assert
	assert_true(PlayResult.is_ok(out), "出牌成功")
	assert_eq(_hp(CHAR_ENEMY_A), 17, "A 受伤")
	assert_eq(_hp(CHAR_ENEMY_B), 17, "B 同样受伤")


## 桥的 resolve_targets 明细：显式目标经存活校验后返回（source = 显式）。
func test_resolve_targets_reports_explicit_source() -> void:
	# Arrange
	_start_battle()
	# Act
	var out: Dictionary = stage.call(&"resolve_targets", [CHAR_ENEMY_B])
	# Assert
	assert_eq(out["targets"], [CHAR_ENEMY_B], "显式目标被采纳")
	assert_eq(int(out["source"]), TargetRules.SOURCE_EXPLICIT, "来源：显式")


## 空显式目标 → 桥走默认策略并报告来源（UI 可据此提示「默认打谁」）。
func test_resolve_targets_reports_default_source() -> void:
	# Arrange
	_start_battle()
	# Act
	var out: Dictionary = stage.call(&"resolve_targets", [])
	# Assert
	assert_eq(out["targets"], [CHAR_ENEMY_A], "默认取首个存活敌人")
	assert_eq(int(out["source"]), TargetRules.SOURCE_DEFAULT, "来源：默认")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 阶段守卫：非出牌阶段不可出
# ═══════════════════════════════════════════════════════════════════════════════

## 非 PLAY 阶段 → 拒绝且原因指向阶段（不给「费用不足」这种误导性提示）。
func test_play_outside_play_phase_rejected() -> void:
	# Arrange——只推进到 DRAW
	var ok: bool = DeploymentSystem.setup_field([CHAR_CASTER], {})
	assert_true(ok, "前置：上场成功")
	if ok:
		_release_ids.append(CHAR_CASTER)
	cs.call("battle_start", {
		"enemy_roster": [{"character_id": CHAR_ENEMY_A, "current_hp": 20,
				"max_hp": 20, "attack": 4, "is_alive": true}],
		"character_ids": [CHAR_CASTER],
	})
	CostSystem.init_for_battle(COST_CAP)
	cs.call("advance_phase")  # PREPARATION → DRAW
	_setup_card(0, [_entry(&"damage_multiplier", 100, &"single_enemy")])
	# Act
	var out: Dictionary = cs.call("play_card_detailed", CARD_ID,
			[CHAR_ENEMY_A], CHAR_CASTER)
	# Assert
	assert_false(PlayResult.is_ok(out), "非 PLAY 阶段 → 拒绝")
	assert_eq(out["reason"], PlayResult.REASON_WRONG_PHASE, "原因：阶段不对")
	assert_eq(CostSystem.get_current_cost(), COST_CAP, "不扣费")
