extends GutTest
## main-menu Story 001 集成测试：场景导航 + 焦点导航（QA 规格 AC-4）。
##
## 覆盖场景：[br]
##   - AC-4 主体: 点击新游戏 → request_scene_change 调用且目标为身份选择场景；
##     无 GSM 直接写（mock scene_manager 捕获调用——不依赖真实 GSM）[br]
##   - 焦点顺序与初始焦点（story Implementation Notes：初始焦点 = 继续游戏，
##     无存档回退新游戏）[br]
##   - 按钮禁用/摘要行可见性（无存档时隐藏占位保留）[br]
##   - 版本号从 ProjectSettings 读取（非硬编码）[br]
##
## 风格先例：tests/integration/hud/test_pause_menu.gd（场景实例化 + 注入
## mock scene_manager 记录 request_scene_change 调用与参数）。

const MAIN_MENU_SCENE: PackedScene = preload("res://src/ui/main_menu/MainMenu.tscn")
## SceneManager 脚本常量——断言引用同一枚举真理来源（与实现同步漂移修复，
## code-review H-1 测试侧姊妹项：实现换枚举常量后断言不再固定字面量语义）。
const SM := preload("res://src/foundation/scene_manager.gd")


## mock 场景管理器——记录 request_scene_change 调用与参数（先例
## test_pause_menu.gd MockSceneManager）。
class MockSceneManager:
	extends Node
	var change_calls: Array = []

	func get_current_scene_id() -> int:
		return 0  # MAIN_MENU——主菜单典型调用场景

	func request_scene_change(from: int, to: int, type: int) -> bool:
		change_calls.append([from, to, type])
		return true


## mock SaveLoadSystem——list_slots 可配置；load_game 恒成功。
class MockSaveLoad:
	extends Node
	signal save_corrupted(slot_type: int, slot_id: int, reason: String)
	signal load_completed(success: bool)

	var slots: Array = []

	func list_slots() -> Array:
		return slots

	func load_game(slot_type: int, slot_id: int) -> Dictionary:
		load_completed.emit(true)
		return {"result": 0, "data": {}}  # LoadResult.SUCCESS


var menu: Control = null
var mock_sm: MockSceneManager = null
var mock_sl: MockSaveLoad = null


func before_each() -> void:
	mock_sm = MockSceneManager.new()
	mock_sl = MockSaveLoad.new()
	menu = MAIN_MENU_SCENE.instantiate()
	menu.animate = false
	menu.scene_manager = mock_sm
	menu.save_load = mock_sl
	add_child(menu)


func after_each() -> void:
	if menu != null and is_instance_valid(menu):
		menu.free()
	menu = null
	if mock_sm != null and is_instance_valid(mock_sm):
		mock_sm.free()
	mock_sm = null
	if mock_sl != null and is_instance_valid(mock_sl):
		mock_sl.free()
	mock_sl = null


