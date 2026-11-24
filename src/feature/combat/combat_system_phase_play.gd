
## CombatSystem 阶段与出牌层（继承链第 5 段）——[b]阶段推进 + 手动确认 + 三堆牌 + 出牌结算[/b]。
##
## [b]本层职责[/b]：一场战斗内的[b]回合内动作面[/b]。[br]
##   · 阶段推进与八个阶段钩子 → [code]combat_phase_sequencer.gd[/code] /
##     [code]combat_phase_manager.gd[/code]（[method advance_phase] 的 8 步顺序会按名字
##     回调它们，[code]_parent.call(...)[/code]——名字与签名不动）；[br]
##   · Phase 2/3 手动确认入口（[method confirm_end_turn] / [method confirm_attack_targets]）；[br]
##   · 三堆牌（抽牌 / 洗牌 / 弃牌 / 开局发牌 / 读档恢复）→ [code]combat_card_piles.gd[/code]；[br]
##   · 出牌结算 → [code]combat_card_resolver.gd[/code]。[br]
##
## [b]为什么这一层在运行时接缝层之前[/b]：GDScript 的静态调用要求被调方在[b]自身或祖先[/b]段。
## 本层被 [code]combat_phase_manager.gd[/code] / [code]combat_phase_sequencer.gd[/code] /
## [code]combat_card_piles.gd[/code] 等子模块回调，且被 [code]combat_system_runtime.gd[/code]
## 的 [method set_battle_active] 静态回调（阶段起手 [method _enter_phase]）——
## 探针实测：基类静态调用派生类方法是解析期错误（"Function not found in base self"），
## 故本层必须排在运行时接缝层[b]之前[/b]。[br]
##
## 来源: ADR-0008 §7 阶段状态机 §阶段转换验证矩阵 §出牌结算流程 / GDD combat-system.md §1、§2。

extends "res://src/feature/combat/combat_system_lifecycle.gd"


# === 阶段管理 ====================================================================
# 推进与手动确认的实现在 combat_phase_sequencer.gd（advance_phase 的 8 步顺序 /
# Phase 2、3 手动入口 / 两个阶段条件检查）；父节点保留同名薄转发——
# [code]advance_phase[/code] 是 [code]combat_card_resolver.gd[/code] 与
# [code]combat_phase_manager.gd[/code] 按名字回调的父节点接缝，
# [code]_can_afford_any_card[/code] / [code]_all_characters_targeted[/code] 是
# [code]combat_phase_manager.gd[/code] 的验证矩阵输入。
# 阶段入口/出口与八个阶段钩子仍留在下面（它们直接委托既有的 phase_manager 子模块）。

## advance_phase —— 确定性序列推进阶段。委托阶段序列件。（实现见 combat_phase_sequencer.gd）[br]
func advance_phase() -> bool:
	return _get_phase_sequencer().advance_phase()


# 以下八个阶段钩子是 combat_phase_manager.gd 的薄委托，advance_phase 的
# 8 步顺序会按名字回调它们（[code]_parent.call(...)[/code]）；名字与签名不动。

## 计算下一阶段——委托给 combat_phase_manager.gd 子模块（Sprint 9 Story 8 拆分）。
func _compute_next_phase(current: int) -> int:
	return _get_phase_manager().compute_next_phase(current)


## 阶段转换验证矩阵（ADR-0008 §验证矩阵）——委托给子模块。
func _validate_transition(from: int, to: int) -> bool:
	return _get_phase_manager().validate_transition(from, to)


## 阶段入口——按固定顺序调用子系统（ADR-0008 §子系统编排顺序）。委托给子模块。
func _enter_phase(phase: int) -> void:
	_get_phase_manager().enter_phase(phase)


## 阶段出口——清理当前阶段状态。委托给子模块。
func _exit_phase(phase: int) -> void:
	_get_phase_manager().exit_phase(phase)


## 自动阶段调度——委托给子模块。
func _schedule_auto_advance() -> void:
	_get_phase_manager()._schedule_auto_advance()


## 状态效果 tick——委托给子模块。
func _tick_status_effects() -> void:
	_get_phase_manager()._tick_status_effects()


