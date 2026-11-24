## GSMAtomicWrites 卡组域写入层（继承链第 4 段）——[b]卡组 / 阵位 / 变更日志 / 上限修正 / 散功计数[/b]。
##
## [b]本层职责[/b]：[code]deck.*[/code] 域的五个窄范围写入，全部仅 DeckEditingSystem 调用
## （ADR-0023）。共性口径三条：[br]
##   · [b]窄范围[/b]——每个方法只写自己那一个字段，不碰 deck 域其他字段；[br]
##   · [b]null 守卫[/b]——[code]deck == null[/code] 时 push_warning 并拒绝写入；[br]
##   · [b]去重[/b]——数组字段按 [method GameStateManager._deep_equal] 深层相等判，
##     标量按同值判，避免无意义的 [signal GameStateManager.batch_updated]。
##
## 来源: ADR-0023 §GSM 第二层扩展方法（H-3 修复补充）。

extends "res://src/foundation/gsm/gsm_atomic_writes_collection.gd"


## 原子写入卡组卡牌列表——仅 DeckEditingSystem 调用。[br]
## [br][b]窄范围[/b]：仅写入 deck.current_deck——不操作 deck 域其他字段。[br]
## [br][b]null 守卫[/b]：deck 为 null 时 push_warning 并返回。[br]
## [br][b]去重[/b]：同值（深层相等）不写入。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播。[br]
## [br]来源: ADR-0023 §GSM 第二层扩展方法。
func _set_deck_cards(ids: Array) -> void:
	if _gsm.deck == null:
		push_warning("GSM._set_deck_cards: deck 域为 null，拒绝写入")
		return
	var old: Array = _gsm.deck.get("current_deck", [])
	if _gsm._deep_equal(old, ids):
		return  # 值无变化——去重
	_gsm.deck.current_deck = ids
	_gsm._buffer_change("deck.current_deck", old, ids)


## 原子写入卡组散功计数——仅 DeckEditingSystem 调用。[br]
## [br][b]窄范围[/b]：仅写入 deck.session_remove_count——不操作 deck 域其他字段。[br]
## [br][b]null 守卫[/b]：deck 为 null 时 push_warning 并返回。[br]
## [br][b]去重[/b]：同值不写入。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播。[br]
## [br]来源: ADR-0023 §GSM 第二层扩展方法。
func _set_deck_session_remove_count(count: int) -> void:
	if _gsm.deck == null:
		push_warning("GSM._set_deck_session_remove_count: deck 域为 null，拒绝写入")
		return
	if count < 0:
		push_warning("GSM._set_deck_session_remove_count: count 不能为负（收到 %d）" % count)
		return
	var old_count: int = int(_gsm.deck.get("session_remove_count", 0))
	if old_count == count:
		return  # 值无变化——去重
	_gsm.deck.session_remove_count = count
	_gsm._buffer_change("deck.session_remove_count", old_count, count)


## 原子写入卡组阵位列表——仅 DeckEditingSystem 调用。[br]
## [br][b]窄范围[/b]：仅写入 deck.slots——不操作 deck 域其他字段。[br]
## [br][b]null 守卫[/b]：deck 为 null 时 push_warning 并返回。[br]
## [br][b]去重[/b]：同值（深层相等）不写入。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播。[br]
## [br]来源: ADR-0023 §GSM 第二层扩展方法（H-3 修复补充）。
func _set_deck_slots(slots: Array) -> void:
	if _gsm.deck == null:
		push_warning("GSM._set_deck_slots: deck 域为 null，拒绝写入")
		return
	var old: Array = _gsm.deck.get("slots", [])
	if _gsm._deep_equal(old, slots):
		return  # 值无变化——去重
	_gsm.deck.slots = slots
	_gsm._buffer_change("deck.slots", old, slots)


## 原子写入卡组变更日志——仅 DeckEditingSystem 调用。[br]
## [br][b]窄范围[/b]：仅写入 deck.change_log——不操作 deck 域其他字段。[br]
## [br][b]null 守卫[/b]：deck 为 null 时 push_warning 并返回。[br]
## [br][b]去重[/b]：同值（深层相等）不写入。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播。[br]
## [br]来源: ADR-0023 §GSM 第二层扩展方法（H-3 修复补充）。
func _set_deck_change_log(log: Array) -> void:
	if _gsm.deck == null:
		push_warning("GSM._set_deck_change_log: deck 域为 null，拒绝写入")
		return
	var old: Array = _gsm.deck.get("change_log", [])
	if _gsm._deep_equal(old, log):
		return  # 值无变化——去重
	_gsm.deck.change_log = log
	_gsm._buffer_change("deck.change_log", old, log)


## 原子写入卡组上限修正——仅 DeckEditingSystem 调用。[br]
## [br][b]窄范围[/b]：仅写入 deck.deck_limit_modifier——不操作 deck 域其他字段。[br]
## [br][b]null 守卫[/b]：deck 为 null 时 push_warning 并返回。[br]
## [br][b]去重[/b]：同值不写入。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal GameStateManager.batch_updated] 帧末传播。[br]
## [br]来源: ADR-0023 §GSM 第二层扩展方法（H-3 修复补充）。
func _set_deck_limit_modifier(modifier: int) -> void:
	if _gsm.deck == null:
		push_warning("GSM._set_deck_limit_modifier: deck 域为 null，拒绝写入")
		return
	var old_mod: int = int(_gsm.deck.get("deck_limit_modifier", 0))
	if old_mod == modifier:
		return  # 值无变化——去重
	_gsm.deck.deck_limit_modifier = modifier
	_gsm._buffer_change("deck.deck_limit_modifier", old_mod, modifier)
