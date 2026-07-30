extends Node
## SceneManager (Autoload #3) —— 场景转换的单一仲裁者。
##
## 所有场景转换必须通过 [method request_scene_change]——禁止任何系统直接调用
## [method SceneTree.change_scene_to_file]。[br]
## [br]
## [b]5 阶段异步转换管线[/b]:[br]
##   1. VALIDATE —— 并发守卫 + 场景 ID 存在性校验[br]
##   2. PRE-TRANSITION —— 锁输入 + 自动存档 + 发射 [signal pre_transition] 信号[br]
##   3. LOAD —— 加载画面 → 目标场景（两段式 change_scene_to_file）[br]
##   4. POST-LOAD —— GSM 写入 + 解锁输入 + 发射 [signal post_transition] 信号[br]
##   5. FINALIZE —— [member _transitioning] = false, [member _transition_type] = NONE[br]
## [br]
## [b]依赖注入[/b]: [method set_dependencies] 注入 GSM/InputManager/SaveLoad——单元测试可用
## 轻量 mock 对象替代真实 Autoload。[br]
## [br]
## [b]调用示例[/b]:[br]
## [codeblock]
##   SceneManager.request_scene_change(SceneManager.SceneID.EXPLORATION,
##                                     SceneManager.SceneID.COMBAT,
##                                     SceneManager.TransitionType.EXPLORE_TO_COMBAT)
## [/codeblock]

## === SceneID 枚举 ==============================================================

## 游戏内全部场景标识符——新增场景需同步更新 [constant SCENE_PATHS]。
enum SceneID {
	MAIN_MENU = 0,            ## 主菜单
	IDENTITY_SELECT = 1,      ## 开局身份选择
	DECK_EDITING = 2,         ## 卡组编辑
	EXPLORATION = 3,          ## 探索地图
	COMBAT = 4,               ## 战斗场景
	TRIBULATION = 5,          ## 渡劫场景
	SHOP = 6,                 ## 商店
	EVENT_PANEL = 7,          ## 事件面板
	RESULT_SCREEN = 8,        ## 战斗结算
	DEFEAT_SCREEN = 9,        ## 战败画面
	CULTIVATION = 10,         ## 修炼室
	LOADING = 99,             ## 加载画面（内部使用）
}

## === TransitionType 枚举 =======================================================

## 场景转换类型——驱动音频系统的 BGM 过渡矩阵（见 audio-system.md）。
enum TransitionType {
	NONE = 0,              ## 无转换（初始状态）
	MENU_TO_GAME = 1,      ## 主菜单→游戏（长淡入，1.5s BGM 过渡）
	GAME_TO_MENU = 2,      ## 游戏→主菜单（长淡出，1.5s BGM 过渡）
	EXPLORE_TO_COMBAT = 3, ## 探索→战斗（快速切入，0.5s BGM 过渡）
	COMBAT_TO_EXPLORE = 4, ## 战斗→探索（正常切回，1.0s BGM 过渡）
	TRIBULATION = 5,       ## 渡劫战斗（特殊 BGM，0.3s 过渡）
}

## === 信号 ======================================================================

## Cat 2a：转场前通知。Phase 2 发射——音频/HUD 做转场前准备。
## [param from] 源场景 ID，[param to] 目标场景 ID，[param type] 转换类型。
signal pre_transition(from: int, to: int, type: int)

## Cat 2a：转场后通知。Phase 4 发射——音频/HUD/探索初始化新场景。
## [param from] 源场景 ID，[param to] 目标场景 ID。
signal post_transition(from: int, to: int)

## === 场景路径注册表 ============================================================

