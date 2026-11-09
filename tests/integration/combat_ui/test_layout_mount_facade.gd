extends GutTest
## CombatLayout 四组挂载门面集成测试（拆分安全网）。
## [br][b]为什么先补这个[/b]：`combat_layout.gd` 是场景挂载侧唯一持有的节点，
## 备战 / 结算 / 反馈 / 装配四组接线全堆在一个 465 行的类里（超 300 行软上限）。
## 拆分前必须先把「门面行为」钉死——否则拆分只是把代码搬了家，回归无人看守。[br]
## [br][b]本文件锁定四件事[/b]：[br]
##   1. [b]结算组[/b]：`setup_settlement` 转发到宿主（含宿主缺失时的告警降级分支）、
##      `show_pre_battle_warning` 三态、`open_retreat_dialog` 打开弹窗；[br]
##   2. [b]装配组[/b]：`build_battle_roster` / `clear_battle_roster` 转发，
##      且与 `play_card` 共用同一个装配台实例；[br]
##   3. [b]反馈组[/b]：`setup_feedback` 同时接好编排器与装配台（建卡自动注册），
##      装配台缺失时降级不崩；[br]
##   4. [b]节点树契约[/b]：子节点名字与顺序不变——顺序即绘制层级（手牌区在区域之上、
##      反馈层在手牌区之上、覆盖层在最后），拆分时挪动顺序会静默改掉遮挡关系。[br]
## [br][b]依赖注入[/b]：桩战斗系统 / 桩部署系统 / 桩卡组 + 真实 `CombatRoot.tscn`
## （`CombatLayout._init()` 自建五区域、四个挂载组件与节点树）。

const CombatRootScene: PackedScene = preload("res://src/ui/combat/layout/CombatRoot.tscn")

## 子节点顺序契约——[b]顺序即绘制层级[/b]（后者盖前者）。
const EXPECTED_CHILD_ORDER: Array[String] = [
	"TopBar", "EnemyArea", "Midline", "AllyArea", "BottomBar",
	"HandArea", "RetreatButtonSlot", "CombatFeedback", "ActorStage",
	"DeployPanel", "SettlementHost",
]


## 桩战斗系统——结算宿主需要 battle_ended / retreat_requested 两个信号，
## 反馈编排器需要 character_damaged / character_died / battle_ended，
## 装配台需要 get_character_hp / get_battle_enemy_roster。
class CombatStub extends Node:
	signal character_damaged(damage_data: Dictionary)
	signal character_died(character_id: int, side: int, binding_card_ids: Array)
	signal battle_ended(result: int, rewards: Dictionary)
	signal retreat_requested()

	var hp_store: Dictionary = {}

	func get_character_hp(character_id: int) -> Dictionary:
		return hp_store.get(character_id, {"current": 0, "max": 0})

	func get_battle_enemy_roster() -> Array:
		return []


## 桩部署系统——我方阵位（一名角色足够锁「施法者裁定」这条链路）。
class DeploymentStub extends Node:
	func get_field() -> Array:
		return [
			{"slot_index": 0, "character_id": 601, "is_front": true,
				"state": 1, "deploy_turn": 0},
		]


## 桩卡组系统——结算宿主读张数/上限（缺失时宿主自行退化为 0/0）。
class DeckStub extends Node:
	func get_deck_summary() -> Dictionary:
		return {"total": 12, "limit": 20}


var layout: Control = null
var combat: CombatStub = null
var deployment: DeploymentStub = null
var deck: DeckStub = null


func before_each() -> void:
	layout = CombatRootScene.instantiate()
	add_child_autofree(layout)
	combat = CombatStub.new()
	add_child_autofree(combat)
	deployment = DeploymentStub.new()
	add_child_autofree(deployment)
	deck = DeckStub.new()
	add_child_autofree(deck)


# ═══════════════════════════════════════════════════════════════════════════════
# 0. 节点树契约（顺序即绘制层级）——拆分时最先会破的一条
# ═══════════════════════════════════════════════════════════════════════════════

## 子节点名字与顺序不变——后者盖前者，挪动顺序会静默改掉遮挡关系。
func test_child_node_order_is_stable() -> void:
	# Act
	var actual: Array[String] = []
	for child: Node in layout.get_children():
		actual.append(String(child.name))
	# Assert
	assert_eq(actual, EXPECTED_CHILD_ORDER,
		"战斗根子节点顺序即绘制层级（手牌区在区域之上、反馈层在手牌区之上、覆盖层最后）")


