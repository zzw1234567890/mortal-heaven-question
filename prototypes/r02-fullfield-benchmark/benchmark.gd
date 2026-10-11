extends SceneTree
## R-02 满场实测（stub 版）——标准 + 峰值两场景 Draw Call 与帧时间采样。
##
## 复用 009a 测量方法（delta 基线 + 60 帧稳定均值），扩展为标准/峰值场景。
## 场景为程序化占位原型（角色卡/手牌/阵法/费用栏/日志/结算/箭头/光环/飘字），
## 实测结论为「原型级」——组件级复测归 combat-ui-layout epic DoD（Sprint 15）。
##
## 复现命令（窗口模式——headless DC 不具代表性）：
##   C:/Users/Administrator/Godot/Godot_v4.6.3-stable_win64.exe \
##     --path E:/mortal-heaven-question \
##     --script prototypes/r02-fullfield-benchmark/benchmark.gd

const SLOT_COUNT := 16
const HAND_COUNT := 7
const FORMATION_COUNT := 2
const FLOAT_TEXT_COUNT := 8
const FRAME_SAMPLE_SECONDS := 10.0


## HP 条自绘 Control——3 个 draw_rect = 3 DC（009a 实测修正）。
class HpBar extends Control:
	var ratio: float = 0.5

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.1, 0.1, 0.1))
		draw_rect(Rect2(r.position, Vector2(r.size.x * ratio, r.size.y)),
				Color(0.2, 0.8, 0.2))
		draw_rect(r, Color(0.5, 0.5, 0.5), false, 1.0)


## 状态图标条——同一图集 region 绘制（1 DC）。
class StatusIconStrip extends Control:
	var atlas: Texture2D
	var count: int = 3

	func _draw() -> void:
		for i in count:
			draw_texture_rect_region(atlas, Rect2(i * 24.0, 0.0, 20.0, 20.0),
					Rect2(i * 32.0, 0.0, 32.0, 32.0))


## 攻击箭头 stub——三条线。
class Arrow extends Control:
	func _draw() -> void:
		var p := Vector2(size.x * 0.1, size.y * 0.5)
		var q := Vector2(size.x * 0.9, size.y * 0.5)
		draw_line(p, q, Color(1.0, 0.3, 0.3), 2.0)
		draw_line(q, q + Vector2(-8, -6), Color(1.0, 0.3, 0.3), 2.0)
		draw_line(q, q + Vector2(-8, 6), Color(1.0, 0.3, 0.3), 2.0)


## 阵法光环 stub——圆环。
class Aura extends Control:
	func _draw() -> void:
		draw_arc(size * 0.5, min(size.x, size.y) * 0.45, 0.0, TAU, 32,
				Color(0.3, 0.8, 1.0, 0.6), 3.0)


func _init() -> void:
	_run()


func _sample_dc() -> int:
	for i in 5:
		await process_frame
	var acc := 0
	for i in 60:
		acc += int(RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		await process_frame
	return int(round(float(acc) / 60.0))


func _sample_frame_times(seconds: float) -> Array:
	var deltas: Array = []
	var prev := Time.get_ticks_usec()
	var frames := int(seconds * 60.0)
	for i in frames:
		await process_frame
		var now := Time.get_ticks_usec()
		deltas.append(float(now - prev) / 1000.0)
		prev = now
	return deltas


func _percentile(sorted_deltas: Array, p: float) -> float:
	if sorted_deltas.is_empty():
		return 0.0
	var idx := int(clamp(p, 0.0, 1.0) * (sorted_deltas.size() - 1))
	return sorted_deltas[idx]


func _run() -> void:
	print("=== R-02 满场实测（stub 版）——标准/峰值场景 DC + 帧时间 ===")
	print("渲染后端: ", RenderingServer.get_current_rendering_method())

	# 基线（空场景）
	var baseline_box := Control.new()
	baseline_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(baseline_box)
	var baseline: int = await _sample_dc()
	baseline_box.queue_free()
	await process_frame

	# 标准场景 + 帧时间采样
	var standard := _build_standard()
	root.add_child(standard)
	var standard_dc: int = await _sample_dc()
	var frame_times: Array = await _sample_frame_times(FRAME_SAMPLE_SECONDS)
	standard.queue_free()
	await process_frame

	# 峰值场景
	var peak := _build_peak()
	root.add_child(peak)
	var peak_dc: int = await _sample_dc()
	peak.queue_free()
	await process_frame

	# 统计
	var sorted_ft: Array = frame_times.duplicate()
	sorted_ft.sort()
	var p50: float = _percentile(sorted_ft, 0.50)
	var p95: float = _percentile(sorted_ft, 0.95)
	var p99: float = _percentile(sorted_ft, 0.99)

	print("baseline DC: ", baseline)
	print("标准场景 DC（净值）: ", standard_dc - baseline, "（整帧 ", standard_dc, "）")
	print("峰值场景 DC（净值）: ", peak_dc - baseline, "（整帧 ", peak_dc, "）")
	print("帧时间采样（", FRAME_SAMPLE_SECONDS, "s, ", sorted_ft.size(), " 帧）:")
	print("  p50: %.2f ms" % p50)
	print("  p95: %.2f ms" % p95)
	print("  p99: %.2f ms" % p99)
	print("  目标: p95 ≤ 16.6ms (60fps)")
	print("=== 基准结束 ===")
	quit()


func _make_atlas() -> Texture2D:
	var img := Image.create_empty(96, 32, false, Image.FORMAT_RGBA8)
	for i in 3:
		img.fill_rect(Rect2i(i * 32, 0, 32, 32), Color(0.5, 0.5, 0.2))
	return ImageTexture.create_from_image(img)


func _make_avatar(hue: float) -> Texture2D:
	var img := Image.create_empty(48, 48, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, 48, 48), Color.from_hsv(hue, 0.4, 0.6))
	return ImageTexture.create_from_image(img)


