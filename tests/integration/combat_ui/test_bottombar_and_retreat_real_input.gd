extends "res://tests/integration/combat_ui/full_battle_fixture.gd"
## 底部条三按钮 + 撤退按钮的[b]真实输入[/b]复现用例（2026-11-19 玩家实测反馈）。[br]
## [br][b]背景[/b]：玩家实测「战斗里『结束出牌』『撤退』『行囊』三个按钮点击都没反应」。
## 既有用例（[code]click_play_end_to_end[/code] / 本文件夹具）全部走
## [code]CombatInputLayer._handle_button[/code] 直调或 [code]button.emit_signal("pressed")[/code]
## ——[b]两者都把按钮从事件分派链路里摘了出来[/b]：命中测试 / [code]mouse_filter[/code]
## / 层级遮挡三段全被跳过。故本文件只走真实事件投递。[br]
## [br][b]投递方式[/b]：视口同步分派（引擎每帧对真实事件做的事），鼠标按下与抬起成对
## （[code]Button.pressed[/code] 在抬起时发射）。[br]
## [br][b]坐标[/b]：投递收视口坐标，控件给的是画布坐标——一律经
## [code]get_global_transform_with_canvas()[/code] 换算。[br]
## [br][b]不提证据不碰生产码[/b]：本文件先跑红，确认红在哪一环后再改生产代码；
## 不许为了让用例变绿而改测试口径。

const DriverScript := preload(
		"res://tests/integration/combat_ui/real_input_click_driver.gd")
## 撤退结局——引真实枚举本身（[constant CS_SCRIPT] 来自父夹具）。
const RETREAT_RESULT: int = CS_SCRIPT.CombatResult.RETREAT

## 暂停菜单场景（第 5 组用例挂它——HUD 的生产挂载点是 [code]hud.gd[/code]，
## 本文件只取菜单这一层，避免把整个 HUD 拉进战斗用例）。
const PauseMenuScene: PackedScene = preload("res://src/ui/hud/PauseMenu.tscn")

var driver: RefCounted = null
## 暂停菜单用例挂上的菜单（清理时要把暂停态与 MODAL 锁还回去——菜单是按
## [code]request_open[/code] 的生产路径打开的，它把 [code]get_tree().paused[/code]
## 置了真并压了锁；不还原会让后续用例连 [code]await process_frame[/code] 都不再推进，
## 于是整轮测试挂死在那里（本轮定位时踩到过）。
var _pause_menu: Control = null


func before_all() -> void:
	# CardSystem 的模板是异步加载的——等它读完（上限防挂死，同既有夹具口径）。
	for _i: int in range(300):
		if CardSystem.get_template(&"basic_attack") != null \
				and CardSystem.get_template(&"lin_yuan") != null:
			break
		await get_tree().process_frame
	AISystem.load_templates()


func before_each() -> void:
	setup(false)
	confirm_deploy()
	# 开战落在准备阶段（0）——三按钮只在出牌阶段（2）出现，先推到那里。
	# 这一步走的是生产路径的阶段推进（[method FullBattleFixture._advance_with_confirm]），
	# 不是把阶段硬设成 2。
	assert_true(drive_to_play(), "前置：应能推进到出牌阶段")
	driver = DriverScript.new()
	driver.call(&"setup", Callable(self, "_root"))
	_pause_menu = null


func after_each() -> void:
	driver = null
	# 暂停菜单用例把整棵树暂停了，而 GUT 是跑在同一棵树上的——不还原，
	# [code]await get_tree().process_frame[/code] 再也回不来（整轮挂死）。
	# 走生产关闭路径（[method PauseMenu.request_close]）pop 锁 + 还原 paused，
	# 不手改 [code]paused[/code]（那会把 MODAL 锁留在栈上）。
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_pause_menu.call(&"request_close")
		_pause_menu = null
	await teardown()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 「结束出牌」——真实点击应真的推进阶段
# ═══════════════════════════════════════════════════════════════════════════════

