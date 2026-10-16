extends GutTest
## TD-012（S15-1）: _apply_deck 视觉接线集成断言——超限三态 + elif 遮蔽。
##
## 补齐 Story 003 QL 关卡 GAP-1 遗留缺口（docs/tech-debt-register.md TD-012）：
##   1. 超限态：[code]deck_label.label_settings.font_color == Color("#B3424A")[/code]
##      （B-1 修复路径——直写独立 LabelSettings）+ [code]overlimit_label.visible
##      == true[/code]
##   2. 恰等于上限（黄）/ 正常（墨）两态回归
##   3. H-1 闪烁 Tween 误重建防护——超限持续期间刷新不 kill/重建循环 Tween
##   4. [code]_on_batch_updated[/code] lingshi+deck 同帧双键 elif 遮蔽路径——
##      lingshi_hit 优先，delta 浮动触发而卡组行同帧一并刷新（_refresh 全量）
##
## 测试策略：复用 test_gsm_signal_binding.gd 的真实 GSM Autoload 模式——
## LingshiDeckBar 直连真实 GSM + DeckEditingSystem Autoload，直写
## deck.current_deck + 手动 emit batch（同步信号无帧时序）。
## Story 类型 Integration——此文件为 TD-012 阻塞项。

const BAR_SCENE: PackedScene = preload("res://src/ui/hud/LingshiDeckBar.tscn")

var gsm: Node = null
var bar: Control = null
var _saved_lingshi: int = 0
var _saved_deck: Array = []


func before_each() -> void:
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		fail_test("GSM Autoload 未注册")
		return
	# 保存原值——after_each 复原（测试自行清理，G4 裁决先例）
	_saved_lingshi = int(gsm.player.resources.ling_shi)
	_saved_deck = gsm.deck.current_deck.duplicate()
	gsm.player.resources.ling_shi = 100  # 独立基线——避免用例间残留耦合
	gsm.set("_pending_changes", {})
	bar = BAR_SCENE.instantiate()
	bar.animate = false  # 测试注入点：跳过滚动/闪烁动画，断言纯数据终态
	add_child(bar)


func after_each() -> void:
	if bar != null and is_instance_valid(bar):
		# 断开 GSM 信号——bar 释放前摘除订阅（防后续用例误触发已释放节点）
		if gsm != null and is_instance_valid(gsm):
			if gsm.resource_changed.is_connected(bar._on_resource_changed):
				gsm.resource_changed.disconnect(bar._on_resource_changed)
			if gsm.batch_updated.is_connected(bar._on_batch_updated):
				gsm.batch_updated.disconnect(bar._on_batch_updated)
		bar.free()
	bar = null
	if gsm != null and is_instance_valid(gsm):
		gsm.set("_pending_changes", {})
		gsm.player.resources.ling_shi = _saved_lingshi
		gsm.deck.current_deck = _saved_deck
	gsm = null


## 写入卡组内容并发 deck 路径 batch 信号——驱动 _apply_deck 的标准入口。
func _emit_deck_batch(new_deck: Array) -> void:
	var old_deck: Array = gsm.deck.current_deck.duplicate()
	gsm.deck.current_deck = new_deck
	gsm.batch_updated.emit({"deck.current_deck": {"old": old_deck, "new": new_deck}})


## 当前系统卡组上限（get_deck_limit 按 player.realm 计算——不钉死具体值）。
func _current_deck_limit() -> int:
	var ds: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/DeckEditingSystem")
	return int(ds.get_deck_summary()["limit"])


# ═══════════════════════════════════════════════════════════════════════════════
# 覆盖 1：超限态三视觉断言（B-1 直写路径 + 超限标记 + 闪烁重建）
# ═══════════════════════════════════════════════════════════════════════════════

func test_overlimit_state_font_color_and_marker_visible() -> void:
	## 超限态（count > cap）：deck_label 直写独立 LabelSettings.font_color
	## 为朱砂红 #B3424A（B-1 修复路径——add_theme_color_override 在共享
	## LabelSettings 下永不生效，此断言捕获该原始 bug）+ overlimit_label 可见。
	var limit: int = _current_deck_limit()
	# Act —— 超限 1 张
	_emit_deck_batch(range(limit + 1))
	# Assert —— 三断言：文本 / 直写色 / 超限标记
	var deck_label: Label = bar.get_node(^"DeckLabel")
	assert_eq(str(deck_label.text), "📜 %d/%d" % [limit + 1, limit],
		"超限态卡组文本应为 (cap+1)/cap")
	assert_eq(deck_label.label_settings.font_color, Color("#B3424A"),
		"超限态 font_color 应直写朱砂红 #B3424A（B-1 路径）")
	var overlimit_label: Label = bar.get_node(^"OverlimitLabel")
	assert_true(overlimit_label.visible, "超限态 overlimit_label 应可见")


func test_overlimit_state_animate_false_static_red_no_tween() -> void:
	## 超限闪烁 H-2 静态降级——animate=false 时不建循环 Tween，
	## 以半透明静态红呈现（reduce-motion 接线点）
	var limit: int = _current_deck_limit()
	_emit_deck_batch(range(limit + 1))
	assert_eq(bar._overlimit_tween, null, "animate=false 超限不应创建闪烁 Tween")
	assert_almost_eq(float(bar.get_node(^"DeckLabel").modulate.a), 0.6, 0.01,
		"animate=false 超限应静态半透明（modulate.a=0.6）")


