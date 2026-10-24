class_name IdentitySelect
extends Control
## IdentitySelect —— 开局身份选择场景（identity-selection Story S16-1）。
##
## [b]节点形态[/b]（ADR-0031 §1）：场景内 Control 树（零新增 Autoload），
## 由 [constant SceneManager.SCENE_PATHS] 的 IDENTITY_SELECT 条目挂载
## （[code]res://src/ui/identity_select/identity_select.tscn[/code]）。[br]
## [br][b]结构[/b]：标题 + 6 卡 2×3 网格（代码动态构建）+ 底部详情面板 +
## 确认按钮 + 解锁提示（AcceptDialog）+ 确认弹窗（ConfirmationDialog）+
## 开局叙事层（全屏覆盖，任意键跳过）。[br]
## [br][b]Logic 内核[/b]（BLOCKING 单测目标）：[method confirm_button_enabled] /
## [method is_identity_unlocked] 两个 static 纯函数（差距 3 裁决——定义在场景
## 脚本内、以 static 暴露供 GUT 直调）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：[member selected_id] 是场景内瞬态
## 交互状态（§2.1 三分类——不进存档、刷新即弃）；最终结果只经
## [code]IdentitySelectionSystem.apply_identity()[/code] 写入 GSM，本场景绝不
## 直接写 GSM。[br]
## [br][b]场景导航[/b]：一律 [code]SceneManager.request_scene_change[/code]
## （control-manifest 必需——绝不直调 change_scene_to_file）。读档跳过：
## [code]is_identity_selected()[/code] true → 直接请求导航 EXPLORATION，
## 不渲染选择 UI。[br]
## [br][b]焦点导航[/b]：6 卡 + 确认按钮键盘焦点环（复用 main-menu 先例
## [code]grab_focus()[/code]）；初始焦点 = 第一张已解锁卡。焦点环（松石青 2px）
## 与悬停（墨色边框加粗）双视觉由引擎默认主题 + 后续视觉 story 落实
## （main-menu story 001 骨架先例 PauseMenu 同源）。[br]
## [br][b]动画[/b]：0.6s 6 卡依次飞入（[code]create_tween()[/code] 纯视觉变换
## 豁免，ADR-0031 §3）。[member animate] 为 reduce-motion 预留接线点。[br]
## [br][b]音频[/b]：入场触发 [code]AudioManager.set_state(AudioState.IDENTITY_SELECT)[/code]
## ——无确切编钟/古琴 SFX id，音频资产归属 audio story 004（Deviations 登记）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]。
##
## @experimental
## 来源: ADR-0022、ADR-0031、control-manifest §Presentation、
## design/gdd/identity-selection-system.md §4-5、story-004-identity-select-ui.md。

## === Visual 常量（数据驱动）====================================================

## 入场动画总时长——0.6s（GDD §视觉/音频需求「6 卡依次飞入 0.6s」）。
const INTRO_DURATION: float = 0.6
## 每卡飞入的 stagger 间隔（秒）——6 卡 × 0.1s 错峰落在 0.6s 总窗口内。
const INTRO_STAGGER: float = 0.1
## 开局叙事逐行显示间隔（秒）——story 仅基础展示 + 任意键跳过，逐行显示
## 归叙事 epic（本常量供逐行推进的 Timer 使用）。
const NARRATIVE_LINE_INTERVAL: float = 0.8

## 固定 UI 词条（GDD §用户界面需求原文；项目暂无本地化系统——先例
## MainMenu.TEXT_* 同源豁免注记，本地化入库后替换为键）。
const TEXT_TITLE: String = "选择你的开局身份"
const TEXT_CONFIRM_BUTTON: String = "确认选择"
const TEXT_CONFIRM_PROMPT: String = "确定选择？本局不可更改"
const TEXT_LOCKED_TOAST: String = "该身份需要轮回天赋『苍玄行者』解锁"
## 底部详情面板分段标签（数据驱动——集中成 const 块，不散落魔法字符串）。
const TEXT_DECK_HEADER: String = "初始卡组"
const TEXT_CHARACTER_HEADER: String = "初始角色"
const TEXT_TALENT_HEADER: String = "专属天赋"
const TEXT_LING_SHI_SUFFIX: String = "灵石"

