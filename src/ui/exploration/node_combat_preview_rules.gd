class_name NodeCombatPreviewRules
extends RefCounted
## NodeCombatPreviewRules —— 战斗弹窗正文的 Logic 内核（从
## [code]node_interaction_rules.gd[/code] 拆出）。[br]
## [br][b]为什么单独一处[/b]：弹窗规则文件已贴近 300 行软上限，而「分发表 +
## 文案 + 布局」与「敌人摘要 → 正文行」是两块独立的纯函数——后者要同时兼容
## 运行时对象（[code]EnemyBattleState[/code]）与预览字典两种名册形态，值得
## 单独推理与单独测试。[br]
## [br][b]与开战同源[/b]：正文的等级取节点遭遇配置（[code]EncounterFields[/code]
## 五键契约），不另推一套——弹窗看到什么，开战就是什么。[br]
## [br][b]零状态纯函数[/b]（ADR-0031 §2）：不读 Autoload、不写任何状态。[br]
## [br][b]文案本地化豁免[/b]：与 [code]node_interaction_rules.gd[/code] 同源
## 口径（项目暂无本地化系统，DEBT-EUI-006-3）。
##
## 来源: design/gdd/exploration-ui-system.md §4、ADR-0014 §决策 3、
## exploration-ui Story 006（AC-2）、本轮「探索遭遇数据来源补齐」。

## 遭遇字段契约（与 DAG 生成器 / 开战上下文共用——弹窗读同一份节点数据）。
const EncounterFields := preload("res://assets/enemies/encounter_fields.gd")

## 普通战斗/精英提示（GDD §4 线框「推荐战力」行——B3 裁决采用角色数版本）。
const TEXT_RECOMMENDED_PREFIX: String = "推荐上场角色："

## 境界等级 → 中文名表（1 炼气 … 5 化神）。
const REALM_NAMES: Dictionary = {
	1: "炼气期", 2: "筑基期", 3: "金丹期", 4: "元婴期", 5: "化神期",
}


## 战斗敌人摘要——敌人名称 + 数量 + 境界（AC-2 三要素）。[br]
## [b]双形态兼容[/b]：元素可为 [code]EnemyBattleState[/code]（含
## [code]template.display_name[/code]/[code]template.realm[/code]）或测试用
## Dictionary（[code]name[/code]/[code]realm[/code]）。[br]
## [b]返回[/b]: [code]{names: Array[String], count: int, realm: int}[/code]。
static func enemy_summary(p_enemy_roster: Array) -> Dictionary:
	var names: Array = []
	var max_realm: int = 0
	for entry: Variant in p_enemy_roster:
		var name: String = _entry_name(entry)
		if not name.is_empty():
			names.append(name)
		max_realm = maxi(max_realm, _entry_realm(entry))
	return {"names": names, "count": p_enemy_roster.size(), "realm": max_realm}


## 战斗弹窗动态正文行（名称 ×数量 / 境界 / 推荐上场角色）——旧入口。[br]
## [param p_max_deploy]: 当前境界上场上限（RealmSystem 查询值，UI 不推算）。[br]
## [param p_recommended_override]: 地图配置显式推荐值（≤0 表示未配置 → 推定）。
static func lines(p_enemy_roster: Array, p_max_deploy: int,
		p_recommended_override: int = 0) -> Array:
	return lines_for_encounter({}, p_enemy_roster, p_max_deploy,
			p_recommended_override)


