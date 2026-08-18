extends Node
# class_name GameStateManager —— 不声明：Autoload 全局单例，声明 class_name 会与全局名冲突。
# 测试以 var gsm 持有 + 动态分派访问（Foundation Autoload 固有权衡）。
## GameStateManager (GSM) —— 游戏运行时单一数据源（Autoload #1）。
##
## 提供四层 API：第一层直接属性读取 / 第二层原子写入（帧末去重缓冲）/
## 第三层信号订阅 / 第四层序列化。消费者应等待 [signal gsm_initialized] 后再读取。
## 绝不直接写入 GSM 属性——始终通过第二层原子方法。
##
## [b]拆分结构[/b]（Story 3-9 技术债）：本文件持有信号、枚举、数据域、生命周期与薄转发 wrapper。
## 第二层原子写入 → [GSMAtomicWrites]；信号缓冲/订阅 → [GSMSignalRouter]；
## 序列化 + 域访问 → [GSMSerializer]。完整文档见各委托文件。

## 玩家修炼境界，从炼气到化神共五级。
enum RealmLevel {
	QI_REFINING = 1,           ## 炼气
	FOUNDATION = 2,            ## 筑基
	GOLDEN_CORE = 3,           ## 金丹
	NASCENT_SOUL = 4,          ## 元婴
	SPIRIT_TRANSFORMATION = 5,  ## 化神
}

# === 信号 ====================================================================

## 当 GSM [method _ready] 完成全部域的初始化后发射。
signal gsm_initialized()
## Cat 1：展平的路径变更字典。帧末一次性发射。[br]
## [br][b]格式:[/b] [code]{ "player.resources.ling_shi": {"old": 100, "new": 150}, ... }[/code]
signal batch_updated(changes: Dictionary)
## Cat 1：境界变更。
signal realm_changed(old_realm: int, new_realm: int)
## Cat 1：修为变更。
signal cultivation_changed(delta: int, current: int, max_val: int)
## Cat 1：修为已满通知。
signal cultivation_full(current: int, max_val: int)
## Cat 1：资源变更。
signal resource_changed(type: StringName, delta: int, balance: int)
## Cat 1：行动力变更。
signal action_points_changed(delta: int, current: int, max_val: int)
## Cat 1：卡组修改。
signal deck_modified(card_id: int, action: StringName)
## Cat 2a：战斗开始（立即发射）。
signal battle_started(config: Dictionary)
## Cat 2a：战斗结束（立即发射）。
signal battle_ended(result: Dictionary)
## Cat 1：场景变更。
signal scene_changed(from_scene: StringName, to_scene: StringName)
## Cat 1：卡牌收藏变更。
signal card_collection_changed(card_id: int, action: StringName)
## Cat 1：进度重置通知。
signal progression_reset(reason: StringName)
## Cat 1：卡牌校验就绪。
signal card_validation_ready()

# === 信号链深度追踪 (ADR-0007) ==============================================

## 当前信号链深度——Cat 2 信号通过 [method _emit_signal_safe] 增减。
static var _signal_chain_depth: int = 0
## 信号链硬限制——超出时截断并记录错误。
const MAX_SIGNAL_CHAIN_DEPTH: int = 4

## Cat 2 信号安全发射包装器。[br]
## [br][b]用法[/b]: [code]GameStateManager._emit_signal_safe(self, &"my_signal", [arg1, arg2])[/code]
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

# === 内部状态 ================================================================

## 初始化完成标志。
var _initialized: bool = false
## 修为上限基准值（炼气期）。
const BASE_MAX: int = 1000
## 帧内变更缓冲：键 = 完整路径，值 = {old, new}。
var _pending_changes: Dictionary = {}
## 帧末刷新是否已调度。
var _flush_scheduled: bool = false
## 信号发射进行中标志。
var _emitting_in_progress: bool = false
## 卡牌引用完整性校验开关。
var validation_enabled: bool = false
## 卡牌模板数据库——enable_validation() 时注入。
var _card_template_database: Dictionary = {}
## 卡牌实例 ID 分配计数器（0 保留为"未分配"哨兵）。来源: ADR-0006。
var _next_card_instance_id: int = 1