## SceneManager 脚本常量——枚举单一真理来源（SceneID/TransitionType 均为
## const，preload 引用不依赖 Autoload 实例存在——先例 main_menu SceneManagerScript）。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
## AudioEnums 脚本常量——AudioState 枚举真理来源（同 main_menu 模式）。
const AudioEnumsScript := preload("res://src/ui/audio/audio_enums.gd")
## InputManager 脚本常量——ActionType/DeviceType 枚举真理来源（preload 引用
## 不依赖 Autoload 实例存在，先例 SceneManagerScript）。
const InputManagerScript := preload("res://src/foundation/input_manager.gd")

## === 依赖注入（测试可替换）=====================================================

## SceneManager 引用——导航转场用（null 时回退 Autoload，先例 main_menu）。
var scene_manager: Node = null
## IdentitySelectionSystem 引用——查询/apply 数据源（null 时回退 Autoload）。
var identity_system: Node = null
## 动画开关——测试注入 + reduce-motion 预留接线点（头注释）。
var animate: bool = true

## === 瞬态交互状态（ADR-0031 §2.1）=============================================

## 当前选中身份 ID（空 = 未选中）——场景内瞬态交互状态，不进存档、刷新即弃。
var selected_id: StringName = &""

## 入场 Tween 句柄（新请求时 kill 防悬挂——先例 main_menu._intro_tween）。
var _intro_tween: Tween = null
## 叙事逐行推进 Timer（确认后叙事展示用）。
var _narrative_timer: Timer = null
## 叙事文本行缓存 + 当前行索引（瞬态交互状态——叙事展示层本地）。
var _narrative_lines: Array[String] = []
var _narrative_index: int = 0

## === 节点引用 ==================================================================

@onready var title_label: Label = $LayoutAnchor/TitleLabel
@onready var grid: GridContainer = $LayoutAnchor/GridContainer
@onready var detail_panel: Panel = $LayoutAnchor/DetailPanel
@onready var detail_name_label: Label = $LayoutAnchor/DetailPanel/NameLabel
@onready var detail_deck_label: Label = $LayoutAnchor/DetailPanel/DeckLabel
@onready var detail_character_label: Label = $LayoutAnchor/DetailPanel/CharacterLabel
@onready var detail_talent_label: Label = $LayoutAnchor/DetailPanel/TalentLabel
@onready var detail_hint_label: Label = $LayoutAnchor/DetailPanel/HintLabel
@onready var confirm_button: Button = $LayoutAnchor/ConfirmButton
@onready var locked_dialog: AcceptDialog = $LockedDialog
@onready var confirm_dialog: ConfirmationDialog = $ConfirmDialog
@onready var confirm_dialog_name: Label = $ConfirmDialog/NameLabel
@onready var confirm_dialog_avatars: HBoxContainer = $ConfirmDialog/Avatars
@onready var narrative_overlay: Control = $NarrativeOverlay
@onready var narrative_label: Label = $NarrativeOverlay/TextLabel

## === Logic 内核（static 纯函数——BLOCKING 单测目标）============================

## 确认按钮启用态判定（AC-1 / QA AC-1）。[br]
## [br][param selected_id]: 当前选中身份 ID（空 StringName = 未选中）。[br]
## [b]返回[/b]: 空选中 → [code]false[/code]；非空 → [code]true[/code]。[br]
## [br]纯函数——无状态、无 Autoload 访问（static 供 GUT 直调）。
static func confirm_button_enabled(selected_id: StringName) -> bool:
	return not selected_id.is_empty()


## 解锁状态透传（AC-2 / QA AC-2）。[br]
## [br][param entry]: [code]get_available_identities()[/code] 返回的单条目
## Dictionary（含 [code]is_unlocked[/code] 字段）。[br]
## [b]返回[/b]: 透传 [code]entry.get(&"is_unlocked", false)[/code]——不自算
## 解锁条件（story 001 [code]get_available_identities[/code] 已结合轮回天赋
## 状态算好）。[br]
## [br]纯函数——无状态、无 Autoload 访问。
static func is_identity_unlocked(entry: Dictionary) -> bool:
	return bool(entry.get(&"is_unlocked", false))


## === 生命周期 ==================================================================

func _ready() -> void:
	# 读档跳过：identity_id 非空 → 直接请求导航 EXPLORATION，不渲染选择 UI。
	if _is_skip_needed():
		_skip_to_exploration()
		return
	_build_ui()


func _exit_tree() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	if _narrative_timer != null:
		_narrative_timer.stop()
		_narrative_timer = null


