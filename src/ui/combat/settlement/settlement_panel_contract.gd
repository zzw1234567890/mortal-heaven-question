## SettlementPanel 声明面（继承链首段）——[b]4 个 preload / 5 个信号 / 3 个尺寸常量 / 20 个实例字段[/b]。
##
## [b]本层职责[/b]：整条链的[b]共享声明[/b]——信号出口、面板尺寸与全部可变态字段。[br]
##   · 信号——[code]loot_selected[/code] / [code]loot_confirmed[/code] / [code]loot_skipped[/code] /
##     [code]defeat_confirmed[/code] / [code]closed[/code]：声明落在本层，由链上各段
##     [code]emit[/code]（基段声明的信号可在派生段发射，探针已验证）；[br]
##   · preload——[code]Rules[/code]（判定内核）/ [code]View[/code] / [code]Frame[/code] /
##     [code]Fade[/code]：链上各段都要取，故随声明一起落在链首；[br]
##   · 实例字段——瞬态视觉状态（[member kind] / [member loot_options] / [member selected_index] /
##     [member loot_ready] / [member _elapsed_sec] / [member reduce_motion]）与控件句柄
##     （[member confirm_button] 等，由 [method _build] 填入）。[br]
## [b]本层不含任何方法[/b]：构造在链尾——[method _init] 要调 [method _build]，而 [method _build]
## 按名接线的回调里有 [method _on_loot_delay_timeout]；把构造挪到本层会构成「祖先段引用
## 后代段成员」，GDScript 解析期直接报错（链序由接线方向定死，详见链尾文档）。[br]
##
## [b]为什么拆出这一层[/b]：[code]settlement_panel.gd[/code] 350 行，超 300 行软上限
## （.claude/docs/coding-standards.md）。声明面独立成段是既有先例
## （[code]binding_manager_contract.gd[/code] / [code]combat_system_contract.gd[/code]）。[br]
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  settlement_panel_contract.gd [/code] ← 本层：信号 / 常量 / 实例字段[br]
## [code]  settlement_panel_flows.gd    [/code] ← 面板流程面：两块面板的开启 + 战利品交互[br]
## [code]  settlement_panel.gd          [/code] ← 链尾：装配与出口面（构造 / 关闭 / 查询 / 销毁）[br]
##
## 来源: ADR-0031、design/gdd/combat-ui-system.md §9、combat-ui-layout Story 008
## （AC-1~AC-5/AC-10）、DEBT-CUI-008-3、.claude/docs/coding-standards.md §文件行数限制。

extends Control


const Rules := preload("res://src/ui/combat/shared/settlement_rules.gd")
const View := preload("res://src/ui/combat/settlement/settlement_panel_view.gd")
const Frame := preload("res://src/ui/combat/settlement/settlement_frame.gd")
const Fade := preload("res://src/ui/combat/settlement/settlement_fade.gd")

## === 信号（对外出口——持久写入归 interaction epic）=========================

## 战利品被选中（高亮，非确认）。载荷为选项下标。
signal loot_selected(option_index: int)
## 确认选择战利品（二次确认生效）。载荷为选项下标。
signal loot_confirmed(option_index: int)
## 跳过全部奖励（后续「放弃所有奖励？」二次确认归 interaction epic）。
signal loot_skipped()
## 战败面板确认返回探索。
signal defeat_confirmed()
## 面板已关闭（[method close_panel] 的唯一出口）。[br]
## [br][b]为什么单开这条[/b]：关闭的触发点有四个（确认 / 跳过 / 战败返回 / 汇总视图
## 再确认），而四个业务信号各自只覆盖一部分路径——「关掉之后要做什么」若挂在业务
## 信号上，就得在四处各写一遍。焦点还原（见 [code]CombatFocusMemory[/code]）正是
## 「关掉之后」的事，故由本信号统一承载。[br]
## [br][b]与业务信号同时发[/b]：先发业务信号（上层据此推进结算），再发本信号。
signal closed()

## === 面板尺寸（px——1920×1080 基准，不覆盖全屏）=============================

const PANEL_WIDTH: float = 720.0
const VICTORY_PANEL_HEIGHT: float = 520.0
const DEFEAT_PANEL_HEIGHT: float = 320.0

## === 瞬态视觉状态（§2.1 豁免）=============================================

## 当前面板种类（[SettlementRules.KIND_*]）。
var kind: StringName = Rules.KIND_NONE
## 战利品选项快照（与 [member loot_options] 同序的卡片见 [member _cards]）。
var loot_options: Array = []
## 当前选中下标（-1 = 未选中）。
var selected_index: int = -1
## 是否已过 0.5s 延迟窗口。
var loot_ready: bool = false
## 延迟窗口已走过的秒数（阈值判定唯一入口是 [method SettlementRules.loot_clickable]
## ——本字段只承载「走了多久」，不在面板内重写 0.5s 语义）。
var _elapsed_sec: float = 0.0
## 减少动态偏好（开合动画直跳终态）。
var reduce_motion: bool = false

## === 控件（[method _build] 创建）==========================================

## 0.5s 延迟计时器（一次性——[b]测试相位推进的确定性接缝[/b]：断言前直接
## [code]loot_delay_timer.timeout.emit()[/code] 即可到点，无需真实等待）。
var loot_delay_timer: Timer = null
var title_label: Label = null
var hint_label: Label = null
## 纵向内容容器（标题/提示/网格/摘要/按钮的父级）。
var body_box: VBoxContainer = null
## 战利品网格（多行 HBox——每行 [constant SettlementRules.LOOT_COLUMNS] 张）。
var loot_grid: VBoxContainer = null
var confirm_button: Button = null
var skip_button: Button = null
## 战败摘要正文（与战利品网格互斥显示）。
var defeat_lines_label: Label = null
## 本场奖励汇总（实得 / 未抽到 / 未入库——仅胜利面板显示）。
var reward_lines_label: Label = null
## 选择段标题（「本次奖励：N 选 1」/「这份直接带走」——仅胜利面板且候选非空时显示）。
var pick_title_label: Label = null
## 外框（[SettlementFrame.build] 返回）。
var frame: Control = null

## 战利品卡片列表（与 [member loot_options] 同序）。
var _cards: Array = []
## 控件引用字典（[method SettlementPanelView.build] 返回——字号下发用）。
var _parts: Dictionary = {}
## 开合动画驱动（[SettlementFade] 实例——同一面板重开需 kill 旧 Tween）。
var _fade: SettlementFade = Fade.new()
