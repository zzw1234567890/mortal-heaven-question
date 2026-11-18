extends "res://tests/integration/save_load/save_round_trip_fixture.gd"
## 「战斗中存档 → 读档回到这场战斗」的往返等价验收（A 存 / B 读）。[br]
## [br][b]为什么需要[/b]：[code]battle[/code] 域不可持久化（ADR-0008），战斗中的存档
## 此前只存探索进度——玩家读回来站在地图上，那场仗连同残血静默消失。本轮补上
## [code]battle_resume[/code] 段，本文件钉住它[b]真的过了一次磁盘[/b]之后仍然等价：
## 不是「内存里赋值对不对」，而是「JSON 写出去再读回来，逐项还能对上」。[br]
## [br][b]期望值的来源[/b]：存档那一刻从[b]活着的系统[/b]现读（战斗系统 / 费用 /
## 状态表 / 敌方名册快照），不是手抄常量——手抄的期望值只能证明「存了我以为的那几个
## 数」，证明不了「存的是当前这一局」。[br]
## [br][b]覆盖[/b]：[br]
##   1. 战斗侧抓快照 → 真实存档 → 清空内存 → 读回：阶段 / 回合 / 费用 / 敌我名册
##      与 HP 逐项等价；[br]
##   2. 读回的段能真的[b]重建[/b]：敌方按 [code]template_id[/code] 重建后 HP 覆盖到位、
##      我方 [code]player_stats[/code] 能被 [code]battle_start[/code] 吃下；[br]
##   3. 读档侧折回的上下文能过开战契约校验（否则「读档回到战斗」进不去）；[br]
##   4. 战斗结束后再存一次，这一份档不再带战斗段（C 项）。[br]
## [br][b]走真实链路[/b]：真 GSM + 真 SaveLoadSystem（仅换存档根）+ 真文件读写 +
## 真 [code]CombatSystem[/code] 实例 + 真 AISystem 模板——不注入桩
## （装置见 [code]save_round_trip_fixture.gd[/code]）。[br]
## [br]本文件独占角色 ID 段 8811+。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const CaptureScript := preload("res://src/feature/combat/combat_resume_capture.gd")
const PayloadScript := preload("res://src/feature/combat/battle_resume_payload.gd")
const RestoreScript := preload("res://src/feature/combat/battle_resume_restore.gd")
const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")
const Seeding := preload("res://src/feature/combat/combat_roster_seeding.gd")

const CHAR_A: int = 8811
const CHAR_B: int = 8812
## 来源节点 ID（读档回到战斗靠它认路）。
const NODE_ID: int = 771
## 敌人模板（[code]assets/enemies/[/code] 下的真实资源）。
const ENEMY_TEMPLATES: Array[StringName] = [&"san_xiu", &"mo_xiu"]
## 落位状态：第 5 回合 · 攻击声明阶段 · 费用 1/4（三个都是「不是出厂值」的数，
## 重置与没存都会被抓出来）。
const TURN: int = 5
const PHASE: int = 3
const COST: int = 1
const MAX_COST: int = 4
## 本场伤害（我方 8→4；敌方第 0 条 -5）。
const DAMAGE_PLAYER: int = 4
const DAMAGE_ENEMY: int = 5

var cs: Node = null


func root_path() -> String:
	return "user://test_battle_resume_saves/"


func before_each() -> void:
	super()
	ContextScript.clear()
	CostSystem.clear_for_battle_end()
	DeploymentSystem._reset_field()
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)


func after_each() -> void:
	ContextScript.clear()
	CostSystem.clear_for_battle_end()
	DeploymentSystem._reset_field()
	if cs != null:
		cs.free()
		cs = null
	super()


# ═══════════════════════════════════════════════════════════════════════════════
# 往返等价（A + B）
# ═══════════════════════════════════════════════════════════════════════════════

