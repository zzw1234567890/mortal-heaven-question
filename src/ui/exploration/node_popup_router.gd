extends RefCounted
## NodePopupRouter —— 弹窗路由的载荷组装（kind + 载荷 → 弹窗该显示什么）。[br]
## [br][b]为什么单独一处[/b]：[code]node_interaction_popup_host.gd[/code] 已贴 300 行
## 软上限（.claude/docs/coding-standards.md），而「到达信号 + 渲染快照 → 节点 ID /
## 正文行 / 警示行 / 待用名册」是一次纯数据组装——宿主拿结果只需写自己的瞬态字段
## 再调 [code]_show[/code]。拆出来后这层可脱开控件树单测。[br]
## [br][b]为什么地图名在这里查探明表[/b]：快照里只有地图 ID（节点图渲染不需要中文名），
## 而 [code]ExplorationMapCatalog[/code] 是「地图 ID → 中文名」的唯一真理来源——
## 在这里查一次，比让 [code]enter_map[/code] 多塞一个只服务弹窗的字段更省事。[br]
## [br][b]零状态纯函数[/b]（ADR-0031 §2）：不读 Autoload、不写任何状态。[br]
##
## 来源: design/gdd/exploration-ui-system.md §4/§4b/§5、
## ADR-0014 §决策 3、ADR-0031 §2。

## 弹窗文案内核（kind / 正文行 / 警示行 / 地图名前缀的唯一实现）。
const Rules := preload("res://src/ui/exploration/node_interaction_rules.gd")
## 遭遇字段契约（与 DAG 生成器、开战上下文读同一份节点数据）。
const Fields := preload("res://assets/enemies/encounter_fields.gd")
## 地图探明表（地图 ID → 中文名）。
const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")

## 载荷键（宿主与测试共用——不裸写字符串）。
const KEY_NODE_ID: String = "node_id"
const KEY_KIND: String = "kind"
const KEY_LINES: String = "lines"
const KEY_WARNING: String = "warning"
const KEY_COMBAT_TYPE: String = "combat_type"
const KEY_ROSTER: String = "roster"
const KEY_ENCOUNTER: String = "encounter"
const KEY_INVENTORY: String = "inventory"


## 组装一次弹窗载荷（五类 kind 共用入口）。[br]
## [br][param p_snapshot] 渲染快照（[code]map_id[/code] 供取中文名、
## [code]nodes[/code] 为遭遇数据源）。[br]
## [param p_node_id] 到达信号的节点 ID（[b]以调用方为准[/b]：快照的
## [code]current_node[/code] 只是缺省回退——交互信号带的首参才是这一格的真相，
## 两者在「先移动后弹窗」的窗口期内可能不同）。[br]
## [param p_interaction_type] 到达信号的交互类型（进战斗的 token 即取自它）。[br]
## [param p_payload] 到达信号载荷。[br]
## [param p_max_deploy] 当前境界上场人数上限（UI 不推算，由宿主查询后传入）。[br]
## [br][b]返回[/b]：见 [constant KEY_NODE_ID] 等键——键齐全（不适用的项为空值），
## 宿主按需取用，不必判断键是否存在。[br]
## [br][b]未列出的 kind[/b]（[constant NodeInteractionRules.KIND_NONE]）：除节点 ID
## 外全为空值——宿主据此不开窗。
static func route(p_snapshot: Dictionary, p_node_id: int,
		p_interaction_type: StringName, p_payload: Dictionary,
		p_max_deploy: int) -> Dictionary:
	var kind: StringName = Rules.popup_kind_for(p_interaction_type)
	var result: Dictionary = _empty(p_node_id, kind)
	match kind:
		Rules.KIND_COMBAT:
			_fill_combat(result, p_snapshot, p_interaction_type, p_payload, p_max_deploy)
		Rules.KIND_BOSS:
			_fill_boss(result, p_snapshot, p_payload, p_max_deploy)
		Rules.KIND_SHOP:
			result[KEY_INVENTORY] = (p_payload.get("inventory", {}) as Dictionary).duplicate(true)
		Rules.KIND_TRIBULATION:
			result[KEY_WARNING] = Rules.tribulation_warning_lines()
	return result


