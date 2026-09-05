extends RefCounted
## StatusEffectImmunity —— 状态免疫机制子模块（从 status_effect_system.gd 拆分）。
##
## 无状态 static 方法集合——3 级免疫短路检查 + 免疫标志读写。
## _immunity_flags 注册表留在父节点（测试直接访问 ses._immunity_flags），
## Dictionary 为引用传递——子模块写入直接生效。
##
## [br]来源: ADR-0011 §免疫机制。
## [br]Sprint 12 Story 016：从 status_effect_system.gd 拆分。


## 设置免疫标志。[br]
## [br][param flags] 父节点 _immunity_flags 注册表（引用传递）。[br]
## [param target_id] 目标角色实例 ID。[br]
## [param level] 免疫级别——"type"/"template"/"element"。[br]
## [param key] 免疫键值——StatusType 枚举值（type 级）/ template_id（template 级）/ element 字符串（element 级）。
static func set_immunity(flags: Dictionary, target_id: int, level: String, key: Variant) -> void:
	if not flags.has(target_id):
		flags[target_id] = {type = {}, template = {}, element = {}}
	var target_flags: Dictionary = flags[target_id]
	if level in target_flags:
		target_flags[level][key] = true


## 清除免疫标志。[br]
## 参数同 [method set_immunity]。清除不存在的免疫不报错（幂等）。
static func clear_immunity(flags: Dictionary, target_id: int, level: String, key: Variant) -> void:
	if not flags.has(target_id):
		return
	var target_flags: Dictionary = flags[target_id]
	if level in target_flags:
		target_flags[level].erase(key)


## 3 级免疫短路检查——type → template → element。[br]
## [br][param flags] 父节点 _immunity_flags 注册表。[br]
## [param template] StatusTemplate——读取 type/template_id/metadata.element。[br]
## [br][b]返回[/b]: [code]{blocked: bool, immune_level: String}[/code]。[br]
## 首个命中的级别立即返回；全部未命中返回 blocked=false。
static func check_immunity(flags: Dictionary, target_id: int, template: StatusTemplate) -> Dictionary:
	if not flags.has(target_id):
		return {blocked = false, immune_level = ""}

	var target_flags: Dictionary = flags[target_id]

	# 级别 1：type 免疫（如 POISON/BUFF/DEBUFF/SPECIAL）
	var type_flags: Dictionary = target_flags.get("type", {})
	if type_flags.get(template.type, false):
		return {blocked = true, immune_level = "type"}

	# 级别 2：template 免疫（如 poison_3）
	var template_flags: Dictionary = target_flags.get("template", {})
	if template_flags.get(template.template_id, false):
		return {blocked = true, immune_level = "template"}

	# 级别 3：element 免疫（如 FIRE/ICE）
	var element_flags: Dictionary = target_flags.get("element", {})
	var element: String = template.metadata.get("element", "")
	if element != "" and element_flags.get(element, false):
		return {blocked = true, immune_level = "element"}

	return {blocked = false, immune_level = ""}
