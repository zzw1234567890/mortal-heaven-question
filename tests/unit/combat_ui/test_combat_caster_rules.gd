extends GutTest
## UI 出牌施法者裁定 + 出牌桥（DEBT-CBT-018-10 第四阶段）。[br]
## [br][b]背景[/b]：`CombatSystem.play_card()` 的 `caster_id` 决定倍率伤害的 ATK
## 取数对象与治疗落点，但 UI 侧此前无人传入——真实对局里这两类效果从不结算。[br]
## [br][b]本文件锁定四条语义[/b]：[br]
##   1. 施法者 = 我方阵位第一个已占用且未阵亡的角色（跳过空位与 DEAD）；[br]
##   2. 判不出（空阵位 / 全阵亡 / 快照不可用）返回 -1——[b]不猜[/b]；[br]
##   3. 出牌桥把裁定结果原样传给 `CombatSystem.play_card()`（含 -1 的原样透传）；[br]
##   4. 装配台 / 布局的公开入口能走通同一条链路（生产接线不只在单测里成立）。[br]
## [br]全部用例使用注入桩——不触碰 Autoload、不依赖文件系统。

const CasterRules := preload("res://src/ui/combat/shared/combat_caster_rules.gd")
const PlayBridge := preload("res://src/ui/combat/shared/combat_play_bridge.gd")
const StageScript: GDScript = preload("res://src/ui/combat/layout/combat_actor_stage.gd")
## 阵位系统脚本——只为读 [code]FieldState[/code] 枚举值做镜像一致性断言。
const DeploymentScript: GDScript = preload("res://src/feature/deployment_system.gd")


## 桩战斗系统——记录 play_card 的入参并返回预设结果。
class CombatStub extends Node:
	var calls: Array = []
	var result: bool = true

	func play_card(card_instance_id: int, target_indices: Array,
			caster_id: int = -1) -> bool:
		calls.append({"card_instance_id": card_instance_id,
				"targets": target_indices.duplicate(), "caster_id": caster_id})
		return result


## 桩部署系统——返回预设阵位快照。
class DeploymentStub extends Node:
	var field: Array = []

	func get_field() -> Array:
		return field.duplicate(true)


## 阵位条目工厂（state：0 空位 / 1 待命 / 2 就绪 / 3 已行动 / 4 阵亡）。
func _slot(character_id: int, state: int = 1, slot_index: int = 0) -> Dictionary:
	return {"slot_index": slot_index, "character_id": character_id,
		"is_front": true, "state": state, "deploy_turn": 0}


func _empty_slot(slot_index: int) -> Dictionary:
	return _slot(-1, CasterRules.FIELD_STATE_EMPTY, slot_index)


var combat: CombatStub = null
var deployment: DeploymentStub = null
var bridge: RefCounted = null


func before_each() -> void:
	combat = CombatStub.new()
	add_child_autofree(combat)
	deployment = DeploymentStub.new()
	add_child_autofree(deployment)
	bridge = PlayBridge.new()
	bridge.call(&"setup", combat, deployment)


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 施法者裁定纯函数
# ═══════════════════════════════════════════════════════════════════════════════

## 阵位第一个已占用角色即施法者（无论前后排）。
func test_resolve_caster_picks_first_occupied_slot() -> void:
	# Arrange
	var field: Array = [_slot(101, 1, 0), _slot(102, 2, 1)]
	# Act / Assert
	assert_eq(CasterRules.resolve_caster(field), 101, "取 slot 0 的角色")

## 空位在前时跳过——不把 -1 当施法者。
func test_resolve_caster_skips_empty_slots() -> void:
	# Arrange
	var field: Array = [_empty_slot(0), _slot(102, 2, 1)]
	# Act / Assert
	assert_eq(CasterRules.resolve_caster(field), 102, "跳过空位取下一名上场角色")

## 阵亡角色（DEAD）跳过——刚死的人不能继续出牌。
func test_resolve_caster_skips_dead_character() -> void:
	# Arrange
	var field: Array = [_slot(101, CasterRules.FIELD_STATE_DEAD, 0), _slot(102, 2, 1)]
	# Act / Assert
	assert_eq(CasterRules.resolve_caster(field), 102, "跳过阵亡者")

