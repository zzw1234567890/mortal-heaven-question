extends "res://tests/integration/exploration_ui/shop_rest_node_fixture.gd"
## 灵泉节点的端到端交互 —— 「确认之后」那一段的真实链路。[br]
## [br][b]本文件补的断链[/b]：灵泉此前有两处断路——弹窗宿主确认时调的
## [code]ExplorationSystem.use_action_spring[/code] 并不存在（宿主 push_warning
## 后返回 0），而且 [code]ShopNodePresenter[/code] 也没有
## [code]spring_used[/code] 的消费方（连提示都没有）。本文件走「到达灵泉 →
## 弹窗确认 → 系统结算 → 提示回填」的完整链路，断言「确认之后行动力真的回满了」。[br]
## [br][b]覆盖[/b]（本轮任务点名的断言）：[br]
##   1. 到达灵泉 → 弹窗确认 → 行动力回复到上限（不是只弹了个框）；[br]
##   2. 回复量[b]不超上限[/b]——差多少回多少，越界存档值不被放大；[br]
##   3. 已满时回复 0 且状态原样不动，提示走「已满」文案（不显示「回复 0 点」）。[br]
## [br][b]用真实探索系统实例[/b]（夹具注入）+ 真实 GSM：AP 的读写都经 GSM 的
## 第二层原子方法，断言的就是「玩家数据变了」。[br]
## [br]装置（场景搭建、存档快照还原）见 [code]shop_rest_node_fixture.gd[/code]；
## 本文件自己多快照一份 GSM 探索域（灵泉写的就是它）。[br]
##
## 来源: GDD exploration-system.md §节点类型一览 / §8 边界、
## design/gdd/exploration-ui-system.md §4 灵泉弹窗（AC-4）、ADR-0031 §2、
## 本轮「灵泉节点最小可用交互」任务。

## 灵泉节点 ID（结算不使用，仅日志透传——与探索系统的节点 API 口径一致）。
const SPRING_NODE: int = 203

## 玩家当前能力值（用例按需改写）。
const START_AP: int = 2
const MAX_AP: int = 10

var _exploration_before: Dictionary = {}


func before_each() -> void:
	super.before_each()
	_exploration_before = (GameStateManager.exploration as Dictionary).duplicate(true)


func after_each() -> void:
	GameStateManager.exploration = _exploration_before
	super.after_each()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 确认 → 回满行动力
# ═══════════════════════════════════════════════════════════════════════════════

func test_spring_confirm_restores_action_points_to_max() -> void:
	# Arrange——2/10
	_set_ap(START_AP, MAX_AP)
	# Act——到达灵泉 → 点确认
	_reach(SPRING_NODE, &"action_spring", {})
	_confirm()
	# Assert——行动力真的回到上限，提示里的回复量与实际一致
	assert_eq(_ap(), MAX_AP, "确认后行动力应达到上限")
	assert_eq(_hinted_amount(), MAX_AP - START_AP,
			"提示里的回复量应为缺口（%d）" % (MAX_AP - START_AP))
	assert_true(str(_presenter().call(&"last_hint")).contains("行动力"),
			"应给出一句行动力相关的中文提示")


func test_spring_from_zero_restores_full_cap() -> void:
	# Arrange——行动力见底
	_set_ap(0, MAX_AP)
	# Act
	_reach(SPRING_NODE, &"action_spring", {})
	_confirm()
	# Assert
	assert_eq(_ap(), MAX_AP, "空行动力应回满")
	assert_eq(_hinted_amount(), MAX_AP, "回复量应等于上限")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 不超上限
# ═══════════════════════════════════════════════════════════════════════════════

func test_spring_never_exceeds_cap_when_already_full() -> void:
	# Arrange——已满
	_set_ap(MAX_AP, MAX_AP)
	# Act
	_reach(SPRING_NODE, &"action_spring", {})
	_confirm()
	# Assert——不动状态，且提示走「已满」而不是「回复 0 点」
	assert_eq(_ap(), MAX_AP, "已满时不应把行动力写坏")
	assert_eq(_hinted_amount(), 0, "已满时提示里不应出现回复量")
	assert_true(str(_presenter().call(&"last_hint")).contains("已满"),
			"已满应给「行动力已满」而不是「回复 0 点」")


func test_spring_clamps_oversized_save_value() -> void:
	# Arrange——越界存档值（AP > 上限，例如旧存档或调试改档）
	_set_ap(MAX_AP + 5, MAX_AP)
	# Act
	_reach(SPRING_NODE, &"action_spring", {})
	_confirm()
	# Assert——不回退也不放大：away 值原样留着，回复量为 0
	assert_eq(_ap(), MAX_AP + 5, "越界存档值不应被灵泉倒扣或抬高")
	assert_eq(_hinted_amount(), 0, "超上限时不产生回复量")


func test_spring_uses_max_ap_from_save() -> void:
	# 上限不是写死的 10——换成 7 也要恰好回满到 7（数据驱动）
	_set_ap(1, 7)
	_reach(SPRING_NODE, &"action_spring", {})
	_confirm()
	assert_eq(_ap(), 7, "应按存档里的行动力上限回满")
	assert_eq(_hinted_amount(), 6, "回复量应为实测缺口")


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 写当前行动力与上限（走 GSM 第二层原子方法——与生产同一条写入口）。
func _set_ap(p_current: int, p_max: int) -> void:
	GameStateManager.call(&"set_exploration_ap", p_current, p_max)


## 读当前行动力。
func _ap() -> int:
	return int(GameStateManager.exploration.get("action_points", -1))
