class_name PauseMenu
extends Control
## PauseMenu —— 暂停菜单组件（hud Story 005）。
##
## [b]结构[/b]：[code]MaskLayer[/code]（全屏 BackBufferCopy + ColorRect 模糊遮罩，
## 点击等效「继续游戏」）+ [code]Panel[/code]（居中面板：标题 / 7 按钮 / 分隔线 /
## 进度行 / 操作反馈行）。[br]
## [br][b]流程[/b]（ADR-0031 §1.1——打开/关闭严格配对）：[br]
## 打开 = InputManager.push_lock(MODAL, &"pause_menu") →
## [code]SceneTree.paused = true[/code] → adapter.suspend() → 显示（0.3s 模糊动画）。[br]
## 关闭 = adapter.resume() → [code]SceneTree.paused = false[/code] → 隐藏 →
## InputManager.pop_lock(&"pause_menu")（pop 锁在最后）。[br]
## [br][b]统一入口[/b]（GAP-3 裁决）：HUD 暴露 [code]hud.request_pause(source)[/code]
## 三路汇入本组件 [method request_open]——ESC 信号/暂停按钮/combat-ui 转发。[br]
## [br][b]存档 / 读档 / 返回主菜单三条动作不在本文件[/b]（[PauseMenuActions]）：
## 「按了存档之后写哪一格、读档走哪条导航链、离开前存不存」与「按钮怎么摆、模糊
## 动画怎么放、ESC 从哪进来」是两件事——后者才是本组件的职责。本文件只做三件事：
## 把按钮接到动作层、把结果翻成一行反馈、管好暂停开合（锁栈配对只此一处）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：探索进度行与存档反馈都由动作层现取现算，
## 打开时刷新、关闭后不缓存。[br]
## [br][b]退出语义[/b]（GAP-5 裁决）：保存并退出 = 存档成功后返主菜单（失败留在菜单
## 里给原因）；返回主菜单 = 先自动存档一次再转场。[br]
## [br][b]两条都需要二次确认[/b]（无障碍要求）：按下先弹 [PauseMenuConfirm]，
## 确认后才走上面那条链；「取消」与 ESC 同义。确认编排在 [PauseMenuState]。[br]
## [br][b]按场景调按钮可见性[/b]（本轮补）：战斗中/商店事件中隐藏「保存并退出」
## （不可存档），焦点起点自动跳过隐藏与置灰的按钮——判定纯函数在 [PauseMenuLayout]，
## 落地在 [PauseMenuState.apply_variant]。[br]
## [br][b]导航请求[/b]：查看卡组/系统设置目标界面不在本 story——发信号留桩，
## 不实现界面本体（Out of Scope）。[br]
## [br][b]引擎注记[/b]：[code]grab_focus()[/code] 在 4.6 双焦点下只影响键盘/手柄
## 焦点不影响鼠标（story Engine Notes）；本组件无 [code]_process()[/code]
## （模糊动画走 Tween，输入驱动纯视觉变换豁免 ADR-0031 §3）。[br]
## [br][b]暂停中输入前提[/b]（code-review G-6）：按钮/遮罩点击与 ESC 关闭在
## 暂停中可响应，依赖 tscn 根节点 [code]process_mode = 3[/code]（ALWAYS）——
## 场景树暂停时本组件仍处理输入/信号。[br]
## [br][b]ESC 关闭路径[/b]（code-review B-3）：菜单打开时 InputManager 被
## PAUSABLE 冻结 + MODAL 锁阻断（不 emit [code]pause_requested[/code]），
## 本组件在 [code]_unhandled_input[/code] 兜底接收 ESC——模态拥有者自判模式
## （[code]is_input_allowed[/code] MODAL 分支注释声明的设计：拥有者经
## [code]has_lock()[/code] 自行判定输入）。ESC 分层（三层）：确认框开着时先收确认框
## → 读档面板开着时先收面板 → 都没有才关菜单（判定归 [PauseMenuState.handle_esc]）。
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
## 确认框结果取值镜像——[code]PauseMenuConfirm[/code] 是真理来源。
const OUTCOME_SAVE_EXIT: int = 0
const OUTCOME_LEAVE: int = 1
## 确认框类型镜像（两个按钮各自对应一种）。
const CONFIRM_SAVE_EXIT: int = 0
const CONFIRM_RETURN: int = 1

## 反馈行成功态色——松石青 #4A9494（与通知区域 green 档同源「正向」编码）。
const COLOR_STATUS_OK: Color = Color("#4A9494")
## 反馈行失败态色——朱砂红 #B3424A（警报编码复用先例 lingshi_deck_bar / exploration_info_area）。
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
var _blur_tween: Tween = null

## 动作编排层实例（懒建一次；注入引用每次透传）。
var _actions: RefCounted = null

## 场景变体 + 二次确认编排层实例（懒建一次，见 [PauseMenuState]）。
var _state: RefCounted = null

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