## 空阵位 / 全空 / 全阵亡 → -1（不猜）。
func test_resolve_caster_returns_no_caster_when_nothing_alive() -> void:
	# Arrange
	var all_empty: Array = [_empty_slot(0), _empty_slot(1)]
	var all_dead: Array = [_slot(101, CasterRules.FIELD_STATE_DEAD, 0)]
	# Act / Assert
	assert_eq(CasterRules.resolve_caster([]), CasterRules.NO_CASTER, "空快照 → -1")
	assert_eq(CasterRules.resolve_caster(all_empty), CasterRules.NO_CASTER, "全空位 → -1")
	assert_eq(CasterRules.resolve_caster(all_dead), CasterRules.NO_CASTER, "全阵亡 → -1")

## 快照不可用（非数组 / 含非法条目）→ -1，不崩。
func test_resolve_caster_tolerates_bad_input() -> void:
	# Act / Assert
	assert_eq(CasterRules.resolve_caster(null), CasterRules.NO_CASTER, "null → -1")
	assert_eq(CasterRules.resolve_caster("field"), CasterRules.NO_CASTER, "字符串 → -1")
	assert_eq(CasterRules.resolve_caster([42, null]), CasterRules.NO_CASTER,
			"非字典条目跳过")

## state 字段缺失视为未阵亡——只有显式 DEAD 才排除（不靠缺失推定阵亡）。
func test_resolve_caster_treats_missing_state_as_alive() -> void:
	# Arrange
	var field: Array = [{"character_id": 101}]
	# Act / Assert
	assert_eq(CasterRules.resolve_caster(field), 101, "缺 state 不判死")


## 乱序快照按 slot_index 升序裁定——不依赖调用方把数组排好。[br]
## [br][b]为什么需要这条[/b]：类文档承诺「按 slot_index 升序」，而
## [code]DeploymentSystem.get_field()[/code] 只是恰好有序；桩数据 / 过滤合并过的
## 快照未必有序，此时按数组顺序裁定会选错出牌角色，且症状极难归因。
func test_resolve_caster_sorts_by_slot_index() -> void:
	# Arrange——slot 3 的条目排在数组第一位
	var field: Array = [_slot(203, 2, 3), _slot(201, 2, 0), _slot(202, 2, 1)]
	# Act / Assert
	assert_eq(CasterRules.resolve_caster(field), 201, "按 slot_index 0 而非数组顺序")


## 缺 slot_index 的条目排到末尾——无法定位的条目不当第一位抢走施法者。
func test_resolve_caster_puts_entry_without_slot_index_last() -> void:
	# Arrange——无 slot_index 的条目在前，有序条目在后
	var field: Array = [{"character_id": 301}, _slot(302, 2, 0)]
	# Act / Assert
	assert_eq(CasterRules.resolve_caster(field), 302, "有 slot_index 的条目优先")


## state = EMPTY 但 character_id 合法（脏数据）→ 跳过，不当作存活角色。[br]
## 空位的正规定义是 [code]character_id = -1[/code]；这条防的是「只改了一半」的
## 脏条目被当成可出牌角色。
func test_resolve_caster_skips_empty_state_with_occupied_id() -> void:
	# Arrange
	var field: Array = [_slot(401, CasterRules.FIELD_STATE_EMPTY, 0), _slot(402, 2, 1)]
	# Act / Assert
	assert_eq(CasterRules.resolve_caster(field), 402, "EMPTY 状态跳过")


## 镜像常量与 DeploymentSystem.FieldState 保持一致——枚举改动未同步时此处变红。[br]
## [br][b]为什么需要这条断言[/b]：纯函数模块刻意不依赖全局单例（可零依赖单测），
## 代价是 FieldState 的取值被按值镜像；没有这条绊线，将来改枚举会静默漏掉
## 「跳过空位 / 跳过阵亡」这两条规则（表现为空位或刚死的人继续出牌）。
func test_mirrored_field_state_constants_match_deployment_system() -> void:
	# Assert
	assert_eq(CasterRules.FIELD_STATE_EMPTY, DeploymentScript.FieldState.EMPTY,
			"FIELD_STATE_EMPTY 应镜像 FieldState.EMPTY")
	assert_eq(CasterRules.FIELD_STATE_READY, DeploymentScript.FieldState.READY,
			"FIELD_STATE_READY 应镜像 FieldState.READY")
	assert_eq(CasterRules.FIELD_STATE_DEAD, DeploymentScript.FieldState.DEAD,
			"FIELD_STATE_DEAD 应镜像 FieldState.DEAD")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 出牌桥：裁定结果原样透传
