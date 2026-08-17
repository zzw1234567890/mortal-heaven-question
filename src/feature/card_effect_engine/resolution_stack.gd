## ResolutionStack —— 栈式结算引擎（优先级队列 + LIFO 出栈 + 中分辨率插入）。
##
## 管理待结算效果的优先级队列，按 5 级主排序键 + 次级决胜键确定性出栈。
## 队列内部始终保持「优先级递增」有序：front = 最低优先级，back = 最高优先级；
## [method pop] 弹出 back（最高优先级），实现「LIFO 出栈 + 优先级排序」的统一语义。
##
## [b]中分辨率插入[/b]（ADR-0009 L133）：效果结算期间新触发（[method push]）的效果
## 按优先级二分插入到尚未结算的队列位置，而非追加到末尾——确保 A→B 的因果关系
## 正确反映在结算顺序中。
##
## [b]不直接写 GSM[/b]：结算执行（_resolve 逻辑）由调用方通过 [method resolve_all] 的
## resolver 回调注入——本类只负责「顺序」，不负责「执行结果写入」。
##
## [b]排序上下文[/b]：先发/阵营/主动出牌等排序键不存储在 [EffectBase] 字段中
## （对象模型属 Story 001 的最小字段集），由调用方通过 [method set_sort_context]
## 按 [member EffectBase.source_card_instance_id] 注入。
##
## 来源: ADR-0009 §栈式结算引擎 / GDD §3 效果结算顺序规则。
class_name ResolutionStack
extends RefCounted


# === 排序上下文（外部注入）========================================================

## 5 级主排序键的层级常量（值越小优先级越高，越先结算）。
## GDD §3：主动出牌(0) > 先发己方(1) > 普通己方(2) > 敌方(3)。
const TIER_ACTIVE_PLAY := 0  ## 玩家主动出牌的效果（当前回合方优先）
const TIER_FIRST_STRIKE := 1  ## 标记「先发」的己方持续效果
const TIER_NORMAL := 2        ## 未标记「先发」的己方持续效果
const TIER_ENEMY := 3         ## 敌方持续效果

## 主动出牌效果的 card_instance_id。值为 -1 表示「无主动出牌」（哨兵）。
var _active_card_id: int = -1

## 先发绑定位集合——[code]{card_instance_id: true}[/code]。
## GDD §3：「先发」是绑定位的可选切换（默认关），同时机内优先于其他己方持续效果。
var _first_strike_card_ids: Dictionary = {}

## 己方卡牌实例集合——[code]{card_instance_id: true}[/code]。
## 用于区分「己方持续效果」与「敌方持续效果」（目标解析对称——视角决定阵营）。
var _player_side_card_ids: Dictionary = {}


# === 待结算队列 ===================================================================

## 待结算队列——始终保持「优先级递增」有序（back = 最高优先级，先出栈）。
var _queue: Array[EffectBase] = []


# === 排序上下文设置 ===============================================================

## 设置排序上下文。[br]
## [br][param active_card_id] 主动出牌效果的 card_instance_id（-1 = 无主动出牌）。[br]
## [br][param first_strike_card_ids] 先发绑定位集合（可选，默认空）。[br]
## [br][param player_side_card_ids] 己方卡牌实例集合（可选，默认空）。
func set_sort_context(
		active_card_id: int = -1,
		first_strike_card_ids: Dictionary = {},
		player_side_card_ids: Dictionary = {}) -> void:
	_active_card_id = active_card_id
	_first_strike_card_ids = first_strike_card_ids
	_player_side_card_ids = player_side_card_ids


## 清空排序上下文——退化到纯字段排序（activation_sequence 降序 → priority 降序 → card_id 升序）。
func clear_sort_context() -> void:
	_active_card_id = -1
	_first_strike_card_ids = {}
	_player_side_card_ids = {}


# === 队列操作 =====================================================================

## 入队——按优先级二分定位插入到正确位置（中分辨率插入）。[br]
## [br][b]复杂度[/b]：定位 O(log n)，[code]Array.insert()[/code] 移位 O(n)——
## 对 100 元素预算无影响，且优于每次插入全量 [code]sort_custom()[/code]（O(n log n)）。[br]
## [br]null 效果静默忽略（防御——不影响既有队列）。
func push(effect: EffectBase) -> void:
	if effect == null:
		return
	var lo := 0
	var hi := _queue.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if _compare(_queue[mid], effect):
			hi = mid
		else:
			lo = mid + 1
	_queue.insert(lo, effect)


