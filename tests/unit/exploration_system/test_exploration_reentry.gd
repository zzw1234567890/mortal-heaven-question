extends GutTest
## ExplorationReentry —— 已通关地图重入编排的判定与扣费（纯单测，无 Autoload）。[br]
## [br][b]本文件补的断链[/b]：[signal MapSelectScreen.reentry_requested] 此前全库
## 无消费者——确认传送既不扣费也不进图。本轮把落地编排收进
## [code]exploration_reentry.gd[/code]，本文件锁住它的三条不变量：[br]
##   1. [b]拒绝路径一律不扣费[/b]——系统不可用 / 未登记地图 / 尚未通关 / 不可重入 /
##      余额不足，全部在扣费之前返回；[br]
##   2. [b]拒绝结果不报「本该扣多少」[/b]——[code]cost[/code] 恒为 0，免得调用方
##      按它去扣一笔没发生的钱；[br]
##   3. [b]放行时扣的正好是经济公式给的数[/b]（本案用桩给出费用，真公式由集成用例盖）。[br]
## [br][b]为什么用桩而不是真实 Autoload[/b]：本模块只依赖三个窄接口
## （[code]calculate_reentry_cost[/code] / [code]map_states[/code] /
## [code]spend_resource[/code]），桩能把每条拒绝路径单独摆出来（真实系统里
## 「余额不足」要先造出正确次数与基价才能触发，测的就不再是判定顺序）。
## 真接线由 [code]test_clear_to_next_map_flow.gd[/code] 端到端盖。[br]
## [br][b]纯函数式静态类[/b]：本模块无实例状态，用例直接调静态方法，无需装置。
##
## 来源: design/gdd/exploration-system.md §1 地图重入消耗规则 / §公式 10、
## design/gdd/exploration-ui-system.md §1 重入确认弹窗、ADR-0014 §决策 4、ADR-0031 §2。

const Reentry := preload("res://src/feature/exploration/exploration_reentry.gd")

## 可重入的已通关地图（探明表未写 reentry_allowed = 缺省允许）。
const MAP: StringName = &"xue_yuan_mi_jing"
## 不可重入的剧情地图（探明表显式 false）。
const NO_REENTRY_MAP: StringName = &"cang_xuan_gu_zhan_chang"
## 只有历史写法、没有规范写法的地图 ID（别名表归一的目标是 sui_xing_wai_huan）。
const LEGACY_MAP: StringName = &"suixing_waihuan"
## 别名归一后的规范写法。
const LEGACY_CANONICAL: StringName = &"sui_xing_wai_huan"


## 探索系统桩——只暴露费用这一个接口（本模块唯一的依赖）。
class FakeExploration extends Node:
	var cost: int = 0

	func calculate_reentry_cost(_map_id: StringName) -> int:
		return cost


## 资源系统桩——可编程余额，扣费按真实语义（不足不扣并返回 false）。
class FakeResources extends Node:
	var ling_shi: int = 0
	## 被调用次数——「没扣就是没扣」的判据之一。
	var spend_calls: int = 0

	func get_resource(type: StringName) -> int:
		return ling_shi if type == &"ling_shi" else 0

	func spend_resource(type: StringName, amount: int) -> bool:
		spend_calls += 1
		if type != &"ling_shi" or amount > ling_shi:
			return false
		ling_shi -= amount
		return true


## 存档桩——只暴露 [code]exploration.map_states[/code] 这一处读取面。
class FakeGsm extends Node:
	var exploration: Dictionary = {}


var exploration: FakeExploration = null
var resources: FakeResources = null
var gsm: FakeGsm = null


func before_each() -> void:
	exploration = FakeExploration.new()
	resources = FakeResources.new()
	gsm = FakeGsm.new()
	add_child_autofree(exploration)
	add_child_autofree(resources)
	add_child_autofree(gsm)


func after_each() -> void:
	exploration = null
	resources = null
	gsm = null


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 放行 —— 扣费并给出实扣金额
# ═══════════════════════════════════════════════════════════════════════════════

func test_cleared_reenterable_map_with_enough_balance_is_allowed() -> void:
	# Arrange——已通关、可重入、余额充足（费用 60，余额 100）
	_clear(MAP)
	exploration.cost = 60
	resources.ling_shi = 100
	# Act
	var result: Dictionary = _enter(MAP)
	# Assert——放行 + 实扣 60 + 扣后余额 40
	assert_true(bool(result["ok"]), "已通关可重入且余额充足时应放行")
	assert_eq(int(result["cost"]), 60, "实扣金额应为经济公式给出的费用")
	assert_eq(int(result["balance"]), 40, "余额应为扣后值")
	assert_eq(resources.ling_shi, 40, "资源系统里的余额应真的少了 60")


