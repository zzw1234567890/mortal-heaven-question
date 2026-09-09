extends GutTest
## HUD Story 001 集成测试：CanvasLayer 挂载、可见性矩阵与 PersistentLayer API。
##
## 覆盖 AC-1（信号驱动挂载与探索可见）、AC-2（矩阵 12 值 + 战斗隐藏 + 恢复）、
## AC-3（PauseOverlay 骨架）、AC-4（信号驱动零轮询）、
## AC-5（PersistentLayer API + 防呆 + 转场存活）、AC-6（零状态副本源码检查）。
##
## Story 类型为 Integration——此测试文件为阻塞项。[br]
## 风格先例：tests/integration/scene_manager/test_loading_screen.gd
## （_test_mode + set_dependencies + 手动 emit 信号）。

const SM := preload("res://src/foundation/scene_manager.gd")
const HUD_SCENE: PackedScene = preload("res://src/ui/hud/HUD.tscn")
const HUD_SCRIPT_PATH: String = "res://src/ui/hud/hud.gd"
const MockFactory := preload("res://tests/integration/scene_manager/mocks/mock_factory.gd")

var sm: Node = null
var hud: CanvasLayer = null
var _mock_gsm: Node = null
var _mock_im: Node = null
var _mock_sl: Node = null


func before_each() -> void:
	sm = SM.new()
	sm._ready()
	sm._test_mode = true
	_mock_gsm = MockFactory.build_gsm()
	_mock_im = MockFactory.build_im()
	_mock_sl = MockFactory.build_sl()
	sm.set_dependencies(_mock_gsm, _mock_im, _mock_sl)
	add_child_autofree(sm)
	hud = HUD_SCENE.instantiate()
	sm.register_persistent(hud)
	hud.setup(sm)


func after_each() -> void:
	# hud 挂在 sm 之下（PersistentLayer）——sm.free 会级联释放；
	# add_child_autofree 也会释放 sm。若 hud 已游离则手动释放。
	if hud != null and is_instance_valid(hud):
		if hud.get_parent() == null:
			hud.free()
		hud = null
	if sm != null and is_instance_valid(sm):
		sm.free()
		sm = null
	_free_mocks()


func _free_mocks() -> void:
	for m: Node in [_mock_gsm, _mock_im, _mock_sl]:
		if m != null and is_instance_valid(m):
			m.free()
	_mock_gsm = null
	_mock_im = null
	_mock_sl = null


# ── Mock 构造（GSM/IM/SL 已提取至 scene_manager/mocks/ 共享 fixture——
#    hud 001 code-review 修复，消除与 test_loading_screen.gd 的双份拷贝）──────


func _content_layer() -> Control:
	return hud.get_node_or_null(^"ContentLayer") as Control


func _pause_overlay() -> Control:
	return hud.get_node_or_null(^"PauseOverlay") as Control


# ═══════════════════════════════════════════════════════════════════════════════
# AC-5 验收标准：PersistentLayer API（GAP-2 裁决）
# ═══════════════════════════════════════════════════════════════════════════════

func test_persistent_layer_ready_creates_layer_node() -> void:
	## AC-5: _ready() 后 PersistentLayer 节点存在
	# Arrange —— before_each 中 sm._ready() 已执行
	# Act
	var layer: Node = sm.get_node_or_null(^"PersistentLayer")
	# Assert
	assert_not_null(layer, "_ready() 后应存在 PersistentLayer 子节点")


func test_register_persistent_sets_parent_to_layer() -> void:
	## AC-5: register_persistent(node) 后 node 的父节点为 PersistentLayer
	# Arrange
	var node := Node.new()
	# Act
	sm.register_persistent(node)
	# Assert
	assert_eq(node.get_parent(), sm.get_node_or_null(^"PersistentLayer"),
			"注册节点的父节点应为 PersistentLayer")
	node.free()


func test_register_persistent_duplicate_pushes_warning() -> void:
	## AC-5: 重复注册同一节点 → push_warning 防呆
	# Arrange
	var node := Node.new()
	node.name = &"DuplicateProbe"
	sm.register_persistent(node)
	# Act
	sm.register_persistent(node)
	# Assert
	assert_push_warning_count(1, "重复注册应 push_warning 1 次")
	assert_eq(node.get_parent(), sm.get_node_or_null(^"PersistentLayer"),
			"重复注册不应破坏现有挂载")
	node.free()


