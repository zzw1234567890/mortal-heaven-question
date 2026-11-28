extends Node
## ui_shot_combat —— 手牌区视觉取证（180×252 + 底栏之上 + 卡面插画）。[br]
## [br][b]为什么是场景而非 [code]-s[/code] 脚本[/b]：同 [code]ui_shot_ui_art.gd[/code]
## 头部注记——[code]-s[/code] 下 Autoload 只是运行时节点、编译期没有全局标识符。[br]
## [br][b]为什么不用 headless[/b]：headless 下 [code]root.get_texture()[/code] 拿不到
## 真实渲染结果，本轮要看的就是玩家实际看到的卡面。[br]
## [br][b]运行[/b]（非 headless）：[br]
## [code]Godot_v4.6.3-stable_win64.exe res://tools/ui_shot_combat.tscn[/code][br]
## [br]输出：`tools/ui_shot_hand_1920.png`（1920×1080）与
## `tools/ui_shot_hand_720.png`（1280×720），并打印每张卡的矩形、卡面贴图来源与
## 「卡底到本档底栏顶」的最小间距（口径：间距 ≥ 0 且 ≤ 60 才算落位正确）。
## 来源: 本轮任务（手牌位置 + 卡牌图片）。

const OUT_DIR: String = "res://tools/"

const HandAreaScript := preload("res://src/ui/combat/layout/hand_area.gd")
const ArtResolver := preload("res://src/ui/combat/card_art_resolver.gd")
const CharacterCardScript := preload("res://src/ui/combat/layout/character_status_card.gd")
const PortraitScript := preload("res://src/ui/identity_select/identity_portrait_resolver.gd")

## 底栏占视口高度的比例（与 HandArcRules / CombatLayoutZones 同源口径）。
const BOTTOMBAR_HEIGHT_RATIO: float = 180.0 / 1080.0

## 取证用的一手牌——卡种 ID 都是真实模板（插画按 card_<id>.png 解析）。
const SAMPLE_KINDS: Array[StringName] = [
	&"basic_attack", &"sha_qi_zhan", &"bing_leng_ci", &"pill_hui_chun_dan",
	&"wan_hun_fan", &"shuang_po_jian_jue", &"artifact_shang_pin_fa_qi",
]

## 假数据里的卡名——真实链路是 snapshot 从模板取中文名，这里照抄模版，
## 免得截图里全是卡种 ID（老板 2026-11-28 会说「怎么还是英文」）。
const SAMPLE_NAMES: Array[String] = [
	"基础攻击", "煞气斩", "冰棱刺", "回春丹",
	"万魂幡", "霜魄剑诀", "上品法器",
]

var _holder: Control = null
var _area: Node = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await get_tree().process_frame
	await _run()