## === 读档跳过（godot-specialist 高风险修正——信号驱动 + call_deferred）==========

## 判定是否需要跳过选择 UI——消费 [code]is_identity_selected()[/code]。
func _is_skip_needed() -> bool:
	var isys: Node = _get_identity_system()
	if isys != null and isys.has_method(&"is_identity_selected"):
		return bool(isys.is_identity_selected())
	return false


## 请求跳到探索——不能直接 request_scene_change。[br]
## [br][b]证据链[/b]：目标场景 [code]_ready()[/code] 在转场完成前同步执行，
## 此时 SceneManager [code]_transitioning[/code] 仍为 true（Phase 2 置 true、
## Phase 5 才置 false），直接调用会被并发守卫静默拒绝（[code]return false[/code]），
## 玩家卡在空场景。必须等 [signal post_transition] 后再 [code]call_deferred[/code]
## 请求导航（godot-specialist 验证结论——仅「场景加载瞬间的读档跳过」需要 defer，
## 确认流程导航发生在玩家点击时、转场早已完成，可直接调用）。
func _skip_to_exploration() -> void:
	var sm: Node = _get_scene_manager()
	if sm == null or not sm.has_signal(&"post_transition"):
		push_error("IdentitySelect: SceneManager 不可用——读档跳过中止")
		return
	# 当前转场未完成（_transitioning=true），必须等 post_transition 后 defer
	sm.post_transition.connect(_on_transition_complete, CONNECT_ONE_SHOT)


func _on_transition_complete(_from: int, _to: int) -> void:
	call_deferred(&"_request_exploration")


## 请求导航到探索地图（读档跳过路径）。[br]
## [b]注意[/b]：EXPLORATION 场景为占位路径（exploration story 002 落盘后自动
## 生效），本 story 只保证导航请求发出。
func _request_exploration() -> void:
	var sm: Node = _get_scene_manager()
	if sm == null or not sm.has_method(&"request_scene_change"):
		return
	var from_id: int = SceneManagerScript.SceneID.IDENTITY_SELECT
	if sm.has_method(&"get_current_scene_id"):
		from_id = sm.get_current_scene_id()  # Phase 5 后已更新为 IDENTITY_SELECT
	sm.request_scene_change(from_id,
			SceneManagerScript.SceneID.EXPLORATION,
			SceneManagerScript.TransitionType.MENU_TO_GAME)


## === UI 构建 ===================================================================

## 渲染 6 卡 2×3 网格 + 底部详情面板初始态 + 音频状态 + 入场动画 + 初始焦点。
func _build_ui() -> void:
	title_label.text = TEXT_TITLE
	confirm_button.text = TEXT_CONFIRM_BUTTON
	detail_panel.visible = false
	# 弹窗静态文案（title/按钮文案）已在 .tscn 配置；动态文案在
	# _show_locked_toast / _show_confirm_dialog 时设置——无需 setup 方法。
	narrative_overlay.visible = false
	_refresh_cards()
	_refresh_confirm_button()
	_trigger_audio_state()
	if animate:
		_play_intro()
	# 初始焦点 = 第一张已解锁卡（story Implementation Notes——键盘焦点环）。
	var first_card: Control = _first_unlocked_card()
	if first_card != null:
		first_card.grab_focus()


## 刷新 6 卡网格——消费 [code]get_available_identities()[/code]（每信号周期
## 从源系统读取，不缓存副本——ADR-0031 §2）。[br]
## [b]防御[/b]：IdentitySelectionSystem 不可用或返回条目数 <6 时，缺失条目以
## 空字典占位——[method _build_card] 对空 entry 安全渲染锁定位卡片，场景不崩溃。
func _refresh_cards() -> void:
	for child: Node in grid.get_children():
		child.queue_free()
	var entries: Array = _get_available_identities()
	for i: int in range(6):
		var entry: Dictionary = {}
		if i < entries.size():
			entry = entries[i]
		var card: Control = _build_card(entry, i)
		grid.add_child(card)


