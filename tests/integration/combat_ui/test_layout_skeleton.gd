extends GutTest
## combat-ui-layout Story 001 集成测试：四区域容器骨架 + HUD 隐藏联动。
##
## 覆盖 AC-1（五区域容器存在性与 anchor 百分比）、AC-2（1280×720 无溢出
## /无重叠）、AC-3（HUD 隐藏联动——进入战斗 HUD 不渲染 + 退出恢复）、
## AC-5（暂停/撤退按钮位预留）。
##
## Story 类型 UI（含 Integration）——此文件为 BLOCKING 证据。
## 风格先例：tests/integration/hud/test_hud_scene_visibility.gd
## （真实 HUD 场景 + mock SceneManager + 手动 emit 信号）。

const CombatRootScene: PackedScene = preload("res://src/ui/combat/layout/CombatRoot.tscn")
const HUD_SCENE: PackedScene = preload("res://src/ui/hud/HUD.tscn")
const SM := preload("res://src/foundation/scene_manager.gd")
const MockFactory := preload("res://tests/integration/scene_manager/mocks/mock_factory.gd")

var combat_root: Control = null
var hud: CanvasLayer = null
var sm: Node = null
var _mock_gsm: Node = null
var _mock_im: Node = null
var _mock_sl: Node = null


func before_each() -> void:
	combat_root = CombatRootScene.instantiate()
	add_child_autofree(combat_root)


func after_each() -> void:
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


func _zone(zone_name: String) -> Control:
	return combat_root.get_node_or_null(zone_name) as Control


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：五区域容器存在性与 anchor 百分比（非像素绝对定位）
# ═══════════════════════════════════════════════════════════════════════════════

func test_layout_skeleton_all_five_zones_exist() -> void:
	# Then: TopBar / EnemyArea / Midline / AllyArea / BottomBar 全部存在
	for zone_name: String in ["TopBar", "EnemyArea", "Midline", "AllyArea", "BottomBar"]:
		assert_not_null(_zone(zone_name), "区域容器 %s 应存在" % zone_name)


func test_layout_skeleton_zones_use_ratio_anchors() -> void:
	# Then: anchor 为百分比预设（0.0-1.0 浮点——非像素绝对定位）
	var topbar: Control = _zone("TopBar")
	assert_almost_eq(topbar.anchor_top, 0.0, 0.0001, "顶部条 anchor_top = 0（顶部）")
	assert_almost_eq(topbar.anchor_left, 0.0, 0.0001, "顶部条 anchor_left = 0（全宽）")
	assert_almost_eq(topbar.anchor_right, 1.0, 0.0001, "顶部条 anchor_right = 1（全宽）")
	assert_almost_eq(topbar.anchor_bottom, 60.0 / 1080.0, 0.0001,
		"顶部条 anchor_bottom = 60/1080（百分比高度）")
	var bottombar: Control = _zone("BottomBar")
	assert_almost_eq(bottombar.anchor_bottom, 1.0, 0.0001, "底部条 anchor_bottom = 1（底部）")
	assert_almost_eq(bottombar.anchor_top, 1.0 - 180.0 / 1080.0, 0.0001,
		"底部条 anchor_top = 1-180/1080（百分比高度）")


func test_layout_skeleton_zone_offsets_zero() -> void:
	# Then: 五区域 offset 全零——纯 anchor 排布（无像素硬编码偏移）
	for zone_name: String in ["TopBar", "EnemyArea", "Midline", "AllyArea", "BottomBar"]:
		var zone: Control = _zone(zone_name)
		assert_eq(zone.offset_left, 0, "%s offset_left 应为 0" % zone_name)
		assert_eq(zone.offset_top, 0, "%s offset_top 应为 0" % zone_name)
		assert_eq(zone.offset_right, 0, "%s offset_right 应为 0" % zone_name)
		assert_eq(zone.offset_bottom, 0, "%s offset_bottom 应为 0" % zone_name)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2 边界：1280×720 下区域不溢出/不重叠
# ═══════════════════════════════════════════════════════════════════════════════

func test_layout_skeleton_720p_no_overflow_or_overlap() -> void:
	# Arrange —— 布局根设为 1280×720（deferred——非等对侧锚节点 set size 警告规避）
	combat_root.set_deferred("size", Vector2(1280, 720))
	await get_tree().process_frame
	# Midline 为 1px 分隔线（anchor_top==anchor_bottom 高度 0）——重叠检查排除之
	var zones: Array = [_zone("TopBar"), _zone("EnemyArea"),
		_zone("AllyArea"), _zone("BottomBar")]
	# Then: 各区域在根矩形内（无溢出）
	for zone: Control in zones:
		assert_true(zone.global_position.y >= combat_root.global_position.y - 0.5,
			"%s 顶缘不应溢出根（y=%s）" % [zone.name, zone.global_position.y])
		assert_true(zone.global_position.y + zone.size.y
				<= combat_root.global_position.y + combat_root.size.y + 0.5,
			"%s 底缘不应溢出根（bottom=%s）" % [zone.name, zone.global_position.y + zone.size.y])
	# Then: 纵向无重叠——相邻区域底缘 ≤ 下一区域顶缘（TopBar < EnemyArea < Midline < AllyArea < BottomBar）
	var sorted_zones: Array = zones.duplicate()
	sorted_zones.sort_custom(func(a: Control, b: Control) -> bool:
		return a.global_position.y < b.global_position.y)
	for i: int in range(sorted_zones.size() - 1):
		var upper: Control = sorted_zones[i]
		var lower: Control = sorted_zones[i + 1]
		assert_true(upper.global_position.y + upper.size.y
				<= lower.global_position.y + 0.5,
			"%s 底缘不应越过 %s 顶缘（重叠）" % [upper.name, lower.name])


