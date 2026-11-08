extends GutTest
## Sprint 18 集成测试：战场角色卡装配台（DEBT-CBT-018-1 残留闭环）。
##
## [b]背景[/b]：此前 `CombatFeedbackCoordinator` 没有任何生产实例化点，`_cards`
## 表永远为空——HP 落库只在数据层可见，HP 条与阵亡动画都不随真实数值变化。
## 本文件锁定装配台的两条职责：[br]
##   1. [b]UI 生命周期[/b]：名册 → 建卡 → 注册 → 阵亡移除 → 空位框 → 清场注销；[br]
##   2. [b]数值联动[/b]：伤害信号 → 结算帧 → 角色卡 [code]current_hp[/code]
##      与注入的 HP 读取契约一致（不是 0/0，也不是自己算的代数累加）。[br]
##
## 依赖注入：桩战斗系统（自持 HP 表 + 两个信号），真实 Coordinator / Card / Stage。

const StageScript: GDScript = preload("res://src/ui/combat/layout/combat_actor_stage.gd")
const CoordinatorScript: GDScript = preload("res://src/ui/combat/feedback/combat_feedback_coordinator.gd")
const EmptyFrameScript: GDScript = preload("res://src/ui/combat/layout/empty_slot_frame.gd")
const RosterState: GDScript = preload("res://src/feature/combat/combat_roster_state.gd")


## 桩战斗系统——HP 表 + character_damaged/character_died/battle_ended 三个信号，
## ID 约定与 CombatRosterState 一致（敌方 100000 起）。
class CombatStub extends Node:
	signal character_damaged(damage_data: Dictionary)
	signal character_died(character_id: int, side: int, binding_card_ids: Array)
	signal battle_ended(result: int, rewards: Dictionary)

	var hp_store: Dictionary = {}
	var roster: Array = []

	func get_character_hp(character_id: int) -> Dictionary:
		return hp_store.get(character_id, {"current": 0, "max": 0})

	func get_battle_enemy_roster() -> Array:
		return roster

	## 模拟一次落库后的伤害广播（先改 HP 表，再发信号——真实顺序）。
	func damage(character_id: int, amount: int, is_kill: bool = false,
			side: int = 0) -> void:
		var hp: Dictionary = get_character_hp(character_id)
		hp["current"] = maxi(int(hp["current"]) - amount, 0)
		hp_store[character_id] = hp
		character_damaged.emit({"character_id": character_id, "side": side,
				"damage": amount, "is_kill": is_kill})
		if is_kill:
			character_died.emit(character_id, side, [])


## 桩部署系统——我方阵位（前 2 后 1）。
class DeploymentStub extends Node:
	func get_field() -> Array:
		return [
			{"slot_index": 0, "character_id": 101, "is_front": true, "state": 1, "deploy_turn": 0},
			{"slot_index": 1, "character_id": 102, "is_front": true, "state": 1, "deploy_turn": 0},
			{"slot_index": 2, "character_id": 103, "is_front": false, "state": 1, "deploy_turn": 0},
		]


var combat: CombatStub = null
var deployment: DeploymentStub = null
var coordinator: Control = null
var stage: Node = null
var ally_area: Control = null
var enemy_area: Control = null


func before_each() -> void:
	combat = CombatStub.new()
	add_child_autofree(combat)
	deployment = DeploymentStub.new()
	add_child_autofree(deployment)
	coordinator = CoordinatorScript.new()
	add_child_autofree(coordinator)
	coordinator.setup([combat], null, Callable(combat, "get_character_hp"), true)
	ally_area = _make_area("AllyArea")
	enemy_area = _make_area("EnemyArea")
	stage = StageScript.new()
	add_child_autofree(stage)
	stage.setup(combat, deployment, null, null)
	stage.set_containers(ally_area, enemy_area)
	stage.bind_coordinator(coordinator)
	# 敌我各两人（敌方按约定派生 100000 / 110000；第二名显式后排）
	combat.roster = [
		{"max_hp": 30, "current_hp": 30, "attack": 4, "is_front_row": true},
		{"max_hp": 20, "current_hp": 20, "attack": 2, "is_front_row": false},
	]
	combat.hp_store = {
		101: {"current": 100, "max": 100},
		102: {"current": 60, "max": 100},
		103: {"current": 40, "max": 100},
		100000: {"current": 30, "max": 30},
		110000: {"current": 20, "max": 20},
	}


func after_each() -> void:
	combat = null
	deployment = null
	coordinator = null
	stage = null
	ally_area = null
	enemy_area = null