# ═══════════════════════════════════════════════════════════════════════════════

## 有存活角色 → play_card 收到该角色 ID。
func test_bridge_passes_resolved_caster_to_play_card() -> void:
	# Arrange
	deployment.field = [_slot(101, 2, 0), _slot(102, 2, 1)]
	# Act
	var ok: bool = bool(bridge.call(&"play_card", 7, [100000]))
	# Assert
	assert_true(ok, "出牌成功")
	assert_eq(combat.calls.size(), 1, "转交一次")
	assert_eq(int(combat.calls[0]["caster_id"]), 101, "施法者 = 阵位第一个存活角色")
	assert_eq(int(combat.calls[0]["card_instance_id"]), 7, "卡实例 ID 原样透传")
	assert_eq(combat.calls[0]["targets"], [100000], "目标列表原样透传")

## 无阵位 → 传 -1（缺省口径不变：下游不结算，不猜）。
func test_bridge_passes_minus_one_when_no_caster() -> void:
	# Arrange
	deployment.field = []
	# Act
	bridge.call(&"play_card", 8, [])
	# Assert
	assert_eq(int(combat.calls[0]["caster_id"]), -1, "判不出施法者时传 -1")

## 目标列表不被篡改（透传副本——桥不改调用方数组）。
func test_bridge_does_not_mutate_targets() -> void:
	# Arrange
	deployment.field = [_slot(101, 2, 0)]
	var targets: Array = [100000]
	# Act
	bridge.call(&"play_card", 9, targets)
	# Assert
	assert_eq(targets, [100000], "调用方数组保持原样")

## 战斗系统未注入 → 返回 false，不崩。
func test_bridge_without_combat_returns_false() -> void:
	# Arrange
	var bare: RefCounted = PlayBridge.new()
	bare.call(&"setup", null, deployment)
	# Act / Assert
	assert_false(bool(bare.call(&"play_card", 1, [])), "未注入战斗系统 → 出牌被拒")

## 部署系统未注入 → 施法者判不出（-1），出牌仍转交（由系统侧决定）。
func test_bridge_without_deployment_passes_no_caster() -> void:
	# Arrange
	bridge.call(&"setup", combat, null)
	# Act
	bridge.call(&"play_card", 10, [])
	# Assert
	assert_eq(int(combat.calls[0]["caster_id"]), -1, "无阵位来源 → -1")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 生产入口：装配台的公开方法走同一条链路
# ═══════════════════════════════════════════════════════════════════════════════

## 装配台 play_card 把裁定结果交给战斗系统（生产接线的唯一入口）。
func test_stage_play_card_routes_through_bridge() -> void:
	# Arrange
	deployment.field = [_slot(201, 2, 0)]
	var stage: Node = StageScript.new()
	add_child_autofree(stage)
	stage.call(&"setup", combat, deployment, null, null)
	# Act
	var ok: bool = bool(stage.call(&"play_card", 11, [100000]))
	# Assert
	assert_true(ok, "出牌成功")
	assert_eq(int(combat.calls[0]["caster_id"]), 201, "装配台同样裁定施法者")

## 装配台的 current_caster_id 与桥一致（交互层查询用）。
func test_stage_exposes_current_caster_id() -> void:
	# Arrange
	deployment.field = [_empty_slot(0), _slot(202, 2, 1)]
	var stage: Node = StageScript.new()
	add_child_autofree(stage)
	stage.call(&"setup", combat, deployment, null, null)
	# Act / Assert
	assert_eq(int(stage.call(&"current_caster_id")), 202, "查询口径与出牌一致")
