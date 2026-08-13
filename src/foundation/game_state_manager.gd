extends Node
## GameStateManager (GSM) —— 游戏运行时单一数据源。
##
## 以 Godot Autoload #1 单例形式存在，在所有场景加载之前初始化。
## 提供三层 API：[br]
##   - 第一层：直接属性读取（零拷贝 O(1) 字典访问）[br]
##   - 第二层：原子写入方法（帧末去重缓冲 → 延迟信号发射）[br]
##   - 第三层：信号订阅（subscribe/unsubscribe API）[br]
## [br]
## 消费者应等待 [signal gsm_initialized] 信号后再读取状态。
## 绝不直接写入 GSM 属性——始终通过第二层原子方法。

## === 境界枚举 ================================================================

## 玩家修炼境界，从炼气到化神共五级。
enum RealmLevel {
	QI_REFINING = 1,           ## 炼气
	FOUNDATION = 2,            ## 筑基
	GOLDEN_CORE = 3,           ## 金丹
	NASCENT_SOUL = 4,          ## 元婴
	SPIRIT_TRANSFORMATION = 5,  ## 化神
}

## === 信号 ====================================================================

## 当 GSM [method _ready] 完成全部域的初始化后发射。消费者应在收到此信号后开始读取状态。
signal gsm_initialized()

## Cat 1：展平的路径变更字典。帧末一次性发射，消费者通过路径前缀过滤。
## [br][b]格式:[/b] [code]{ "player.resources.ling_shi": {"old": 100, "new": 150}, ... }[/code]
signal batch_updated(changes: Dictionary)

## Cat 1：境界变更。[param old_realm] → [param new_realm]。
signal realm_changed(old_realm: int, new_realm: int)

## Cat 1：修为变更。[param delta] 为变化量，[param current] 为当前值，[param max_val] 为上限。
signal cultivation_changed(delta: int, current: int, max_val: int)

## Cat 1：修为已满通知。[param current] 为当前值，[param max_val] 为上限。
signal cultivation_full(current: int, max_val: int)

## Cat 1：资源变更。[param type] 为资源名，[param delta] 为变化量，[param balance] 为当前余额。[br]
## [br][b]balance 语义[/b]：ling_shi 为总余额；ling_cai 为变更品质的单品质余额（非四品质总和）——[br]
## 消费者如需 ling_cai 总和应调用 [method ResourceSystem.get_resource](&"ling_cai")。
signal resource_changed(type: StringName, delta: int, balance: int)

## Cat 1：行动力变更。[param delta] 为变化量，[param current] 为当前值，[param max_val] 为上限。
signal action_points_changed(delta: int, current: int, max_val: int)

## Cat 1：卡组修改。[param card_id] 为卡牌实例 ID，[param action] 为操作类型（"added"/"removed"）。
signal deck_modified(card_id: int, action: StringName)

## Cat 2a：战斗开始（立即发射，不经过缓冲）。
signal battle_started(config: Dictionary)

## Cat 2a：战斗结束（立即发射，不经过缓冲）。
signal battle_ended(result: Dictionary)

## Cat 1：场景变更。[param from_scene] → [param to_scene]。
signal scene_changed(from_scene: StringName, to_scene: StringName)

## Cat 1：卡牌收藏变更。[param card_id] 为卡牌实例 ID，[param action] 为操作类型。
signal card_collection_changed(card_id: int, action: StringName)

## Cat 1：进度重置通知。[param reason] 为重置原因。
signal progression_reset(reason: StringName)

## Cat 1：卡牌校验就绪——CardSystem 调用 enable_validation() 后发射。
signal card_validation_ready()

## === 信号链深度追踪 (ADR-0007) ==============================================

## 当前信号链深度——Cat 2 信号通过 [method _emit_signal_safe] 增减。
## 每帧开始时由 [signal SceneTree.process_frame] 信号重置，防止异常泄漏。
static var _signal_chain_depth: int = 0

## 信号链硬限制——超出时截断并记录错误。
const MAX_SIGNAL_CHAIN_DEPTH: int = 4

## Cat 2 信号安全发射包装器——信号链深度追踪。[br]
## [br][b]用法[/b]: [code]GameStateManager._emit_signal_safe(self, &"my_signal", [arg1, arg2])[/code][br]
## [br]深度超出 [constant MAX_SIGNAL_CHAIN_DEPTH] 时截断并记录 [method @GlobalScope.push_error]。[br]
## [b]注意[/b]: 若信号处理器抛出未捕获异常，深度计数器会泄漏——[method _ready] 通过
## [code]process_frame[/code] 每帧重置来恢复。
static func _emit_signal_safe(target: Object, signal_name: StringName, args: Array) -> void:
	_signal_chain_depth += 1
	if _signal_chain_depth > MAX_SIGNAL_CHAIN_DEPTH:
		push_error("GSM._emit_signal_safe: 信号链深度超出 (%d > %d)。最后信号: %s。已截断。"
				% [_signal_chain_depth, MAX_SIGNAL_CHAIN_DEPTH, signal_name])
		_signal_chain_depth -= 1
		return

	var call_args: Array = [signal_name]
	call_args.append_array(args)
	target.callv("emit_signal", call_args)
	_signal_chain_depth -= 1

## === 内部状态 ================================================================

## 初始化完成标志——消费者在读取前应检查此标志或等待 [signal gsm_initialized]。
var _initialized: bool = false

## 修为上限基准值（炼气期）。境界提升后按公式增长。
const BASE_MAX: int = 1000

## === 信号缓冲层内部状态 ======================================================

## 帧内变更缓冲：键 = 完整路径（如 "player.cultivation"），值 = {old, new}。
var _pending_changes: Dictionary = {}

## 帧末刷新是否已调度——防止重复 call_deferred。
var _flush_scheduled: bool = false

