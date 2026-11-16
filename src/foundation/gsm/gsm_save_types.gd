extends RefCounted
## GsmSaveTypes —— GSM 存档载荷的[b]类型边界[/b]：写出去归一为 JSON 安全标量，
## 读回来还原为 GSM 内存里的规范类型（纯函数，不碰 GSM / 不碰磁盘）。[br]
## [br][b]为什么必须有一层[/b]：存档是 JSON，而 JSON 只认 String 键与「数字一律是
## float」；GSM 内存里却有几处[b]非 String 键[/b]与 int 数组。实测（Godot 4.6）往返
## 后的失效形态：[br]
##   · [code]visited_nodes[/code] 元素变 float → [code]Array.has(int)[/code] 恒 false
##     （已访问节点可重复进入）；[br]
##   · [code]map_states[..].graph/nodes/harvested[/code] 的 int 键变 String 键 →
##     节点 ID 查不到（可达性判死、节点详情退化、已采记录查不到）；[br]
##   · 标量 int 变 float → [code]GSM.deserialize[/code] 的默认值类型校验拒绝整份存档。[br]
## [br][b]int 键必须还原[/b]：int 键与 String 键是[b]两个不同的键[/b]——往 String 键
## 字典上写 int 键会[b]新增条目[/b]而不是覆盖（实测），于是「已采记录」会分裂成两条。
## String 与 StringName 则双向等价（[code]has[/code] / [code]get[/code] / 赋值都命中
## 同一个键，实测），故本模块[b]不[/b]动它们：改了没有收益，而把数组元素
## String→StringName 会让 [code][&"a"] == ["a"][/code] 变 false（实测），
## 白白改掉既有断言的语义。[br]
## [br][b]为什么还原是「点名」而不是「全量 float→int」[/b]：合法的 float 确实存在
## （掉落概率 [code]chance[/code]、突破成功率），一刀切会把它们压成 int。故本模块只
## 还原[b]声明过的那几处[/b]（见 [method restore_domain]），其余交给读侧的
## [code]int()[/code] / [code]str()[/code] 归一——那些读者本来就宽容（审计逐处核过）。[br]
## [br]来源: ADR-0002 §JSON + 迁移链、ADR-0014 §决策 1 状态分层模型。

## 需要还原成 int 元素的数组路径的「域内声明」（见 [method restore_domain]）。
## 纯文档用途——实际还原在各自的 _restore_* 里就近写，免得路径表与代码两处漂移。

# ═══════════════════════════════════════════════════════════════════════════════
# 写出去：归一为 JSON 安全标量
# ═══════════════════════════════════════════════════════════════════════════════

## 深拷贝并归一为 JSON 安全形态——StringName 键/值 → String，int 键 → String 键。[br]
## [br][b]其他类型原样透传[/b]（含 Vector2 / Color / Object）——本模块不负责拒绝，
## 由 [code]SaveLoadSystem._is_json_compatible[/code] 统一把关（一处报错文案）。[br]
## [br][b]键折叠[/b]：同一层里 [code]1[/code] 与 [code]"1"[/code] 会被折叠成一个 String
## 键（后者覆盖前者）。GSM 内存里每个结构的键类型是同构的，构造不出这种输入。[br]
## [br][param p_value] 任意 GSM 域值。[br]
## [br][b]返回[/b]：仅含 nil/bool/int/float/String/Array/Dictionary 的深拷贝。
static func to_save_safe(p_value: Variant) -> Variant:
	match typeof(p_value):
		TYPE_STRING_NAME:
			return String(p_value)
		TYPE_ARRAY:
			var out_array: Array = []
			var source_array: Array = p_value
			out_array.resize(source_array.size())
			for i: int in range(source_array.size()):
				out_array[i] = to_save_safe(source_array[i])
			return out_array
		TYPE_DICTIONARY:
			var out_dict: Dictionary = {}
			var source_dict: Dictionary = p_value
			for raw_key: Variant in source_dict.keys():
				out_dict[_key_to_save(raw_key)] = to_save_safe(source_dict[raw_key])
			return out_dict
		_:
			return p_value


## 字典键 → JSON 安全键（JSON 对象键只认 String）。[br]
static func _key_to_save(p_key: Variant) -> String:
	if p_key is String:
		return p_key
	return str(p_key)


# ═══════════════════════════════════════════════════════════════════════════════
# 读回来：还原 GSM 内存里的规范类型
# ═══════════════════════════════════════════════════════════════════════════════