## 编译时常量字典——所有场景文件路径的单一真理来源。O(1) 查询，无文件 I/O。
const SCENE_PATHS: Dictionary = {
	SceneID.MAIN_MENU:       "res://src/ui/main_menu/main_menu.tscn",
	SceneID.IDENTITY_SELECT: "res://src/ui/identity_select/identity_select.tscn",
	SceneID.DECK_EDITING:    "res://src/ui/deck_editing/deck_editing.tscn",
	SceneID.EXPLORATION:     "res://src/feature/exploration/exploration_scene.tscn",
	SceneID.COMBAT:          "res://src/feature/combat/combat_scene.tscn",
	SceneID.TRIBULATION:     "res://src/feature/tribulation/tribulation_scene.tscn",
	SceneID.SHOP:            "res://src/feature/shop/shop_scene.tscn",
	SceneID.EVENT_PANEL:     "res://src/ui/event_panel/event_panel.tscn",
	SceneID.RESULT_SCREEN:   "res://src/ui/result_screen/result_screen.tscn",
	SceneID.DEFEAT_SCREEN:   "res://src/ui/defeat_screen/defeat_screen.tscn",
	SceneID.CULTIVATION:     "res://src/feature/cultivation/cultivation_scene.tscn",
	SceneID.LOADING:         "res://src/ui/loading/loading_screen.tscn",
}

## === 音频过渡参数表 ==========================================================

## 编译时常量——TransitionType → BGM 过渡参数的映射表。[br]
## 音频系统通过 [signal pre_transition] 的 [code]type[/code] 参数索引本表。[br]
## [br][b]角色[/b]: SceneManager 提供数据契约——音频系统执行实际的 BGM 淡入/淡出。[br]
## [b]维护[/b]: 新增 TransitionType 值时必须同步向本表添加条目——否则音频系统
## 的 [code]match[/code] 语句将报 missing-branch 编译警告。
const TRANSITION_AUDIO_PARAMS: Dictionary = {
	TransitionType.MENU_TO_GAME: {
		duration_seconds = 1.5,
		from_behavior = &"fade_out",
		to_behavior = &"fade_in",
	},
	TransitionType.GAME_TO_MENU: {
		duration_seconds = 1.5,
		from_behavior = &"fade_out",
		to_behavior = &"fade_in",
	},
	TransitionType.EXPLORE_TO_COMBAT: {
		duration_seconds = 0.5,
		from_behavior = &"cut",
		to_behavior = &"fade_in",
	},
	TransitionType.COMBAT_TO_EXPLORE: {
		duration_seconds = 1.0,
		from_behavior = &"fade_out",
		to_behavior = &"fade_in",
	},
	TransitionType.TRIBULATION: {
		duration_seconds = 0.3,
		from_behavior = &"cut",
		to_behavior = &"cut",
	},
}

## === 内部状态 ==================================================================

## 转场进行中标志——true 时拒绝所有新的转换请求。
var _transitioning: bool = false

## 当前转换类型——Phase 2 设置，Phase 5 重置为 NONE。
var _transition_type: TransitionType = TransitionType.NONE

## 当前活跃场景 ID——成功完成转场后更新。
var _current_scene_id: int = SceneID.MAIN_MENU

## 测试模式标志——为 true 时跳过 [method _execute_transition] 中的异步场景加载。
## [br][b]仅测试使用[/b]——GUT 单元测试无有效 .tscn 文件，await 会永久挂起。
var _test_mode: bool = false

## Phase 3 进行中标志位——await 中断双重保底。
## Phase 3 开始时设为 true，Phase 4 正常到达时设为 false。
## tree_changed 信号可能在非场景切换场景下触发——此标志位作为语义校验。
var _phase3_in_progress: bool = false

## === 依赖注入 ==================================================================

## 注入的 GSM 引用。null 时使用 GameStateManager Autoload。
## 测试中可替换为轻量 mock（需实现 session Dictionary + set_session_scene 方法）。
var _gsm: Node = null

## 注入的 InputManager 引用。null 时使用 InputManager Autoload。
## 测试中可替换为 mock（需实现 push_lock / pop_lock 方法）。
var _im: Node = null

## 注入的 SaveLoad 引用。null 时使用 SaveLoadSystem Autoload。
## 测试中可替换为 mock（需实现 auto_save 方法）。
var _save_load: Node = null

## === 内置虚方法 ================================================================

func _ready() -> void:
	_transitioning = false
	_transition_type = TransitionType.NONE
	# _current_scene_id 默认 MAIN_MENU——首个启动场景

## === 依赖注入方法 ==============================================================

## 设置依赖引用。不传参数则使用 Autoload 默认值。
func set_dependencies(gsm: Node = null, im: Node = null, save_load: Node = null) -> void:
	if gsm != null:
		_gsm = gsm
	if im != null:
		_im = im
	if save_load != null:
		_save_load = save_load

