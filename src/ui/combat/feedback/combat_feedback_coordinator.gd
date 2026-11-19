class_name CombatFeedbackCoordinator
extends Control
## CombatFeedbackCoordinator —— 战斗反馈编排器（combat-ui-layout Story 003）。
##
## [b]职责[/b]：消费战斗/上场系统信号，编排角色卡视觉反馈——[br]
##   - AC-1：[code]character_damaged[/code]（缺省回退 [code]attack_resolved[/code]）
##     伤害/治疗入队，结算帧合并为每目标一次 [code]apply_hp(终值)[/code]（内部 kill 重建）[br]
##   - AC-2：[code]standby_cleared[/code] → [code]set_standby(false)[/code]；
##     [code]character_deployed[/code]（新角色）→ [code]set_standby(true)[/code][br]
##   - AC-3：[code]battle_ended[/code] → 全灭短路：取消待处理队列与进行中的
##     阵亡动画，转发结算信号 [code]battle_result_forwarded[/code]（面板归 008）[br]
##   - AC-4：[code]character_died[/code] → 阵亡 0.5s 淡出 → 移除卡 → 空位虚线框；
##     伤害 → 飘字（池化）[br]
## [b]飘字 = 实际扣血[/b]：载荷 [code]damage[/code] 已是落库后的增量（攻击结算为减伤后的
## [code]final_damage[/code]），本编排器不还原原始伤害；[code]damage_reduced[/code] 为真
## 时给飘字「减」角标 + 琥珀色。[br]
## [b]零状态所有权[/b]（ADR-0031 §2）：入队增量为瞬态视觉状态（§2.1 豁免）；游戏数据
## （HP/角色状态）所有权在战斗/上场系统——终值每结算帧从注入的快照 Callable 读取。[br]
## [b]零轮询[/b]：无 [code]_process()[/code]——信号驱动 + 帧边界 [code]call_deferred[/code]
## + 一次性 Tween；[b]依赖注入[/b]：信号源经 [method setup] 注入，HP 终值经 [code]hp_reader_cb[/code]。[br]
## [b]伤害入口优先级[/b]：信号源带 [code]character_damaged[/code] 时只订阅它（覆盖攻击
## 结算与出牌两条来源）；同一次攻击两条信号都会发，同订会让飘字重影。缺省回退旧信号。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md（HP条与视觉反馈 AC、角色阵亡 AC、
## 动画表）、combat-ui-layout Story 003（AC-1~AC-4）。

## 飘字池（预创建——依赖注入可替换）。
var floater_pool: FloaterPool = null
## 减少动态（进场时从设置读取——进场后静态，零轮询）。
var reduce_motion: bool = false

## 阵亡动画时长（秒——GDD 动画表「角色阵亡 0.5s」）。
const DEATH_DURATION_SEC: float = 0.5

## 阵亡终态的空位接替（卡 → 带「已阵亡」戳记的空位虚线框，见该模块类文档）。
const DeathHandoff := preload("res://src/ui/combat/feedback/combat_death_handoff.gd")

## 已转发的战斗结果（-1 = 未结束；AC-3 断言用）。
var forwarded_result: int = -1

## === 瞬态视觉状态（§2.1 豁免）=================================================

## 待结算增量表——[code]{character_id: {delta: int, pending_death: bool}}[/code]；
## 同帧多次伤害合并（每目标一条），结算帧清空。
var _pending_deltas: Dictionary = {}
## 结算帧调度标志（防重复 call_deferred）。
var _flush_scheduled: bool = false
## 角色 ID → 角色卡映射（场景层注册——card_registry 非游戏状态，是 UI 节点表）。
var _cards: Dictionary = {}
## 阵亡动画 Tween 句柄表——[code]{character_id: Tween}[/code]。
var _death_tweens: Dictionary = {}
## 已连接信号源（防重——_connect_once 先例）。
var _connected_sources: Array = []

