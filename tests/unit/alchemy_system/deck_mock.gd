extends Node
## DeckEditingSystem mock——测试 AlchemySystem 炼制编排时替换 DeckEditingSystem。[br]
## [br]模拟 add_cards_to_deck 行为：写入 GSM deck.current_deck。[br]
## [br]来源: ADR-0028 §craft_pill ⑥ 写入卡组。

## 记录的 add_cards_to_deck 调用次数。
var _add_calls: int = 0


func add_cards_to_deck(card_ids: Array, source: String, detail: String = "") -> bool:
	_add_calls += 1
	var gsm: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm != null:
		var old_deck: Array = gsm.deck.get("current_deck", [])
		var new_deck: Array = old_deck.duplicate()
		new_deck.append_array(card_ids)
		gsm._set_deck_cards(new_deck)
	return true