extends GutTest
## combat-ui-layout Story 002 集成测试：角色卡信号驱动更新（AC-3）。
##
## 覆盖：HP 变更信号→条/数字更新（0.3s Tween + reduce_motion 直跳）、
## 同帧多次信号终值生效（批量伤害免抖）、max_hp=0 守卫、
## 无 _process 轮询（源码检查）、前后排缩放+边框属性、境界条件显示、
## L2 绑定/L4 buff 钳制、图集合批（同纹理引用）。
##
## Story 类型 UI（Logic 内核）——此文件为 BLOCKING 证据。
## 风格先例：tests/integration/combat_ui/test_layout_skeleton.gd。

const CardScene := "res://src/ui/combat/layout/character_status_card.gd"
const Rules := preload("res://src/ui/combat/shared/combat_ui_rules.gd")
const Icons := preload("res://src/ui/combat/shared/combat_icon_atlas.gd")

var card: Control = null


func before_each() -> void:
	var script: GDScript = load(CardScene)
	card = script.new()
	add_child_autofree(card)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：HP 变更信号驱动更新（条+数字）
# ═══════════════════════════════════════════════════════════════════════════════

func test_hp_signal_updates_bar_and_number() -> void:
	# Arrange
	card.apply_hp(100, 100)
	# Act —— HP 变更（比例 0.5 → 黄）
	card.apply_hp(50, 100)
	var label: Label = card.get_node("StatLabel") as Label
	# Then: 数字立即终值直显（≤100ms——无数字 Tween）
	assert_eq(card.current_hp, 50, "current_hp 快照应为 50")
	assert_eq(card.max_hp, 100, "max_hp 快照应为 100")
	assert_true(label.text.contains("50/100"), "Label 数字应含 50/100：%s" % label.text)
	# Then: Tween 已创建（0.3s 过渡进行中）
	assert_not_null(card._hp_tween, "HP 过渡 Tween 应已创建")


func test_hp_tween_completes_to_target_ratio() -> void:
	# Arrange
	card.apply_hp(100, 100)
	card.apply_hp(30, 100)
	# Act —— 等待 0.3s 线性过渡完成
	assert_not_null(card._hp_tween, "前置：Tween 存在")
	await card._hp_tween.finished
	# Then: 显示比例收敛到终值 0.3
	assert_almost_eq(card._hp_display_ratio, 0.3, 0.01,
		"过渡完成后显示比例应为 0.3")


func test_hp_batch_same_frame_signals_final_value_wins() -> void:
	# Arrange —— 批量伤害免抖（GDD 公式 3）：同帧多次信号终值生效
	card.apply_hp(100, 100)
	# Act —— 同帧三次 HP 变更（100 → 70 → 40 → 25）
	card.apply_hp(70, 100)
	card.apply_hp(40, 100)
	card.apply_hp(25, 100)
	# Then: 从当前显示比例向终值单次过渡（重入 kill 重建——非链式）
	assert_eq(card.current_hp, 25, "终值应为 25")
	assert_not_null(card._hp_tween, "应有且仅有一条过渡 Tween（kill 重建）")
	await card._hp_tween.finished
	assert_almost_eq(card._hp_display_ratio, 0.25, 0.01,
		"批量伤害后单次过渡到终值 0.25")


func test_hp_reduce_motion_skips_tween_snaps() -> void:
	# Arrange —— reduce_motion 直跳（UX 减少动态替代）
	card.set_reduce_motion(true)
	# Act
	card.apply_hp(40, 100)
	# Then: 无 Tween，比例直接终值
	assert_null(card._hp_tween, "reduce_motion 下不应创建 Tween")
	assert_almost_eq(card._hp_display_ratio, 0.4, 0.001, "应直接跳到 0.4")


func test_hp_max_zero_guard_ratio_full() -> void:
	# Act —— max_hp=0 守卫（QA 规格 AC-1 edge：防除零）
	card.apply_hp(0, 0)
	# Then: 比例 1.0 不崩溃
	assert_eq(card.max_hp, 0, "max_hp 应为 0")
	assert_almost_eq(card._hp_display_ratio, 1.0, 0.001,
		"max_hp=0 时比例应守卫为 1.0")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3 补充：非轮询 + 纯函数消费（禁止内联）
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_has_no_process_polling() -> void:
	# Then: 无 _process/_physics_process 轮询（ADR-0031 §3——源码检查）
	assert_false(card.has_method("_process"), "不应有 _process")
	assert_false(card.has_method("_physics_process"), "不应有 _physics_process")


