extends GutTest
## 修炼室（[code]cultivation_scene.tscn[/code]）端到端 —— 真实场景 + 真实 Autoload。[br]
## [br][b]为什么是集成测试而不是单元测试[/b]：本屏的价值全在「按下去玩家数据真的变了」
## ——修为走 [code]CultivationSystem.gain_cultivation[/code]、境界走
## [code]RealmSystem.realm_up[/code]→[code]GSM.change_realm[/code]、上限重算由
## [code]CultivationSystem[/code] 订阅 [code]realm_changed[/code] 完成
## （GDD §6）。替身这三段就等于把断言换成「我调了那个桩」，验不出「修为涨了、境界真的
## 升了、上限真的跟着变」。[br]
## [br][b]只给一个替身[/b]：[method _mount] 的 [param p_cultivation] 可注入一个
## 「要什么没什么」的桩系统——它验的是界面在[b]系统缺失[/b]时的降级形态
## （可读的中文提示 + 不崩），真实 Autoload 永远不为 null，不注入就构造不出这个形态。[br]
## [br][b]存档隔离[/b]：player 域（修为 / 境界 / 上限 / 溢出 / 灵石）在
## [code]before_each[/code] 快照、[code]after_each[/code] 原样还原。[br]
## [br][b]帧末到账[/b]：境界写入的 Cat 1 信号走 GSM 帧末缓冲，故「突破后上限变了」
## 这条用例必须在动作后[b]等一帧[/b]（[method _flush]）再断言——本屏自己也订阅了同一
## 信号（见 [code]CultivationScreen[/code] 类文档「上限是帧末到账的」）。[br]
##
## [b]同帧两次写入会吞掉域信号（GSM 既有契约）[/b]：[code]GSM._flush_pending_changes[/code]
## 只在「本帧恰好一条变更」时发射对应域信号，多条时[b]只发[/b] [code]batch_updated[/code]
## ——而 [code]CultivationSystem[/code] 订阅的是 [code]realm_changed[/code]，收不到就不会
## 重算修为上限。故构造「先攒修为、再突破」的场景时必须在两次写入之间 [method _flush]
## 一帧（生产里玩家按键天然隔帧，不受影响）。[br]
## [br]来源: design/gdd/cultivation-system.md §4/§5/§6、ADR-0010 §realm_up 编排器、
## ADR-0005、ADR-0031 §2、先例 [code]test_shop_scene.gd[/code]
## （真实场景 + 真实 Autoload + 存档还原）。

const ScreenScene: PackedScene = preload("res://src/feature/cultivation/cultivation_scene.tscn")
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
## 渡劫判定层（本文件借它取键名与规则表——不自己抄一份配置）。
const GateScript := preload("res://src/ui/cultivation/cultivation_tribulation_gate.gd")
## 渡劫规则表（「炼气期不需要渡劫」那张覆盖表的底本——规则单点）。
const RealmRulesScript := preload("res://src/feature/tribulation/tribulation_realm_rules.gd")
## 配置读取面（期望的境界名 / 所需修为从这里取——测试不自己硬编码等级名）。
const TableScript := preload("res://src/feature/exploration/exploration_breakthrough_table.gd")

## 打坐一次的期望增量（与屏幕的 [code]MEDITATE_AMOUNT[/code] 对齐——本屏的固定档）。
const MEDITATE_AMOUNT: int = 50
## 炼气期的修为上限（境界表 §1——本文件的基准状态）。
const BASE_MAX: int = 1000
## 账上有钱的档位（本屏只读灵石、不花，任何非零值都够）。
const RICH: int = 500

## 导航桩——记录转场请求，不真跳场景。
class SceneManagerStub extends Node:
	var requests: Array = []
	var current_id: int = 10

	func get_current_scene_id() -> int:
		return current_id

	func request_scene_change(from: int, to: int, type: int) -> bool:
		requests.append({"from": from, "to": to, "type": type})
		return true


## 桩修行系统——什么都不提供（界面据此走降级形态）。
class BareSystem extends Node:
	pass


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

## 基准存档：炼气期、修为 0 / 1000、无溢出、灵石若干。[br]
## [br][b]直接写 player 域而不是走 API[/b]：修为写入口全是只增不减的，构造「修为恰好
## 差一点」这种边界只能置位（同 [code]test_realm_upgraded_breakthrough.gd[/code] 口径）。
func _reset_player() -> void:
	var player: Dictionary = GameStateManager.player
	player["realm"] = 1
	player["cultivation"] = 0
	player["max_cultivation"] = BASE_MAX
	player["cultivation_full"] = false
	player["overflow_pool"] = 0
	player["resources"]["ling_shi"] = RICH
	GameStateManager.set("_pending_changes", {})
	GameStateManager.set("_flush_scheduled", false)


