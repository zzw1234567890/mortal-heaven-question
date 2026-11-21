extends GutTest
## TribulationLaunch（渡劫入口共用件）单元测试 —— 纯逻辑，两个入口都走它。[br]
## [br][b]测的是哪几件事[/b]：[br]
##   · 顺序——先触发状态机、再请求转场（反过来就是「从地图进渡劫空打一场」那个 bug）；[br]
##   · 越阶判定单点——[code]CROSS_REALM[/code] 只在玩家主动选时才发（GDD §6 非默认路径）；[br]
##   · 失败收尾——转场缺失 / 被拒都必须把状态退回去，不留「渡劫流程进行中」的残局；[br]
##   · 可用性——半吊子系统按不可用处理（不让玩家点了没反应）。[br]
## [br][b]为什么不用真系统[/b]：本文件验的是「怎么组织调用顺序」，与状态机自身的规则
## 无关（那部分在 [code]tests/unit/tribulation_system/[/code] 其余文件与
## [code]tests/integration/exploration_ui/test_node_tribulation_entry.gd[/code]）。
## 替身只是为了能把「转场前状态是什么」摆成任意姿势。[br]
##
## 来源: design/gdd/tribulation-system.md §1/§2/§6、ADR-0021 §trigger_tribulation /
## §cancel_tribulation、ADR-0031 §2。

const LaunchScript := preload("res://src/feature/tribulation/tribulation_launch.gd")
const TS_SCRIPT := preload("res://src/feature/tribulation_system.gd")
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")


## 渡劫系统桩——记录调用顺序，[member reach_preparing] = false 时模拟状态机拒绝触发。
class TribStub extends Node:
	var calls: Array = []
	var reach_preparing: bool = true
	var state: int = 0

	func trigger_tribulation(trib_type: int) -> void:
		calls.append({"call": "trigger", "type": trib_type})
		if reach_preparing:
			state = 2  # TribulationState.PREPARING

	func get_tribulation_status() -> Dictionary:
		return {"state": state, "consecutive_failures": 0, "trib_type": 0}

	func cancel_tribulation() -> void:
		calls.append({"call": "cancel"})
		state = 0


## 场景管理器桩——记录请求，[member accept] = false 时模拟并发守卫拒绝。
class SceneStub extends Node:
	var requests: Array = []
	var accept: bool = true

	func get_current_scene_id() -> int:
		return SceneManagerScript.SceneID.EXPLORATION

	func request_scene_change(from: int, to: int, type: int) -> bool:
		requests.append({"from": from, "to": to, "type": type})
		return accept


## 半吊子渡劫系统（有对象、缺方法）。
class BareTrib extends Node:
	pass


var trib: TribStub = null
var sm: SceneStub = null


func before_each() -> void:
	trib = TribStub.new()
	sm = SceneStub.new()
	add_child_autofree(trib)
	add_child_autofree(sm)


# ═══════════════════════════════════════════════════════════════════════════════
# 顺序 —— 先触发、后转场
# ═══════════════════════════════════════════════════════════════════════════════

func test_launch_triggers_state_machine_before_requesting_scene() -> void:
	# Act
	var result: Dictionary = LaunchScript.launch(trib, sm,
			SceneManagerScript.SceneID.EXPLORATION)
	# Assert——每一步都发生了，且触发排在转场之前（本 bug 的现场）
	assert_true(bool(result.get("ok", false)), "正常路径应受理")
	assert_eq(trib.calls.size(), 1, "应触发一次渡劫状态机")
	assert_eq(str((trib.calls[0] as Dictionary)["call"]), "trigger",
			"第一次调用应是 trigger_tribulation")
	assert_eq(sm.requests.size(), 1, "应发出一次转场请求")
	assert_eq(trib.state, TS_SCRIPT.TribulationState.PREPARING,
			"转场前状态机必须已进 PREPARING")


func test_launch_uses_tribulation_transition_targeting_tribulation_scene() -> void:
	# Act
	LaunchScript.launch(trib, sm, SceneManagerScript.SceneID.EXPLORATION)
	# Assert——目标与过渡类型都取自 SceneManager 枚举
	assert_eq(int(sm.requests[0]["to"]), SceneManagerScript.SceneID.TRIBULATION,
			"目标场景应为渡劫场景")
	assert_eq(int(sm.requests[0]["type"]), SceneManagerScript.TransitionType.TRIBULATION,
			"过渡类型应为渡劫过渡")


func test_launch_prefers_live_scene_id_over_fallback() -> void:
	# Arrange——桩的实况是 EXPLORATION，兜底值故意传一个别的
	# Act
	LaunchScript.launch(trib, sm, SceneManagerScript.SceneID.CULTIVATION)
	# Assert——转场参数里的 from 取实况（两个入口各自的当前场景不同，兜底只是没有实况时的退路）
	assert_eq(int(sm.requests[0]["from"]), SceneManagerScript.SceneID.EXPLORATION,
			"from 应取 SceneManager 的实况而非调用方兜底值")


# ═══════════════════════════════════════════════════════════════════════════════
# 越阶判定单点
# ═══════════════════════════════════════════════════════════════════════════════

func test_tribulation_type_defaults_to_normal() -> void:
	assert_eq(LaunchScript.tribulation_type(false), TS_SCRIPT.TribulationType.NORMAL,
			"没人主动选越阶时发的必须是正常渡劫（GDD §6「非默认」）")