func test_register_persistent_null_pushes_error() -> void:
	## AC-5: null 注册 push_error 防呆——不崩溃
	## （code-review L-6 强化：以 push_error 计数+子节点数不变替代空断言）
	# Arrange —— 记录注册前子节点数
	var children_before: int = sm.get_node_or_null(^"PersistentLayer").get_child_count()
	# Act
	sm.register_persistent(null)
	# Assert —— 不崩溃 + 无副作用
	assert_push_error_count(1, "null 注册应 push_error 1 次")
	assert_eq(sm.get_node_or_null(^"PersistentLayer").get_child_count(),
			children_before, "null 注册不应改变 PersistentLayer 子节点数")


func test_register_persistent_node_with_other_parent_pushes_error() -> void:
	## AC-5（code-review GAP 补充）：已有其他父节点的节点注册 → push_error 忽略
	# Arrange —— node 挂在临时父节点下
	var holder := Node.new()
	add_child_autofree(holder)
	var node := Node.new()
	node.name = &"AdoptedProbe"
	holder.add_child(node)
	# Act
	sm.register_persistent(node)
	# Assert
	assert_push_error_count(1, "已有父节点的注册应 push_error 1 次")
	assert_eq(node.get_parent(), holder,
			"节点应保持原父节点——不被移入 PersistentLayer")


func test_register_persistent_same_name_different_node_warns_and_adds() -> void:
	## AC-5（code-review GAP 补充）：同名不同节点 → push_warning 仍添加（自动重命名）
	# Arrange
	var node_a := Node.new()
	node_a.name = &"NameClash"
	sm.register_persistent(node_a)
	var node_b := Node.new()
	node_b.name = &"NameClash"
	# Act
	sm.register_persistent(node_b)
	# Assert
	assert_push_warning_count(1, "同名注册应 push_warning 1 次")
	assert_eq(node_b.get_parent(), sm.get_node_or_null(^"PersistentLayer"),
			"同名新节点仍应被添加")
	assert_ne(str(node_b.name), "NameClash",
			"Godot 应已自动重命名新节点（原名冲突）")
	node_a.free()
	node_b.free()


func test_persistent_layer_survives_scene_transition() -> void:
	## AC-5 edge: 场景转场后 PersistentLayer 及其子节点仍存在
	## test_mode 下 _execute_transition 直接执行 Phase 4-5（同步），
	## 不触碰真实 SceneTree——此处验证 sm 及其子树经完整请求管线后存活。
	# Arrange —— before_each 已挂载 hud 到 PersistentLayer
	var marker := Node.new()
	marker.name = &"SurvivalProbe"
	sm.register_persistent(marker)
	# Act —— 经完整 5 阶段请求管线（test_mode 同步执行 Phase 4-5）
	var ok: bool = sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION,
			SM.TransitionType.MENU_TO_GAME)
	# Assert
	assert_true(ok, "转场请求应被接受")
	assert_true(is_instance_valid(marker), "转场后持久子节点仍存活")
	assert_eq(marker.get_parent(), sm.get_node_or_null(^"PersistentLayer"),
			"转场后子节点仍挂在 PersistentLayer 下")
	assert_true(is_instance_valid(hud), "转场后 HUD 仍存活")
	marker.free()


