extends RefCounted
## CharacterStatusModel —— 角色状态界面的只读取数半边（境界 / 修为 / 生命 / 属性 / 阵亡）。[br]
## [br][b]三块数据，各有各的归属[/b]：[br]
##   · [b]境界与修为[/b]——[code]player.realm[/code] / [code]player.cultivation[/code] /
##     [code]player.max_cultivation[/code]（ADR-0010：境界值所有权在 GSM）。[br]
##   · [b]各属性[/b]——[b]现查 [code]RealmSystem.realm_table[/code][/b]，本模块一个数值都不写。
##     [method attributes] 遍历当前境界那一档的全部键（[code]name[/code] 除外，它已作为
##     境界名单独展示），因此「表里加一个键，界面上就多一行」——不存在第二条数值来源。[br]
##   · [b]角色[/b]——名册走 [code]DeployRosterReader[/code]（[code]deck.slots[/code] → 卡牌模板），
##     生命走 [code]CombatHpCarryover.read_all[/code]（[code]player.character_hp[/code] 的
##     唯一读侧），阵亡走 [code]DeploymentSystem.get_unavailable_characters()[/code]。[br]
## [br][b]生命为什么要另取[/b]：名册里的 [code]hp[/code] 是模板 [code]base_hp[/code]（满血基准），
## 而界面要显示的是「打完一场之后的残血」——那是 [code]CombatHpCarryover[/code] 的职责
## （它自述为 [code]player.character_hp[/code] 的唯一读侧）。本模块[b]不写 HP[/b]，
## 只在读不到时回退模板基准并标明来源，让「10/10」与「未记过账的满血」可区分。[br]
## [br][b]防御力缺席（已登记的缺口）[/b]：境界表没有防御项，[code]CardTemplate[/code] 也没有
## [code]base_defense[/code]（该字段只存在于敌方 [code]EnemyTemplate[/code]）——故本界面
## 不显示防御，也不拿 [code]max_deploy[/code] 之类冒充。见类末「已知边界」。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：全只读，每次调用现读，不缓存快照。[br]
## [br][b]文案本地化豁免[/b]：与 inventory_catalog / shop_panel_screen 同源口径。[br]
## [br][b]已知边界[/b]：① 防御力无来源（见上）；② 灵能只到「上限」（[code]cost_per_turn[/code]），
## 战斗内的当前灵能属战斗域，不在本界面；③ 角色属性只到模板基础值，未叠功法/法宝/本命加成
## （那是战斗内的结算口径）。[br]
##
## 来源: ADR-0010 §境界值所有权、ADR-0001 §第一层数据读取、GDD realm-system.md §2 境界属性表、
## GDD combat-system.md §7（跨战斗死亡持久）、GDD deployment-system.md §10（不可用角色）、
## ADR-0031 §2、先例 [code]deploy_roster_reader.gd[/code] / [code]combat_hp_carryover.gd[/code]。

## 属性标签表（数值一律现查境界表——本模块只借用词条）。
const CatalogScript := preload("res://src/feature/inventory/inventory_catalog.gd")
## 角色名册的读取与详情投影（角色那一整块，见该文件类文档）。
const RosterScript := preload("res://src/feature/inventory/character_roster.gd")
## HP 持久化的唯一读侧。
const HpScript := preload("res://src/feature/combat/combat_hp_carryover.gd")

## 境界名不在属性列表里重复（它已作为「当前境界」单独展示）。
const REALM_NAME_KEY: String = "name"

## 依赖注入（测试用桩；null 时按 Autoload 查找）。
var gsm: Node = null
var card_system: Node = null
var realm_system: Node = null
var deployment_system: Node = null
var binding_manager: Node = null
## HP 账本读取器（[code]CombatHpCarryover[/code] 形态：有 [code]read_all()[/code]）。[br]
## [br][b]为什么要能注入[/b]：该模块自己去找 [code]/root/GameStateManager[/code]
## （它自述为 [code]player.character_hp[/code] 的唯一读侧，不接注入），而本模型的
## 其余依赖都是注入式的——若把它写死在内部，单元测试就得去改真实存档才能验
## 「残血显示」。注入后两条路径都干净：生产传真实实例，测试传桩。
var hp_carryover: RefCounted = null


## 构造——依赖全部可后置注入（[method set_dependencies]）。
func _init(p_gsm: Node = null, p_realm_system: Node = null) -> void:
	gsm = p_gsm
	realm_system = p_realm_system


## 后置注入（生产路径：Autoload 就绪后再接上）。
func set_dependencies(p_gsm: Node, p_card_system: Node, p_realm_system: Node,
		p_deployment_system: Node, p_binding_manager: Node = null) -> void:
	gsm = p_gsm
	card_system = p_card_system
	realm_system = p_realm_system
	deployment_system = p_deployment_system
	binding_manager = p_binding_manager