## 获取当前使用的 GSM 引用——注入对象优先，否则回退到 Autoload。
func _get_gsm() -> Node:
	if _gsm != null:
		return _gsm
	return GameStateManager

## 获取当前使用的 InputManager 引用。
func _get_im() -> Node:
	if _im != null:
		return _im
	return InputManager

## 获取当前使用的 SaveLoad 引用。
func _get_save_load() -> Node:
	if _save_load != null:
		return _save_load
	return SaveLoadSystem

## === 公共 API ==================================================================

## 请求场景转换——SceneManager 唯一入口点。
## 返回 [code]false[/code] 的条件：[br]
##   - [member _transitioning] 为 [code]true[/code]（拒绝并发请求）[br]
##   - [param to] 不在 [constant SCENE_PATHS] 中（未注册的场景 ID）[br]
## [br][param from] 与内部 [_current_scene_id] 不匹配时记录警告但不阻止执行。
## [br]返回 [code]true[/code] = 转换已被接受并将异步执行。
func request_scene_change(from: int, to: int, type: TransitionType) -> bool:
	# Phase 1 —— VALIDATE
	if _transitioning:
		push_warning("SceneManager: 拒绝并发转换请求——_transitioning=true")
		return false

	if not SCENE_PATHS.has(to):
		push_error("SceneManager: 未注册的目标场景 ID '%d'" % to)
		return false

	if from != _current_scene_id:
		push_warning("SceneManager: from 不匹配（请求=%d, 内部=%d）——继续执行" % [from, _current_scene_id])

	# Phase 2 —— PRE-TRANSITION
	_transitioning = true
	_transition_type = type

	# 锁输入——TRANSITION 级阻止所有输入（AC-1：null 检查防御性编程）
	var im: Node = _get_im()
	if im != null and im.has_method("push_lock"):
		im.push_lock(3, &"scene_manager")  # LockType.TRANSITION = 3

	# 自动存档——fire-and-forget，不阻塞管线推进（AC-2）
	var sl: Node = _get_save_load()
	if sl != null and sl.has_method("auto_save"):
		sl.auto_save()

	# 发射 pre_transition（Cat 2a——通过 _emit_signal_safe 路由）
	_emit_pre_transition(from, to, type)

	# Phase 3-5 执行
	# 测试模式：跳过异步部分——测试需手动调用 _execute_post_load 验证 Phase 4-5
	if not _test_mode:
		_execute_transition(from, to)
	return true


## 获取当前场景 ID（O(1) 查询——不依赖 GSM）。
func get_current_scene_id() -> int:
	return _current_scene_id


## 是否正在转场中。
func is_transitioning() -> bool:
	return _transitioning


## === 信号发射包装 ==============================================================

## 发射 [signal pre_transition]——通过 ADR-0007 信号链深度追踪路由。[br]
## 当 GSM._emit_signal_safe 不可用时（单元测试 mock 场景），回退到直接 emit。
func _emit_pre_transition(from: int, to: int, type: TransitionType) -> void:
	var _gsm_script: GDScript = GameStateManager.get_script()
	if _gsm_script.has_method("_emit_signal_safe"):
		_gsm_script._emit_signal_safe(self, &"pre_transition", [from, to, type])
	else:
		pre_transition.emit(from, to, type)


## 发射 [signal post_transition]——通过 ADR-0007 信号链深度追踪路由。
func _emit_post_transition(from: int, to: int) -> void:
	var _gsm_script: GDScript = GameStateManager.get_script()
	if _gsm_script.has_method("_emit_signal_safe"):
		_gsm_script._emit_signal_safe(self, &"post_transition", [from, to])
	else:
		post_transition.emit(from, to)


## === 异步转换管线 ==============================================================