## 信号发射进行中标志——检测递归写入。
var _emitting_in_progress: bool = false

## === 校验跳过模式内部状态 =====================================================

## 卡牌引用完整性校验开关。CardSystem 调用 enable_validation() 前为 false。
var validation_enabled: bool = false

## 卡牌模板数据库——enable_validation() 时注入，用于 add_card_to_collection() 引用完整性校验。
var _card_template_database: Dictionary = {}

## 卡牌实例 ID 分配计数器——单调递增，由 [method allocate_card_id] 推进。[br]
## 初始为 1（0 保留为"未分配"哨兵值，见 CardInstance.card_instance_id 默认值）。[br]
## 来源: ADR-0006 §GSM 集成合约——GSM 作为全局唯一 ID 分配者（跨系统单调递增）。
var _next_card_instance_id: int = 1

## === 第一层：数据域（直接属性读取，O(1) ======================================

## 运行元数据：局ID、随机种子、时间戳。
var meta: Dictionary = {}

## 玩家核心数据：境界、修为、资源、身份、天赋。
var player: Dictionary = {}

## 卡牌收藏：已拥有卡牌列表、总数统计。
var collection: Dictionary = {}

## 当前卡组：角色位、卡组内容、预设列表。
var deck: Dictionary = {}

## 战斗状态——非战斗时始终为 null，战斗中为 Dictionary。
var battle = null

## 探索进度：地图ID、节点位置、行动力、已探索节点、地图完整状态。
var exploration: Dictionary = {}

## 剧情状态：当前章节、已完成章节列表、剧情触发标记。
var narrative: Dictionary = {}

## 会话临时状态（不持久化）：当前场景、UI 暂存状态、输入锁定。
var session: Dictionary = {}

## === 内置虚方法 ==============================================================

func _ready() -> void:
	_init_all_domains()
	_initialized = true
	# ADR-0007: 每帧重置信号链深度——防止异常泄漏导致永久计数器偏移
	get_tree().process_frame.connect(_reset_signal_chain_depth, CONNECT_DEFERRED)
	gsm_initialized.emit()

## 每帧重置信号链深度计数器——防止信号处理器异常逃逸导致持久泄漏。
func _reset_signal_chain_depth() -> void:
	_signal_chain_depth = 0

## === 第一层：通用读取方法 ====================================================

## 以 "." 分隔的路径逐级读取嵌套字典中的值。
func get_state(path: String) -> Variant:
	var keys: PackedStringArray = path.split(".", false)
	var current: Variant = null

	for i: int in range(keys.size()):
		var key: String = keys[i]
		if i == 0:
			current = _get_domain(key)
			if current == null:
				push_warning("GSM.get: 域 '%s' 不存在 (路径: '%s')" % [key, path])
				return null
		else:
			if not current is Dictionary:
				push_warning("GSM.get: 路径 '%s' 在 '%s' 处不是字典类型" % [path, key])
				return null
			if not current.has(key):
				push_warning("GSM.get: 键 '%s' 不存在 (路径: '%s')" % [key, path])
				return null
			current = current[key]

	return current

## === 第二层：原子写入方法 ====================================================

## 修为增加——仅 CultivationSystem 调用。
func add_cultivation(amount: int, source: String = "") -> void:
	if amount <= 0:
		push_error("GSM.add_cultivation: amount 必须为正值（收到: %d, 来源: '%s'）" % [amount, source])
		return

	var old_cultivation: int = player.cultivation
	var old_full: bool = player.cultivation_full
	var old_overflow: int = player.overflow_pool

	var space: int = player.max_cultivation - player.cultivation

	if amount <= space:
		player.cultivation += amount
		_buffer_change("player.cultivation", old_cultivation, player.cultivation)
	else:
		player.cultivation = player.max_cultivation
		var excess: int = amount - space
		player.overflow_pool += excess
		player.cultivation_full = true
		_buffer_change("player.cultivation", old_cultivation, player.cultivation)
		_buffer_change("player.cultivation_full", old_full, true)
		_buffer_change("player.overflow_pool", old_overflow, player.overflow_pool)

## 原子写入灵石——仅 ResourceSystem 调用。[br]
## [br][param value] 新值。[br]
## [br][b]非负守卫[/b]：[code]maxi(0, value)[/code]——即便绕过 ResourceSystem 也防止负数。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal batch_updated] 帧末传播。[br]
## [br]来源: ADR-0019 §GSM 第二层扩展方法。
func _set_resource_ling_shi(value: int) -> void:
	value = maxi(0, value)
	var old_val: int = player.resources.ling_shi
	if old_val == value:
		return
	player.resources.ling_shi = value
	_buffer_change("player.resources.ling_shi", old_val, value)

## 原子写入灵材指定品质——仅 ResourceSystem 调用。[br]
## [br][param quality] 品质（1=low, 2=medium, 3=high, 4=top）。[br]
## [br][param value] 新值。[br]
## [br][b]非负守卫[/b]：[code]maxi(0, value)[/code]——各品质同样防止负数。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal batch_updated] 帧末传播。[br]
## [br]来源: ADR-0019 §GSM 第二层扩展方法。
func _set_resource_ling_cai(quality: int, value: int) -> void:
	if quality < 1 or quality > 4:
		push_error("GSM._set_resource_ling_cai: 无效品质 %d（有效 1-4）" % quality)
		return
	value = maxi(0, value)
	var key: String = ["low", "medium", "high", "top"][quality - 1]
	var old_val: int = player.resources.ling_cai[key]
	if old_val == value:
		return
	player.resources.ling_cai[key] = value
	_buffer_change("player.resources.ling_cai.%s" % key, old_val, value)