## 按域还原规范类型——返回[b]新字典[/b]（不改入参，调用方拿返回值原子替换）。[br]
## [br][b]还原清单[/b]（每一处都对应一个真实读侧，审计逐处核过）：[br]
##   · [code]exploration.visited_nodes[/code] → int 元素（reasons: move_to_node /
##     can_move_to_detail / mark_node_visited / 可达性 p_blocked / 传送落点）；[br]
##   · [code]exploration.map_states[*].graph[/code] → int 键 + int 元素（邻接判定）；[br]
##   · [code]exploration.map_states[*].nodes[/code] → int 键（节点详情 / 层数 / 载荷）；[br]
##   · [code]exploration.map_states[*].harvested[/code] → int 键 + int 元素（已采判定）；[br]
##   · [code]exploration.map_states[*][/code] 的累计标量 → int（通关次数 / 灵泉次数 /
##     已收集资源——读侧本就 [code]int()[/code]，还原是为了「状态等价」断言能直比）；[br]
##   · [code]player.unavailable_characters[/code] → int 键（阵亡名单，备战与名册查它）；[br]
##   · [code]deck.current_deck[/code] → int 元素（移除卡牌的成员判定）；[br]
##   · [code]collection.owned_cards[*][/code] 的 5 个整型字段 → int（状态等价）。[br]
## [br][param p_domain] 域名（非持久域 / 未知域原样返回）。[br]
## [param p_data] 已通过类型校验的域字典。[br]
static func restore_domain(p_domain: String, p_data: Dictionary) -> Dictionary:
	match p_domain:
		"player":
			return _restore_player(p_data)
		"collection":
			return _restore_collection(p_data)
		"deck":
			return _restore_deck(p_data)
		"exploration":
			return _restore_exploration(p_data)
		_:
			return p_data


# ═══════════════════════════════════════════════════════════════════════════════
# 标量：默认值驱动的类型归一（deserialize 的类型校验唯一入口）
# ═══════════════════════════════════════════════════════════════════════════════

## 按默认值类型归一一个标量——返回 [code]{ok, value, expected, actual}[/code]。[br]
## [br][b]放行的跨类型转换[/b]（全部无损）：[br]
##   · 默认 int + 实际 float 且值本来就是整数 → int（JSON 数字一律 float）；[br]
##   · 默认 float + 实际 int → float；[br]
##   · 默认 StringName + 实际 String → StringName；默认 String + 实际 StringName → String。[br]
## [br][b]其余一律拒绝[/b]（[code]ok=false[/code]）——包括「默认 int + 实际 String」，
## 那是真的类型写错，不能静默吞掉（既有断言锁着这条）。[br]
## [br][param p_default] 默认值（类型模板）。[br]
## [param p_input] 存档里的值。[br]
static func coerce(p_default: Variant, p_input: Variant) -> Dictionary:
	var default_type: int = typeof(p_default)
	var input_type: int = typeof(p_input)

	# null 默认值放行——允许未来扩展该字段（既有语义，见 gsm_serializer）
	if default_type == TYPE_NIL:
		return {"ok": true, "value": p_input}

	if input_type == default_type:
		# 非空默认字典 → 逐键递归（嵌套字段同样要过类型关，例：node_position.layer）
		if default_type == TYPE_DICTIONARY and not (p_default as Dictionary).is_empty():
			return coerce_dict(p_input, p_default)
		return {"ok": true, "value": p_input}

	var reject: Dictionary = {
		"ok": false, "value": null,
		"expected": default_type, "actual": input_type,
	}
	if default_type == TYPE_INT and input_type == TYPE_FLOAT:
		var as_int: int = int(p_input)
		if float(as_int) == float(p_input):
			return {"ok": true, "value": as_int}
		return reject
	if default_type == TYPE_FLOAT and input_type == TYPE_INT:
		return {"ok": true, "value": float(p_input)}
	if default_type == TYPE_STRING_NAME and input_type == TYPE_STRING:
		return {"ok": true, "value": StringName(p_input)}
	if default_type == TYPE_STRING and input_type == TYPE_STRING_NAME:
		return {"ok": true, "value": String(p_input)}
	return reject