## 构建单张身份卡片（纯代码构建——先例 notification_toast_area 动态节点模式）。[br]
## [br]结构：Panel（卡片底）+ VBox（名称 Label / 风格标签 Label / 角色头像占位
## HBox / 灵石 Label）。[br]
## [br]解锁判定走 [method is_identity_unlocked] 纯函数；锁定卡半透明 + 点击提示。[br]
## [br]卡片点击 = 瞬态选中态（场景内局部状态），直接 [code]gui_input[/code] 合法
## （改变游戏状态的确认按钮才需过 InputManager 锁栈）。[br]
## [br]卡片解锁态经 [code]set_meta(&amp;"unlocked", ...)[/code] 存入节点——供
## [method _highlight_selected] 高亮时区分锁定卡（锁定卡遮罩不随选中态变化）。
func _build_card(entry: Dictionary, index: int) -> Control:
	var unlocked: bool = is_identity_unlocked(entry)
	var card: Panel = Panel.new()
	card.name = "Card%d" % index
	card.custom_minimum_size = Vector2(280, 150)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	# 键盘焦点环（godot-specialist：纯 Control 默认 FOCUS_NONE，必须显式开启
	# 才能 grab_focus——双焦点下键盘/手柄焦点与鼠标悬停独立）。
	card.focus_mode = Control.FOCUS_ALL
	card.set_meta(&"unlocked", unlocked)
	if not unlocked:
		card.modulate = Color(1.0, 1.0, 1.0, 0.45)  # 半透明锁定态

	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12.0
	box.offset_top = 10.0
	box.offset_right = -12.0
	box.offset_bottom = -10.0
	card.add_child(box)

	var name_label: Label = Label.new()
	name_label.text = _entry_text(entry, &"name", "—")
	if not unlocked:
		name_label.text += " 🔒"
	box.add_child(name_label)

	var tag_label: Label = Label.new()
	tag_label.text = str(entry.get(&"style_tag", ""))
	box.add_child(tag_label)

	box.add_child(_build_avatar_box(entry))

	var ling_shi_label: Label = Label.new()
	var ling_shi: int = int(entry.get(&"initial_ling_shi", 0))
	ling_shi_label.text = "%d %s" % [ling_shi, TEXT_LING_SHI_SUFFIX]
	box.add_child(ling_shi_label)

	card.gui_input.connect(_on_card_gui_input.bind(index, entry))
	return card


## 构建卡片头像占位 HBox——两名初始角色显示名（disabled Button 占位，头像
## 纹理由后续视觉 story 走统一图集替换，control-manifest R-02 禁独立纹理）。
func _build_avatar_box(entry: Dictionary) -> HBoxContainer:
	var avatars: HBoxContainer = HBoxContainer.new()
	for display_name: String in _entry_character_names(entry):
		var avatar: Button = Button.new()
		avatar.text = display_name
		avatar.disabled = true  # 头像占位——不可交互
		avatar.custom_minimum_size = Vector2(0, 32)
		avatars.add_child(avatar)
	return avatars


## === 卡片交互 ==================================================================

## 卡片点击——瞬态选中态，直接 [code]gui_input[/code] 合法（不改变游戏状态）。[br]
## [br]锁定卡 → 弹解锁提示；已解锁卡 → 选中 + 详情面板刷新。
func _on_card_gui_input(event: InputEvent, index: int, entry: Dictionary) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var card: Control = grid.get_child(index) as Control
	if card == null:
		return
	if not is_identity_unlocked(entry):
		_show_locked_toast()
		return
	var identity_id: StringName = StringName(str(entry.get(&"identity_id", &"")))
	selected_id = identity_id
	_highlight_selected(card)
	_show_detail(identity_id)
	_refresh_confirm_button()


## 高亮选中卡片（其余恢复默认）——纯视觉，不写游戏状态。[br]
## [b]锁定卡遮罩保护[/b]：锁定卡（[code]get_meta(&amp;"unlocked") == false[/code]）
## 始终保持 0.45 半透明遮罩，不随选中态变化（AC「阵道双杰未解锁时卡片显示
## 半透明 🔒 遮罩」）；未选中的解锁卡 0.85，选中卡 1.0。
func _highlight_selected(selected_card: Control) -> void:
	for i: int in range(grid.get_child_count()):
		var card: Control = grid.get_child(i) as Control
		if card == null:
			continue
		if not bool(card.get_meta(&"unlocked", true)):
			card.modulate.a = 0.45  # 锁定卡遮罩不随选中态变化
			continue
		var selected: bool = (card == selected_card)
		card.modulate.a = 1.0 if selected else 0.85


## === 详情面板 ==================================================================