## 原子写入战斗费用——仅 CostSystem 调用（从 CombatSystem 委托写入权）。[br]
## [br][b]窄范围[/b]：仅写入 battle.current_cost / battle.max_cost——不操作 battle 域其他字段。[br]
## [br][b]null 守卫[/b]：battle 非活跃时 push_warning 并返回。[br]
## [br][b]去重[/b]：同值不写入，避免无意义 [signal batch_updated]。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal batch_updated] 帧末传播。[br]
## [br]来源: ADR-0015 §GSM 第二层扩展。
func _set_battle_cost(current_cost: int, max_cost: int) -> void:
	if battle == null:
		push_warning("GSM._set_battle_cost: 无活跃战斗，拒绝写入")
		return

	var old_current: int = battle.get("current_cost", 0)
	var old_max: int = battle.get("max_cost", 0)

	if old_current == current_cost and old_max == max_cost:
		return  # 值无变化——去重

	battle.current_cost = current_cost
	battle.max_cost = max_cost

	_buffer_change("battle.current_cost", old_current, current_cost)
	_buffer_change("battle.max_cost", old_max, max_cost)

## 原子写入战斗状态快照——仅 StatusEffectSystem 调用（战斗结束导出）。[br]
## [br][b]窄范围[/b]：仅写入 battle.status_snapshot——不操作 battle 域其他字段。[br]
## [br][b]null 守卫[/b]：battle 非活跃时 push_warning 并返回。[br]
## [br][b]去重[/b]：同值（深层相等）不写入，避免无意义 [signal batch_updated]。[br]
## [br][b]Cat 1 信号[/b]：写入后通过 [signal batch_updated] 帧末传播（展平路径 [code]"battle.status_snapshot"[/code]）。[br]
## [br]来源: ADR-0011 §snapshot 导出 §GSM 例外模式。
func _set_battle_status_snapshot(snapshot: Array) -> void:
	if battle == null:
		push_warning("GSM._set_battle_status_snapshot: 无活跃战斗，拒绝写入")
		return

	var old_snapshot: Array = battle.get("status_snapshot", [])
	if _deep_equal(old_snapshot, snapshot):
		return  # 值无变化——去重

	battle.status_snapshot = snapshot
	_buffer_change("battle.status_snapshot", old_snapshot, snapshot)

## 战斗开始——仅 CombatSystem 调用。Cat 2a 生命周期信号，立即发射不缓冲。
func battle_start(config: Dictionary) -> void:
	if battle != null:
		push_warning("GSM.battle_start: 已有活跃战斗，拒绝重复调用")
		return

	battle = {
		"config": config.duplicate(true),
		"player_snapshot": player.duplicate(true),
		"collection_snapshot": collection.duplicate(true),
		"snapshot_realm": player.realm,
	}

	battle_started.emit(config.duplicate(true))

## 战斗结束——仅 CombatSystem 调用。Cat 2a 生命周期信号，立即发射不缓冲。
func battle_end(result: Dictionary) -> void:
	if battle == null:
		push_warning("GSM.battle_end: 没有活跃战斗，拒绝调用")
		return

	battle = null
	battle_ended.emit(result.duplicate(true))

## 身份设置——仅 IdentitySelectionSystem 调用。
func set_identity(identity_id: StringName) -> void:
	var id_str: String = str(identity_id).strip_edges()
	if id_str.is_empty():
		push_warning("GSM.set_identity: identity_id 为空，拒绝写入")
		return

	var old_val: String = player.identity_id
	if old_val == id_str:
		return  # 值无变化，去重

	_buffer_change("player.identity_id", old_val, id_str)
	if not _set_by_path("player.identity_id", id_str):
		push_error("GSM.set_identity: 写入失败")

## 原子写入境界等级——仅 RealmSystem.realm_up() 调用。[br]
## [br][param new_level] 新境界等级（1-5）。[br]
## [br][b]Cat 1 信号[/b]：写入后发射 [signal realm_changed]，携带 old/new int 载荷。[br]
## [br][b]校验跳过模式[/b]：本方法不受 [member validation_enabled] 影响——境界写入与卡牌校验独立。[br]
## [br]来源: ADR-0001 §三层 API + ADR-0010 §GSM 集成合约。
func change_realm(new_level: int) -> void:
	var old_realm: int = player.realm
	if old_realm == new_level:
		return  # 值无变化，去重
	player.realm = new_level
	_buffer_change("player.realm", old_realm, new_level)
	# realm_changed 由帧末 _emit_domain_signal 统一发射——与 reincarnation_reset/add_cultivation 等
	# 所有第二层方法一致，避免单帧重复发射（Cat 1 信号契约一致性）


## 死亡/轮回结算——仅 CombatSystem/StorySystem 调用。
func reincarnation_reset() -> void:
	# 修为归零
	var old_cult: int = player.cultivation
	player.cultivation = 0
	_buffer_change("player.cultivation", old_cult, 0)

	# 溢出池归零
	var old_overflow: int = player.overflow_pool
	player.overflow_pool = 0
	_buffer_change("player.overflow_pool", old_overflow, 0)

	# cultivation_full 重置
	var old_full: bool = player.cultivation_full
	player.cultivation_full = false
	_buffer_change("player.cultivation_full", old_full, false)

	# 境界重置
	var old_realm: int = player.realm
	player.realm = RealmLevel.QI_REFINING
	_buffer_change("player.realm", old_realm, RealmLevel.QI_REFINING)

	# 资源重置
	var resources: Dictionary = player.resources
	# 灵石重置
	var old_ls: int = resources.ling_shi
	if old_ls != 0:
		resources.ling_shi = 0
		_buffer_change("player.resources.ling_shi", old_ls, 0)
	# 灵材四品质重置
	var lc: Dictionary = resources.ling_cai
	for q_key: String in ["low", "medium", "high", "top"]:
		var old_q: int = lc[q_key]
		if old_q != 0:
			lc[q_key] = 0
			_buffer_change("player.resources.ling_cai.%s" % q_key, old_q, 0)
	# 丹药碎片重置
	var old_dysp: int = resources.dan_yao_sui_pian
	if old_dysp != 0:
		resources.dan_yao_sui_pian = 0
		_buffer_change("player.resources.dan_yao_sui_pian", old_dysp, 0)

	# 重置 max_cultivation 为基准值
	var old_max: int = player.max_cultivation
	player.max_cultivation = BASE_MAX
	_buffer_change("player.max_cultivation", old_max, BASE_MAX)

