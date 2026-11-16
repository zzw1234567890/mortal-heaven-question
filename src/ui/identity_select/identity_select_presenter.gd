extends RefCounted
## IdentitySelectPresenter —— 身份选择界面的「渲染与文本落地」子模块。
##
## 从 [code]identity_select.gd[/code] 拆出：场景脚本只留节点接线与事件处理，
## 凡是「把数据画成节点 / 把词典拼成文案」的活都在这里。卡片本身的结构构建再拆到
## [code]identity_card_factory.gd[/code]（纯构建，可单测直调）。
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本类不改任何游戏状态，只读传入的
## [code]preview[/code] / [code]entry[/code] 字典并写节点属性；选中态仍由场景脚本持有。
##
## [br]来源: ADR-0031、design/gdd/identity-selection-system.md §用户界面需求、
## story-004-identity-select-ui.md。

## 判定/文本纯函数子模块。
const Rules := preload("res://src/ui/identity_select/identity_select_rules.gd")
## 卡片纯构建子模块。
const Factory := preload("res://src/ui/identity_select/identity_card_factory.gd")

## 未选中卡的常驻不透明度；选中卡 1.0；被拦卡恒 0.45（Factory.ALPHA_BLOCKED）。
const ALPHA_IDLE: float = 0.85
const ALPHA_SELECTED: float = 1.0
## 入场动画总时长——0.6s（GDD §视觉/音频需求「6 卡依次飞入 0.6s」）。
const INTRO_DURATION: float = 0.6
## 每卡飞入的 stagger 间隔（秒）——6 卡 × 0.1s 错峰落在 0.6s 总窗口内。
const INTRO_STAGGER: float = 0.1
## 开局叙事逐行显示间隔（秒）。
const NARRATIVE_LINE_INTERVAL: float = 0.8

## 叙事播完（或跳过）后发射——场景脚本据此请求导航。[br]
## [br]实测要点：故意 [code]teardown()[/code]（[code]_exit_tree[/code] 调用）后
## 本信号一并失效，避免已释放场景收到回调。
signal narrative_finished

## 宿主节点——[code]create_tween[/code] / [code]add_child[/code] 需要树内节点。
var host: Node = null
## 网格容器——6 张身份卡构建于此，子节点索引即身份条目索引。
var grid: GridContainer = null

## 详情面板节点组（场景 .tscn 固定结构，缺失时 [method show_detail] 直接跳过）。
var detail_panel: Panel = null
var detail_name_label: Label = null
var detail_deck_label: Label = null
var detail_character_label: Label = null
var detail_talent_label: Label = null
var detail_hint_label: Label = null

## 提示弹窗 + 确认弹窗节点组。
var toast_dialog: AcceptDialog = null
var confirm_dialog: ConfirmationDialog = null
var confirm_dialog_name: Label = null
var confirm_dialog_avatars: HBoxContainer = null

## 叙事层节点组。
var narrative_overlay: Control = null
var narrative_label: Label = null

## 入场 Tween 句柄（新请求时 kill 防悬挂——先例 main_menu._intro_tween）。
var _intro_tween: Tween = null
## 叙事逐行推进 Timer。
var _narrative_timer: Timer = null
## 叙事文本行缓存 + 当前行索引（展示层本地瞬态——不进存档）。
var _narrative_lines: Array[String] = []
var _narrative_index: int = 0


# === 接线 ======================================================================