## 展示选中身份详情——消费 [code]get_identity_preview()[/code]（卡组概览 /
## 角色属性 / 天赋描述）。
func _show_detail(identity_id: StringName) -> void:
	var preview: Dictionary = _get_identity_preview(identity_id)
	if preview.is_empty():
		return
	detail_panel.visible = true
	detail_name_label.text = str(preview.get(&"name", ""))
	detail_deck_label.text = TEXT_DECK_HEADER + "：" + _deck_summary(preview)
	detail_character_label.text = TEXT_CHARACTER_HEADER + "：" \
			+ _character_summary(preview)
	detail_talent_label.text = TEXT_TALENT_HEADER + "：" + _talent_summary(preview)
	detail_hint_label.text = str(preview.get(&"playstyle_hint", ""))


## 卡组概览——卡名×数量拼装（从 initial_deck_cards 读，不硬编码卡名）。
func _deck_summary(preview: Dictionary) -> String:
	var parts: Array[String] = []
	var cards: Array = preview.get(&"initial_deck_cards", [])
	for card_entry: Dictionary in cards:
		parts.append("%s×%d" % [str(card_entry.get(&"card_id", "")),
				int(card_entry.get(&"count", 0))])
	return "、".join(parts)


## 角色概览——角色名拼装（从 character_details 读 display_name）。
func _character_summary(preview: Dictionary) -> String:
	var parts: Array[String] = []
	var details: Array = preview.get(&"character_details", [])
	for detail: Dictionary in details:
		parts.append(str(detail.get(&"display_name", "")))
	return "+".join(parts)


## 天赋描述——从 talent 字典读（名称 + 描述）。
func _talent_summary(preview: Dictionary) -> String:
	var talent: Dictionary = preview.get(&"talent", {})
	return "%s：%s" % [str(talent.get(&"name", "")),
			str(talent.get(&"description", ""))]


## === 确认流程 ==================================================================

## 确认按钮点击——改变游戏状态（apply_identity 写 GSM）必须过
## [code]InputManager.is_input_allowed()[/code] 锁栈判定。[br]
## [br]通过 → 弹确认弹窗；不通过 → 静默忽略（输入被上层锁冻结）。
func _on_confirm_pressed() -> void:
	if selected_id.is_empty():
		return
	if not _is_input_allowed():
		return
	_show_confirm_dialog()


## 确认弹窗内容组装——身份名 + 两名初始角色头像占位 + 提示文案。[br]
## [b]角色头像[/b]：从 [code]get_identity_preview()[/code] 的 [code]character_details[/code]
## 渲染两名角色显示名（disabled Button 占位，复用 [method _build_avatar_box]
## 模式；头像纹理走统一图集归视觉 story）。
func _show_confirm_dialog() -> void:
	var preview: Dictionary = _get_identity_preview(selected_id)
	if preview.is_empty():
		return
	confirm_dialog_name.text = str(preview.get(&"name", ""))
	confirm_dialog.dialog_text = TEXT_CONFIRM_PROMPT
	_rebuild_confirm_avatars(preview)
	confirm_dialog.popup_centered()


## 重建确认弹窗头像行——消费 character_details（display_name），清空旧节点
## 后重建（弹窗复用，避免重复添加）。
func _rebuild_confirm_avatars(preview: Dictionary) -> void:
	for child: Node in confirm_dialog_avatars.get_children():
		child.queue_free()
	var avatars: HBoxContainer = confirm_dialog_avatars
	var details: Array = preview.get(&"character_details", [])
	for detail: Dictionary in details:
		var avatar: Button = Button.new()
		avatar.text = str(detail.get(&"display_name", ""))
		avatar.disabled = true  # 头像占位——不可交互
		avatar.custom_minimum_size = Vector2(0, 32)
		avatars.add_child(avatar)


## [返回重选]——关闭弹窗、保留选中（不重置 [member selected_id]）。
func _on_confirm_dialog_canceled() -> void:
	pass  # 选中保留——仅关闭弹窗（selected_id 不动）


## [确定]——[code]apply_identity()[/code] 成功 → 开局叙事展示（flavor_text
## 逐行显示，任意键跳过）→ 请求导航 EXPLORATION。
func _on_confirm_dialog_confirmed() -> void:
	var isys: Node = _get_identity_system()
	if isys == null or not isys.has_method(&"apply_identity"):
		push_error("IdentitySelect: IdentitySelectionSystem 不可用——确认中止")
		return
	if not bool(isys.apply_identity(selected_id)):
		push_error("IdentitySelect: apply_identity 失败——确认中止")
		return
	_start_narrative()