## 分配全局唯一的卡牌实例 ID——单调递增。[br]
## [br]由 CardSystem.create_instance() 调用，确保每张卡牌实例拥有全局唯一 ID。[br]
## [br][b]返回[/b]: 下一个未使用的卡牌实例 ID（从 1 开始，0 保留为"未分配"哨兵）。[br]
## [br][b]示例[/b]: [code]var inst_id: int = GameStateManager.allocate_card_id()[/code][br]
## [br]来源: ADR-0006 §GSM 集成合约——GSM 是卡牌实例 ID 的全局唯一分配者。
func allocate_card_id() -> int:
	var allocated: int = _next_card_instance_id
	_next_card_instance_id += 1
	return allocated


## 添加卡牌到收藏——仅 CardSystem 调用。
## [br][b]校验跳过模式[/b]：若 [member validation_enabled] 为 false，拒绝写入并返回 false。
## [br][b]校验开启后[/b]：检查 [param inst_dict] 的 [code]template_id[/code] 是否存在于模板数据库中。
func add_card_to_collection(inst_dict: Dictionary) -> bool:
	if not validation_enabled:
		push_warning("GSM.add_card_to_collection: 校验未开启——请先调用 GSM.enable_validation()（由 CardSystem._ready() 执行）")
		return false

	var template_id: String = inst_dict.get("template_id", "")
	if not _validate_card_ref(template_id):
		push_error("GSM.add_card_to_collection: 无效 template_id '%s'" % template_id)
		return false

	var old_cards: Array = collection.owned_cards
	var old_count: int = collection.total_count

	collection.owned_cards.append(inst_dict.duplicate(true))
	collection.total_count += 1

	_buffer_change("collection.owned_cards", old_cards.duplicate(), collection.owned_cards)
	_buffer_change("collection.total_count", old_count, collection.total_count)

	var card_id: int = inst_dict.get("card_instance_id", inst_dict.get("instance_id", 0))
	card_collection_changed.emit(card_id, &"added")
	return true

## 激活卡牌校验——仅 CardSystem 在一次性的 [method Node._ready] 中调用。
## [br][param card_template_database] 为模板 ID → 模板数据的映射字典。
## [br]重复调用会触发 [method @GDScript.push_warning] 但不覆盖已有数据库。
func enable_validation(card_template_database: Dictionary) -> void:
	if validation_enabled:
		push_warning("GSM.enable_validation: 校验已开启——忽略重复调用")
		return

	if card_template_database.is_empty():
		push_error("GSM.enable_validation: 模板数据库为空——校验未开启")
		return

	_card_template_database = card_template_database
	validation_enabled = true
	card_validation_ready.emit()

	# 回溯校验：修复校验跳过期间可能已写入的卡牌数据
	_retroactive_validate_collection()

## 校验卡牌模板 ID 是否存在于模板数据库中。
func _validate_card_ref(template_id: String) -> bool:
	if template_id.is_empty():
		return false
	return template_id in _card_template_database

## 回溯校验——清洗在 enable_validation() 调用前可能被污染的 collection 数据。
func _retroactive_validate_collection() -> void:
	var cards: Array = collection.owned_cards
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
		collection.total_count = cards.size()
		push_warning("GSM._retroactive_validate_collection: 共移除 %d 个无效卡牌实例" % removed)

## 设置输入锁栈——仅 [b]InputManager[/b] 调用。
## [br]写入 [code]session.input_locks[/code] 并通过 [signal batch_updated] 传播变更。
## [param locks] [code]Array[Dictionary][/code]——每个元素 [code]{type: int, source: StringName, device_mask: int}[/code]。
func set_input_locks(locks: Array[Dictionary]) -> void:
	var old: Array = session.input_locks.duplicate(true)
	session.input_locks = locks.duplicate(true)
	_buffer_change("session.input_locks", old, session.input_locks)

## 设置当前场景——仅 [b]SceneManager[/b] 调用（ADR-0005 独占写入授权）。
## [br]写入 [code]session.scene_id[/code] 和 [code]session.current_scene[/code]，
## 通过 [signal batch_updated] 传播 [code]scene_changed[/code]。
func set_session_scene(id: int, path: String) -> void:
	var old_id: int = session.get("scene_id", 0)
	var old_path: String = session.get("current_scene", "")
	session.scene_id = id
	session.current_scene = path
	_buffer_change("session.scene_id", old_id, id)
	_buffer_change("session.current_scene", old_path, path)

## story_flags 写入——仅 [b]EventSystem.set_flag()[/b] 调用（ADR-0003 唯一写入者契约）。[br]
## [br][b]委托链[/b]: EventSystem.set_flag() → 此方法 → [method _buffer_change] → 帧末 [signal batch_updated]。[br]
## [br]相同值重复写入不缓冲变更（去重），减少 SaveLoad 误触发自动存档。[br]
## [br][param flag] flag 键名；[param value] flag 值（Variant——仅接口处使用，不在 Resource @export 中使用）。[br]
## [br][b]示例[/b]: [code]GameStateManager.set_narrative_flag(&"chapter_1", true)[/code]
func set_narrative_flag(flag: StringName, value: Variant) -> void:
	var old: Variant = narrative.story_flags.get(flag, null)
	if old == value:
		return
	narrative.story_flags[flag] = value
	_buffer_change("narrative.story_flags.%s" % flag, old, value)


