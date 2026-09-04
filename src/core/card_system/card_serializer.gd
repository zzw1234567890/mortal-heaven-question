extends RefCounted
## CardSerializer —— 卡牌实例序列化/反序列化子模块（从 card_system.gd 拆分）。
##
## 纯函数 RefCounted 类——不持有运行时状态，不访问父节点状态。[br]
## 包含 serialize_instance / deserialize_instance / reconstitute_instances +
## _get_int_field / _to_stringname / _get_inscriptions_field 辅助。
##
## [br]来源: ADR-0006 §GSM 集成合约。
## [br]Sprint 10 Story 6：从 card_system.gd 拆分。


## 序列化 [CardInstance] 为纯 [Dictionary]——用于存档往返。[br]
## [br][b]ADR-0006 §GSM 集成合约[/b]：GSM 持有序列化的 Dictionary（模型 A），
## 通过 [method reconstitute_instances] 批量重构 CardInstance 对象。[br]
## [br][b]9 字段[/b]：card_instance_id、template_id、level、inscriptions、[br]
## breakthrough_layers、binding_target_id、acquired_chapter、acquired_event_id、acquired_method。[br]
## [br][param inst]: 待序列化的卡牌实例。[br]
## [br][b]返回[/b]: 含全部 9 字段的 Dictionary，inscriptions 为深拷贝（避免共享引用）。
static func serialize_instance(inst: CardInstance) -> Dictionary:
	return {
		"card_instance_id": inst.card_instance_id,
		"template_id": inst.template_id,
		"level": inst.level,
		"inscriptions": inst.inscriptions.duplicate(true),
		"breakthrough_layers": inst.breakthrough_layers,
		"binding_target_id": inst.binding_target_id,
		"acquired_chapter": inst.acquired_chapter,
		"acquired_event_id": inst.acquired_event_id,
		"acquired_method": inst.acquired_method,
	}


## 从 [Dictionary] 反序列化为 [CardInstance]——恢复全部 9 字段。[br]
## [br][b]AC-003 StringName 显式转换[/b]：template_id、binding_target_id、acquired_event_id
## 三个 StringName 字段经 JSON 往返后为 String，必须 [code]StringName()[/code] 转换，[br]
## 否则 [member templates] 字典查找失败（Godot 4.6 字典键类型敏感）。[br]
## [br][b]AC-007 缺失字段容错[/b]：使用 [code].get(key, default)[/code]，默认值与 Story 002 一致。[br]
## [br][b]AC-008 未知字段[/b]：仅读取已知 9 字段，Dictionary 中其他键被自然忽略。[br]
## [br][b]AC-009 类型不匹配[/b]：对 5 个 int 字段做 [code]typeof[/code] 检查 + [code]int()[/code] 强制转换，[br]
## 非数字值 → [method @GlobalScope.push_error] + 使用默认值（AC-007 一致）。[br]
## [br][param data]: 序列化的 Dictionary（可能来自 JSON 反序列化，字段类型可能为 String）。[br]
## [br][b]返回[/b]: 恢复的 CardInstance 实例。
static func deserialize_instance(data: Dictionary) -> CardInstance:
	var inst: CardInstance = CardInstance.new()
	inst.card_instance_id = _get_int_field(data, "card_instance_id", 0)
	inst.template_id = _to_stringname(data.get("template_id", &""))
	inst.level = _get_int_field(data, "level", 1)
	inst.inscriptions = _get_inscriptions_field(data, "inscriptions")
	inst.breakthrough_layers = _get_int_field(data, "breakthrough_layers", 0)
	inst.binding_target_id = _to_stringname(data.get("binding_target_id", &""))
	inst.acquired_chapter = _get_int_field(data, "acquired_chapter", 0)
	inst.acquired_event_id = _to_stringname(data.get("acquired_event_id", &""))
	inst.acquired_method = _get_int_field(data, "acquired_method", 0)
	return inst


## 批量反序列化——将存档中的 Dictionary 数组重构为 CardInstance 数组。[br]
## [br]用于 SaveLoadSystem 读档后重构 GSM [code]collection.owned_cards[/code] 对应的实例对象。[br]
## [br][b]复杂度[/b]: O(n) 遍历——非热路径（仅读档时调用）。[br]
## [br][param dicts]: 序列化的 Dictionary 数组。[br]
## [br][b]返回[/b]: [Array] 含反序列化的 CardInstance；空数组返回空数组（非 null）。[br]
## NOTE: 返回裸 Array 而非 Array[CardInstance]——GDScript 4.6 在不声明 class_name 的
## 脚本中跨文件 typed array 返回类型解析不稳定（同 get_templates_by_type 先例）。
static func reconstitute_instances(dicts: Array) -> Array:
	var result: Array = []
	result.resize(dicts.size())
	for i: int in range(dicts.size()):
		result[i] = deserialize_instance(dicts[i])
	return result


## 从 Dictionary 读取 int 字段——AC-009 类型不匹配容错。[br]
## [br][b]策略[/b]：[br]
##   - int 类型 → 直接返回[br]
##   - float 类型 → [code]int()[/code] 截断转换（JSON 数字可能为 float）[br]
##   - String 类型且为数字 → [code]int()[/code] 转换（兼容 JSON 数字字符串）[br]
##   - String 类型且非数字 → [method @GlobalScope.push_error] + 返回默认值[br]
##   - 其他类型 → [method @GlobalScope.push_error] + 返回默认值[br]
## [br][param data]: 源 Dictionary。[br]
## [br][param key]: 字段键名。[br]
## [br][param default_value]: 类型不匹配或缺失时的默认值。[br]
## [br][b]返回[/b]: int 字段值或默认值。
static func _get_int_field(data: Dictionary, key: String, default_value: int) -> int:
	if not data.has(key):
		return default_value
	var value: Variant = data[key]
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	if typeof(value) == TYPE_STRING:
		var s: String = value
		if s.is_valid_int():
			return int(s)
		push_error("CardSystem.deserialize_instance: 字段 '%s' 类型不匹配（String 非数字 '%s'）——使用默认值 %d" % [key, s, default_value])
		return default_value
	push_error("CardSystem.deserialize_instance: 字段 '%s' 类型不匹配（期望 int，实际类型 %d）——使用默认值 %d" % [key, typeof(value), default_value])
	return default_value


## 将 Variant 值安全转换为 StringName——处理 JSON 往返产生的 String/null。[br]
## [br]Godot 4.6 的 [code]StringName(null)[/code] 构造函数不存在（运行时报错），
## 此方法对 null/非 String 类型统一返回默认 [code]&""[/code]。[br]
## [br][param value]: 输入值（可能为 String、StringName、null 或其他）。
static func _to_stringname(value: Variant) -> StringName:
	if value == null:
		return &""
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return &""


## 从 Dictionary 读取 inscriptions 字段——显式深拷贝 + null/类型容错。[br]
## [br]AC-002 元素级深拷贝：[method Array.duplicate] 递归拷贝 Array 容器及内部 Dictionary 元素，[br]
## 避免反序列化后的实例修改影响原存档 Dictionary。[br]
## [br]容错：null 或非 Array 值（存档损坏）→ 空数组，不崩溃。[br]
## [br][param data]: 源 Dictionary。[br]
## [br][param key]: 字段键名。[br]
## [br][b]返回[/b]: 深拷贝的 Array[Dictionary]，或空数组（值缺失/无效时）。
static func _get_inscriptions_field(data: Dictionary, key: String) -> Array[Dictionary]:
	var raw: Variant = data.get(key, [])
	if not raw is Array:
		return []
	var result: Array[Dictionary] = []
	for item: Variant in raw:
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result