## === 开局叙事（基础展示 + 任意键跳过——完整演出归叙事 epic）====================

## 开始叙事展示——从 [code]get_identity_preview()[/code] 的 flavor_text 逐行
## 显示（story 仅基础展示 + 任意键跳过；正式逐行动画曲线归叙事 epic）。
func _start_narrative() -> void:
	var preview: Dictionary = _get_identity_preview(selected_id)
	var flavor: String = str(preview.get(&"flavor_text", ""))
	_narrative_lines = _split_narrative(flavor)
	_narrative_index = 0
	narrative_overlay.visible = true
	_show_next_narrative_line()
	if _narrative_lines.size() > 1:
		_narrative_timer = Timer.new()
		_narrative_timer.wait_time = NARRATIVE_LINE_INTERVAL
		_narrative_timer.timeout.connect(_on_narrative_tick)
		add_child(_narrative_timer)
		_narrative_timer.start()


func _on_narrative_tick() -> void:
	_show_next_narrative_line()


## 显示下一行——超出末尾 → 请求导航 EXPLORATION（本 story 只保证导航请求发出）。
func _show_next_narrative_line() -> void:
	if _narrative_index >= _narrative_lines.size():
		_finish_narrative()
		return
	narrative_label.text = _narrative_lines[_narrative_index]
	_narrative_index += 1


## 叙事结束——清理 Timer + 请求导航（本 story 以「任意键跳过即触发导航请求」
## 实现；正式「开始游戏」按钮归叙事 epic）。
func _finish_narrative() -> void:
	if _narrative_timer != null:
		_narrative_timer.stop()
		_narrative_timer = null
	narrative_overlay.visible = false
	_request_exploration()


## 任意键跳过叙事——[code]_input()[/code] 拦截（先例 pause_menu ESC 拦截路径）。[br]
## [b]消费输入[/b]：触发跳过后立即 [code]get_viewport().set_input_as_handled()[/code]
## 消费该事件——阻止 ESC 继续传播到 InputManager 触发暂停菜单、阻止鼠标点击
## 穿透到下层卡片（NarrativeOverlay mouse_filter=IGNORE）。ESC 保留暂停语义的
## 细化归叙事 epic / 视觉 story，本 story 任意键跳过优先。
func _input(event: InputEvent) -> void:
	if not narrative_overlay.visible:
		return
	if event is InputEventKey and event.pressed:
		_finish_narrative()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_finish_narrative()
		get_viewport().set_input_as_handled()


## 叙事文本拆分——按句读拆行（。！？……后断行，空行过滤）。
func _split_narrative(text: String) -> Array[String]:
	var lines: Array[String] = []
	var current: String = ""
	for ch: String in text:
		current += ch
		if ch in ["。", "！", "？"]:
			lines.append(current)
			current = ""
	if not current.is_empty():
		lines.append(current)
	if lines.is_empty() and not text.is_empty():
		lines.append(text)
	return lines


## === 锁定提示 ==================================================================

## 锁定提示——AcceptDialog 弹窗（现有先例 corrupt_save_dialog）。
func _show_locked_toast() -> void:
	locked_dialog.dialog_text = TEXT_LOCKED_TOAST
	locked_dialog.popup_centered()


## === 音频（最小触发——AC-10）====================================================

## 入场音频状态——调用 AudioManager 现有 [code]set_state[/code]。[br]
## [b]Deviations[/b]：无确切编钟/古琴 SFX id，触发
## [code]set_state(AudioState.IDENTITY_SELECT)[/code] 作为最小接入；音频资产
## 归属 audio story 004（故事范围 Out of Scope 记录）。
func _trigger_audio_state() -> void:
	var sm: Node = _get_scene_manager()
	if sm == null or not sm.has_method(&"get_audio_manager"):
		return
	var am = sm.get_audio_manager()
	if am != null and am.has_method(&"set_state"):
		am.set_state(AudioEnumsScript.AudioState.IDENTITY_SELECT)


## === 入场动画（Tween 纯视觉变换——ADR-0031 §3 豁免）===========================

