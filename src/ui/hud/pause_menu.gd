class_name PauseMenu
extends Control
## PauseMenu —— 暂停菜单组件（hud Story 005）。
##
## [b]结构[/b]：[code]MaskLayer[/code]（全屏 BackBufferCopy + ColorRect 模糊遮罩，
## 点击等效「继续游戏」）+ [code]Panel[/code]（居中面板：标题/5 按钮/分隔线/进度行）。[br]
## [br][b]流程[/b]（ADR-0031 §1.1——打开/关闭严格配对）：[br]
## 打开 = InputManager.push_lock(MODAL, &"pause_menu") →
## [code]SceneTree.paused = true[/code] → adapter.suspend() → 显示（0.3s 模糊动画）。[br]
## 关闭 = adapter.resume() → [code]SceneTree.paused = false[/code] → 隐藏 →
## InputManager.pop_lock(&"pause_menu")（pop 锁在最后）。[br]
## [br][b]统一入口[/b]（GAP-3 裁决）：HUD 暴露 [code]hud.request_pause(source)[/code]
## 三路汇入本组件 [method request_open]——ESC 信号/暂停按钮/combat-ui 转发。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：探索进度行不缓存——打开时从
## GSM.exploration 第一层直接属性读取 [code]node_position.layer + 1[/code]（0 基转
## 1 基，GAP-2 降级裁决——仅显示「层 N」，不建 map_id 映射表）。[br]
## [br][b]退出语义[/b]（GAP-5 裁决）：保存并退出 = SaveLoadSystem 存档后返主菜单；
## 返回主菜单 = 直接转场（从简无二次确认）。[br]
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
## [code]has_lock()[/code] 自行判定输入）。
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

## === 依赖注入（测试可替换）=====================================================

## 音频暂停 adapter——默认 no-op 桩；测试注入 mock 记录调用（AC-3）。
var audio_adapter: PauseAudioAdapter = null

## SceneManager 引用——退出路由转场用（HUD 注入，避免直引 Autoload）。
var scene_manager: Node = null

## SaveLoadSystem 引用——「保存并退出」存档用（HUD 注入）。
var save_load: Node = null

## 动画开关——测试注入 + reduce-motion 预留接线点（先例
## NotificationToastArea.animate）。
var animate: bool = true

## === 节点引用 ==================================================================

@onready var _blur_rect: ColorRect = $MaskLayer/BlurRect
@onready var _mask: Control = $MaskLayer
@onready var _continue_button: Button = $Panel/VBox/ContinueButton
@onready var _progress_label: Label = $Panel/VBox/ProgressLabel

## 活跃模糊 Tween 引用——重开/关闭时 kill 防悬挂回调（code-review T-1）。
var _blur_tween: Tween = null

## === 生命周期 ==================================================================

func _ready() -> void:
	visible = false
	_blur_rect.material.set(&"shader_parameter/blur_amount", 0.0)

## ESC 关闭兜底（code-review B-3——模态拥有者自判模式）。[br]
## [br]菜单打开时 InputManager（PAUSABLE）被 [code]SceneTree.paused[/code] 冻结
## 且 MODAL 锁阻断其 [code]_input[/code] 拦截——本组件（tscn 根节点
## [code]process_mode = 3[/code] ALWAYS）在 [code]_unhandled_input[/code]
## 兜底接收 ESC。先经 [method InputManager.has_lock] 确认自己仍是活跃模态
## 拥有者（[code]is_input_allowed[/code] MODAL 分支声明的 owner-check 设计），
## 再关闭并标记输入已处理（阻止后续节点重复响应）。
func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE \
			and event.pressed and not event.echo:
		if InputManager.has_lock(LOCK_SOURCE):
			get_viewport().set_input_as_handled()
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
	_refresh_progress_row()
	if animate:
		if _blur_tween != null:
			_blur_tween.kill() # 防悬挂 Tween 回调（T-1——快速重开场景）
		_blur_tween = create_tween()
		_blur_tween.tween_method(_set_blur, 0.0, 1.0, BLUR_DURATION)
	# 键盘导航起点锚定（4.6 双焦点：grab_focus 只影响键盘/手柄焦点——Engine Notes）
	_continue_button.grab_focus()

## 关闭暂停菜单（严格逆序——pop 锁在最后）。
func request_close() -> void:
	if not visible:
		return
	if _blur_tween != null:
		_blur_tween.kill() # 关闭时终止进行中的模糊动画（T-1）
		_blur_tween = null
	_set_blur(0.0) # 复位模糊强度——下次打开从 0 起始
	if audio_adapter != null:
		audio_adapter.resume()
	get_tree().paused = false
	visible = false
	InputManager.pop_lock(LOCK_SOURCE)

## === 菜单项路由 ================================================================

func _on_continue_pressed() -> void:
	request_close()

## 查看卡组——发导航请求（界面本体归 deck-editing-ui epic，Out of Scope）。
func _on_deck_view_pressed() -> void:
	deck_view_requested.emit()