## 移除卡牌实例——按 card_instance_id 查找并从 collection.owned_cards 移除。[br]
## [br][b]校验跳过模式[/b]：若 [member validation_enabled] 为 false，拒绝写入并返回 false。[br]
## [br]兼容 [code]card_instance_id[/code]（ADR-0006 权威字段）与 [code]instance_id[/code] 两种字段命名。[br]
## [br][param card_instance_id] 卡牌实例 ID。[br]
## [br][b]返回[/b]: [code]true[/code] 成功移除，[code]false[/code] 未找到或校验未开启。[br]
## [br][b]示例[/b]: [code]var ok := GameStateManager.remove_card_from_collection(42)[/code]
func remove_card_from_collection(card_instance_id: int) -> bool:
	if not validation_enabled:
		push_warning("GSM.remove_card_from_collection: 校验未开启——请先调用 GSM.enable_validation()")
		return false

	var cards: Array = collection.owned_cards
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

	var old_cards: Array = collection.owned_cards.duplicate()
	var old_count: int = collection.total_count

	cards.remove_at(idx_to_remove)
	collection.total_count = cards.size()

	_buffer_change("collection.owned_cards", old_cards, collection.owned_cards)
	_buffer_change("collection.total_count", old_count, collection.total_count)

	card_collection_changed.emit(card_instance_id, &"removed")
	return true


## 恢复行动力——写入 exploration.action_points。[br]
## [br]行动力属探索系统（ADR-0014），AP 上限由 ExplorationSystem 管理——本方法不 clamp。[br]
## [br][param amount] 恢复量（必须为正值）。[br]
## [br][b]示例[/b]: [code]GameStateManager.restore_action_points(2)[/code]
func restore_action_points(amount: int) -> void:
	if amount <= 0:
		push_error("GSM.restore_action_points: amount 必须为正值（收到: %d）" % amount)
		return

	var old_val: int = exploration.action_points
	exploration.action_points = old_val + amount
	_buffer_change("exploration.action_points", old_val, exploration.action_points)


## 解锁天赋——写入 player.talents（去重 append）。[br]
## [br][param talent_id] 天赋 ID。[br]
## [br][b]示例[/b]: [code]GameStateManager.unlock_talent(&"talent_003")[/code]
func unlock_talent(talent_id: StringName) -> void:
	var talents: Array = player.talents
	if talents.has(talent_id):
		return  # 已拥有——去重

	var old_talents: Array = talents.duplicate()
	talents.append(talent_id)
	_buffer_change("player.talents", old_talents, talents)


## 推进章节——写入 narrative.current_chapter + completed_chapters。[br]
## [br]若 [code]narrative.current_chapter[/code] 非空且与新章节不同，将旧章节 append 到 [code]completed_chapters[/code]。[br]
## [br][param chapter_id] 新章节 ID。[br]
## [br][b]示例[/b]: [code]GameStateManager.advance_chapter(&"chapter_2")[/code]
func advance_chapter(chapter_id: StringName) -> void:
	var chapter_str: String = str(chapter_id)
	if chapter_str.is_empty():
		push_warning("GSM.advance_chapter: chapter_id 为空，拒绝写入")
		return

	var old_current: String = narrative.current_chapter
	if old_current == chapter_str:
		return  # 相同章节——去重

	var old_completed: Array = narrative.completed_chapters.duplicate()
	if not old_current.is_empty():
		narrative.completed_chapters.append(old_current)

	narrative.current_chapter = chapter_str
	_buffer_change("narrative.current_chapter", old_current, chapter_str)
	_buffer_change("narrative.completed_chapters", old_completed, narrative.completed_chapters)


## === 第三层：信号订阅 API ====================================================

## 有效信号名列表——subscribe/unsubscribe 的白名单。
const VALID_SIGNALS: PackedStringArray = [
	"gsm_initialized", "realm_changed", "cultivation_changed",
	"cultivation_full", "resource_changed", "action_points_changed",
	"deck_modified", "battle_started", "battle_ended", "scene_changed",
	"card_collection_changed", "progression_reset", "batch_updated",
	"card_validation_ready",
]

## 订阅指定 GSM 信号。
## [br][param event_name] 必须存在于 [constant VALID_SIGNALS] 列表中，无效时 [method @GDScript.push_error]。
## [param callback] 信号发射时调用的 [Callable]。
func subscribe(event_name: StringName, callback: Callable) -> void:
	match event_name:
		&"gsm_initialized": gsm_initialized.connect(callback)
		&"realm_changed": realm_changed.connect(callback)
		&"cultivation_changed": cultivation_changed.connect(callback)
		&"cultivation_full": cultivation_full.connect(callback)
		&"resource_changed": resource_changed.connect(callback)
		&"action_points_changed": action_points_changed.connect(callback)
		&"deck_modified": deck_modified.connect(callback)
		&"battle_started": battle_started.connect(callback)
		&"battle_ended": battle_ended.connect(callback)
		&"scene_changed": scene_changed.connect(callback)
		&"card_collection_changed": card_collection_changed.connect(callback)
		&"progression_reset": progression_reset.connect(callback)
		&"batch_updated": batch_updated.connect(callback)
		&"card_validation_ready": card_validation_ready.connect(callback)
		_:
			push_error("GSM.subscribe: 无效信号名 '%s'" % event_name)