## 真实投递点「结束出牌」→ 阶段 2 应变成 3（[code]CombatPhaseManager[/code] 真的推进）。
func test_end_turn_button_click_advances_phase() -> void:
	# Arrange
	assert_eq(int(cs.call("get_current_phase")), 2, "前置：应处于出牌阶段（2）")
	assert_true(driver.call(&"probe_end_turn"), "前置：结束出牌按钮应可见")
	# Act
	driver.call(&"click", driver.call(&"end_turn_button_pos"))
	# Assert
	assert_eq(int(cs.call("get_current_phase")), 3,
			"点「结束出牌」应推进到攻击声明（3）——诊断：%s" % driver.call(&"diagnose"))


## 按钮本体没有被错误地置灰 / 隐形，且该坐标的命中控件就是它自己。[br]
## [br][b]与上一条分工[/b]：上一条红了而这条绿 = 事件没送到；两条都红 = 按钮 / 层级坏。
func test_end_turn_button_clickable_and_topmost() -> void:
	# Arrange
	var button: Button = driver.call(&"end_turn_button")
	assert_not_null(button, "底部条应持有结束出牌按钮本体")
	# Assert
	assert_true(button.visible, "出牌阶段按钮应可见")
	assert_false(button.disabled, "按钮不应被置灰")
	assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP,
			"按钮应接收鼠标事件（STOP）")
	var pos: Vector2 = driver.call(&"end_turn_button_pos")
	assert_eq(int(driver.call(&"hit_control_at", pos)), button.get_instance_id(),
			"该坐标的命中控件应是按钮本体——诊断：%s" % driver.call(&"diagnose"))


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 「行囊」——真实点击应真的打开并填充面板
# ═══════════════════════════════════════════════════════════════════════════════

## 真实投递点「行囊」→ 面板打开。[br]
## [br][b]只判「打开标志」会漏掉「打开了但是空白」[/b]，故面板可见性与条目数一并断言
## （种子夹具的收藏里就是空的——空行囊也是合法处境，故这里只锁「打开」与「命中」，
## 条目数由下一条在补货后验证）。
func test_bag_button_click_opens_panel() -> void:
	# Arrange
	assert_false(bool(scene.get("bag_mount").call(&"is_open")), "前置：行囊应关着")
	assert_true(driver.call(&"probe_bag"), "前置：行囊入口按钮应可见")
	# Act
	driver.call(&"click", driver.call(&"bag_button_pos"))
	# Assert
	assert_true(bool(scene.get("bag_mount").call(&"is_open")),
			"点「行囊」应打开面板——诊断：%s" % driver.call(&"diagnose"))
	var panel: Control = driver.call(&"bag_panel")
	assert_not_null(panel, "行囊面板应已装配")
	assert_true(panel.visible, "面板应真的可见")


## 打开后收藏里有丹可列时，面板应真的把条目填出来（「看得见点不着」的反面）。
func test_bag_panel_lists_owned_pill_after_open() -> void:
	# Arrange——补一枚回春丹进收藏（走真实卡实例创建）
	var primer: GDScript = preload(
			"res://tests/integration/exploration_ui/card_template_primer.gd")
	assert_true(primer.call(&"prime", CardSystem, &"pill_hui_chun_dan"),
			"前置：回春丹模板应就位")
	SeedScript.make_card(&"pill_hui_chun_dan")
	# Act
	driver.call(&"click", driver.call(&"bag_button_pos"))
	# Assert
	assert_gt(int(driver.call(&"bag_entry_count")), 0,
			"面板应列出收藏里的丹药——诊断：%s" % driver.call(&"diagnose"))