## 树一变就回认 MODAL 锁。[br]
## [br][b]为什么必须认回来[/b]：[code]InputManager[/code] 对
## [code]SceneTree.tree_changed[/code] 挂了一张「场景切换就清锁」的安全网，而它
## [b]分不清「换场景」与「同一场景里插了个子节点」[/b]——暂停期间必然有树变
## （本菜单自己插读档面板、通知区域弹 Toast）。锁一没，「暂停中屏蔽下层输入」与
## [method _unhandled_input] 的 ESC owner-check[b]同时失效[/b]，玩家被卡在一个
## 关不掉的菜单里。[br]
## [br][b]只在锁栈空时认领[/b]：栈非空说明另有活跃模态（转场锁、别人的弹窗），
## 此时不抢——ESC 归它（[method _unhandled_input] 的 [code]has_lock[/code] 据此放行）。
## [br][b]顺序确定[/b]：Autoload 的 [code]_ready[/code] 先于场景节点，InputManager
## 先清、本组件后认，故每次树变后栈深恰好回到 1（不累积）。
func _on_tree_changed() -> void:
	if visible and is_inside_tree() and InputManager.get_lock_stack().is_empty():
		InputManager.push_lock(InputManager.LockType.MODAL, LOCK_SOURCE)

## ESC 关闭兜底（code-review B-3——模态拥有者自判模式）。[br]
## [br]菜单打开时 InputManager（PAUSABLE）被 [code]SceneTree.paused[/code] 冻结
## 且 MODAL 锁阻断其 [code]_input[/code] 拦截——本组件（tscn 根节点
## [code]process_mode = 3[/code] ALWAYS）在 [code]_unhandled_input[/code]
## 兜底接收 ESC。先经 [method InputManager.has_lock] 确认自己仍是活跃模态
## 拥有者（[code]is_input_allowed[/code] MODAL 分支声明的 owner-check 设计），
## 再关闭并标记输入已处理（阻止后续节点重复响应）。[br]
## [br][b]分层[/b]（本轮由两层变三层）：确认框开着时第一下先收确认框（取消），
## 读档面板开着时先收面板（取消选槽），都没有才关整个菜单——三件事共用一个键时
## 必须一层层退。分层判定与焦点回锚都归 [method PauseMenuState.handle_esc]。
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
## 已打开时幂等——不重复执行打开流程（AC-6 edge）。
func request_open(source: StringName) -> void:
	if visible:
		push_warning("PauseMenu.request_open: 菜单已打开（source=%s）——幂等跳过" % source)
		return
	InputManager.push_lock(InputManager.LockType.MODAL, LOCK_SOURCE)
	get_tree().paused = true
	if audio_adapter != null:
		audio_adapter.suspend()
	visible = true
	_clear_status()
	_refresh_progress_row()
	# 场景变体：按当前场景落定「保存并退出」可见性 + 焦点起点（顺序在 grab 之前）
	get_state().apply_variant()
	if animate:
		if _blur_tween != null:
			_blur_tween.kill() # 防悬挂 Tween 回调（T-1——快速重开场景）
		_blur_tween = create_tween()
		_blur_tween.tween_method(_set_blur, 0.0, 1.0, BLUR_DURATION)

## 关闭暂停菜单（严格逆序——pop 锁在最后）。[br]
## [br]未打开时幂等：不暂停、不动锁栈、不调 adapter（G-3）。
func request_close() -> void:
	if not visible:
		return
	_release_pause()

## === 菜单项路由 ================================================================

func _on_continue_pressed() -> void:
	request_close()

## 查看卡组——发导航请求（界面本体归 deck-editing-ui epic，Out of Scope）。
func _on_deck_view_pressed() -> void:
	deck_view_requested.emit()

## 系统设置——发导航请求（界面本体归 main-menu epic，Out of Scope）。
func _on_settings_pressed() -> void:
	settings_requested.emit()

## 存档——成功给「已存档」，失败给原因（磁盘满 / 校验不过 / 依赖缺失）。[br]
## [br][b]失败不关菜单、不退出[/b]：玩家留在菜单里能再试一次或换个动作，
## 比静默丢档强（动作层返回失败文案，本层只负责显示）。
func _on_save_pressed() -> void:
	var outcome: Dictionary = get_actions().save_now()
	_show_status(str(outcome.get("message", "")),
			bool(outcome.get("ok", false)))

## 读档——打开槽位选择面板（复用主菜单那份 LoadSlotPanel）。[br]
## [br]列表每次现取（[method PauseMenuActions.loadable_entries]）——停留期间
## 槽位可能已被刚写的存档改变。
func _on_load_pressed() -> void:
	_clear_status()
	get_actions().open_load_panel(self)