func test_battle_save_round_trip_keeps_progress_and_rosters() -> void:
	# Arrange——一场打到「第 5 回合 · 攻击声明阶段 · 只剩 1 费」的仗，双方都带伤
	var live: Dictionary = _start_and_capture()
	# Act——真实写盘 → 清空内存 → 真实读回
	assert_eq(save_wipe_load(), SLS.LoadResult.SUCCESS,
			"带战斗段的存档必须能读回来（形状不合 JSON 会在这里就失败）")
	var loaded: Dictionary = gsm.battle_resume
	# Assert——「这份档在战斗中」的判据在真档上成立
	assert_true(PayloadScript.is_in_battle(loaded),
			"读回的存档应带着「进行中战斗」标记（读档侧据此改去战斗场景）")
	assert_true(PayloadScript.is_resumable_payload(loaded),
			"读回的段应可续战（名册齐备）")
	# Assert——进度逐项等价（JSON 数字回来是 float，读侧一律 int()，故按读取口径比）
	assert_eq(int(loaded[PayloadScript.KEY_PHASE]), live["phase"], "阶段应与存档那一刻相同")
	assert_eq(int(loaded[PayloadScript.KEY_TURN]), live["turn"], "回合应与存档那一刻相同")
	assert_eq(int(loaded[PayloadScript.KEY_CURRENT_COST]), live["current_cost"],
			"当前费用应与存档那一刻相同")
	assert_eq(int(loaded[PayloadScript.KEY_MAX_COST]), live["max_cost"],
			"费用上限应与存档那一刻相同")
	assert_eq(int(loaded[PayloadScript.KEY_SCENE_ID]), 4, "存档场景 ID 应仍是战斗场景")
	# Assert——来源等价（读档要经探索那条开战链，来源是它的输入之一）
	assert_eq(int(loaded[PayloadScript.KEY_ORIGIN_NODE_ID]), NODE_ID, "来源节点应原样往返")
	assert_eq(str(loaded[PayloadScript.KEY_ORIGIN_COMBAT_TYPE]), "boss",
			"战斗类型应原样往返（Boss 通关判定读它）")
	# Assert——我方阵容 / HP / 阵型等价
	assert_eq(PayloadScript.player_ids(loaded), live["player_ids"],
			"出战阵容应与存档那一刻相同（含阵位顺序）")
	assert_eq(PayloadScript.player_stats(loaded), live["player_stats"],
			"我方 HP 表应逐项等价（8 扣 4 = 4，另一名保持 5）")
	assert_eq(PayloadScript.player_layout(loaded), live["player_layout"],
			"前后排应原样往返（重建时不过备战面板，靠它复现阵型）")
	# Assert——敌方名册与 HP 等价（残血必须存下来，否则等于满血重打）[br]
	# [b]比的是「再解析一次的结果」[/b]：JSON 数字读回来一律是 float，直接拿读回的
	# 字典与内存里的 int 字典比会全是类型差（而那不是缺陷，读侧本来就按 int() 消费）。
	# 两侧都过一遍载荷模块的解析口径，比的才是「同一场仗」。
	assert_eq(PayloadScript.enemy_entries(loaded[PayloadScript.KEY_ENEMY_ROSTER]),
			live["enemy_roster"], "敌方名册应逐条等价（身份 / 模板 / HP / 阵位全项）")
	assert_eq(int(loaded[PayloadScript.KEY_ENEMY_ROSTER][0][PayloadScript.KEY_CURRENT_HP]),
			live["enemy_hp"][0], "第 0 条敌人应带着残血往返")
	assert_lt(live["enemy_hp"][0], live["enemy_max_hp"][0],
			"前置：第 0 条敌人确实受了伤（否则这条断言证明不了残血存下来了）")


## 读回的段必须能[b]真的重建[/b]成战斗侧状态——否则「读档回到战斗」只是把玩家
## 送进一场数值不对的仗。
func test_loaded_payload_rebuilds_battle_side_state() -> void:
	# Arrange
	var live: Dictionary = _start_and_capture()
	assert_eq(save_wipe_load(), SLS.LoadResult.SUCCESS, "前置：存档往返成功")
	var loaded: Dictionary = gsm.battle_resume
	# Act——敌方按模板重建 + HP 覆盖（读档续战的真实重建路径）
	var roster: Array = RestoreScript.enemy_roster(loaded, AISystem)
	# Assert——重建出来的名册与存档逐条对齐（HP 以存档为准，不是模板满血）
	assert_eq(roster.size(), live["enemy_roster"].size(), "敌方应逐条重建（模板都还在）")
	for i: int in range(roster.size()):
		var state: Variant = roster[i]
		assert_eq(int(state.get("current_hp")), live["enemy_hp"][i],
				"第 %d 条敌人的残血应来自存档而不是模板满血" % i)
		assert_eq(int(state.get("max_hp")), live["enemy_max_hp"][i],
				"第 %d 条敌人的 HP 上限应来自存档" % i)
		assert_eq(int(state.get("field_position")), live["enemy_slots"][i],
				"第 %d 条敌人的阵位应来自存档" % i)
		assert_eq(bool(state.get("is_alive")), true, "第 %d 条敌人应仍存活" % i)
	# Assert——我方 HP 表与存档一致（[code]battle_start.player_stats[/code] 吃得下）
	assert_eq(PayloadScript.player_stats(loaded), live["player_stats"],
			"我方种子 HP 表应逐项等价（两名上场角色都在）")