## HP 终值读取 Callable——签名 [code]func(character_id) -> Dictionary[/code]
## 返回 [code]{current: int, max: int}[/code]（注入，读源系统——零状态所有权）。
var hp_reader_cb: Callable = Callable()

## 结算信号（AC-3 全灭短路转发——结算面板本体归 story 008）。
signal battle_result_forwarded(result: int, rewards: Dictionary)


## 初始化（场景层挂载时调用）。[br]
## [param sources]: 信号源数组——战斗系统 + 上场系统（注入 mock 可测）。[br]
## [param p_floater_pool]: 飘字池（预创建；null 时内部新建）。[br]
## [param p_hp_reader]: HP 终值读取 Callable（结算帧从源系统读取）。[br]
## [param p_reduce_motion]: 减少动态（进场时从设置读取一次）。
func setup(sources: Array, p_floater_pool: FloaterPool,
		p_hp_reader: Callable, p_reduce_motion: bool = false) -> void:
	floater_pool = p_floater_pool if p_floater_pool != null \
			else FloaterPool.new()
	add_child(floater_pool)
	reduce_motion = p_reduce_motion
	floater_pool.set_reduce_motion(p_reduce_motion)
	hp_reader_cb = p_hp_reader
	for source: Node in sources:
		_subscribe(source)


## 注册角色卡（场景层创建卡后注册——character_id → 卡节点表）。[br]
## 卡节点表是 UI 节点索引（非游戏状态副本——ADR-0031 §2 合规）。
func register_card(character_id: int, card: Control) -> void:
	_cards[character_id] = card


## 请求移除注册（战斗结束清理——防悬空引用）。
func unregister_card(character_id: int) -> void:
	_cards.erase(character_id)
	_pending_deltas.erase(character_id)
	_kill_death_tween(character_id)


## === 信号订阅（_connect_once 防重——realm_bar 先例）===========================

func _subscribe(source: Node) -> void:
	if source == null or source in _connected_sources:
		return
	_connected_sources.append(source)
	# 伤害入口：优先 character_damaged（覆盖攻击结算 + 出牌效果两条来源）；
	# 该信号缺失时回退 attack_resolved（旧信号源/测试 mock 的兼容路径）。
	if source.has_signal(&"character_damaged"):
		_connect_once(source, &"character_damaged", _on_character_damaged)
	else:
		_connect_once(source, &"attack_resolved", _on_attack_resolved)
	_connect_once(source, &"character_died", _on_character_died)
	_connect_once(source, &"battle_ended", _on_battle_ended)
	_connect_once(source, &"standby_cleared", _on_standby_cleared)
	_connect_once(source, &"character_deployed", _on_character_deployed)


func _connect_once(source: Node, signal_name: StringName, handler: Callable) -> void:
	if not source.has_signal(signal_name):
		return  # 信号源契约可选——缺失静默跳过（多源注入时各带各的信号）
	var s: Signal = source.get(signal_name)
	if not s.is_connected(handler):
		source.connect(signal_name, handler)


## === AC-1：伤害/治疗入队合并 ===================================================

## character_damaged 处理器——载荷 {character_id, side, damage, is_kill, damage_reduced}
## （战斗侧落库后统一通知；攻击结算与出牌效果两条来源都到这里）。[br]
## [code]damage[/code] 已是减伤后的实际扣血——飘字不改写、不还原。
func _on_character_damaged(damage_data: Dictionary) -> void:
	_enqueue_damage(int(damage_data.get("character_id", -1)),
		int(damage_data.get("damage", 0)),
		bool(damage_data.get("is_kill", false)),
		bool(damage_data.get("damage_reduced", false)))


## attack_resolved 信号处理器——载荷 {attacker_id, target_id, damage, is_kill, damage_reduced}。[br]
## [b]兼容路径[/b]：信号源带 character_damaged 时不会走这里（见 [method _subscribe]）。
## 该信号的 [code]damage[/code] 同为减伤后的最终伤害（见 [method CombatSystem.calculate_damage]）。
func _on_attack_resolved(attack_data: Dictionary) -> void:
	_enqueue_damage(int(attack_data.get("target_id", -1)),
		int(attack_data.get("damage", 0)),
		bool(attack_data.get("is_kill", false)),
		bool(attack_data.get("damage_reduced", false)))


