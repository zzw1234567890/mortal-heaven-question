## GSMAtomicWrites 收藏域写入层（继承链第 3 段）——[b]卡牌实例 ID / 收藏增删 / 模板校验[/b]。
##
## [b]本层职责[/b]：[code]collection.*[/code] 域的写入与卡牌引用完整性校验。[br]
##   · [method allocate_card_id]——全局唯一卡牌实例 ID 的单调分配者
##     （从 1 起，0 保留为「未分配」哨兵，ADR-0006）；[br]
##   · [method add_card_to_collection] / [method remove_card_from_collection]——收藏增删，
##     受 [member GameStateManager.validation_enabled] 门控；移除侧兼容
##     [code]card_instance_id[/code]（ADR-0006 权威字段）与 [code]instance_id[/code] 两种命名；[br]
##   · [method enable_validation]——一次性开启校验并[b]回溯清洗[/b]开启前写入的脏数据
##     （[method _retroactive_validate_collection]）；[br]
##   · [method _validate_card_ref]——「模板 ID 是否在库」的内聚判据。
##
## [b]为什么这几个住同一层（不能拆开）[/b]：校验链是自洽的——
## [method add_card_to_collection] 与 [method _retroactive_validate_collection] 都调
## [method _validate_card_ref]，[method enable_validation] 又调
## [method _retroactive_validate_collection]。GDScript 解析期要求被调方在本段或[b]祖先[/b]段，
## 故三者必须同段（或让被调方更靠前）。
##
## 来源: ADR-0006 §GSM 集成合约（GSM 是卡牌实例 ID 的全局唯一分配者）/ ADR-0001 §第二层原子写入。

extends "res://src/foundation/gsm/gsm_atomic_writes_player.gd"


## 分配全局唯一的卡牌实例 ID——单调递增。[br]
## [br]由 CardSystem.create_instance() 调用，确保每张卡牌实例拥有全局唯一 ID。[br]
## [br][b]返回[/b]: 下一个未使用的卡牌实例 ID（从 1 开始，0 保留为"未分配"哨兵）。[br]
## [br][b]示例[/b]: [code]var inst_id: int = GameStateManager.allocate_card_id()[/code][br]
## [br]来源: ADR-0006 §GSM 集成合约——GSM 是卡牌实例 ID 的全局唯一分配者。
func allocate_card_id() -> int:
	var allocated: int = _gsm._next_card_instance_id
	_gsm._next_card_instance_id += 1
	return allocated


## 添加卡牌到收藏——仅 CardSystem 调用。[br]
## [br][b]校验跳过模式[/b]：若 [member GameStateManager.validation_enabled] 为 false，拒绝写入并返回 false。[br]
## [br][b]校验开启后[/b]：检查 [param inst_dict] 的 [code]template_id[/code] 是否存在于模板数据库中。
func add_card_to_collection(inst_dict: Dictionary) -> bool:
	if not _gsm.validation_enabled:
		push_warning("GSM.add_card_to_collection: 校验未开启——请先调用 GSM.enable_validation()（由 CardSystem._ready() 执行）")
		return false

	var template_id: String = inst_dict.get("template_id", "")
	if not _validate_card_ref(template_id):
		push_error("GSM.add_card_to_collection: 无效 template_id '%s'" % template_id)
		return false

	var old_cards: Array = _gsm.collection.owned_cards
	var old_count: int = _gsm.collection.total_count

	_gsm.collection.owned_cards.append(inst_dict.duplicate(true))
	_gsm.collection.total_count += 1

	_gsm._buffer_change("collection.owned_cards", old_cards.duplicate(), _gsm.collection.owned_cards)
	_gsm._buffer_change("collection.total_count", old_count, _gsm.collection.total_count)

	var card_id: int = inst_dict.get("card_instance_id", inst_dict.get("instance_id", 0))
	_gsm.card_collection_changed.emit(card_id, &"added")
	return true