## 战斗中存的档，读回来时要认得出「这一仗的原点是哪个节点」——读档侧据此折回
## 开战上下文（标题 / 掉落 / 模板全从那里读）。
func test_loaded_payload_folds_back_into_launch_context() -> void:
	# Arrange
	_start_and_capture()
	assert_eq(save_wipe_load(), SLS.LoadResult.SUCCESS, "前置：存档往返成功")
	# Act
	var context: Dictionary = PayloadScript.launch_context(gsm.battle_resume)
	# Assert——折回的上下文要能过开战契约校验，否则读档进不了战斗
	assert_true(ContextScript.validate(context).is_empty(),
			"折回的上下文必须过开战校验：%s" % ContextScript.validate(context))
	assert_eq(int(context[ContextScript.KEY_NODE_ID]), NODE_ID, "来源节点应折回")
	assert_eq(str(context[ContextScript.KEY_COMBAT_TYPE]), "boss", "战斗类型应折回")
	assert_eq(context[ContextScript.KEY_PLAYER_ROSTER], [CHAR_A, CHAR_B],
			"玩家阵容应折回（开战校验要求非空）")


# ═══════════════════════════════════════════════════════════════════════════════
# 收尾（C 项：打完之后的档不该再带着这场仗）
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_after_battle_end_carries_no_battle_section() -> void:
	# Arrange——存过一次战斗中档，然后战斗结束
	_start_and_capture()
	assert_true(PayloadScript.is_in_battle(gsm.battle_resume), "前置：战斗中档已写入")
	cs.call("battle_end", CS_SCRIPT.CombatResult.RETREAT)
	# Act——结束之后再存一次（走真实写盘与读回）
	assert_eq(save_wipe_load(), SLS.LoadResult.SUCCESS, "战后存档同样要能读回来")
	# Assert——这一份档不再带战斗段
	assert_false(PayloadScript.is_in_battle(gsm.battle_resume),
			"战斗结束后的存档不得再带「进行中战斗」标记（否则读档回到一盘打完的棋）")
	assert_eq(PayloadScript.is_resumable_payload(gsm.battle_resume), false,
			"战斗结束后的存档不得判为可续战")
	assert_eq(gsm.battle_resume, {}, "收尾后这一段应回到出厂值（空字典）")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 开一场状态确定的仗、打点伤害、抓快照，并返回[b]存档那一刻的活值[/b]。[br]
## [br][b]状态怎么定[/b]：走生产 API [code]restore_battle_state[/code]（读档续战用的
## 就是它），把阶段 / 回合 / 费用摆成确定值——不去手工戳私有字段，也不靠推进
## 阶段链凑（那条链的结果依赖手牌与费用，与本文件要验的东西无关）。[br]
## [br][b]返回[/b]：期望值字典（阶段 / 回合 / 费用 / 敌我 HP 与阵容），
## 全部现读自活着的系统。
func _start_and_capture() -> Dictionary:
	assert_true(DeploymentSystem.setup_field([CHAR_A, CHAR_B], {CHAR_A: true, CHAR_B: false}),
			"前置：两名角色上场成功（练气上限 2 人）")
	ContextScript.publish({
		ContextScript.KEY_NODE_ID: NODE_ID,
		ContextScript.KEY_COMBAT_TYPE: "boss",
		ContextScript.KEY_TEMPLATE_IDS: ENEMY_TEMPLATES.duplicate(),
		ContextScript.KEY_ENEMY_LEVEL: 2,
		ContextScript.KEY_REWARDS: {"lingshi": 30},
		ContextScript.KEY_PLAYER_ROSTER: [CHAR_A, CHAR_B],
	})
	var enemy_roster: Array = AISystem.create_enemy_roster(ENEMY_TEMPLATES, 1, 2)
	assert_eq(enemy_roster.size(), 2, "前置：敌方名册生成成功")
	cs.call("battle_start", {
		"character_ids": [CHAR_A, CHAR_B],
		"enemy_roster": enemy_roster,
		"enemy_template_ids": ENEMY_TEMPLATES.duplicate(),
		"enemy_level": 2,
		"rewards": {"lingshi": 30},
		"player_stats": {
			CHAR_A: {"current_hp": 8, "max_hp": 12},
			CHAR_B: {"current_hp": 5, "max_hp": 9},
		},
	})
	assert_true(bool(cs.call("is_battle_active")), "前置：战斗已开")
	assert_true(bool(cs.call("restore_battle_state", TURN, PHASE, COST, MAX_COST)),
			"前置：状态落位成功")
	# 打点伤害——残血是「存档真的存了这一局」的最强证据
	var enemy_ids: Array = _enemy_ids(2)
	cs.call("get_roster_state").call("apply_damage", CHAR_A, DAMAGE_PLAYER)
	cs.call("get_roster_state").call("apply_damage", enemy_ids[0], DAMAGE_ENEMY)
	var live: Dictionary = _live_expectations(enemy_ids)
	# Act——抓快照（存档侧的真实入口）
	var capture: RefCounted = CaptureScript.new()
	capture.combat = cs
	capture.deployment = DeploymentSystem
	capture.gsm = gsm
	var outcome: Dictionary = capture.call(&"capture", 4)
	assert_true(bool(outcome.get("written", false)),
			"战斗中抓快照应成功（原因：%s）" % outcome.get("reason", ""))
	assert_true(PayloadScript.is_in_battle(gsm.battle_resume), "前置：快照落在 GSM 里")
	return live


