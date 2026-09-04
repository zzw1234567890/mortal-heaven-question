extends RefCounted
## FormationAura —— 阵法光环查询子模块（从 formation_system.gd 拆分）。
##
## 持有对 FormationSystem 父节点的引用，通过它访问 _affiliations /
## is_formation_active / _get_slot_by_formation / fixed_bonus_cb /
## count_on_field_cb / _get_faction_system 等状态和方法。
##
## [br]来源: ADR-0024 §关键接口 §梯度阵法动态效果计算 / GDD formation-system.md §光环查询。
## [br]Sprint 9 Story 3：从 formation_system.gd 拆分。

## AuraScope.AFFILIATED_CHARACTERS 枚举值（避免依赖父节点枚举）。
const _SCOPE_AFFILIATED: int = 1

## 父节点引用——FormationSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 战斗热路径 O(1) 查询——计算角色从归属阵法获得的总光环加成（AC-001/002）。[br]
## 梯度阵法实时计算当前场上同阵营人数 → 确定效果等级 → 返回梯度值。[br]
## 固定阵法从 [code]effect_config[stat_name][/code] 读取。[br]
## [br][param character_id] 角色 ID。[br]
## [br][param stat_name] 属性名（如 "hp"/"def"/"atk"）。[br]
## [br][b]返回[/b]: [code]{total_bonus: float, breakdown: Array}[/code]——未归属/非 ACTIVE 返回 0。[br]
## [br]来源: ADR-0024 §关键接口 §梯度阵法动态效果计算。
func get_aura_bonus(character_id: int, stat_name: String) -> Dictionary:
	var affiliations: Dictionary = _parent.get("_affiliations")
	if not affiliations.has(character_id):
		return {"total_bonus": 0.0, "breakdown": []}
	var formation_id: int = affiliations[character_id]
	if not _parent.call("is_formation_active", formation_id):
		return {"total_bonus": 0.0, "breakdown": []}
	var slot: Dictionary = _parent.call("_get_slot_by_formation", formation_id)
	if slot.is_empty():
		return {"total_bonus": 0.0, "breakdown": []}
	var aura_scope: int = slot.get("aura_scope", _SCOPE_AFFILIATED)
	var bonus: float = 0.0
	var breakdown: Array = []
	# 梯度阵法——requirement 含 tag_id + max_level > 0 时走梯度计算
	var requirement: Dictionary = slot.get("requirement", {})
	var max_level: int = int(slot.get("max_level", 0))
	if max_level > 0 and requirement.has("tag_id"):
		bonus = _calculate_gradient_aura(formation_id, stat_name)
	else:
		# 固定阵法——从 effect_config 读取
		bonus = _get_fixed_bonus(slot, stat_name)
	if bonus != 0.0:
		breakdown.append({
			"formation_id": formation_id,
			"template_id": slot.get("template_id", &""),
			"aura_scope": aura_scope,
			"bonus": bonus,
			"stat": stat_name,
		})
	return {"total_bonus": bonus, "breakdown": breakdown}


## 梯度阵法光环加成——实时计算当前场上同阵营人数（AC-003~007）。[br]
## [b]公式[/b]: [code]effect_value = base_value × min(count_on_field(tag_id) - 1, max_level)[/code][br]
## 门槛 ≥2 人——不足返回 0.0。[br]
## [br][param formation_id] 阵法 ID。[br]
## [br][param stat_name] 属性名（固定阵法 effect_config 的 key，梯度阵法不区分 stat）。[br]
## [br][b]返回[/b]: 梯度效果值 float。[br]
## [br]来源: ADR-0024 §梯度阵法动态效果计算。
func _calculate_gradient_aura(formation_id: int, _stat_name: String) -> float:
	var slot: Dictionary = _parent.call("_get_slot_by_formation", formation_id)
	if slot.is_empty():
		return 0.0
	var requirement: Dictionary = slot.get("requirement", {})
	var tag_id: StringName = requirement.get("tag_id", &"")
	if tag_id.is_empty():
		return 0.0
	var count_on_field: int = _query_count_on_field(tag_id)
	if count_on_field < 2:
		return 0.0
	var max_level: int = int(slot.get("max_level", 0))
	if max_level <= 0:
		return 0.0
	var effect_level: int = mini(count_on_field - 1, max_level)
	var base_value: float = float(slot.get("base_value", 0.0))
	return base_value * float(effect_level)


## 固定阵法属性增益——从 effect_config 读取指定 stat 的加成值。[br]
## [br][param slot] 阵法位 Dictionary。[br]
## [br][param stat_name] 属性名。[br]
## [br][b]返回[/b]: 加成值 float（无配置返回 0.0）。
func _get_fixed_bonus(slot: Dictionary, stat_name: String) -> float:
	var cb: Callable = _parent.get("fixed_bonus_cb")
	if cb.is_valid():
		return float(cb.call(slot.get("formation_id", -1), stat_name))
	var effect_config: Dictionary = slot.get("effect_config", {})
	return float(effect_config.get(stat_name, 0.0))


## 查询场上某阵营角色数——优先 count_on_field_cb，否则走 FactionSystem。[br]
## [br][param tag_id] 阵营标签 ID。[br]
## [br][b]返回[/b]: 场上该阵营角色数 int。
func _query_count_on_field(tag_id: StringName) -> int:
	var cb: Callable = _parent.get("count_on_field_cb")
	if cb.is_valid():
		return int(cb.call(tag_id))
	var fs: Node = _get_faction_system()
	if fs != null and fs.has_method("count_on_field"):
		return int(fs.call("count_on_field", tag_id))
	return 0


## 动态获取 FactionSystem Autoload 节点。
func _get_faction_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/FactionSystem")