## 0.6s 6 卡依次飞入（[code]create_tween().set_parallel(true)[/code] + 逐卡
## [code]tween_property[/code] 错峰）。[br]
## [member animate] false（测试/reduce-motion）时直接跳到位。[br]
## [b]锁定卡遮罩保护[/b]：锁定卡飞入目标 alpha 为 0.45 而非 1.0（与
## [method _highlight_selected] 同一遮罩不变量——阵道双杰锁定卡半透明遮罩
## 不得被入场动画冲到完全不透明）。
func _play_intro() -> void:
	if not is_inside_tree():
		return
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.set_parallel(true)
	for i: int in range(grid.get_child_count()):
		var card: Control = grid.get_child(i) as Control
		if card == null:
			continue
		var target_alpha: float = 1.0
		if not bool(card.get_meta(&"unlocked", true)):
			target_alpha = 0.45  # 锁定卡遮罩不随入场动画丢失
		card.modulate.a = 0.0
		_intro_tween.tween_property(card, "modulate:a", target_alpha,
				INTRO_DURATION) \
				.set_delay(i * INTRO_STAGGER) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## === 内部辅助 ==================================================================

## 确认按钮 enabled 态刷新——由 Logic 内核 [method confirm_button_enabled] 驱动。
func _refresh_confirm_button() -> void:
	confirm_button.disabled = not confirm_button_enabled(selected_id)


## 获取第一张已解锁卡（初始焦点目标）——遍历网格找首个 is_unlocked 卡片。
func _first_unlocked_card() -> Control:
	var entries: Array = _get_available_identities()
	for i: int in range(min(grid.get_child_count(), entries.size())):
		if is_identity_unlocked(entries[i]):
			return grid.get_child(i) as Control
	return null


## 从 entry 取文本字段（防御空值——数据缺失时安全占位）。
func _entry_text(entry: Dictionary, key: StringName, fallback: String) -> String:
	var value: String = str(entry.get(key, ""))
	return value if not value.is_empty() else fallback


## 从 entry 取角色显示名列表（防御——兼容 character_display_names 缺失）。
func _entry_character_names(entry: Dictionary) -> Array[String]:
	var names: Array = entry.get(&"character_display_names", [])
	var result: Array[String] = []
	for n: Variant in names:
		result.append(str(n))
	return result


## 获取 6 条身份条目——IdentitySelectionSystem 不可用时返回空数组（渲染 6 张
## 锁定位卡片，场景不崩溃）。
func _get_available_identities() -> Array:
	var isys: Node = _get_identity_system()
	if isys != null and isys.has_method(&"get_available_identities"):
		return isys.get_available_identities()
	push_warning("IdentitySelect: IdentitySelectionSystem 不可用——渲染锁定位")
	return []


## 获取身份预览——同上防御。
func _get_identity_preview(identity_id: StringName) -> Dictionary:
	var isys: Node = _get_identity_system()
	if isys != null and isys.has_method(&"get_identity_preview"):
		return isys.get_identity_preview(identity_id)
	return {}


## 输入锁栈判定——确认按钮改变游戏状态必须过 [code]InputManager.is_input_allowed[/code]
## （ADR-0004 公共 API）。[br]
## [br][b]设备判定[/b]：[code]Button.pressed[/code] 信号不携带触发设备，确认按钮
## 主路径为鼠标点击，恒判 [code]DeviceType.MOUSE[/code]（GAMEPLAY 分类）。键盘
## Enter 激活确认按钮的设备区分属 focus/gamepad 细化（story Out of Scope），
## 待键盘激活落地后补 KEYBOARD 判定——当前不声称存在未实现的逻辑。[br]
## [br]InputManager 不可用时放行（测试 mock 场景无 Autoload）。
func _is_input_allowed() -> bool:
	var im: Node = get_node_or_null("/root/InputManager")
	if im == null or not im.has_method(&"is_input_allowed"):
		return true
	return bool(im.is_input_allowed(
			InputManagerScript.ActionType.GAMEPLAY,
			InputManagerScript.DeviceType.MOUSE))


## 获取 SceneManager——注入对象优先，否则回退 Autoload（先例 main_menu）。
func _get_scene_manager() -> Node:
	if scene_manager != null:
		return scene_manager
	return get_node_or_null("/root/SceneManager")


## 获取 IdentitySelectionSystem——注入对象优先，否则回退 Autoload。
func _get_identity_system() -> Node:
	if identity_system != null:
		return identity_system
	return get_node_or_null("/root/IdentitySelectionSystem")