func test_persistent_layer_survives_real_change_scene_to_file() -> void:
	## AC-5 edge（code-review BLOCKING 修复）：真实 change_scene_to_file 转场存活。
	## test_mode 会跳过 Phase 3 的 change_scene_to_file——本测试关闭 test_mode，
	## 以真实存在的 loading_screen.tscn 为目标执行完整异步管线，
	## 验证 ADR-0031 §1.2 的挂载等价性所依赖的引擎行为本身。
	## 先例：GUT await 异步测试（add_child_autofree + await process_frame）。
	# Arrange —— 独立实例（不复用 before_each 的 test_mode sm）
	var real_sm: Node = SM.new()
	real_sm._ready()
	real_sm._test_mode = false
	var local_gsm: Node = MockFactory.build_gsm()
	var local_im: Node = MockFactory.build_im()
	var local_sl: Node = MockFactory.build_sl()
	real_sm.set_dependencies(local_gsm, local_im, local_sl)
	add_child_autofree(real_sm)
	var real_hud: CanvasLayer = HUD_SCENE.instantiate()
	real_sm.register_persistent(real_hud)
	real_hud.setup(real_sm)
	var layer_before: Node = real_sm.get_node_or_null(^"PersistentLayer")
	assert_not_null(layer_before, "前置：PersistentLayer 存在")
	# Act —— 真实转场（MAIN_MENU → LOADING 场景，目标 .tscn 确认存在）
	var ok: bool = real_sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.LOADING,
			SM.TransitionType.MENU_TO_GAME)
	assert_true(ok, "真实转场请求应被接受")
	# Phase 3 await tree_changed + 场景实例化需要数帧完成——轮询至转场结束或超时
	var waited: int = 0
	while real_sm.is_transitioning() and waited < 60:
		await get_tree().process_frame
		waited += 1
	# Assert
	assert_false(real_sm.is_transitioning(),
			"转场应在帧预算内完成（等待 %d 帧）" % waited)
	assert_true(is_instance_valid(real_hud), "真实转场后 HUD 仍存活")
	assert_true(is_instance_valid(layer_before), "真实转场后 PersistentLayer 仍存活")
	assert_eq(real_hud.get_parent(), real_sm.get_node_or_null(^"PersistentLayer"),
			"真实转场后 HUD 仍挂在 PersistentLayer 下")
	# 清理——mock 不在 sm 子树内，须显式释放（复审 LOW-2：孤儿泄漏）
	local_gsm.free()
	local_im.free()
	local_sl.free()


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1 验收标准：信号驱动挂载与探索可见
# ═══════════════════════════════════════════════════════════════════════════════

func test_mounted_hud_exists_under_persistent_layer() -> void:
	## AC-1: HUD CanvasLayer 存在于 PersistentLayer 下
	# Arrange —— before_each 已实例化 + register_persistent
	# Act
	var layer: Node = sm.get_node_or_null(^"PersistentLayer")
	# Assert
	assert_not_null(layer, "PersistentLayer 应存在")
	assert_eq(hud.get_parent(), layer, "HUD 应挂在 PersistentLayer 下")
	assert_true(hud is CanvasLayer, "HUD 根节点应为 CanvasLayer")


func test_post_transition_to_exploration_shows_content() -> void:
	## AC-1: MAIN_MENU→EXPLORATION 转场后 ContentLayer 可见
	# Arrange
	_content_layer().visible = false
	# Act —— 手动 emit（先例：QA 规格——场景 .tscn 多数未创建）
	sm.post_transition.emit(SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION)
	# Assert
	assert_true(_content_layer().visible, "EXPLORATION 后内容分支应可见")


func test_post_transition_to_shop_event_deck_cultivation_show_content() -> void:
	## AC-1 edge: SHOP/EVENT_PANEL/DECK_EDITING/CULTIVATION 同样可见
	# Arrange
	var visible_ids: Array[int] = [
		SM.SceneID.SHOP, SM.SceneID.EVENT_PANEL,
		SM.SceneID.DECK_EDITING, SM.SceneID.CULTIVATION,
	]
	# Act + Assert
	for sid: int in visible_ids:
		_content_layer().visible = false
		sm.post_transition.emit(SM.SceneID.MAIN_MENU, sid)
		assert_true(_content_layer().visible,
				"SceneID %d 转场后内容分支应可见" % sid)


