class_name DeployPanel
extends Control
## DeployPanel —— 备战面板视觉框架（combat-ui-layout Story 007）。
##
## [b]职责[/b]：战斗名称标题 + 角色缩略卡网格 + 阵位布局预览 + 「还可以选择X人」
## 提示 + 确认出战/返回按钮 + 名额满时的替换确认弹窗框架 + 悬停协同信息。
## 判定逻辑全部委托 [DeployPanelRules]（Logic 内核，BLOCKING 单测）；
## 数据读取委托 [DeployRosterReader]。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：角色数据由注入的系统读取，本面板只持
## 渲染快照；[b]选择状态是瞬态交互状态[/b]（§2.1 豁免）——确认出战前不写回系统，
## 确认时只发 [signal confirm_requested]，由上层调用 DeploymentSystem。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——交互全部由按钮/悬停信号驱动。[br]
## [br][b]交互边界[/b]（story 划界裁决 2026-09-07）：点选/拖拽阵位调整/替换决策流/
## 数字键选择归 interaction epic；本 story 只提供视觉框架、判定与信号出口。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §8 备战阶段UI、
## combat-ui-layout Story 007（AC-1~AC-7）。

const Rules := preload("res://src/ui/combat/shared/deploy_panel_rules.gd")
const RosterReader := preload("res://src/ui/combat/deploy/deploy_roster_reader.gd")
const CardScript := preload("res://src/ui/combat/deploy/deploy_character_card.gd")
const PreviewScript := preload("res://src/ui/combat/deploy/deploy_formation_preview.gd")
const View := preload("res://src/ui/combat/deploy/deploy_panel_view.gd")

## === 信号（对外出口——系统调用归上层/interaction）=========================

## 确认出战——载荷为已选角色 ID 列表（上层调用 DeploymentSystem.setup_field）。
signal confirm_requested(character_ids: Array)
## 返回探索——载荷为空（上层经 SceneManager 转场）。
signal back_requested()
## 名额满时请求替换——[code](new_character_id, replaced_character_id)[/code]。
signal replace_requested(new_character_id: int, replaced_character_id: int)

## === 注入依赖（全部可空——缺失时退化为空名册）=============================

var gsm: Node = null
var card_system: Node = null
var deployment_system: Node = null
var binding_manager: Node = null

## === 渲染快照 =============================================================

## 角色名册快照（[DeployRosterReader.read] 输出）。
var roster: Array = []
## 当前已选角色 ID（瞬态——不写系统）。
var selected_ids: Array = []
## 当前境界 ID 与上场上限。
var realm_id: int = 1
var max_deploy: int = 0
## 当前阵位布局（[Rules.formation_slot_layout] 结果）。
var formation_layout: Dictionary = {}

## === 子节点（控件树由 [DeployPanelView] 构建——布局常量亦在该处）==========

var title_label: Label = null
var hint_label: Label = null
var tooltip_label: Label = null
var preview: Control = null
var confirm_button: Button = null
var back_button: Button = null
var replace_dialog: ConfirmationDialog = null
## 角色卡列表（与 [member roster] 同序）。
var _cards: Array = []
## 网格容器。
var _grid: GridContainer = null
## 待确认替换的目标角色 ID。
var _pending_replace_id: int = -1
## 待确认替换的[b]被替换[/b]角色 ID（-1 = 默认取首位已选）。
var _pending_replaced_id: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()


## 注入数据依赖（全部可选——缺失时名册为空，面板仍可渲染骨架）。[br]
## [b]信号接线[/b]（审查 M10）：注入部署系统后订阅
## [signal DeploymentSystem.character_unavailable] / [signal DeploymentSystem.character_revived]
## 刷新名册——阵亡/复活是备战前可发生状态变化，仅靠外部手动刷新会让显示漂移。
func setup(p_gsm: Node, p_card_system: Node, p_deployment_system: Node,
		p_binding_manager: Node = null) -> void:
	gsm = p_gsm
	card_system = p_card_system
	deployment_system = p_deployment_system
	binding_manager = p_binding_manager
	if deployment_system != null:
		if deployment_system.has_signal("character_unavailable") \
				and not deployment_system.character_unavailable.is_connected(_on_roster_dirty):
			deployment_system.character_unavailable.connect(_on_roster_dirty)
		if deployment_system.has_signal("character_revived") \
				and not deployment_system.character_revived.is_connected(_on_roster_dirty):
			deployment_system.character_revived.connect(_on_roster_dirty)


