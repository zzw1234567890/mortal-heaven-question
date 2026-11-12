class_name EventDef
extends Resource
## EventDef —— 探索事件节点资源（修仙题材）。
##
## 存放在 [code]assets/events/<分类>/[/code] 下作为 [code].tres[/code] 文件，
## 由 [ExplorationEventSystem] 按 [member event_id] 加载。[br]
## [br][b]与既有 EventTemplate 的关系[/b]：[code]EventTemplate[/code] 是
## Foundation 层 EventSystem（Autoload #5）的模板资源，承载条件/连锁/加权随机等
## 完整机制；本 [code]EventDef[/code] 是探索节点专用的轻量事件资源——只含
## 标题/正文/选项/结果文案/效果，由探索侧 [ExplorationEventSystem] 直接掷骰落库。[br]
## [br][b]共驻目录[/b]：两类资源同住 [code]assets/events/[/code]——EventSystem 的
## [code]_register_template[/code] 对非 EventTemplate 文件会静默跳过 EventDef
## （不 push_error），避免共驻冲突。[br]
## [br][b]字段[/b]：[member event_id] 全局唯一；[member options] 为
## [EventDefOption] 列表（2~3 个）。[br]
## [br]来源: 探索事件节点需求、ADR-0014 §决策 3（事件节点走 event_node_reached）、
## ADR-0003（事件资源 .tres 模式先例）。

# === 标识 =====================================================================

@export_group("标识")
## 事件 ID——全局唯一，用作加载注册表的键。
## 命名约定：[code]{分类}_{序号}[/code]，例如 [code]"ling_mai_caijue_001"[/code]。
@export var event_id: String = ""

# === 显示文本 =================================================================

@export_group("显示文本")
## 事件标题——显示在事件面板顶部。
@export var title: String = ""

## 事件正文——显示在事件面板正文区域（多行）。
@export_multiline var body: String = ""

# === 选项 =====================================================================

@export_group("选项")
## 选项列表——2~3 个 [EventDefOption]。玩家选其一后结算其 [member EventDefOption.effects]。
## NOTE: 裸 Array 而非 Array[EventDefOption]——GDScript 4.6 class_name 跨文件
## 类型注解受限（同 EventTemplate.options 先例）。
@export var options: Array = []