## 把场景节点组接到本实例上——节点引用只在宿主 [code]_ready[/code] 后可解析，
## 故由场景脚本在首次取用时调用一次（而非在 [code]_init[/code] 里固化）。
func attach(p_host: Node) -> void:
	host = p_host
	grid = p_host.get_node_or_null(NodePath("LayoutAnchor/GridContainer"))
	detail_panel = p_host.get_node_or_null(NodePath("LayoutAnchor/DetailPanel"))
	detail_name_label = p_host.get_node_or_null(NodePath("LayoutAnchor/DetailPanel/NameLabel"))
	detail_deck_label = p_host.get_node_or_null(NodePath("LayoutAnchor/DetailPanel/DeckLabel"))
	detail_character_label = p_host.get_node_or_null(
			NodePath("LayoutAnchor/DetailPanel/CharacterLabel"))
	detail_talent_label = p_host.get_node_or_null(NodePath("LayoutAnchor/DetailPanel/TalentLabel"))
	detail_hint_label = p_host.get_node_or_null(NodePath("LayoutAnchor/DetailPanel/HintLabel"))
	toast_dialog = p_host.get_node_or_null(NodePath("LockedDialog"))
	confirm_dialog = p_host.get_node_or_null(NodePath("ConfirmDialog"))
	confirm_dialog_name = p_host.get_node_or_null(NodePath("ConfirmDialog/NameLabel"))
	confirm_dialog_avatars = p_host.get_node_or_null(NodePath("ConfirmDialog/Avatars"))
	narrative_overlay = p_host.get_node_or_null(NodePath("NarrativeOverlay"))
	narrative_label = p_host.get_node_or_null(NodePath("NarrativeOverlay/TextLabel"))


# === 网格渲染 ===================================================================

## 渲染 6 张身份卡——[param p_entries] 不足 6 条时以空字典补位（安全渲染
## 「暂未开放」占位卡，场景不崩溃，也不会凭空出现可开局的假象）。[br]
## [br][param p_on_card_input] 卡片 [code]gui_input[/code] 处理（场景脚本提供，
## 签名 [code](event, index, entry)[/code]）。
func refresh_cards(p_entries: Array, p_on_card_input: Callable) -> void:
	if grid == null:
		return
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for i: int in range(6):
		var entry: Dictionary = p_entries[i] if i < p_entries.size() else {}
		var card: Control = Factory.build_card(entry, i)
		if p_on_card_input.is_valid():
			card.gui_input.connect(p_on_card_input.bind(i, entry))
		grid.add_child(card)


## 高亮选中卡片（其余恢复默认）——纯视觉。[br]
## [br]被拦的卡恒为 [constant Factory.ALPHA_BLOCKED]，不随选中态变化。
func highlight(p_selected_card: Control) -> void:
	if grid == null:
		return
	for i: int in range(grid.get_child_count()):
		var card: Control = grid.get_child(i) as Control
		if card == null:
			continue
		if not bool(card.get_meta(&"unlocked", true)):
			card.modulate.a = Factory.ALPHA_BLOCKED
			continue
		card.modulate.a = ALPHA_SELECTED if card == p_selected_card else ALPHA_IDLE


## 首张可开局卡的网格索引——初始键盘焦点目标；无可开局卡返回 -1。
func first_startable_index(p_entries: Array) -> int:
	if grid == null:
		return -1
	for i: int in range(min(grid.get_child_count(), p_entries.size())):
		if Rules.is_identity_ready(p_entries[i]):
			return i
	return -1


# === 详情面板 ==================================================================

## 详情面板落地——[param p_preview] 为空（身份表查无 / 系统不可用）时保持隐藏。
func show_detail(p_preview: Dictionary) -> void:
	if detail_panel == null or p_preview.is_empty():
		return
	detail_panel.visible = true
	detail_name_label.text = str(p_preview.get(&"name", ""))
	detail_deck_label.text = Rules.TEXT_DECK_HEADER + "：" + Rules.deck_summary(p_preview)
	detail_character_label.text = Rules.TEXT_CHARACTER_HEADER + "：" \
			+ Rules.character_summary(p_preview)
	detail_talent_label.text = Rules.TEXT_TALENT_HEADER + "：" \
			+ Rules.talent_summary(p_preview)
	detail_hint_label.text = str(p_preview.get(&"playstyle_hint", ""))


# === 弹窗 ======================================================================

## 确认弹窗内容组装——身份名 + 两名初始角色头像占位 + 提示文案。[br]
## [br]头像行先清空再重建（弹窗复用，避免重复添加）。
func populate_confirm_dialog(p_preview: Dictionary) -> void:
	if confirm_dialog == null or p_preview.is_empty():
		return
	confirm_dialog_name.text = str(p_preview.get(&"name", ""))
	confirm_dialog.dialog_text = Rules.TEXT_CONFIRM_PROMPT
	for child: Node in confirm_dialog_avatars.get_children():
		confirm_dialog_avatars.remove_child(child)
		child.queue_free()
	for display_name: String in Rules.character_names(p_preview):
		confirm_dialog_avatars.add_child(Factory.make_avatar_button(display_name))
	confirm_dialog.popup_centered()