func _existing_slot() -> Dictionary:
	## 测试数据：单一存在槽位（有存档场景）。
	return {
		"slot_type": 0, "slot_id": 0, "exists": true,
		"name": "测试档", "timestamp": "2026-09-12T10:00:00",
		"realm": "元婴期", "playtime": 7200,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4：场景导航
# ═══════════════════════════════════════════════════════════════════════════════

func test_navigation_new_game_targets_identity_select() -> void:
	## AC-4 主体: 点击新游戏 → request_scene_change 调用且目标为 IDENTITY_SELECT
	# Arrange
	# Act
	menu._on_new_game_pressed()
	# Assert
	assert_eq(mock_sm.change_calls.size(), 1, "request_scene_change 应被调用 1 次")
	if mock_sm.change_calls.size() == 1:
		var call: Array = mock_sm.change_calls[0]
		assert_eq(call[1], SM.SceneID.IDENTITY_SELECT,
				"转场目标应为 IDENTITY_SELECT")
		assert_eq(call[0], 0, "转场源应为 MAIN_MENU（mock 返回 0）")
		assert_eq(call[2], SM.TransitionType.MENU_TO_GAME,
				"转场类型应为 MENU_TO_GAME")


func test_navigation_new_game_no_gsm_direct_write() -> void:
	## AC-4: 无 GSM 直接写——两重验证（GAP-4 修复）：[br]
	## ① 调用面只含经 mock scene_manager 的转场请求；[br]
	## ② 静态守卫——脚本源码不含 change_scene_to_file 直调（control-manifest
	## 必需模式的回归防线；注释坦承原先仅断言计数不验证真语义）。
	# Arrange
	var calls_before: int = mock_sm.change_calls.size()
	# Act
	menu._on_new_game_pressed()
	# Assert
	assert_eq(mock_sm.change_calls.size(), calls_before + 1,
			"新游戏仅产生 1 次转场请求（无其他副作用调用）")
	# 源码守卫排除文档注释——仅扫函数体（[^] 注释中提及 API 名称属正常）
	var body: String = String(menu.get_script().source_code)
	for line: String in body.split("\n"):
		var code: String = line.strip_edges()
		if code.begins_with("#") or code.begins_with("##"):
			continue  # 注释行豁免
		assert_false(code.contains("change_scene_to_file"),
				"MainMenu 可执行代码不得直调 change_scene_to_file（必须经"
				+ " SceneManager）——违规行: %s" % code)


func test_navigation_registered_scene_paths_exist() -> void:
	## GAP-4 姊妹守卫: SCENE_PATHS 注册路径防大小写错配——对每个注册路径
	## 扫描其父目录实际文件名，文件存在但大小写不一致 → 失败（本 story 曾因
	## main_menu.tscn vs MainMenu.tscn 返工：Windows 大小写不敏感本地过、
	## Linux CI 必挂）。文件完全不存在 = 相邻 story 占位（如 identity_select），
	## 不在守卫范围——按当前已实现场景目录精确核对。
	# Arrange + Act + Assert
	for scene_id: int in SM.SCENE_PATHS.keys():
		var path: String = SM.SCENE_PATHS[scene_id]
		var dir_path: String = path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir_path):
			continue  # 未创建的目录 = 未来 story 占位
		var file_name: String = path.get_file()
		var actual_names: PackedStringArray = \
				DirAccess.get_files_at(dir_path)
		var found_exact: bool = false
		var found_case_mismatch: String = ""
		for name: String in actual_names:
			if name == file_name:
				found_exact = true
			elif name.to_lower() == file_name.to_lower():
				found_case_mismatch = name
		assert_true(found_exact or found_case_mismatch.is_empty(),
				"SceneID=%d 注册路径 %s 与实际文件 %s 大小写不一致" % [
					scene_id, path, found_case_mismatch])


func test_navigation_scene_manager_missing_no_crash() -> void:
	## AC-4 防御: SceneManager 不可用（缺失 request_scene_change 方法）——
	## push_error 中止导航，不崩溃。[br]
	## 注：headless GUT 下真实 SceneManager Autoload 存在——scene_manager
	## 置 null 会回退 Autoload 触发真实转场（污染测试环境）。故以「缺方法的
	## mock」走 [code]has_method[/code] 守卫分支——守卫语义等价且零副作用。
	# Arrange —— 注入缺 request_scene_change 的对象（触发 has_method 守卫）
	var bare_node: Node = Node.new()
	menu.scene_manager = bare_node
	# Act
	menu._on_new_game_pressed()
	# Assert —— 到达此行即未崩溃（守卫分支 push_error 中止，无转场副作用）
	assert_eq(mock_sm.change_calls.size(), 0,
			"真实 mock 不应被调用（守卫在 bare_node 分支中止）")
	bare_node.free()


# ═══════════════════════════════════════════════════════════════════════════════
# 焦点导航（story Implementation Notes）
# ═══════════════════════════════════════════════════════════════════════════════

func test_navigation_initial_focus_continue_with_save() -> void:
	## 焦点: 有存档 → 初始焦点 = 继续游戏（UX 场景 2「零摩擦中转站」）。[br]
	## GAP-1 修复：注入存档后**二次实例化**场景让 _ready 真实运行——
	## 验证 MainMenu 的焦点决策分支，而非 grab_focus API 本身（code-review
	## 三方交叉确认原测试为同义反复）。
	# Arrange —— slots 先行注入，再实例化（_ready 读取 mock 槽位）
	mock_sl.slots = [_existing_slot()]
	var menu2: Control = MAIN_MENU_SCENE.instantiate()
	menu2.animate = false
	menu2.scene_manager = mock_sm
	menu2.save_load = mock_sl
	add_child(menu2)
	# Act + Assert —— _ready 已真实执行（add_child 同步触发）
	assert_eq(menu2.get_viewport().gui_get_focus_owner(), menu2.continue_button,
			"有存档时初始焦点应落在继续游戏（_ready 真实路径）")
	assert_false(menu2.continue_button.disabled, "有存档时继续按钮应可用")
	menu2.free()