## 战斗弹窗动态正文行——[b]与开战上下文读同一份节点遭遇数据[/b]。[br]
## [br][b]为什么要带 encounter[/b]：弹窗若只读到达名册，展示的等级/数量与
## 开战时用的会是两套推导（名册可能为空、或只含预览字段）。这里先吃节点的
## 遭遇配置，再回退到名册——文案与 [code]CombatLaunchContext[/code] 同源。[br]
## [br][param p_encounter] 规范化遭遇配置（[code]EncounterFields.make/of_detail[/code]）。[br]
## [param p_roster] 到达名册（可为空——数量退化为模板 ID 数）。[br]
## [param p_max_deploy] 当前境界上场上限。[br]
## [param p_recommended_override] 地图配置显式推荐值（≤0 = 未配置）。
static func lines_for_encounter(p_encounter: Dictionary, p_roster: Array,
		p_max_deploy: int, p_recommended_override: int = 0) -> Array:
	var summary: Dictionary = enemy_summary(p_roster)
	var names: Array = summary["names"]
	var count: int = int(summary["count"])
	if count <= 0:
		count = _template_count(p_encounter)
	var first_name: String = ""
	if not names.is_empty():
		first_name = str(names[0])
	if first_name.is_empty():
		first_name = str(p_encounter.get(EncounterFields.KEY_DISPLAY_NAME, ""))
		# 遭遇展示名可能自带「×N」——正文另有数量，去掉避免「散修 ×2 ×2」。
		var marker: int = first_name.rfind(" ×")
		if marker > 0:
			first_name = first_name.substr(0, marker)
	var lines: Array = []
	if first_name.is_empty():
		lines.append("敌人：未知 ×%d" % count)
	else:
		lines.append("%s ×%d" % [first_name, count])
	var realm: int = int(p_encounter.get(EncounterFields.KEY_ENEMY_LEVEL, 0))
	if realm <= 0:
		realm = int(summary["realm"])
	if realm > 0:
		lines.append(realm_name(realm))
	lines.append(TEXT_RECOMMENDED_PREFIX + "≥%d"
			% recommended_deploy(count, p_max_deploy, p_recommended_override))
	return lines


## 推荐上场角色数——[b]数据驱动[/b]：配置值优先，缺失时按敌人数对等推定
## （B3 裁决弃用数值战力版；本推定仅覆盖配置缺失的 stub 阶段）。[br]
## [b]不变量[/b]：≥1 且 ≤ max_deploy（max_deploy ≤0 时退化为 1）。
static func recommended_deploy(p_enemy_count: int, p_max_deploy: int,
		p_recommended_override: int = 0) -> int:
	var cap: int = maxi(p_max_deploy, 1)
	if p_recommended_override > 0:
		return clampi(p_recommended_override, 1, cap)
	if p_enemy_count <= 0:
		return 1
	return clampi(p_enemy_count, 1, cap)


## 境界等级 → 中文名（1 炼气 … 5 化神）；未知等级返回空串不臆造。
static func realm_name(p_realm: int) -> String:
	return str(REALM_NAMES.get(p_realm, ""))


## 遭遇配置里的模板数（数量回退口径——名册为空时不让弹窗显示「×0」）。
static func _template_count(p_encounter: Dictionary) -> int:
	var ids: Variant = p_encounter.get(EncounterFields.KEY_TEMPLATE_IDS, [])
	return (ids as Array).size() if ids is Array else 0


## 敌人条目名称——兼容对象（template.display_name）与 Dictionary（name）。
static func _entry_name(p_entry: Variant) -> String:
	if p_entry is Dictionary:
		var dict: Dictionary = p_entry
		return str(dict.get("name", dict.get("display_name", "")))
	if p_entry == null:
		return ""
	var template_variant: Variant = p_entry.get("template") if p_entry is Object else null
	if template_variant is Object and template_variant != null:
		return str(template_variant.get("display_name"))
	return ""


## 敌人条目境界——兼容对象（template.realm）与 Dictionary（realm）。
static func _entry_realm(p_entry: Variant) -> int:
	if p_entry is Dictionary:
		return int((p_entry as Dictionary).get("realm", 0))
	if p_entry == null:
		return 0
	var template_variant: Variant = p_entry.get("template") if p_entry is Object else null
	if template_variant is Object and template_variant != null:
		return int(template_variant.get("realm"))
	return 0