## 存档那一刻的活值——阶段 / 回合 / 费用现读系统，HP 与名册现读状态表快照。[br]
## [br][b]为什么敌方 HP 走 [code]snapshot_all[/code][/b]：那是战斗内 HP 的唯一真理来源
## （伤害落库与结算回流同一取数口径）；现读名册对象只是它的工作面。
func _live_expectations(p_enemy_ids: Array) -> Dictionary:
	var hp_by_id: Dictionary = {}
	for raw: Variant in cs.call("get_roster_state").call("snapshot_all"):
		var entry: Dictionary = raw
		hp_by_id[int(entry["character_id"])] = int(entry["current_hp"])
	var enemy_hp: Array = []
	var enemy_max_hp: Array = []
	var enemy_slots: Array = []
	for raw_id: Variant in p_enemy_ids:
		var cid: int = int(raw_id)
		enemy_hp.append(int(hp_by_id.get(cid, -1)))
		enemy_max_hp.append(_enemy_max_hp(cid))
		enemy_slots.append(_enemy_slot(cid))
	return {
		"phase": int(cs.call("get_current_phase")),
		"turn": int(cs.call("get_turn_number")),
		"current_cost": int(CostSystem.get_current_cost()),
		"max_cost": int(CostSystem.get_max_cost()),
		"player_ids": [CHAR_A, CHAR_B],
		"player_stats": {
			CHAR_A: {"current_hp": 8 - DAMAGE_PLAYER, "max_hp": 12},
			CHAR_B: {"current_hp": 5, "max_hp": 9},
		},
		"player_layout": {CHAR_A: true, CHAR_B: false},
		"enemy_hp": enemy_hp,
		"enemy_max_hp": enemy_max_hp,
		"enemy_slots": enemy_slots,
		"enemy_roster": PayloadScript.enemy_entries(
				cs.call("get_battle_enemy_roster")),
	}


## 本场敌方角色的编码 ID（与开战种子同一套：BASE + 序号 × STRIDE）。
func _enemy_ids(p_count: int) -> Array:
	var out: Array = []
	for i: int in range(p_count):
		out.append(Seeding.ENEMY_ID_BASE + i * Seeding.ENEMY_ID_STRIDE)
	return out


## 本场敌方当前 HP 上限（现读战斗系统定格的名册——按真实序号算身份）。
func _enemy_max_hp(p_id: int) -> int:
	var roster: Array = cs.call("get_battle_enemy_roster")
	for idx: int in range(roster.size()):
		if Seeding.enemy_id_of(roster[idx], idx) == p_id:
			return int(Seeding.entry_int(roster[idx], "max_hp", -1))
	return -1


## 本场敌方阵位（同上）。
func _enemy_slot(p_id: int) -> int:
	var roster: Array = cs.call("get_battle_enemy_roster")
	for idx: int in range(roster.size()):
		if Seeding.enemy_id_of(roster[idx], idx) == p_id:
			return int(Seeding.entry_int(roster[idx], "field_position", -1))
	return -1
