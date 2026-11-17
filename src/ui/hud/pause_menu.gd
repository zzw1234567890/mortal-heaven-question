class_name PauseMenu
extends Control
## PauseMenu —— 暂停菜单组件（hud Story 005）。[br]
## [br][b]结构[/b]：[code]MaskLayer[/code]（全屏 BackBufferCopy + ColorRect 模糊遮罩，
## 点击等效「继续游戏」）+ [code]Panel[/code]（居中面板：标题 / 7 按钮 / 分隔线 /
## 进度行 / 操作反馈行）。[br]
## [br][b]本文件只做两件事[/b]：把 tscn 的控件路径与注入点写一遍、把按钮信号转发给
## 编排层。各条规则的[b]家[/b]分别在：[br]
##   · 点按钮之后做什么（存档 / 读档 / 卡组 / 退出 / 反馈行）→ [PauseMenuHandlers]；[br]
##   · 开合五步与锁栈配对 → [PauseMenuPauseCycle]（理由与顺序注记在那边）；[br]
##   · 存档 / 读档 / 返回主菜单的底层动作 → [PauseMenuActions]；[br]
##   · 场景变体 / 二次确认 / ESC 分层 / 退出链分叉 → [PauseMenuState]；[br]
##   · 战斗中投降收尾 → [PauseMenuCombatExit]；[br]
##   · 只读卡组面板 → [PauseMenuDeckHost]。[br]
## 本文件只持有控件路径与注入点——路径改一处即可，规则不在此重述（重复必然漂移）。[br]
## [br][b]统一入口[/b]（GAP-3 裁决）：HUD 暴露 [code]hud.request_pause(source)[/code]
## 三路汇入 [method request_open]——ESC 信号 / 暂停按钮 / combat-ui 转发。[br]
## [br][b]引擎注记[/b]：[code]grab_focus()[/code] 在 4.6 双焦点下只影响键盘/手柄
## 焦点不影响鼠标（story Engine Notes）；本组件无 [code]_process()[/code]
## （模糊动画走 Tween，输入驱动纯视觉变换豁免 ADR-0031 §3）。[br]
## [br][b]暂停中输入前提[/b]（code-review G-6）：按钮/遮罩点击与 ESC 关闭在暂停中
## 可响应，依赖 tscn 根节点 [code]process_mode = 3[/code]（ALWAYS）——场景树暂停时
## 本组件仍处理输入/信号。[br]
##
## @experimental
## 来源: ADR-0031 §1.1、design/ux/pause-menu.md、hud Story 005（2026-09-11）。

## === 信号（导航请求——留桩，目标界面归各自 epic）=============================

## 请求打开卡组浏览界面（deck-editing-ui epic）。[br]
## 战斗中为只读查看（GDD 待解决问题 #3 当前设计）。
signal deck_view_requested()

## 请求打开系统设置面板（main-menu epic）。
signal settings_requested()

## === 常量（数据驱动）===========================================================

## 模糊动画时长（0.3s——story Guardrail + GDD 过渡表「打开暂停 0.3s」）。
const BLUR_DURATION: float = 0.3

## MODAL 锁 source——push/pop 配对标识（ADR-0031 §1.1）。
const LOCK_SOURCE: StringName = &"pause_menu"

## 存档 / 读档 / 返回主菜单三条动作的编排层（见类文档「三条动作不在本文件」）。
const ActionsScript := preload("res://src/ui/hud/pause_menu_actions.gd")

## 场景变体 + 二次确认的编排层（本轮拆出——见类文档「按场景调按钮可见性」）。
const StateScript := preload("res://src/ui/hud/pause_menu_state.gd")
## 开合配对内核（锁 / 暂停 / 模糊动画五步——见 [PauseMenuPauseCycle]）。
const CycleScript := preload("res://src/ui/hud/pause_menu_pause_cycle.gd")
## 只读卡组查看面板的挂载与开合（见 [PauseMenuDeckHost]）。
const DeckHostScript := preload("res://src/ui/hud/pause_menu_deck_host.gd")
## 菜单项处理器集合（点按钮之后做什么——见 [PauseMenuHandlers]）。
const HandlersScript := preload("res://src/ui/hud/pause_menu_handlers.gd")