# === 委托对象 ================================================================

## 第二层原子写入委托。
var _atomic_writes: RefCounted = null
## 信号缓冲/订阅委托。
var _signal_router: RefCounted = null
## 序列化/反序列化委托。
var _serializer: RefCounted = null

# === 第一层：数据域 ==========================================================

var meta: Dictionary = {}
var player: Dictionary = {}
var collection: Dictionary = {}
var deck: Dictionary = {}
var battle = null
var exploration: Dictionary = {}
var narrative: Dictionary = {}
var session: Dictionary = {}

# === 生命周期 ================================================================

func _init() -> void:
	_atomic_writes = load("res://src/foundation/gsm/gsm_atomic_writes.gd").new()
	_signal_router = load("res://src/foundation/gsm/gsm_signal_router.gd").new()
	_serializer = load("res://src/foundation/gsm/gsm_serializer.gd").new()
	_atomic_writes.init(self)
	_signal_router.init(self)
	_serializer.init(self)

func _ready() -> void:
	_init_all_domains()
	_initialized = true
	get_tree().process_frame.connect(_reset_signal_chain_depth, CONNECT_DEFERRED)
	gsm_initialized.emit()

## 每帧重置信号链深度计数器——防止信号处理器异常逃逸导致持久泄漏。
func _reset_signal_chain_depth() -> void:
	_signal_chain_depth = 0

# === 第一层：读取 ============================================================

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

# === 第二层：原子写入（委托 → GSMAtomicWrites）==============================

func add_cultivation(amount: int, source: String = "") -> void:
	_atomic_writes.add_cultivation(amount, source)
func _set_resource_ling_shi(value: int) -> void:
	_atomic_writes._set_resource_ling_shi(value)
func _set_resource_ling_cai(quality: int, value: int) -> void:
	_atomic_writes._set_resource_ling_cai(quality, value)
func _set_battle_cost(current_cost: int, max_cost: int) -> void:
	_atomic_writes._set_battle_cost(current_cost, max_cost)
func _set_battle_status_snapshot(snapshot: Array) -> void:
	_atomic_writes._set_battle_status_snapshot(snapshot)
func _set_battle_deployment_snapshot(snapshot: Dictionary) -> void:
	_atomic_writes._set_battle_deployment_snapshot(snapshot)
func _set_player_unavailable_characters(data: Dictionary) -> void:
	_atomic_writes._set_player_unavailable_characters(data)
func battle_start(config: Dictionary) -> void:
	_atomic_writes.battle_start(config)
func battle_end(result: Dictionary) -> void:
	_atomic_writes.battle_end(result)
func set_identity(identity_id: StringName) -> void:
	_atomic_writes.set_identity(identity_id)
func change_realm(new_level: int) -> void:
	_atomic_writes.change_realm(new_level)
func reincarnation_reset() -> void:
	_atomic_writes.reincarnation_reset()
func allocate_card_id() -> int:
	return _atomic_writes.allocate_card_id()
func add_card_to_collection(inst_dict: Dictionary) -> bool:
	return _atomic_writes.add_card_to_collection(inst_dict)
func enable_validation(card_template_database: Dictionary) -> void:
	_atomic_writes.enable_validation(card_template_database)
func _validate_card_ref(template_id: String) -> bool:
	return _atomic_writes._validate_card_ref(template_id)
func _retroactive_validate_collection() -> void:
	_atomic_writes._retroactive_validate_collection()
func set_input_locks(locks: Array[Dictionary]) -> void:
	_atomic_writes.set_input_locks(locks)
func set_session_scene(id: int, path: String) -> void:
	_atomic_writes.set_session_scene(id, path)
func set_narrative_flag(flag: StringName, value: Variant) -> void:
	_atomic_writes.set_narrative_flag(flag, value)