# ═══════════════════════════════════════════════════════════════════════════════
# 覆盖 2：恰等上限（黄）/ 正常（墨）回归 + 超限回落
# ═══════════════════════════════════════════════════════════════════════════════

func test_at_limit_state_yellow_not_overlimit() -> void:
	## 恰等于上限（count == cap）：琉璃金 #C8A84E + 无超限标记
	var limit: int = _current_deck_limit()
	_emit_deck_batch(range(limit))
	var deck_label: Label = bar.get_node(^"DeckLabel")
	assert_eq(deck_label.label_settings.font_color, Color("#C8A84E"),
		"恰等上限 font_color 应为琉璃金 #C8A84E")
	assert_false(bar.get_node(^"OverlimitLabel").visible, "恰等上限超限标记不应可见")


func test_normal_state_ink_color() -> void:
	## 正常态（count < cap）：墨色 #1A1A1A + 无超限标记
	var limit: int = _current_deck_limit()
	_emit_deck_batch(range(maxi(limit - 1, 1)))
	var deck_label: Label = bar.get_node(^"DeckLabel")
	assert_eq(deck_label.label_settings.font_color, Color("#1A1A1A"),
		"正常态 font_color 应为墨色 #1A1A1A")
	assert_false(bar.get_node(^"OverlimitLabel").visible, "正常态超限标记不应可见")


func test_overlimit_recovery_stops_flicker() -> void:
	## 超限 → 弃牌回到上限内：overlimit 翻转 false、标记隐藏（停止条件路径）
	var limit: int = _current_deck_limit()
	_emit_deck_batch(range(limit + 1))
	# Act —— 回落到正常
	_emit_deck_batch(range(limit - 1))
	# Assert
	assert_false(bar.get_node(^"OverlimitLabel").visible, "回落后超限标记应隐藏")
	assert_false(bool(bar._last_overlimit), "回落后 _last_overlimit 应翻转 false")


# ═══════════════════════════════════════════════════════════════════════════════
# 覆盖 3：H-1 闪烁 Tween 误重建防护
# ═══════════════════════════════════════════════════════════════════════════════

func test_overlimit_persistent_refresh_no_flicker_rebuild() -> void:
	## 超限持续期间的同键刷新——不 kill/重建闪烁 Tween（H-1 修复：
	## _stop_overlimit_flicker 不触碰 _last_overlimit，翻转检测仅由
	## _apply_deck 管理——防每次刷新误判翻转重建循环动画）。
	## animate=false 下闪烁走静态降级——重建检测用 animate=true 走 Tween 路径。
	bar.animate = true
	var limit: int = _current_deck_limit()
	_emit_deck_batch(range(limit + 1))
	var flicker_tween: Tween = bar._overlimit_tween
	assert_ne(flicker_tween, null, "前置：animate=true 超限应创建闪烁 Tween")
	# Act —— 超限持续期间的无关路径刷新（灵石变更触发 _refresh 全量——
	## _apply_deck 以同 deck_key 重复调用）
	gsm.player.resources.ling_shi = 150
	gsm.batch_updated.emit({"player.resources.ling_shi": {"old": 100, "new": 150}})
	# Assert —— Tween 句柄不变（未 kill 重建）
	assert_eq(bar._overlimit_tween, flicker_tween,
		"超限持续期间刷新不应重建闪烁 Tween（H-1 回归）")


# ═══════════════════════════════════════════════════════════════════════════════
# 覆盖 4：_on_batch_updated lingshi+deck 同帧双键 elif 遮蔽路径
# ═══════════════════════════════════════════════════════════════════════════════

func test_batch_dual_key_lingshi_priority_deck_still_refreshed() -> void:
	## 同帧双键：lingshi+deck 同时出现在 batch 载荷——elif 使 lingshi_hit
	## 分支优先（携带 delta 参数），但 _refresh 是全量刷新——卡组行同帧
	## 一并更新（遮蔽不丢卡组刷新）。
	var limit: int = _current_deck_limit()
	# Arrange —— 直写双路径载荷（同帧多变更模拟——GSM 真实行为）
	var old_deck: Array = gsm.deck.current_deck.duplicate()
	var new_deck: Array = range(limit + 1)  # 超限卡组
	gsm.deck.current_deck = new_deck
	gsm.player.resources.ling_shi = 180
	# Act —— 双键 batch
	gsm.batch_updated.emit({
		"player.resources.ling_shi": {"old": 100, "new": 180},
		"deck.current_deck": {"old": old_deck, "new": new_deck},
	})
	# Assert —— 两行都刷新：灵石行新值 + 卡组行超限态（遮蔽不丢刷新）
	assert_eq(str(bar.get_node(^"LingshiLabel").text), "🪙 180",
		"双键 batch 灵石行应刷新（elif 优先分支）")
	var deck_label: Label = bar.get_node(^"DeckLabel")
	assert_eq(deck_label.label_settings.font_color, Color("#B3424A"),
		"双键 batch 卡组行应同帧刷新为超限红（_refresh 全量——遮蔽不丢）")
	assert_true(bar.get_node(^"OverlimitLabel").visible, "双键 batch 超限标记应可见")