## 出栈——弹出优先级最高的效果（back）。空栈返回 null。
func pop() -> EffectBase:
	if _queue.is_empty():
		return null
	return _queue.pop_back()


## 窥视栈顶（优先级最高）——不弹出。空栈返回 null。
func peek() -> EffectBase:
	if _queue.is_empty():
		return null
	return _queue.back()


## 队列是否为空。
func is_empty() -> bool:
	return _queue.is_empty()


## 队列当前长度。
func size() -> int:
	return _queue.size()


## 清空队列（保留排序上下文）。
func clear() -> void:
	_queue.clear()


# === 结算循环 =====================================================================

## 结算全部——循环出栈，对每个效果调用 [param resolver]，直到队列为空。[br]
## [br][b]中分辨率插入[/b]：resolver 回调内可调用 [method push] 注入新效果，
## 新效果按优先级插入尚未结算的队列位置。[br]
## [br][b]触发链检查[/b]（Story 003）：若提供 [param chain_state]，每次出栈按 ADR-0009 L147-158 顺序
## 检查——depth+1 → 深度超限截断 → 循环检测跳过 → 记录 → resolver 结算。
## 截断/跳过均 [code]continue[/code]（不 [code]break[/code]）——剩余队列继续结算。[br]
## [br][param resolver] 结算执行回调（签名 [code]func(effect: EffectBase) -> void[/code]）。[br]
## [br][param chain_state] 触发链追踪状态（可选，[TriggerChainState]）。null = 不启用触发链检查。[br]
## [br][param overflow_handler] 深度超限回调（可选，签名 [code]func(chain_state: TriggerChainState) -> void[/code]）
## ——由调用方（CardEffectEngine）发射 [code]stack_overflow_warning[/code] 信号 + WARN 日志。[br]
## [br][param cycle_skip_handler] 循环跳过回调（可选，签名 [code]func(card_instance_id: int, chain_state: TriggerChainState) -> void[/code]）
## ——由调用方记录 AC-002 要求的 DEBUG 日志。[br]
## [br][b]返回[/b]: 实际结算（通过检查并调用 resolver）的效果总数。
func resolve_all(
		resolver: Callable,
		chain_state: TriggerChainState = null,
		overflow_handler: Callable = Callable(),
		cycle_skip_handler: Callable = Callable()) -> int:
	var count := 0
	while not _queue.is_empty():
		var effect := pop()
		if effect == null:
			break
		if chain_state != null:
			var result := chain_state.check_and_record(effect.source_card_instance_id)
			if result == TriggerChainState.CheckResult.DEPTH_EXCEEDED:
				if overflow_handler.is_valid():
					overflow_handler.call(chain_state)
				continue  # 第 11 层截断——不结算，剩余队列继续
			if result == TriggerChainState.CheckResult.ALREADY_VISITED:
				if cycle_skip_handler.is_valid():
					cycle_skip_handler.call(effect.source_card_instance_id, chain_state)
				continue  # 循环检测——同一 card_instance_id 不重复触发
		count += 1
		if resolver.is_valid():
			resolver.call(effect)
	return count


# === 排序 =========================================================================

## 主排序键——5 级优先级（值越小优先级越高，越先结算）。
## GDD §3：主动出牌(0) > 先发己方(1) > 普通己方(2) > 敌方(3)。
func _sort_tier(effect: EffectBase) -> int:
	var card_id: int = effect.source_card_instance_id
	if _active_card_id != -1 and card_id == _active_card_id:
		return TIER_ACTIVE_PLAY  # 主动出牌效果
	var is_first_strike: bool = _first_strike_card_ids.get(card_id, false)
	var is_player_side: bool = _player_side_card_ids.get(card_id, false)
	if is_player_side:
		return TIER_FIRST_STRIKE if is_first_strike else TIER_NORMAL  # 先发己方 / 普通己方
	return TIER_ENEMY  # 敌方持续效果


## 比较器——返回 [param a] 是否优先级高于 [param b]（应排在 [param b] 前）。[br]
## [br]同主排序层级内次级决胜（GDD §3 / ADR-0009 L122-129）：
##   activation_sequence 降序（新的先）→ priority 降序（大的先）→ card_instance_id 升序。
func _compare(a: EffectBase, b: EffectBase) -> bool:
	var tier_a := _sort_tier(a)
	var tier_b := _sort_tier(b)
	if tier_a != tier_b:
		return tier_a < tier_b
	if a.activation_sequence != b.activation_sequence:
		return a.activation_sequence > b.activation_sequence
	if a.priority != b.priority:
		return a.priority > b.priority
	return a.source_card_instance_id < b.source_card_instance_id