## 伤害入队 + 飘字——增量入队（同帧同目标合并），飘字立即发射
## （飘字不入队——每条伤害的反馈独立）。[br]
## 治疗语义：damage 字段为负（CardEffectEngine 治疗 resolve 结果）。
## 载荷不含治疗标志——以 damage 符号判定种类（飘字方向/颜色）。[br]
## [param reduced]: 该次伤害是否被减伤（只影响飘字样式：琥珀色 + 「减」角标）。
func _enqueue_damage(target_id: int, delta: int, is_kill: bool,
		reduced: bool = false) -> void:
	if target_id < 0 or delta == 0:
		return
	var entry: Dictionary = _pending_deltas.get_or_add(target_id,
		{"delta": 0, "pending_death": false})
	entry["delta"] = int(entry["delta"]) + delta
	if is_kill:
		entry["pending_death"] = true
	_pending_deltas[target_id] = entry
	# 飘字（伤害红下落/治疗绿上浮——池化复用；显示值为实际扣血，非原始伤害）
	if floater_pool != null:
		var card: Control = _cards.get(target_id)
		if card != null:
			# 卡中心（全局坐标）——size 乘缩放（后排 85% 卡视觉中心偏移），
			# 池内换算为局部坐标（H-1 坐标空间修正）
			var origin: Vector2 = card.global_position \
					+ card.size * card.scale * 0.5
			floater_pool.spawn(origin, absi(delta),
				FloaterPool.FloaterKind.HEAL if delta < 0 \
					else FloaterPool.FloaterKind.DAMAGE,
				reduced)
	_schedule_flush()


## 结算帧调度——同帧多次信号仅调度一次（call_deferred 合并）。
func _schedule_flush() -> void:
	if _flush_scheduled:
		return
	_flush_scheduled = true
	_flush_deltas.call_deferred()


## 结算帧——每目标一次 apply_hp(终值)（终值从源系统读取——零状态所有权）。
func _flush_deltas() -> void:
	_flush_scheduled = false
	var entries: Array = _pending_deltas.keys()
	for character_id: int in entries:
		var entry: Dictionary = _pending_deltas[character_id]
		var card: Control = _cards.get(character_id)
		if card != null and hp_reader_cb.is_valid():
			var hp: Dictionary = hp_reader_cb.call(character_id)
			card.apply_hp(int(hp.get("current", 0)), int(hp.get("max", 0)))
		if bool(entry.get("pending_death", false)):
			_play_death(character_id)
	_pending_deltas.clear()


## === AC-2：待命/已行动标记 ====================================================

## standby_cleared 信号处理器——载荷 (character_ids: Array[int])。[br]
## 待命→就绪：[code]set_standby(false)[/code]（沙漏标记消失——story 002 L5）。
## 同帧多次信号最终态生效（幂等赋值——信号天然满足）。
func _on_standby_cleared(character_ids: Array) -> void:
	for character_id: int in character_ids:
		var card: Control = _cards.get(int(character_id))
		if card != null:
			card.set_standby(false)


## character_deployed 信号处理器——新上场角色标记待命
## （载荷 (character_id, slot_index, is_front, deploy_turn)）。
func _on_character_deployed(character_id: int, slot_index: int,
		is_front: bool, deploy_turn: int) -> void:
	var card: Control = _cards.get(character_id)
	if card != null:
		card.set_standby(true)


## 已行动外部入口——deployment 无逐角色 state_changed 信号，已行动（ACTED）
## 由战斗侧阶段信号或调用方驱动：[code]set_acted_state(true)[/code]。
## 调用方持有 FieldState 真源（[code]get_field()[/code] 快照），
## 本编排器仅提供信号→卡入口映射。
func request_acted(character_id: int) -> void:
	var card: Control = _cards.get(character_id)
	if card != null:
		card.set_acted_state(true)


