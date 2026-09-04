extends RefCounted
## FactionFieldStats —— 场上阵营统计 + 关系判定子模块（从 faction_system.gd 拆分）。
##
## 持有对 FactionSystem 父节点的引用，通过它访问 FACTION_LIBRARY /
## FactionRelation / get_tags_of_character / derive_major_alignment / count_on_field
## 等状态和方法。
##
## [br]来源: ADR-0018 §关键接口 §统计 API + §判定 API。
## [br]Sprint 11 Story 2：从 faction_system.gd 拆分。

## 父节点引用——FactionSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 两角色是否敌对 —— 基于 [method get_alignment_relation] 判定。[br]
## [br][param card_a_instance_id] 角色 A 实例 ID。[br]
## [br][param card_b_instance_id] 角色 B 实例 ID。[br]
## [br][b]返回[/b]: 关系为 [constant FactionRelation.HOSTILE] 则 true。[br]
## [br][b]来源[/b]: ADR-0018 §关键接口 §判定 API。
func is_hostile_to(card_a_instance_id: int, card_b_instance_id: int) -> bool:
	return get_alignment_relation(card_a_instance_id, card_b_instance_id) == _parent.get("FactionRelation").HOSTILE


## 两角色阵营关系 —— 三层关系判定（SAME/HOSTILE/NEUTRAL）。[br]
## [br][b]算法[/b]:[br]
##   1. 分别取两角色的首个非空大阵营推导值（跨阵营标签跳过）[br]
##   2. 任一方无大阵营归属（跨阵营角色）→ [constant FactionRelation.NEUTRAL][br]
##   3. 两方大阵营相同 → [constant FactionRelation.SAME][br]
##   4. 两方大阵营不同（正道 vs 魔道）→ [constant FactionRelation.HOSTILE][br]
## [br][b]返回[/b]: [code]0/1/2[/code]（SAME/HOSTILE/NEUTRAL）。[br]
## [br][b]来源[/b]: ADR-0018 §关键接口 §判定 API + GDD §公式 2。
func get_alignment_relation(a_instance_id: int, b_instance_id: int) -> int:
	var a_major: StringName = _first_major_alignment(a_instance_id)
	var b_major: StringName = _first_major_alignment(b_instance_id)

	if a_major.is_empty() or b_major.is_empty():
		return _parent.get("FactionRelation").NEUTRAL  # 跨阵营角色 → 中立
	if a_major == b_major:
		return _parent.get("FactionRelation").SAME
	return _parent.get("FactionRelation").HOSTILE


## 取角色的首个非空大阵营推导值 —— 用于 [method get_alignment_relation]。[br]
## [br]遍历角色标签，返回第一个 [method derive_major_alignment] 非空的标签推导结果；[br]
## 跨阵营标签（[code]parent_alignment=&""[/code]）推导为空，自动跳过。[br]
## [br][b]返回[/b]: 大阵营 tag_id，或 [code]&""[/code]（角色无大阵营归属）。
func _first_major_alignment(character_id: int) -> StringName:
	var tags: Array[StringName] = _parent.call("get_tags_of_character", character_id)
	for tag in tags:
		var derived: StringName = _parent.call("derive_major_alignment", tag)
		if not derived.is_empty():
			return derived
	return &""