## 固定尺寸的战场区域（无容器父节点时 Control 不会自动撑开）。
func _make_area(area_name: String) -> Control:
	var area := Control.new()
	area.name = area_name
	area.size = Vector2(1400.0, 340.0)
	add_child_autofree(area)
	return area


func _wait_frames(frames: int) -> void:
	for i: int in frames:
		await get_tree().process_frame


# ═══════════════════════════════════════════════════════════════════════════════
# UI 生命周期：建卡 / 注册 / 阵亡 / 清场
# ═══════════════════════════════════════════════════════════════════════════════

func test_build_roster_creates_ally_and_enemy_cards() -> void:
	# Act——空名册 → 回退读阵位（3 人）+ 敌方快照 2 人
	stage.build_roster([])
	# Assert
	assert_eq(stage.card_count(), 5, "应建 3 张我方卡 + 2 张敌方卡")
	assert_eq(ally_area.get_child_count(), 3, "我方区应有 3 张卡")
	assert_eq(enemy_area.get_child_count(), 2, "敌方区应有 2 张卡")
	assert_not_null(stage.get_card(101), "我方角色 101 应有卡")
	assert_not_null(stage.get_card(100000), "敌方按约定派生 ID 建卡")
	assert_not_null(stage.get_card(110000), "第二名敌方 ID 步进 10000")


func test_build_roster_registers_cards_into_coordinator() -> void:
	# Act
	stage.build_roster([101, 102])
	# Assert——编排器的卡表不再为空（此前生产路径永远空 → HP 条无从更新）
	var registered: Dictionary = coordinator._cards
	assert_eq(registered.size(), 4, "2 名我方 + 2 名敌方应全部注册")
	assert_eq(registered[101], stage.get_card(101), "注册的节点应与装配台一致")


func test_initial_stats_come_from_system_not_zero() -> void:
	# Act
	stage.build_roster([101, 102])
	# Assert——首帧即真实数值（不是 0/0 等第一次伤害才刷新）
	var card: Control = stage.get_card(102)
	assert_eq(card.current_hp, 60, "我方卡初始 HP 应读战斗系统")
	assert_eq(card.max_hp, 100, "我方卡初始 max HP 应读战斗系统")
	var enemy: Control = stage.get_card(100000)
	assert_eq(enemy.current_hp, 30, "敌方卡初始 HP 应读敌方条目")
	assert_eq(enemy.atk_value, 4, "敌方 ATK 应读 EnemyBattleState.attack")


func test_front_row_sits_closer_to_midline_than_back_row() -> void:
	# Act
	stage.build_roster([])
	# Assert——我方前排在上（y 小）、后排在下；敌方相反
	var ally_front: Control = stage.get_card(101)
	var ally_back: Control = stage.get_card(103)
	assert_true(ally_front.position.y < ally_back.position.y,
		"我方前排应比我方后排更靠近中线")
	var enemy_front: Control = stage.get_card(100000)
	var enemy_back: Control = stage.get_card(110000)
	assert_true(enemy_front.position.y > enemy_back.position.y,
		"敌方前排应贴中线（位于己方前排之上、敌方后排之下）")


func test_death_signal_removes_card_and_leaves_empty_slot() -> void:
	# Arrange
	stage.build_roster([101, 102])
	# Act——致死伤害（reduce_motion 下瞬时移除）
	combat.damage(101, 100, true)
	await _wait_frames(2)
	# Assert
	assert_null(stage.get_card(101), "阵亡后装配台不应再持有该卡")
	assert_false(coordinator._cards.has(101), "编排器卡表应同步清理")
	var frame_found: bool = false
	for child: Node in ally_area.get_children():
		if child.get_script() == EmptyFrameScript:
			frame_found = true
	assert_true(frame_found, "阵亡卡位应出现空位虚线框")


func test_clear_roster_unregisters_and_frees_nodes() -> void:
	# Arrange
	stage.build_roster([101, 102])
	assert_true(coordinator._cards.has(101), "前置：已注册")
	# Act
	stage.clear_roster()
	# Assert
	assert_eq(stage.card_count(), 0, "装配台卡表应清空")
	assert_eq(coordinator._cards.size(), 0, "编排器卡表应清空（防悬空引用）")
	await _wait_frames(2)
	assert_eq(ally_area.get_child_count(), 0, "我方区节点应释放")


