extends GutTest
## 战场布局门面出牌入口集成测试（DEBT-CBT-018-10 第四阶段）。[br]
## [br][b]为什么单独测门面[/b]：`CombatLayout.play_card()` / `current_caster_id()`
## 是 combat-ui-interaction epic 将来直接调的两个入口，但现有测试只到
## `CombatActorStage` 层——门面自身的转发与「装配台缺失」早退分支从未被执行过。
## 门面多一层转发就该多一层绊线，否则交互层接入时才发现接错线。[br]
## [br][b]依赖注入[/b]：桩战斗系统 + 桩部署系统 + 真实 `CombatRoot.tscn`
## （`CombatLayout._init()` 会自建五个区域容器与装配台）。

const CombatRootScene: PackedScene = preload("res://src/ui/combat/layout/CombatRoot.tscn")


## 桩战斗系统——只实现 play_card（记录入参）。
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


var layout: Control = null
var combat: CombatStub = null
var deployment: DeploymentStub = null


func before_each() -> void:
	layout = CombatRootScene.instantiate()
	add_child_autofree(layout)
	combat = CombatStub.new()
	add_child_autofree(combat)
	deployment = DeploymentStub.new()
	add_child_autofree(deployment)
	deployment.field = [
		{"slot_index": 0, "character_id": 501, "is_front": true,
			"state": 1, "deploy_turn": 0},
	]
	# 门面的依赖注入入口——顺带把装配台的数据源接上（生产走同一条路径）。
	layout.call(&"setup_feedback", combat, deployment, Callable(), null, null, true)


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 门面转发：布局 → 装配台 → 出牌桥 → 战斗系统
# ═══════════════════════════════════════════════════════════════════════════════

## 布局出牌把裁定出的施法者一路带到战斗系统（交互层的唯一入口）。
func test_layout_play_card_routes_to_combat_with_caster() -> void:
	# Act
	var ok: bool = bool(layout.call(&"play_card", 42, [100001]))
	# Assert
	assert_true(ok, "出牌成功")
	assert_eq(combat.calls.size(), 1, "转交一次")
	assert_eq(int(combat.calls[0]["caster_id"]), 501, "施法者由阵位裁定")
	assert_eq(int(combat.calls[0]["card_instance_id"]), 42, "卡实例 ID 原样透传")
	assert_eq(combat.calls[0]["targets"], [100001], "目标列表原样透传")


## 门面 current_caster_id 与装配台一致（交互层查询用）。
func test_layout_current_caster_id_matches_stage() -> void:
	# Act / Assert
	assert_eq(int(layout.call(&"current_caster_id")), 501, "读到阵位首个存活角色")


## 装配台缺失（未装配 / 已释放）→ 出牌被拒且不崩，查询返回 NO_CASTER。
func test_layout_without_actor_stage_rejects_play() -> void:
	# Arrange——把装配台摘掉（模拟装配失败后的降级态）
	layout.set("actor_stage", null)
	# Act
	var ok: bool = bool(layout.call(&"play_card", 43, []))
	# Assert
	assert_false(ok, "无装配台 → 出牌被拒")
	assert_eq(int(layout.call(&"current_caster_id")), -1, "无装配台 → 不猜施法者")
	assert_eq(combat.calls.size(), 0, "被拒的请求不落到战斗系统")