# ═══════════════════════════════════════════════════════════════════════════════
# 境界与修为
# ═══════════════════════════════════════════════════════════════════════════════

## 境界概况——[code]{realm, realm_name, cultivation, max_cultivation, cultivation_text,
## at_max_realm, is_fallen}[/code]。[br]
## [br]GSM 缺失时返回全零的合法形状（面板据此显示「数据不可用」而非崩溃）。[br]
## [br][b]境界名现查境界表[/b]（不引第二份名单）；查不到时回退「境界 N」——
## 表里没有的等级不该让整行变成空白。
func realm_status() -> Dictionary:
	var level: int = player_realm()
	var cultivation: int = int(_player_field("cultivation", 0))
	var max_cultivation: int = int(_player_field("max_cultivation", 0))
	return {
		"realm": level,
		"realm_name": realm_name(level),
		"cultivation": cultivation,
		"max_cultivation": max_cultivation,
		"cultivation_text": "%d / %d" % [cultivation, max_cultivation],
		"at_max_realm": level >= max_realm_level(),
		"is_fallen": bool(_player_field("is_fallen", false)),
	}


## 当前境界等级（GSM 不可用返回 0——「未知」而非「炼气」）。
func player_realm() -> int:
	return int(_player_field("realm", 0))


## 境界等级 → 中文名（境界表查不到时回退「境界 N」，不臆造名字）。
func realm_name(p_level: int) -> String:
	var table: Dictionary = realm_table()
	if not table.has(p_level):
		return "境界 %d" % p_level if p_level > 0 else "未知境界"
	return str((table[p_level] as Dictionary).get(REALM_NAME_KEY, "境界 %d" % p_level))


## 最高境界等级（境界表的键数——表是唯一真理来源，不写死 5）。
func max_realm_level() -> int:
	return realm_table().size()


# ═══════════════════════════════════════════════════════════════════════════════
# 属性（现查境界表）
# ═══════════════════════════════════════════════════════════════════════════════

## 当前境界的全部属性行——[code]Array[{key, label, value_text}][/code]。[br]
## [br][b]遍历境界表那一档的全部键[/b]（[code]name[/code] 除外，它已作为境界名展示）：
## 表是唯一数值来源，本模块不维护第二份属性清单，也不做任何换算。[br]
## [br]键序按境界表的书写顺序（GDScript Dictionary 保序）——玩家看到的分组与
## 策划在表里写的分组一致。[br]
## [br]整数写作纯数字，字符串原样透传（[code]map_unlock[/code] 是地名），
## 浮点保留两位（当前表内没有浮点项，留作前向兼容）。
func attributes() -> Array:
	var out: Array = []
	for key: Variant in attributes_source().keys():
		var text_key: String = str(key)
		if text_key == REALM_NAME_KEY:
			continue
		out.append({
			"key": text_key,
			"label": CatalogScript.attribute_label(text_key),
			"value_text": _format_value(attributes_source()[key]),
		})
	return out


## 当前境界在境界表里的原始条目（[code]{键: 值}[/code]；查不到为空字典）。[br]
## [br]面板与测试的取数口——[b]它返回的就是表里的原值[/b]，本模块不做二次加工。
func attributes_source() -> Dictionary:
	var table: Dictionary = realm_table()
	var level: int = player_realm()
	if not table.has(level):
		return {}
	return (table[level] as Dictionary).duplicate(true)


# ═══════════════════════════════════════════════════════════════════════════════
# 角色（名册 + 生命 + 阵亡）
# ═══════════════════════════════════════════════════════════════════════════════

## 全部角色位角色——[code]Array[{character_id, name, slot_index, current_hp, max_hp,
## hp_text, hp_known, attack, is_dead, status_text}][/code]。[br]
## [br]读法与投影在 [code]CharacterRoster[/code]（本模块只负责解析依赖与降级）。
func characters() -> Array:
	return RosterScript.entries(_resolve_gsm(), _resolve_card_system(),
			_resolve_deployment_system(), _resolve_binding_manager(),
			_resolve_hp_carryover().read_all())


## 阵亡角色数（面板顶部摘要用——与 [method characters] 同一判据）。
func dead_count() -> int:
	var count: int = 0
	for entry: Variant in characters():
		if bool((entry as Dictionary).get("is_dead", false)):
			count += 1
	return count


