extends RefCounted
## CultivationScreenView —— 修炼室的[b]呈现与读取半边[/b]（从 [CultivationScreen] 拆出）。[br]
## [br][b]为什么单独一处[/b]：屏幕脚本要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「把数字写进哪几个 [Label]、按钮该写什么字、
## 提示行显示什么」与「按下去调谁、焦点怎么走」是两件事——同
## [code]cultivation_scene_layout.gd[/code]（控件树）/
## [code]cultivation_scene_input.gd[/code]（导航）/ [code]cultivation_actions.gd[/code]
## （接入）的拆因，本模块补齐第四边。[br]
## [br][b]只持控件引用，不做判断[/b]：可用性、文案、比例全由规则层
## （[code]CultivationViewRules[/code] / 判定层）算出后经 [method present] 传进来——
## 本模块不认识 GSM、不调系统、不自己措辞（零状态所有权，ADR-0031 §2）。[br]
## [br][b]为什么连「读」也在这[/b]：测试口（[method title_text] 等）读的就是这些控件，
## 与写在同一处才不会再冒出第三份控件引用表。[br]
## [br][b]文案本地化豁免[/b]：项目暂无本地化系统——本模块不自己措辞，句子都从
## [code]CultivationViewRules[/code] 的 [code]TEXT_*[/code] 取。[br]
##
## 来源: .claude/rules/ui-code.md（数字由文字承载 + 色盲可读）、ADR-0031 §2/§4、
## 先例 [code]cultivation_scene_layout.gd[/code] / [code]cultivation_scene_input.gd[/code]。

## 文案单点（本模块不自己措辞——初值与降级句子都从这里取）。
const RulesScript := preload("res://src/ui/cultivation/cultivation_view_rules.gd")

var _title: Label = null
var _balance: Label = null
var _realm: Label = null
var _status: Label = null
var _progress: Label = null
var _fill: ColorRect = null
var _message: Label = null
var _meditate: Button = null
var _breakthrough: Button = null
## 越阶渡劫勾选框（GDD §6 主动选项——默认不勾，能不能勾由判定层给）。
var _cross_toggle: CheckButton = null


## 接线——取控件树产物（[code]CultivationSceneLayout.build[/code] 的返回值）。[br]
## [br][b]两个按钮的词条在这里落一次[/b]：控件树不持有面向玩家的措辞，
## 词条单点是 [code]CultivationViewRules[/code]。第二行先按「突破」写一个初值，
## [method present] 会按判定层的结果覆盖成「渡劫」或「突破」
## （进树前就有可读文案，不出现空按钮）。[br]
## [br][b]提示行初值也在这里[/b]：它是「这一屏怎么操作」的常驻说明，与状态无关。
func _init(p_parts: Dictionary) -> void:
	_title = p_parts.get("title_label") as Label
	_balance = p_parts.get("balance_label") as Label
	_realm = p_parts.get("realm_label") as Label
	_status = p_parts.get("status_label") as Label
	_progress = p_parts.get("progress_label") as Label
	_fill = p_parts.get("progress_fill") as ColorRect
	_message = p_parts.get("message_label") as Label
	_meditate = p_parts.get("meditate_button") as Button
	_breakthrough = p_parts.get("breakthrough_button") as Button
	_cross_toggle = p_parts.get("cross_realm_toggle") as CheckButton
	if _meditate != null:
		_meditate.text = RulesScript.meditate_line()
	if _breakthrough != null:
		_breakthrough.text = RulesScript.TEXT_BREAKTHROUGH
	if _cross_toggle != null:
		# 初值「关」——GDD §6 越阶非默认（勾选态由玩家决定，界面不代他选）。
		_cross_toggle.text = RulesScript.cross_realm_line(false)
		# 勾选态一动手就把文案换成对应那一句（两处写「开/关」必然漂移）。
		_cross_toggle.toggled.connect(func(p_pressed: bool) -> void:
			_cross_toggle.text = RulesScript.cross_realm_line(p_pressed))
	show_message(RulesScript.TEXT_HINT)


# ═══════════════════════════════════════════════════════════════════════════════
# 写入
# ═══════════════════════════════════════════════════════════════════════════════

## 上架一份状态（数字与文本全来自规则层——本模块零数值计算、零措辞）。[br]
## [br][param p_status] [code]CultivationActions.status[/code] 的返回值。[br]
## [param p_ling_shi] 当前灵石（只读快照——本模块不查系统）。[br]
## [br][b]两行的文案与可用性都取判定层的结果[/b]：第二行的语义随境界而变
## （渡劫 / 直接突破），第一行也会在到顶时关闭（修为无处可用）——措辞与能不能点必须
## 来自同一处判定，不能在这里用 [code]allows_breakthrough[/code] 另判一道。
func present(p_status: Dictionary, p_ling_shi: int) -> void:
	var current: int = int(p_status.get("current", 0))
	var max_value: int = int(p_status.get("max", 0))
	_balance.text = RulesScript.balance_line(p_ling_shi)
	_realm.text = RulesScript.realm_line(int(p_status.get("realm", 0)))
	_progress.text = RulesScript.progress_line(current, max_value)
	_fill.anchor_right = RulesScript.fill_ratio(current, max_value)
	_status.text = str(p_status.get("status_text", RulesScript.TEXT_UNAVAILABLE))
	_meditate.disabled = not bool(p_status.get("meditate_enabled", true))
	_breakthrough.text = str(p_status.get("button_text", RulesScript.TEXT_BREAKTHROUGH))
	_breakthrough.disabled = not bool(p_status.get("enabled", false))
	_present_cross_realm(p_status)


