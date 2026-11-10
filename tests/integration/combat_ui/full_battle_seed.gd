extends RefCounted
## FullBattleSeed —— 完整战斗用例的卡组 / 角色种子（2026-11-10 验收）。[br]
## [br][b]职责[/b]：用真实 [code]CardSystem.create_instance[/code] 建实例、写进 GSM
## 收藏，并把实例 ID 写进卡组与角色位——模拟「身份初始化已完成」的进入战斗前置。[br]
## [br][b]为什么独立成文件[/b]：GSM/卡牌系统的写入细节是测试基础设施，与战斗编排
## 分开（单文件 300 行软上限）。实例 ID 由系统分配，测试不手写 ID。


## 确保卡牌模板已加载（同步驱动 CardSystem 的异步加载）。[br]
## [br][b]为什么不能只靠 before_all 的 await[/b]：首个用例在 GUT 的
## [code]before_all[/code] 之后立即执行，帧驱动时机不保证模板已就绪——
## 后跑的用例能过、第一个用例拿不到模板，是最难归因的那类「有时过有时不过」。
## 这里按 [code]test_template_assets.gd[/code] 的既有做法手动喂帧。
static func ensure_templates() -> bool:
	if _templates_ready():
		return true
	for _attempt: int in range(3):
		for _frame: int in range(100):
			CardSystem._process(0.016)
			if CardSystem.get("_pending_paths").is_empty():
				break
			OS.delay_msec(10)
		if _templates_ready():
			return true
	return false


static func _templates_ready() -> bool:
	return CardSystem.get_template(&"basic_attack") != null \
			and CardSystem.get_template(&"lin_yuan") != null \
			and CardSystem.get_template(&"su_jian_ming") != null


## 建一张真实卡实例并写入收藏（收藏是 [code]get_template_by_instance_id[/code] 的查询源）。[br]
## [br][b]返回[/b]：卡实例 ID；失败返回 -1（由调用方断言）。
static func make_card(p_template_id: StringName) -> int:
	var inst: Variant = CardSystem.call("create_instance", p_template_id)
	if inst == null:
		return -1
	var cid: int = int(inst.get("card_instance_id"))
	var entry: Dictionary = {
		"card_instance_id": cid, "template_id": str(p_template_id), "level": 1,
		"inscriptions": [], "breakthrough_layers": 0, "binding_target_id": &"",
		"acquired_chapter": 0, "acquired_event_id": &"", "acquired_method": 0,
	}
	# 优先走真实 API；全套件中其它用例可能改过 GSM 的校验模板库（enable_validation
	# 只认第一次注入），此时 API 会拒收并 push_error——先探测再决定，避免红字。
	var db: Variant = GameStateManager.get("_card_template_database")
	var api_ready: bool = bool(GameStateManager.validation_enabled) \
			and db is Dictionary and (db as Dictionary).has(str(p_template_id))
	if not api_ready or not bool(GameStateManager.add_card_to_collection(entry)):
		GameStateManager.collection["owned_cards"].append(entry.duplicate(true))
		GameStateManager.collection["total_count"] = \
				int(GameStateManager.collection.get("total_count", 0)) + 1
	return cid


## 写入卡组与两个角色位。[br]
## [br][param p_character_templates] 两名上场角色的模板 ID。[br]
## [param p_basic_count] 基础攻击张数。[param p_hold_card] 留在手里的 1 费卡。[br]
## [br][b]返回[/b]：[code]{char_ids, deck_ids}[/code]（建卡失败时列表里会出现 -1，
## 调用方据此断言）。
static func seed(p_character_templates: Array, p_basic_count: int,
		p_basic_attack: StringName, p_hold_card: StringName) -> Dictionary:
	var deck_ids: Array = []
	for _i: int in range(p_basic_count):
		deck_ids.append(make_card(p_basic_attack))
	deck_ids.append(make_card(p_hold_card))
	var char_ids: Array = []
	for tid: StringName in p_character_templates:
		char_ids.append(make_card(tid))
	DeckEditingSystem.initialize_initial_deck(deck_ids)
	GameStateManager._set_deck_slots([char_ids[0], char_ids[1], null, null, null, null])
	return {"char_ids": char_ids, "deck_ids": deck_ids}