## 重置费用——委托给子模块。
func _reset_cost_for_turn() -> void:
	_get_phase_manager()._reset_cost_for_turn()


## 清除待命状态——委托给子模块。
func _clear_standby_state() -> void:
	_get_phase_manager()._clear_standby_state()


## 执行 AI 回合——委托给子模块。
func _execute_ai_turn() -> void:
	_get_phase_manager()._execute_ai_turn()


## 构建场上状态快照——委托给子模块。
func _build_field_state() -> Dictionary:
	return _get_phase_manager()._build_field_state()


## 获取场上角色列表——委托给子模块。
func _get_field_characters() -> Array:
	return _get_phase_manager()._get_field_characters()


## 计算抽牌数量——委托给子模块。
func _calculate_draw_count() -> int:
	return _get_phase_manager()._calculate_draw_count()

# === 手动确认 API（Phase 2/3 玩家交互入口）========================================

## 玩家确认结束出牌阶段——UI "结束回合"按钮触发。委托阶段序列件。（实现见 combat_phase_sequencer.gd）[br]
func confirm_end_turn() -> bool:
	return _get_phase_sequencer().confirm_end_turn()


## 玩家确认攻击目标——UI "确认攻击"按钮触发。委托阶段序列件。（实现见 combat_phase_sequencer.gd）[br]
func confirm_attack_targets() -> bool:
	return _get_phase_sequencer().confirm_attack_targets()


## 设置 Phase 2 超时标志——计时器到期时调用（AC-011）。委托阶段序列件。
func set_timer_exceeded() -> void:
	_get_phase_sequencer().set_timer_exceeded()


# === 阶段条件检查 ================================================================

## 检查手牌中是否有任何可支付费用的卡牌（AC-006 条件）。委托阶段序列件。（实现见 combat_phase_sequencer.gd）[br]
func _can_afford_any_card() -> bool:
	return _get_phase_sequencer().can_afford_any_card()


## 检查所有可攻击角色是否已分配目标（AC-007/012 空真条件）。委托阶段序列件。（实现见 combat_phase_sequencer.gd）[br]
func _all_characters_targeted() -> bool:
	return _get_phase_sequencer().all_characters_targeted()


# === 抽牌 + 牌库抽空返还（AC-013）================================================
# 实现全部在 combat_card_piles.gd 子模块（抽牌 / 洗牌 / 弃牌 / 开局发牌 / 读档恢复 /
# 三处查询口）；父节点只保留同名薄转发——[code]_draw_cards[/code] 与 [code]discard_card[/code]
# 是 [code]combat_phase_manager.gd[/code] / [code]combat_card_resolver.gd[/code]
# 按名字回调的父节点接缝，其余是同名公开面。

## 从牌库抽 n 张牌到手牌——牌库抽空时从弃牌堆随机返还 1 张到牌库底部。委托子模块。（实现见 combat_card_piles.gd）[br]
func _draw_cards(count: int) -> void:
	_get_piles().draw_cards(count)


## 初始化战斗牌库——接收卡组 ID 列表并洗牌。委托子模块。（实现见 combat_card_piles.gd）[br]
func init_deck(card_ids: Array) -> void:
	_get_piles().init_deck(card_ids)


## 发开局手牌——GDD §2「开局手牌：先手 4 张，后手 5 张」。委托子模块。（实现见 combat_card_piles.gd）[br]
func deal_opening_hand() -> int:
	return _get_piles().deal_opening_hand()


## 先手标志——开战 config 供数（回合经济规则的输入）。委托子模块。
func _is_first_player() -> bool:
	return _get_piles().is_first_player()


## 弃牌——将手牌中的指定卡牌移到弃牌堆。委托子模块。（实现见 combat_card_piles.gd）[br]
func discard_card(card_instance_id: int) -> void:
	_get_piles().discard_card(card_instance_id)


## 洗牌——将弃牌堆全部洗回牌库，弃牌堆清空。委托子模块。
func shuffle_discard_into_deck() -> void:
	_get_piles().shuffle_discard_into_deck()