func test_tribulation_type_cross_realm_when_player_chose_it() -> void:
	assert_eq(LaunchScript.tribulation_type(true), TS_SCRIPT.TribulationType.CROSS_REALM,
			"玩家主动选越阶时才发 CROSS_REALM")


func test_launch_forwards_cross_realm_choice_to_state_machine() -> void:
	# Act——调用方透传玩家的越阶选择
	LaunchScript.launch(trib, sm, SceneManagerScript.SceneID.EXPLORATION, true)
	# Assert——状态机收到的就是越阶类型（判定只在共用件里做一次）
	assert_eq(int((trib.calls[0] as Dictionary)["type"]),
			TS_SCRIPT.TribulationType.CROSS_REALM, "越阶选择应原样透传给状态机")


# ═══════════════════════════════════════════════════════════════════════════════
# 失败收尾 —— 不留残余状态
# ═══════════════════════════════════════════════════════════════════════════════

func test_launch_without_scene_manager_cancels_tribulation() -> void:
	# Act——没有场景管理器
	var result: Dictionary = LaunchScript.launch(trib, null,
			SceneManagerScript.SceneID.EXPLORATION)
	# Assert——状态退回 + 可读原因（否则玩家永久卡在「渡劫流程进行中」）
	assert_false(bool(result.get("ok", false)), "无导航时不应报受理")
	assert_eq(StringName(str(result.get("outcome", &""))),
			LaunchScript.OUTCOME_NO_SCENE_MANAGER, "结果令牌应为场景管理器不可用")
	assert_eq(trib.state, TS_SCRIPT.TribulationState.NOT_READY,
			"去不了渡劫场景时必须把状态退回去")
	assert_eq(str(result.get("text", "")), LaunchScript.TEXT_NO_SCENE_MANAGER,
			"应给出可读的中文原因")


func test_launch_rejected_transition_cancels_tribulation() -> void:
	# Arrange——并发守卫拒掉转场
	sm.accept = false
	# Act
	var result: Dictionary = LaunchScript.launch(trib, sm,
			SceneManagerScript.SceneID.EXPLORATION)
	# Assert——同样退回，且令牌区分于「导航缺失」
	assert_false(bool(result.get("ok", false)), "转场被拒时不应报受理")
	assert_eq(StringName(str(result.get("outcome", &""))),
			LaunchScript.OUTCOME_DEPART_FAILED, "结果令牌应为转场被拒")
	assert_eq(trib.state, TS_SCRIPT.TribulationState.NOT_READY,
			"转场被拒后状态必须退回")
	assert_eq(str(result.get("text", "")), LaunchScript.TEXT_DEPART_FAILED,
			"应给出可读的中文原因")


func test_launch_when_state_machine_refuses_reports_busy_without_transition() -> void:
	# Arrange——状态机拒绝触发（修为未满 / 越阶越界都会这样）
	trib.reach_preparing = false
	# Act
	var result: Dictionary = LaunchScript.launch(trib, sm,
			SceneManagerScript.SceneID.EXPLORATION)
	# Assert——不谎报成功，也不转场（发「已前往渡劫」而其实没进流程是最坏的谎）
	assert_false(bool(result.get("ok", false)), "状态机拒绝时不得报受理")
	assert_eq(StringName(str(result.get("outcome", &""))), LaunchScript.OUTCOME_BUSY,
			"结果令牌应为流程进行中 / 未就绪")
	assert_eq(sm.requests.size(), 0, "状态没进 PREPARING 就不该请求转场")
	assert_eq(str(result.get("text", "")), LaunchScript.TEXT_BUSY,
			"应给出可读的中文原因")


# ═══════════════════════════════════════════════════════════════════════════════
# 可用性 —— 判的是能力不是存在
# ═══════════════════════════════════════════════════════════════════════════════

func test_usable_rejects_null_and_half_baked_system() -> void:
	assert_false(LaunchScript.usable(null), "null 应判不可用")
	var bare := BareTrib.new()
	add_child_autofree(bare)
	assert_false(LaunchScript.usable(bare), "有对象但没方法应判不可用")
	assert_true(LaunchScript.usable(trib), "齐备方法的系统应判可用")


func test_launch_with_unusable_system_does_not_touch_scene_manager() -> void:
	# Arrange
	var bare := BareTrib.new()
	add_child_autofree(bare)
	# Act
	var result: Dictionary = LaunchScript.launch(bare, sm,
			SceneManagerScript.SceneID.EXPLORATION)
	# Assert——不发转场、不报成功，给可读原因
	assert_false(bool(result.get("ok", false)), "系统不可用时不应报受理")
	assert_eq(StringName(str(result.get("outcome", &""))),
			LaunchScript.OUTCOME_TRIBULATION_UNAVAILABLE, "结果令牌应为渡劫系统不可用")
	assert_eq(sm.requests.size(), 0, "系统不可用时不得请求转场")
	assert_eq(str(result.get("text", "")), LaunchScript.TEXT_TRIBULATION_UNAVAILABLE,
			"应给出可读的中文原因")


func test_state_of_reads_not_ready_when_unavailable() -> void:
	# 读不到状态时按 NOT_READY 传（调用方已先过可用性——不会把它当成「可以点」）
	assert_eq(LaunchScript.state_of(null), TS_SCRIPT.TribulationState.NOT_READY,
			"系统缺席时状态应读作 NOT_READY")
	assert_eq(LaunchScript.state_of(trib), TS_SCRIPT.TribulationState.NOT_READY,
			"桩的初始状态为 NOT_READY")
