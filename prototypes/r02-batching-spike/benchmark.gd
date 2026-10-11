extends SceneTree
## R-02 合批基准原型——程序化构造 16 角色卡，采样 Draw Call（009b 复用测量方法）。
##
## 按合批规范（r02-batching-spec.md §3）构造，每角色卡预期 4 DC：
##   - 头像：独立纹理（每角色唯一，无法图集化）→ 1 DC
##   - 状态图标：同一 AtlasTexture 图集的 3 个 region（单一 CanvasItem
##     draw_texture_rect_region——同纹理合批）→ 1 DC
##   - HP 条：自绘 Control（_draw() 内 draw_rect 纯色）→ 1 DC
##   - 文字：Label（引擎默认字体图集合批）→ 1 DC
##
## 测量方法（delta——隔离固定开销）：
##   baseline DC = 空场景（仅根 Control）稳定值
##   full DC     = 16 角色卡稳定值
##   角色卡净成本 = full - baseline；每角色位 = 净成本 / 16
## 仅用「full/16」会高估（把窗口/清屏等固定开销摊到每张卡上）。
##
## 复现命令（窗口模式——headless DC 不具代表性）：
##   C:/Users/Administrator/Godot/Godot_v4.6.3-stable_win64.exe \
##     --path E:/mortal-heaven-question \
##     --script prototypes/r02-batching-spike/benchmark.gd

const SLOT_COUNT := 16

## HP 条自绘 Control——单一 CanvasItem 纯色绘制（合批规范 §2）。
class HpBar extends Control:
	var ratio: float = 0.5

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.1, 0.1, 0.1))               # 底槽
		draw_rect(Rect2(r.position, Vector2(r.size.x * ratio, r.size.y)),
				Color(0.2, 0.8, 0.2))                     # 前景
		draw_rect(r, Color(0.5, 0.5, 0.5), false, 1.0)   # 边框


## 状态图标条——3 个状态图标作为同一图集纹理的 region 绘制（合批规范 §3）。
## 单一 CanvasItem + 同纹理 draw_texture_rect_region → 1 draw call。
class StatusIconStrip extends Control:
	var atlas: Texture2D = null
	var count: int = 3

	func _draw() -> void:
		if atlas == null:
			return
		for i in count:
			var src := Rect2(i * 32.0, 0.0, 32.0, 32.0)
			var dst := Rect2(i * 24.0, 0.0, 20.0, 20.0)
			draw_texture_rect_region(atlas, dst, src)


func _init() -> void:
	_run()


func _sample_dc() -> int:
	## 采样稳定 DC——预热 5 帧后取 60 帧均值（避免首帧尖峰与帧间抖动）。
	var acc: int = 0
	for i in 5:
		await process_frame
	for i in 60:
		acc += int(RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		await process_frame
	return int(round(float(acc) / 60.0))


func _run() -> void:
	print("=== R-02 基准原型：16 角色卡 DC 采样（图集合批方案，delta 测量） ===")
	print("渲染后端: ", RenderingServer.get_current_rendering_method())

	# 基线——空场景（仅根 Control）
	var baseline_box := Control.new()
	baseline_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(baseline_box)
	var baseline: int = await _sample_dc()
	baseline_box.queue_free()
	await process_frame

	# 满载——16 角色卡
	var atlas := _make_atlas()
	var cards := _build_cards(atlas)
	root.add_child(cards)
	var full: int = await _sample_dc()

	var net: int = full - baseline
	print("baseline DC（空场景固定开销）: ", baseline)
	print("full DC（16 角色卡）: ", full)
	print("角色卡净成本: ", net)
	print("每角色位 DC ≈ %.1f" % (float(net) / SLOT_COUNT))
	print("目标：每角色位 ≤4（净成本 ≤64）")
	print("=== 基准结束 ===")
	quit()


func _make_atlas() -> Texture2D:
	## 共享状态图标图集——96×32（3 个 32×32 图标横排）。
	var img := Image.create_empty(96, 32, false, Image.FORMAT_RGBA8)
	for i in 3:
		img.fill_rect(Rect2i(i * 32, 0, 32, 32), Color(0.5, 0.5, 0.2))
	return ImageTexture.create_from_image(img)


func _make_avatar(hue: float) -> Texture2D:
	## 每角色唯一头像纹理——48×48（独立纹理，无法图集化）。
	var img := Image.create_empty(48, 48, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, 48, 48), Color.from_hsv(hue, 0.4, 0.6))
	return ImageTexture.create_from_image(img)


func _build_cards(atlas: Texture2D) -> Control:
	var root_box := Control.new()
	root_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grid := GridContainer.new()
	grid.columns = 4
	root_box.add_child(grid)
	for i in SLOT_COUNT:
		grid.add_child(_build_card(i, atlas))
	return root_box


func _build_card(index: int, atlas: Texture2D) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(180, 90)
	# 头像——独立纹理（1 DC）
	var avatar := TextureRect.new()
	avatar.position = Vector2(4, 4)
	avatar.size = Vector2(48, 48)
	avatar.texture = _make_avatar(float(index) / SLOT_COUNT)
	card.add_child(avatar)
	# HP 条——自绘（1 DC）
	var hp := HpBar.new()
	hp.position = Vector2(60, 8)
	hp.size = Vector2(110, 12)
	hp.ratio = 0.5 + (index % 10) * 0.05
	card.add_child(hp)
	# 状态图标——同一图集 region（1 DC）
	var strip := StatusIconStrip.new()
	strip.position = Vector2(60, 26)
	strip.size = Vector2(68, 20)
	strip.atlas = atlas
	strip.count = 3
	card.add_child(strip)
	# 文字（1 DC）
	var label := Label.new()
	label.position = Vector2(60, 52)
	label.text = "角色 %d" % index
	label.add_theme_font_size_override("font_size", 12)
	card.add_child(label)
	return card
