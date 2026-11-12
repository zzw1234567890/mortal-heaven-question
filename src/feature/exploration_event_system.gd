class_name ExplorationEventSystem
extends RefCounted
## ExplorationEventSystem —— 探索事件节点的加载与结算。
##
## 职责（三件事）：
## [br]1. 扫描 [code]res://assets/events/[/code] 下的 [EventDef] 资源，按
## [member EventDef.event_id] 建注册表；
## [br]2. 事件节点取事件——[method pick_for_node] 按玩家境界筛候选后取一个
## （选取策略在 [ExplorationEventSelector]）；
## [br]3. 结算玩家选择的选项——把 [EventDefEffect] 落到 GSM/资源系统，并给出
## 可直接显示的文案行。
##
## [b]不持有状态[/b]：所有落库都委托给注入的依赖（GSM / ResourceSystem /
## CultivationSystem / CardSystem），本类只做加载、掷骰与调用，方便单测。
##
## [b]与 EventSystem（Autoload）的区别[/b]：EventSystem 是 Foundation 层的
## 连锁/条件事件引擎，模板是 [code]EventTemplate[/code]；本类服务探索节点，
## 资源是 [code]EventDef[/code]。两类 .tres 共驻 [code]assets/events/[/code]。
##
## 来源: Sprint 18 探索事件节点。

const EVENT_ROOT: String = "res://assets/events"

const CardSerializer := preload("res://src/core/card_system/card_serializer.gd")

## 选取策略子模块——按境界筛选 + 随机取一（见 [ExplorationEventSelector]）。
const EventSelectorScript := preload("res://src/feature/exploration_event_selector.gd")

## 效果种类——与 [code]EventDefEffect.Kind[/code] 的导出枚举顺序保持一致。
const KIND_LING_SHI: int = 0
const KIND_CULTIVATION: int = 1
const KIND_HP: int = 2
const KIND_CARD: int = 3

## event_id -> EventDef
var _registry: Dictionary = {}
var _last_error: String = ""


# === 加载 =====================================================================

## 递归扫描事件目录并注册。[br]
## [br]返回注册数量；解析失败的文件记 [member _last_error] 后跳过，
## 不让一个坏文件拖垮整张表。
func load_events() -> int:
	_registry.clear()
	_last_error = ""
	var dir := DirAccess.open(EVENT_ROOT)
	if dir == null:
		_last_error = "事件目录不可读：%s" % EVENT_ROOT
		return 0
	_scan(dir, EVENT_ROOT)
	return _registry.size()


func _scan(p_dir: DirAccess, p_path: String) -> void:
	p_dir.list_dir_begin()
	var name := p_dir.get_next()
	while not name.is_empty():
		if name.begins_with("."):
			name = p_dir.get_next()
			continue
		var full: String = p_path.path_join(name)
		if p_dir.current_is_dir():
			var sub := DirAccess.open(full)
			if sub != null:
				_scan(sub, full)
		elif name.ends_with(".tres"):
			_register(full)
		name = p_dir.get_next()
	p_dir.list_dir_end()


func _register(p_path: String) -> void:
	if not ResourceLoader.exists(p_path):
		return
	var res: Variant = ResourceLoader.load(p_path, "", ResourceLoader.CACHE_MODE_REUSE)
	if res == null:
		_last_error = "加载失败：%s" % p_path
		return
	# 同目录还躺着 EventTemplate——不是本类的事，静默跳过。
	if not (res is EventDef):
		return
	var def: EventDef = res
	if def.event_id.is_empty():
		_last_error = "事件缺少 event_id：%s" % p_path
		return
	if _registry.has(def.event_id):
		_last_error = "event_id 重复：%s" % def.event_id
		return
	_registry[def.event_id] = def


# === 查询 =====================================================================

func has_event(p_event_id: String) -> bool:
	return _registry.has(p_event_id)


func get_event(p_event_id: String) -> EventDef:
	var raw: Variant = _registry.get(p_event_id)
	return raw if raw is EventDef else null


func event_ids() -> Array:
	return _registry.keys()


func event_count() -> int:
	return _registry.size()


func last_error() -> String:
	return _last_error