## 越阶渡劫勾选框的可见性 / 可用性 / 文案。[br]
## [br][b]三态各有各的呈现[/b]：规则允许（该境界需渡劫且 +1 存在）→ 可勾可取消；
## 规则不允许 → 藏起来（到顶前一级、不走渡劫的境界里这一行毫无意义，留着只是噪音）；
## 玩家已经勾上但此刻规则不允许（境界变了）→ 取消勾选，避免把「上一次的选择」
## 带进一个它不成立的场合。[br]
## [br][b]为什么在刷新时收回勾选[/b]：勾选态属于玩家的[b]当下选择[/b]，不是持久偏好——
## 越阶渡劫成功会升境（+1 可能不再可选），那时留着勾就是在替玩家选了下一次的越阶。
func _present_cross_realm(p_status: Dictionary) -> void:
	if _cross_toggle == null:
		return
	var available: bool = bool(p_status.get("cross_realm_available", false))
	_cross_toggle.visible = available
	if not available:
		_cross_toggle.button_pressed = false
		_cross_toggle.text = RulesScript.TEXT_CROSS_REALM_UNAVAILABLE
		return
	_cross_toggle.text = RulesScript.cross_realm_line(_cross_toggle.button_pressed)


## 系统缺失时的降级形态（可读的中文原因 + 唯一可用的出口，不臆造数值）。
func present_unavailable(p_ling_shi: int) -> void:
	_balance.text = RulesScript.balance_line(p_ling_shi)
	_realm.text = RulesScript.realm_line(0)
	_progress.text = RulesScript.progress_line(0, 0)
	_fill.anchor_right = 0.0
	_status.text = RulesScript.TEXT_UNAVAILABLE
	_meditate.disabled = true
	_breakthrough.text = RulesScript.TEXT_BREAKTHROUGH
	_breakthrough.disabled = true
	if _cross_toggle != null:
		_cross_toggle.visible = false
		_cross_toggle.button_pressed = false
	show_message(RulesScript.TEXT_UNAVAILABLE)


## 写提示行（空串即隐藏——不留一条空行占位）。
func show_message(p_text: String) -> void:
	_message.text = p_text
	_message.visible = not p_text.strip_edges().is_empty()


# ═══════════════════════════════════════════════════════════════════════════════
# 读取（测试口——不暴露控件路径）
# ═══════════════════════════════════════════════════════════════════════════════

func title_text() -> String: return _title.text
func balance_text() -> String: return _balance.text
func realm_text() -> String: return _realm.text
func progress_text() -> String: return _progress.text
func status_text() -> String: return _status.text
func meditate_text() -> String: return _meditate.text
func breakthrough_text() -> String: return _breakthrough.text


## 进度条填充比例（0.0-1.0——条是第二通道，文字才是主通道）。
func progress_ratio() -> float: return _fill.anchor_right


## 当前提示行文案（不可见时返回空串）。
func message_text() -> String: return _message.text if _message.visible else ""


## 「打坐」按钮是否可点（到顶时关闭——修为无处可用）。
func is_meditate_enabled() -> bool:
	return _meditate != null and not _meditate.disabled


## 第二动作行是否可点（修为未满 / 已达最高境界 / 渡劫不可用时为 false）。
func is_breakthrough_enabled() -> bool:
	return _breakthrough != null and not _breakthrough.disabled


## 两个按钮本身（屏幕接线与测试投递鼠标事件用——不发 [signal Button.pressed]，
## 只把控件交出去）。
func meditate_button() -> Button: return _meditate
func breakthrough_button() -> Button: return _breakthrough


## 第 [param p_index] 个动作行的控件（测试投递真实鼠标事件用——「点灰行给原因」那条
## 路走的是 [signal Control.gui_input]，只有拿到控件本身才验得了）。
func row_button(p_index: int) -> Button:
	return _meditate if p_index == 0 else _breakthrough


# === 越阶渡劫勾选框 =============================================================

## 勾选框本身（屏幕接线与测试投递真实点击用——不发任何信号，只把控件交出去）。
func cross_realm_toggle() -> CheckButton: return _cross_toggle


## 当前是否勾了越阶（控件缺席时为 false——不臆造玩家的选择）。
func cross_realm_checked() -> bool:
	return _cross_toggle != null and _cross_toggle.button_pressed


## 勾选框此刻是否露出（规则不允许时藏起来——见 [method _present_cross_realm]）。
func cross_realm_visible() -> bool:
	return _cross_toggle != null and _cross_toggle.visible


## 勾选框此刻的文案（控件缺席时为空串）。
func cross_realm_text() -> String:
	return _cross_toggle.text if _cross_toggle != null else ""


## 翻转勾选（测试口——走 [member BaseButton.button_pressed] 而不是改控件内部状态：
## 这个属性的 setter 会发 [signal BaseButton.toggled]，文案换句正挂在那条信号上，
## 绕开属性验到的是一条生产里不存在的路径）。
func toggle_cross_realm() -> void:
	if _cross_toggle != null:
		_cross_toggle.button_pressed = not _cross_toggle.button_pressed
