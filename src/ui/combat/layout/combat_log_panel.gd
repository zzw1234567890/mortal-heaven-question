class_name CombatLogPanel
extends PanelContainer
## CombatLogPanel —— 战斗日志的展开面板（渲染态——CombatLog 的展示下半身）。
##
## [b]职责[/b]：面板本体（背板 + 滚动容器 + 正文 RichTextLabel）、按视口换算的
## 展开尺寸、条目追加与滚底、空态占位。[b]不持条目列表、不持开合状态[/b]——
## 「展不展开」「有几条」归 [code]CombatLog[/code]（它是逻辑持有者，本类是它的画布）。[br]
## [br][b]为什么单独成文件[/b]：[code]combat_log.gd[/code] 加上开合入口后贴上
## 300 行软上限；面板的构建与尺寸换算是一块能整体搬走的纯渲染职责
## （同 [code]hand_area_cards.gd[/code] 拆节点池、[code]actor_stage_layout.gd[/code]
## 拆排位的先例）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——滚底由 [method append] 追加后
## 延迟一帧读新鲜 [code]max_value[/code]（[code]fit_content[/code] 的高度下一帧
## 才落定）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：正文是渲染快照，条目文本由调用方组装后传入。
##
## 来源: ADR-0031 §2、design/gdd/combat-ui-system.md §战斗日志/§11、
## combat-ui-layout Story 004（AC-6）、DEBT-CUI-007-2（同类拆分）。

## 展开态高度比例（屏高 50%——GDD「半屏覆盖」）。
const EXPANDED_HEIGHT_RATIO: float = 0.5
## 展开态宽度比例（屏宽 45%——收在左侧，不做全屏遮罩：底栏动作与右侧战场的
## 点选都留在玩家手边）。
const EXPANDED_WIDTH_RATIO: float = 0.45
## 展开面板背板色。
const EXPANDED_BG: Color = Color(0.05, 0.06, 0.09, 0.94)
## 面板圆角半径。
const CORNER_RADIUS: int = 4

## 滚动容器（面板内唯一可聚焦元素——键盘 / 手柄玩家翻看历史用）。
var scroll: ScrollContainer = null
## 日志正文（RichTextLabel——GDD §11 指定）。
var log_rich: RichTextLabel = null

## 空态是否已写进正文（避免每次追加都覆盖真实条目）。
var _empty_shown: bool = false


func _init() -> void:
	_build()


## 构建背板 + 滚动容器 + 正文（_init 构建——不依赖场景树时序）。[br]
## [br][b]尺寸按视口换算而非父控件[/b]：父控件（顶部条里的日志入口）只有 90px 宽，
## 相对锚定会算出 ~40px 的面板——一行字都放不下。高度同理（父控件仅 32-48px）。
func _build() -> void:
	name = "ExpandPanel"
	visible = false
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	anchor_top = 1.0
	anchor_bottom = 1.0
	add_theme_stylebox_override("panel", _make_panel_style(EXPANDED_BG))
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 面板内唯一可聚焦元素：滚动区（键盘/手柄玩家展开日志后 Tab 能进得来、
	# 用方向键翻看历史）。正文 RichTextLabel 保持引擎默认的读屏态，不做聚焦站。
	scroll.focus_mode = Control.FOCUS_ALL
	add_child(scroll)
	log_rich = RichTextLabel.new()
	log_rich.name = "LogRich"
	log_rich.bbcode_enabled = false
	log_rich.scroll_active = false
	log_rich.fit_content = true
	log_rich.add_theme_font_size_override("normal_font_size", 13)
	scroll.add_child(log_rich)


## 展开（显示面板 + 按视口落尺寸；正文为空时写空态占位）。[br]
## [param p_empty_text] 空态文案（由 [code]CombatLog[/code] 传入——文案常量归它，
## 本类不另存一份）。
func open(p_empty_text: String) -> void:
	visible = true
	_apply_size()
	if log_rich.text == "" and not _empty_shown:
		log_rich.text = p_empty_text
		_empty_shown = true
	scroll_to_bottom()


## 收起（隐藏面板；正文与空态标记保留，展开时按 [param p_empty_text] 重判）。
func close() -> void:
	visible = false


## 追加一条（空态占位先被顶掉，否则正文会带着「暂无记录」一直到战后）。
func append(p_entry_text: String) -> void:
	if p_entry_text == "":
		return
	if _empty_shown:
		log_rich.text = ""
		_empty_shown = false
	if log_rich.text == "":
		log_rich.text = p_entry_text
	else:
		log_rich.text = log_rich.text + "\n" + p_entry_text
	scroll_to_bottom()


## 清空正文与空态标记（战后清理——AC-2）。
func clear() -> void:
	_empty_shown = false
	log_rich.text = ""


## 当前正文文本。
func text() -> String:
	return log_rich.text


## 当前滚动位置（测试断言滚底用）。
func scroll_vertical() -> int:
	return scroll.scroll_vertical if scroll != null else 0


## 请求滚底（滚动条 max_value 于帧末布局阶段才刷新，故同步兜底一次后延迟到
## 帧末 deferred 阶段再读新鲜 max_value 滚底；零轮询、零固定帧等待）。
func scroll_to_bottom() -> void:
	if scroll == null:
		return
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value
	_flush_scroll.call_deferred()


## 尺寸落定后重算面板尺寸（按视口换算）。
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_size()


## 高度 = 视口高 × 50%（GDD「半屏覆盖」）；宽度 = 视口宽 × 45%（收在左侧）。
func _apply_size() -> void:
	var viewport: Vector2 = get_viewport_rect().size if is_inside_tree() \
			else Vector2(1920.0, 1080.0)
	offset_bottom = EXPANDED_HEIGHT_RATIO * viewport.y
	anchor_left = 0.0
	anchor_right = 0.0
	offset_left = 0.0
	offset_right = EXPANDED_WIDTH_RATIO * viewport.x


## 滚底落定（deferred 阶段调用——此时滚动条 max_value 已按 fit_content
## 内容高度重算，读到的值为新鲜值）。
func _flush_scroll() -> void:
	if scroll != null and is_instance_valid(scroll):
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value


## 面板样式（纯色背板——StyleBoxFlat）。
func _make_panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	return style