func test_success_message_names_the_map_and_cost() -> void:
	# Arrange
	_clear(MAP)
	exploration.cost = 60
	resources.ling_shi = 100
	# Act
	var result: Dictionary = _enter(MAP)
	# Assert——文案写清「这是一次重入」与花了多少（与首次进入区分）
	assert_string_contains(str(result["message"]), "重入", "回报应说明这是一次重入")
	assert_string_contains(str(result["message"]), "60", "回报应含实扣金额")
	assert_string_contains(str(result["message"]), "血渊秘境", "回报应含地图中文名")


func test_free_reentry_still_goes_through_validation() -> void:
	## 0 费不等于免检：苍玄古战场若被当成「免费就放行」，剧情图会被重入。
	# Arrange——费用 0 但本图不可重入
	_clear(NO_REENTRY_MAP)
	exploration.cost = 0
	resources.ling_shi = 999
	# Act
	var result: Dictionary = _enter(NO_REENTRY_MAP)
	# Assert——照样被拒
	assert_false(bool(result["ok"]), "免费不豁免重入资格判定")
	assert_eq(str(result["reason"]), Reentry.REASON_NOT_REENTERABLE, "拒绝原因应为不可重入")
	assert_eq(resources.spend_calls, 0, "被拒时不应调一次扣费")


func test_zero_cost_reentry_does_not_call_spend() -> void:
	# Arrange——可重入 + 余额 0（0 费地图，例如永久免费图）
	_clear(MAP)
	exploration.cost = 0
	resources.ling_shi = 0
	# Act
	var result: Dictionary = _enter(MAP)
	# Assert——放行，且没有走一次「扣 0」的空扣费
	assert_true(bool(result["ok"]), "0 费重入应放行")
	assert_eq(int(result["cost"]), 0, "0 费重入的实扣金额为 0")
	assert_eq(resources.spend_calls, 0, "0 费不应触发扣费调用")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 拒绝路径 —— 一律不扣费
# ═══════════════════════════════════════════════════════════════════════════════

func test_insufficient_balance_is_rejected_before_any_spend() -> void:
	# Arrange——费用 60，余额 10
	_clear(MAP)
	exploration.cost = 60
	resources.ling_shi = 10
	# Act
	var result: Dictionary = _enter(MAP)
	# Assert——拒绝，且[b]没有发生过扣费[/b]（余额原样）
	assert_false(bool(result["ok"]), "余额不足应拒绝")
	assert_eq(str(result["reason"]), Reentry.REASON_NO_LING_SHI, "拒绝原因应为灵石不足")
	assert_eq(int(result["cost"]), 0, "被拒时 cost 恒为 0——不报一个没发生的数字")
	assert_eq(resources.ling_shi, 10, "被拒时余额不应变化")
	assert_eq(resources.spend_calls, 0, "余额预判失败时不该再调一次扣费")
	assert_string_contains(str(result["message"]), "10", "提示应带上当前余额")


func test_exact_balance_is_accepted() -> void:
	# Arrange——余额恰好等于费用（边界：够就是够）
	_clear(MAP)
	exploration.cost = 60
	resources.ling_shi = 60
	# Act
	var result: Dictionary = _enter(MAP)
	# Assert
	assert_true(bool(result["ok"]), "余额恰好够时应放行（边界含等号）")
	assert_eq(resources.ling_shi, 0, "扣后余额为 0")


func test_uncleared_map_is_rejected() -> void:
	# Arrange——本图没有任何通关记录
	exploration.cost = 60
	resources.ling_shi = 999
	# Act
	var result: Dictionary = _enter(MAP)
	# Assert——没通关就该直接进（走首次进入路径），不该走重入
	assert_false(bool(result["ok"]), "未通关地图不应走重入")
	assert_eq(str(result["reason"]), Reentry.REASON_NOT_CLEARED, "拒绝原因应为尚未通关")
	assert_eq(int(result["cost"]), 0, "被拒时 cost 为 0")
	assert_eq(resources.spend_calls, 0, "被拒时不应扣费")


func test_non_reenterable_map_is_rejected_at_any_balance() -> void:
	# Arrange——剧情图已通关，余额充足
	_clear(NO_REENTRY_MAP)
	exploration.cost = 60
	resources.ling_shi = 99999
	# Act
	var result: Dictionary = _enter(NO_REENTRY_MAP)
	# Assert
	assert_false(bool(result["ok"]), "苍玄古战场通关后不可重入（GDD §8）")
	assert_eq(str(result["reason"]), Reentry.REASON_NOT_REENTERABLE, "拒绝原因应为不可重入")
	assert_string_contains(str(result["message"]), "苍玄古战场", "提示应点名是哪张图")


