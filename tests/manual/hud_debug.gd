extends Node
## hud_debug —— HUD 视觉手动验证 debug 宿主（TD-006/TD-013）。
##
## F6 运行本场景（tests/manual/hud_debug.tscn）：挂载 HUD.tscn +
## 经 GSM/DeckEditingSystem Autoload 原子写入 API 直接驱动 hud 002
## （境界+修为条）与 hud 003（灵石+卡组计数）的视觉状态，供人工截图与
## 走查——生产代码零改动。
##
## 验证剧本（对应 TD-006/TD-013 证据清单）：
##   [1]~[4] 修为四档（45% 蓝 / 80% 紫 / 95% 金脉动 / 100% 满值）（hud 002 AC-5）
##   [5]     ��难状态破碎光效（hud 002 AC-6 相关视觉）
##   [6]     灵石 +100 滚动 + (+100) 向下浮动（hud 003 AC-4）
##   [7]     灵石 -50 浮动（(-50) 红）（hud 003 AC-4）
##   [8]     卡组超限三态（红+闪烁+「超限！」）（hud 003 AC-5）
##   [9]     卡组达上限变黄（超限前置档）
##   [0]     重置
##
## 用法：F6 运行后按数字键逐步切换状态（每步截图——见证据文档）。
##
## 来源: docs/tech-debt-register.md TD-006/TD-013、
## hud Story 002 G4 裁决（L59 手动验证前提）、hud Story 003 AC-4/AC-5。

const HUD_SCENE: PackedScene = preload("res://src/ui/hud/HUD.tscn")

var hud: CanvasLayer = null

func _ready() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	# hud 006 手动验证前置：HUD 可见性矩阵默认全隐藏（Story 001——主菜单场景
	# Node3D 无场景 ID），debug 宿主直开 ContentLayer 供探索信息组走查。
	hud.content_layer.visible = true
	_print_instructions()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1: _set_cultivation_ratio(0.45)
		KEY_2: _set_cultivation_ratio(0.80)
		KEY_3: _set_cultivation_ratio(0.95)
		KEY_4: _set_cultivation_ratio(1.00)
		KEY_5: _set_fallen(true)
		KEY_6: _add_lingshi(100)
		KEY_7: _add_lingshi(-50)
		KEY_8: _set_deck_count(_current_deck_limit() + 1)
		KEY_9: _set_deck_count(_current_deck_limit())
		KEY_0: _reset_all()
		KEY_Q: _enter_exploration()
		KEY_W: _consume_ap()
		KEY_E: _restore_ap()

func _print_instructions() -> void:
	print("=== hud_debug 宿主（TD-006/TD-013 + hud 006 探索信息组）===")
	print("1-4: 修为 45%/80%/95%/100%（蓝/紫/金脉动/满值）")
	print("5: 落难破碎光效  6/7: 灵石 +100/-50 浮动")
	print("9: 卡组达上限黄  8: 卡组超限红+闪烁  0: 重置")
	print("Q: 进入探索地图（青云剑宗 层3/5 AP 5/5→消耗看分段格）——hud 006 验证")
	print("（卡组 limit 经 DeckEditingSystem.get_deck_limit() 动态取——炼气期默认 20）")

func _get_gsm() -> Node:
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm == null:
		push_error("hud_debug: GameStateManager Autoload 不存在")
	return gsm

## 修为条档位驱动——经 GSM add_cultivation 原子写入（帧末 batch_updated 传播）。[br]
## 先清零再加到目标值——模拟从 0 开始积累的连续状态变化。
func _set_cultivation_ratio(ratio: float) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return
	var max_val: int = int(gsm.player.get("max_cultivation", 100))
	var target: int = int(round(max_val * ratio))
	var current: int = int(gsm.player.get("cultivation", 0))
	if current > target:
		# 无减少 API（修为只增不减）——经 player 域直接重置后走原子写入
		gsm.player.cultivation = 0
		current = 0
	if target > current:
		gsm.add_cultivation(target - current, &"hud_debug")
	print("[1-4] cultivation = %d/%d（%.0f%%）" % [target, max_val, ratio * 100])

## 落难状态——炼气期 is_fallen（hud 002 破碎光效临时路径）。
func _set_fallen(fallen: bool) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return
	gsm.player.is_fallen = fallen
	gsm._buffer_change("player.is_fallen", not fallen, fallen)
	print("[5] is_fallen = %s" % fallen)

## 灵石增减——经 GSM 原子写入（batch_updated 传播 → delta 浮动+滚动动画）。
func _add_lingshi(delta: int) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return
	var current: int = int(gsm.player.resources.get("ling_shi", 0))
	gsm._set_resource_ling_shi(current + delta)
	print("[6/7] ling_shi = %d（delta %+d）" % [current + delta, delta])

