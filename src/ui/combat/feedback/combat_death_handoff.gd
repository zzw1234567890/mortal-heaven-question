extends RefCounted
## CombatDeathHandoff —— 阵亡终态的空位接替（角色卡 → EmptySlotFrame）。[br]
## [br][b]职责[/b]：阵亡动画结束后把「卡节点」换成同尺寸同位置的
## [code]EmptySlotFrame[/code]，并把「已阵亡」戳记文字一并填上。[br]
## [br][b]为什么两件事必须一起做[/b]：只换框不填字，玩家看到的是一格无来由的空位
## ——虚线框的语义是「这里可以补位」，不是「这里原本的人没了」。阵亡动画那 0.5s
## 里卡上还有戳记，动画一结束信息就断了，正是本轮要补的缺口。[br]
## [br][b]为什么独立成文件[/b]：[code]combat_feedback_coordinator.gd[/code] 贴近
## 单文件 300 行软上限（coding-standards），而「接替」是一次性无状态的节点搬运
## （输入卡节点 → 输出空位框），与协调器的信号编排没有交集。[br]
## [br][b]戳记文案单一来源[/b]：取自 [code]CombatCardDefeatMarker.TEXT_DEFEATED[/code]
## ——卡上戳记与空位戳记是同一句话，两处各写一遍必然某天只改一处。[br]
##
## @experimental
## 来源: combat-ui-layout Story 003 AC-4、本轮任务书缺口一（终态没有文字）。

## 卡上戳记的判定与文案（[constant TEXT_DEFEATED] 的持有者）。
const DefeatMarker := preload("res://src/ui/combat/layout/combat_card_defeat_marker.gd")


## 用空位虚线框接替 [param p_card]（同父、同尺寸、同局部坐标）。[br]
## [br][b]返回[/b]：新建的空位框（卡与框无父子关系，调用方负责
## [code]queue_free()[/code] 掉卡）。[br]
## [br][b]父节点为空时[/b]：仍返回一个摆好尺寸的框（不挂树）——调用方拿到的
## 契约恒定，不必先判断卡在不在树上。[br]
## [br][b]坐标口径[/b]：同父下局部坐标等价于卡原位，故在 [code]add_child[/code]
## 之后设置 [code]position[/code]（入树前的 global 换算不可靠——既有实现注记）。
static func replace_with_empty_slot(p_card: Control) -> Control:
	var frame: Control = EmptySlotFrame.new()
	frame.custom_minimum_size = p_card.size
	frame.size = p_card.size
	var parent: Node = p_card.get_parent()
	if parent != null:
		parent.add_child(frame)
		frame.position = p_card.position
		parent.remove_child(p_card)
	# 戳记在框入树、尺寸落定之后填——文字条按 size 居中摆放
	frame.call(&"set_defeat_text", DefeatMarker.TEXT_DEFEATED)
	return frame
