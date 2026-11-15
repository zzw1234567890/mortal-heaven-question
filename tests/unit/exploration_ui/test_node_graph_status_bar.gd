extends GutTest
## 节点图顶栏状态区 —— 行动力显示 / 走投无路提示 / 退出探索。[br]
## [br][b]本文件补的断链[/b]：GDD exploration-system.md §8 要求「探索HUD中始终显示
## 『退出探索』按钮」，而全库此前[b]没有任何退出入口[/b]——行动力见底的玩家卡在
## 节点图里出不去（§5「行动力归零且无法到达Boss → 立即结算」也因此没有触发器）。[br]
## [br][b]覆盖[/b]：[br]
##   1. [b]提示文案纯函数[/b]——走得到时无提示，走不到时按行动力是否见底分两种
##      陈述（不把两种处境说成一句话）；[br]
##   2. [b]刷新口径[/b]——行动力标签文案 = 快照值（既有集成测试按 [code]AP: N[/code]
##      锁定同一份文案）；提示标签随之显隐；[br]
##   3. [b]判定来源[/b]——快照不出自系统 / 系统问不出答案 / 站在 AP 豁免节点上时
##      [b]不下断语[/b]（宁可少提示也不误报「你走投无路了」）；[br]
##   4. [b]退出两步走[/b]——按下弹确认、确认才发意图（GDD §AC「点击退出探索按钮，
##      WHEN 确认退出，THEN ...」）；取消不发；[br]
##   5. [b]输入锁[/b]——改变游戏状态的退出点击必须过 InputManager（ADR-0004），
##      被锁时既不弹窗也不发意图。[br]
## [br][b]隔离[/b]：本文件不碰 GSM，也不进 Autoload——状态区是纯 RefCounted，
## 用 [code]new()[/code] 构造、控件就地建（先例
## [code]test_node_popup_stage.gd[/code]）。[br]
##
## 来源: design/gdd/exploration-system.md §5 结束条件 / §8 边界 + §AC 退出、
## design/gdd/action-point-system.md §4 UI、ADR-0004、ADR-0031 §2。

const StatusBarScript := preload("res://src/ui/exploration/node_graph_status_bar.gd")
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")

## Boss 类型值（AP 豁免——与 [code]NodeStateLogic.AP_EXEMPT_TYPES[/code] 同源）。
const TYPE_BOSS: int = 3
## 战斗类型值（非豁免——用于「站在普通节点上」的对照）。
const TYPE_COMBAT: int = 1

var bar: RefCounted = null
var host: Control = null
var ap_label: Label = null
var status_label: Label = null
var exit_button: Button = null
var dialog: ConfirmationDialog = null
## 退出意图回调收到的次数。
var exit_count: int = 0


func before_each() -> void:
	host = Control.new()
	add_child_autofree(host)
	ap_label = _add(Label.new(), "APLabel")
	status_label = _add(Label.new(), "StatusLabel")
	exit_button = _add(Button.new(), "ExitButton")
	dialog = ConfirmationDialog.new()
	dialog.name = "ExitDialog"
	host.add_child(dialog)
	exit_count = 0
	bar = StatusBarScript.new()
	bar.call(&"bind", host, ap_label, exit_button, status_label, dialog,
			Callable(self, &"_on_exit"))
	# 输入锁默认放行——单独用例再收紧（否则每条用例都要先过锁）
	bar.set("input_allowed_cb", Callable(func() -> bool: return true))


func after_each() -> void:
	dialog.hide()
	bar = null


func _add(p_node: Node, p_name: String) -> Variant:
	p_node.name = p_name
	host.add_child(p_node)
	return p_node


func _on_exit() -> void:
	exit_count += 1


