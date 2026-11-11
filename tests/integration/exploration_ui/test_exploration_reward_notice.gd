extends GutTest
## 回探索后的战斗奖励提示——一次性、不重复。[br]
## [br][b]链路[/b]：战斗结束 → [code]CombatResultView.publish[/code] 备好文案 →
## 转场回探索 → [code]ExplorationScene._ready[/code] 取走并请求 HUD 通知。[br]
## [br][b]断言三件事[/b]：[br]
##   1. 有奖励时弹一条 item 通知，文案含实得内容；[br]
##   2. 同一条提示只弹一次（场景重挂载不再弹）；[br]
##   3. 无奖励 / 无 HUD 时静默跳过，不崩。[br]
## [br]来源: 本轮「探索→战斗→结算→回探索」闭环、hud Story 004 通知接口。

const SceneScript := preload("res://src/feature/exploration/exploration_scene.gd")
const ViewScript := preload("res://src/feature/combat/combat_result_view.gd")

var scene: Control = null
var _notices: Array = []


func before_each() -> void:
	ViewScript.clear()
	_notices.clear()


func after_each() -> void:
	ViewScript.clear()
	if scene != null and is_instance_valid(scene):
		scene.free()
	scene = null
	if GameStateManager != null:
		GameStateManager.exploration = {
			"current_map": &"",
			"node_position": {"layer": 0, "idx": 0},
			"visited_nodes": [],
			"action_points": 0,
			"map_states": {},
		}


## 发布一份带奖励的结算对象（模拟战斗侧刚发过 battle_ended）。
func _publish_victory(p_rewards: Dictionary) -> void:
	ViewScript.publish(ViewScript.from_battle_ended(1, p_rewards))


## 挂载探索容器，并注入通知入口（不依赖真实 HUD）。
func _mount_scene() -> void:
	scene = SceneScript.new()
	scene.set("notify_cb", Callable(func(type: String, text: String) -> int:
		_notices.append({"type": type, "text": text})
		return _notices.size()))
	add_child_autofree(scene)


func test_mount_emits_reward_notice_once() -> void:
	# Arrange——上一场胜利拿到了灵石与卡牌
	_publish_victory({
		"lingshi": 12, "cultivation": 3,
		"cards": [{"card_id": "pei_yuan_dan", "name": "培元丹"}],
	})
	# Act——回到探索
	_mount_scene()
	# Assert——弹一条 item 通知，内容含实得
	assert_eq(_notices.size(), 1, "有奖励时应弹一条通知")
	assert_eq(str(_notices[0]["type"]), "item", "奖励通知走高亮 item 类型")
	var text: String = str(_notices[0]["text"])
	assert_string_contains(text, "灵石 +12", "通知含灵石")
	assert_string_contains(text, "修为 +3", "通知含修为")
	assert_string_contains(text, "培元丹", "通知含到手卡牌")


func test_notice_is_not_repeated_on_remount() -> void:
	# Arrange
	_publish_victory({"lingshi": 5})
	_mount_scene()
	assert_eq(_notices.size(), 1, "前置：首次挂载弹一次")
	# Act——玩家离开又回来（场景重挂载）
	scene.free()
	scene = null
	_mount_scene()
	# Assert
	assert_eq(_notices.size(), 1, "同一场奖励只提示一次（取走即清）")


func test_no_notice_without_rewards() -> void:
	_publish_victory({})
	_mount_scene()
	assert_true(_notices.is_empty(), "无奖励时不弹通知")


func test_no_notice_without_result_view() -> void:
	# 从未打过战斗（缓存为空）
	_mount_scene()
	assert_true(_notices.is_empty(), "无结算数据时不弹通知")


func test_missing_notification_sink_is_silent() -> void:
	# Arrange——有奖励但没有任何通知入口
	_publish_victory({"lingshi": 5})
	scene = SceneScript.new()
	# 不注入 notify_cb，且 SceneManager Autoload 下没有挂 HUD
	# Act——不应崩溃
	add_child_autofree(scene)
	# Assert——提示被取走（不会在下一次挂载时重放）
	assert_eq(str(ViewScript.take_pending_notice()), "",
			"取走即清——缺 HUD 时也不留待重放")