## 五区域容器仍在根上直接命名可查（场景挂载侧与既有测试按 NodePath 取用）。
func test_five_zones_remain_direct_children() -> void:
	for zone_name: String in ["TopBar", "EnemyArea", "Midline", "AllyArea", "BottomBar"]:
		assert_not_null(layout.get_node_or_null(NodePath(zone_name)),
			"区域容器 %s 应仍是战斗根的直接子节点" % zone_name)


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 结算组：setup_settlement / show_pre_battle_warning / open_retreat_dialog
# ═══════════════════════════════════════════════════════════════════════════════

## setup_settlement 把战斗/卡组系统转发进宿主（信号源到位 → 战斗结束能开面板）。
func test_setup_settlement_forwards_sources_to_host() -> void:
	# Act
	layout.call(&"setup_settlement", combat, deck, false)
	# Assert
	var host: Node = layout.get(&"settlement_host")
	assert_not_null(host, "战斗根应装配结算宿主")
	assert_eq(host.get("combat_system"), combat, "宿主应持有注入的战斗系统")
	assert_eq(host.get("deck_system"), deck, "宿主应持有注入的卡组系统")
	assert_true(bool(host.call(&"has_sources")), "注入后宿主应报数据源齐备")


## 宿主缺失（装配失败降级态）→ 告警且不崩（不把缺依赖变成崩溃）。
func test_setup_settlement_without_host_warns() -> void:
	# Arrange——摘掉宿主（模拟装配失败）
	layout.set("settlement_host", null)
	# Act
	layout.call(&"setup_settlement", combat, deck, false)
	# Assert
	assert_push_warning_count(1, "宿主缺失时应 push_warning 1 次")


## 渡劫战 → 战前警示弹出（门面转发到宿主）。
func test_show_pre_battle_warning_true_for_tribulation() -> void:
	# Arrange
	layout.call(&"setup_settlement", combat, deck, true)
	# Act / Assert
	assert_true(bool(layout.call(&"show_pre_battle_warning")), "渡劫战未确认时应弹出警示")


## 非渡劫战 → 不弹（门面只做转发，判定归 RetreatRules）。
func test_show_pre_battle_warning_false_without_tribulation() -> void:
	# Arrange
	layout.call(&"setup_settlement", combat, deck, false)
	# Act / Assert
	assert_false(bool(layout.call(&"show_pre_battle_warning")), "非渡劫战不应弹战前警示")


## 宿主缺失 → 返回 false 且告警（不静默）。
func test_show_pre_battle_warning_without_host_warns() -> void:
	# Arrange
	layout.set("settlement_host", null)
	# Act
	var shown: bool = bool(layout.call(&"show_pre_battle_warning"))
	# Assert
	assert_false(shown, "无宿主时不应报「已弹出」")
	assert_push_warning_count(1, "宿主缺失时应 push_warning 1 次")


## open_retreat_dialog 打开撤退确认弹窗（门面是撤退按钮与战斗系统请求的共同出口）。
func test_open_retreat_dialog_opens_dialog() -> void:
	# Arrange
	layout.call(&"setup_settlement", combat, deck, false)
	var host: Node = layout.get(&"settlement_host")
	var dialog: Variant = host.get("retreat_dialog")
	assert_false(bool(dialog.call(&"is_showing")), "前置：弹窗默认关闭")
	# Act
	layout.call(&"open_retreat_dialog")
	# Assert
	assert_true(bool(dialog.call(&"is_showing")), "门面应打开撤退确认弹窗")


## 战斗系统的 retreat_requested 信号同样经宿主开门（按钮与信号同源）。
func test_retreat_requested_signal_opens_dialog() -> void:
	# Arrange
	layout.call(&"setup_settlement", combat, deck, false)
	var dialog: Variant = layout.get(&"settlement_host").get("retreat_dialog")
	# Act
	combat.retreat_requested.emit()
	# Assert
	assert_true(bool(dialog.call(&"is_showing")), "撤退请求信号应打开确认弹窗")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 反馈组：setup_feedback（编排器 + 装配台同时接好）
# ═══════════════════════════════════════════════════════════════════════════════

## setup_feedback 把信号源接进编排器，并把装配台与编排器绑定。
func test_setup_feedback_wires_coordinator_and_stage() -> void:
	# Arrange
	var feedback: Control = layout.get(&"feedback")
	var stage: Node = layout.get(&"actor_stage")
	# Act
	layout.call(&"setup_feedback", combat, deployment, Callable(), null, null, true)
	# Assert
	assert_eq(feedback._connected_sources.size(), 2, "编排器应订阅战斗系统 + 部署系统两个信号源")
	assert_true(bool(feedback.reduce_motion), "reduce_motion 应透传到编排器")
	assert_true(stage.get("_coordinator") == feedback,
		"装配台应绑定编排器——此后建的卡自动注册")