## 一份含单个节点的快照（[param p_type] 为节点类型）。
func _snapshot(p_type: int, p_ap: int = 3) -> Dictionary:
	return {
		"nodes": {0: {"type": p_type}},
		"graph": {0: []},
		"visited": [0],
		"current_node": 0,
		"ap_remaining": p_ap,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 提示文案（纯函数）
# ═══════════════════════════════════════════════════════════════════════════════

func test_warning_text_is_empty_while_boss_is_still_reachable() -> void:
	assert_eq(StatusBarScript.warning_text(3, true), "",
			"还走得到 Boss 时不应有任何提示")
	assert_eq(StatusBarScript.warning_text(0, true), "",
			"AP=0 但走得到（下一格是豁免节点）时同样不提示")


func test_warning_text_distinguishes_empty_from_insufficient() -> void:
	## 两种处境分开陈述：行动力见底 / 还有行动力但不够走到 Boss。
	assert_eq(StatusBarScript.warning_text(0, false), StatusBarScript.TEXT_AP_EMPTY,
			"行动力见底应陈述「已耗尽」")
	assert_eq(StatusBarScript.warning_text(2, false), StatusBarScript.TEXT_AP_INSUFFICIENT,
			"还剩几点但不够走应陈述「不足以抵达」")
	assert_ne(StatusBarScript.TEXT_AP_EMPTY, StatusBarScript.TEXT_AP_INSUFFICIENT,
			"两种处境不能是同一句话")
	# 越界存档值（负数）按「见底」处理——不出现「-3 点不足以抵达」
	assert_eq(StatusBarScript.warning_text(-3, false), StatusBarScript.TEXT_AP_EMPTY,
			"负数存档按已耗尽陈述")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 刷新（行动力标签 + 提示显隐）
# ═══════════════════════════════════════════════════════════════════════════════

func test_refresh_writes_ap_label_from_snapshot() -> void:
	# Arrange——快照不出自系统（不下断语），只看行动力那一路
	bar.call(&"bind_system", null, false)
	# Act
	bar.call(&"refresh", _snapshot(TYPE_COMBAT, 2))
	# Assert——与既有集成测试读的文案同口径
	assert_eq(ap_label.text, "AP: 2", "行动力标签应反映快照的 ap_remaining")


func test_refresh_updates_ap_label_on_every_call() -> void:
	bar.call(&"bind_system", null, false)
	bar.call(&"refresh", _snapshot(TYPE_COMBAT, 5))
	assert_eq(ap_label.text, "AP: 5", "首次刷新")
	bar.call(&"refresh", _snapshot(TYPE_COMBAT, 0))
	assert_eq(ap_label.text, "AP: 0", "第二次刷新应覆盖上一次的值")


func test_status_label_hidden_when_reachable() -> void:
	bar.call(&"bind_system", null, false)
	bar.call(&"refresh", _snapshot(TYPE_COMBAT, 3))
	assert_false(status_label.visible, "无提示时提示标签应隐藏")
	assert_eq(status_label.text, "", "隐藏时文案也应为空（不留上一轮的残句）")


func test_status_label_shown_with_reason_when_stuck() -> void:
	# Arrange——系统报「走不到」，行动力见底
	bar.call(&"bind_system", _stuck_system(), true)
	# Act
	bar.call(&"refresh", _snapshot(TYPE_COMBAT, 0))
	# Assert
	assert_true(status_label.visible, "走投无路时应显示提示")
	assert_eq(status_label.text, StatusBarScript.TEXT_AP_EMPTY,
			"提示文案应说明原因（不是一句「无法继续」）")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 判定来源（不下断语的三条路径）
# ═══════════════════════════════════════════════════════════════════════════════

func test_snapshot_not_from_system_does_not_judge() -> void:
	## stub 降级 / 测试直调的快照不在系统缓存的那张图里——拿系统的判定去问，
	## 会得到与画面无关的答案。
	bar.call(&"bind_system", _stuck_system(), false)
	assert_eq(bar.call(&"can_reach_boss", _snapshot(TYPE_COMBAT, 0)), true,
			"快照不出自系统时不查询系统判定")


func test_system_without_the_query_does_not_judge() -> void:
	## 早期实情 / 测试桩：系统在场但没声明该查询——问不出答案就不下断语。
	var bare: Node = Node.new()
	add_child_autofree(bare)
	bar.call(&"bind_system", bare, true)
	assert_eq(bar.call(&"can_reach_boss", _snapshot(TYPE_COMBAT, 0)), true,
			"系统未声明 can_still_reach_boss 时不判定")


func test_no_system_at_all_does_not_judge() -> void:
	bar.call(&"bind_system", null, true)
	assert_eq(bar.call(&"can_reach_boss", _snapshot(TYPE_COMBAT, 0)), true,
			"无系统时不判定（accessor 缺失也不崩）")


func test_standing_on_exempt_node_does_not_judge() -> void:
	## 三种豁免节点各自都是一条出路（已在终点 / 免费跳转 / 回复全部行动力），
	## 而最短路只算移动开销、看不见「站在这眼泉上还能回一口血」。
	for exempt: int in NodeStateLogicScript.AP_EXEMPT_TYPES:
		bar.call(&"bind_system", _stuck_system(), true)
		assert_eq(bar.call(&"can_reach_boss", _snapshot(exempt, 0)), true,
				"站在豁免类型 %d 上不该报走投无路" % exempt)


func test_standing_on_ordinary_node_consults_the_system() -> void:
	## 对照（防「一律不判定」的假通过）：普通节点上必须真的问系统。
	var system: Node = _stuck_system()
	bar.call(&"bind_system", system, true)
	assert_eq(bar.call(&"can_reach_boss", _snapshot(TYPE_COMBAT, 0)), false,
			"普通节点上应采信系统的「走不到」")
	assert_eq(int(system.get("calls")), 1, "系统查询应被真的调用一次")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 退出：按钮 → 确认 → 意图
# ═══════════════════════════════════════════════════════════════════════════════

func test_exit_button_carries_the_gdd_label() -> void:
	assert_eq(exit_button.text, StatusBarScript.TEXT_EXIT, "按钮文案应为「退出探索」")
	assert_eq(StatusBarScript.TEXT_EXIT, "退出探索",
			"GDD exploration-system.md §8 的点名词条")


func test_pressing_exit_opens_confirmation_and_does_not_settle_yet() -> void:
	# Act——按下（还没确认）
	exit_button.pressed.emit()
	# Assert——意图未发出，窗口已开（GDD §AC 是两步）
	assert_eq(exit_count, 0, "只按下不应退出（未确认）")
	assert_true(bar.call(&"is_confirm_open"), "按下应打开确认弹窗")


func test_confirming_the_dialog_emits_the_exit_intent() -> void:
	# Arrange
	exit_button.pressed.emit()
	# Act——玩家确认
	dialog.confirmed.emit()
	# Assert
	assert_eq(exit_count, 1, "确认后应发出退出意图恰好一次")


func test_canceling_the_dialog_does_not_emit_the_exit_intent() -> void:
	# Arrange
	exit_button.pressed.emit()
	# Act——玩家取消
	dialog.canceled.emit()
	dialog.hide()
	# Assert
	assert_eq(exit_count, 0, "取消不应退出")
	assert_false(bar.call(&"is_confirm_open"), "取消后窗口应已关闭")


func test_repeated_press_does_not_stack_dialogs() -> void:
	# Arrange——第一次按下已开窗
	exit_button.pressed.emit()
	# Act——继续连点
	exit_button.pressed.emit()
	exit_button.pressed.emit()
	# Act——确认一次
	dialog.confirmed.emit()
	# Assert——不该叠出多次退出
	assert_eq(exit_count, 1, "连点后确认仍只退出一次")


func test_exit_without_confirmation_control_settles_directly() -> void:
	## 无确认控件（headless / 无 UI 位）时按下即退出——不把缺控件变成死路。
	var bar2: RefCounted = StatusBarScript.new()
	bar2.call(&"bind", host, ap_label, exit_button, status_label, null,
			Callable(self, &"_on_exit"))
	bar2.set("input_allowed_cb", Callable(func() -> bool: return true))
	# Act
	exit_button.pressed.emit()
	# Assert
	assert_eq(exit_count, 1, "无确认控件时应直接退出")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 输入锁（ADR-0004）
# ═══════════════════════════════════════════════════════════════════════════════

func test_locked_input_neither_opens_dialog_nor_exits() -> void:
	# Arrange——输入被锁（转场 / 模态期间）
	bar.set("input_allowed_cb", Callable(func() -> bool: return false))
	# Act
	exit_button.pressed.emit()
	# Assert——既不弹窗也不退出
	assert_eq(exit_count, 0, "输入被锁时不应退出")
	assert_false(bar.call(&"is_confirm_open"), "输入被锁时不应弹确认窗")


func test_input_lock_is_read_through_the_gate() -> void:
	## 未注入时查 [code]/root/InputManager[/code]——本文件所在场景树无该 Autoload，
	## 应放行（headless / 早期启动同口径）。
	bar.set("input_allowed_cb", Callable())
	assert_eq(bar.call(&"is_input_allowed"), true,
			"InputManager 不可用时放行（与 MapSelectData 同口径）")


# ═══════════════════════════════════════════════════════════════════════════════
# 装置：一个「走不到 Boss」的系统桩
# ═══════════════════════════════════════════════════════════════════════════════

## 只实现 [code]can_still_reach_boss[/code]（恒 false）并记录调用次数。[br]
## [br][b]为什么用脚本桩而非 [code]ES_SCRIPT.new()[/code][/b]：本文件测的是「状态区
## 拿谁的答案」，需要精确控制答案是真是假；真实系统的答案由
## [code]test_boss_reachability.gd[/code] 负责。
func _stuck_system() -> Node:
	var node: Node = Node.new()
	var script: GDScript = GDScript.new()
	script.source_code = "extends Node\nvar calls: int = 0\nfunc can_still_reach_boss() -> bool:\n\tcalls += 1\n\treturn false\n"
	script.reload()
	node.set_script(script)
	add_child_autofree(node)
	return node