## 取消订阅指定 GSM 信号。未找到或未连接时不报错（安全取消）。
func unsubscribe(event_name: StringName, callback: Callable) -> void:
	match event_name:
		&"gsm_initialized":
			if gsm_initialized.is_connected(callback): gsm_initialized.disconnect(callback)
		&"realm_changed":
			if realm_changed.is_connected(callback): realm_changed.disconnect(callback)
		&"cultivation_changed":
			if cultivation_changed.is_connected(callback): cultivation_changed.disconnect(callback)
		&"cultivation_full":
			if cultivation_full.is_connected(callback): cultivation_full.disconnect(callback)
		&"resource_changed":
			if resource_changed.is_connected(callback): resource_changed.disconnect(callback)
		&"action_points_changed":
			if action_points_changed.is_connected(callback): action_points_changed.disconnect(callback)
		&"deck_modified":
			if deck_modified.is_connected(callback): deck_modified.disconnect(callback)
		&"battle_started":
			if battle_started.is_connected(callback): battle_started.disconnect(callback)
		&"battle_ended":
			if battle_ended.is_connected(callback): battle_ended.disconnect(callback)
		&"scene_changed":
			if scene_changed.is_connected(callback): scene_changed.disconnect(callback)
		&"card_collection_changed":
			if card_collection_changed.is_connected(callback): card_collection_changed.disconnect(callback)
		&"progression_reset":
			if progression_reset.is_connected(callback): progression_reset.disconnect(callback)
		&"batch_updated":
			if batch_updated.is_connected(callback): batch_updated.disconnect(callback)
		&"card_validation_ready":
			if card_validation_ready.is_connected(callback): card_validation_ready.disconnect(callback)
		_:  # 未知信号名——静默忽略
			pass

## === 第一层数据域初始化 ======================================================

func _init_all_domains() -> void:
	meta = {
		"game_id": "",
		"seed": 0,
		"timestamp": 0,
	}

	player = {
		"realm": RealmLevel.QI_REFINING,
		"cultivation": 0,
		"max_cultivation": BASE_MAX,
		"cultivation_full": false,
		"overflow_pool": 0,
		"resources": {
			"ling_shi": 0,
			"ling_cai": {"low": 0, "medium": 0, "high": 0, "top": 0},
			"dan_yao_sui_pian": 0,
		},
		"identity_id": "",
		"talents": [],
	}

	collection = {
		"owned_cards": [],
		"total_count": 0,
	}

	deck = {
		"character_slots": [null, null, null, null, null, null],
		"current_deck": [],
		"presets": [],
	}

	battle = null

	exploration = {
		"current_map_id": "",
		"node_position": 0,
		"action_points": 0,
		"revealed_nodes": [],
		"map_state": {},
	}

	narrative = {
		"current_chapter": "",
		"completed_chapters": [],
		"story_flags": {},
	}

	session = {
		"current_scene": "",
		"scene_id": 0,
		"ui_state": {},
		"input_locks": [],
	}

## === 私有辅助方法 ============================================================

## 将域名字符串映射到对应的属性引用。
func _get_domain(domain_name: String) -> Variant:
	match domain_name:
		"meta":        return meta
		"player":      return player
		"collection":  return collection
		"deck":        return deck
		"battle":      return battle
		"exploration": return exploration
		"narrative":   return narrative
		"session":     return session
		_:             return null

## === 信号缓冲层私有方法 ======================================================

## 将单一路径变更写入帧内缓冲，并调度帧末刷新。
## 同路径多次写入：保留首次 old，更新末次 new。
func _buffer_change(path: String, old_val: Variant, new_val: Variant) -> void:
	if _emitting_in_progress:
		push_warning("GSM: 递归写入检测——在信号回调中再次写入 %s" % path)
	if _pending_changes.has(path):
		_pending_changes[path]["new"] = new_val
	else:
		_pending_changes[path] = {"old": old_val, "new": new_val}
	_schedule_flush()

## 调度帧末刷新——同一帧多次调用只排一次 call_deferred。
func _schedule_flush() -> void:
	if not _flush_scheduled:
		_flush_scheduled = true
		call_deferred("_do_flush")

## call_deferred 入口——重置调度标志并执行刷新。
func _do_flush() -> void:
	_flush_scheduled = false
	_flush_pending_changes()

## 帧末刷新所有缓冲的变更：发射域信号 + batch_updated。
func _flush_pending_changes() -> void:
	if _pending_changes.is_empty():
		return
	_emitting_in_progress = true

	var changes: Dictionary = _pending_changes.duplicate(true)
	_pending_changes.clear()

	# 单条变更 → 发射对应域信号；多条变更 → 仅 batch_updated
	if changes.size() == 1:
		var path: String = changes.keys()[0]
		var data: Dictionary = changes[path]
		_emit_domain_signal(path, data)

	# batch_updated 始终发射——消费者也可通过路径前缀过滤
	batch_updated.emit(changes)
	_emitting_in_progress = false

## 根据路径自动路由到对应域信号。
func _emit_domain_signal(path: String, data: Dictionary) -> void:
	var old_val: Variant = data["old"]
	var new_val: Variant = data["new"]
	var delta: int = new_val - old_val if (old_val is int and new_val is int) else 0

	if path == "player.realm":
		realm_changed.emit(old_val, new_val)
	elif path == "player.cultivation":
		cultivation_changed.emit(delta, new_val, player.max_cultivation)
	elif path == "player.cultivation_full":
		if new_val == true:
			cultivation_full.emit(new_val, player.max_cultivation)
	elif path.begins_with("player.resources."):
		var res_type: StringName = StringName(path.get_slice(".", 2))
		resource_changed.emit(res_type, delta, new_val)
	elif path == "exploration.action_points":
		# max_val=0：AP 上限由 ExplorationSystem 管理（ADR-0014），GSM 不跟踪
		action_points_changed.emit(delta, new_val, 0)

