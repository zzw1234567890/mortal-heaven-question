extends RefCounted
## IdentityInitializer —— 开局身份初始化子模块（从 identity_selection_system.gd 拆分）。
##
## 持有对 IdentitySelectionSystem 父节点的引用，通过它访问 _get_gsm /
## _get_card_system / _get_deck_editing_system 等方法。
##
## [br]来源: ADR-0022 §apply_identity ⑤⑥ / GDD identity-selection-system.md §3。
## [br]Sprint 9 Story 4：从 identity_selection_system.gd 拆分。

## 父节点引用——IdentitySelectionSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 创建初始卡牌实例——通过 CardSystem.create_instance + DeckEditingSystem.add_cards_to_deck。[br]
## [br][param cards_def] 卡牌定义数组 [{card_id, count}]。[br]
## [br]来源: ADR-0022 §apply_identity ⑤。
func create_initial_cards(cards_def: Array) -> void:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return
	var card_sys: Node = _parent.call("_get_card_system")
	if card_sys == null or not card_sys.has_method("create_instance"):
		return
	var deck_sys: Node = _parent.call("_get_deck_editing_system")

	var card_instance_ids: Array = []
	for card_entry: Dictionary in cards_def:
		var card_id: String = str(card_entry["card_id"])
		var count: int = int(card_entry["count"])
		for _i: int in range(count):
			var inst = card_sys.create_instance(StringName(card_id))
			if inst != null:
				var inst_id: int = inst.get("card_instance_id") if "card_instance_id" in inst else int(inst.card_instance_id)
				# 写入收藏
				if gsm.has_method("add_card_to_collection"):
					var inst_dict: Dictionary = {
						"card_instance_id": inst_id,
						"template_id": card_id,
						"level": 1,
						"inscriptions": [],
						"breakthrough_layers": 0,
						"binding_target_id": &"",
						"acquired_chapter": 0,
						"acquired_event_id": &"",
						"acquired_method": 0,
					}
					gsm.add_card_to_collection(inst_dict)
				card_instance_ids.append(inst_id)

	# 写入 deck.current_deck——通过 DeckEditingSystem.initialize_initial_deck
	if deck_sys != null and deck_sys.has_method("initialize_initial_deck"):
		deck_sys.initialize_initial_deck(card_instance_ids)
		# initialize_initial_deck 已重置 slots，角色位在 ⑥ 中写入


## 创建初始角色实例——写入 deck.slots。[br]
## [br][param char_slots_def] 角色位数组 [{card_id, slot_index}]。[br]
## [br]来源: ADR-0022 §apply_identity ⑥。
func create_initial_characters(char_slots_def: Array) -> void:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return
	var card_sys: Node = _parent.call("_get_card_system")
	if card_sys == null or not card_sys.has_method("create_instance"):
		return

	# 读取当前 slots（initialize_initial_deck 已重置为 [null×6]）
	var slots: Array = gsm.deck.get("slots", [null, null, null, null, null, null]).duplicate()
	for char_entry: Dictionary in char_slots_def:
		var char_id: String = str(char_entry["card_id"])
		var slot_idx: int = int(char_entry["slot_index"])
		var inst = card_sys.create_instance(StringName(char_id))
		if inst != null:
			var inst_id: int = inst.get("card_instance_id") if "card_instance_id" in inst else int(inst.card_instance_id)
			# 写入收藏
			if gsm.has_method("add_card_to_collection"):
				var inst_dict: Dictionary = {
					"card_instance_id": inst_id,
					"template_id": char_id,
					"level": 1,
					"inscriptions": [],
					"breakthrough_layers": 0,
					"binding_target_id": &"",
					"acquired_chapter": 0,
					"acquired_event_id": &"",
					"acquired_method": 0,
				}
				gsm.add_card_to_collection(inst_dict)
			# 写入 slot（slot_index 从 1 开始 → 数组索引 0 开始）
			if slot_idx >= 1 and slot_idx <= slots.size():
				slots[slot_idx - 1] = inst_id

	# 通过 GSM 第二层原子写入 slots
	if gsm.has_method("_set_deck_slots"):
		gsm._set_deck_slots(slots)