## 卡组计数——经 GSM Autoload 的 [code]_set_deck_cards[/code] 原子写入。[br]
## [br][b]不走 DeckEditingSystem.add_cards_to_deck[/b]：其 [code]can_add_to_deck[/code]
## 守卫会拒绝超限写入（8/9 档位无法达到）——debug 宿主绕过守卫直写数据域，
## 专测 UI 三态渲染（normal/黄/红+闪烁）。limit 经 get_deck_limit() 动态取
## （默认炼气期 20——按实际 limit 打印）。
func _set_deck_count(count: int) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return
	var ds: Node = get_node_or_null("/root/DeckEditingSystem")
	var limit: int = 20
	if ds != null and ds.has_method(&"get_deck_limit"):
		limit = ds.get_deck_limit()
	# 卡组计数由 deck.current_deck 数组长度驱动——构造 N 个占位 id
	var ids: Array = []
	for i: int in range(count):
		ids.append(1000 + i)
	gsm._set_deck_cards(ids)
	print("[8/9] deck count = %d/%d（%s）" % [count, limit,
			"超限红+闪烁" if count > limit else ("达上限黄" if count == limit else "normal")])

## 全量重置——修为 0 / 灵石 500 / 卡组 limit-5。
func _reset_all() -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return
	gsm.player.cultivation = 0
	gsm._buffer_change("player.cultivation", 1, 0)
	gsm.player.is_fallen = false
	gsm._set_resource_ling_shi(500)
	var limit: int = _current_deck_limit()
	var base: int = limit - 5 if limit > 5 else 15
	_set_deck_count(base)
	print("[0] 已重置：修为 0 / 灵石 500 / 卡组 %d/%d" % [base, limit])

## 当前卡组上限（重置基准用）。
func _current_deck_limit() -> int:
	var ds: Node = get_node_or_null("/root/DeckEditingSystem")
	if ds != null and ds.has_method(&"get_deck_limit"):
		return ds.get_deck_limit()
	return 20

## 进入探索地图——hud 006 探索信息组手动验证驱动（AC-3/AC-4）。[br]
## 经 ExplorationSystem.enter_map 真实路径写入 GSM exploration 域
## （set_exploration_map + set_exploration_ap 单帧双写 → batch_updated →
## HUD 信息组双路径刷新），随后消耗 AP 验证分段格与颜色阈值。[br]
## [b]场景链说明[/b]：完整游戏需经身份选择 UI（identity-selection-system epic
## Backlog，identity_select.tscn 未落地）→ 主菜单「新游戏」点击后
## SceneManager 转场失败静默回退——此为已知留桩（main-menu story-001
## Completion Notes 声明），非 hud 006 缺陷。debug 宿主直接驱动数据域，
## 绕过未落地的场景链。
func _enter_exploration() -> void:
	var es: Node = get_node_or_null("/root/ExplorationSystem")
	if es == null or not es.has_method(&"enter_map"):
		push_error("hud_debug: ExplorationSystem Autoload 不存在")
		return
	es.enter_map(&"qing_yun_jian_zong", 1, 5)
	var gsm: Node = _get_gsm()
	if gsm != null:
		# 走到层 3（0 基 layer=2——非首层的中间层，验证 layer+1 换算显示「层3/5」）
		gsm.set_exploration_position(2, 0)
	print("[Q] 已进入青云剑宗（AP 5/5，位置 层3）——观察右下信息组")
	print("    再按 W 消耗 1 AP 看分段格熄灭；按 E 恢复 2 AP 看点亮/颜色阈值")

## 消耗 1 AP——GSM 原子写入（单写 → 帧末域信号路径 action_points_changed）。[br]
## hud 006 AC-4：分段格熄灭 + 颜色阈值（5/5→4/5 normal；连按到 1/5 critical）。
func _consume_ap() -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return
	var current: int = int(gsm.exploration.get("action_points", 0))
	if current <= 0:
		print("[W] AP 已为 0——按 E 恢复")
		return
	gsm.set_exploration_ap(current - 1, int(gsm.exploration.get("max_action_points", 5)))
	print("[W] AP = %d/%d" % [current - 1,
			int(gsm.exploration.get("max_action_points", 5))])

## 恢复 2 AP——GSM restore_action_points（单写 → 域信号路径——AC-2 路径对偶）。
func _restore_ap() -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return
	gsm.restore_action_points(2)
	print("[E] AP = %d/%d（恢复 +2）" % [int(gsm.exploration.get("action_points", 0)),
			int(gsm.exploration.get("max_action_points", 5))])