func _run() -> void:
	await _shoot(1920, 1080, "ui_shot_hand_1920")
	await _shoot_hover(1920, 1080)
	await _shoot(1280, 720, "ui_shot_hand_720")
	await _shoot_actors()
	print("[shot-combat] 完成，两张图在 " + ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()


## 在指定分辨率下手牌区落位 → 打印读数 → 截图。
func _shoot(p_w: int, p_h: int, p_name: String) -> void:
	await _clear()
	_force_window_size(p_w, p_h)
	_holder = Control.new()
	_holder.name = "CombatShotHolder"
	_holder.size = Vector2(p_w, p_h)
	add_child(_holder)
	_area = HandAreaScript.new()
	(_area as Control).name = "HandArea"
	(_area as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(_area)
	await _settle(4)
	_area.call(&"apply_hand", _cards())
	await _settle(6)
	_report(p_w, p_h)
	await _capture(p_name)
	_force_window_size(1920, 1080)


## 角色卡视觉取证（立绘 + 功法/法宝栏）。[br]
## [br]直接建 [code]character_status_card[/code] 组件——战斗里它们由
## [code]ActorStageRoster._spawn()[/code] 用同样的入口（portrait / set_bindings）装出来。
func _shoot_actors() -> void:
	await _clear()
	_force_window_size(1920, 1080)
	_holder = Control.new()
	_holder.name = "ActorCardHolder"
	_holder.size = Vector2(1920, 1080)
	add_child(_holder)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	row.position = Vector2(60.0, 120.0)
	_holder.add_child(row)
	var cases: Array = [
		[&"lin_yuan", "林渊", 32, 45, 2, 1],
		[&"su_jian_ming", "苏剑鸣", 26, 38, 1, 2],
		[&"tu_ye", "屠野", 18, 52, 0, 3],
		[&"yun_su_xin", "云素心", 21, 30, 3, 0],
		[&"yin_ruo_han", "殷若寒", 15, 34, 1, 1],
	]
	for entry: Array in cases:
		var card: Control = CharacterCardScript.new()
		card.size = card.custom_minimum_size
		row.add_child(card)
		card.set(&"portrait", PortraitScript.portrait_for(str(entry[0])))
		card.call(&"apply_name", str(entry[1]))
		card.call(&"apply_hp", int(entry[2]), int(entry[3]))
		card.call(&"apply_atk", 12)
		card.call(&"set_front_row", true)
		card.call(&"set_bindings", int(entry[4]), int(entry[5]))
	await _settle(8)
	for child: Node in row.get_children():
		var c2: Control = child as Control
		var has_portrait: bool = c2.get(&"portrait") != null
		print("[shot-actor] %s rect=%s portrait=%s gongfa=%d fabao=%d"
				% [str(c2.get(&"name")), str(c2.get_global_rect()),
				"OK" if has_portrait else "MISSING",
				int(c2.get(&"gongfa_count")), int(c2.get(&"fabao_count"))])
	await _capture("ui_shot_actor_cards")

## 造一手快照（结构与 CombatHandSnapshot.build 输出一致，多一个 card_kind）。
## 悬停态截图：把中间那张卡抬起并置顶（手牌是每张遮 1/3，只有这样才能看全）。
func _shoot_hover(p_w: int, p_h: int) -> void:
	await _clear()
	_force_window_size(p_w, p_h)
	_holder = Control.new()
	_holder.name = "HoverShotHolder"
	_holder.size = Vector2(p_w, p_h)
	add_child(_holder)
	_area = HandAreaScript.new()
	(_area as Control).name = "HandArea"
	(_area as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(_area)
	await _settle(4)
	var cards: Array = _cards()
	_area.call(&"apply_hand", cards)
	await _settle(6)
	if cards.size() >= 4:
		_area.call(&"set_hovered_card", int((cards[3] as Dictionary).get("card_instance_id", -1)))
	await _settle(12)
	print("[shot-combat] 悬停卡 = 第 4 张（应当抬起并压在邻居之上）")
	await _capture("ui_shot_hand_hover")
	_force_window_size(1920, 1080)


func _cards() -> Array:
	var out: Array = []
	for i: int in range(SAMPLE_KINDS.size()):
		out.append({
			"card_instance_id": 100 + i,
			"name": SAMPLE_NAMES[i % SAMPLE_NAMES.size()],
			"cost": i % 4,
			"rarity": (i % 5) + 1,
			"type": i % 3,
			"target_type": &"",
			"card_kind": SAMPLE_KINDS[i],
			"affordable": i % 3 != 2,
		})
	return out


func _report(p_w: int, p_h: int) -> void:
	var bar_top: float = float(p_h) * (1.0 - BOTTOMBAR_HEIGHT_RATIO)
	var worst: float = INF
	var count: int = int(_area.call(&"get_card_count"))
	for i: int in range(count):
		var card: Control = _area.call(&"get_card", i)
		if card == null:
			continue
		var r: Rect2 = card.get_global_rect()
		worst = minf(worst, bar_top - r.position.y - r.size.y)
		var kind: StringName = StringName(str(card.get(&"card_kind")))
		var art: String = ArtResolver.path_for(kind)
		print("[shot-combat] %dx%d card%d rect=%s kind=%s art=%s"
				% [p_w, p_h, i, str(r), str(kind), "OK" if not art.is_empty() else "MISSING"])
	print("[shot-combat] %dx%d 张数=%d 卡底到本档底栏顶最小间距=%.1fpx（底栏顶 y=%.1f）"
			% [p_w, p_h, count, worst, bar_top])


func _force_window_size(p_w: int, p_h: int) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(p_w, p_h))
	var window: Window = get_window()
	window.content_scale_size = Vector2i(p_w, p_h)
	window.size = Vector2i(p_w, p_h)


func _clear() -> void:
	if _holder != null and is_instance_valid(_holder):
		_holder.queue_free()
		_holder = null
		_area = null
	await get_tree().process_frame


func _settle(p_frames: int) -> void:
	for _i: int in range(maxi(p_frames, 1)):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _capture(p_name: String) -> void:
	var image: Image = get_tree().root.get_texture().get_image()
	var path: String = OUT_DIR + p_name + ".png"
	var err: int = image.save_png(path)
	print("[shot-combat] %s -> %s (%dx%d, err=%d)"
			% [p_name, path, image.get_width(), image.get_height(), err])