## 弹提示——AcceptDialog（现有先例 corrupt_save_dialog）。[br]
## [br]标题与文案一起设：弹窗是复用的，不重设标题会停在上一句的语义上
## （「未解锁身份」标题配「暂未开放」文案）。空文案不弹。
func show_toast(p_text: String, p_title: String = "") -> void:
	if toast_dialog == null or p_text.is_empty():
		return
	if not p_title.is_empty():
		toast_dialog.title = p_title
	toast_dialog.dialog_text = p_text
	toast_dialog.popup_centered()


# === 入场动画（Tween 纯视觉变换——ADR-0031 §3 豁免）===========================

## 0.6s 6 卡依次飞入（[code]set_parallel(true)[/code] + 逐卡错峰）。[br]
## [br][b]遮罩保护[/b]：被拦卡的飞入目标为 [constant Factory.ALPHA_BLOCKED]，不是 1.0。
func play_intro() -> void:
	if grid == null or host == null or not host.is_inside_tree():
		return
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = host.create_tween()
	_intro_tween.set_parallel(true)
	for i: int in range(grid.get_child_count()):
		var card: Control = grid.get_child(i) as Control
		if card == null:
			continue
		var target_alpha: float = ALPHA_SELECTED
		if not bool(card.get_meta(&"unlocked", true)):
			target_alpha = Factory.ALPHA_BLOCKED
		card.modulate.a = 0.0
		_intro_tween.tween_property(card, "modulate:a", target_alpha, INTRO_DURATION) \
				.set_delay(i * INTRO_STAGGER) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# === 开局叙事（基础展示 + 任意键跳过——完整演出归叙事 epic）====================

## 开始叙事——按句读拆行逐行显示；仅一行时不起 Timer（无 tick 可等）。
func start_narrative(p_flavor_text: String) -> void:
	if narrative_overlay == null:
		return
	_stop_narrative_timer()
	_narrative_lines = Rules.split_narrative(p_flavor_text)
	_narrative_index = 0
	narrative_overlay.visible = true
	_show_next_narrative_line()
	if _narrative_lines.size() > 1 and host != null:
		_narrative_timer = Timer.new()
		_narrative_timer.wait_time = NARRATIVE_LINE_INTERVAL
		_narrative_timer.timeout.connect(_show_next_narrative_line)
		host.add_child(_narrative_timer)
		_narrative_timer.start()


## 叙事层当前是否可见——场景脚本据此决定是否消费输入。
func narrative_visible() -> bool:
	return narrative_overlay != null and narrative_overlay.visible


## 跳过叙事——已结束（不可见）时返回 false 且不重复发信号
## （逐行 tick 与跳过可能同帧到达，重复发信号会让上层重复请求导航）。
func skip_narrative() -> bool:
	if not narrative_visible():
		return false
	_finish_narrative()
	return true


## 场景退出时清理——停 Timer + kill Tween（防悬挂回调打到已释放节点）。
func teardown() -> void:
	_stop_narrative_timer()
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()


## 显示下一行——超出末尾 → 结束。
func _show_next_narrative_line() -> void:
	if _narrative_index >= _narrative_lines.size():
		_finish_narrative()
		return
	if narrative_label != null:
		narrative_label.text = _narrative_lines[_narrative_index]
	_narrative_index += 1


## 叙事结束——收层 + 停 Timer + 发 [signal narrative_finished]。
func _finish_narrative() -> void:
	_stop_narrative_timer()
	if narrative_overlay != null:
		narrative_overlay.visible = false
	narrative_finished.emit()


func _stop_narrative_timer() -> void:
	if _narrative_timer == null:
		return
	_narrative_timer.stop()
	if _narrative_timer.get_parent() != null:
		_narrative_timer.get_parent().remove_child(_narrative_timer)
	_narrative_timer.queue_free()
	_narrative_timer = null