## 面板打开后，点面板内的「返回」应真的关掉它。[br]
## [br][b]为什么不是「再点一次行囊」[/b]：面板是全屏 [code]MOUSE_FILTER_STOP[/code]，
## 打开时把底部条的入口按钮整个盖住——这是[b]设计如此[/b]（不盖住就会隔着面板点穿出牌），
## 所以「再点一次关闭」在真实鼠标路径上不存在，玩家走的是面板里的出口。
## 宿主自己的开 / 关切换由 [code]test_combat_bag_battle_flow[/code] 覆盖。
func test_bag_panel_click_closes_it() -> void:
	# Arrange
	driver.call(&"click", driver.call(&"bag_button_pos"))
	# 面板刚打开时行还没排版——等一帧让「返回」按钮拿到矩形（同撤退弹窗那条）。
	await get_tree().process_frame
	assert_true(bool(scene.get("bag_mount").call(&"is_open")), "前置：第一次点击应打开")
	var leave: Button = driver.call(&"bag_leave_button")
	assert_not_null(leave, "面板应有「返回」按钮")
	# Act
	driver.call(&"click_control", leave)
	# Assert
	assert_false(bool(scene.get("bag_mount").call(&"is_open")),
			"点面板「返回」应关闭——诊断：%s" % driver.call(&"diagnose"))


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 「撤退」——真实点击弹确认框，二次确认后战斗真的以撤退收场
# ═══════════════════════════════════════════════════════════════════════════════

## 点右上角「撤退」→ 确认弹窗打开。[br]
## [br][b]命中控件必须是按钮本体[/b]：右上角另有暂停按钮位与顶部条，
## 层级若压住撤退按钮，事件就送不到——这条先回答「点落在谁身上」。
func test_retreat_button_click_opens_confirm_dialog() -> void:
	# Arrange
	var host: Variant = _root().get("settlement_host")
	assert_not_null(host, "前置：结算宿主应已装配")
	assert_false(bool(host.get("retreat_dialog").call(&"is_showing")),
			"前置：确认弹窗应关着")
	assert_true(driver.call(&"probe_retreat"), "前置：撤退按钮应可见")
	var button: Button = driver.call(&"retreat_button")
	var pos: Vector2 = driver.call(&"retreat_button_pos")
	assert_eq(int(driver.call(&"hit_control_at", pos)), button.get_instance_id(),
			"撤退按钮坐标的命中控件应是它自己——诊断：%s" % driver.call(&"diagnose"))
	# Act
	driver.call(&"click", pos)
	# Assert
	assert_true(bool(host.get("retreat_dialog").call(&"is_showing")),
			"点「撤退」应弹出确认框——诊断：%s" % driver.call(&"diagnose"))


## 撤退 → 二次确认「确认」→ [code]battle_end(CombatResult.RETREAT)[/code] 真的发生。[br]
## [br][b]断言终点是战斗系统的结局枚举[/b]，不是「弹窗关了没」——玩家要的是撤退真的生效。
## 全程真实点击：右上角按钮 → 确认框里的确认按钮。
func test_retreat_confirmed_ends_battle_with_retreat_result() -> void:
	# Arrange
	driver.call(&"click", driver.call(&"retreat_button_pos"))
	# 弹窗刚打开时内部容器还没排版——不等这一帧，确认按钮的矩形还是 0×0，
	# 坐标算出来落在弹窗原点，点到的不是按钮（假红，与暂停菜单那条同因）。
	await get_tree().process_frame
	var host: Variant = _root().get("settlement_host")
	var dialog: Control = host.get("retreat_dialog")
	assert_true(bool(dialog.call(&"is_showing")), "前置：撤退确认框应已打开")
	var confirm: Button = dialog.get("confirm_button") as Button
	assert_not_null(confirm, "确认框应有确认按钮")
	# Act
	driver.call(&"click_control", confirm)
	# Assert
	var why: String = _confirm_diagnose(dialog, confirm)
	assert_false(bool(cs.call("is_battle_active")), "确认撤退后战斗应已结束——诊断：%s" % why)
	assert_eq(battle_events.size(), 1, "应广播一次 battle_ended——诊断：%s" % why)
	assert_eq(int(battle_events[0].get("result", -1)), RETREAT_RESULT,
			"战斗结束原因应为撤退（CombatResult.RETREAT = 3）")