## 反馈行两档颜色——[code]COLOR_STATUS_OK[/code] 松石青 #4A9494（与通知区域 green
## 档同源「正向」编码）、[code]COLOR_STATUS_FAIL[/code] 朱砂红 #B3424A（警报编码复用
## 先例 lingshi_deck_bar / exploration_info_area）。[br]
## [br][b]常量留在本类[/b]（实现在 [PauseMenuHandlers]）：它们是本组件对外承诺的
## 配色契约，既有用例按 [code]menu.COLOR_STATUS_*[/code] 读——搬家会把一处引用
## 拆成两处真理来源。
const COLOR_STATUS_OK: Color = Color("#4A9494")
const COLOR_STATUS_FAIL: Color = Color("#B3424A")

## === 依赖注入（测试可替换）=====================================================

## 音频暂停 adapter——默认 no-op 桩；测试注入 mock 记录调用（AC-3）。
var audio_adapter: PauseAudioAdapter = null

## SceneManager 引用——退出路由转场用（HUD 注入，避免直引 Autoload）。
var scene_manager: Node = null

## SaveLoadSystem 引用——「保存并退出」存档用（HUD 注入）。
var save_load: Node = null

## GameStateManager 引用——存档载荷来源（HUD 注入；null 时动作层回退 Autoload）。
var gsm: Node = null

## CombatSystem 引用——战斗中「返回主菜单」的投降收尾用（HUD 注入）。[br]
## [br][b]为什么要它[/b]：战斗里点「返回主菜单」不是导航而是一次战败结算
## （design/ux/pause-menu.md §Events Fired），投降入口在战斗系统上
## （[code]confirm_retreat[/code]）。判据与调用都归
## [code]pause_menu_combat_exit.gd[/code]，本人只是它的注入点。
var combat_system: Node = null

## DeckEditingSystem 引用——卡组查看的数据源（HUD 注入；null 时面板回退 Autoload）。
var deck_system: Node = null

## CardSystem 引用——卡组行的名称/稀有度取模板（HUD 注入；null 时同上回退）。
var card_system: Node = null

## 动画开关——测试注入 + reduce-motion 预留接线点（先例
## NotificationToastArea.animate）。
var animate: bool = true

## === 节点引用 ==================================================================

@onready var _blur_rect: ColorRect = $MaskLayer/BlurRect
@onready var _mask: Control = $MaskLayer
@onready var _save_exit_button: Button = $Panel/VBox/SaveExitButton
@onready var _return_button: Button = $Panel/VBox/ReturnButton
@onready var _progress_label: Label = $Panel/VBox/ProgressLabel
@onready var _status_label: Label = $Panel/VBox/StatusLabel

## 活跃模糊 Tween 引用——重开/关闭时 kill 防悬挂回调（code-review T-1）。
## [br]已移交 [PauseMenuPauseCycle]（本组件不再直接建 Tween，只持有那个内核）。
var _cycle: RefCounted = null

## 动作编排层实例（懒建一次；注入引用每次透传）。
var _actions: RefCounted = null

## 场景变体 + 二次确认编排层实例（懒建一次，见 [PauseMenuState]）。
var _state: RefCounted = null

## 只读卡组查看面板的挂载层实例（懒建一次——见 [PauseMenuDeckHost]）。
var _deck_host: RefCounted = null

## 菜单项处理器集合实例（懒建一次——见 [PauseMenuHandlers]）。
var _handlers: RefCounted = null

## === 生命周期 ==================================================================

func _ready() -> void:
	visible = false
	_blur_rect.material.set(&"shader_parameter/blur_amount", 0.0)
	# 变体编排层绑定（按钮引用在此一次性交给它——路径只在本文件写一遍）
	get_state().bind(self, _save_exit_button, _return_button)
	# 树拓扑变化时认领回自己的 MODAL 锁（见 _on_tree_changed 的原因说明）
	if not get_tree().tree_changed.is_connected(_on_tree_changed):
		get_tree().tree_changed.connect(_on_tree_changed)

func _exit_tree() -> void:
	if is_inside_tree() and get_tree().tree_changed.is_connected(_on_tree_changed):
		get_tree().tree_changed.disconnect(_on_tree_changed)

## 树一变就回认 MODAL 锁——判定与理由全在
## [method PauseMenuPauseCycle.reclaim_lock_if_owner]（接线点必须落在场景节点上：
## Autoload 看不到「菜单是否开着」，而漏认一次玩家就被卡在关不掉的菜单里）。
func _on_tree_changed() -> void:
	get_cycle().reclaim_lock_if_owner()

