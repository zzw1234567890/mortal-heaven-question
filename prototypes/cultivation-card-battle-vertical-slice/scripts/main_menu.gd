# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: 玩家能否在 3 分钟内完成一场卡牌战斗？
# Date: 2026-07-27
##
## 主菜单 —— 「左序」布局。
## 背景用纯色深色底 + 程序化水墨线条（用多个 Control 节点模拟），
## 左侧面板半透明悬浮在背景之上，无分割线。

class_name VSMainMenu
extends Control

@onready var new_game_button: Button = $"LeftPanel/NewGameButton"
@onready var quit_button: Button = $"LeftPanel/QuitButton"


func _ready() -> void:
	new_game_button.grab_focus()
	_create_ink_wash_background()


func _create_ink_wash_background() -> void:
	# 创建水墨风格背景——程序化生成，无外部纹理依赖
	# 视觉方向：「墨骨丹青」——黑白为骨，一色为魂

	# 1. 远山剪影（底部，多层叠加）
	_draw_mountain_layer(0.35, 0.95, 0.22, 0.15, Color(0.18, 0.15, 0.12, 0.35))
	_draw_mountain_layer(0.42, 0.92, 0.18, 0.12, Color(0.22, 0.18, 0.15, 0.28))
	_draw_mountain_layer(0.50, 0.88, 0.14, 0.10, Color(0.25, 0.20, 0.17, 0.22))

	# 2. 云海（中部，半透明圆形叠加）
	_draw_cloud_cluster(0.45, 0.55, 0.12, Color(0.35, 0.30, 0.25, 0.08))
	_draw_cloud_cluster(0.60, 0.48, 0.15, Color(0.32, 0.28, 0.24, 0.06))
	_draw_cloud_cluster(0.72, 0.52, 0.10, Color(0.38, 0.33, 0.28, 0.07))
	_draw_cloud_cluster(0.55, 0.62, 0.13, Color(0.30, 0.26, 0.22, 0.05))

	# 3. 水墨笔触（斜向线条，模拟书法笔意）
	_draw_ink_stroke(0.40, 0.30, 0.75, 0.38, 3.0, Color(0.28, 0.24, 0.20, 0.12))
	_draw_ink_stroke(0.48, 0.42, 0.82, 0.48, 2.0, Color(0.32, 0.28, 0.24, 0.09))
	_draw_ink_stroke(0.42, 0.58, 0.78, 0.65, 2.5, Color(0.30, 0.26, 0.22, 0.10))
	_draw_ink_stroke(0.52, 0.70, 0.85, 0.76, 1.8, Color(0.26, 0.22, 0.18, 0.08))


func _draw_mountain_layer(left: float, right: float, peak: float, bottom: float, color: Color) -> void:
	# 远山剪影——底部锚点=1.0，顶部按比例收缩
	var mountain := ColorRect.new()
	mountain.color = color
	mountain.set_anchors_preset(Control.PRESET_FULL_RECT)
	mountain.anchor_left = left
	mountain.anchor_right = right
	mountain.anchor_bottom = 1.0
	mountain.anchor_top = 1.0 - peak - bottom
	add_child(mountain)


func _draw_cloud_cluster(center_x: float, center_y: float, radius: float, color: Color) -> void:
	# 云海——多个半透明圆形叠加
	var cloud_count := 5
	var rng := RandomNumberGenerator.new()
	rng.seed = int(center_x * 1000 + center_y * 100)

	for i in range(cloud_count):
		var cloud := ColorRect.new()
		cloud.color = color
		var offset_x: float = rng.randf_range(-radius * 0.5, radius * 0.5)
		var offset_y: float = rng.randf_range(-radius * 0.3, radius * 0.3)
		var size_x: float = rng.randf_range(radius * 0.3, radius * 0.6)
		var size_y: float = rng.randf_range(radius * 0.2, radius * 0.4)

		cloud.set_anchors_preset(Control.PRESET_FULL_RECT)
		cloud.anchor_left = center_x + offset_x - size_x * 0.5
		cloud.anchor_right = center_x + offset_x + size_x * 0.5
		cloud.anchor_top = center_y + offset_y - size_y * 0.5
		cloud.anchor_bottom = center_y + offset_y + size_y * 0.5
		add_child(cloud)


func _draw_ink_stroke(x1: float, y1: float, x2: float, y2: float, thickness: float, color: Color) -> void:
	# 水墨笔触——用细长的 ColorRect 模拟
	var stroke := ColorRect.new()
	stroke.color = color
	stroke.set_anchors_preset(Control.PRESET_FULL_RECT)

	# 计算起点和终点（锚点坐标）
	stroke.anchor_left = minf(x1, x2)
	stroke.anchor_right = maxf(x1, x2)
	stroke.anchor_top = minf(y1, y2)
	stroke.anchor_bottom = maxf(y1, y2)

	# 使用 offset 控制厚度（相对于锚点区域）
	var viewport_size := get_viewport_rect().size
	var avg_width: float = (x2 - x1) * viewport_size.x
	var avg_height: float = (y2 - y1) * viewport_size.y

	# 根据斜率调整厚度
	if absf(avg_width) > absf(avg_height):
		# 水平方向为主
		stroke.offset_top = -thickness * 0.5
		stroke.offset_bottom = thickness * 0.5
	else:
		# 垂直方向为主
		stroke.offset_left = -thickness * 0.5
		stroke.offset_right = thickness * 0.5

	add_child(stroke)


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(
		"res://prototypes/cultivation-card-battle-vertical-slice/scenes/battle.tscn"
	)


func _on_quit_pressed() -> void:
	get_tree().quit()
