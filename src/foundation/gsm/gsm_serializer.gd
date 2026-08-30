extends RefCounted
## GameStateManager.GSMSerializer —— 序列化/反序列化 + 域访问引擎（提取自 game_state_manager.gd）。
##
## 持有对 GSM 父节点的引用，负责：[br]
##   - 域访问辅助（_get_domain/_set_domain/_is_valid_domain/_get_default_for_domain）[br]
##   - 域初始化（init_all_domains）[br]
##   - 序列化/反序列化（serialize/deserialize）+ 旧存档迁移 + 向前兼容[br]
##   - 深拷贝/深层相等（_deep_copy/_deep_equal）
##
## [b]提取原因[/b]：game_state_manager.gd 1080 行 → 拆分（Story 3-9 技术债，Sprint 1 回顾行动项 #2）。
##
## 来源: ADR-0001 §第四层序列化 + ADR-0019 §向前兼容。

## 指向 GSM 父节点的引用——序列化引擎通过它访问域数据。
var _gsm: Node = null


## 绑定 GSM 父节点引用。
func init(gsm: Node) -> void:
	_gsm = gsm


# === 域访问辅助 ================================================================

## 将域名字符串映射到 GSM 对应属性引用。
func _get_domain(domain_name: String) -> Variant:
	match domain_name:
		"meta":        return _gsm.meta
		"player":      return _gsm.player
		"collection":  return _gsm.collection
		"deck":        return _gsm.deck
		"battle":      return _gsm.battle
		"exploration": return _gsm.exploration
		"narrative":   return _gsm.narrative
		"session":     return _gsm.session
		_:             return null


## 直接将域值写入 GSM 对应属性（供 [method deserialize] 原子替换用）。
func _set_domain(domain_name: String, value: Variant) -> void:
	match domain_name:
		"meta":        _gsm.meta = value
		"player":      _gsm.player = value
		"collection":  _gsm.collection = value
		"deck":        _gsm.deck = value
		"battle":      _gsm.battle = value
		"exploration": _gsm.exploration = value
		"narrative":   _gsm.narrative = value
		"session":     _gsm.session = value


## 检查域名是否存在于数据域中。
func _is_valid_domain(domain_name: String) -> bool:
	return _get_domain(domain_name) != null


## 通过 "." 分隔路径写入嵌套字典中的值（无声，不发射信号）。[br]
## [br]用于 [method GameStateManager.set_identity] 等需要按路径写嵌套字段的第二层方法。
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


## 返回指定域的完整默认 Dictionary——序列化与域初始化的单一真理来源。
func _get_default_for_domain(domain_name: String) -> Dictionary:
	match domain_name:
		"meta":
			return {"game_id": "", "seed": 0, "timestamp": 0}
		"player":
			return {
				"realm": _gsm.RealmLevel.QI_REFINING,
				"cultivation": 0,
				"max_cultivation": _gsm.BASE_MAX,
				"cultivation_full": false,
				"overflow_pool": 0,
				"resources": {"ling_shi": 0, "ling_cai": {"low": 0, "medium": 0, "high": 0, "top": 0}, "dan_yao_sui_pian": 0},
				"identity_id": "",
				"talents": [],
				"unavailable_characters": {},
				"tribulation_state": 0,
				"consecutive_tribulation_failures": 0,
			}
		"collection":
			return {"owned_cards": [], "total_count": 0}
		"deck":
			return {
				"current_deck": [],
				"slots": [null, null, null, null, null, null],
				"change_log": [],
				"session_remove_count": 0,
				"deck_limit_modifier": 0,
			}
		"exploration":
			return {
				"current_map": &"",
				"node_position": {"layer": 0, "idx": 0},
				"visited_nodes": [],
				"action_points": 0,
				"max_action_points": 0,
				"map_states": {},
			}
		"narrative":
			return {"current_chapter": "", "completed_chapters": [], "story_flags": {}}
		"session":
			return {"current_scene": "", "scene_id": 0, "ui_state": {}, "input_locks": []}
	return {}