## 添加卡牌到牌库底部（绑定卡阵亡洗回——BindingManager 回调）。委托子模块。
func add_card_to_deck(card_instance_id: int) -> void:
	_get_piles().add_card_to_deck(card_instance_id)


## 添加卡牌到弃牌堆（绑定卡覆盖进弃牌——BindingManager 回调）。委托子模块。
func add_card_to_discard(card_instance_id: int) -> void:
	_get_piles().add_card_to_discard(card_instance_id)


## 设置牌库/弃牌堆/手牌（[b]deprecated[/b]——测试注入用，生产代码使用 init_deck）。委托子模块。
func set_deck_state(deck: Array, discard: Array, hand: Array) -> void:
	_get_piles().set_deck_state(deck, discard, hand)


## 按存档快照原样恢复三堆牌——读档续战专用（顺序与内容都取存档值）。委托子模块。（实现见 combat_card_piles.gd）[br]
func restore_piles(p_hand: Array, p_draw_pile: Array, p_discard_pile: Array) -> void:
	_get_piles().restore_piles(p_hand, p_draw_pile, p_discard_pile)


## 返回牌库（查询 API）。委托子模块。
func get_deck() -> Array:
	return _get_piles().get_deck()


## 返回弃牌堆（查询 API）。委托子模块。
func get_discard_pile() -> Array:
	return _get_piles().get_discard_pile()


## 返回手牌（查询 API）。委托子模块。
func get_hand() -> Array:
	return _get_piles().get_hand()


# === 出牌结算（Story 003）=======================================================

## 玩家打出卡牌——由 CombatUI 触发（AC-001~007）。[br]
func play_card(card_instance_id: int, target_indices: Array, caster_id: int = -1) -> bool:
	return _get_card_resolver().play_card(card_instance_id, target_indices, caster_id)


## 同 [method play_card]，但返回带拒绝原因与中文提示文本的结果字典。[br]
## [br][b]为什么保留 bool 版本[/b]：AI / 既有调用方只关心成败，改签名会波及一片；
## 两条入口共用同一份结算实现（[code]CombatCardResolver.play_card_detailed[/code]），
## 不会漂移。UI 出牌链路走本方法，以便费用不足时给出提示而不是静默失败。[br]
## [br][b]返回[/b]: [code]{ok, reason, message, context}[/code]——
## [code]reason[/code] 取 [code]CombatPlayResult[/code] 的常量。
func play_card_detailed(card_instance_id: int, target_indices: Array,
		caster_id: int = -1) -> Dictionary:
	return _get_card_resolver().play_card_detailed(
			card_instance_id, target_indices, caster_id)


## 获取卡牌实例——委托给 _card_resolver 子模块。
func _get_card_instance(card_instance_id: int) -> Variant:
	return _get_card_resolver()._get_card_instance(card_instance_id)


## 获取卡牌费用——委托给 _card_resolver 子模块。
func _get_card_cost(card: Variant) -> int:
	return _get_card_resolver()._get_card_cost(card)


## 费用验证——委托给 _card_resolver 子模块。
func _can_afford(cost: int) -> bool:
	return _get_card_resolver()._can_afford(cost)


## 扣费——委托给 _card_resolver 子模块。
func _spend(cost: int) -> void:
	_get_card_resolver()._spend(cost)


## 目标解析——委托给 _card_resolver 子模块。
func _resolve_targets(card: Variant, target_indices: Array) -> Array:
	return _get_card_resolver()._resolve_targets(card, target_indices)


## 目标验证——委托给 _card_resolver 子模块。
func _validate_targets(card: Variant, targets: Array) -> bool:
	return _get_card_resolver()._validate_targets(card, targets)


## 效果结算——委托给 _card_resolver 子模块。
func _resolve_effects(card: Variant, targets: Array) -> Array:
	return _get_card_resolver()._resolve_effects(card, targets)


## 阵亡检查——委托给 _card_resolver 子模块。
func _check_and_process_deaths(results: Array) -> void:
	_get_card_resolver()._check_and_process_deaths(results)


## 从手牌移除已打出的卡牌——委托给 _card_resolver 子模块。
func _remove_card_from_hand(card_instance_id: int) -> void:
	_get_card_resolver()._remove_card_from_hand(card_instance_id)