## 系统设置——发导航请求（界面本体归 main-menu epic，Out of Scope）。
func _on_settings_pressed() -> void:
	settings_requested.emit()

## 保存并退出（GAP-5 裁决）——存档后返主菜单；存档失败保持菜单打开不丢进度。[br]
## [br][b]防御[/b]（code-review M-1）：save_load 为 null 或缺 save_game 方法时
## push_error 并保持菜单打开（不静默丢档、不退出）。
func _on_save_exit_pressed() -> void:
	if save_load == null or not save_load.has_method(&"save_game"):
		push_error("PauseMenu: save_load 不可用——保存并退出中止，保持菜单打开")
		return
	var payload: Dictionary = _serialize_gsm()
	if payload.is_empty():
		# GSM 序列化失败（_serialize_gsm 已 push_error）——走失败分支，
		# 不以空载荷覆盖 autosave 槽位（code-review H-1 修正语义）。
		return
	var result: int = save_load.save_game(
			SaveLoadSystem.SaveSlotType.AUTOSAVE, 0, payload, {})
	if result != SaveLoadSystem.SaveResult.SUCCESS:
		push_error("PauseMenu: 保存失败（code=%d）——保持菜单打开，不退出" % result)
		return
	_return_to_main_menu()

## 返回主菜单（GAP-5 裁决）——不存档直接转场（本 story 从简无二次确认）。
func _on_return_main_menu_pressed() -> void:
	_return_to_main_menu()

## 遮罩点击——等效「继续游戏」（UX 规格退出点表）。
func _on_mask_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		request_close()

## === 内部方法 ==================================================================

## GSM 序列化（存档载荷）——防御式读取，GSM 不可用时 push_error 并返回空字典[br]
## （调用方以空字典走存档失败分支，不以空载荷覆盖 autosave——code-review H-1）。[br]
## [br]注意：GSM 是 Autoload 节点（[code]/root/GameStateManager[/code]），
## [b]不是[/b] Engine singleton——[code]Engine.has_singleton()[/code] 对 Autoload
## 恒 false，不能用作探测分支（H-1 原实现即此死代码误判）。
func _serialize_gsm() -> Dictionary:
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm != null and gsm.has_method(&"serialize"):
		return gsm.serialize()
	push_error("PauseMenu: GameStateManager 不可用——存档载荷序列化失败")
	return {}

## 返主菜单——解除暂停后经 SceneManager 转场（GAP-5 裁决路径）。[br]
## [br]from 取 [code]SceneManager.get_current_scene_id()[/code] 动态值
## （code-review M-2——去魔数 + 不假设调用场景；SceneManager 不可用时
## 缺省 EXPLORATION）。
func _return_to_main_menu() -> void:
	# 先解除暂停（逆序关闭流程），再转场——转场管线不含暂停恢复职责
	# Tween 清理与 request_close 保持一致（code-review 复审 LOW——两条关闭
	# 路径清理对称；HUD 跨场景存续，悬挂 tween 会继续跑完 0.3s）
	if _blur_tween != null:
		_blur_tween.kill()
		_blur_tween = null
	_set_blur(0.0)
	if audio_adapter != null:
		audio_adapter.resume()
	get_tree().paused = false
	visible = false
	InputManager.pop_lock(LOCK_SOURCE)
	var from_id: int = SceneManager.SceneID.EXPLORATION # 缺省值（守卫失败回退）
	if scene_manager != null and scene_manager.has_method(&"get_current_scene_id"):
		from_id = scene_manager.get_current_scene_id()
	else:
		push_warning("PauseMenu: scene_manager 不可用——转场 from 缺省 EXPLORATION")
	if scene_manager != null and scene_manager.has_method(&"request_scene_change"):
		scene_manager.request_scene_change(from_id,
				SceneManager.SceneID.MAIN_MENU,
				SceneManager.TransitionType.GAME_TO_MENU)

## 探索进度行刷新（GAP-2 降级裁决）——「层 N」= node_position.layer + 1（0 基转 1 基）。
## 零状态所有权：打开时从 GSM 第一层直接属性读取，不缓存副本（ADR-0031 §2）。
func _refresh_progress_row() -> void:
	var layer_display: int = 1
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm != null:
		var exploration: Dictionary = {}
		# gsm.get 为 Variant——先判型再赋给类型化 Dictionary（外层 null 防御，
		# code-review 复审 LOW；GSM 恒有 exploration 属性，此为防御式写法）
		if gsm.get("exploration") is Dictionary:
			exploration = gsm.get("exploration")
		# node_position 键存在但值为 null 时 Dictionary.get 默认值不生效
		# （仅缺失键才回退）——显式 null 防御（code-review M-3）
		var node_pos: Dictionary = {}
		if exploration.get("node_position") is Dictionary:
			node_pos = exploration["node_position"]
		layer_display = int(node_pos.get("layer", 0)) + 1
	_progress_label.text = "探索进度：层 %d" % layer_display

## 模糊强度设置（Tween tween_method 目标）。
func _set_blur(value: float) -> void:
	_blur_rect.material.set(&"shader_parameter/blur_amount", value)