func test_rebuild_roster_does_not_leak_previous_cards() -> void:
	# Arrange——第一场：3 名我方 + 2 名敌方
	stage.build_roster([])
	# Act——第二场：只剩 1 名我方
	combat.roster = []
	stage.build_roster([102])
	# Assert
	assert_eq(stage.card_count(), 1, "重开战应清掉上一场的卡")
	assert_eq(ally_area.get_child_count(), 1, "我方区不应残留上一场的卡节点")
	assert_eq(enemy_area.get_child_count(), 0, "敌方区不应残留上一场的卡节点")


# ═══════════════════════════════════════════════════════════════════════════════
# 数值联动：伤害信号 → 结算帧 → HP 条
# ═══════════════════════════════════════════════════════════════════════════════

func test_damage_signal_updates_card_hp_to_terminal_value() -> void:
	# Arrange
	stage.build_roster([101])
	var card: Control = stage.get_card(101)
	# Act——两次同帧伤害（源系统终值 70）
	combat.damage(101, 20)
	combat.damage(101, 10)
	# Then：结算帧前不提前 apply
	assert_eq(card.current_hp, 100, "结算帧前不应提前更新")
	await _wait_frames(2)
	# Then：终值来自 HP 读取契约（读什么显示什么——UI 不自己减）
	assert_eq(card.current_hp, 70, "角色卡 HP 应跟随源系统终值")
	assert_eq(card.max_hp, 100, "max HP 保持不变")


func test_enemy_damage_updates_enemy_card_hp() -> void:
	# Arrange
	stage.build_roster([])
	var enemy: Control = stage.get_card(100000)
	# Act——敌方挨打（side=1）
	combat.damage(100000, 12, false, 1)
	await _wait_frames(2)
	# Assert
	assert_eq(enemy.current_hp, 18, "敌方卡 HP 应随落库后的终值更新")


func test_damage_without_card_is_ignored() -> void:
	# Arrange——未建卡的 ID
	stage.build_roster([101])
	var before: int = stage.card_count()
	# Act——不该崩溃
	combat.damage(999, 10)
	await _wait_frames(2)
	# Assert
	assert_eq(stage.card_count(), before, "未建卡角色不产生新卡")


func test_stage_has_no_process_polling() -> void:
	# Then：零轮询（ADR-0031 §3——建卡显式驱动 + resized 信号重排）
	assert_false(stage.has_method("_process"), "装配台不应有 _process")
	assert_false(stage.has_method("_physics_process"), "装配台不应有 _physics_process")


func test_enemy_id_matches_roster_state_convention() -> void:
	# Then——建卡与 HP 种子必须落在同一个键上（否则 UI 永远读 0/0）
	assert_eq(RosterState.enemy_id_of({"max_hp": 1}, 0), 100000, "第一名敌方 ID")
	assert_eq(RosterState.enemy_id_of({"max_hp": 1}, 2), 120000, "第三名敌方 ID 步进")
	assert_eq(RosterState.enemy_id_of({"character_id": 7}, 5), 7,
		"条目自带 character_id 时以其为准")


# ═══════════════════════════════════════════════════════════════════════════════
# 伤害入口不重复消费（character_damaged 优先于 attack_resolved）
# ═══════════════════════════════════════════════════════════════════════════════

## 信号源同时带两个伤害信号时，只订阅 character_damaged——否则同一次攻击
## 会发两次飘字（character_damaged 由落库广播、attack_resolved 由攻击队列广播）。
func test_coordinator_ignores_attack_resolved_when_damaged_present() -> void:
	# Arrange——带两个信号的源（真实 CombatSystem 的形态）
	var both := DualSignalStub.new()
	add_child_autofree(both)
	var dual_coordinator: Control = CoordinatorScript.new()
	add_child_autofree(dual_coordinator)
	dual_coordinator.setup([both], null, Callable(self, "_read_stub_hp"), true)
	# Act——两条信号各发一次同一角色
	both.attack_resolved.emit({"attacker_id": 1, "target_id": 101, "damage": 10,
			"is_kill": false})
	both.character_damaged.emit({"character_id": 101, "side": 0, "damage": 10,
			"is_kill": false})
	# Then: 只入队一次（10 而非 20）
	assert_eq(int(dual_coordinator._pending_deltas[101]["delta"]), 10,
		"两个伤害信号并存时只消费 character_damaged（防飘字重影）")


## 桩 HP 读取（dual 测试用——无卡时不会真的调用，契约仍需可调用）。
func _read_stub_hp(_character_id: int) -> Dictionary:
	return {"current": 90, "max": 100}


## 同时声明两个伤害信号的桩（真实 CombatSystem 的形态）。
class DualSignalStub extends Node:
	signal attack_resolved(attack_data: Dictionary)
	signal character_damaged(damage_data: Dictionary)
