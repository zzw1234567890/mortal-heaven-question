extends GutTest
## 越阶渡劫（GDD §6）端到端 —— 真实修炼室场景 + 真实渡劫状态机 + 真实 GSM。[br]
## [br][b]本轮补的是什么[/b]：[code]TribulationType.CROSS_REALM[/code] 此前只有单测
## 覆盖（[code]tribulation_launch.gd[/code] 的越阶判定、状态机的越界校验），
## [b]生产里没有任何调用者[/b]——玩家在界面上找不到那个选项，这条分支等于不存在。
## 本文件钉住补完之后的那条路：界面上有个[b]默认不勾[/b]的越阶勾选框，
## 勾上再按「渡劫」，状态机收到的类型就是 [code]CROSS_REALM[/code]。[br]
## [br][b]为什么是集成测试[/b]：要验的是「玩家勾了一下，最后状态机真的收到越阶类型」
## ——中间隔着判定层（能不能越阶）、呈现层（露出与否）、接入层（透传选择）三层。
## 只用替身验其中任一层，就等于把断言换成「我调了那个桩」。[br]
## [br][b]替身只有导航桩[/b]：真转场会换场景并释放本屏，测试就再也断言不到回调之后的
## 画面。渡劫系统、GSM、境界表全部是真的（本文件的存在理由正是它们的联动）。[br]
## [br][b]存档隔离[/b]：player 域（修为 / 上限 / 境界 / 溢出 / 灵石 / 渡劫状态 / 失败计数）
## 在 [code]before_each[/code] 快照、[code]after_each[/code] 原样还原——越阶用例会把
## 状态机推进 [code]PREPARING[/code]，不还原就会漏进下一个用例。[br]
##
## 来源: design/gdd/tribulation-system.md §1/§2/§6/§7（含「唯一例外」）、
## design/gdd/story-system.md §第2章·苍玄古战场、ADR-0021 §trigger_tribulation、
## ADR-0010、ADR-0005、ADR-0031 §2、
## 先例 [code]test_cultivation_tribulation_entry.gd[/code]（同装置）。

const ScreenScene: PackedScene = preload("res://src/feature/cultivation/cultivation_scene.tscn")
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
const GateScript := preload("res://src/ui/cultivation/cultivation_tribulation_gate.gd")
const RulesScript := preload("res://src/ui/cultivation/cultivation_view_rules.gd")
## 渡劫规则表（越阶可用性 / 例外登记的真理来源——测试不自己硬编码境界数）。
const RealmRulesScript := preload("res://src/feature/tribulation/tribulation_realm_rules.gd")
## 渡劫系统枚举与常量真理来源（状态值 / 类型值都不写死）。
const TS_SCRIPT := preload("res://src/feature/tribulation_system.gd")

## 炼气期的修为上限（境界表 §1——本文件的基准状态）。
const BASE_MAX: int = 1000
## 账上有钱的档位（本屏只读灵石、不花）。
const RICH: int = 500


## 导航桩——记录转场请求，不真跳场景（[member accept] = false 时模拟并发守卫拒绝）。
class SceneManagerStub extends Node:
	var requests: Array = []
	var current_id: int = 10
	var accept: bool = true

	func get_current_scene_id() -> int:
		return current_id

	func request_scene_change(from: int, to: int, type: int) -> bool:
		requests.append({"from": from, "to": to, "type": type})
		return accept


var sm: SceneManagerStub = null
var screen: Control = null
var _player_before: Dictionary = {}


func before_each() -> void:
	_player_before = (GameStateManager.player as Dictionary).duplicate(true)
	_reset_player()
	sm = SceneManagerStub.new()
	add_child_autofree(sm)


