## ShopScreen 声明面（继承链首段）——[b]1 信号 / 12 常量 / 15 实例字段[/b]。
##
## [b]本层职责[/b]：整条链的[b]共享声明[/b]，[b]不含任何方法[/b]。[br]
##   · 信号 [signal leave_requested]——「离开」的唯一出口。控件树模块
##     （[code]ShopPanelLayout.build[/code]）把按钮的 [signal Button.pressed]
##     转发到这个信号名上（[method Object.emit_signal] 对未声明的信号名不报编译错、
##     只在运行时静默失败），本屏不接受别的名字；[br]
##   · 7 条协作模块常量——控件树 / 游标 / 逻辑层 / 依赖解析 / 模板守望 /
##     SceneManager 枚举真理来源 / 输入消费包装。本屏[b]一个字都不重造[/b]，
##     这七条就是「谁提供什么」的接缝，路径逐字不动；[br]
##   · 5 条面向玩家词条——文案本地化豁免（项目暂无本地化系统），
##     本地化 epic 入库后整体替换为 key（同 S16/S17 口径）；[br]
##   · 15 个实例字段——5 个可注入依赖（集成用例按名 [code]set[/code] 进来）
##     + 3 个运行期状态 + 1 份行映射 + 5 个控件引用（控件树在链尾
##     [method _build_layout] 里搭好，此处只声明）。
##
## [b]本层为什么不放 [method _init][/b]：[method _init] 要调 [method _build_layout]
## （链尾）/ [method _rows_of] 与 [method _activate_row]（访问段）/ [method _request_leave]
## 与 [method _on_focus_changed]（流程段）——把构造留在祖先段会构成「祖先调后代」，
## 解析期即失败（链序推导见链尾段文档「链序不是自由选择」）。
##
## [b]为什么拆出这一层[/b]：原 [code]shop_screen.gd[/code] 415 行，超 300 行软上限
## （.claude/docs/coding-standards.md）。声明面独立成段是既有先例
## （[code]formation_system_contract.gd[/code] / [code]tribulation_system_contract.gd[/code] /
## [code]scene_manager_contract.gd[/code]）。
##
## 来源: ADR-0031 §1/§2、design/ux/deck-editing-ui.md §坊市-买卡、
## 先例 [code]formation_system_contract.gd[/code]。

extends Control

## 玩家点了「离开」（[code]ShopPanelLayout.build[/code] 把「离开」按钮的
## [signal Button.pressed] 转发到这个信号上——本屏必须[b]自己声明[/b]它：
## [method Object.emit_signal] 对未声明的信号名不报编译错、只在运行时静默失败
## （[code]ERR_UNAVAILABLE[/code]），届时按钮点了没反应）。[br]
## [br][b]本屏自己消费这个信号[/b]（见 [method _build_layout]）：唯一的出口是
## [method _request_leave]。若改成「另外把按钮的 pressed 接到出口上」，同一次点击会
## 经两条路各发一次转场请求。
signal leave_requested

## 控件树构建与配色 / 配色与焦点环（探索侧既有模块——本界面一个字都不重造）。
const LayoutScript := preload("res://src/ui/exploration/shop_panel_layout.gd")
## 键盘/手柄游标（纯逻辑，不碰控件树）。
const NavScript := preload("res://src/ui/exploration/shop_panel_navigator.gd")
## 货架与购买结算（Feature 层——本界面只调它的公开方法）。
const LogicScript := preload("res://src/feature/shop/shop_logic.gd")
## 依赖解析（注入优先、否则 Autoload——与卡组编辑同口径）。
const SourcesScript := preload("res://src/ui/hud/deck_view_sources.gd")
## 模板就绪守望（异步装载完成后自己再刷一次——见类文档「模板是异步来的」）。
const WatchScript := preload("res://src/ui/deck_editing/deck_editing_template_watch.gd")
## SceneManager 脚本常量——SceneID / TransitionType 枚举真理来源
## （preload 而非 Autoload 全局名——同 placeholder_scene.gd 口径）。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
## 消费输入的包装（Esc 离开会把自己摘走——见 [method UiInputConsume.mark_handled]）。
const ConsumeScript := preload("res://src/ui/shared/ui_input_consume.gd")

## 标题与提示词条。
const TEXT_TITLE: String = "🏪 坊市"
const TEXT_EMPTY: String = "货架空空——坊市今日无货可售。"
const TEXT_HINT: String = "↑ ↓ 选货，回车买入，Esc 或「离开」返回主菜单。"
const TEXT_LEAVE_HAS_FOCUS: String = "按回车离开坊市。"
## 余额行前缀（面板右上——与探索侧「灵石：N」同措辞，玩家不必学两套）。
const TEXT_BALANCE: String = "灵石：%d"

## 依赖注入（null 时按 /root 找 Autoload——同卡组编辑的回退口径）。[br]
## [br][b]逻辑层也可注入[/b]：测试用「空货架 / 定值余额」的替身构造本界面时，
## 把 [member shop_logic] 先赋好再挂进树即可——[member _logic_] 只在它为 null 时
## 才自建。
var resource_system: Node = null
var card_system: Node = null
var gsm: Node = null
var scene_manager: Node = null
var shop_logic: RefCounted = null
## 已接上「模板装载完成」信号的守望（换了一个卡牌系统则改接新的那一个）。
var _watch: RefCounted = null
## 实际使用的逻辑层（注入优先，否则 [method _ready] 时自建）。
var _logic_: RefCounted = null
## 键盘/手柄游标。
var _navigator: RefCounted = null
## 本次上架的行数（与控件数一致——测试断言用）。
var _item_count: int = 0
## 货架行下标 → 逻辑层货架下标（模板缺失的条目被 [method ShopLogic.rows] 剔除后，
## 屏幕上第 N 行不再是货架第 N 件——故把对应关系单独记一份，购买时按它回传）。
var _row_to_goods: Array[int] = []

var _title_label: Label = null
var _balance_label: Label = null
var _item_box: VBoxContainer = null
var _message_label: Label = null
var _leave_button: Button = null