## 挂载修炼室场景（注入导航桩；[param p_cultivation] 非空时替换修行系统）。[br]
## [br][b]注入必须在进树前[/b]：[code]_ready[/code] 那一刻就会 [code]refresh()[/code]，
## 之后再赋字段这次刷新已经错过了。[br]
## [br][b]为什么本文件要传一张「无需渡劫」的境界表[/b]：按渡劫 GDD，低于最高境界的
## 每次大境界提升都要先渡劫（修为满 → 打一场天劫战 → 才进境），此时第二行动作叫
## 「渡劫」、点下去是转场而不是 [code]realm_up[/code]。本文件验的是[b]直接突破那条
## 路本身[/b]（点下去境界真的升、上限真的跟着重算），故注入一张把炼气期标成
## 「无需渡劫」的同构表——那条路在真配置里正是留给剧情专属境界的（GDD
## tribulation-system.md §7「唯一例外」）。两条路的界面行为由
## [code]test_cultivation_tribulation_entry.gd[/code] 分别钉住。
func _mount(p_cultivation: Variant = null, p_table: Variant = null) -> Control:
	var instance: Control = ScreenScene.instantiate() as Control
	instance.set("scene_manager", sm)
	if p_cultivation != null:
		instance.set("cultivation_system", p_cultivation)
	instance.set("tribulation_table", p_table if p_table != null \
			else _table_without_tribulation_at_realm_one())
	add_child_autofree(instance)
	return instance


## 一张「炼气期不需要渡劫」的规则表副本（其余行全部走真配置——见 [method _mount]）。[br]
## [br][b]为什么复制而不是改真表[/b]：[code]TribulationRealmRules.TABLE[/code] 是全局
## 单例数据，改了会漏进别的用例。[br]
## [br][b]底本取自规则表而不是境界表[/b]：渡劫规则已独立成册（键名同形但表不同，
## 见 [code]tribulation_realm_rules.gd[/code]）——取错表构造出来的覆盖对象
## 形状对不上，判定层读不到会走「未配置」那条路，用例会以看不懂的方式红。
func _table_without_tribulation_at_realm_one() -> Dictionary:
	var table: Dictionary = RealmRulesScript.TABLE.duplicate(true)
	(table[1] as Dictionary)[GateScript.KEY_REQUIRES_TRIBULATION] = false
	return table


func _cultivation() -> int:
	return int(GameStateManager.player.cultivation)


func _realm() -> int:
	return int(GameStateManager.player.realm)


func _max_cultivation() -> int:
	return int(GameStateManager.player.max_cultivation)


## 一条「按下取消」的动作事件（界面判的是动作名，不是键码）。
func _cancel_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event


## 刷新 GSM 帧末缓冲（境界信号与上限重算在这一帧到账）。
func _flush() -> void:
	await get_tree().process_frame


## 投递一条真实按键（按下 + 抬起成对——引擎对合成事件同样做 UI 动作派发）。[br]
## [br][b]两条事件都要发、且都要带 [member InputEventKey.physical_keycode][/b]：
## 只投「按下」一条、且不带 physical 键码时，焦点在 [Button] 上的回车不会被翻译成
## 按钮的 [signal Button.pressed]（[code]ui_accept[/code] 的动作派发只在完整配对上
## 成立）——测试会在「回车没反应」上假红。同 [code]test_shop_scene.gd[/code] 口径。
func _press(p_code: Key) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for is_pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = p_code
		event.physical_keycode = p_code
		event.pressed = is_pressed
		tree.root.push_input(event, true)


## 造一条鼠标按下事件（[member InputEventMouseButton.pressed] 为 true——界面只认这一种）。
func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


# ═══════════════════════════════════════════════════════════════════════════════
# 进场形态
# ═══════════════════════════════════════════════════════════════════════════════

func test_cultivation_scene_shows_title_realm_and_numbers() -> void:
	# Arrange + Act——进修炼室（基准存档：炼气期 0/1000）
	screen = _mount()
	# Assert——标题 / 境界名 / 修为数字都非空，且数字与系统读数一致
	assert_true(str(screen.title_text()).contains("修炼室"),
			"标题应写明这是修炼室：%s" % str(screen.title_text()))
	assert_true(str(screen.realm_text()).contains(TableScript.realm_name(1)),
			"境界行应显示配置表里的境界名：%s" % str(screen.realm_text()))
	assert_eq(str(screen.progress_text()), "修为 0 / %d" % BASE_MAX,
			"修为行应显示当前 / 上限（数字由文字承载）")
	assert_eq(str(screen.balance_text()), "灵石：%d" % RICH, "右上应显示真实余额")
	assert_eq(screen.action_count(), 2, "应恰有打坐与突破两个动作行")


