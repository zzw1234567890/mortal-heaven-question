class_name CombatLog
extends Control
## CombatLog —— 顶部条战斗日志组件（combat-ui-layout Story 004；本轮接上开合入口）。
##
## [b]职责[/b]：日志的[b]逻辑与入口[/b]——折叠标签按钮（开合、文案随状态变化）、
## 开合状态、条目列表（渲染快照）、阶段 2 自动收起、战后清空。
## 画面（面板背板 / 滚动区 / 正文 / 尺寸换算）归 [CombatLogPanel]——见下方「拆分」。[br]
## [br][b]开合入口已接线[/b]（本轮）：折叠按钮的 [signal BaseButton.pressed] 直连
## [method toggle]——此前该信号全库无人接线，点它什么都不会发生（上一轮为此把按钮的
## [member Control.focus_mode] 收成 [constant Control.FOCUS_NONE]，入口等于彻底消失）。
## 现在按钮恢复可聚焦、文案随状态变化（[constant LABEL_TEXT] ↔
## [constant LABEL_TEXT_EXPANDED]），并且是焦点链上的一站（含键盘 / 手柄）。[br]
## [br][b]条目复用既有战报数据源[/b]：[code]enemy_action_resolved[/code]
## → [code]EnemyActionBroadcast[/code] → [method append_entry]（生产接线在
## [code]CombatLayout.setup_feedback[/code]）。本组件[b]不新造第二套战报[/b]，
## 只持展示快照。[br]
## [br][b]拆分[/b]：面板（[CombatLogPanel]）在 [code]combat_log_panel.gd[/code]——
## 开合入口接进来后本文件贴上 300 行软上限，而「面板怎么画、展开多大」是一块能整体
## 搬走的纯渲染职责（同 [code]hand_area_cards.gd[/code] / [code]actor_stage_layout.gd[/code]
## 的先例）。[member expand_panel] / [member log_rich] / [member scroll] 是面板的
## 代理属性，外部引用点（含既有用例）保持不变。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：日志内容为渲染快照——条目文本由
## 战斗系统信号组装后传入，本组件只持展示列表。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——滚底由面板的 [method
## CombatLogPanel.scroll_to_bottom] 延迟一帧完成。[br]
## [br][b]阶段 2 自动收起[/b]（AC-2）：[method apply_phase] 收到 phase=2 且展开
## 时折叠；战斗结束 [method clear] 清空条目。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §战斗日志/§11、
## combat-ui-layout Story 004（AC-6）、.claude/rules/ui-code.md（双输入）。

## 展开面板（渲染态——画布本体）。
const PanelScript: GDScript = preload(
		"res://src/ui/combat/layout/combat_log_panel.gd")
## 焦点环几何（复用「能不能落焦点」判据——不另写一份）。
const Ring: GDScript = preload("res://src/ui/combat/interaction/combat_focus_ring.gd")

## === 文案常量（状态写在按钮上，不用图标暗示）=================================

## 标签文本（折叠态）。
const LABEL_TEXT: String = "战斗日志"
## 标签文本（展开态——写清「再按一次会发生什么」）。
const LABEL_TEXT_EXPANDED: String = "收起日志"
## 空态文案（展开时本场还没有任何条目）——如实说「暂无」，不摆一块空白面板
## 让人以为界面坏了。
const EMPTY_TEXT: String = "（本场战斗暂无记录）"

## === 视觉常量 ================================================================

## 标签文本色。
const LABEL_COLOR: Color = Color(0.92, 0.92, 0.90)

## === 信号 ====================================================================

## 开合状态变化（[code]true[/code] = 已展开）。[br]
## [br][b]为什么要有这个信号[/b]：焦点链按「面板是否可见」决定日志面板内还有没有
## 可聚焦的一站；开合只发生在按钮的 [signal BaseButton.pressed] 上，链若不订阅
## 就只能等下一次阶段切换才更新——玩家展开日志后按 Tab 会直接跳过面板。
signal expand_changed(expanded: bool)

## === 子节点引用 ==============================================================

## 折叠标签按钮（开合入口——[signal BaseButton.pressed] 直连 [method toggle]）。
var collapse_label: Button = null
## 展开面板（画布本体——[CombatLogPanel]）。
var panel: CombatLogPanel = null

## === 运行态 ==================================================================

## 是否展开。
var _expanded: bool = false
## 日志条目文本列表（渲染快照——展示用）。
var _entries: Array[String] = []


## 展开面板（代理属性——面板是唯一持有者；既有引用点保持不变）。
var expand_panel: PanelContainer:
	get: return panel

## 日志正文（代理属性——RichTextLabel——GDD §11 指定）。
var log_rich: RichTextLabel:
	get: return panel.log_rich if panel != null else null