## 组装 Boss 弹窗载荷（[code]boss_node_reached[/code] 直达入口——不经分发表）。[br]
## [br][b]为什么另开一条[/b]：Boss 到达信号的载荷里没有 [code]interaction_type[/code]
## （节点类型本身就是 boss），走 [method route] 要先伪造一个类型再查表，绕。[br]
## [br][b]节点 ID 优先级[/b]：载荷显式 [code]node_id[/code] > [param p_node_id]
## （控件宿主可传快照当前节点）——Boss 信号自带首参，故通常走前者。
static func route_boss(p_snapshot: Dictionary, p_node_id: int,
		p_boss_data: Dictionary, p_max_deploy: int) -> Dictionary:
	var node_id: int = p_node_id
	if p_boss_data.has("node_id"):
		node_id = int(p_boss_data.get("node_id", p_node_id))
	var result: Dictionary = _empty(node_id, Rules.KIND_BOSS)
	_fill_boss(result, p_snapshot, p_boss_data, p_max_deploy)
	return result


## 空载荷骨架（键齐全——调用方不必判断键是否存在）。
static func _empty(p_node_id: int, p_kind: StringName) -> Dictionary:
	return {
		KEY_NODE_ID: p_node_id,
		KEY_KIND: p_kind,
		KEY_LINES: [],
		KEY_WARNING: [],
		KEY_COMBAT_TYPE: &"combat",
		KEY_ROSTER: [],
		KEY_ENCOUNTER: {},
		KEY_INVENTORY: {},
	}


## 战斗/精英弹窗（GDD §4 线框：敌人 → 境界 → 推荐上场）。[br]
## [br][b]战斗类型取自到达类型[/b]（[code]combat[/code] / [code]elite[/code]）——
## 它随后要折进开战上下文，是「这场战斗算不算精英档」的唯一标记。
static func _fill_combat(p_result: Dictionary, p_snapshot: Dictionary,
		p_type: StringName, p_payload: Dictionary, p_max_deploy: int) -> void:
	p_result[KEY_COMBAT_TYPE] = p_type
	var roster: Array = Fields.roster_copy(p_payload.get("enemy_roster", []))
	var encounter: Dictionary = _encounter(p_snapshot, int(p_result[KEY_NODE_ID]))
	p_result[KEY_ROSTER] = roster
	p_result[KEY_ENCOUNTER] = encounter
	p_result[KEY_LINES] = Rules.combat_lines_for_encounter(encounter, roster,
			p_max_deploy, int(p_payload.get("recommended_deploy", 0)))


## Boss 弹窗（GDD §5 独立规格：地图 → 敌人 → 境界 → 推荐上场 + 战败警示）。
static func _fill_boss(p_result: Dictionary, p_snapshot: Dictionary,
		p_data: Dictionary, p_max_deploy: int) -> void:
	var roster: Array = Fields.roster_copy(p_data.get("enemy_roster", []))
	var encounter: Dictionary = _encounter(p_snapshot, int(p_result[KEY_NODE_ID]))
	p_result[KEY_COMBAT_TYPE] = Rules.KIND_BOSS
	p_result[KEY_ROSTER] = roster
	p_result[KEY_ENCOUNTER] = encounter
	p_result[KEY_LINES] = Rules.boss_body_lines(map_name(p_snapshot), encounter,
			roster, p_max_deploy)
	p_result[KEY_WARNING] = Rules.boss_warning_lines()


## 节点遭遇的规范化读取（与开战上下文同源）。
static func _encounter(p_snapshot: Dictionary, p_node_id: int) -> Dictionary:
	return Fields.of_snapshot(p_snapshot, p_node_id)


## 当前地图中文名（快照 [code]map_id[/code] 经探明表取名）。[br]
## [br][b]空串语义[/b]：无地图上下文 / 未知地图返回空串，正文组装会把该行整行
## 省略——不在弹窗上显示一个占位名。
static func map_name(p_snapshot: Dictionary) -> String:
	var map_id: StringName = StringName(str(p_snapshot.get("map_id", "")))
	if map_id == &"":
		return ""
	return str(CatalogScript.config_for(map_id).get("name", ""))
