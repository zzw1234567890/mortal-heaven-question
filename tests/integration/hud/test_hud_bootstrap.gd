extends GutTest
## Sprint 18 集成测试：HUD 生产挂载入口（HudBootstrap + 主菜单承载点）。
##
## 背景（gate-check 2026-11-08 §B1 / DEBT-EUI-005-6）：`HUD.tscn` 此前全库
## 无任何实例化点——境界条/灵石条/通知/暂停菜单在生产运行中永远不可见。
## 本文件验证补链后的契约：[br]
##   - [code]HudBootstrap.mount()[/code] 把 HUD 挂进 PersistentLayer 并调 setup；[br]
##   - 幂等——重复调用复用同一实例，不产生第二个 HUD；[br]
##   - 静默降级——null / 无 register_persistent 的 mock 返回 null 不抛错；[br]
##   - 主菜单承载点——[code]MainMenu._mount_hud()[/code] 走同一入口；[br]
##   - 非主场景实例不自动挂载（集成测试把主菜单当普通节点 add_child 的情形）。
##
## 风格先例：tests/integration/hud/test_hud_scene_visibility.gd（新建 SceneManager
## 实例 + 依赖 mock，不污染全局 Autoload 的 PersistentLayer）。

const SM := preload("res://src/foundation/scene_manager.gd")
const HudBootstrap := preload("res://src/ui/hud/hud_bootstrap.gd")
const MENU_SCENE: PackedScene = preload("res://src/ui/main_menu/MainMenu.tscn")
const MockFactory := preload("res://tests/integration/scene_manager/mocks/mock_factory.gd")

var sm: Node = null
var menu: Control = null
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


func after_each() -> void:
	# HUD 挂在 sm 的 PersistentLayer 下——随 sm 级联释放
	if menu != null and is_instance_valid(menu):
		menu.free()
	menu = null
	if sm != null and is_instance_valid(sm):
		sm.free()
		sm = null
	for m: Node in [_mock_gsm, _mock_im, _mock_sl]:
		if m != null and is_instance_valid(m):
			m.free()
	_mock_gsm = null
	_mock_im = null
	_mock_sl = null


## 该 SceneManager 下已挂载的 HUD（未挂载时 null）。
func _mounted_hud() -> Node:
	return sm.get_node_or_null(^"PersistentLayer/HUD")


# ═══════════════════════════════════════════════════════════════════════════════
# HudBootstrap.mount
# ═══════════════════════════════════════════════════════════════════════════════

func test_mount_attaches_hud_to_persistent_layer() -> void:
	# Act
	var hud: CanvasLayer = HudBootstrap.mount(sm)
	# Assert
	assert_not_null(hud, "mount 应返回 HUD 实例")
	assert_eq(hud.get_parent(), sm.get_node_or_null(^"PersistentLayer"),
			"HUD 应挂在 PersistentLayer 下（跨场景常驻）")
	assert_eq(hud.layer, 90, "HUD 的 CanvasLayer 层号应保持 90（暂停菜单置顶预算）")
	assert_true(HudBootstrap.is_mounted(sm), "is_mounted 应返回 true")


func test_mount_is_idempotent() -> void:
	# Arrange
	var first: CanvasLayer = HudBootstrap.mount(sm)
	# Act——模拟「读档/转场再次回到主菜单」
	var second: CanvasLayer = HudBootstrap.mount(sm)
	# Assert
	assert_eq(second, first, "重复挂载应复用同一实例")
	var hud_count: int = 0
	for child: Node in sm.get_node_or_null(^"PersistentLayer").get_children():
		if String(child.name).begins_with("HUD"):
			hud_count += 1
	assert_eq(hud_count, 1, "PersistentLayer 下只应存在 1 个 HUD（幂等）")


func test_mount_null_scene_manager_returns_null() -> void:
	# Act + Assert
	assert_null(HudBootstrap.mount(null), "SceneManager 为 null 时应静默返回 null")
	assert_false(HudBootstrap.is_mounted(null), "is_mounted(null) 应为 false")


func test_mount_rejects_manager_without_register_persistent() -> void:
	# Arrange——测试 mock 常常没有 register_persistent
	var stub := Node.new()
	add_child_autofree(stub)
	# Act + Assert
	assert_null(HudBootstrap.mount(stub), "不支持持久挂载的宿主应返回 null（不抛错）")


# ═══════════════════════════════════════════════════════════════════════════════
# 主菜单承载点
# ═══════════════════════════════════════════════════════════════════════════════

func test_main_menu_mount_hud_uses_bootstrap() -> void:
	# Arrange
	menu = MENU_SCENE.instantiate()
	menu.animate = false
	menu.scene_manager = sm
	add_child_autofree(menu)
	# Act
	var hud: CanvasLayer = menu._mount_hud()
	# Assert
	assert_not_null(hud, "主菜单应能挂载全局 HUD")
	assert_eq(hud, _mounted_hud(), "挂载目标应为 SceneManager 的 PersistentLayer")
	# 再次调用（重复进入主菜单）——复用
	assert_eq(menu._mount_hud(), hud, "重复挂载应返回同一 HUD")


func test_main_menu_does_not_auto_mount_when_not_current_scene() -> void:
	# Arrange——集成测试把主菜单当普通节点 add_child，current_scene 不是它
	menu = MENU_SCENE.instantiate()
	menu.animate = false
	menu.scene_manager = sm
	add_child(menu)
	# Act——等 call_deferred 执行
	await get_tree().process_frame
	# Assert
	assert_null(_mounted_hud(), "非运行主场景时不应自动挂载 HUD（避免测试进程多出常驻 HUD）")
	# 显式调用仍可挂载（守卫只拦自动路径）
	assert_not_null(menu._mount_hud(), "显式 _mount_hud 不受守卫限制")