func test_unknown_map_is_rejected() -> void:
	# Arrange——探明表里没有的 ID
	resources.ling_shi = 999
	# Act
	var result: Dictionary = _enter(&"not_a_registered_map")
	# Assert
	assert_false(bool(result["ok"]), "未登记地图应拒绝")
	assert_eq(str(result["reason"]), Reentry.REASON_UNKNOWN_MAP, "拒绝原因应为未知地图")


func test_missing_system_dependencies_are_rejected() -> void:
	# Arrange——本图已通关（否则会先撞上「尚未通关」，测不到依赖缺失这几条）
	_clear(MAP)
	# Act / Assert——三种依赖各缺一个都不该崩，且各自有独立的原因词
	var no_system: Dictionary = Reentry.enter(MAP, null, gsm, resources)
	assert_eq(str(no_system["reason"]), Reentry.REASON_NO_SYSTEM, "无探索系统应拒绝")
	var no_gsm: Dictionary = Reentry.enter(MAP, exploration, null, resources)
	assert_eq(str(no_gsm["reason"]), Reentry.REASON_NO_GSM, "无存档应拒绝")
	var no_res: Dictionary = Reentry.enter(MAP, exploration, gsm, null)
	assert_eq(str(no_res["reason"]), Reentry.REASON_NO_RESOURCE, "无资源系统应拒绝")
	for result: Dictionary in [no_system, no_gsm, no_res]:
		assert_eq(int(result["cost"]), 0, "依赖缺失时 cost 为 0")


func test_rejection_shape_is_uniform() -> void:
	## 调用方按同一形状读结果——缺键会让「拒绝」在界面上变成一次静默的空操作。
	# Act
	var result: Dictionary = _enter(&"not_a_registered_map")
	# Assert
	for key: String in ["ok", "reason", "message", "cost", "balance", "map_id"]:
		assert_true(result.has(key), "拒绝结果应含键 %s" % key)
	assert_false(str(result["message"]).is_empty(), "拒绝时必须给得出面向玩家的文案")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 别名归一 —— 历史写法与规范写法等价
# ═══════════════════════════════════════════════════════════════════════════════

func test_legacy_map_id_is_canonicalized_before_lookup() -> void:
	# Arrange——存档里按规范写法记，调用方给历史写法
	_clear(LEGACY_CANONICAL)
	exploration.cost = 0
	resources.ling_shi = 0
	# Act
	var result: Dictionary = _enter(LEGACY_MAP)
	# Assert——归一后才查得到通关记录（不归一的话这里会误报「尚未通关」）
	assert_true(bool(result["ok"]), "历史写法应能查到同一张图的通关记录")
	assert_eq(StringName(str(result["map_id"])), LEGACY_CANONICAL,
			"返回的地图 ID 应为规范写法")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 只读查询
# ═══════════════════════════════════════════════════════════════════════════════

func test_reentry_allowed_defaults_to_true_for_registered_map() -> void:
	assert_true(Reentry.reentry_allowed(MAP), "探明表未写 reentry_allowed 时缺省允许")
	assert_false(Reentry.reentry_allowed(NO_REENTRY_MAP), "显式 false 的图不允许重入")


func test_display_name_falls_back_to_map_id() -> void:
	assert_eq(Reentry.display_name(MAP), "血渊秘境", "已登记地图给中文名")
	assert_eq(Reentry.display_name(&"not_a_registered_map"), "not_a_registered_map",
			"未登记地图回退地图 ID——不臆造名字")


func test_balance_of_unknown_system_is_zero() -> void:
	assert_eq(Reentry.balance_of(null), 0, "资源系统缺失时余额按 0（不臆造）")


func test_map_state_reads_gsm_map_states() -> void:
	# Arrange
	_clear(MAP)
	# Act / Assert
	assert_true(bool(Reentry.map_state(gsm, MAP).get("is_first_clear", false)),
			"应读到 GSM 里的通关标记")
	assert_eq(Reentry.map_state(gsm, &"other_map"), {}, "没有记录的图给空字典")


func test_map_state_tolerates_malformed_storage() -> void:
	# Arrange——结构不对的存档（不崩、按无记录处理）
	gsm.exploration = {"map_states": "不是字典"}
	assert_eq(Reentry.map_state(gsm, MAP), {}, "map_states 结构不对时按空处理")
	gsm.exploration = {}
	assert_eq(Reentry.map_state(gsm, MAP), {}, "缺 map_states 键时按空处理")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 调一次重入（三个桩已由 [method before_each] 备好）。
func _enter(p_map_id: StringName) -> Dictionary:
	return Reentry.enter(p_map_id, exploration, gsm, resources)


## 把某图标为已通关（写进桩存档的 [code]map_states[/code]）。
func _clear(p_map_id: StringName) -> void:
	var states: Dictionary = gsm.exploration.get("map_states", {})
	states[p_map_id] = {"is_first_clear": true, "clear_count": 1, "entry_count": 1}
	gsm.exploration["map_states"] = states