func after_each() -> void:
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	screen = null
	GameStateManager.player = _player_before
	sm = null


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 基准存档：炼气期、修为 0 / 1000、无溢出、未在渡劫流程中。[br]
## [br][b]直接写 player 域而不是走 API[/b]：修为写入口全是只增不减的，构造「修为恰好
## 差一点」这种边界只能置位（同 [code]test_cultivation_scene.gd[/code] 口径）。
func _reset_player() -> void:
	var player: Dictionary = GameStateManager.player
	player["realm"] = 1
	player["cultivation"] = 0
	player["max_cultivation"] = BASE_MAX
	player["cultivation_full"] = false
	player["overflow_pool"] = 0
	player["resources"]["ling_shi"] = RICH
	player["tribulation_state"] = TS_SCRIPT.TribulationState.NOT_READY
	player["consecutive_tribulation_failures"] = 0
	GameStateManager.set("_pending_changes", {})
	GameStateManager.set("_flush_scheduled", false)


## 挂载修炼室场景（注入导航桩）。[br]
## [br][b]注入必须在进树前[/b]：[code]_ready[/code] 那一刻就会 [code]refresh()[/code]。
func _mount() -> Control:
	var instance: Control = ScreenScene.instantiate() as Control
	instance.set("scene_manager", sm)
	add_child_autofree(instance)
	return instance


## 把修为攒到满（经唯一入口 [code]gain_cultivation[/code]）+ 等一帧让域信号落定。[br]
## [br][b]为什么要等帧[/b]：GSM 的域信号只在「本帧恰好一条变更」时发射，同帧再写
## 境界就收不到 [code]realm_changed[/code]（本文件末的用例要跨境界，必须隔帧）。
func _fill_cultivation_and_flush() -> void:
	CultivationSystem.call("gain_cultivation", BASE_MAX, "test")
	await _flush()


func _cultivation() -> int:
	return int(GameStateManager.player.cultivation)


func _realm() -> int:
	return int(GameStateManager.player.realm)


func _trib_state() -> int:
	return int(GameStateManager.player.tribulation_state)


## 刷新 GSM 帧末缓冲（境界信号与上限重算在这一帧到账）。
func _flush() -> void:
	await get_tree().process_frame


## 投递一条真实按键（按下 + 抬起成对，且都带 [member InputEventKey.physical_keycode]——
## 只投「按下」不带 physical 时，焦点在 [Button] 上的回车不会被翻译成按钮按下）。
func _press(p_code: Key) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for is_pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = p_code
		event.physical_keycode = p_code
		event.pressed = is_pressed
		tree.root.push_input(event, true)


## 状态机最后收到的渡劫类型（[code]_trib_type[/code] 是私有字段——测试直读它，
## 因为「玩家勾了越阶」最终的真实去向就是这一个值）。
func _trib_type() -> int:
	return int(TribulationSystem.get("_trib_type"))


# ═══════════════════════════════════════════════════════════════════════════════
# 界面入口 —— 默认不勾、勾上才越阶
# ═══════════════════════════════════════════════════════════════════════════════

func test_cross_realm_toggle_exists_and_defaults_to_off() -> void:
	# Arrange + Act——炼气期修为攒满（该境界需渡劫，且 +1 存在故可越阶）
	await _fill_cultivation_and_flush()
	screen = _mount()
	# Assert——勾选框露出且默认「关」（GDD §6「非默认」）
	assert_true(screen.is_cross_realm_visible(), "可越阶的境界上勾选框应露出")
	assert_false(screen.is_cross_realm_checked(), "越阶渡劫默认不得勾上（GDD §6 非默认）")
	assert_eq(screen.cross_realm_text(), RulesScript.cross_realm_line(false),
			"未勾时的文案应是「关」那一句：%s" % screen.cross_realm_text())