## 初始化全部 8 个数据域（battle 恒为 null——非战斗状态）。由 GSM._ready 调用。
func init_all_domains() -> void:
	_gsm.meta = _get_default_for_domain("meta")
	_gsm.player = _get_default_for_domain("player")
	_gsm.collection = _get_default_for_domain("collection")
	_gsm.deck = _get_default_for_domain("deck")
	_gsm.battle = null
	_gsm.exploration = _get_default_for_domain("exploration")
	_gsm.narrative = _get_default_for_domain("narrative")
	_gsm.session = _get_default_for_domain("session")


# === 序列化 / 反序列化 =========================================================

## 将当前游戏状态序列化为纯 Dictionary。[br]
## [br]排除 battle 和 session 域（不可持久化）。返回深拷贝——调用方修改不影响 GSM 内部状态。
func serialize() -> Dictionary:
	var data: Dictionary = {}
	for domain: String in _gsm.PERSISTABLE_DOMAINS:
		data[domain] = _deep_copy(_get_domain(domain))
	return data


## 从存档数据反序列化并原子替换内存状态。[br]
## [br][b]失败时[/b]（结构无效、类型不匹配）：内存状态不变，返回 [code]false[/code]。[br]
## [br][b]成功时[/b]：原子替换所有持久域，返回 [code]true[/code]。[br]
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
	for domain: String in _gsm.NON_PERSISTABLE_DOMAINS:
		snapshot[domain] = _get_domain(domain)

	for domain: String in _gsm.PERSISTABLE_DOMAINS:
		if data.has(domain):
			var defaults: Dictionary = _get_default_for_domain(domain)
			var ok: bool = _deserialize_domain(snapshot, domain, data[domain], defaults)
			if not ok:
				return false
		else:
			# 旧版本存档缺少整个域 → 填充默认值
			snapshot[domain] = _get_default_for_domain(domain)

	# 3. 原子替换：全部校验通过后才写入内存状态
	for domain: String in _gsm.ALL_DOMAINS:
		_set_domain(domain, snapshot[domain])

	# 4. 恢复卡牌实例 ID 计数器——_next_card_instance_id 不在持久化域中，
	# 但读档后必须大于已存档卡牌的最大 ID，否则新建实例会与旧实例 ID 冲突。
	_recover_card_id_counter()

	return true


## 恢复卡牌实例 ID 计数器——从已存档卡牌的最大 card_instance_id 推导。[br]
## [br]兼容 [code]card_instance_id[/code]（ADR-0006 权威）与 [code]instance_id[/code] 两种字段命名。[br]
## [br]无存档卡牌或所有 ID 为 0 时，重置为初始值 1。
func _recover_card_id_counter() -> void:
	var max_id: int = 0
	for inst: Dictionary in _gsm.collection.owned_cards:
		var cid: int = int(inst.get("card_instance_id", inst.get("instance_id", 0)))
		if cid > max_id:
			max_id = cid
	_gsm._next_card_instance_id = max(1, max_id + 1)


## 校验存档结构的合法性。[br]
## [br]检查：非空 Dictionary、无未知域、存在的域值为 Dictionary 类型。[br]
## [br]注意：不检查所有持久域是否齐全——缺失域由 [method deserialize] 自动填充默认值（向前兼容）。
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


## 反序列化单个域到目标快照中。[br]
## [br]逐字段写入——类型不匹配时返回 false。输入中缺失的字段使用默认值。
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
## [br]旧 int 值被丢弃（旧格式未区分品质，无法可靠映射到任一品质）；缺失品质键填充 0。
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


## 类型校验——新值的类型必须与默认值匹配。[br]
## [br]null 默认值不校验（任何类型均接受——允许未来扩展）。
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


# === 深拷贝 / 深层相等 =========================================================

## 递归深拷贝——返回与 GSM 内部状态完全解耦的拷贝。[br]
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