## 激活卡牌校验——仅 CardSystem 在一次性的 [method Node._ready] 中调用。[br]
## [br][param card_template_database] 为模板 ID → 模板数据的映射字典。[br]
## [br]重复调用会触发 [method @GDScript.push_warning] 但不覆盖已有数据库。
func enable_validation(card_template_database: Dictionary) -> void:
	if _gsm.validation_enabled:
		push_warning("GSM.enable_validation: 校验已开启——忽略重复调用")
		return

	if card_template_database.is_empty():
		push_error("GSM.enable_validation: 模板数据库为空——校验未开启")
		return

	_gsm._card_template_database = card_template_database
	_gsm.validation_enabled = true
	_gsm.card_validation_ready.emit()

	# 回溯校验：修复校验跳过期间可能已写入的卡牌数据
	_retroactive_validate_collection()


## 校验卡牌模板 ID 是否存在于模板数据库中。
func _validate_card_ref(template_id: String) -> bool:
	if template_id.is_empty():
		return false
	return template_id in _gsm._card_template_database


## 回溯校验——清洗在 enable_validation() 调用前可能被污染的 collection 数据。
func _retroactive_validate_collection() -> void:
	var cards: Array = _gsm.collection.owned_cards
	var removed: int = 0
	var i: int = cards.size() - 1
	while i >= 0:
		var inst: Dictionary = cards[i]
		var tid: String = inst.get("template_id", "")
		if not _validate_card_ref(tid):
			push_warning("GSM._retroactive_validate_collection: 移除无效卡牌实例（template_id='%s'）" % tid)
			cards.remove_at(i)
			removed += 1
		i -= 1
	if removed > 0:
		_gsm.collection.total_count = cards.size()
		push_warning("GSM._retroactive_validate_collection: 共移除 %d 个无效卡牌实例" % removed)


## story_flags 写入——委托给 _narrative_writes 子模块（Sprint 12 Story 012 拆分）。
## 移除卡牌实例——按 card_instance_id 查找并从 collection.owned_cards 移除。[br]
## [br][b]校验跳过模式[/b]：若 [member GameStateManager.validation_enabled] 为 false，拒绝写入并返回 false。[br]
## [br]兼容 [code]card_instance_id[/code]（ADR-0006 权威字段）与 [code]instance_id[/code] 两种字段命名。[br]
## [br][param card_instance_id] 卡牌实例 ID。[br]
## [br][b]返回[/b]: [code]true[/code] 成功移除，[code]false[/code] 未找到或校验未开启。[br]
## [br][b]示例[/b]: [code]var ok := GameStateManager.remove_card_from_collection(42)[/code]
func remove_card_from_collection(card_instance_id: int) -> bool:
	if not _gsm.validation_enabled:
		push_warning("GSM.remove_card_from_collection: 校验未开启——请先调用 GSM.enable_validation()")
		return false

	var cards: Array = _gsm.collection.owned_cards
	var idx_to_remove: int = -1
	for i: int in range(cards.size()):
		var inst: Dictionary = cards[i]
		# 兼容 card_instance_id（ADR-0006 权威）与 instance_id 两种字段命名
		var stored_id: Variant = inst.get("card_instance_id", inst.get("instance_id", -1))
		if stored_id == card_instance_id:
			idx_to_remove = i
			break

	if idx_to_remove == -1:
		push_warning("GSM.remove_card_from_collection: 未找到 card_instance_id=%d" % card_instance_id)
		return false

	var old_cards: Array = _gsm.collection.owned_cards.duplicate()
	var old_count: int = _gsm.collection.total_count

	cards.remove_at(idx_to_remove)
	_gsm.collection.total_count = cards.size()

	_gsm._buffer_change("collection.owned_cards", old_cards, _gsm.collection.owned_cards)
	_gsm._buffer_change("collection.total_count", old_count, _gsm.collection.total_count)

	_gsm.card_collection_changed.emit(card_instance_id, &"removed")
	return true