## 按 id 稳定排序后取第 [code]index % count[/code] 个——测试与「按节点序号取事件」
## 都用它，保证同一输入永远同一结果。
func pick_by_index(p_index: int) -> EventDef:
	var ids: Array = event_ids()
	if ids.is_empty():
		return null
	ids.sort()
	var idx: int = posmod(p_index, ids.size())
	return get_event(String(ids[idx]))


## 事件节点取事件——委托 [ExplorationEventSelector]：按玩家境界（下限按炼气期
## 兜底）筛出候选后取一个，有 [param p_rng] 时随机、无 rng 时按 [param p_node_id]
## 取模（确定性，可复现）。[br]
## [br]候选为空（如玩家境界低于全部事件的 [member EventDef.min_realm]）时返回
## [code]null[/code]——调用方据此不弹面板、不报错。
func pick_for_node(p_node_id: int, p_player_realm: int,
		p_rng: RandomNumberGenerator = null) -> EventDef:
	return EventSelectorScript.pick_for_node(self, p_node_id, p_player_realm, p_rng)


# === 结算 =====================================================================

## 结算玩家在 [param p_event_id] 上选择的第 [param p_option_index] 个选项。[br]
## [br][param p_deps] 支持的键：[code]gsm[/code]、[code]resource_system[/code]、
## [code]cultivation_system[/code]、[code]card_system[/code]；缺哪个就跳过对应的
## 效果种类并在 [code]lines[/code] 里标「未能发放」。[br]
## [br]返回 [code]{ok, result_text, lines, applied}[/code]——[code]lines[/code]
## 是给人看的文案行，[code]applied[/code] 是成功落库的效果条数。
func resolve_option(p_event_id: String, p_option_index: int,
		p_deps: Dictionary = {}, p_rng: RandomNumberGenerator = null) -> Dictionary:
	var def := get_event(p_event_id)
	if def == null:
		return _failure("事件不存在：%s" % p_event_id)
	if p_option_index < 0 or p_option_index >= def.options.size():
		return _failure("选项下标越界：%d" % p_option_index)
	var raw_option: Variant = def.options[p_option_index]
	if not (raw_option is EventDefOption):
		return _failure("选项类型不正确：%s" % p_event_id)
	var option: EventDefOption = raw_option
	var lines: Array = []
	var applied: int = 0
	for raw_effect: Variant in option.effects:
		if not (raw_effect is EventDefEffect):
			continue
		var effect: EventDefEffect = raw_effect
		var amount: int = _roll_amount(effect, p_rng)
		# 数值类效果数额为 0 时跳过；卡片效果不看数额（amount 恒为 0）。
		if amount == 0 and effect.kind != KIND_CARD:
			continue
		var line: String = _apply_effect(effect, amount, p_deps)
		if line.is_empty():
			continue
		lines.append(line)
		applied += 1
	return {
		"ok": true,
		"result_text": option.result_text,
		"lines": lines,
		"applied": applied,
	}


func _failure(p_message: String) -> Dictionary:
	return {"ok": false, "result_text": p_message, "lines": [], "applied": 0}


## 数额掷骰——[member EventDefEffect.use_range] 为真时在 [min, max] 内取整，
## 否则用 [member EventDefEffect.amount]；没有 rng 时取区间中值（可复现）。
func _roll_amount(p_effect: EventDefEffect, p_rng: RandomNumberGenerator) -> int:
	if not p_effect.use_range:
		return p_effect.amount
	var lo: int = mini(p_effect.min_amount, p_effect.max_amount)
	var hi: int = maxi(p_effect.min_amount, p_effect.max_amount)
	if lo == hi:
		return lo
	if p_rng == null:
		return int((lo + hi) / 2)
	return p_rng.randi_range(lo, hi)


func _apply_effect(p_effect: EventDefEffect, p_amount: int,
		p_deps: Dictionary) -> String:
	match p_effect.kind:
		KIND_LING_SHI:
			return _apply_ling_shi(p_amount, p_deps)
		KIND_CULTIVATION:
			return _apply_cultivation(p_amount, p_deps)
		KIND_HP:
			return _apply_hp(p_effect, p_amount, p_deps)
		KIND_CARD:
			return _apply_card(p_effect, p_deps)
	return ""