## 通过 "." 分隔路径写入嵌套字典中的值（无声，不发射信号）。
func _set_by_path(path: String, value: Variant) -> bool:
	var keys: PackedStringArray = path.split(".", false)
	if keys.size() < 2:
		push_error("GSM._set_by_path: 路径至少需要两级（域.键），收到: '%s'" % path)
		return false

	var current: Variant = _get_domain(keys[0])
	if current == null:
		push_error("GSM._set_by_path: 域 '%s' 不存在（路径: '%s'）" % [keys[0], path])
		return false

	for i: int in range(1, keys.size() - 1):
		var key: String = keys[i]
		if not current is Dictionary:
			push_error("GSM._set_by_path: 路径 '%s' 在 '%s' 处不是字典类型" % [path, key])
			return false
		if not current.has(key):
			push_error("GSM._set_by_path: 键 '%s' 不存在（路径: '%s'）" % [key, path])
			return false
		current = current[key]

	var last_key: String = keys[keys.size() - 1]
	if not current is Dictionary:
		push_error("GSM._set_by_path: 路径 '%s' 的目标容器不是字典类型" % path)
		return false
	current[last_key] = value
	return true

## 已废弃——由 [method _buffer_change] + [method _schedule_flush] 取代。
## 保留仅供向后兼容（外部不应直接调用）。
func _write_and_emit(path: String, old_val, new_val) -> void:
	if not _set_by_path(path, new_val):
		push_error("GSM._write_and_emit: 写入失败（路径: '%s'）" % path)
		return
	_buffer_change(path, old_val, new_val)


## === 持久域常量 =============================================================

## 全部 8 个数据域——用于序列化/反序列化遍历。
const ALL_DOMAINS: PackedStringArray = ["meta", "player", "collection", "deck", "battle", "exploration", "narrative", "session"]

## 可持久化的域——序列化/反序列化时包含。
const PERSISTABLE_DOMAINS: PackedStringArray = ["meta", "player", "collection", "deck", "exploration", "narrative"]

## 不可持久化的域——序列化/反序列化时排除。
const NON_PERSISTABLE_DOMAINS: PackedStringArray = ["battle", "session"]


## === 第四层：序列化/反序列化 =================================================

## 将当前游戏状态序列化为纯 Dictionary。
## 排除 [b]battle[/b] 和 [b]session[/b] 域（不可持久化）。
## 返回值为深拷贝——调用方修改不影响 GSM 内部状态。
func serialize() -> Dictionary:
	var data: Dictionary = {}
	for domain: String in PERSISTABLE_DOMAINS:
		var domain_value: Variant = _get_domain(domain)
		data[domain] = _deep_copy(domain_value)
	return data


## 从存档数据反序列化并原子替换内存状态。
## [br][b]失败时[/b]（结构无效、类型不匹配）：内存状态不变，返回 [code]false[/code]。
## [br][b]成功时[/b]：原子替换所有持久域，返回 [code]true[/code]。
## [br]旧版本存档缺失域/字段 → 自动填充默认值（向前兼容）。
func deserialize(data) -> bool:
	# 类型检查——非 Dictionary 直接拒绝
	if not data is Dictionary:
		push_error("GSM.deserialize: 输入不是字典类型")
		return false

	# 1. 结构校验
	if not _validate_save_structure(data):
		return false

	# 2. 在快照上逐域反序列化——缺失域填充默认值
	var snapshot: Dictionary = {}
	# 预先复制不可持久化域——deserialize 不改变它们
	for domain: String in NON_PERSISTABLE_DOMAINS:
		snapshot[domain] = _get_domain(domain)

	for domain: String in PERSISTABLE_DOMAINS:
		if data.has(domain):
			var defaults: Dictionary = _get_default_for_domain(domain)
			var ok: bool = _deserialize_domain(snapshot, domain, data[domain], defaults)
			if not ok:
				return false
		else:
			# 旧版本存档缺少整个域 → 填充默认值
			snapshot[domain] = _get_default_for_domain(domain)

	# 3. 原子替换：全部校验通过后才写入内存状态
	for domain: String in ALL_DOMAINS:
		_set_domain(domain, snapshot[domain])

	# 4. 恢复卡牌实例 ID 计数器——_next_card_instance_id 不在持久化域中，
	# 但读档后必须大于已存档卡牌的最大 ID，否则新建实例会与旧实例 ID 冲突。
	_recover_card_id_counter()

	return true


## === 私有：序列化辅助方法 ====================================================

## 恢复卡牌实例 ID 计数器——从已存档卡牌的最大 card_instance_id 推导。[br]
## [br]_next_card_instance_id 不在持久化域中，但读档后必须大于已存档卡牌的最大 ID，
## 否则 [method allocate_card_id] 会返回与旧实例冲突的 ID。[br]
## [br]兼容 [code]card_instance_id[/code]（ADR-0006 权威）与 [code]instance_id[/code] 两种字段命名。[br]
## [br]无存档卡牌或所有 ID 为 0 时，重置为初始值 1。
func _recover_card_id_counter() -> void:
	var max_id: int = 0
	for inst: Dictionary in collection.owned_cards:
		var cid: int = int(inst.get("card_instance_id", inst.get("instance_id", 0)))
		if cid > max_id:
			max_id = cid
	_next_card_instance_id = max(1, max_id + 1)


## 递归深拷贝——返回与 GSM 内部状态完全解耦的拷贝。
## Dictionary 和 Array 递归拷贝，其他类型（int/float/String/bool/null）直接返回。
func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value.keys():
			result[key] = _deep_copy(value[key])
		return result
	elif value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_deep_copy(item))
		return result
	else:
		return value


## 深层相等比较——两个 Variant 递归比较（用于快照去重）。[br]
## [br]Dictionary/Array 递归比较；其他类型直接 [code]==[/code] 比较。
func _deep_equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key: Variant in a.keys():
			if not b.has(key):
				return false
			if not _deep_equal(a[key], b[key]):
				return false
		return true
	elif a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i: int in range(a.size()):
			if not _deep_equal(a[i], b[i]):
				return false
		return true
	else:
		return a == b


