extends RefCounted
## ExplorationBreakthroughStatus —— 打坐/洞府突破的[b]只读半边[/b]：状态查询、
## 属性快照、结果形状与系统接入。[br]
## [br][b]为什么拆两半[/b]：「现在能不能突破、代价多少、属性几何」（读）与
## 「掷骰、扣修为、升境界」（写）是两件事；且写半边守住 300 行软上限
## （.claude/docs/coding-standards.md）。同 [code]exploration_craft.gd[/code] ↔
## [code]exploration_craft_list.gd[/code] 的分工先例。[br]
## [br][b]数值一律读配置，不硬编码等级与所需修为[/b]：所需修为 / 境界名 / 最高境界 /
## 各项属性上限全来自[b]既有境界配置表[/b] [code]RealmSystem.realm_table[/code]
## （读取面收在 [code]ExplorationBreakthroughTable[/code]）；[code]realm_table[/code]
## 只管静态属性（其 12 个键被既有测试锁死），突破的随机性参数另表承载。[br]
## [br][b]随机源可注入[/b]：[member rng] 由调用方注入（生产随机实例、测试固定种子）
## ——同 [code]exploration_craft.gd[/code] 口径。没注入时自建并
## [method RandomNumberGenerator.randomize]，绝不退回「不掷骰」。[br]
## [br][b]属性从哪来[/b]：全部是 [code]get_realm_property[/code] 的查询值——本层
## 不推算任何境界数值（[method attributes_of] 只是把查询结果拼成一份快照，
## UI 与测试据此断言「属性按配置重算」）。[br]
## [br]来源: design/gdd/cultivation-system.md §6 突破后修为处理 / §边界、
## docs/decisions/ADR-0010 §realm_up 编排器、
## 先例 [code]exploration_craft.gd[/code] / [code]exploration_harvest.gd[/code]。

## 配置读取面与文案单点（成功率 / 惩罚比例 / 所需修为 / 境界名）。
const TableScript := preload("res://src/feature/exploration/exploration_breakthrough_table.gd")

## 突破成功后随返回值下发的属性键（[code]realm_table[/code] 的查询项——
## 「属性按配置重算」的实证面，UI 与测试都读它，不自己查表）。
const ATTRIBUTE_KEYS: Array = ["max_cultivation", "max_deploy", "deck_limit",
		"action_points", "card_pool_tier", "gongfa_slots", "fabao_slots"]

## 依赖注入（测试用桩；null 时按 Autoload 查找）。
var realm_system: Node = null
var cultivation_system: Node = null
var gsm: Node = null
## 成功率掷骰的随机源——由调用方注入（生产为随机实例，测试注入固定种子）。
var rng: RandomNumberGenerator = null

## 父节点引用——ExplorationSystem 实例（GSM 与 Autoload 的入口）。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


# ═══════════════════════════════════════════════════════════════════════════════
# 只读状态（面板的唯一数据源——每次现取即刷新）
# ═══════════════════════════════════════════════════════════════════════════════

## 当前突破状态——不修改任何状态。[br]
## [br][b]返回[/b]：[code]{can_breakthrough, reason, message, realm, next_realm,
## realm_name, next_realm_name, headline, cultivation, max_cultivation, required,
## success_rate, penalty, at_max, action_text, status_lines}[/code]；文案已由本层
## 格式化好（UI 零数值计算）。[br]
## [br][b]不可突破时不臆造数值[/b]：[code]success_rate[/code] 与 [code]penalty[/code]
## 仍按配置给出（面板可展示代价），[code]can_breakthrough=false[/code] 且
## [code]reason[/code] / [code]message[/code] 说明原因。
func status() -> Dictionary:
	var store: Node = _gsm()
	if store == null:
		return unavailable("GSM 不可用")
	var player: Dictionary = store.get(&"player")
	var realm: int = int(player.get("realm", 1))
	var cultivation: int = int(player.get("cultivation", 0))
	var max_cult: int = int(player.get("max_cultivation", 0))
	var required: int = TableScript.required_cultivation(realm)
	var at_max: bool = realm >= TableScript.max_realm()
	var out: Dictionary = {
		"can_breakthrough": false,
		"reason": "",
		"message": "",
		"realm": realm,
		"next_realm": realm + 1,
		"realm_name": TableScript.realm_name(realm),
		"next_realm_name": TableScript.realm_name(realm + 1),
		"headline": "" if at_max else TableScript.headline(realm),
		"cultivation": cultivation,
		"max_cultivation": max_cult,
		"required": required,
		"success_rate": TableScript.success_rate_for(realm),
		"penalty": TableScript.penalty_for(realm, max_cult),
		"at_max": at_max,
		"action_text": "",
		"status_lines": [],
	}
	if at_max:
		out["reason"] = TableScript.TEXT_AT_MAX
		out["message"] = TableScript.TEXT_AT_MAX
		return out
	if required <= 0:
		out["reason"] = "no_config"
		out["message"] = "境界配置缺失，无法突破"
		return out
	out["action_text"] = TableScript.action_text(realm, required)
	out["status_lines"] = TableScript.status_lines(cultivation, max_cult,
			required, int(out["penalty"]))
	if cultivation < required:
		out["reason"] = "not_enough"
		out["message"] = TableScript.TEXT_NOT_ENOUGH % [cultivation, required]
		return out
	out["can_breakthrough"] = true
	return out