func test_cultivation_scene_breakthrough_disabled_when_not_full() -> void:
	# Arrange + Act——修为 0，远未满
	screen = _mount()
	# Assert——突破按钮禁用，且状态行给出中文原因（不只靠灰掉）
	assert_false(screen.is_breakthrough_enabled(), "修为未满时突破应不可点")
	var status: String = str(screen.status_text())
	assert_true(status.contains("修为不足"), "状态行应写明原因：%s" % status)
	assert_true(status.contains(str(BASE_MAX)),
			"原因里应写清所需修为：%s" % status)


func test_cultivation_scene_breakthrough_enabled_when_full() -> void:
	# Arrange——修为攒满（经唯一入口 gain_cultivation）
	CultivationSystem.call("gain_cultivation", BASE_MAX, "test")
	# Act
	screen = _mount()
	# Assert——按钮可用 + 状态行提示可以突破
	assert_true(screen.is_breakthrough_enabled(), "修为满后突破应可点")
	assert_true(str(screen.status_text()).contains("可以突破"),
			"状态行应提示可以突破：%s" % str(screen.status_text()))
	await _flush()


# ═══════════════════════════════════════════════════════════════════════════════
# 打坐
# ═══════════════════════════════════════════════════════════════════════════════

func test_cultivation_scene_meditate_adds_exact_amount() -> void:
	# Arrange
	screen = _mount()
	# Act——打坐一次
	screen.press_meditate()
	# Assert——修为恰好 +50，界面数字跟着变（不是只在 _ready 读一次）
	assert_eq(_cultivation(), MEDITATE_AMOUNT, "打坐一次应恰好加 %d 修为" % MEDITATE_AMOUNT)
	assert_eq(str(screen.progress_text()), "修为 %d / %d" % [MEDITATE_AMOUNT, BASE_MAX],
			"界面修为数字应跟着刷新")
	assert_true(str(screen.message_text()).contains("+%d" % MEDITATE_AMOUNT),
			"提示行应说明这次加了多少：%s" % str(screen.message_text()))
	await _flush()


func test_cultivation_scene_meditate_twice_both_take_effect() -> void:
	# Arrange——打坐不是一次性动作（GDD §5 修为获取可反复）
	screen = _mount()
	# Act——连按两次
	screen.press_meditate()
	screen.press_meditate()
	# Assert——两次都算数
	assert_eq(_cultivation(), MEDITATE_AMOUNT * 2, "连按两次应加两份修为")
	assert_eq(str(screen.progress_text()),
			"修为 %d / %d" % [MEDITATE_AMOUNT * 2, BASE_MAX], "两次都应反映到界面上")
	await _flush()


func test_cultivation_scene_meditate_overflow_goes_to_pool() -> void:
	# Arrange——修为只差 10 点满（GSM 既有溢出逻辑：超出部分进 overflow_pool）
	GameStateManager.player["cultivation"] = BASE_MAX - 10
	screen = _mount()
	# Act
	screen.press_meditate()
	# Assert——修为顶到上限、溢出池拿到差额
	assert_eq(_cultivation(), BASE_MAX, "修为应顶到上限而不是超过")
	assert_eq(int(GameStateManager.player.overflow_pool), MEDITATE_AMOUNT - 10,
			"超出部分应进溢出池")
	await _flush()


# ═══════════════════════════════════════════════════════════════════════════════
# 突破
# ═══════════════════════════════════════════════════════════════════════════════

func test_cultivation_scene_breakthrough_raises_realm_and_max() -> void:
	# Arrange——修为攒满，并[b]等一帧[/b]让它落定
	# （GSM 的域信号只在「本帧恰好一条变更」时发射，见本文件末「同帧两次写入」注记）
	CultivationSystem.call("gain_cultivation", BASE_MAX, "test")
	await _flush()
	screen = _mount()
	# Act——突破
	screen.press_breakthrough()
	# Assert——境界 +1，界面显示新境界名
	assert_eq(_realm(), 2, "突破应把境界从 1 推到 2")
	assert_true(str(screen.realm_text()).contains(TableScript.realm_name(2)),
			"界面上应是新境界名：%s" % str(screen.realm_text()))
	assert_true(str(screen.message_text()).contains(TableScript.realm_name(2)),
			"提示行应写明突破到了哪个境界：%s" % str(screen.message_text()))
	# Act——等两帧：第一帧帧末才 flush 出 [code]realm_changed[/code]（本屏与
	# [code]CultivationSystem[/code] 在同一信号上先后处理），上限的写入再到下一帧才 flush
	await _flush()
	await _flush()
	# Assert——上限按境界配置重算（1500），且界面数字跟着变
	assert_eq(_max_cultivation(), 1500, "修为上限应按境界表重算为 1500")
	assert_eq(str(screen.progress_text()), "修为 %d / 1500" % BASE_MAX,
			"界面上的上限应跟着刷新")