func _build_character_card(index: int, atlas: Texture2D) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(180, 90)
	var avatar := TextureRect.new()
	avatar.position = Vector2(4, 4)
	avatar.size = Vector2(48, 48)
	avatar.texture = _make_avatar(float(index) / SLOT_COUNT)
	card.add_child(avatar)
	var hp := HpBar.new()
	hp.position = Vector2(60, 8)
	hp.size = Vector2(110, 12)
	hp.ratio = 0.5 + (index % 10) * 0.05
	card.add_child(hp)
	var strip := StatusIconStrip.new()
	strip.position = Vector2(60, 26)
	strip.size = Vector2(68, 20)
	strip.atlas = atlas
	card.add_child(strip)
	var label := Label.new()
	label.position = Vector2(60, 52)
	label.text = "角色 %d" % index
	label.add_theme_font_size_override("font_size", 12)
	card.add_child(label)
	return card


func _build_hand_card(index: int) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(120, 60)
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(panel)
	var label := Label.new()
	label.position = Vector2(8, 20)
	label.text = "手牌 %d" % index
	label.add_theme_font_size_override("font_size", 12)
	card.add_child(label)
	return card


func _build_formation(index: int, atlas: Texture2D) -> Control:
	var f := Control.new()
	f.custom_minimum_size = Vector2(60, 60)
	var icon := TextureRect.new()
	icon.size = Vector2(24, 24)
	icon.texture = atlas
	f.add_child(icon)
	var label := Label.new()
	label.position = Vector2(0, 28)
	label.text = "阵%d" % index
	label.add_theme_font_size_override("font_size", 11)
	f.add_child(label)
	return f


func _build_cost_bar() -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(200, 24)
	var label := Label.new()
	label.text = "费用 3/10"
	label.add_theme_font_size_override("font_size", 14)
	bar.add_child(label)
	return bar


func _build_collapsed_log() -> Control:
	var log := Control.new()
	log.custom_minimum_size = Vector2(220, 18)
	var label := Label.new()
	label.text = "战斗日志（折叠）"
	label.add_theme_font_size_override("font_size", 11)
	log.add_child(label)
	return log


func _build_standard() -> Control:
	var box := Control.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	var atlas := _make_atlas()

	# 16 角色卡（4×4 网格）
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(10, 10)
	box.add_child(grid)
	for i in SLOT_COUNT:
		grid.add_child(_build_character_card(i, atlas))

	# 7 手牌（底部横排）
	var hand := HBoxContainer.new()
	hand.position = Vector2(10, 420)
	box.add_child(hand)
	for i in HAND_COUNT:
		hand.add_child(_build_hand_card(i))

	# 2 阵法
	var formations := HBoxContainer.new()
	formations.position = Vector2(10, 360)
	box.add_child(formations)
	for i in FORMATION_COUNT:
		formations.add_child(_build_formation(i, atlas))

	# 费用栏 + 日志折叠
	var cost := _build_cost_bar()
	cost.position = Vector2(600, 10)
	box.add_child(cost)
	var log := _build_collapsed_log()
	log.position = Vector2(600, 40)
	box.add_child(log)

	return box


func _build_peak() -> Control:
	var box := _build_standard()

	# 结算面板（胜利）
	var panel := Panel.new()
	panel.position = Vector2(250, 150)
	panel.size = Vector2(260, 120)
	var title := Label.new()
	title.position = Vector2(20, 20)
	title.text = "战斗胜利"
	title.add_theme_font_size_override("font_size", 20)
	panel.add_child(title)
	var detail := Label.new()
	detail.position = Vector2(20, 60)
	detail.text = "获得战利品"
	panel.add_child(detail)
	box.add_child(panel)

	# 攻击箭头 stub
	var arrow := Arrow.new()
	arrow.position = Vector2(120, 260)
	arrow.size = Vector2(80, 30)
	box.add_child(arrow)

	# 阵法光环 stub
	var aura := Aura.new()
	aura.position = Vector2(500, 300)
	aura.size = Vector2(120, 100)
	box.add_child(aura)

	# 飘字满发
	for i in FLOAT_TEXT_COUNT:
		var ft := Label.new()
		ft.text = "-%d" % (i * 7 + 3)
		ft.position = Vector2(150 + i * 45, 180 + (i % 4) * 26)
		ft.add_theme_font_size_override("font_size", 14)
		box.add_child(ft)

	return box
