class_name RetreatRules
extends RefCounted
## RetreatRules —— 撤退确认与渡劫战前警示 Logic 内核纯函数（combat-ui-layout Story 008）。
##
## [b]职责[/b]：撤退确认双变体（普通/渡劫）与渡劫战前警示的全部判定与文案——
## 标题/正文/警示行/边框色变体 [method retreat_title] / [method retreat_lines]
## / [method retreat_warning_lines] / [method retreat_border_color]、
## 伤亡与绑定卡摘要、战前警示文案 [method pre_battle_body]。[br]
## [br][b]与 [SettlementRules] 的分工[/b]：胜利/战败结算本体在 [SettlementRules]；
## 本文件只管「撤退」与「进战前」两条独立流程（GDD §10）。两文件共享数值常量
## 由 [SettlementRules] 单一持有（[constant SettlementRules.CULTIVATION_LOSS_NORMAL]
## / [constant SettlementRules.CULTIVATION_LOSS_TRIBULATION]），本文件不复制值。[br]
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用、确定映射。[br]
## [br][b]变体切换唯一入口[/b]（AC-7）：[param is_tribulation] 一处开关决定
## 标题/正文/警示/边框四项视觉——面板不做二次判断。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §10 撤退确认（2026-07-24 修订）/
## §边界情况（渡劫战撤退）、combat-ui-layout Story 008（AC-6/AC-7/AC-8/AC-9）。

const Rules := preload("res://src/ui/combat/shared/settlement_rules.gd")

## === 文案常量（GDD §10 线框逐行——本地化豁免）===============================

const TEXT_RETREAT_TITLE: String = "⚠ 确认撤退？"
const TEXT_RETREAT_TITLE_TRIBULATION: String = "⚠ 渡劫战·确认撤退？"
const TEXT_RETREAT_WARNING: String = "畏劫而退，修为散尽"
const TEXT_RETREAT_CONFIRM: String = "确认撤退"
const TEXT_RETREAT_CANCEL: String = "继续战斗"
const TEXT_PRE_BATTLE_TITLE: String = "⚠ 渡劫战"
const TEXT_PRE_BATTLE_BODY: String = "天劫在前，退路将断。确认进战？"
const TEXT_PRE_BATTLE_CONFIRM: String = "确认进战"
const TEXT_PRE_BATTLE_CANCEL: String = "返回"
const TEXT_RETREAT_BUTTON: String = "撤退"

## 撤退按钮是否常驻可点（GDD §10「撤退按钮始终在战斗中可点击」）。[br]
## [br][b]渲染态口径[/b]（GDD 划界补充）：本函数只回答「渲染态是否常驻可点」；
## 实际执行的锁栈仲裁（ANIMATION 阶段排队而非丢弃）归 interaction epic。
static func retreat_button_always_enabled() -> bool:
	return true


## 撤退按钮文案。
static func retreat_button_text() -> String:
	return TEXT_RETREAT_BUTTON


## 撤退修为损失比例（GDD §10：普通 50% / 渡劫 80%）。[br]
## [param is_tribulation]: 是否渡劫战。
static func retreat_cultivation_loss_ratio(is_tribulation: bool) -> float:
	return Rules.CULTIVATION_LOSS_TRIBULATION if is_tribulation \
			else Rules.CULTIVATION_LOSS_NORMAL


## 撤退修为损失百分比（整数——50 / 80）。[br]
## [param is_tribulation]: 是否渡劫战。
static func retreat_cultivation_loss_percent(is_tribulation: bool) -> int:
	return int(round(retreat_cultivation_loss_ratio(is_tribulation) * 100.0))


## 撤退面板标题（渡劫变体带「渡劫战」前缀——与普通撤退一眼可分）。[br]
## [param is_tribulation]: 是否渡劫战。
static func retreat_title(is_tribulation: bool) -> String:
	return TEXT_RETREAT_TITLE_TRIBULATION if is_tribulation else TEXT_RETREAT_TITLE


## 渡劫撤退专属警示行（朱砂红渲染）。[br]
## [br][b]普通撤退返回空数组[/b]——警示文案是渡劫专属（AC-7），不与普通变体混用。[br]
## [param is_tribulation]: 是否渡劫战。
static func retreat_warning_lines(is_tribulation: bool) -> Array:
	if not is_tribulation:
		return []
	return [TEXT_RETREAT_WARNING]


## 撤退后果说明正文行。[br]
## [br][b]普通[/b]（GDD §10 线框）：保留非绑定物品 / 阵亡角色绑定卡失去。[br]
## [b]渡劫[/b]（GDD §10 2026-07-24 修订）：80% 修为损失 / 失去渡劫机会 /
## 绑定卡仍永久失去。[br]
## [br][param is_tribulation]: 是否渡劫战。[br]
## [param binding_card_count]: 已阵亡角色的绑定卡张数（>0 时补具体数字）。
static func retreat_lines(is_tribulation: bool, binding_card_count: int = 0) -> Array:
	var lines: Array = ["撤退视为战败处理："]
	if is_tribulation:
		lines.append("· 损失 %d%% 修为" % retreat_cultivation_loss_percent(true))
		lines.append("· 失去本次渡劫机会（需重新积累修为）")
	else:
		lines.append("· 保留已获得的非绑定物品")
	if binding_card_count > 0:
		lines.append("· 已阵亡角色的绑定卡将失去（%d 张）" % binding_card_count)
	else:
		lines.append("· 已阵亡角色的绑定卡将失去")
	return lines


## 撤退面板边框色——渡劫变体朱砂红（AC-7），普通变体淡墨。[br]
## [param is_tribulation]: 是否渡劫战。
static func retreat_border_color(is_tribulation: bool) -> Color:
	return Rules.COLOR_DANGER if is_tribulation else Rules.COLOR_PANEL_BORDER


## 撤退/警示面板按钮文案。[br]
## [br][b]返回[/b]: [code]{confirm, cancel}[/code]。
static func retreat_button_texts() -> Dictionary:
	return {"confirm": TEXT_RETREAT_CONFIRM, "cancel": TEXT_RETREAT_CANCEL}


## 渡劫战前警示标题。
static func pre_battle_title() -> String:
	return TEXT_PRE_BATTLE_TITLE


## 渡劫战前警示正文（GDD §10 明文文案「天劫在前，退路将断。确认进战？」）。
static func pre_battle_body() -> String:
	return TEXT_PRE_BATTLE_BODY


## 渡劫战前警示按钮文案（GDD §10：确认进战 / 返回）。[br]
## [br][b]返回[/b]: [code]{confirm, cancel}[/code]。
static func pre_battle_button_texts() -> Dictionary:
	return {"confirm": TEXT_PRE_BATTLE_CONFIRM, "cancel": TEXT_PRE_BATTLE_CANCEL}


## 是否需要弹出渡劫战前警示。[br]
## [br][b]仅在渡劫战且尚未确认过时弹[/b]（已确认后同场不再重复弹——避免每次
## 进入备战界面都拦一次）。[br]
## [param is_tribulation]: 是否渡劫战。[br]
## [param already_confirmed]: 玩家是否已在本场确认过进战。
static func should_show_pre_battle_warning(is_tribulation: bool,
		already_confirmed: bool) -> bool:
	return is_tribulation and not already_confirmed