## 玩家在读档面板选中一格——面板已自行收起（先收再报意图）。[br]
## [br][b]成功才解除暂停[/b]：动作层在能续玩时已发出转场请求，转场管线不含暂停
## 恢复职责，冻结态下新场景会停在冻结帧；失败则留在菜单里给一句交代。
func _on_load_slot_chosen(p_slot_type: int, p_slot_id: int) -> void:
	var outcome: Dictionary = get_actions().load_slot(p_slot_type, p_slot_id)
	if bool(outcome.get("navigated", false)):
		_release_pause()
		return
	_show_status(str(outcome.get("message", "")), false)

## 读档面板「返回」——面板已自行收起。收起后把键盘/手柄焦点还给菜单的默认按钮：
## 面板按钮一隐藏，焦点就悬空，键盘玩家会觉得「什么都按不动」（4.6 双焦点下
## 鼠标不受影响，只有键盘/手柄能感觉到）。[br]
## [br]回锚走 [method PauseMenuState.focus_default]（跳过隐藏/置灰者）——战斗中
## 「保存并退出」是隐藏的，硬抓它等于把焦点扔回一个看不见的按钮上。
func _on_load_panel_back() -> void:
	_clear_status()
	get_state().focus_default()

## 读档面板若开着则收起；返回「是否真的收掉了」（ESC 分层的第二层）。[br]
## [br][b]为什么要这一层包装[/b]：分层判定归 [PauseMenuState]（它不持面板引用），
## 面板开合归动作层——包一层让两边都不必知道对方的细节。
func close_load_panel_if_open() -> bool:
	if not get_actions().is_load_panel_open():
		return false
	get_actions().close_load_panel()
	return true

## 保存并退出（GAP-5 裁决 + 二次确认）——先弹确认框；确认后才存档并离开。[br]
## [br][b]为什么不在按下时就存[/b]：这是不可逆动作（存档后结束本次会话），
## 无障碍要求防误触（design/ux/pause-menu.md §Accessibility）。
func _on_save_exit_pressed() -> void:
	_clear_status()
	get_state().request_confirm(CONFIRM_SAVE_EXIT)

## 返回主菜单（GAP-5 裁决 + 二次确认）——先弹确认框。确认框里的三键对应：
## 确认 = 先存档再离开；不保存 = 直接离开（自动存档仍会顺手存一次底）；
## 取消 / ESC = 留在菜单。
func _on_return_main_menu_pressed() -> void:
	_clear_status()
	get_state().request_confirm(CONFIRM_RETURN)

## 确认框结果落地（[signal PauseMenuConfirm.outcome_chosen] 的唯一消费者——
## 委托 [PauseMenuState.resolve_outcome]）。本方法只做转发：宿主是信号接收端，
## 「确认之后走哪条退出链」是变体编排层的知识。
func _on_confirm_outcome(outcome: int) -> void:
	get_state().resolve_outcome(outcome)

## 遮罩点击——等效「继续游戏」（UX 规格退出点表）。
func _on_mask_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		request_close()

## === 内部方法 ==================================================================

## 解除暂停并收起菜单（关闭与「转场前离开」两条路径共用）。[br]
## [br][b]顺序不可反[/b]（ADR-0031 §1.1）：adapter.resume → [code]paused = false[/code]
## → 隐藏 → pop 锁（pop 在最后）。Tween 一并清理——HUD 跨场景存续，
## 悬挂的 tween 会在新场景里继续跑完 0.3s。
func _release_pause() -> void:
	if _blur_tween != null:
		_blur_tween.kill()
		_blur_tween = null
	_set_blur(0.0) # 复位模糊强度——下次打开从 0 起始
	# 确认框若还开着则一并收起——留一个「开着」的框在隐藏的菜单里，
	# 下次打开会看到上一次的确认框浮在菜单上（状态串味）
	get_state().close_confirm()
	if audio_adapter != null:
		audio_adapter.resume()
	get_tree().paused = false
	visible = false
	InputManager.pop_lock(LOCK_SOURCE)

## 探索进度行刷新（GAP-2 降级裁决）——「层 N」由动作层现读 GSM 求得
## （零状态所有权：本组件不缓存副本——ADR-0031 §2）。
func _refresh_progress_row() -> void:
	_progress_label.text = get_actions().progress_text()

## 反馈行显示（存档/读档结果）。[br]
## [br][param p_ok] 决定颜色档（松石青「正向」/ 朱砂红「警报」）——文案本身
## 已含原因（错误码），颜色只是让玩家不用读完就知道成没成。
func _show_status(p_text: String, p_ok: bool) -> void:
	_status_label.text = p_text
	_status_label.add_theme_color_override(&"font_color",
			COLOR_STATUS_OK if p_ok else COLOR_STATUS_FAIL)

## 清空反馈行（打开菜单 / 再次发起动作时——上一条结果与这一次无关）。
func _clear_status() -> void:
	_status_label.text = ""

## 模糊强度设置（Tween tween_method 目标）。
func _set_blur(value: float) -> void:
	_blur_rect.material.set(&"shader_parameter/blur_amount", value)

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