## 名册脏通知——阵亡/复活后按当前上限重读名册（信号驱动，零轮询）。
func _on_roster_dirty(_unused: int) -> void:
	if visible:
		refresh_roster()


## 依赖是否已注入（生产路径守卫——未注入时面板只能出空骨架）。
func has_sources() -> bool:
	return gsm != null and card_system != null


## 从注入依赖读取名册并下发（[member max_deploy] / [member realm_id] 由调用侧先设定）。[br]
## 返回读取到的角色数（0 表示依赖缺失或角色位为空）。
func refresh_roster() -> int:
	var read_roster: Array = RosterReader.read(gsm, card_system,
			deployment_system, binding_manager)
	apply_roster(read_roster, max_deploy, realm_id)
	return read_roster.size()


## 读取名册并按给定境界参数下发——[b]单次调用完成取数与下发[/b]，
## 避免「先 refresh 后设上限」导致首次刷新用上限 0 判定成全部可替换。[br]
## [param p_max_deploy]: 当前境界上场人数上限。[br]
## [param p_realm_id]: 当前境界 ID（决定阵位布局）。
func load_roster(p_max_deploy: int, p_realm_id: int) -> int:
	var read_roster: Array = RosterReader.read(gsm, card_system,
			deployment_system, binding_manager)
	apply_roster(read_roster, p_max_deploy, p_realm_id)
	return read_roster.size()


## 下报名册快照并重建角色卡（[b]全量重建[/b]——名册变化频率极低，
## 避免增量同步的漂移面）。[br]
## [b]参数顺序[/b]：先设 [member max_deploy]/[member realm_id] 再刷新，
## 本方法内两字段的赋值仅作调用侧缺省补齐。
## [param p_roster]: [DeployRosterReader.read] 输出。[br]
## [param p_max_deploy]: 当前境界上场人数上限。[br]
## [param p_realm_id]: 当前境界 ID（决定阵位布局）。
func apply_roster(p_roster: Array, p_max_deploy: int, p_realm_id: int) -> void:
	roster = p_roster.duplicate(true)
	max_deploy = p_max_deploy
	realm_id = p_realm_id
	formation_layout = Rules.formation_slot_layout(p_realm_id)
	# 剔除已不在名册或已阵亡的选择（名册变化后的自洽性维护）
	var valid_ids: Array = _eligible_ids()
	for cid: int in selected_ids.duplicate():
		if not valid_ids.has(cid):
			selected_ids.erase(cid)
	# 上限收缩（审查 H3）：境界回落（如化神 6 → 炼气 2）时保留先选者，
	# 否则会出现「已选满 5/2」+ 预览静默丢名 + setup_field 拒收的三重漂移
	if max_deploy > 0 and selected_ids.size() > max_deploy:
		selected_ids = selected_ids.slice(0, max_deploy)
	_rebuild_cards()
	_refresh_all()


## 可用角色 ID 列表（未阵亡且在名册内）。
func _eligible_ids() -> Array:
	var ids: Array = []
	for entry: Dictionary in roster:
		if not bool(entry.get("is_dead", false)):
			ids.append(int(entry.get("character_id", -1)))
	return ids


## 设置战斗名称标题（GDD §8「⚔ 青云剑宗·山门 — 普通战斗」）。
func set_battle_title(p_title: String) -> void:
	title_label.text = p_title


## 切换选中态（瞬态——不写系统）。阵亡角色与超上限时拒绝并走替换流程。[br]
## [b]返回[/b]: true = 选择状态有变化。
func toggle_selection(character_id: int) -> bool:
	var entry: Dictionary = _find_entry(character_id)
	if entry.is_empty():
		return false
	if selected_ids.has(character_id):
		selected_ids.erase(character_id)
		_refresh_all()
		return true
	if bool(entry.get("is_dead", false)):
		return false
	var state: String = Rules.deploy_selection_state(false, false,
			selected_ids.size(), max_deploy)
	if state == Rules.STATE_REPLACEABLE:
		_open_replace_dialog(character_id)
		return false
	selected_ids.append(character_id)
	_refresh_all()
	return true