## 单个角色的详情——名册条目（生命/出战态）+ 卡牌模板字段的原样投影。[br]
## [br][b]为什么在模型里而不是面板里[/b]：详情里的每个数都来自别人的地盘（模板、
## HP 账本、阵亡名单），面板若自己去查就是第二处「谁读了存档」的现场；本方法把它们
## 收在一处，面板只负责把值写成句子（[code]CharacterStatusRows.detail_rows[/code]）。[br]
## [br][b]找不到该角色[/b]：返回空字典（面板据此不发详情，不臆造一行）。
func character_detail(p_character_id: int) -> Dictionary:
	var base: Dictionary = _roster_entry(p_character_id)
	if base.is_empty():
		return {}
	return RosterScript.detail(base, _template_by_instance(p_character_id))


# ═══════════════════════════════════════════════════════════════════════════════
# 内部辅助
# ═══════════════════════════════════════════════════════════════════════════════

## 名册里某个角色的条目（不在名册里返回空字典——调用方走「查无此人」分支）。[br]
## [br]复用 [method characters] 的投影（而不是自己再读一遍名册与 HP 账本）：
## 「谁在名册上」与「血量怎么算」的口径只有一处，详情页与列表页因此不可能给出
## 两个不同的生命值。
func _roster_entry(p_character_id: int) -> Dictionary:
	for raw: Variant in characters():
		if raw is Dictionary and int((raw as Dictionary).get("character_id", -1)) == p_character_id:
			return raw
	return {}


## 按实例 ID 取卡牌模板——卡牌系统缺失 / 实例不在收藏里时返回 null（不臆造字段）。
func _template_by_instance(p_character_id: int) -> Variant:
	var system: Node = _resolve_card_system()
	if system == null or not system.has_method(&"get_template_by_instance_id"):
		return null
	return system.call(&"get_template_by_instance_id", p_character_id)


## 值 → 展示文本（见 [method attributes] 注记）。
static func _format_value(p_value: Variant) -> String:
	if p_value is int:
		return str(p_value)
	if p_value is float:
		return "%.2f" % p_value
	return str(p_value)


## 读 [code]player.<键>[/code]——GSM 缺失 / 域不是字典时返回 [param p_fallback]。[br]
## [br]边界：不直接写 GSM 属性（ADR-0001 §第二层原子写入管的是[b]写[/b]），
## 但读走第一层（同 DeployRosterReader / CombatHpCarryover 的读侧先例）。
func _player_field(p_key: String, p_fallback: Variant) -> Variant:
	var store: Node = _resolve_gsm()
	if store == null:
		return p_fallback
	var player: Variant = store.get("player")
	if not (player is Dictionary):
		return p_fallback
	return (player as Dictionary).get(p_key, p_fallback)


## 境界表——经 [code]RealmSystem[/code]；系统缺失时退到脚本常量（先例
## [code]exploration_breakthrough_status.gd[/code] 的同一降级口径）。[br]
## [br]降级而非返回空：境界表是编译时常量，系统未注册不代表数据不存在——
## 面板在 Autoload 未就绪的测试环境里仍应显示出真实属性。
func realm_table() -> Dictionary:
	var system: Node = _resolve_realm_system()
	if system != null:
		var table: Variant = system.get("realm_table")
		if table is Dictionary:
			return table
	return RealmSystemScript.realm_table


## GSM——注入优先，否则 Autoload 查找。
func _resolve_gsm() -> Node:
	if gsm != null:
		return gsm
	return _autoload(&"GameStateManager")


## 卡牌系统——同上。
func _resolve_card_system() -> Node:
	if card_system != null:
		return card_system
	return _autoload(&"CardSystem")


## 境界系统——同上。
func _resolve_realm_system() -> Node:
	if realm_system != null:
		return realm_system
	return _autoload(&"RealmSystem")


## 部署系统——同上（阵亡名单的唯一来源）。[br]
## [br][b]为什么也要回落[/b]：漏接这条依赖不会报错，只会让全部角色显示「可出战」
## （阵亡标记静默失效）——那是最难在界面上发现的一类缺陷，故不依赖调用方记得接。
func _resolve_deployment_system() -> Node:
	if deployment_system != null:
		return deployment_system
	return _autoload(&"DeploymentSystem")


## 绑定管理器——同上（缺失只是没有绑定角标，读取器已按可空处理）。
func _resolve_binding_manager() -> Node:
	if binding_manager != null:
		return binding_manager
	return _autoload(&"BindingManager")


## HP 账本读取器——注入优先，否则本地 new（它自己去找 GSM）。[br]
## [br]new 出来的实例无状态（每次 [code]read_all()[/code] 现读），复用一个实例
## 只是省一次分配，不影响读取口径。
func _resolve_hp_carryover() -> RefCounted:
	if hp_carryover != null:
		return hp_carryover
	return HpScript.new()


## Autoload 动态查找（无 SceneTree / 未注册时返回 null，不抛错）。
static func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))


## RealmSystem 脚本常量——境界表的静态降级来源（[code]realm_table[/code] 是 const）。
const RealmSystemScript := preload("res://src/core/realm_system.gd")