## 按默认值字典归一整本字典——返回 [code]{ok, value, key, expected, actual}[/code]。[br]
## [br][b]缺失字段用默认值填[/b]（向前兼容），[b]多出来的键原样保留[/b]（未知字段是
## 未来版本的合法内容，丢弃等于读档悄悄丢数据）。[br]
## [br][b]与旧实现的差别[/b]：旧 [code]_type_check[/code] 只比顶层键的
## [code]typeof[/code]，嵌套字段（[code]node_position.layer[/code]、
## [code]resources.ling_shi[/code]）从来不校验也从来不归一——JSON 往返后它们
## 全变 float，靠读侧各自 [code]int()[/code] 兜。[br]
## [br][param p_input] 存档里的子字典。[br]
## [param p_defaults] 该层的默认值字典（类型模板 + 缺失填充来源）。[br]
static func coerce_dict(p_input: Dictionary, p_defaults: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in p_defaults.keys():
		if p_input.has(key):
			var step: Dictionary = coerce(p_defaults[key], p_input[key])
			if not bool(step.get("ok", false)):
				step["key"] = key
				step["value"] = null
				return step
			out[key] = step["value"]
		else:
			out[key] = copy_value(p_defaults[key])
	for key: Variant in p_input.keys():
		if not p_defaults.has(key):
			out[key] = p_input[key]
	return {"ok": true, "value": out, "key": "", "expected": 0, "actual": 0}


## 递归深拷贝——仅供默认值填充用（默认值树里含嵌套字典/数组）。[br]
static func copy_value(p_value: Variant) -> Variant:
	if p_value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in (p_value as Dictionary).keys():
			out[key] = copy_value((p_value as Dictionary)[key])
		return out
	if p_value is Array:
		var out_array: Array = []
		for item: Variant in (p_value as Array):
			out_array.append(copy_value(item))
		return out_array
	return p_value


# ═══════════════════════════════════════════════════════════════════════════════
# 数值归一助手
# ═══════════════════════════════════════════════════════════════════════════════

## 数值原样转 int——[b]非数值原样返回[/b]。[br]
## [br][b]为什么不直接 [code]int(v)[/code][/b]：对 String 它静默给 0（
## [code]int("char_1") == 0[/code]）——[code]deck.slots[/code] 里既有角色实例 ID
## 也有非数字占位串，压成 0 等于凭空造出一个「0 号角色」。[br]
static func numeric(p_value: Variant) -> Variant:
	if p_value is int:
		return p_value
	if p_value is float:
		return int(p_value) if float(int(p_value)) == float(p_value) else p_value
	if p_value is String and (p_value as String).is_valid_int():
		return (p_value as String).to_int()
	return p_value


## 数组元素逐个过 [method numeric]（非数组入参原样返回——脏数据不至于让读档崩）。[br]
static func numeric_array(p_value: Variant) -> Variant:
	if not (p_value is Array):
		return p_value
	var out: Array = []
	for item: Variant in (p_value as Array):
		out.append(numeric(item))
	return out


## 字典键逐个过 [method numeric]（值原样保留）。[br]
## [br][b]本模块存在的理由就在这里[/b]：JSON 把 int 键写成 String 键，读回来若不还原，
## 往同一个结构里写 int 键会新增条目而不是覆盖（实测）。[br]
static func numeric_keyed(p_value: Variant) -> Variant:
	if not (p_value is Dictionary):
		return p_value
	var out: Dictionary = {}
	for raw_key: Variant in (p_value as Dictionary).keys():
		var key: Variant = numeric(raw_key)
		out[key] = (p_value as Dictionary)[raw_key]
	return out


# ═══════════════════════════════════════════════════════════════════════════════
# 逐域还原
# ═══════════════════════════════════════════════════════════════════════════════

## player 域——阵亡名单还原 int 键（备战 / 名册读侧按角色 ID 判）。[br]
static func _restore_player(p_data: Dictionary) -> Dictionary:
	var out: Dictionary = p_data.duplicate(true)
	if out.has("unavailable_characters"):
		var restored: Variant = numeric_keyed(out["unavailable_characters"])
		if restored is Dictionary:
			out["unavailable_characters"] = restored
	return out


## collection 域——卡牌实例的 5 个整型字段还原 int（状态等价可直比）。[br]
static func _restore_collection(p_data: Dictionary) -> Dictionary:
	var out: Dictionary = p_data.duplicate(true)
	var cards: Variant = out.get("owned_cards", [])
	if not (cards is Array):
		return out
	for i: int in range((cards as Array).size()):
		var entry: Variant = (cards as Array)[i]
		if not (entry is Dictionary):
			continue
		for key: String in INT_CARD_FIELDS:
			if (entry as Dictionary).has(key):
				(entry as Dictionary)[key] = numeric((entry as Dictionary)[key])
	return out


## deck 域——当前卡组还原 int 元素（移除卡牌的成员判定按数值比）。[br]
static func _restore_deck(p_data: Dictionary) -> Dictionary:
	var out: Dictionary = p_data.duplicate(true)
	if out.has("current_deck"):
		out["current_deck"] = numeric_array(out["current_deck"])
	if out.has("slots"):
		out["slots"] = numeric_array(out["slots"])
	return out


## exploration 域——已访问节点 / 各图快照的 int 键与 int 元素。图形键统一为
## StringName（写侧 [code]update_exploration_map_state[/code] 用的就是它）。[br]
static func _restore_exploration(p_data: Dictionary) -> Dictionary:
	var out: Dictionary = p_data.duplicate(true)
	if out.has("visited_nodes"):
		out["visited_nodes"] = numeric_array(out["visited_nodes"])
	if out.has("map_states"):
		out["map_states"] = _restore_map_states(out["map_states"])
	return out


## map_states 整体——外层键（地图 ID）还原 StringName，子条目逐个还原。[br]
static func _restore_map_states(p_value: Variant) -> Variant:
	if not (p_value is Dictionary):
		return p_value
	var out: Dictionary = {}
	for raw_key: Variant in (p_value as Dictionary).keys():
		var state: Variant = (p_value as Dictionary)[raw_key]
		out[StringName(str(raw_key))] = _restore_map_state(state) \
				if state is Dictionary else state
	return out


## 单张地图的状态条目——graph / nodes / harvested 三类 int 键结构 + 累计标量。[br]
static func _restore_map_state(p_value: Variant) -> Variant:
	if not (p_value is Dictionary):
		return p_value
	var out: Dictionary = (p_value as Dictionary).duplicate(true)
	# 邻接表：int 键 + int 元素数组
	if out.has("graph"):
		var graph: Variant = numeric_keyed(out["graph"])
		if graph is Dictionary:
			for key: Variant in (graph as Dictionary).keys():
				(graph as Dictionary)[key] = numeric_array((graph as Dictionary)[key])
			out["graph"] = graph
	# 节点详情：int 键（子字典内容交给读侧归一——`type` 等字段读侧都有 int()）
	if out.has("nodes"):
		out["nodes"] = numeric_keyed(out["nodes"])
	# 已采槽位：int 键 + int 元素数组
	if out.has("harvested"):
		var harvested: Variant = numeric_keyed(out["harvested"])
		if harvested is Dictionary:
			for key: Variant in (harvested as Dictionary).keys():
				(harvested as Dictionary)[key] = numeric_array((harvested as Dictionary)[key])
			out["harvested"] = harvested
	# 纯 int 数组字段（已弹事件节点等）——元素不还原成 int 的话
	# [code]Array.has(int)[/code] 恒 false（同一事件会重复弹出）
	for key: String in INT_MAP_STATE_ARRAYS:
		if out.has(key):
			out[key] = numeric_array(out[key])
	# 累计标量（通关次数 / 灵泉次数 / 进入次数 / 已收集资源）
	for key: String in INT_MAP_STATE_FIELDS:
		if out.has(key):
			out[key] = numeric(out[key])
	return out


## 卡牌实例的整型字段（与 [code]CardSerializer[/code] 的 int 字段口径同源）。[br]
const INT_CARD_FIELDS: Array[String] = [
	"card_instance_id", "level", "breakthrough_layers",
	"acquired_chapter", "acquired_method",
]

## map_state 里语义为「计数」的整型字段（[code]is_first_clear[/code] 是 bool，
## 不在此列——bool 由类型校验把关，不该由本模块压）。[br]
const INT_MAP_STATE_FIELDS: Array[String] = [
	"entry_count", "clear_count", "action_spring_uses",
	"collected_ling_shi", "collected_cultivation",
]

## map_state 里元素为 int 的数组字段——元素不还原成 int 时
## [code]Array.has(int)[/code] 恒 false（[code]events_shown[/code]：
## 同一事件节点读档后会再弹一次，奖励再发一次）。[br]
## [br][b]为什么用数组而不是字典存[/b]：int 键的字典经 JSON 后键变 String，
## 还原要额外一层；数组元素由 [method numeric_array] 天然还原。[br]
const INT_MAP_STATE_ARRAYS: Array[String] = [
	"events_shown",
]