func _apply_ling_shi(p_amount: int, p_deps: Dictionary) -> String:
	var system: Variant = p_deps.get("resource_system")
	if system == null or not (system is Node) or not system.has_method(&"add_resource"):
		return "灵石 +%d（未能发放：资源系统不可用）" % p_amount
	var ok: bool = bool(system.call(&"add_resource", &"ling_shi", p_amount))
	if not ok:
		return "灵石 +%d（未能发放）" % p_amount
	return "灵石 +%d" % p_amount


func _apply_cultivation(p_amount: int, p_deps: Dictionary) -> String:
	var system: Variant = p_deps.get("cultivation_system")
	if system == null or not (system is Node) or not system.has_method(&"gain_cultivation"):
		return "修为 +%d（未能发放：修炼系统不可用）" % p_amount
	system.call(&"gain_cultivation", p_amount, "exploration_event")
	return "修为 +%d" % p_amount


## 生命效果直接写 [code]player.character_hp[/code]：负值为伤害，正值为回复，
## 只影响已登记 HP 的角色，不凭空造出满血角色。
func _apply_hp(p_effect: EventDefEffect, p_amount: int, p_deps: Dictionary) -> String:
	var gsm: Variant = p_deps.get("gsm")
	if gsm == null or not (gsm is Node) or not gsm.has_method(&"get_state"):
		return "生命 %+d（未能发放：存档系统不可用）" % p_amount
	var table: Variant = gsm.call(&"get_state", "player.character_hp")
	if not (table is Dictionary):
		return "生命 %+d（未能发放：无角色血量）" % p_amount
	var hp_table: Dictionary = table
	var target_id: int = p_effect.character_id
	# GSM 里 character_hp 的键是字符串（写入口统一 str(character_id)），
	# 读侧两种键都要认。
	var key: String = ""
	if target_id > 0:
		key = str(target_id)
		if not hp_table.has(key):
			# 兼容旧存档里以整数为键的写法。
			for raw_key: Variant in hp_table.keys():
				if int(raw_key) == target_id:
					key = str(raw_key)
					break
			if not hp_table.has(key):
				return "生命 %+d（未能发放：角色未登记血量）" % p_amount
	else:
		# 未指定角色时作用于键序最小的那个角色（阵容首位）。
		if hp_table.is_empty():
			return "生命 %+d（未能发放：无角色血量）" % p_amount
		var keys: Array = hp_table.keys()
		keys.sort()
		key = str(keys[0])
	var entry: Variant = hp_table[key]
	if not (entry is Dictionary):
		return "生命 %+d（未能发放：血量数据格式异常）" % p_amount
	var hp_entry: Dictionary = entry
	var current: int = int(hp_entry.get("current_hp", hp_entry.get("current", 0)))
	var max_hp: int = int(hp_entry.get("max_hp", hp_entry.get("max", current)))
	var next_hp: int = clampi(current + p_amount, 0, maxi(max_hp, 0))
	hp_entry["current_hp"] = next_hp
	hp_table[key] = hp_entry
	gsm.call(&"_set_player_character_hp", int(key),
			{"current_hp": next_hp, "max_hp": max_hp})
	return "生命 %+d（%d/%d）" % [next_hp - current, next_hp, max_hp]


func _apply_card(p_effect: EventDefEffect, p_deps: Dictionary) -> String:
	var card_id: String = p_effect.card_id
	if card_id.is_empty():
		return ""
	var card_system: Variant = p_deps.get("card_system")
	var gsm: Variant = p_deps.get("gsm")
	if card_system == null or not (card_system is Node) or not card_system.has_method(&"create_instance"):
		return "卡牌 %s（未能发放：卡牌系统不可用）" % card_id
	if gsm == null or not (gsm is Node) or not gsm.has_method(&"add_card_to_collection"):
		return "卡牌 %s（未能发放：存档系统不可用）" % card_id
	var template: Variant = null
	if card_system.has_method(&"get_template"):
		template = card_system.call(&"get_template", StringName(card_id))
	if template == null:
		return "卡牌 %s（未能发放：未知卡牌）" % card_id
	var inst: Variant = card_system.call(&"create_instance", StringName(card_id))
	if inst == null:
		return "卡牌 %s（未能发放：实例创建失败）" % card_id
	var entry: Dictionary = CardSerializer.serialize_instance(inst)
	entry["template_id"] = card_id
	if not bool(gsm.call(&"add_card_to_collection", entry)):
		return "卡牌 %s（未能发放：收藏写入失败）" % card_id
	return "获得卡牌 %s" % card_id