## 确认按钮那一次点击的现场：命中谁 / 矩形多大 / 弹窗还开着没 / 战斗还活着没。[br]
## [br][b]为什么单独一段[/b]：这条链跨四个模块（弹窗 → 结算宿主 → 战斗场景出口 →
## 战斗系统），「战斗没结束」可能是任何一环断——先分清「点没送到」与「送到了没生效」。
func _confirm_diagnose(p_dialog: Control, p_confirm: Button) -> String:
	return "hit=%s | confirm_rect=%s | dialog_showing=%s | battle_active=%s | %s" % [
		driver.call(&"describe", driver.call(&"sample_at",
				driver.call(&"control_center_in_viewport", p_confirm))),
		driver.call(&"rect_text", p_confirm),
		str(p_dialog.call(&"is_showing")),
		str(cs.call("is_battle_active")),
		driver.call(&"diagnose")]


## 确认框的「继续战斗」应关掉弹窗且战斗不结束（取消路径不许误伤）。
func test_retreat_cancel_keeps_battle_running() -> void:
	# Arrange
	driver.call(&"click", driver.call(&"retreat_button_pos"))
	var host: Variant = _root().get("settlement_host")
	var dialog: Control = host.get("retreat_dialog")
	var cancel: Button = dialog.get("cancel_button") as Button
	# Act
	driver.call(&"click_control", cancel)
	# Assert
	assert_true(bool(cs.call("is_battle_active")), "取消后战斗应仍在进行")
	assert_true(battle_events.is_empty(), "取消不应广播 battle_ended")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 输入锁栈：按钮该可点时锁栈应为空
# ═══════════════════════════════════════════════════════════════════════════════

## 开战后（出牌阶段）锁栈应为空——「点了没反应」的头号嫌疑是残留锁。[br]
## [br][b]为什么单列一条[/b]：本项目已两次踩过同坑（敌人行动播报、暂停菜单读档插入
## 面板的 ANIMATION / MODAL 锁被漏 pop），且 [code]tree_changed[/code] 会在场景挂载
## 那一帧整体清空锁栈——「同帧 push 的锁立刻被抹掉」正是行囊冻结改走普通字段的原因。
func test_lock_stack_is_empty_when_buttons_should_be_clickable() -> void:
	assert_eq(InputManager.get_lock_stack(), [],
			"出牌阶段锁栈应为空——诊断：%s" % driver.call(&"diagnose"))
	assert_true(InputManager.is_input_allowed(
			InputManager.ActionType.GAMEPLAY, InputManager.DeviceType.MOUSE),
			"出牌阶段鼠标玩法输入应放行")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 暂停菜单里的「返回主菜单」（战斗中 = 投降，须二次确认）
# ═══════════════════════════════════════════════════════════════════════════════

## 战斗中暂停菜单点「返回主菜单」→ 弹二次确认（而不是直接转场）。[br]
## [br][b]为什么单列[/b]：玩家报的「撤退」也可能是走这条路的入口（暂停菜单里的退出）；
## 它和右上角撤退按钮是两条链，任一条断掉都是「点了没反应」。
func test_pause_menu_return_in_combat_requests_confirmation() -> void:
	# Arrange——挂真实暂停菜单并注入战斗系统（HUD 的生产注入点）
	var menu: Control = PauseMenuScene.instantiate() as Control
	add_child_autofree(menu)
	_pause_menu = menu
	menu.set("combat_system", cs)
	menu.set("scene_manager", sm)
	menu.call(&"request_open", &"test")
	# 容器布局要一帧才落定——不等这一帧，按钮的矩形还是 0×0，
	# 坐标算出来落在容器原点，点到的就不是按钮（假红）。
	await get_tree().process_frame
	var return_button: Button = menu.get_node("Panel/VBox/ReturnButton") as Button
	assert_not_null(return_button, "前置：暂停菜单应有「返回主菜单」按钮")
	assert_true(return_button.is_visible_in_tree(), "战斗中「返回主菜单」应可见")
	# Act
	driver.call(&"click_control", return_button)
	# Assert——必须弹二次确认；不许「点了没反应」，也不许绕过确认直接投降
	assert_true(bool(menu.call(&"get_state").call(&"is_confirm_open")),
			"战斗中「返回主菜单」应弹二次确认——诊断：%s" % driver.call(&"diagnose"))
	assert_true(bool(cs.call("is_battle_active")), "仅弹确认框不应结束战斗")