## ESC 关闭兜底（code-review B-3——模态拥有者自判模式）。[br]
## [br]菜单打开时 InputManager（PAUSABLE）被冻结且 MODAL 锁阻断其 [code]_input[/code]
## 拦截——本组件（tscn 根节点 [code]process_mode = 3[/code] ALWAYS）在
## [code]_unhandled_input[/code] 兜底接收；先经 [method InputManager.has_lock]
## 确认自己仍是活跃模态拥有者（[code]is_input_allowed[/code] MODAL 分支声明的
## owner-check 设计）。[br]
## [br][b]分层判定与焦点回锚全归 [method PauseMenuState.handle_esc][/b]（确认框 →
## 卡组面板 → 读档面板 → 菜单，一次只退一层）：共用一个键时必须一层层退，
## 否则玩家按一下 ESC 就被打回游戏，连自己在哪个框里都来不及看清。
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	if event.keycode != KEY_ESCAPE or not event.pressed or event.echo:
		return
	if not InputManager.has_lock(LOCK_SOURCE):
		return
	get_viewport().set_input_as_handled()
	if get_state().handle_esc():
		_clear_status()
		return
	request_close()

## === 统一入口（GAP-3 裁决——三路汇入）==========================================

## 请求打开/关闭暂停菜单。[br]
## [br][param source] 来源标识（[code]&"esc"[/code] / [code]&"button"[/code] /
## [code]&"combat_ui"[/code]——区分来源，行为统一）。[br]
## 已打开时幂等——不重复执行打开流程（AC-6 edge）。[br]
## [br][b]开合五步归 [PauseMenuPauseCycle][/b]（锁 / 暂停 / 音频 / 显示 / 模糊，
## 顺序不可拆）；本方法只做「幂等守卫 + 打开后要刷新的那几行字」。
func request_open(source: StringName) -> void:
	if visible:
		push_warning("PauseMenu.request_open: 菜单已打开（source=%s）——幂等跳过" % source)
		return
	get_cycle().acquire()
	_clear_status()
	_refresh_progress_row()
	# 场景变体：按当前场景落定「保存并退出」可见性 + 焦点起点（顺序在 grab 之前）
	get_state().apply_variant()

## 关闭暂停菜单（严格逆序——pop 锁在最后）。[br]
## [br]未打开时幂等：不暂停、不动锁栈、不调 adapter（G-3）。[br]
## [br][b]已经在关的守卫也在这里[/b]：转场路径（保存并退出 / 投降 / 读档成功）
## 会先收起覆盖层再调本方法，重复进入 [method _release_pause] 会 pop 两次锁
## ——症状是 InputManager 的「source not found」告警加一把被别人捡走的锁。
func request_close() -> void:
	if not visible:
		return
	_release_pause()

## === 菜单项路由（知识全在各自的编排层，此处只转发）=============================

func _on_continue_pressed() -> void:
	request_close()

## 查看卡组——打开[b]只读[/b]卡组查看面板（见 [PauseMenuDeckView] / [PauseMenuDeckHost]）。
func _on_deck_view_pressed() -> void:
	get_handlers().open_deck_view()

## 系统设置——发导航请求（界面本体归 main-menu epic，Out of Scope）。
func _on_settings_pressed() -> void:
	get_handlers().request_settings()

## 存档——成功给「已存档」，失败给原因（磁盘满 / 校验不过 / 依赖缺失）。
func _on_save_pressed() -> void:
	get_handlers().save_now()

## 读档——打开槽位选择面板（复用主菜单那份 LoadSlotPanel）。
func _on_load_pressed() -> void:
	get_handlers().open_load_panel()

## 玩家在读档面板选中一格——面板已自行收起（先收再报意图）。
func _on_load_slot_chosen(p_slot_type: int, p_slot_id: int) -> void:
	get_handlers().load_slot_chosen(p_slot_type, p_slot_id)

## 读档面板「返回」——面板已自行收起，焦点还给菜单默认按钮。
func _on_load_panel_back() -> void:
	get_handlers().restore_focus()

## 卡组查看面板「返回」——同一套回锚口径（面板已自行收起）。
func _on_deck_view_back() -> void:
	get_handlers().restore_focus()

## 读档面板若开着则收起；返回「是否真的收掉了」（ESC 分层的第二层）。
## [br]ESC 分层判定归 [PauseMenuState]，面板开合归动作层——本方法只是那条链的名字。
func close_load_panel_if_open() -> bool:
	return get_handlers().close_load_panel_if_open()

## 卡组查看面板若开着则收起；返回「是否真的收掉了」（ESC 分层的第三层）。
func close_deck_view_if_open() -> bool:
	return get_handlers().close_deck_view_if_open()

