class_name EnemyHandBack
extends Control
## EnemyHandBack —— 敌方手牌背面区（combat-ui-layout Story 006）。
##
## [b]职责[/b]：敌方角色区上方小区域显示卡背（仅动画起始位置，不可交互）——
## GDD §2 手牌区边界补充「敌方手牌背面区：卡背小区域」。只渲染卡背占位，
## 抽牌/出牌动画的起始锚点由 feedback 层消费本组件位置。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：无游戏状态——卡背数量为渲染快照
## （[method set_card_back_count]）。[br]
## [br][b]不可交互[/b]：mouse_filter = IGNORE（事件穿透）。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §边界情况（敌方手牌背面区）、
## combat-ui-layout Story 006（AC-7）。

## === 尺寸常量 ================================================================

## 单张卡背宽（px——同手牌缩略卡宽）。
const CARD_BACK_WIDTH: float = 100.0
## 卡背高（px——同手牌缩略卡高）。
const CARD_BACK_HEIGHT: float = 140.0
## 相邻卡背重叠（px——紧凑排列，仅起始位置指示）。
const CARD_BACK_OVERLAP: float = 70.0
## 卡背底色。
const CARD_BACK_BG: Color = Color(0.30, 0.18, 0.38)
## 卡背描边色。
const CARD_BACK_BORDER: Color = Color(0.55, 0.36, 0.68)

## 卡背数量快照。
var _count: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_card_back_count(0)


## 设置卡背数量（渲染快照——敌方手牌数信号驱动）。[br]
## size 随卡背数同步（非容器节点——手动设定尺寸与 custom_minimum_size 一致）。
func set_card_back_count(count: int) -> void:
	_count = maxi(count, 0)
	var total_width: float = CARD_BACK_WIDTH \
			+ CARD_BACK_OVERLAP * float(maxi(_count - 1, 0))
	custom_minimum_size = Vector2(total_width, CARD_BACK_HEIGHT)
	size = Vector2(total_width, CARD_BACK_HEIGHT)
	queue_redraw()


## 获取卡背数量（测试断言用）。
func get_card_back_count() -> int:
	return _count


## 卡背绘制（重叠排列——仅起始位置指示，不可交互）。
func _draw() -> void:
	for i: int in range(_count):
		var x: float = float(i) * CARD_BACK_OVERLAP
		var rect: Rect2 = Rect2(x, 0.0, CARD_BACK_WIDTH, CARD_BACK_HEIGHT)
		draw_rect(rect, CARD_BACK_BG)
		draw_rect(rect, CARD_BACK_BORDER, false, 2.0)
