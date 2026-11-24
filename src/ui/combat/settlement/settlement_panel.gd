class_name SettlementPanel
extends "res://src/ui/combat/settlement/settlement_panel_flows.gd"
## SettlementPanel —— 胜利/战败结算面板（combat-ui-layout Story 008）。
##
## [b]职责[/b]：两类面板的视觉框架与状态渲染。判定全部委托 [SettlementRules]（Logic
## 内核，BLOCKING 单测）；外框 [SettlementFrame] 建、控件树 [SettlementPanelView] 搭、
## 开合 [SettlementFade] 驱动——本面板只编排与转发点击。[br]
## [br][b]两段分工[/b]（DEBT-CUI-008-3）：胜利面板先给「要挑的那一份」（选择段标题按
## 实际候选数写 + 网格），确认后才换成「已入账」清单——顺序即语义。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：数据由宿主按信号载荷下发；选中态与延迟窗口
## 是瞬态交互状态（§2.1 豁免），确认前不写任何系统。[br]
## [br][b]零轮询[/b]（§3）：0.5s 延迟由一次性 [Timer] 驱动，开合为 Tween。[br]
## [br][b]不自动关闭[/b]（AC-10）：只在玩家点确认/跳过/返回时关闭；持久写入归
## interaction epic（Out of Scope）——此处只发信号。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §9、
## Story 008（AC-1~AC-5/AC-10）、DEBT-CUI-008-3。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  settlement_panel_contract.gd [/code] ← 声明面：4 preload / 5 信号 / 3 尺寸常量 / 20 实例字段[br]
## [code]  settlement_panel_flows.gd    [/code] ← 面板流程面：两块面板的开启 + 战利品交互[br]
## [code]  settlement_panel.gd          [/code] ← 本层：装配与出口面（构造 / 关闭 / 查询 / 销毁）[br]
##
## [b]链序不是自由选择[/b]：本层的 [method _build] 按名接线三个回调
## （[code]confirm_button.pressed.connect(_on_confirm_pressed)[/code] /
## [code]skip_button.pressed.connect(_on_skip_pressed)[/code] /
## [code]loot_delay_timer.timeout.connect(_on_loot_delay_timeout)[/code]），前两个在本层、
## 第三个在上一段。GDScript 解析期要求被接方在本段或祖先段——祖先段用裸标识符引用后代段
## 成员会直接解析失败（探针验证），故链序由「谁接线谁靠后」定死。[br]
## [b]路径即契约[/b]：外部（[code]settlement_host_panels.gd[/code] 与三个集成测试）按
## [code]res://src/ui/combat/settlement/settlement_panel.gd[/code] 这一串字符取类，
## 故 [code]class_name[/code] 与本文件名都留在本层、逐字不动。[br]
## 守卫用例：[code]tests/unit/combat_ui/test_settlement_panel_public_face_lock.gd[/code]。


func _init() -> void:
	name = "SettlementPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false


## 构建控件树（一次——重开只改内容不改结构）。[br]
## 结构由 [SettlementPanelView] 搭建（单文件 ≤300 行拆分）；本方法只接线与缓存引用。
func _build() -> void:
	var parts: Dictionary = View.build(self,
			Vector2(PANEL_WIDTH, VICTORY_PANEL_HEIGHT))
	_parts = parts
	frame = parts["frame"] as Control
	body_box = parts["body_box"] as VBoxContainer
	title_label = parts["title_label"] as Label
	hint_label = parts["hint_label"] as Label
	loot_grid = parts["loot_grid"] as VBoxContainer
	defeat_lines_label = parts["defeat_lines"] as Label
	reward_lines_label = parts["reward_lines"] as Label
	pick_title_label = parts["pick_title"] as Label
	confirm_button = parts["confirm_button"] as Button
	skip_button = parts["skip_button"] as Button
	loot_delay_timer = parts["loot_delay_timer"] as Timer
	confirm_button.pressed.connect(_on_confirm_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	loot_delay_timer.timeout.connect(_on_loot_delay_timeout)


# ═══════════════════════════════════════════════════════════════════════════════
# 关闭与查询
# ═══════════════════════════════════════════════════════════════════════════════

## 关闭面板（确认/跳过/返回——[b]唯一[/b]关闭入口，无自动关闭路径）。[br]
## [b]幂等[/b]：已关闭时再调用不重复发信号。
func close_panel() -> void:
	if kind == Rules.KIND_NONE:
		return
	loot_delay_timer.stop()
	kind = Rules.KIND_NONE
	_fade.play_close(self, reduce_motion)
	closed.emit()


## 当前面板是否打开。
func is_open() -> bool:
	return kind != Rules.KIND_NONE


## 当前面板种类（[SettlementRules.KIND_*]）。
func get_kind() -> StringName:
	return kind


## 战利品卡片列表（尺寸/状态断言用——与 [member loot_options] 同序）。
func get_cards() -> Array:
	return _cards


## 当前选中下标（-1 = 未选中）。
func get_selected_index() -> int:
	return selected_index


## 战利品当前是否可点（0.5s 延迟窗口已过）。
func is_loot_clickable() -> bool:
	return loot_ready


## 战利品卡片等宽值（口径统一在 [method SettlementPanelView.loot_cell_width]）。
func get_loot_cell_width() -> float:
	return View.loot_cell_width(PANEL_WIDTH)


## 是否处于「已到账汇总」视图（战利品网格隐藏，只显示奖励汇总行）。
func is_showing_grant_summary() -> bool:
	return kind == Rules.KIND_VICTORY and not loot_grid.visible


## 外框尺寸（「不覆盖全屏」断言用）。
func get_frame_size() -> Vector2:
	if frame == null:
		return Vector2.ZERO
	return frame.custom_minimum_size


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

func _on_confirm_pressed() -> void:
	if kind == Rules.KIND_VICTORY:
		if not Rules.confirm_button_enabled(selected_index, loot_ready):
			return
		var confirmed: int = selected_index
		close_panel()
		loot_confirmed.emit(confirmed)
	elif kind == Rules.KIND_DEFEAT:
		close_panel()
		defeat_confirmed.emit()


func _on_skip_pressed() -> void:
	if kind != Rules.KIND_VICTORY:
		return
	close_panel()
	loot_skipped.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		# 入树后才有真实视口高度——响应式字号在此下发（Frame.apply_font 唯一入口）
		View.apply_fonts(_parts, Frame.viewport_height(self))
	elif what == NOTIFICATION_PREDELETE:
		_fade.kill()