## 校验存档结构的合法性。
## 检查：非空 Dictionary、无未知域、存在的域值为 Dictionary 类型。
## 注意：不检查所有持久域是否齐全——缺失域由 [method deserialize] 自动填充默认值（向前兼容）。
func _validate_save_structure(data: Dictionary) -> bool:
	if data.is_empty():
		push_error("GSM.deserialize: 存档数据为空字典")
		return false

	# 检查未知顶级域
	for key: String in data.keys():
		if not _is_valid_domain(key):
			push_error("GSM.deserialize: 未知域 '%s'" % key)
			return false

	# 检查存在的域值为 Dictionary 类型
	for key: String in data.keys():
		if not data[key] is Dictionary:
			push_error("GSM.deserialize: 域 '%s' 不是字典类型" % key)
			return false

	return true


## 反序列化单个域到目标快照中。
## 逐字段写入——类型不匹配时返回 false。输入中缺失的字段使用默认值。
func _deserialize_domain(snapshot: Dictionary, domain: String, input: Dictionary, defaults: Dictionary) -> bool:
	var result: Dictionary = {}
	for key: Variant in defaults.keys():
		if input.has(key):
			var default_val = defaults[key]
			var input_val = input[key]
			# 向前兼容：旧存档 player.resources.ling_cai 为扁平 int，迁移为嵌套 Dictionary
			if domain == "player" and key == "resources" and input_val is Dictionary:
				input_val = _migrate_resources_dict(input_val)
			if not _type_check(domain, key, input_val, default_val):
				return false
			result[key] = _deep_copy(input_val)
		else:
			# 旧存档缺失字段 → 使用默认值
			result[key] = _deep_copy(defaults[key])
	snapshot[domain] = result
	return true


## 迁移 resources 字典——将旧扁平 int ling_cai 迁移为嵌套 Dictionary。[br]
## [br][b]向前兼容[/b]：旧存档 ling_cai 为 int（无品质区分），新存档为 [code]{low, medium, high, top}[/code]。[br]
## [br]旧 int 值被丢弃（旧格式未区分品质，无法可靠映射到任一品质）；缺失品质键填充 0。[br]
## [br][param input] 原始 resources 字典。[br]
## [br][b]返回[/b]: 迁移后的 resources 字典（新格式）。[br]
## [br]来源: ADR-0019 §GSM 第二层扩展方法——向前兼容旧存档。
func _migrate_resources_dict(input: Dictionary) -> Dictionary:
	var result: Dictionary = input.duplicate(true)
	if result.has("ling_cai"):
		var lc: Variant = result["ling_cai"]
		if lc is int:
			# 旧扁平格式——丢弃旧值（无法区分品质），填充为四品质零值
			result["ling_cai"] = {"low": 0, "medium": 0, "high": 0, "top": 0}
		elif lc is Dictionary:
			# 新格式——确保四品质齐全，缺失或类型不匹配填充 0
			var new_lc: Dictionary = {"low": 0, "medium": 0, "high": 0, "top": 0}
			for q_key: String in ["low", "medium", "high", "top"]:
				if lc.has(q_key) and lc[q_key] is int:
					new_lc[q_key] = lc[q_key]
			result["ling_cai"] = new_lc
	return result


## 类型校验——新值的类型必须与默认值匹配。
## null 默认值不校验（任何类型均接受——允许未来扩展）。
func _type_check(domain: String, key: String, new_val: Variant, default_val: Variant) -> bool:
	var default_type: int = typeof(default_val)
	var new_type: int = typeof(new_val)

	# null 默认值放行——允许未来扩展该字段
	if default_type == TYPE_NIL:
		return true
	if new_type != default_type:
		push_error("GSM.deserialize: 域 '%s.%s' 类型不匹配（期望%d，实际%d）" % [domain, key, default_type, new_type])
		return false
	return true


## 检查域名是否存在于数据域中。
func _is_valid_domain(domain_name: String) -> bool:
	return _get_domain(domain_name) != null


## 直接将域值写入 GSM 对应属性（无声，供 [method deserialize] 原子替换用）。
func _set_domain(domain_name: String, value: Variant) -> void:
	match domain_name:
		"meta":        meta = value
		"player":      player = value
		"collection":  collection = value
		"deck":        deck = value
		"battle":      battle = value
		"exploration": exploration = value
		"narrative":   narrative = value
		"session":     session = value



## 返回指定域的完整默认 Dictionary——与 [method _init_all_domains] 一致。
## 用于 [method deserialize] 中缺失域/字段的默认值填充。
func _get_default_for_domain(domain_name: String) -> Dictionary:
	match domain_name:
		"meta":
			return {"game_id": "", "seed": 0, "timestamp": 0}
		"player":
			return {
				"realm": RealmLevel.QI_REFINING,
				"cultivation": 0,
				"max_cultivation": BASE_MAX,
				"cultivation_full": false,
				"overflow_pool": 0,
				"resources": {"ling_shi": 0, "ling_cai": {"low": 0, "medium": 0, "high": 0, "top": 0}, "dan_yao_sui_pian": 0},
				"identity_id": "",
				"talents": [],
			}
		"collection":
			return {"owned_cards": [], "total_count": 0}
		"deck":
			return {"character_slots": [null, null, null, null, null, null], "current_deck": [], "presets": []}
		"exploration":
			return {"current_map_id": "", "node_position": 0, "action_points": 0, "revealed_nodes": [], "map_state": {}}
		"narrative":
			return {"current_chapter": "", "completed_chapters": [], "story_flags": {}}
	return {}