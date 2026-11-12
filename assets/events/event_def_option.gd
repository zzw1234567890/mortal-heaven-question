class_name EventDefOption
extends Resource
## EventDefOption —— 探索事件的单个可选项。
##
## 每个 [EventDef] 含 2~3 个本资源。玩家选择后，[ExplorationEventSystem] 依次
## 结算 [member effects] 并把 [member result_text] 显示为结果文案。[br]
## [br]来源: 探索事件节点需求（同 EventOption 先例，但剥离条件/权重/连锁）。

# === 文案 =====================================================================

@export_group("文案")
## 选项文本——显示在事件面板按钮上。
@export var text: String = ""

## 结果文案——选完该选项后显示的叙事文本（多行），再关闭面板。
@export_multiline var result_text: String = ""

# === 效果 =====================================================================

@export_group("效果")
## 效果列表——结算时按顺序掷骰并落库 GSM。
## 数组元素类型: EventDefEffect
## NOTE: 裸 Array（同 EventDef.options 先例）。
@export var effects: Array = []
