extends GutTest
## 新游戏必须走身份选择流程（2026-11-27 听风报的 bug 的回归钉子）。
##
## [b]bug[/b]：玩家从游戏里退回主菜单、再点「新游戏」，身份选择场景挂载时读到
## [code]is_identity_selected()[/code] 为真（同一进程里刚选过），于是一路跳过选择 UI
## 直接奔探索——表现成「点新游戏直接跳到选地图」。
## [b]修法[/b]：主菜单点新游戏时落一份一次性意图（[code]IdentitySelectIntent[/code]），
## 身份选择场景 [code]_ready[/code] 先消费它，命中就无条件渲染选择 UI。
##
## 本文件钉两条：① 有意图 ⇒ 不跳过、渲染 UI、不发转场；② 无意图 ⇒ 照旧跳过并请求转场
## （读档路径不能被改坏）。意图是一次性的——取走即清。

const ScreenScene: PackedScene = preload("res://src/ui/identity_select/identity_select.tscn")
const IntentScript := preload("res://src/ui/identity_select/identity_select_intent.gd")
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")

var _sm: Node = null
var _isys: Node = null


## SceneManager 替身：记录转场请求，并暴露 post_transition 信号（跳过路径要连它）。
class FakeSceneManager:
	extends Node
	signal post_transition(from_id: int, to_id: int)
	var requests: Array = []

	func request_scene_change(from_id: int, to_id: int, type: int) -> bool:
		requests.append({"from": from_id, "to": to_id, "type": type})
		return true

	func get_current_scene_id() -> int:
		return 0


## IdentitySelectionSystem 替身：is_identity_selected 恒真（模拟「这个进程里已经选过」）。
class FakeIdentitySystem:
	extends Node
	var queried: int = 0
	var available_calls: int = 0

	func is_identity_selected() -> bool:
		queried += 1
		return true

	func get_available_identities() -> Array:
		available_calls += 1
		return []


func before_each() -> void:
	IntentScript.clear()
	_sm = FakeSceneManager.new()
	_isys = FakeIdentitySystem.new()
	add_child_autofree(_sm)
	add_child_autofree(_isys)


func after_each() -> void:
	IntentScript.clear()


func _mount() -> Control:
	var screen: Control = ScreenScene.instantiate()
	screen.set(&"animate", false)
	screen.set(&"scene_manager", _sm)
	screen.set(&"identity_system", _isys)
	add_child_autofree(screen)
	return screen


# ───────────────────────────────────────────────────────────────────────────────
# 1. 有「新游戏」意图 → 必须渲染选择 UI，不跳转
# ───────────────────────────────────────────────────────────────────────────────
func test_new_game_intent_forces_the_selection_ui() -> void:
	IntentScript.request_force_show()

	var screen: Control = _mount()

	assert_eq(_sm.requests.size(), 0,
			"有强制意图时不应发出任何转场请求（应停在选择页）")
	# 静态节点树里 TitleLabel 始终存在，判「真的渲染了」要看数据是否被拉：
	# _build_ui 会调 get_available_identities()，跳过路径不会。
	assert_eq(_isys.available_calls, 1,
			"应渲染选择页（_build_ui 会向身份系统拉取条目）")
	assert_false(IntentScript.has_pending(),
			"意图是一次性的——_ready 消费后必须清空")


# ───────────────────────────────────────────────────────────────────────────────
# 2. 无意图 + 已选过身份 → 照旧跳过（读档路径不能被改坏）
# ───────────────────────────────────────────────────────────────────────────────
func test_without_intent_an_already_selected_identity_still_skips() -> void:
	var screen: Control = _mount()

	assert_eq(_isys.queried, 1, "无意图时应查询一次 is_identity_selected()")
	# 跳过路径不直接发转场：它等 post_transition 再 defer 请求（_ready 期间
	# SceneManager 的 _transitioning 还是 true，直接请求会被并发守卫静默拒绝）。
	_sm.post_transition.emit(0, 0)
	await get_tree().process_frame

	assert_eq(_sm.requests.size(), 1, "已选过身份 ⇒ 应请求一次转场（跳过选择 UI）")
	if _sm.requests.size() == 1:
		assert_eq(int(_sm.requests[0]["to"]), int(SceneManagerScript.SceneID.EXPLORATION),
				"跳过时应导航到探索")
	assert_eq(_isys.available_calls, 0,
			"跳过时不应渲染选择页（不该向身份系统拉取条目）")


# ───────────────────────────────────────────────────────────────────────────────
# 3. 意图的取用语义（单元层）
# ───────────────────────────────────────────────────────────────────────────────
func test_force_show_flag_is_one_shot() -> void:
	assert_false(IntentScript.has_pending(), "前置：初始无意图")
	IntentScript.request_force_show()
	assert_true(IntentScript.has_pending(), "请求后应有待消费意图")
	assert_true(IntentScript.take_force_show(), "第一次取走应返回 true")
	assert_false(IntentScript.has_pending(), "取走后应已清空")
	assert_false(IntentScript.take_force_show(), "第二次取走应返回 false")