func remove_card_from_collection(card_instance_id: int) -> bool:
	return _atomic_writes.remove_card_from_collection(card_instance_id)
func restore_action_points(amount: int) -> void:
	_atomic_writes.restore_action_points(amount)
func unlock_talent(talent_id: StringName) -> void:
	_atomic_writes.unlock_talent(talent_id)
func advance_chapter(chapter_id: StringName) -> void:
	_atomic_writes.advance_chapter(chapter_id)

# === 第三层：信号订阅（委托 → GSMSignalRouter）==============================

## 有效信号名列表——subscribe/unsubscribe 的白名单。
const VALID_SIGNALS: PackedStringArray = [
	"gsm_initialized", "realm_changed", "cultivation_changed",
	"cultivation_full", "resource_changed", "action_points_changed",
	"deck_modified", "battle_started", "battle_ended", "scene_changed",
	"card_collection_changed", "progression_reset", "batch_updated",
	"card_validation_ready",
]

func subscribe(event_name: StringName, callback: Callable) -> void:
	_signal_router.subscribe(event_name, callback)
func unsubscribe(event_name: StringName, callback: Callable) -> void:
	_signal_router.unsubscribe(event_name, callback)

# === 信号缓冲层（委托 → GSMSignalRouter）====================================

func _buffer_change(path: String, old_val: Variant, new_val: Variant) -> void:
	_signal_router._buffer_change(path, old_val, new_val)
func _schedule_flush() -> void:
	_signal_router._schedule_flush()
func _do_flush() -> void:
	_signal_router._do_flush()
func _flush_pending_changes() -> void:
	_signal_router._flush_pending_changes()
func _emit_domain_signal(path: String, data: Dictionary) -> void:
	_signal_router._emit_domain_signal(path, data)

# === 第四层：序列化（委托 → GSMSerializer）==================================

func serialize() -> Dictionary:
	return _serializer.serialize()
func deserialize(data) -> bool:
	return _serializer.deserialize(data)

# === 域常量 =================================================================

const ALL_DOMAINS: PackedStringArray = ["meta", "player", "collection", "deck", "battle", "exploration", "narrative", "session"]
const PERSISTABLE_DOMAINS: PackedStringArray = ["meta", "player", "collection", "deck", "exploration", "narrative"]
const NON_PERSISTABLE_DOMAINS: PackedStringArray = ["battle", "session"]

# === 域初始化与默认值 ========================================================

## 初始化全部 8 个数据域——委托 [GSMSerializer.init_all_domains]（单一真理来源）。
func _init_all_domains() -> void:
	_serializer.init_all_domains()

## 将域名字符串映射到对应的属性引用（委托序列化引擎）。
func _get_domain(domain_name: String) -> Variant:
	return _serializer._get_domain(domain_name)

## 直接将域值写入 GSM 对应属性（供 [method deserialize] 原子替换用，委托）。
func _set_domain(domain_name: String, value: Variant) -> void:
	_serializer._set_domain(domain_name, value)

## 检查域名是否存在于数据域中（委托）。
func _is_valid_domain(domain_name: String) -> bool:
	return _serializer._is_valid_domain(domain_name)

## 返回指定域的完整默认 Dictionary（委托）。
func _get_default_for_domain(domain_name: String) -> Dictionary:
	return _serializer._get_default_for_domain(domain_name)

## 通过 "." 分隔路径写入嵌套字典中的值（委托 [GSMSerializer._set_by_path]，无声）。
func _set_by_path(path: String, value: Variant) -> bool:
	return _serializer._set_by_path(path, value)

## 递归深拷贝——委托 [GSMSerializer._deep_copy]。
func _deep_copy(value: Variant) -> Variant:
	return _serializer._deep_copy(value)

## 深层相等比较——委托 [GSMSerializer._deep_equal]（用于快照去重）。
func _deep_equal(a: Variant, b: Variant) -> bool:
	return _serializer._deep_equal(a, b)