## 已选角色 ID（副本）。
func get_selected_ids() -> Array:
	return selected_ids.duplicate()


## 某角色的当前 4 态（供测试与 interaction epic 消费）。[br]
## [br][b]未知 ID 返回空串[/b]（审查 M11）：与「已阵亡」区分开——
## 调用方传错 ID 时不再被伪装成不可用状态。
func get_selection_state(character_id: int) -> String:
	for card: Control in _cards:
		if card.get_character_id() == character_id:
			return card.get_state()
	return ""


## 角色卡列表（测试断言用）。
func get_cards() -> Array:
	return _cards.duplicate()


## === 内部：构建 ============================================================

## 构建控件树（结构委托 [DeployPanelView]，本方法只做信号接线——布局常量
## 与文案集中在 View，避免两处漂移）。
func _build() -> void:
	var built: Dictionary = View.build(self)
	title_label = built["title_label"]
	_grid = built["grid"]
	hint_label = built["hint_label"]
	tooltip_label = built["tooltip_label"]
	confirm_button = built["confirm_button"]
	back_button = built["back_button"]
	replace_dialog = built["replace_dialog"]
	preview = PreviewScript.new()
	preview.name = "FormationPreview"
	add_child(preview)
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	replace_dialog.confirmed.connect(_on_replace_confirmed)
	replace_dialog.canceled.connect(_on_replace_canceled)


## 重建角色卡（名册全量变化时）——先释放旧卡再按新名册创建。[br]
## [b]同步 free[/b]：名册刷新发生在信号处理帧内，queue_free 会遗留一帧孤儿节点
## （GUT 孤儿检测在测试结束时立即执行），故移出树后直接 free。
func _rebuild_cards() -> void:
	for card: Control in _cards:
		if not is_instance_valid(card):
			continue
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
		card.free()
	_cards.clear()
	for entry: Dictionary in roster:
		var card: Control = CardScript.new()
		card.name = "Card_%d" % int(entry.get("character_id", 0))
		card.apply_data(int(entry.get("character_id", -1)), entry)
		card.mouse_entered.connect(_on_card_hover.bind(card, true))
		card.mouse_exited.connect(_on_card_hover.bind(card, false))
		# [b]点选接线[/b]：卡自己不决策，只上报「有人点了这张」——
		# 能不能选 / 超没超上限 / 走不走替换流程全归 [method toggle_selection]。
		# 不接的话，mouse_filter = STOP 会让左键被卡吞掉：玩家点卡什么都不发生。
		card.connect(&"card_pressed",
				_on_card_pressed.bind(int(entry.get("character_id", -1))))
		_grid.add_child(card)
		_cards.append(card)


## 卡片被点/被键盘确认——转发到公开的选中入口。[br]
## [br][b]为什么不直接调 [method toggle_selection][/b]：签名带 [code]character_id[/code]，
## 而按钮信号不带参数——绑定一次比在每个卡实例上装 lambda 干净（同
## [code]map_select_cards[/code] 的 [code]card_activated[/code] 口径）。
func _on_card_pressed(p_character_id: int) -> void:
	toggle_selection(p_character_id)


## === 内部：刷新 ============================================================

## 全量刷新（4 态 + 预览 + 提示 + 按钮 + 布局位置）。
func _refresh_all() -> void:
	for card: Control in _cards:
		var entry: Dictionary = _find_entry(card.get_character_id())
		card.set_selection_state(Rules.deploy_selection_state(
				bool(entry.get("is_dead", false)),
				selected_ids.has(card.get_character_id()),
				selected_ids.size(), max_deploy))
	confirm_button.disabled = not Rules.confirm_button_enabled(selected_ids.size())
	hint_label.text = Rules.remaining_hint(selected_ids.size(), max_deploy)
	var names: Array = []
	for cid: int in selected_ids:
		var entry: Dictionary = _find_entry(cid)
		names.append(str(entry.get("display_name", "")))
	preview.apply_preview(formation_layout, names)
	_relayout()