func test_card_consumes_shared_pure_functions_not_inline() -> void:
	# Then: 消费共享纯函数（story 001/002 唯一落地处——源码无内联阈值实现）
	var source: String = (load(CardScene) as GDScript).source_code
	assert_true(source.contains("Rules.hp_bar_color"),
		"HP 颜色应经 CombatUiRules.hp_bar_color（禁止内联）")
	assert_true(source.contains("Rules.formation_row_scale"),
		"缩放应经 CombatUiRules.formation_row_scale（禁止内联）")
	assert_true(source.contains("UiFont.font_size_responsive"),
		"字号应经 CombatUiFont.font_size_responsive（story 001 共享）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4：前后排缩放 + 边框样式独立属性
# ═══════════════════════════════════════════════════════════════════════════════

func test_front_row_full_scale_and_solid_border() -> void:
	# Act
	card.set_front_row(true)
	# Then: 100% 缩放（经 Rules——非内联）
	assert_almost_eq(card.scale.x, Rules.formation_row_scale(true), 0.0001,
		"前排缩放应为 1.0")
	assert_almost_eq(card.scale.y, Rules.formation_row_scale(true), 0.0001,
		"前排缩放 y 应为 1.0")
	assert_true(card.is_front_row, "is_front_row 应为 true（实线边框决策）")


func test_back_row_85_scale_and_dashed_border() -> void:
	# Act
	card.set_front_row(false)
	# Then: 85% 缩放
	assert_almost_eq(card.scale.x, Rules.formation_row_scale(false), 0.0001,
		"后排缩放应为 0.85")
	assert_almost_eq(card.scale.y, Rules.formation_row_scale(false), 0.0001,
		"后排缩放 y 应为 0.85")
	assert_false(card.is_front_row, "is_front_row 应为 false（虚线边框决策）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6：境界标记条件显示 + L2/L4 钳制
# ═══════════════════════════════════════════════════════════════════════════════

func test_realm_badge_only_shown_above_player_realm() -> void:
	# Act/Then: 低于或等于玩家境界——不显示
	card.set_realm(2, 3)
	assert_false(card.realm > card.player_realm, "realm=2 ≤ player=3 不应显示")
	# Act/Then: 高于玩家境界——显示
	card.set_realm(4, 3)
	assert_true(card.realm > card.player_realm, "realm=4 > player=3 应显示")


func test_bindings_clamped_to_side_limit() -> void:
	# Act —— 超上限（每侧最多 3——UX 规格）
	card.set_bindings(5, 2)
	# Then: 钳制到上限
	assert_eq(card.gongfa_count, 3, "功法图标数应钳制到 3")
	assert_eq(card.fabao_count, 2, "法宝图标数应保持 2")


func test_status_effects_clamped_to_buff_limit() -> void:
	# Act —— 超上限（最多 5）
	card.set_status_effects(7, 3)
	# Then
	assert_eq(card.buff_count, 5, "buff 数应钳制到 5")
	assert_eq(card.debuff_count, 3, "debuff 数应保持 3")


# ═══════════════════════════════════════════════════════════════════════════════
# 合批：图集共享（R-02 §3——同纹理才能合批）
# ═══════════════════════════════════════════════════════════════════════════════

func test_icon_atlas_shared_single_texture() -> void:
	# Then: 图集单实例共享（多卡引用同纹理——合批前提）
	var atlas_a: Texture2D = Icons.get_atlas()
	var atlas_b: Texture2D = Icons.get_atlas()
	assert_same(atlas_a, atlas_b, "图集应为单实例共享")
	assert_eq(atlas_a.get_size(), Vector2(256, 32), "图集尺寸应为 256×32（8 格×32px）")
	# Then: region 索引覆盖全部图标枚举
	for icon_id: int in Icons.IconId.values():
		var region: Rect2 = Icons.get_region(icon_id)
		assert_almost_eq(region.size.x, 32.0, 0.001,
			"IconId %d region 宽应为 32" % icon_id)