## 保存并退出（GAP-5 裁决 + 二次确认）——先弹确认框；确认后才存档并离开。
func _on_save_exit_pressed() -> void:
	get_handlers().confirm_save_exit()

## 返回主菜单（GAP-5 裁决 + 二次确认）——先弹确认框。三键对应「确认保存 /
## 不保存 / 取消」，战斗中的前两者都走投降（见 [method PauseMenuState.resolve_outcome]）。
func _on_return_main_menu_pressed() -> void:
	get_handlers().confirm_return()

## 确认框结果落地（[signal PauseMenuConfirm.outcome_chosen] 的唯一消费者——
## 委托 [PauseMenuState.resolve_outcome]）。本方法只做转发：宿主是信号接收端，
## 「确认之后走哪条退出链」是变体编排层的知识。
func _on_confirm_outcome(outcome: int) -> void:
	get_handlers().resolve_outcome(outcome)

## 遮罩点击——等效「继续游戏」（UX 规格退出点表）。
func _on_mask_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		request_close()

## === 内部方法 ==================================================================

## 解除暂停并收起菜单（关闭与「转场前离开」两条路径共用——顺序注记见
## [method PauseMenuHandlers.release_pause]）。
func _release_pause() -> void:
	get_handlers().release_pause()

## 探索进度行刷新（GAP-2 降级裁决——「层 N」由动作层现读 GSM 求得）。
func _refresh_progress_row() -> void:
	get_handlers().refresh_progress_row()

## 反馈行显示（存档 / 读档结果——成功/失败两档颜色见
## [method PauseMenuHandlers.show_status]）。
func _show_status(p_text: String, p_ok: bool) -> void:
	get_handlers().show_status(p_text, p_ok)

## 清空反馈行（打开菜单 / 再次发起动作时——上一条结果与这一次无关）。
func _clear_status() -> void:
	get_handlers().clear_status()

## 菜单项处理器集合——懒建一次并绑定宿主与反馈行（控件的 [code]@onready[/code]
## 路径只在 [method _ready] 之后才有值，故绑定推迟到那时）。
func get_handlers() -> RefCounted:
	if _handlers == null:
		_handlers = HandlersScript.new()
		_handlers.call(&"bind", self, _status_label)
	return _handlers

## 开合配对内核（锁 / 暂停 / 音频 / 模糊五步）——懒建一次并绑定宿主引用与
## 模糊控件（控件的 [code]@onready[/code] 路径只在 [method _ready] 之后才有值）。
func get_cycle() -> RefCounted:
	if _cycle == null:
		_cycle = CycleScript.new()
		_cycle.call(&"bind", self, _blur_rect, BLUR_DURATION, LOCK_SOURCE)
	return _cycle

## 动作编排层——懒建一次，注入引用每次透传（一条即断，避免持有过期引用）。[br]
## [br][b]gsm 的 Autoload 回退[/b]：生产由 HUD 注入，测试可直连替换；
## 两者都没有时回退 [code]/root/GameStateManager[/code]（Autoload 节点，
## 不是 Engine singleton——[code]Engine.has_singleton[/code] 对其恒 false）。
func get_actions() -> RefCounted:
	if _actions == null:
		_actions = ActionsScript.new()
	var gsm_ref: Node = gsm
	if gsm_ref == null:
		gsm_ref = get_node_or_null("/root/GameStateManager")
	_actions.scene_manager = scene_manager
	_actions.save_load = save_load
	_actions.gsm = gsm_ref
	return _actions

## 场景变体 + 二次确认编排层——懒建一次，宿主引用在此一次性交给它（同
## [method get_actions] 的口径：一条即断，避免持有过期引用）。[br]
## [br][b]scene_manager 的现取[/b]：本层每次都读宿主当前的 [member scene_manager]
## 注入值（测试可在开菜单前替换它——见 [method PauseMenuState.current_scene_id]）。
func get_state() -> RefCounted:
	if _state == null:
		_state = StateScript.new()
	return _state

## 只读卡组查看面板的挂载层——懒建一次并绑定宿主（依赖每次现取，见
## [method PauseMenuDeckHost.open]）。[br]
## [br][b]点「查看卡组」才建树[/b]——本方法不在 [code]_ready[/code] 里预先调用
## （理由见 [PauseMenuDeckHost] 类文档「为什么懒建」）。
func get_deck_host() -> RefCounted:
	if _deck_host == null:
		_deck_host = DeckHostScript.new()
		_deck_host.call(&"bind", self)
	return _deck_host
