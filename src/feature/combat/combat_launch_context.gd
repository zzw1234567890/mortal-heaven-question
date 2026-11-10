extends RefCounted
## CombatLaunchContext —— 探索→战斗的开战上下文（跨场景传递 + 契约校验）。[br]
## [br][b]职责[/b]：把「探索节点点进战斗」需要的四份输入从 UI 场景带到战斗场景——[br]
##   1. [b]敌方阵容[/b]：节点生成时确定的模板 ID 列表（战斗侧据此重建运行时名册）；[br]
##   2. [b]敌方等级[/b]：节点遭遇的基准境界（展示与缩放口径）；[br]
##   3. [b]掉落[/b]：本场胜利奖励 [code]{lingshi, cultivation, cards}[/code]；[br]
##   4. [b]玩家出战阵容[/b]：进入战斗时玩家当前的阵容（备战面板预选）。[br]
## [br][b]为什么用 static var[/b]：战斗场景是独立 .tscn，实例化时探索场景已释放；
## 项目内跨场景轻量缓存的既有口径即 static var（同 [code]CombatResultView._last[/code]）。[br]
## [br][b]为什么不在战斗侧兜底默认遭遇[/b]：上一轮战斗场景在无注入时读
## [code]default_encounter.tres[/code]，导致「探索点哪一格都打同一批敌人」。
## 本模块把「没有配置」变成可读失败（[method validate]），而不是静默兜底。[br]
## [br][b]写入口[/b]：探索侧弹窗确认（[code]node_interaction_popup_host.gd[/code]）；
## [b]读出口[/b]：[method take] 一次性消费（战斗场景 [code]_ready[/code]）。[br]
##
## 来源: ADR-0014 §决策 3 信号委托、ADR-0031 §2 零状态所有权、
## exploration-system.md §3 步骤⑥（战斗节点阵容在节点生成时确定）。

## 上下文键（单一真理来源——消费方不裸写字符串）。
const KEY_NODE_ID: String = "node_id"
const KEY_COMBAT_TYPE: String = "combat_type"
const KEY_ENCOUNTER_ID: String = "encounter_id"
const KEY_DISPLAY_NAME: String = "display_name"
const KEY_TEMPLATE_IDS: String = "enemy_template_ids"
const KEY_ENEMY_ROSTER: String = "enemy_roster"
const KEY_ENEMY_LEVEL: String = "enemy_level"
const KEY_REWARDS: String = "rewards"
const KEY_PLAYER_ROSTER: String = "player_roster"

## 待消费的上下文（null/空 = 无探索侧上下文）。
static var _pending: Dictionary = {}


## 构造上下文——从节点详情 + 运行时名册 + 玩家阵容合并出四份输入。[br]
## [br][param p_node_id] 探索节点 ID。[br]
## [param p_combat_type] [code]&"combat"[/code] / [code]&"elite"[/code]。[br]
## [param p_roster] 节点到达信号携带的敌方名册（运行时实例或预览字典）。[br]
## [param p_player_roster] 玩家当前出战阵容（角色实例 ID）。[br]
## [param p_detail] 节点详情（可含 [code]encounter[/code] 子字典——显式配置优先）。[br]
## [param p_lookup] 模板查询闭包 [code]func(template_id) -> Resource[/code]（可空）。[br]
static func build(p_node_id: int, p_combat_type: StringName, p_roster: Array,
		p_player_roster: Array, p_detail: Dictionary = {},
		p_lookup: Callable = Callable()) -> Dictionary:
	var encounter: Dictionary = _encounter_of(p_detail)
	var template_ids: Array = _template_ids(encounter, p_roster)
	var level: int = int(encounter.get("enemy_level", 0))
	if level <= 0:
		level = _enemy_level(p_roster, p_lookup)
	var rewards: Dictionary = _rewards_of(encounter, p_roster, p_lookup)
	return {
		KEY_NODE_ID: p_node_id,
		KEY_COMBAT_TYPE: p_combat_type,
		KEY_ENCOUNTER_ID: str(encounter.get("encounter_id", "")),
		KEY_DISPLAY_NAME: str(encounter.get("display_name", _detail_label(p_detail))),
		KEY_TEMPLATE_IDS: template_ids,
		KEY_ENEMY_ROSTER: p_roster.duplicate(),
		KEY_ENEMY_LEVEL: level,
		KEY_REWARDS: rewards,
		KEY_PLAYER_ROSTER: _int_list(p_player_roster),
	}


## 发布上下文（探索侧弹窗确认时调用；覆盖上一份未消费的上下文）。[br]
## [br][b]可序列化约束[/b]：只保留 JSON 兼容类型——上下文要跨场景缓存，而战斗场景
## 会把它折进 [code]battle_start[/code] 配置（可能进存档）。运行时对象
## （[code]EnemyBattleState[/code]）与 [code]StringName[/code] 键会在
## [code]JSON.stringify[/code] 处静默失败，故发布时先净化。
static func publish(context: Dictionary) -> void:
	_pending = _sanitize(context) if context is Dictionary else {}