## 按内容高度重排子节点（面板无固定高度——由内容撑开）。[br]
## 布局常量统一取自 [DeployPanelView]（与控件初始定位同源，避免两处漂移）。
func _relayout() -> void:
	var grid_h: float = _grid.get_combined_minimum_size().y
	var preview_y: float = View.GRID_TOP + grid_h + View.PREVIEW_TOP_OFFSET
	preview.position = Vector2(0, preview_y)
	var hint_y: float = preview_y + preview.custom_minimum_size.y + View.HINT_TOP_OFFSET
	hint_label.position = Vector2(0, hint_y)
	tooltip_label.position = Vector2(320, hint_y)
	var button_y: float = hint_y + 28.0
	confirm_button.position = Vector2(0, button_y)
	back_button.position = Vector2(View.BUTTON_WIDTH + 16.0, button_y)
	custom_minimum_size = Vector2(700, button_y + View.BUTTON_HEIGHT)


## 按角色 ID 取快照条目（找不到返回空字典）。
func _find_entry(character_id: int) -> Dictionary:
	for entry: Dictionary in roster:
		if int(entry.get("character_id", -1)) == character_id:
			return entry
	return {}


## === 内部：交互 ============================================================

func _on_confirm_pressed() -> void:
	if not Rules.confirm_button_enabled(selected_ids.size()):
		return
	confirm_requested.emit(selected_ids.duplicate())


## 名额满时的替换确认弹窗（弹窗框架归本 story，决策流归 interaction）。[br]
## [b]被替换者由调用方指定[/b]（审查 H5）：默认取第一位已选角色，但支持显式传入——
## 「替换哪一名」是玩家选择，不能由 UI 任意决定（GDD §8 语义）。
func _open_replace_dialog(new_character_id: int, replaced_character_id: int = -1) -> void:
	if selected_ids.is_empty():
		return
	var target_id: int = replaced_character_id if selected_ids.has(replaced_character_id) \
			else int(selected_ids[0])
	_pending_replace_id = new_character_id
	_pending_replaced_id = target_id
	var new_name: String = str(_find_entry(new_character_id).get("display_name", ""))
	var old_name: String = str(_find_entry(target_id).get("display_name", ""))
	replace_dialog.dialog_text = Rules.replace_prompt(new_name, old_name)
	replace_dialog.popup_centered()


## 替换确认——本地完成替换（瞬态）+ 发出 [signal replace_requested]。
func _on_replace_confirmed() -> void:
	if _pending_replace_id < 0 or selected_ids.is_empty():
		return
	var new_id: int = _pending_replace_id
	var replaced_id: int = _pending_replaced_id
	var index: int = selected_ids.find(replaced_id)
	if index < 0:
		index = 0
		replaced_id = int(selected_ids[0])
	selected_ids[index] = new_id
	_pending_replace_id = -1
	_pending_replaced_id = -1
	_refresh_all()
	replace_requested.emit(new_id, replaced_id)


func _on_replace_canceled() -> void:
	_pending_replace_id = -1
	_pending_replaced_id = -1


## 公开的替换请求入口（interaction epic 接线用——绕过鼠标点选区）。
func request_replace(new_character_id: int, replaced_character_id: int = -1) -> void:
	_open_replace_dialog(new_character_id, replaced_character_id)


## 待确认替换的新角色 ID（-1 = 无待确认）。
func get_pending_replace_id() -> int:
	return _pending_replace_id


## 悬停协同信息——只在与已选阵容存在共享阵营标签时显示。
func _on_card_hover(card: Control, entered: bool) -> void:
	if not entered:
		tooltip_label.visible = false
		return
	var hovered_tags: Array = card.get_faction_tags()
	var selected_tags: Array = []
	for cid: int in selected_ids:
		if cid == card.get_character_id():
			continue
		selected_tags.append_array(_find_entry(cid).get("faction_tags", []))
	var shared: Array = Rules.shared_faction_tags(hovered_tags, selected_tags)
	tooltip_label.text = Rules.synergy_text(card.get_display_name(), shared)
	tooltip_label.visible = true
