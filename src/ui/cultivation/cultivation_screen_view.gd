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
	if _meditate != null:
		_meditate.text = RulesScript.meditate_line()
	if _breakthrough != null:
		_breakthrough.text = RulesScript.TEXT_BREAKTHROUGH
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
