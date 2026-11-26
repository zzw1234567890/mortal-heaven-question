## SchoolConditions 标签规则（继承链首段）——[b]门派 → 大阵营推导与显示名[/b]。
##
## [b]本层职责[/b]：整条链的[b]叶子[/b]——不依赖任何其他段，只被评估器调用。[br]
##   · [method _char_matches_tags]——「这个角色的阵营标签算不算命中目标」，
##     先精确匹配、再走大阵营推导；[br]
##   · [method _is_tag_under_alignment]——门派标签 → 大阵营的[b]内置映射表[/b]，
##     刻意不依赖 [code]FactionSystem[/code]（保持纯函数、可单独测）；[br]
##   · [method _get_tag_display_name] / [method _tags_display]——[code]missing_text[/code]
##     的玩家可读词条（硬编码中文；项目暂无本地化系统，本地化 epic 入库后整体换 key）。
##
## [b]为什么是链首[/b]：调用方向决定链序——评估器要调这四个方法，它们就必须待在祖先段
## （祖先段裸标识符调后代段方法会报 [code]Function "x()" not found in base self[/code]）。
## 本类 0 信号 / 0 类级字段 / 0 类级常量 / 0 默认参数，故「信号落链首」「默认参数引用的
## 枚举/常量随声明落链首」两条解析期约束在这里是[b]空约束[/b]。
##
## 来源: ADR-0025 §关键接口 + GDD school-system.md §公式#1。
extends RefCounted


# --- 辅助方法 ---------------------------------------------------------------------

## 检查角色是否匹配 tags 中任一标签。[br]
## 对 tags 中的每个 tag，检查角色 faction_tags 中是否有直接匹配或可推导为该大阵营的标签。
func _char_matches_tags(char: Dictionary, tags: Array) -> bool:
	var char_tags: Array = char.get("faction_tags", [])
	for char_tag in char_tags:
		for target_tag in tags:
			if char_tag == target_tag:
				return true
			# 门派推导为大阵营——简化版：如果角色标签的 parent 是目标标签
			# 委托 FactionSystem 的 derive_major_alignment 逻辑
			if _is_tag_under_alignment(char_tag, target_tag):
				return true
	return false


## 判定某标签是否属于指定大阵营。[br]
## 简化版推导——基于 SCHOOL_LIBRARY 不依赖 FactionSystem。[br]
## 内置映射：门派标签 → 大阵营。
func _is_tag_under_alignment(tag: StringName, alignment: StringName) -> bool:
	# 门派 → 大阵营映射（与 FactionSystem.FACTION_LIBRARY 一致）
	const TAG_TO_MAJOR: Dictionary = {
		# 正道门派
		&"qixuanmen": &"zhengdao",
		&"dangxia_valley": &"zhengdao",
		&"xuanbing_palace": &"zhengdao",
		&"dongyu": &"zhengdao",
		&"xingdou_sect": &"zhengdao",
		&"wei_family": &"zhengdao",
		# 魔道门派
		&"xuehai_temple": &"modao",
		&"meiying_pavilion": &"modao",
		&"samsara_hall": &"modao",
		&"xuesha_cult": &"modao",
		&"heisha_cult": &"modao",
		&"yunmeng": &"modao",
	}
	var derived: StringName = TAG_TO_MAJOR.get(tag, &"") as StringName
	if derived.is_empty():
		return false
	return derived == alignment


## 获取标签的显示名称（用于 missing_text）。
func _get_tag_display_name(tag: StringName) -> String:
	const TAG_NAMES: Dictionary = {
		&"zhengdao": "正道",
		&"modao": "魔道",
		&"guixu_abyss": "归墟",
		&"zhenling": "真灵",
	}
	return TAG_NAMES.get(tag, str(tag))


## 标签列表显示名（用于 missing_text）。
func _tags_display(tags: Array) -> String:
	var names: Array[String] = []
	for tag in tags:
		names.append(_get_tag_display_name(tag))
	return "/".join(names)
