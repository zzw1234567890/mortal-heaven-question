class_name CombatLog
extends Control
## CombatLog —— 顶部条战斗日志组件（combat-ui-layout Story 004）。
##
## [b]职责[/b]：日志渲染态——默认折叠为小标签，展开为半屏覆盖（50% 屏高）；
## 条目格式 [code][回合·阶段] 行动者 → 动作 → 目标 → 数值[/code]（由调用侧
## 组装好文本经 [method append_entry] 追加）；最新在底自动滚底。[br]
## [br][b]范围划分[/b]：本 story 只做**展开/收起渲染态 + 条目追加滚底**；
## 点击展开的输入流转归 interaction epic（story 008），日志条目**生成**
## 归战斗系统域（行动记录数据源——当前 stub 先行，见 [method append_entry]）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：日志内容为渲染快照——条目文本由
## 战斗系统信号组装后传入，本组件只持展示列表。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——滚底由 [method append_entry]
## 追加后延迟一帧设置 [code]scroll_vertical[/code]（fit_content 高度下一帧才
## 落定，非逐帧跟随；interaction 展开时「跟随暂停」语义归 story 008）。[br]
## [br][b]阶段 2 自动收起[/b]（AC-2）：[method apply_phase] 收到 phase=2 且展开
## 时折叠；战斗结束 [method clear] 清空条目。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §战斗日志/§11、
## combat-ui-layout Story 004（AC-6）。

## === 布局常量（半屏覆盖 50%）=================================================

## 展开态高度比例（屏高 50%）。
const EXPANDED_HEIGHT_RATIO: float = 0.5
## 标签文本（折叠态）。
const LABEL_TEXT: String = "战斗日志"

## === 视觉常量 ================================================================

## 折叠标签背板色。
const COLLAPSED_BG: Color = Color(0.08, 0.09, 0.12, 0.85)
## 展开面板背板色。
const EXPANDED_BG: Color = Color(0.05, 0.06, 0.09, 0.94)
## 标签文本色。
const LABEL_COLOR: Color = Color(0.92, 0.92, 0.90)
## 面板圆角半径。
const CORNER_RADIUS: int = 4

## === 子节点引用 ==============================================================

## 折叠态标签按钮（入口位——点击流转归 interaction）。
var collapse_label: Button = null
## 展开态面板（RichTextLabel + ScrollContainer 包装）。
var expand_panel: PanelContainer = null
## 日志正文（RichTextLabel——GDD §11 指定）。
var log_rich: RichTextLabel = null
## 滚动容器。
var scroll: ScrollContainer = null

## === 运行态 ==================================================================

## 是否展开。
var _expanded: bool = false
## 日志条目文本列表（渲染快照——展示用）。
var _entries: Array[String] = []


func _init() -> void:
	_build()


## 构建折叠标签 + 展开面板（_init 构建——不依赖场景树时序）。
func _build() -> void:
	custom_minimum_size = Vector2(90, 32)
	collapse_label = Button.new()
	collapse_label.name = "CollapseLabel"
	collapse_label.text = LABEL_TEXT
	collapse_label.add_theme_font_size_override("font_size", 13)
	collapse_label.add_theme_color_override("font_color", LABEL_COLOR)
	collapse_label.flat = false
	collapse_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(collapse_label)
	# 展开面板：初始隐藏（默认折叠——AC「日志默认折叠为小标签」）。
	# 半屏覆盖（50% 屏高）：面板锚定在 CombatLog 底部，高度按**视口**换算——
	# 而非父控件高度（父控件仅 32-48px，相对锚定会产出 ~16-24px 的错误面板）。
	expand_panel = PanelContainer.new()
	expand_panel.name = "ExpandPanel"
	expand_panel.visible = false
	expand_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	expand_panel.anchor_top = 1.0
	expand_panel.anchor_bottom = 1.0
	expand_panel.add_theme_stylebox_override("panel", _make_panel_style(EXPANDED_BG))
	add_child(expand_panel)
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	expand_panel.add_child(scroll)
	log_rich = RichTextLabel.new()
	log_rich.name = "LogRich"
	log_rich.bbcode_enabled = false
	log_rich.scroll_active = false
	log_rich.fit_content = true
	log_rich.add_theme_font_size_override("normal_font_size", 13)
	scroll.add_child(log_rich)


## 设置减少动态。[br]
## [br][b]当前实现[/b]：展开/收起为瞬态 visible 切换（无动画 Tween）——
## 天然满足减少动态（UX「减少动态」= 无动画直跳）。方法保留为接口一致性，
## 供顶层 [CombatTopbar.set_reduce_motion] 统一转发。
func set_reduce_motion(_reduce_motion: bool) -> void:
	pass


## 追加日志条目（渲染管线入口——条目文本由战斗系统组装后传入）。[br]
## [b]stub 先行[/b]（2026-10-30 用户裁决）：战斗系统行动记录信号尚未落地，
## 本接口公开供测试直调与未来接线；追加后自动滚底（AC-2 滚底条款）。[br]
## [br][param entry_text]: 已组装好的条目文本（[code][回合·阶段] 行动者 → ...[/code]）。
func append_entry(entry_text: String) -> void:
	if entry_text == "":
		return
	_entries.append(entry_text)
	if log_rich.text == "":
		log_rich.text = entry_text
	else:
		log_rich.text = log_rich.text + "\n" + entry_text
	# 自动滚底（最新条目完全可见且位于容器底边——AC-2）
	request_scroll_to_bottom()


## 应用阶段（phase_changed 载荷——AC-2：阶段 2 进入时自动收起）。
func apply_phase(new_phase: int) -> void:
	if new_phase == 2 and _expanded:
		collapse()


## 展开（渲染态——interaction 触发流转时调用；本 story 亦经测试直调验证渲染）。
func expand() -> void:
	if _expanded:
		return
	_expanded = true
	expand_panel.visible = true
	# 展开面板高度按视口 50% 换算（_notification 会按尺寸重算——此处兜底设置）
	_apply_panel_height()
	request_scroll_to_bottom()


## 收起（渲染态）。
func collapse() -> void:
	if not _expanded:
		return
	_expanded = false
	expand_panel.visible = false


## 清空日志（战斗结束返回探索后——AC-2 清空条款）。
func clear() -> void:
	_entries.clear()
	log_rich.text = ""


## 是否展开（测试断言用）。
func is_expanded() -> bool:
	return _expanded


## 获取条目列表（测试断言用）。
func get_entries() -> Array[String]:
	return _entries


## 当前滚动位置（测试断言滚底用）。
func get_scroll_vertical() -> int:
	return scroll.scroll_vertical if scroll != null else 0


## === 内部 ====================================================================

## 尺寸落定后重算展开面板高度（按视口 50% 换算——非父控件相对锚定）。
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_panel_height()


## 展开面板高度 = 视口高度 × 50%（GDD「半屏覆盖」）。
func _apply_panel_height() -> void:
	if expand_panel == null:
		return
	var viewport_h: float = get_viewport_rect().size.y if is_inside_tree() else 1080.0
	expand_panel.offset_bottom = EXPANDED_HEIGHT_RATIO * viewport_h


## 请求滚底（声明滚底意图——滚动条 max_value 于帧末布局阶段才刷新，
## 故同步兜底一次后延迟到帧末 deferred 阶段再读新鲜 max_value 滚底；
## 零轮询、零固定帧等待）。
func request_scroll_to_bottom() -> void:
	if scroll == null:
		return
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value
	_flush_scroll.call_deferred()


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