func test_navigation_initial_focus_new_game_without_save() -> void:
	## 焦点: 无存档 → 初始焦点回退新游戏（story Implementation Notes）。[br]
	## GAP-1 修复：默认态二次实例化——无存档分支由 _ready 真实执行
	## （before_each 的 menu 是 slots 空态实例，此处独立重放验证）。
	# Arrange —— 无存档（slots 为空，_ready 默认态）
	var menu2: Control = MAIN_MENU_SCENE.instantiate()
	menu2.animate = false
	menu2.scene_manager = mock_sm
	menu2.save_load = mock_sl
	add_child(menu2)
	# Act + Assert
	assert_true(menu2.continue_button.disabled, "无存档时继续按钮应 disabled")
	assert_eq(menu2.get_viewport().gui_get_focus_owner(), menu2.new_game_button,
			"无存档时初始焦点应回退新游戏（_ready 真实路径）")
	menu2.free()


func test_navigation_focus_order_buttons_in_vbox() -> void:
	## 焦点顺序: 新游戏→继续→设置→退出（VBox 树序天然满足——断言树序）。[br]
	## 注：[code]Node.name[/code] 为 StringName——转 String 后比较（类型化数组
	## 严格相等拒绝 StringName/String 混比）。
	# Arrange
	var box: Node = menu.get_node("LayoutAnchor/ButtonBox")
	# Act
	var order: Array[String] = []
	for child: Node in box.get_children():
		if child is Button:
			order.append(String(child.name))
	# Assert
	assert_eq(order, ["NewGameButton", "ContinueButton", "SettingsButton",
			"QuitButton"], "按钮树序应为 新游戏→继续→设置→退出")


# ═══════════════════════════════════════════════════════════════════════════════
# 按钮状态与摘要（story AC + UX AC-EMPTY-01）
# ═══════════════════════════════════════════════════════════════════════════════

func test_navigation_summary_hidden_without_save() -> void:
	## UX AC-EMPTY-01: 无存档时摘要行隐藏（visible=false 占位保留——
	## 仍为 ButtonBox 子节点）。
	# Arrange —— slots 为空（before_each 默认态，_ready 已按无存档刷新）
	# Act + Assert
	assert_false(menu.save_summary_label.visible, "无存档时摘要行应隐藏")
	var summary_in_tree: bool = menu.save_summary_label.get_parent() != null
	assert_true(summary_in_tree, "摘要行占位保留（visible 而非从树移除）")


func test_navigation_summary_shown_with_save() -> void:
	## 有存档时摘要行显示「上次：[境界] · 游玩 [时长]」。
	# Arrange
	mock_sl.slots = [_existing_slot()]
	# Act —— 重入场景刷新存档状态
	mock_sl.load_completed.emit(true)
	# Assert
	assert_true(menu.save_summary_label.visible, "有存档时摘要行应显示")
	assert_eq(menu.save_summary_label.text, "上次：元婴期 · 游玩 2小时0分",
			"摘要应从 realm + playtime 组装")


func test_navigation_version_from_project_settings() -> void:
	## 版本号从 ProjectSettings 读取（非硬编码）——期望值与 project.godot
	## [code]application/config/version[/code] 一致（当前 "0.1.0-dev"）。
	# Arrange
	var expected: String = "v" + str(ProjectSettings.get_setting(
			&"application/config/version", ""))
	# Act + Assert
	assert_eq(menu.version_label.text, expected,
			"版本号应等于 project.godot 配置值（前缀 v）")


func test_navigation_quit_calls_tree_quit() -> void:
	## AC-main-menu-006: 退出按钮 → get_tree().quit()。[br]
	## headless GUT 不可真调 quit()（会请求进程退出、破坏后续测试的帧信号
	## 等待——全量回归挂死的根因）。改测路由契约：QuitButton.pressed 信号
	## 已连接到 [method MainMenu._on_quit_pressed]（场景 connection 声明）。
	## quit 真语义由 AC-5 手动演练覆盖。
	# Arrange —— 验证场景连接（.tscn [connection] 声明的运行时形态）
	var quit_button: Button = menu.get_node("LayoutAnchor/ButtonBox/QuitButton")
	# Act + Assert
	assert_true(quit_button.pressed.is_connected(menu._on_quit_pressed),
			"QuitButton.pressed 应连接到 _on_quit_pressed（场景声明）")
	assert_true(menu.has_method("_on_quit_pressed"),
			"退出路由方法应存在（quit 真调用由 AC-5 手动验证）")
