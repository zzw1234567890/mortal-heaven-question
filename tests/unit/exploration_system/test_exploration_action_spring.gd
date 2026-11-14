extends GutTest
## 行动力泉（灵泉）节点结算单元测试。[br]
## [br][b]覆盖[/b]：[br]
##   - 公式 [code]restore_for[/code]：回复量 = 上限 - 当前，夹到 [0, 上限]；[br]
##   - 结算 [code]use_action_spring[/code]：真的写 GSM 行动力、写到上限为止、[br]
##     已满时不写状态、GSM 不可用/缺写入口时返回 0 并告警；[br]
##   - 与 UI 侧期望值同源：[code]NodeInteractionRules.spring_restore_all[/code]
##     转发到本模块的公式（两侧不会各算一套）。[br]
## [br][b]隔离[/b]：GSM 的 exploration 域在 [code]before_each[/code] 快照、
## [code]after_each[/code] 原样还原。[br]
##
## 来源: GDD exploration-system.md §节点类型一览（回复全部行动力）+ §8 边界、
## design/gdd/exploration-ui-system.md §4 灵泉弹窗（AC-4）。

const SPRING_SCRIPT := preload("res://src/feature/exploration/exploration_action_spring.gd")
const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
const Rules := preload("res://src/ui/exploration/node_interaction_rules.gd")

## 灵泉节点 ID（结算不使用，仅透传日志——对齐探索系统的节点 API 口径）。
const SPRING_NODE: int = 203

var es: Node = null
var _exploration_before: Dictionary = {}


func before_each() -> void:
	_exploration_before = (GameStateManager.exploration as Dictionary).duplicate(true)
	GameStateManager.exploration = {
		"current_map": &"",
		"node_position": {"layer": 0, "idx": 0},
		"visited_nodes": [],
		"action_points": 0,
		"max_action_points": 0,
		"map_states": {},
	}
	es = ES_SCRIPT.new()


func after_each() -> void:
	GameStateManager.exploration = _exploration_before
	if es != null:
		es.free()
		es = null


# ═══════════════════════════════════════════════════════════════════════════════
# 公式（纯函数——不读不写状态）
# ═══════════════════════════════════════════════════════════════════════════════

func test_restore_for_equals_missing_points() -> void:
	assert_eq(SPRING_SCRIPT.restore_for(0, 7), 7, "空行动力 → 回复全部 7 点")
	assert_eq(SPRING_SCRIPT.restore_for(3, 7), 4, "3/7 → 回复 4 点")
	assert_eq(SPRING_SCRIPT.restore_for(7, 7), 0, "已满 → 回复 0 点")
	assert_eq(SPRING_SCRIPT.restore_for(9, 7), 0, "越界（超上限）→ 不产生负回复")


func test_restore_for_handles_degenerate_inputs() -> void:
	assert_eq(SPRING_SCRIPT.restore_for(-3, 7), 7, "负数行动力按 0 处理（回复全量）")
	assert_eq(SPRING_SCRIPT.restore_for(0, 0), 0, "无上限可回 → 0（不臆造）")
	assert_eq(SPRING_SCRIPT.restore_for(5, -1), 0, "负上限 → 0（不臆造）")


func test_ui_expectation_forwards_to_same_formula() -> void:
	# UI 侧的 spring_restore_all 是交叉校验用的期望值——必须与实现同源
	for pair: Array in [[0, 7], [3, 7], [7, 7], [9, 7], [2, 13], [13, 13]]:
		assert_eq(Rules.spring_restore_all(int(pair[0]), int(pair[1])),
				SPRING_SCRIPT.restore_for(int(pair[0]), int(pair[1])),
				"UI 期望值与实现公式应一致（%s）" % str(pair))


# ═══════════════════════════════════════════════════════════════════════════════
# 结算（真的写 GSM）
# ═══════════════════════════════════════════════════════════════════════════════

func test_spring_restores_action_points_to_max() -> void:
	GameStateManager.exploration.action_points = 2
	GameStateManager.exploration.max_action_points = 7
	var restored: int = int(es.call(&"use_action_spring", SPRING_NODE))
	assert_eq(restored, 5, "2/7 → 应回复 5 点")
	assert_eq(int(GameStateManager.exploration.action_points), 7,
			"结算后行动力应达到上限")
	assert_eq(int(GameStateManager.exploration.max_action_points), 7,
			"上限不应被写坏")


func test_spring_from_zero_restores_full_cap() -> void:
	GameStateManager.exploration.action_points = 0
	GameStateManager.exploration.max_action_points = 7
	assert_eq(int(es.call(&"use_action_spring", SPRING_NODE)), 7, "0/7 → 回复 7 点")
	assert_eq(int(GameStateManager.exploration.action_points), 7, "应填满")


func test_spring_never_exceeds_cap() -> void:
	# 越界存档值（超过上限）不得被放大，也不得倒扣
	GameStateManager.exploration.action_points = 99
	GameStateManager.exploration.max_action_points = 7
	assert_eq(int(es.call(&"use_action_spring", SPRING_NODE)), 0,
			"超上限存档不产生回复量")
	assert_eq(int(GameStateManager.exploration.action_points), 99,
			"已满时不应写状态（原值原样保留）")


func test_spring_at_full_cap_writes_nothing() -> void:
	GameStateManager.exploration.action_points = 7
	GameStateManager.exploration.max_action_points = 7
	assert_eq(int(es.call(&"use_action_spring", SPRING_NODE)), 0, "满行动力 → 0")
	assert_eq(int(GameStateManager.exploration.action_points), 7, "原值不动")


func test_spring_without_write_entry_warns_and_reports_zero() -> void:
	# GSM 缺写入口（降级）——宁可返回 0 也不虚报回复量
	var fake_gsm: Node = Node.new()
	add_child_autofree(fake_gsm)
	var stub: Node = _StubParent.new(fake_gsm)
	add_child_autofree(stub)
	var orphan: RefCounted = SPRING_SCRIPT.new(stub)
	assert_eq(int(orphan.call(&"use_action_spring", SPRING_NODE)), 0,
			"GSM 缺 set_exploration_ap 时应返回 0")
	assert_push_warning("GSM 缺少 set_exploration_ap")


func test_spring_without_gsm_warns_and_reports_zero() -> void:
	var stub: Node = _StubParent.new(null)
	add_child_autofree(stub)
	var orphan: RefCounted = SPRING_SCRIPT.new(stub)
	assert_eq(int(orphan.call(&"use_action_spring", SPRING_NODE)), 0,
			"GSM 不可用时应返回 0")
	assert_push_warning("GSM 不可用")


## 桩父节点——只回答 [code]_get_gsm()[/code]，用于「GSM 缺失 / 能力缺失」的降级路径。
class _StubParent extends Node:
	var _gsm_ref: Node = null
	func _init(p_gsm: Node = null) -> void:
		_gsm_ref = p_gsm
	func _get_gsm() -> Node:
		return _gsm_ref as Node
