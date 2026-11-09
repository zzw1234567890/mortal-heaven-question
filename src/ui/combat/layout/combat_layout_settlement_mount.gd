extends RefCounted
## CombatLayoutSettlementMount —— 结算宿主与撤退按钮的装配（combat_layout 拆分模块·结算组）。
##
## [b]职责[/b]：实例化 [code]SettlementHost[/code]（结算 / 撤退 / 渡劫警示三面板的宿主），
## 在右上角按钮位内装配常驻撤退按钮，并把三条入口转发给宿主——
## [method setup]（注入战斗/卡组系统与渡劫标识）、[method show_pre_battle_warning]、
## [method open_retreat_dialog]。[b]不持有游戏状态[/b]：是否渡劫、卡组张数等全部现读。
##
## [b]为什么单独成文件[/b]：[code]combat_layout.gd[/code] 是场景挂载侧唯一持有的节点，
## 四组接线此前挤在同一个类里（465 行）。本模块只负责「结算这一组」，
## 判定与文案仍全部委托 [code]SettlementRules[/code] / [code]RetreatRules[/code]。
##
## 来源: combat-ui-layout Story 008、DEBT-CUI-007-2（combat_layout 拆分）。

## 结算/撤退/渡劫警示宿主脚本（全屏覆盖层，默认隐藏）。
const HostScript: GDScript = preload("res://src/ui/combat/settlement/settlement_host.gd")
## 撤退规则纯函数（按钮渲染态判定与文案）。
const RetreatRulesScript: GDScript = preload("res://src/ui/combat/shared/retreat_rules.gd")

## 撤退按钮文案（GDD §10「撤退按钮始终在战斗中可点击」）。
const TEXT_RETREAT_BUTTON: String = "撤退"
## 按钮尺寸（px——1920×1080 基准）。
const BUTTON_SIZE: Vector2 = Vector2(48, 48)

## 宿主布局根（宿主挂在这里——须排在战场内容之后、手牌区之上）。
var _layout: Control = null
## 结算宿主实例（[method build] 创建）。
var host: Variant = null
## 撤退按钮（右上角常驻，渲染态始终可点）。
var retreat_button: Button = null


## 构造——传入宿主布局根。
func _init(p_layout: Control) -> void:
	_layout = p_layout


## 构建宿主 + 撤退按钮。[br]
## [param p_retreat_slot] 右上角按钮位容器（由主类的区域骨架创建并传入）。
func build(p_retreat_slot: Control) -> void:
	host = HostScript.new()
	host.name = "SettlementHost"
	host.call(&"set_anchors_and_offsets_preset", Control.PRESET_FULL_RECT)
	_layout.add_child(host)
	_build_retreat_button(p_retreat_slot)


## 撤退按钮本体（story 008——渲染态始终可点；点击流转由本模块接到宿主）。
func _build_retreat_button(p_retreat_slot: Control) -> void:
	if p_retreat_slot == null:
		return
	retreat_button = Button.new()
	retreat_button.name = "RetreatButton"
	retreat_button.text = TEXT_RETREAT_BUTTON
	retreat_button.custom_minimum_size = BUTTON_SIZE
	retreat_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 渲染态常驻可点（GDD §10）——disabled 恒 false，锁栈仲裁归 interaction
	retreat_button.disabled = not RetreatRulesScript.retreat_button_always_enabled()
	p_retreat_slot.add_child(retreat_button)
	# 点击转发到结算宿主（未注入依赖前宿主只开空确认弹窗——无副作用）
	retreat_button.pressed.connect(open_retreat_dialog)


## 注入结算宿主依赖（战斗系统 / 卡组系统 / 渡劫标识）。
## [br][b]宿主缺失时[/b]告警并返回——战斗结束 / 撤退面板将不可用，但不把缺依赖变成崩溃。
func setup(p_combat_system: Node, p_deck_system: Node = null,
		p_is_tribulation: bool = false) -> void:
	if host == null:
		push_warning("CombatLayout.setup_settlement: 结算宿主未装配——"
				+ "战斗结束/撤退面板将不可用")
		return
	host.call(&"setup", p_combat_system, p_deck_system, p_is_tribulation)


## 渡劫战前警示（AC-8——备战界面之上弹出）。[br]
## [br][b]返回[/b]: 是否真的弹出了弹窗（非渡劫战、已确认过或宿主缺失时为 false）。
func show_pre_battle_warning() -> bool:
	if host == null:
		push_warning("CombatLayout.show_pre_battle_warning: 结算宿主未装配")
		return false
	return bool(host.call(&"show_pre_battle_warning"))


## 打开撤退确认弹窗（AC-6/AC-7——撤退按钮点击或战斗系统撤退请求触发）。
func open_retreat_dialog() -> void:
	if host != null:
		host.call(&"request_retreat")