func test_mid_transition_keeps_previous_state() -> void:
	## AC-1 edge: pre 已发 post 未发（转场中途）——保持前一状态
	# Arrange
	_content_layer().visible = true
	# Act —— 仅 emit pre_transition
	sm.pre_transition.emit(SM.SceneID.EXPLORATION, SM.SceneID.COMBAT,
			SM.TransitionType.EXPLORE_TO_COMBAT)
	# Assert
	assert_true(_content_layer().visible,
			"pre_transition 期间内容分支应保持前一状态（EXPLORATION 可见）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2 验收标准：战斗场景内容分支不渲染
# ═══════════════════════════════════════════════════════════════════════════════

func test_visibility_matrix_all_twelve_values() -> void:
	## AC-2 edge: 矩阵全 12 值逐一断言（11 显式 + LOADING 保持前一状态）
	# Arrange —— 期望表（与 story 裁决矩阵一致）
	var expected: Dictionary = {
		SM.SceneID.EXPLORATION: true,
		SM.SceneID.SHOP: true,
		SM.SceneID.EVENT_PANEL: true,
		SM.SceneID.DECK_EDITING: true,
		SM.SceneID.CULTIVATION: true,
		SM.SceneID.COMBAT: false,
		SM.SceneID.TRIBULATION: false,
		SM.SceneID.RESULT_SCREEN: false,
		SM.SceneID.DEFEAT_SCREEN: false,
		SM.SceneID.MAIN_MENU: false,
		SM.SceneID.IDENTITY_SELECT: false,
	}
	# Act + Assert —— 11 个注册场景 ID
	for sid: int in expected:
		_content_layer().visible = not expected[sid]
		sm.post_transition.emit(SM.SceneID.MAIN_MENU, sid)
		assert_eq(_content_layer().visible, expected[sid],
				"SceneID %d 可见性应为 %s" % [sid, str(expected[sid])])
	# 第 12 值 LOADING：保持前一状态（两组对照）
	_content_layer().visible = true
	sm.post_transition.emit(SM.SceneID.EXPLORATION, SM.SceneID.LOADING)
	assert_true(_content_layer().visible, "LOADING 应保持前一状态（可见）")
	_content_layer().visible = false
	sm.post_transition.emit(SM.SceneID.COMBAT, SM.SceneID.LOADING)
	assert_false(_content_layer().visible, "LOADING 应保持前一状态（隐藏）")


func test_hud_visibility_matrix_keys_match_registered_scene_ids() -> void:
	## 守卫断言（code-review H-2 修复）：SCENE_VISIBILITY 键集与 SCENE_PATHS
	## 键集对齐（LOADING 除外）——SceneID 枚举新增值时矩阵漏配在此显式失败，
	## 而非静默保持前一场景的可见性。
	# Arrange —— 读取 hud.gd 源码解析 const SCENE_VISIBILITY 字面键集
	var matrix_keys: Array = hud.SCENE_VISIBILITY.keys()
	var registered: Array = SM.SCENE_PATHS.keys()
	# Act + Assert —— 矩阵无多余键
	for k: int in matrix_keys:
		assert_true(registered.has(k),
				"矩阵键 %d 不在 SCENE_PATHS 注册表中" % k)
	# 每个注册 ID（除 LOADING=99）都入矩阵
	for sid: int in registered:
		if sid == SM.SceneID.LOADING:
			continue
		assert_true(matrix_keys.has(sid),
				"SceneID %d 已注册但未入可见性矩阵——新增场景须同步矩阵" % sid)
	# _LOADING_SCENE_ID 与枚举值钉死（复审 INFO-3：双维护守卫）
	assert_eq(hud._LOADING_SCENE_ID, SM.SceneID.LOADING,
			"_LOADING_SCENE_ID 须与 SceneID.LOADING 一致（双处维护守卫）")


func test_hud_initial_visibility_matches_boot_scene() -> void:
	## AC-1 隐含（code-review H-1/HIGH-2 修复）：挂载后、首信号前，
	## 内容分支按当前场景 ID 同步——MAIN_MENU 启动时不可见。
	## before_each 中 setup(sm) 已执行（sm 默认 _current_scene_id = MAIN_MENU）。
	# Arrange + Act —— before_each 已完成 setup（无任何 post_transition emit）
	# Assert
	assert_false(_content_layer().visible,
			"MAIN_MENU 启动（无转场信号）时内容分支应不可见")


func test_hud_unknown_scene_id_keeps_previous_state_and_warns() -> void:
	## 未注册 SceneID（code-review H-2 修复）：保持前一状态 + push_warning
	# Arrange
	_content_layer().visible = true
	# Act —— emit 未注册 ID（42——不在矩阵与注册表）
	sm.post_transition.emit(SM.SceneID.EXPLORATION, 42)
	# Assert
	assert_true(_content_layer().visible, "未注册 ID 应保持前一状态")
	assert_push_warning_count(1, "未注册 ID 应 push_warning 1 次")


func test_post_transition_to_combat_hides_content_keeps_pause_overlay() -> void:
	## AC-2: EXPLORATION→COMBAT 内容分支隐藏；PauseOverlay 不受矩阵影响
	## （code-review GAP 修复：先手动置 PauseOverlay 可见，使豁免断言可证伪——
	## 骨架默认 false 时断言空转，矩阵误隐藏 PauseOverlay 无感知）
	# Arrange —— 处于 EXPLORATION 可见状态；模拟暂停菜单打开（Story 005 场景）
	sm.post_transition.emit(SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION)
	_pause_overlay().visible = true
	# Act
	sm.post_transition.emit(SM.SceneID.EXPLORATION, SM.SceneID.COMBAT)
	# Assert
	assert_false(_content_layer().visible, "COMBAT 后内容分支应隐藏")
	assert_true(_pause_overlay().visible,
			"PauseOverlay 不受矩阵影响（战斗中打开的暂停菜单保持可见）")


func test_combat_to_exploration_restores_visibility() -> void:
	## AC-2 edge: 战斗→探索返回后恢复可见
	# Arrange
	sm.post_transition.emit(SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION)
	sm.post_transition.emit(SM.SceneID.EXPLORATION, SM.SceneID.COMBAT)
	assert_false(_content_layer().visible, "前置：COMBAT 后内容分支隐藏")
	# Act
	sm.post_transition.emit(SM.SceneID.COMBAT, SM.SceneID.EXPLORATION)
	# Assert
	assert_true(_content_layer().visible, "返回 EXPLORATION 后应恢复可见")


func test_cleanup_on_error_fallback_to_main_menu_hides_hud() -> void:
	## AC-2 edge: _cleanup_on_error 回退 MAIN_MENU 后 HUD 隐藏
	## 模拟转场失败路径：处于可见状态后目标场景缺失 → 清理 → 回退请求 MAIN_MENU
	# Arrange
	sm.post_transition.emit(SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION)
	assert_true(_content_layer().visible, "前置：EXPLORATION 可见")
	sm._transitioning = true
	sm._phase3_in_progress = true
	# Act —— 错误恢复（转场失败清理——重置 _transitioning 后方可发起新请求）
	sm._cleanup_on_error(&"target_scene_missing")
	assert_false(sm._transitioning, "前置：清理后 _transitioning 应已复位")
	# 回退请求 MAIN_MENU——test_mode 下同步 emit pre_transition（post 需手动）；
	# 真实管线中 post_transition 由 _execute_post_load 发射，这里手动补发模拟 Phase 4
	sm.request_scene_change(SM.SceneID.EXPLORATION, SM.SceneID.MAIN_MENU,
			SM.TransitionType.GAME_TO_MENU)
	sm.post_transition.emit(SM.SceneID.EXPLORATION, SM.SceneID.MAIN_MENU)
	# Assert
	assert_false(_content_layer().visible,
			"回退 MAIN_MENU 转场后 HUD 内容分支应隐藏")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3 验收标准：PauseOverlay 挂载点骨架
# ═══════════════════════════════════════════════════════════════════════════════

func test_pause_overlay_skeleton_structure() -> void:
	## AC-3: PauseOverlay 存在、为 CanvasLayer 直接子节点、PROCESS_MODE_ALWAYS
	# Arrange —— HUD 已实例化
	# Act
	var pause: Control = _pause_overlay()
	# Assert
	assert_not_null(pause, "PauseOverlay 节点应存在")
	assert_eq(pause.get_parent(), hud, "PauseOverlay 应为 CanvasLayer 直接子节点")
	assert_eq(pause.process_mode, Node.PROCESS_MODE_ALWAYS,
			"PauseOverlay 的 process_mode 应为 PROCESS_MODE_ALWAYS")


func test_content_layer_four_area_containers_exist() -> void:
	## AC（story Implementation Notes）：ContentLayer 下四个区域容器骨架
	# Arrange —— 无
	# Act + Assert
	for area_name: String in ["RealmBarArea", "LingshiDeckArea",
			"ExplorationInfoArea", "NotificationArea"]:
		var area: Node = _content_layer().get_node_or_null(area_name)
		assert_not_null(area, "ContentLayer 下应存在 %s 区域容器" % area_name)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4 验收标准：可见性切换由信号驱动（零轮询）
# ═══════════════════════════════════════════════════════════════════════════════

func test_visibility_changes_only_via_signal_emission() -> void:
	## AC-4: 行为断言——每次 visible 变化均由 post_transition emit 触发
	# Arrange —— 直接改 visible 建立基线（模拟非信号路径无效果的前提）
	_content_layer().visible = false
	# Act —— emit 序列驱动全部翻转
	sm.post_transition.emit(SM.SceneID.MAIN_MENU, SM.SceneID.SHOP)
	assert_true(_content_layer().visible, "SHOP emit → 可见")
	sm.post_transition.emit(SM.SceneID.SHOP, SM.SceneID.COMBAT)
	assert_false(_content_layer().visible, "COMBAT emit → 隐藏")
	sm.post_transition.emit(SM.SceneID.COMBAT, SM.SceneID.EVENT_PANEL)
	assert_true(_content_layer().visible, "EVENT_PANEL emit → 可见")
	sm.post_transition.emit(SM.SceneID.EVENT_PANEL, SM.SceneID.TRIBULATION)
	assert_false(_content_layer().visible, "TRIBULATION emit → 隐藏")


func test_hud_setup_called_twice_does_not_duplicate_connection() -> void:
	## AC-4（code-review LOW-1/GAP 补充）：重复 setup 不产生重复连接
	## 默认 connect flags 下同一 callable 重复连接被忽略——守卫断言钉死该行为，
	## Story 002/003 在处理器加入非幂等逻辑前此契约不因回归而失效。
	# Arrange —— before_each 已 setup 一次
	# Act
	hud.setup(sm)
	hud.setup(sm)
	# Assert —— 连接仍为单份
	var conn_count: int = 0
	for c: Dictionary in sm.post_transition.get_connections():
		if c.callable == Callable(hud, &"_on_post_transition"):
			conn_count += 1
	assert_eq(conn_count, 1, "重复 setup 后信号连接数应为 1")
	# 行为幂等：emit 后 visible 只按矩阵落定一次
	sm.post_transition.emit(SM.SceneID.MAIN_MENU, SM.SceneID.SHOP)
	assert_true(_content_layer().visible, "重复 setup 后信号驱动仍正常")


func test_hud_script_has_no_scene_id_polling() -> void:
	## AC-4 源码检查: hud.gd 中无 SceneID 轮询
	## 模式（story 规格）：get_current_scene\( 或 current_scene ==
	var source: String = _read_hud_source()
	assert_false(source.contains("get_current_scene("),
			"hud.gd 不应调用 get_current_scene()（轮询）")
	assert_false(source.contains("current_scene =="),
			"hud.gd 不应比较 current_scene（轮询）")


func test_hud_script_has_no_process_method() -> void:
	## AC-4 源码检查: hud.gd 无 _process（零轮询）
	var source: String = _read_hud_source()
	assert_false(source.contains("func _process("),
			"hud.gd 不应定义 _process（零轮询——AC-4）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6 验收标准：HUD 零状态副本（源码检查）
# ═══════════════════════════════════════════════════════════════════════════════

func test_hud_source_has_no_gsm_assignment() -> void:
	## AC-6: hud.gd 无对 GSM 域的赋值语句
	## 模式（story 规格）：GameStateManager\.\w+\s*= 与 GSM\.\w+\s*=
	var source: String = _read_hud_source()
	var gsm_assign := RegEx.new()
	gsm_assign.compile("GameStateManager\\.\\w+\\s*=")
	assert_eq(gsm_assign.search(source), null,
			"hud.gd 不应包含 GameStateManager.*= 赋值模式")
	var short_assign := RegEx.new()
	short_assign.compile("GSM\\.\\w+\\s*=")
	assert_eq(short_assign.search(source), null,
			"hud.gd 不应包含 GSM.*= 赋值模式")


func test_hud_source_has_no_cache_or_last_members() -> void:
	## AC-6: _cache/_last 前缀成员均须有瞬态交互状态注释——本骨架直接零持有
	var source: String = _read_hud_source()
	var cache_member := RegEx.new()
	cache_member.compile("var\\s+_\\w*(cache|last)\\w*\\s*[:=]")
	assert_eq(cache_member.search(source), null,
			"hud.gd 不应声明 _cache/_last 前缀成员（本 story 无瞬态缓存需求）")


func _read_hud_source() -> String:
	var f := FileAccess.open(HUD_SCRIPT_PATH, FileAccess.READ)
	assert_not_null(f, "hud.gd 源码应可读")
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text