func test_cross_realm_toggle_switches_its_wording() -> void:
	# Arrange——修为满，可越阶
	await _fill_cultivation_and_flush()
	screen = _mount()
	# Act——勾上
	screen.toggle_cross_realm()
	# Assert——勾选态与文案同步（两处各写一套「开/关」必然漂移）
	assert_true(screen.is_cross_realm_checked(), "切换后应处于勾选态")
	assert_eq(screen.cross_realm_text(), RulesScript.cross_realm_line(true),
			"勾上后的文案应是「开」那一句：%s" % screen.cross_realm_text())


func test_cross_realm_press_without_toggle_sends_normal_type() -> void:
	# Arrange——修为满，不勾越阶
	await _fill_cultivation_and_flush()
	screen = _mount()
	# Act——直接按「渡劫」
	screen.press_breakthrough()
	# Assert——状态机收到的是正常渡劫（默认那条路不被越阶污染）
	assert_eq(_trib_type(), TS_SCRIPT.TribulationType.NORMAL,
			"没勾越阶时发出必须是 NORMAL")
	assert_eq(sm.requests.size(), 1, "不勾也应正常发出一次转场请求")


func test_cross_realm_press_with_toggle_sends_cross_realm_type() -> void:
	# Arrange——修为满 + 玩家主动勾上越阶
	await _fill_cultivation_and_flush()
	screen = _mount()
	screen.toggle_cross_realm()
	assert_true(screen.is_cross_realm_checked(), "前置：越阶应已勾上")
	# Act——按「渡劫」
	screen.press_breakthrough()
	# Assert——状态机收到 CROSS_REALM（本文件存在的理由），且转场仍只发一次
	assert_eq(_trib_type(), TS_SCRIPT.TribulationType.CROSS_REALM,
			"勾了越阶后状态机应收到 CROSS_REALM")
	assert_eq(_trib_state(), TS_SCRIPT.TribulationState.PREPARING,
			"越阶同样要先推进到 PREPARING（否则渡劫场景会降级成普通战斗）")
	assert_eq(sm.requests.size(), 1, "越阶不得多发转场请求")
	assert_eq(int(sm.requests[0]["to"]), SceneManagerScript.SceneID.TRIBULATION,
			"越阶的目标同样是渡劫场景")


func test_cross_realm_press_does_not_change_realm_directly() -> void:
	# Arrange——修为满 + 勾上越阶
	await _fill_cultivation_and_flush()
	screen = _mount()
	screen.toggle_cross_realm()
	# Act
	screen.press_breakthrough()
	# Assert——触发只是触发：境界与修为都不动（进境由渡劫战的胜负决定）
	assert_eq(_realm(), 1, "触发越阶渡劫不得直接改境界")
	assert_eq(_cultivation(), BASE_MAX, "触发越阶渡劫不得动修为")


# ═══════════════════════════════════════════════════════════════════════════════
# 规则边界 —— 什么时候不该露出越阶选项
# ═══════════════════════════════════════════════════════════════════════════════

func test_cross_realm_toggle_hidden_at_last_selectable_realm() -> void:
	# Arrange——元婴期（4）：越阶会指向化神（5），仍在表内 → 可越阶
	# 而化神期（5）到顶 → 无处可越。这里验的是「最高境界」那一端。
	var top: int = RealmRulesScript.REALM_COUNT
	GameStateManager.player["realm"] = top
	GameStateManager.player["max_cultivation"] = 5063
	GameStateManager.player["cultivation"] = 5063
	await _flush()
	screen = _mount()
	# Assert——到顶时勾选框藏起来（没有更高处，留着只是噪音）
	assert_false(screen.is_cross_realm_visible(),
			"最高境界上不应露出越阶选项")


func test_cross_realm_boss_realm_is_one_above_current() -> void:
	# Act + Assert——越阶挑战的天劫 Boss 恒为「当前境界 + 1」（GDD §6 不能跳阶）
	for realm: int in range(1, RealmRulesScript.REALM_COUNT):
		assert_eq(RealmRulesScript.cross_realm_boss_realm(realm), realm + 1,
				"境界 %d 的越阶应挑战 %d 的天劫" % [realm, realm + 1])