## 滚动容器（代理属性）。
var scroll: ScrollContainer:
	get: return panel.scroll if panel != null else null


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
	collapse_label.focus_mode = Control.FOCUS_ALL
	collapse_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(collapse_label)
	# 开合入口：此前 [signal BaseButton.pressed] 全库无人接线，点下去什么都不发生。
	# 直连 [method toggle]——本组件自己持展开态，不需要外部再转一手。
	collapse_label.pressed.connect(toggle)
	# 展开面板：初始隐藏（默认折叠——AC「日志默认折叠为小标签」）。
	panel = PanelScript.new()
	add_child(panel)


## 设置减少动态。[br]
## [br][b]当前实现[/b]：展开/收起为瞬态 visible 切换（无动画 Tween）——
## 天然满足减少动态（UX「减少动态」= 无动画直跳）。方法保留为接口一致性，
## 供顶层 [CombatTopbar.set_reduce_motion] 统一转发。
func set_reduce_motion(_reduce_motion: bool) -> void:
	pass


## 追加日志条目（渲染管线入口——条目文本由战斗系统组装后传入）。[br]
## [b]与播报组件同源[/b]：生产路径是
## [code]enemy_action_resolved[/code] → [code]EnemyActionBroadcast[/code] →
## 本方法（接线在 [code]CombatLayout.setup_feedback[/code]）——不另造第二套战报。[br]
## [br][param entry_text]: 已组装好的条目文本（[code][回合·阶段] 行动者 → ...[/code]）。
func append_entry(entry_text: String) -> void:
	if entry_text == "":
		return
	_entries.append(entry_text)
	panel.append(entry_text)


## 应用阶段（phase_changed 载荷——AC-2：阶段 2 进入时自动收起）。[br]
## [br][b]只收阶段 2[/b]：敌方行动期间玩家正该读战报，那时收掉面板等于把信息
## 从眼前夺走（AC 的原话是「阶段 2 进入时自动收起」）。
func apply_phase(new_phase: int) -> void:
	if new_phase == 2 and _expanded:
		collapse()


## 切换展开 / 收起（折叠按钮的入口——键盘确认、鼠标点击、手柄 A 都走这里）。
func toggle() -> void:
	if _expanded:
		collapse()
	else:
		expand()


## 展开（渲染态——按钮点击与测试直调共用这一条）。
func expand() -> void:
	if _expanded:
		return
	_expanded = true
	collapse_label.text = LABEL_TEXT_EXPANDED
	panel.open(EMPTY_TEXT)
	expand_changed.emit(true)


## 收起（渲染态）。[br]
## [br][b]顺序不能颠倒：先拉焦点，再隐藏面板[/b]——实测（用例
## [code]test_collapsing_panel_pulls_focus_back_to_button[/code] 首轮变红）：
## 隐藏正在持有焦点的控件时，引擎[b]立即[/b]把焦点释放成空；此后
## [method _pull_focus_back] 读到的焦点持有者是 null，判定「不在面板里」直接返回，
## 紧接着 [signal expand_changed] 触发焦点链重建，链见焦点为空便落默认焦点——
## 玩家看到的是「关一次日志，焦点跳到第一张手牌」。[br]
## [br][b]面板内有关键盘玩家时把焦点拉回来[/b]：阶段 2 会自动收起（AC-2），
## 而此时焦点可能正停在面板的滚动区上——控件一隐藏，焦点就悬在看不见的地方。
func collapse() -> void:
	if not _expanded:
		return
	_pull_focus_back()
	_expanded = false
	panel.close()
	collapse_label.text = LABEL_TEXT
	expand_changed.emit(false)


## 清空日志（战斗结束返回探索后——AC-2 清空条款）。
func clear() -> void:
	_entries.clear()
	panel.clear()


## 是否展开（测试断言用）。
func is_expanded() -> bool:
	return _expanded


## 折叠按钮（焦点链与测试取用——入口的唯一控件）。
func collapse_button() -> Button:
	return collapse_label


## 当前条目列表（测试断言用）。
func get_entries() -> Array[String]:
	return _entries


## 当前滚动位置（测试断言滚底用——转发面板）。
func get_scroll_vertical() -> int:
	return panel.scroll_vertical()


## 请求滚底（转发面板——保留为公开入口，既有引用点用）。
func request_scroll_to_bottom() -> void:
	panel.scroll_to_bottom()


## === 内部 ====================================================================

## 面板收起后把焦点拉回折叠按钮（焦点不在面板内时不动——收起不该抢走别处的焦点）。[br]
## [br][b]先验可落再抓[/b]：整条链停用时（模态面板打开）折叠按钮被置
## [constant Control.FOCUS_NONE]，此时 [method Control.grab_focus] 会被引擎拒绝并
## 打告警——「能不能落」的判据复用焦点环那一份，不在这里另写。
func _pull_focus_back() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var owner: Control = tree.root.gui_get_focus_owner()
	if owner == null or owner == collapse_label:
		return
	if panel == null or not is_instance_valid(panel) or not panel.is_ancestor_of(owner):
		return
	if Ring.inside_tree(collapse_label) and collapse_label.is_visible_in_tree() \
			and collapse_label.focus_mode != Control.FOCUS_NONE:
		collapse_label.grab_focus()