## 净化——键转 String、丢弃运行时对象（对象/资源不进跨场景缓存）。[br]
## [br][b]为什么保留 StringName 值[/b]：模板 ID 是 [code]AISystem[/code] 注册表的
## 键类型；转成 String 后虽仍能查表，但语义上与「模板 ID 是 StringName」的既有
## 契约不一致。[br]
## [br][b]为什么不用 GSM 的 [code]_deep_copy[/code][/b]：那份实现保留对象引用，
## 而这里要的恰恰是「丢掉不能跨场景传递的东西」。
static func _sanitize(p_value: Variant) -> Variant:
	match typeof(p_value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return p_value
		TYPE_ARRAY:
			var array: Array = []
			for item: Variant in p_value:
				var clean: Variant = _sanitize(item)
				if clean != null:
					array.append(clean)  # 对象条目落成 null——不占位
			return array
		TYPE_DICTIONARY:
			var dictionary: Dictionary = {}
			for key: Variant in (p_value as Dictionary).keys():
				dictionary[str(key)] = _sanitize((p_value as Dictionary)[key])
			return dictionary
		_:
			return null


## 一次性取走上下文（战斗场景 _ready 消费；取后清空，防下一场串用）。
static func take() -> Dictionary:
	var context: Dictionary = _pending
	_pending = {}
	return context


## 查看当前待消费的上下文（测试/预览用——不消费）。
static func peek() -> Dictionary:
	return _pending.duplicate(true)


## 清空上下文（测试隔离 / 放弃进入战斗）。
static func clear() -> void:
	_pending = {}


## 契约校验——返回空串表示可开战，否则返回可读的缺失项说明。[br]
## [br][b]为什么玩家阵容也要求非空[/b]：探索侧进入战斗前玩家必然有阵容；
## 为空说明上下文在传递途中丢了字段，此时开战会静默退化成「面板全空」。
static func validate(context: Dictionary) -> String:
	if context.is_empty():
		return "未收到探索侧开战上下文（CombatLaunchContext 为空）"
	var problems: Array[String] = []
	if not _non_empty_array(context.get(KEY_TEMPLATE_IDS)) \
			and not _non_empty_array(context.get(KEY_ENEMY_ROSTER)):
		problems.append("缺少敌方阵容（enemy_template_ids / enemy_roster 均为空）")
	if not _non_empty_array(context.get(KEY_PLAYER_ROSTER)):
		problems.append("缺少玩家出战阵容（player_roster 为空）")
	if problems.is_empty():
		return ""
	return "；".join(PackedStringArray(problems))


## 战斗标题——显式名称优先，缺失时回退调用方给的默认标题。
static func title(context: Dictionary, p_fallback: String) -> String:
	var name: String = str(context.get(KEY_DISPLAY_NAME, ""))
	return name if not name.is_empty() else p_fallback


## === 派生（节点详情 > 名册条目 > 模板）=====================================

## 节点详情里的显式遭遇配置（缺失/类型不符时为空字典）。
static func _encounter_of(p_detail: Dictionary) -> Dictionary:
	var raw: Variant = p_detail.get("encounter", {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


## 敌方模板 ID——显式配置优先，否则从名册条目派生。[br]
## [br][b]统一成 StringName[/b]：显式配置与派生两条路径的产物必须同型——
## [code]AISystem.create_enemy_roster[/code] 按 StringName 查模板注册表，
## 混入 String 会变成「模板不存在」。
static func _template_ids(p_encounter: Dictionary, p_roster: Array) -> Array:
	var explicit: Variant = p_encounter.get("enemy_template_ids", [])
	if explicit is Array:
		var listed: Array = []
		for raw: Variant in explicit:
			var tid: StringName = StringName(str(raw))
			if tid != &"":
				listed.append(tid)  # 显式列表保留重复——「散修 ×2」就是两名敌人
		if not listed.is_empty():
			return listed
	var derived: Array = []
	for entry: Variant in p_roster:
		var tid: StringName = _entry_template_id(entry)
		if tid != &"" and not derived.has(tid):
			derived.append(tid)  # 派生路径按模板去重（名册里的实例 ID 才有数量语义）
	return derived


## 敌方基准等级——名册条目的最大境界（无数据返回 0，不臆造）。
static func _enemy_level(p_roster: Array, p_lookup: Callable) -> int:
	var level: int = 0
	for entry: Variant in p_roster:
		level = maxi(level, _entry_realm(entry, p_lookup))
	return level


## 掉落——显式配置 > 名册条目自带的 [code]rewards[/code] > 模板 reward_config 聚合。[br]
## [br][b]灵石取区间中值[/b]：节点生成时不掷骰，保证同节点重复进入口径稳定。
static func _rewards_of(p_encounter: Dictionary, p_roster: Array,
		p_lookup: Callable) -> Dictionary:
	var explicit: Variant = p_encounter.get("rewards", {})
	if explicit is Dictionary and not (explicit as Dictionary).is_empty():
		return (explicit as Dictionary).duplicate(true)
	var lingshi: int = 0
	var cultivation: int = 0
	var cards: Array = []
	for entry: Variant in p_roster:
		var entry_rewards: Variant = _entry_field(entry, "rewards")
		if entry_rewards is Dictionary:
			lingshi += int((entry_rewards as Dictionary).get("lingshi", 0))
			cultivation += int((entry_rewards as Dictionary).get("cultivation", 0))
			_append_cards(cards, (entry_rewards as Dictionary).get("cards", []))
			continue
		var config: Variant = _entry_reward_config(entry, p_lookup)
		if config == null:
			continue
		var lo: int = int(config.get("ling_shi_min"))
		var hi: int = int(config.get("ling_shi_max"))
		lingshi += int(round((float(lo) + float(hi)) * 0.5))
		cultivation += int(config.get("cultivation_reward"))
		_append_cards(cards, config.get("card_drops", []))
	if lingshi <= 0 and cultivation <= 0 and cards.is_empty():
		return {}
	return {"lingshi": lingshi, "cultivation": cultivation, "cards": cards}


## 追加卡牌掉落条目（字典深拷贝；非字典忽略）。
static func _append_cards(p_cards: Array, p_source: Variant) -> void:
	if not (p_source is Array):
		return
	for item: Variant in p_source:
		if item is Dictionary:
			p_cards.append((item as Dictionary).duplicate(true))


## 条目模板 ID——对象读 [code]template.template_id[/code]；字典读 [code]template_id[/code]。
static func _entry_template_id(p_entry: Variant) -> StringName:
	if p_entry is Object and p_entry != null:
		var template: Variant = (p_entry as Object).get("template")
		if template is Object and template != null:
			return StringName(str((template as Object).get("template_id")))
		return &""
	if p_entry is Dictionary:
		return StringName(str((p_entry as Dictionary).get("template_id", "")))
	return &""


## 条目境界——对象读 template.realm；字典读 [code]realm[/code]（可经模板查询补）。
static func _entry_realm(p_entry: Variant, p_lookup: Callable) -> int:
	if p_entry is Object and p_entry != null:
		var template: Variant = (p_entry as Object).get("template")
		return int((template as Object).get("realm")) if template is Object and template != null else 0
	if p_entry is Dictionary:
		var direct: int = int((p_entry as Dictionary).get("realm", 0))
		if direct > 0:
			return direct
		var template: Variant = _lookup_template(_entry_template_id(p_entry), p_lookup)
		return int(template.get("realm")) if template != null else 0
	return 0


## 条目奖励配置——对象读 template.reward_config；字典按 template_id 查模板。
static func _entry_reward_config(p_entry: Variant, p_lookup: Callable) -> Variant:
	var template: Variant = null
	if p_entry is Object and p_entry != null:
		template = (p_entry as Object).get("template")
	elif p_entry is Dictionary:
		template = _lookup_template(_entry_template_id(p_entry), p_lookup)
	if template == null:
		return null
	return template.get("reward_config")


## 字典条目的任意字段（对象条目返回 null——字段读取只服务预览字典）。
static func _entry_field(p_entry: Variant, p_field: String) -> Variant:
	if p_entry is Dictionary:
		return (p_entry as Dictionary).get(p_field)
	return null


## 模板查询——闭包无效时返回 null（不臆造模板）。
static func _lookup_template(p_id: StringName, p_lookup: Callable) -> Variant:
	if p_id == &"" or not p_lookup.is_valid():
		return null
	return p_lookup.call(p_id)


## 节点展示名——encounter.display_name > description > label。
static func _detail_label(p_detail: Dictionary) -> String:
	for key: String in ["description", "label"]:
		var text: String = str(p_detail.get(key, ""))
		if not text.is_empty():
			return text
	return ""


## 角色 ID 列表规范化（只保留正整数，去重）。
static func _int_list(p_ids: Array) -> Array:
	var result: Array = []
	for raw: Variant in p_ids:
		var cid: int = int(raw)
		if cid > 0 and not result.has(cid):
			result.append(cid)
	return result


## 数组非空判定（非 Array / 空数组均为 false）。
static func _non_empty_array(p_value: Variant) -> bool:
	return p_value is Array and not (p_value as Array).is_empty()