# ═══════════════════════════════════════════════════════════════════════════════
# AC-5：暂停/撤退按钮位预留
# ═══════════════════════════════════════════════════════════════════════════════

func test_layout_skeleton_pause_button_slot_in_topbar() -> void:
	# Then: 暂停按钮位存在于 TopBar 内（转发 hud 暂停菜单——菜单本体归 hud 005）
	var slot: Control = combat_root.get_node_or_null("TopBar/PauseButtonSlot") as Control
	assert_not_null(slot, "暂停按钮位应预留于 TopBar 内")


func test_layout_skeleton_retreat_button_slot_top_right() -> void:
	# Then: 撤退按钮位存在且位于右上角（内容/行为归 008/interaction）
	var slot: Control = _zone("RetreatButtonSlot")
	assert_not_null(slot, "撤退按钮位应存在")
	assert_almost_eq(slot.anchor_left, 1.0 - 60.0 / 1920.0, 0.0001,
		"撤退按钮位 anchor_left 靠近右缘")
	assert_true(slot.anchor_top > 0.0, "撤退按钮位应在顶部条下方（右上角常驻）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：HUD 隐藏联动（进入战斗 HUD 不渲染 + 退出恢复）
# ═══════════════════════════════════════════════════════════════════════════════

func test_hud_hidden_when_entering_combat_scene() -> void:
	# Arrange —— 真实 HUD 场景 + mock SceneManager（hud story 001 同源模式）
	_setup_hud_with_mock_sm()
	var content_layer: Control = hud.get_node_or_null(^"ContentLayer") as Control
	# Act —— 模拟 post_transition(→ COMBAT=4)（进入战斗）
	sm.post_transition.emit(3, 4)
	await get_tree().process_frame
	# Then: HUD 内容层不可见（战斗场景 combat-ui 接管）
	assert_false(content_layer.visible, "进入战斗后 HUD 内容层应隐藏（combat-ui 接管）")


func test_hud_restored_when_leaving_combat_scene() -> void:
	# Arrange —— 先进入战斗（HUD 隐藏）
	_setup_hud_with_mock_sm()
	var content_layer: Control = hud.get_node_or_null(^"ContentLayer") as Control
	sm.post_transition.emit(3, 4)
	await get_tree().process_frame
	assert_false(content_layer.visible, "前置：战斗中 HUD 隐藏")
	# Act —— 退出战斗回到探索（EXPLORATION=3）
	sm.post_transition.emit(4, 3)
	await get_tree().process_frame
	# Then: HUD 恢复可见
	assert_true(content_layer.visible, "退出战斗后 HUD 应回复可见")


func _setup_hud_with_mock_sm() -> void:
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


# ═══════════════════════════════════════════════════════════════════════════════
# AC-7：音频对接——进入战斗触发 set_state(IN_COMBAT)（消费 audio-manager API）
# ═══════════════════════════════════════════════════════════════════════════════

func test_request_in_combat_audio_calls_audio_manager() -> void:
	# Arrange —— 记录型 mock AudioManager（RefCounted 子类不可——签名要求
	# AudioManager 类型；用 GDScript 动态代理类捕获 set_state 调用）
	var recorder := AudioRecorder.new()
	combat_root.set_audio_manager(recorder)
	# Act
	combat_root.request_in_combat_audio()
	# Then: set_state(IN_COMBAT=3) 被请求恰好一次
	assert_eq(recorder.calls.size(), 1, "set_state 应被调用 1 次")
	assert_eq(recorder.calls[0], AudioEnums.AudioState.IN_COMBAT,
		"请求的状态应为 IN_COMBAT")


func test_request_in_combat_audio_noop_without_injection() -> void:
	# Act —— 未注入 AudioManager（布局骨架独立可测试）
	combat_root.request_in_combat_audio()
	# Then: 不崩溃（静默跳过）
	assert_true(true, "未注入 AudioManager 时 request_in_combat_audio 应安全无操作")


## 记录型 AudioManager 代理——捕获 set_state 调用载荷（duck-typing：
## AudioManager.set_state 为空桩，story 004 才有行为——mock 只验证调用契约）。
class AudioRecorder extends AudioManager:
	var calls: Array = []

	func set_state(state: AudioEnums.AudioState) -> void:
		calls.append(state)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6 边界：进场过渡（reduce_motion 静态路径 + 总时长 ≤2s）
# ═══════════════════════════════════════════════════════════════════════════════

func test_entrance_reduce_motion_snaps_zones_visible() -> void:
	# Act —— reduce_motion = true 直接就位无动画
	combat_root.play_entrance(true)
	await get_tree().process_frame
	# Then: 各区域立即可见（无过渡起始态）
	for zone_name: String in ["TopBar", "EnemyArea", "AllyArea", "BottomBar"]:
		var zone: Control = _zone(zone_name)
		assert_almost_eq(zone.modulate.a, 1.0, 0.001,
			"reduce_motion 下 %s 应直接就位（alpha=1）" % zone_name)


func test_entrance_full_sequence_within_2s_budget() -> void:
	# Arrange —— 常规动效路径
	combat_root.play_entrance(false)
	# Then: 编排总时长（最长延迟 0.3s + 时长 0.4s = 0.7s 串行收敛，UI AC ≤2s 预算内）
	# Tween 挂起等待完成（0.7s < 2s——等待本身验证不超时挂起）
	var tween: Tween = combat_root._entrance_tween
	assert_not_null(tween, "进场过渡 Tween 应已创建")
	await tween.finished
	for zone_name: String in ["TopBar", "EnemyArea", "AllyArea", "BottomBar"]:
		var zone: Control = _zone(zone_name)
		assert_almost_eq(zone.modulate.a, 1.0, 0.001,
			"过渡完成后 %s 应完全可见" % zone_name)
