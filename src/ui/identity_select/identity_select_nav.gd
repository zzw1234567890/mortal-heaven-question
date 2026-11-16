extends RefCounted
## IdentitySelectNav —— 身份选择场景的导航与音频接线（从 identity_select.gd 拆出）。
##
## 三件事，都是「场景进出」这一层的事，与卡片交互无关：[br]
##   ① 读档跳过判定（[code]is_identity_selected()[/code] 为真 → 不进选择 UI）；[br]
##   ② 转场请求（一律走 [code]SceneManager.request_scene_change[/code]——
##      control-manifest 必需，绝不直调 [code]change_scene_to_file[/code]）；[br]
##   ③ 入场音频状态（AudioManager 现有 [code]set_state[/code]）。[br]
##
## [br][b]为什么要等 [signal SceneManager.post_transition][/b]：[code]_ready()[/code]
## 期间 SceneManager 的 [code]_transitioning[/code] 仍为 true（Phase 2 置 true、
## Phase 5 才置 false），此刻直接请求会被并发守卫静默拒绝（返回 false），
## 玩家卡在空场景。必须等信号后再 [code]call_deferred[/code] 请求。[br]
## [br]仅「场景加载瞬间的读档跳过」需要这一手；玩家点确认后的导航发生在转场早已
## 完成之时，可直接调用。
##
## [br]来源: ADR-0005（导航唯一入口）、ADR-0031、control-manifest §Presentation。

## SceneManager 脚本常量——SceneID / TransitionType 枚举真理来源（preload 引用
## 不依赖 Autoload 实例存在，先例 main_menu SceneManagerScript）。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
## AudioEnums 脚本常量——AudioState 枚举真理来源。
const AudioEnumsScript := preload("res://src/ui/audio/audio_enums.gd")
## InputManager 脚本常量——ActionType / DeviceType 枚举真理来源。
const InputManagerScript := preload("res://src/foundation/input_manager.gd")

## 宿主场景节点（取 Autoload 回退用）。
var host: Node = null
## 注入的 SceneManager（测试替换；null 时回退 Autoload）。
var scene_manager: Node = null
## 注入的 IdentitySelectionSystem（测试替换；null 时回退 Autoload）。
var identity_system: Node = null
## 转场完成后的回调目标（[code]call_deferred[/code] 调用——转场完成时
## [signal scene_manager.post_transition] 带 2 个参数，而导航请求本身不带参数，
## 故经本类的方法中转一次）。
var on_transition_target: Callable = Callable()


# === 读档跳过 ===================================================================

## 是否需要跳过选择 UI——消费 [code]is_identity_selected()[/code]。
func is_skip_needed() -> bool:
	var isys: Node = get_identity_system()
	if isys != null and isys.has_method(&"is_identity_selected"):
		return bool(isys.is_identity_selected())
	return false


## 请求跳到探索——挂 [signal scene_manager.post_transition] 一次性回调，
## 转场完成后再 defer 请求导航（见文件头「为什么要等」）。[br]
## [br][b]返回[/b]: 是否成功挂上（SceneManager 不可用时 false + push_error）。
func skip_to_exploration() -> bool:
	var sm: Node = get_scene_manager()
	if sm == null or not sm.has_signal(&"post_transition"):
		push_error("IdentitySelect: SceneManager 不可用——读档跳过中止")
		return false
	sm.post_transition.connect(_on_scene_transition, CONNECT_ONE_SHOT)
	return true


## [signal scene_manager.post_transition] 处理——信号带 [code](from, to)[/code]，
## 而导航请求不带参数；且必须 [code]call_deferred[/code]（信号发射瞬间
## [code]_transitioning[/code] 可能尚未落回 false）。
func _on_scene_transition(_from: int, _to: int) -> void:
	if on_transition_target.is_valid():
		on_transition_target.call_deferred()


# === 导航请求 ===================================================================

## 请求导航到探索地图（读档跳过 + 叙事结束两条路径共用）。[br]
## [b]注意[/b]：EXPLORATION 场景为占位路径（exploration story 002 落盘后自动生效）。
func request_exploration() -> void:
	var sm: Node = get_scene_manager()
	if sm == null or not sm.has_method(&"request_scene_change"):
		return
	var from_id: int = SceneManagerScript.SceneID.IDENTITY_SELECT
	if sm.has_method(&"get_current_scene_id"):
		from_id = sm.get_current_scene_id()  # Phase 5 后已更新为 IDENTITY_SELECT
	sm.request_scene_change(from_id,
			SceneManagerScript.SceneID.EXPLORATION,
			SceneManagerScript.TransitionType.MENU_TO_GAME)


# === 音频（最小触发——AC-10）====================================================

## 入场音频状态——调用 AudioManager 现有 [code]set_state[/code]。[br]
## [b]Deviations[/b]：无确切编钟/古琴 SFX id，触发
## [code]set_state(AudioState.IDENTITY_SELECT)[/code] 作为最小接入；音频资产归属
## audio story 004。
func trigger_audio_state() -> void:
	var sm: Node = get_scene_manager()
	if sm == null or not sm.has_method(&"get_audio_manager"):
		return
	var am = sm.get_audio_manager()
	if am != null and am.has_method(&"set_state"):
		am.set_state(AudioEnumsScript.AudioState.IDENTITY_SELECT)


# === 依赖获取 ===================================================================

## 输入锁栈判定——确认按钮改变游戏状态必须过
## [code]InputManager.is_input_allowed[/code]（ADR-0004 公共 API）。[br]
## [br][b]设备判定[/b]：[code]Button.pressed[/code] 信号不携带触发设备，确认按钮主路径
## 为鼠标点击，恒判 [code]DeviceType.MOUSE[/code]（GAMEPLAY 分类）；键盘 Enter 激活
## 的设备区分属 focus/gamepad 细化（story Out of Scope）。[br]
## [br]InputManager 不可用时放行（测试 mock 场景无 Autoload）。
func is_input_allowed() -> bool:
	if host == null:
		return true
	var im: Node = host.get_node_or_null("/root/InputManager")
	if im == null or not im.has_method(&"is_input_allowed"):
		return true
	return bool(im.is_input_allowed(
			InputManagerScript.ActionType.GAMEPLAY,
			InputManagerScript.DeviceType.MOUSE))


## 获取 SceneManager——注入对象优先，否则回退 Autoload（先例 main_menu）。
func get_scene_manager() -> Node:
	if scene_manager != null:
		return scene_manager
	if host == null:
		return null
	return host.get_node_or_null("/root/SceneManager")


## 获取 IdentitySelectionSystem——注入对象优先，否则回退 Autoload。
func get_identity_system() -> Node:
	if identity_system != null:
		return identity_system
	if host == null:
		return null
	return host.get_node_or_null("/root/IdentitySelectionSystem")
