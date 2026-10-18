class_name CombatFeedbackCoordinator
extends Control
## CombatFeedbackCoordinator —— 战斗反馈编排器（combat-ui-layout Story 003）。
##
## [b]职责[/b]：消费战斗/上场系统信号，编排角色卡视觉反馈——[br]
##   - AC-1：[code]attack_resolved[/code] 伤害/治疗入队，结算帧合并为每目标
##     一次 [code]apply_hp(终值)[/code]（apply_hp 内部 kill 重建单次 Tween）[br]
##   - AC-2：[code]standby_cleared[/code] → [code]set_standby(false)[/code]；
##     [code]character_deployed[/code]（新角色）→ [code]set_standby(true)[/code][br]
##   - AC-3：[code]battle_ended[/code] → 全灭短路：取消待处理队列与进行中的
##     阵亡动画，转发结算信号 [code]battle_result_forwarded[/code]（面板归 008）[br]
##   - AC-4：[code]character_died[/code] → 阵亡 0.5s 淡出 → 移除卡 → 空位虚线框；
##     [code]attack_resolved[/code] 伤害 → 飘字（池化）[br]
## [b]零状态所有权[/b]（ADR-0031 §2）：入队增量与触发器表为瞬态视觉状态
## （§2.1 豁免——待合并的 UI 编排中间态）；游戏数据（HP/角色状态）所有权在
## 战斗/上场系统——终值每结算帧从注入的快照 Callable 读取，不缓存。[br]
## [b]零轮询[/b]：无 [code]_process()[/code]——信号驱动 + 帧边界
## [code]call_deferred[/code]（合并结算用的单帧延迟，非循环轮询）+
## 一次性 Tween。[br]
## [b]依赖注入[/b]：信号源经 [method setup] 注入（测试可接 mock——参照
## realm_bar.setup + _connect_once 防重先例）；HP 终值经
## [code]hp_reader_cb[/code] Callable 注入（零状态所有权——不复制 HP）。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §HP条与视觉反馈 AC/
## §角色阵亡 AC/§动画表、combat-ui-layout Story 003（AC-1~AC-4）。

## 飘字池（预创建——依赖注入可替换）。
var floater_pool: FloaterPool = null
## 减少动态（进场时从设置读取——进场后静态，零轮询）。
var reduce_motion: bool = false

## 阵亡动画时长（秒——GDD 动画表「角色阵亡 0.5s」）。
const DEATH_DURATION_SEC: float = 0.5

## 已转发的战斗结果（-1 = 未结束；AC-3 断言用）。
var forwarded_result: int = -1

## === 瞬态视觉状态（§2.1 豁免）=================================================

## 待结算增量表——[code]{character_id: {delta: int, pending_death: bool}}[/code]。
## 同帧多次 attack_resolved 合并（每目标一条）；结算帧清空。
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
## 阵亡移除回调——签名 [code]func(character_id) -> Node[/code]，返回卡节点
## 供动画播放；实际从容器移除由本编排器在动画完成后执行。
var card_lookup_cb: Callable = Callable()

## 结算信号（AC-3 全灭短路转发——结算面板本体归 story 008）。
signal battle_result_forwarded(result: int, rewards: Dictionary)


## 初始化（场景层挂载时调用）。[br]
## [param sources]: 信号源数组——战斗系统 + 上场系统（注入 mock 可测）。[br]
## [param p_floater_pool]: 飘字池（预创建；null 时内部新建）。[br]
## [param p_hp_reader]: HP 终值读取 Callable（结算帧从源系统读取）。[br]
## [param p_card_lookup]: 角色 ID → 卡节点查找 Callable（阵亡动画定位卡）。[br]
## [param p_reduce_motion]: 减少动态（进场时从设置读取一次）。
func setup(sources: Array, p_floater_pool: FloaterPool,
		p_hp_reader: Callable, p_card_lookup: Callable,
		p_reduce_motion: bool = false) -> void:
	floater_pool = p_floater_pool if p_floater_pool != null \
			else FloaterPool.new()
	add_child(floater_pool)
	reduce_motion = p_reduce_motion
	floater_pool.set_reduce_motion(p_reduce_motion)
	hp_reader_cb = p_hp_reader
	card_lookup_cb = p_card_lookup
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

## attack_resolved 信号处理器——载荷 {attacker_id, target_id, damage, is_kill}。[br]
## 增量入队 + 飘字立即发射（飘字不入队——每条攻击的反馈独立）；
## 结算帧合并到终值（同帧多次攻击同一目标 → 一次 apply_hp）。
func _on_attack_resolved(attack_data: Dictionary) -> void:
	var target_id: int = int(attack_data.get("target_id", -1))
	if target_id < 0:
		return
	# 治疗语义：damage 字段为负（CardEffectEngine 治疗 resolve 结果）。
	# attack_resolved 载荷不含治疗标志——以 damage 符号判定种类（飘字方向/颜色）。
	var delta: int = int(attack_data.get("damage", 0))
	if delta == 0:
		return
	var entry: Dictionary = _pending_deltas.get_or_add(target_id,
		{"delta": 0, "pending_death": false})
	entry["delta"] = int(entry["delta"]) + delta
	if bool(attack_data.get("is_kill", false)):
		entry["pending_death"] = true
	_pending_deltas[target_id] = entry
	# 飘字（伤害红下落/治疗绿上浮——池化复用）
	if floater_pool != null:
		var card: Control = _cards.get(target_id)
		var origin: Vector2 = card.global_position + card.size * 0.5 \
				if card != null else Vector2.ZERO
		floater_pool.spawn(origin, absi(delta),
			FloaterPool.FloaterKind.HEAL if delta < 0 \
				else FloaterPool.FloaterKind.DAMAGE)
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


## 阵亡动画完成——移除卡节点 + 原位显示空位虚线框。
func _finish_death(character_id: int) -> void:
	_kill_death_tween(character_id)
	var card: Control = _cards.get(character_id)
	if card == null:
		return
	# 空位虚线框在卡位置接替（同尺寸同父——阵位语义）
	var frame: Control = EmptySlotFrame.new()
	frame.custom_minimum_size = card.size
	frame.size = card.size
	frame.global_position = card.global_position
	if card.get_parent() != null:
		card.get_parent().add_child(frame)
		card.get_parent().remove_child(card)
	_unregister_card_only(character_id)
	card.queue_free()


## === 内部 ====================================================================

## 从卡表移除（保留 pending_deltas 清理给 unregister_card——内部变体）。
func _unregister_card_only(character_id: int) -> void:
	_cards.erase(character_id)


func _kill_death_tween(character_id: int) -> void:
	var tween: Tween = _death_tweens.get(character_id)
	if tween != null and tween.is_valid():
		tween.kill()
	_death_tweens.erase(character_id)