func test_cultivation_scene_breakthrough_without_enough_changes_nothing() -> void:
	# Arrange——修为 0，突破按钮禁用
	screen = _mount()
	# Act——点那个灰按钮
	screen.press_breakthrough()
	# Assert——境界与修为都没动，且给了中文原因
	assert_eq(_realm(), 1, "修为不足时不得改境界")
	assert_eq(_cultivation(), 0, "修为不足时不得动修为")
	var message: String = str(screen.message_text())
	assert_true(message.contains("修为不足"), "应给出中文原因：%s" % message)


## 灰按钮的[b]真实鼠标点击[/b]同样给原因（不走 [method press_breakthrough] 这条测试口）。[br]
## [br][b]为什么单测一条[/b]：禁用按钮不发 [signal Button.pressed]，玩家点下去本会
## 「没反应」——补的那条 [signal Control.gui_input] 路必须真的接在行控件上。本用例把
## 鼠标事件直接投给行控件（真实点击的必经之路），并按「只认左键按下」的口径顺带钉住
## 非左键 / 抬起事件不得弹提示。
func test_cultivation_scene_disabled_row_click_shows_reason() -> void:
	# Arrange——修为 0，突破行禁用
	screen = _mount()
	var breakthrough: Button = screen.row_button(1)
	assert_true(breakthrough != null, "前置：应能取到第二动作行的控件")
	assert_true(breakthrough.disabled, "前置：修为未满时突破行应禁用")
	# Act——把真实鼠标按下事件投给那一行
	breakthrough.gui_input.emit(_click())
	# Assert——提示行给出中文原因
	var message: String = str(screen.message_text())
	assert_true(message.contains("修为不足"), "点禁用行应给出中文原因：%s" % message)


## 非左键 / 抬起事件不得被当成点击（否则鼠标划过灰按钮就弹一句「修为不足」）。
func test_cultivation_scene_hover_does_not_show_reason() -> void:
	# Arrange
	screen = _mount()
	var breakthrough: Button = screen.row_button(1)
	var before: String = str(screen.message_text())
	# Act——抬起事件（非按下）
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	breakthrough.gui_input.emit(released)
	# Assert——提示行一字未改
	assert_eq(str(screen.message_text()), before, "抬起事件不应弹拒绝原因")


func test_cultivation_scene_breakthrough_at_max_realm_is_refused() -> void:
	# Arrange——化神期（最高境界）且修为攒满：修为满不等于可以突破
	GameStateManager.player["realm"] = TableScript.max_realm()
	GameStateManager.player["max_cultivation"] = 5063
	GameStateManager.player["cultivation"] = 5063
	screen = _mount()
	# Assert——按钮禁用 + 状态行写明已达最高境界
	assert_false(screen.is_breakthrough_enabled(), "已达最高境界时突破应不可点")
	assert_true(str(screen.status_text()).contains("最高境界"),
			"状态行应写明已达最高境界：%s" % str(screen.status_text()))
	# Act——点灰按钮
	screen.press_breakthrough()
	# Assert——境界纹丝不动 + 中文原因
	assert_eq(_realm(), TableScript.max_realm(), "到顶时不得越界升境界")
	assert_true(str(screen.message_text()).contains("最高境界"),
			"应给出中文原因：%s" % str(screen.message_text()))


func test_cultivation_scene_breakthrough_keyboard_enter_works() -> void:
	# Arrange——修为攒满，默认焦点在「打坐」，↓ 移到「突破」
	CultivationSystem.call("gain_cultivation", BASE_MAX, "test")
	screen = _mount()
	# Act——↓ 选中突破 → 回车
	_press(KEY_DOWN)
	assert_eq(screen.focused_index(), 1, "前置：↓ 应把游标移到「突破」")
	_press(KEY_ENTER)
	# Assert——回车真的推进了境界（不是只有鼠标能突破）
	assert_eq(_realm(), 2, "回车应触发「突破」")
	await _flush()


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘 / 手柄 / 出口
# ═══════════════════════════════════════════════════════════════════════════════

