class_name RosterEntries
extends RefCounted
## RosterEntries —— 敌方名册条目的字段读取（从 [code]encounter_fields.gd[/code] 拆出）。[br]
## [br][b]为什么单独一处[/b]：名册条目有[b]两种形态[/b]——战斗期间的运行时对象
## （[code]EnemyBattleState[/code]，模板挂在 [code]template[/code] 上）与探索侧的
## 预览字典（[code]{template_id, name, realm, rewards}[/code]）。所有「读条目」的
## 调用点都必须同时兼容两者，散开写就会出现「预览能读、实战读不到」的静默缺口。[br]
## [br][b]只读[/b]：不构造、不修改条目；查不到的字段返回缺省（空串 / 0 / null）。[br]
##
## 来源: ADR-0017 §关键接口 RewardConfig、GDD ai-system.md §2。

## 条目模板 ID——对象读 [code]template.template_id[/code]；字典读 [code]template_id[/code]。
static func template_id(p_entry: Variant) -> StringName:
	if p_entry is Object and p_entry != null:
		var template: Variant = (p_entry as Object).get("template")
		if template is Object and template != null:
			return StringName(str((template as Object).get("template_id")))
		return &""
	if p_entry is Dictionary:
		return StringName(str((p_entry as Dictionary).get("template_id", "")))
	return &""


## 条目境界——对象读 [code]template.realm[/code]；字典读 [code]realm[/code]
## （为 0 时按模板 ID 查询补齐）。
static func realm(p_entry: Variant, p_lookup: Callable) -> int:
	if p_entry is Object and p_entry != null:
		var template: Variant = (p_entry as Object).get("template")
		return int((template as Object).get("realm")) \
				if template is Object and template != null else 0
	if p_entry is Dictionary:
		var direct: int = int((p_entry as Dictionary).get("realm", 0))
		if direct > 0:
			return direct
		var template: Variant = lookup(template_id(p_entry), p_lookup)
		return int(template.get("realm")) if template != null else 0
	return 0


## 条目奖励配置——对象读 [code]template.reward_config[/code]；字典按模板 ID 查。
static func reward_config(p_entry: Variant, p_lookup: Callable) -> Variant:
	var template: Variant = null
	if p_entry is Object and p_entry != null:
		template = (p_entry as Object).get("template")
	elif p_entry is Dictionary:
		template = lookup(template_id(p_entry), p_lookup)
	if template == null:
		return null
	return template.get("reward_config")


## 字典条目的任意字段（对象条目返回 null——字段读取只服务预览字典）。
static func field(p_entry: Variant, p_field: String) -> Variant:
	if p_entry is Dictionary:
		return (p_entry as Dictionary).get(p_field)
	return null


## 模板查询——闭包无效 / ID 为空时返回 null（不臆造模板）。
static func lookup(p_id: StringName, p_lookup: Callable) -> Variant:
	if p_id == &"" or not p_lookup.is_valid():
		return null
	return p_lookup.call(p_id)