func test_cross_realm_unavailable_at_max_realm() -> void:
	# Act + Assert——到顶那一级无处可越（不是「修为不足」，是规则上不存在）
	assert_false(RealmRulesScript.can_cross_realm(RealmRulesScript.REALM_COUNT),
			"最高境界不应可越阶")
	assert_eq(RealmRulesScript.cross_realm_boss_realm(RealmRulesScript.REALM_COUNT), 0,
			"不可越阶时不应给出 Boss 境界（给 0 让「忘了先判」一眼看得出）")


# ═══════════════════════════════════════════════════════════════════════════════
# 被拒 —— 勾了越阶也进不去时，状态不留残余
# ═══════════════════════════════════════════════════════════════════════════════

func test_cross_realm_checked_but_cultivation_low_is_refused_in_chinese() -> void:
	# Arrange——修为 0（远未满），勾上越阶
	screen = _mount()
	screen.toggle_cross_realm()
	sm.requests.clear()
	# Act——按「渡劫」
	screen.press_breakthrough()
	# Assert——给中文原因（修为不足）、状态机没被推进、也没发转场
	assert_true(str(screen.message_text()).contains("修为不足"),
			"修为不足时应给可读的中文原因：%s" % str(screen.message_text()))
	assert_eq(_trib_state(), TS_SCRIPT.TribulationState.NOT_READY,
			"被拒时不得把状态机推进渡劫流程（否则玩家被永久卡住）")
	assert_eq(sm.requests.size(), 0, "被拒时不得请求转场")
	await _flush()


func test_cross_realm_rejected_transition_cancels_state() -> void:
	# Arrange——修为满 + 勾越阶 + 导航桩拒绝转场（模拟并发守卫）
	await _fill_cultivation_and_flush()
	sm.accept = false
	screen = _mount()
	screen.toggle_cross_realm()
	# Act
	screen.press_breakthrough()
	# Assert——越阶这条路的收尾与普通渡劫同一份：状态退回 + 中文回执
	assert_eq(_trib_state(), TS_SCRIPT.TribulationState.NOT_READY,
			"越阶转场被拒后状态也应退回（收尾逻辑不因类型而分岔）")
	assert_true(str(screen.message_text()).contains("转场"),
			"应给出可读的中文回执：%s" % str(screen.message_text()))
	await _flush()


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘 / 焦点 —— 勾选框在动作行之外，别被游标吃掉确认键
# ═══════════════════════════════════════════════════════════════════════════════

func test_cross_realm_toggle_accepts_keyboard_confirm() -> void:
	# Arrange——修为满，先把焦点放到勾选框上（玩家走 Tab 或鼠标点过去）
	await _fill_cultivation_and_flush()
	screen = _mount()
	var toggle: CheckButton = screen.get("_view").call(&"cross_realm_toggle")
	assert_true(toggle != null, "前置：应能取到越阶勾选框")
	toggle.grab_focus()
	sm.requests.clear()
	# Act——回车
	_press(KEY_ENTER)
	# Assert——勾上了，[b]且没有顺带触发渡劫[/b]
	# （事件若被动作行的游标吃掉，玩家会「想勾选项结果直接开打」）
	assert_true(screen.is_cross_realm_checked(),
			"焦点在勾选框上时回车应切换勾选（不被动作行游标截走）")
	assert_eq(sm.requests.size(), 0, "回车只应切换勾选，不得触发渡劫")


func test_cross_realm_toggle_not_exposed_as_action_row() -> void:
	# Arrange——修为满
	await _fill_cultivation_and_flush()
	screen = _mount()
	# Assert——勾选框不在动作行容器里（动作行的条数 = 能做的事有几件）
	assert_eq(screen.action_count(), 2, "动作行仍应只有打坐与第二动作两行")
	assert_true(screen.is_cross_realm_visible(), "勾选框应在状态块里可见")