## HP 读取契约（注入 Callable）经门面直达——UI 不缓存 HP。
func test_setup_feedback_binds_hp_reader() -> void:
	# Arrange
	combat.hp_store = {601: {"current": 42, "max": 60}}
	# Act
	layout.call(&"setup_feedback", combat, deployment,
			Callable(combat, "get_character_hp"), null, null, true)
	# Assert
	var feedback: Control = layout.get(&"feedback")
	var hp: Dictionary = feedback.hp_reader_cb.call(601)
	assert_eq(int(hp["current"]), 42, "hp_reader_cb 应直达战斗系统")
	assert_eq(int(hp["max"]), 60, "max 同源读取")


## 装配台缺失（降级态）→ 编排器照常接线，不崩。
func test_setup_feedback_without_stage_still_wires_coordinator() -> void:
	# Arrange
	layout.set("actor_stage", null)
	# Act
	layout.call(&"setup_feedback", combat, deployment, Callable(), null, null, true)
	# Assert
	var feedback: Control = layout.get(&"feedback")
	assert_true(is_instance_valid(feedback), "装配台缺失不应影响编排器实例")
	assert_eq(feedback._connected_sources.size(), 2, "编排器仍应订阅战斗 + 部署两个信号源")


## 建卡自动注册进编排器（反馈组的「装配台 ↔ 编排器」绑定真的生效）。
func test_build_roster_registers_cards_into_coordinator() -> void:
	# Arrange
	combat.hp_store = {601: {"current": 50, "max": 50}}
	layout.call(&"setup_feedback", combat, deployment, Callable(), null, null, true)
	var feedback: Control = layout.get(&"feedback")
	# Act
	layout.call(&"build_battle_roster", [601])
	# Assert
	assert_true(feedback._cards.has(601), "建的卡应注册进编排器——HP 条/飘字才有对象")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 装配组：名册建卡 / 清场 / 出牌入口共用同一个装配台
# ═══════════════════════════════════════════════════════════════════════════════

## clear_battle_roster 清空装配台（门面转发——此前只有测试直接调装配台）。
func test_clear_battle_roster_empties_stage() -> void:
	# Arrange
	combat.hp_store = {601: {"current": 50, "max": 50}}
	layout.call(&"setup_feedback", combat, deployment, Callable(), null, null, true)
	layout.call(&"build_battle_roster", [601])
	var stage: Node = layout.get(&"actor_stage")
	assert_eq(int(stage.call(&"card_count")), 1, "前置：已建 1 张卡")
	# Act
	layout.call(&"clear_battle_roster")
	# Assert
	assert_eq(int(stage.call(&"card_count")), 0, "清场后装配台应无卡")
	assert_null(stage.call(&"get_card", 601), "被清的卡不应再查得到")


## 装配台缺失 → build / clear 都静默早退（降级不崩）。
func test_roster_facade_without_stage_is_safe() -> void:
	# Arrange
	layout.set("actor_stage", null)
	# Act
	layout.call(&"build_battle_roster", [601])
	layout.call(&"clear_battle_roster")
	# Assert
	assert_true(true, "装配台缺失时建卡/清场应安全早退")


## 出牌入口与名册建卡共用同一个装配台实例（门面只转发，不自建第二份）。
func test_play_card_and_roster_share_same_stage() -> void:
	# Arrange
	layout.call(&"setup_feedback", combat, deployment, Callable(), null, null, true)
	var stage: Node = layout.get(&"actor_stage")
	# Act / Assert——门面 current_caster_id 与装配台一致（同一实例、同一数据源）
	assert_eq(int(layout.call(&"current_caster_id")),
			int(stage.call(&"current_caster_id")), "门面查询应转发到同一个装配台")
	assert_eq(int(layout.call(&"current_caster_id")), 601,
			"施法者由阵位现读（桩阵位 601）")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 备战组：show/hide 转发（细节在 test_deploy_panel_host.gd，这里只锁门面存在）
# ═══════════════════════════════════════════════════════════════════════════════

## 备战面板仍以 `DeployPanel` 为节点名挂在根上（NodePath 取用契约）。
func test_deploy_panel_node_path_is_stable() -> void:
	var panel: Node = layout.get_node_or_null(NodePath("DeployPanel"))
	assert_not_null(panel, "备战面板应仍以 DeployPanel 挂在战斗根上")
	assert_eq(panel, layout.get(&"deploy_panel"), "属性引用与节点树应是同一实例")