func test_cultivation_scene_default_focus_lands_on_meditate() -> void:
	# Arrange + Act
	screen = _mount()
	# Assert——默认焦点在「打坐」（进场景就能直接按回车涨修为）
	assert_eq(screen.focused_index(), 0, "默认游标应在「打坐」上")
	assert_true(screen.is_action_focused(0), "「打坐」应真的持有键盘焦点")


func test_cultivation_scene_enter_key_meditates() -> void:
	# Arrange
	screen = _mount()
	# Act——回车（焦点默认在「打坐」）
	_press(KEY_ENTER)
	# Assert——修为涨了
	assert_eq(_cultivation(), MEDITATE_AMOUNT, "回车应触发「打坐」")
	await _flush()


func test_cultivation_scene_escape_returns_to_main_menu() -> void:
	# Arrange
	screen = _mount()
	sm.requests.clear()
	# Act——Esc
	_press(KEY_ESCAPE)
	# Assert——经 SceneManager 回主菜单（ADR-0005 唯一入口 + 音频过渡类型）
	assert_eq(sm.requests.size(), 1, "Esc 应发出一次转场请求")
	assert_eq(int(sm.requests[0]["from"]), SceneManagerScript.SceneID.CULTIVATION,
			"from 应为当前场景")
	assert_eq(int(sm.requests[0]["to"]), SceneManagerScript.SceneID.MAIN_MENU, "应回主菜单")
	assert_eq(int(sm.requests[0]["type"]),
			SceneManagerScript.TransitionType.GAME_TO_MENU, "应走回主菜单的过渡类型")


func test_cultivation_scene_leave_button_returns_to_main_menu() -> void:
	# Arrange
	screen = _mount()
	sm.requests.clear()
	# Act——点「离开」
	screen.press_leave()
	# Assert——与 Esc 同一出口，且只发一次（不重复接线）
	assert_eq(sm.requests.size(), 1, "「离开」应恰好发出一次转场请求")
	assert_eq(int(sm.requests[0]["to"]), SceneManagerScript.SceneID.MAIN_MENU, "应回主菜单")


## Esc 返回之后本屏已离树（转场把当前场景摘走了）——消费不得再碰取不到的 viewport。[br]
## [br][b]真机走查现场[/b]：[code]get_viewport().set_input_as_handled()[/code] 在离树后
## 报 [code]Cannot call method 'set_input_as_handled' on a null value[/code]
## （机制与修法见 [code]ui_input_consume.gd[/code] 类文档；同构的卡组编辑 / 坊市各有
## 同名用例）。[br]
## [br][b]为什么手工摘出树[/b]：真实转场要过 [code]change_scene_to_file[/code]，
## 会换掉测试树；摘出树就复现了同一个瞬间（探针实测：离树同帧
## [code]get_viewport()[/code] 即为 null）。
func test_cultivation_scene_escape_after_leaving_tree_does_not_error() -> void:
	# Arrange
	screen = _mount()
	remove_child(screen)
	sm.requests.clear()
	# Act——界面读的就是取消动作本身（离树后引擎不再派发到这里，直接调同一条
	# 处理链：SceneInput → 回主菜单转场 → 消费，正是崩的那一段）
	screen._input(_cancel_event())
	# Assert——转场照旧发出（修的是崩溃，不是把这条路堵死）
	assert_eq(sm.requests.size(), 1, "Esc 的返回请求仍应发出（离树只是消费不了事件）")


# ═══════════════════════════════════════════════════════════════════════════════
# 降级：系统缺失
# ═══════════════════════════════════════════════════════════════════════════════

func test_cultivation_scene_survives_missing_cultivation_system() -> void:
	# Arrange + Act——注入一个「要什么没什么」的桩系统
	var stub := BareSystem.new()
	add_child_autofree(stub)
	screen = _mount(stub)
	# Assert——不崩、给可读的中文降级文案、突破不可点、离开仍可达
	assert_true(str(screen.status_text()).contains("不可用"),
			"系统缺失时状态行应给出可读原因：%s" % str(screen.status_text()))
	assert_false(screen.is_breakthrough_enabled(), "系统缺失时突破应不可点")
	# Act——此时按「离开」仍应能走（唯一的可用出口）
	sm.requests.clear()
	screen.press_leave()
	# Assert
	assert_eq(sm.requests.size(), 1, "系统缺失时「离开」仍应可用")