## Phase 3-4-5 异步执行体。[br]
## [br]Phase 3: 加载画面 → 目标场景（两段式 change_scene_to_file）。[br]
## 测试中直接调用 [method _execute_post_load]（同步的 Phase 4-5），无需 mock SceneTree。
## [br][br][b]错误恢复[/b]: 加载画面缺失 → 清理状态返回；目标场景缺失 → 回退 MAIN_MENU。
func _execute_transition(from: int, to: int) -> void:
	# 测试模式：跳过异步场景加载——直接执行 Phase 4-5
	if _test_mode:
		_execute_post_load(from, to, SCENE_PATHS[to])
		return

	# Phase 3 —— LOAD（两段式：加载画面 → 目标场景）
	_phase3_in_progress = true
	var loading_path: String = SCENE_PATHS[SceneID.LOADING]
	var target_path: String = SCENE_PATHS[to]

	# Step 1: 切换到加载画面
	var err1: int = get_tree().change_scene_to_file(loading_path)
	if err1 != OK:
		# AC-4: 加载画面缺失——清理状态，返回当前场景
		push_error("SceneManager: 无法加载 loading_screen.tscn（err=%d）" % err1)
		_cleanup_on_error(&"loading_screen_missing")
		return

	await get_tree().tree_changed
	# tree_changed 后再检查：若 Phase 3 被外部中断则清理
	if not _phase3_in_progress:
		return

	# Step 2: 切换到目标场景
	var err2: int = get_tree().change_scene_to_file(target_path)
	if err2 != OK:
		# AC-5: 目标场景不存在——记录错误，尝试回退 MAIN_MENU
		push_error("SceneManager: 目标场景不存在：%s（err=%d）" % [target_path, err2])
		_cleanup_on_error(&"target_scene_missing")
		# 尝试回退到主菜单
		request_scene_change(_current_scene_id, SceneID.MAIN_MENU, TransitionType.GAME_TO_MENU)
		return

	await get_tree().tree_changed

	# Phase 4 —— POST-LOAD（双重保底：检查 _phase3_in_progress）
	if not _phase3_in_progress:
		# AC-6: await 异常中断——tree_changed 到达但标志位已被外部清除
		push_error("SceneManager: Phase 3 异常中断——强制清理")
		_cleanup_on_error(&"phase3_aborted")
		return

	# 防御性校验：确认当前场景路径匹配
	var current: Node = get_tree().current_scene
	if current == null or current.scene_file_path != target_path:
		push_error("SceneManager: tree_changed 后场景路径不匹配（期望=%s, 实际=%s）" % [
				target_path,
				current.scene_file_path if current != null else "null"])
		_cleanup_on_error(&"path_mismatch")
		return

	_execute_post_load(from, to, target_path)


## 错误恢复——统一清理入口。[br]
## 恢复 _transitioning + _transition_type + _phase3_in_progress 到初始状态，
## 并强制释放 TRANSITION 级输入锁，防止死锁和锁泄漏。
func _cleanup_on_error(reason: StringName) -> void:
	_transitioning = false
	_transition_type = TransitionType.NONE
	_phase3_in_progress = false

	var im: Node = _get_im()
	if im != null and im.has_method("pop_lock"):
		im.pop_lock(&"scene_manager")


## Phase 4-5 同步执行体。[br]
## [br][b]生产[/b]: 由 [method _execute_transition] 在 [code]await tree_changed[/code] 成功后调用。[br]
## [b]测试[/b]: 可直接调用——绕过 [code]await[/code] 和 Godot SceneTree 依赖。[br]
## [br]Phase 4: GSM 写入 → 解锁输入 → 发射 [signal post_transition]。[br]
## Phase 5: [_current_scene_id] = [param to], [_transitioning] = false, [_transition_type] = NONE.
func _execute_post_load(from: int, to: int, target_path: String) -> void:
	# Phase 4 —— GSM 写入
	var gsm: Node = _get_gsm()
	if gsm != null and gsm.has_method("set_session_scene"):
		# 通过 GSM 第二层原子方法——触发 batch_updated（生产路径）
		gsm.set_session_scene(to, target_path)
	elif gsm != null and "session" in gsm:
		# 测试 mock 回退——mock 对象无 GSM 缓冲层，直接赋值
		gsm.session.current_scene = target_path
		gsm.session.scene_id = to

	# 解锁输入（AC-3：顺序——GSM 写入 → post_transition → pop_lock）
	var im_ok: Node = _get_im()
	if im_ok != null and im_ok.has_method("pop_lock"):
		im_ok.pop_lock(&"scene_manager")

	# 发射 post_transition（必须在新场景 ready 后、第一个 _process 前）
	_emit_post_transition(from, to)

	# Phase 5 —— FINALIZE
	_current_scene_id = to
	_transitioning = false
	_transition_type = TransitionType.NONE
	_phase3_in_progress = false