## === AC-3：全灭短路 ===========================================================

## battle_ended 信号处理器——全灭短路（GDD：不逐个播阵亡动画，
## 立即切结算面板）。[br]
## [b]职责边界[/b]：UI 不裁定胜负——转发战斗系统的原始 result（双方同时
## 全灭等裁定归战斗系统）；本编排器取消全部待处理/进行中的视觉动画。
func _on_battle_ended(result: int, rewards: Dictionary) -> void:
	# 短路：清空待结算增量 + 杀死全部阵亡动画（不逐个播）
	_pending_deltas.clear()
	_flush_scheduled = false
	for character_id: int in _death_tweens.keys():
		var dying_card: Control = _cards.get(character_id)
		if dying_card != null:
			dying_card.modulate.a = 1.0  # L-2——中途杀动画恢复不透明（防半透明悬挂）
		_kill_death_tween(character_id)
	forwarded_result = result
	battle_result_forwarded.emit(result, rewards)


## === AC-4：阵亡流程 ===========================================================

## 播放阵亡动画（character_died 信号驱动——0.5s 碎裂淡出 stub → 移除 → 空位框）。[br]
## [b]reduce_motion[/b]：直接移除+显示空位框（瞬时替代——UX 减少动态条款）。[br]
## [b]幂等守卫[/b]：同一角色重复阵亡信号不重播（pending_death 队列 + 信号
## 双路径汇合——GAP 防重入）。
func _on_character_died(character_id: int, side: int,
		binding_card_ids: Array) -> void:
	_play_death(character_id)


## 阵亡动画执行（两条路径汇合：pending_death 结算帧 / character_died 信号）。[br]
## 幂等：已在播或已移除的卡不重播。
func _play_death(character_id: int) -> void:
	if forwarded_result != -1:
		return  # 全灭短路后不再播动画（M-1——结算面板已接管）
	var card: Control = _cards.get(character_id)
	if card == null:
		return
	if _death_tweens.has(character_id):
		return  # 幂等——动画进行中不重播
	if reduce_motion:
		_finish_death(character_id)
		return
	_kill_death_tween(character_id)
	var tween: Tween = create_tween()
	# 碎裂+消散 stub：整体 modulate alpha 淡出 0.5s（美术碎裂素材归后续 story）
	tween.tween_property(card, "modulate:a", 0.0, DEATH_DURATION_SEC)
	tween.tween_callback(_finish_death.bind(character_id))
	_death_tweens[character_id] = tween


## 阵亡动画完成——移除卡节点 + 原位显示带戳记的空位虚线框。[br]
## [br][b]接替动作委托 [code]CombatDeathHandoff[/code][/b]：搬运节点与填「已阵亡」
## 文字是同一件事的两半（框上没有字的终态等于把信息丢掉），收在一处才拆不开。[br]
## [br][b]三层清理的分工[/b]：本方法只摘卡表（[code]_cards[/code]）；
## [code]_pending_deltas[/code] 留给 [method unregister_card]（战斗结束统一清扫），
## 阵亡 Tween 表由 [method _kill_death_tween] 先行摘干净——三者不合并，避免
## 「战斗结束清理」与「单个角色阵亡」两条路径互相误伤。
func _finish_death(character_id: int) -> void:
	_kill_death_tween(character_id)
	var card: Control = _cards.get(character_id)
	if card == null:
		return
	DeathHandoff.replace_with_empty_slot(card)
	_cards.erase(character_id)
	card.queue_free()


## === 内部 ====================================================================

func _kill_death_tween(character_id: int) -> void:
	var tween: Tween = _death_tweens.get(character_id)
	if tween != null and tween.is_valid():
		tween.kill()
	_death_tweens.erase(character_id)
