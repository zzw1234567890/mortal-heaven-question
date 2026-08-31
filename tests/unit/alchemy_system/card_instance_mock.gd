extends RefCounted
## CardInstance mock——测试 AlchemySystem.create_instance 返回的卡牌实例替身。[br]
## [br]持有 card_instance_id + template_id 属性。[br]
## [br]来源: ADR-0006 §CardInstance 测试桩。

var card_instance_id: int = 0
var template_id: String = ""