## 各属性在指定境界的取值（[code]realm_table[/code] 的查询快照——不推算）。[br]
## [br][b]返回[/b]：[code]{key: value}[/code]；境界不在表中时为空字典（不臆造）。
func attributes_of(p_level: int) -> Dictionary:
	var out: Dictionary = {}
	for key: String in ATTRIBUTE_KEYS:
		var value: Variant = _realm_query(p_level, key)
		if value != null:
			out[key] = value
	return out


# ═══════════════════════════════════════════════════════════════════════════════
# 结果形状（结算与拒绝共用一套键——面板只读 message）
# ═══════════════════════════════════════════════════════════════════════════════

## 拒绝结果——[b]未掷骰、未写入[/b]（[code]rolled=false[/code] 是「被拒」与
## 「掷骰失败」的区分点）。[br]
## [br][param p_reason] 机器可读原因。[param p_message] 面向玩家的中文提示。
func reject(p_reason: String, p_message: String, p_realm: int,
		p_cultivation: int) -> Dictionary:
	return {
		"success": false,
		"reason": p_reason,
		"message": p_message,
		"rolled": false,
		"realm_before": p_realm,
		"realm_after": p_realm,
		"cultivation_before": p_cultivation,
		"cultivation_after": p_cultivation,
		"spent": 0,
		"penalty": 0,
		"attributes": attributes_of(p_realm),
		"cultivation_full": false,
	}


## 系统缺失时的状态（面板显示可读原因而非崩溃）。
func unavailable(p_reason: String) -> Dictionary:
	return {
		"can_breakthrough": false, "reason": p_reason, "message": p_reason,
		"realm": 0, "next_realm": 0, "realm_name": "", "next_realm_name": "",
		"headline": "", "cultivation": 0, "max_cultivation": 0, "required": 0,
		"success_rate": 0.0, "penalty": 0, "at_max": false,
		"action_text": "", "status_lines": [],
	}


# ═══════════════════════════════════════════════════════════════════════════════
# 系统接入（子类沿用——结算与查询走同一套查找口径）
# ═══════════════════════════════════════════════════════════════════════════════

## RNG 实例——注入优先，否则自建一个随机种子的（生产路径）。
func rng_instance() -> RandomNumberGenerator:
	if rng != null:
		return rng
	var generator := RandomNumberGenerator.new()
	generator.randomize()
	return generator


## 境界表查询——经 RealmSystem（注入优先），缺失时退到配置读取面的静态表。
func _realm_query(p_level: int, p_key: String) -> Variant:
	var rs: Node = _realm_system()
	if rs != null and rs.has_method(&"get_realm_property"):
		return rs.call(&"get_realm_property", p_level, StringName(p_key))
	var table: Dictionary = TableScript.RealmSystemScript.realm_table
	if not table.has(p_level):
		return null
	return (table[p_level] as Dictionary).get(p_key)


func _realm_system() -> Node:
	return realm_system if realm_system != null else _autoload(&"RealmSystem")


## 修为系统——用于「上限重算是否有人接」的可用性告警（重算由它订阅
## [code]realm_changed[/code] 完成，本层不代算）。
func _cultivation_system() -> Node:
	return cultivation_system if cultivation_system != null \
			else _autoload(&"CultivationSystem")


func _gsm() -> Node:
	if gsm != null:
		return gsm
	if _parent != null and _parent.has_method(&"_get_gsm"):
		return _parent.call(&"_get_gsm")
	return _autoload(&"GameStateManager")


## Autoload 动态查找（测试环境缺 Autoload 时返回 null）。
static func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))
