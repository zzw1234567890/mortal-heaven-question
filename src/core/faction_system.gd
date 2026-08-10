extends Node
# class_name FactionSystem —— 不声明：Autoload 全局单例，
# 声明 class_name 会与全局名冲突，导致 FS_SCRIPT.new() 测试实例无法解析。
# 测试以 var fs: Node 持有 + 动态分派访问（同 GSM/EventSystem/RealmSystem/
# ResourceSystem/CardSystem 先例，控制清单 2026-08-05 规则）。

## FactionSystem —— 阵营标签库 + 纯查询 API Autoload（#7）。
##
## Core 层 Autoload。持有 [constant FACTION_LIBRARY] 编译时常量标签库
## （18 标签：2 大阵营 + 12 门派 + 4 跨阵营），提供 O(1) 查询接口：
## [method get_tag_info] / [method get_major_alignments] / [method derive_major_alignment]
## 以及角色标签查询 [method get_tags_of_character] / [method belongs_to_alignment]。
##
## [b]纯查询接口[/b]（ADR-0018 §信号策略）——不发射任何自有信号。
## 阵营分布变化是上场/阵亡事件的结果，由 DeploymentSystem/CombatSystem 信号
## 驱动消费者重新查询。这一模式与 ADR-0007 "直接调用决策矩阵" 一致。
##
## [b]Autoload 顺序[/b]：GSM → ... → ResourceSystem → FactionSystem
## （在 CardSystem 之后——[method get_tags_of_character] 通过 CardSystem 查询模板）。
##
## [b]原则[/b]：所有阵营标签元数据查询必须通过本系统，绝不硬编码标签定义。
## 阵营标签数据的运行时来源是 [member CardTemplate.faction_tags]（ADR-0006），
## FactionSystem 不持有副本——避免双源真理。
##
## 来源: ADR-0018。

# === 枚举 =========================================================================

## 阵营关系枚举（ADR-0018 §关键接口）。
enum FactionRelation {
	SAME = 0,      ## 同大阵营
	HOSTILE = 1,   ## 敌对大阵营（正道 vs 魔道）
	NEUTRAL = 2,   ## 中立（任一方为跨阵营标签，或无大阵营归属）
}


# === 阵营标签库（编译时常量）=====================================================
## 18 标签的元数据真理来源。[br]
## [b]只读约定[/b]（ADR-0018）：const Dictionary 并非真正冻结，团队约定运行时不写入。
## 结构：每个 tag_id → { name, parent_alignment, is_major, icon, color? }[br]
## - 大阵营 [code]is_major=true[/code]、[code]parent_alignment=&""[/code][br]
## - 门派 [code]is_major=false[/code]、[code]parent_alignment[/code] 指向大阵营[br]
## - 跨阵营中立标签 [code]parent_alignment=&""[/code]（无大阵营归属）
const FACTION_LIBRARY: Dictionary = {
	# --- 大阵营 (is_major=true, parent_alignment=&"") ---
	&"zhengdao": {
		name = "正道", parent_alignment = &"", is_major = true,
		icon = "res://assets/icons/factions/zhengdao.png",
		color = Color(0.29, 0.62, 0.43),  # 青金色 #4A9E6E
	},
	&"modao": {
		name = "魔道", parent_alignment = &"", is_major = true,
		icon = "res://assets/icons/factions/modao.png",
		color = Color(0.75, 0.22, 0.17),  # 赤紫色 #C0392B
	},
	# --- 正道门派 (parent_alignment=&"zhengdao") ---
	&"qixuanmen": {
		name = "青云剑宗", parent_alignment = &"zhengdao", is_major = false,
		icon = "res://assets/icons/factions/qixuanmen.png",
	},
	&"dangxia_valley": {
		name = "丹霞谷", parent_alignment = &"zhengdao", is_major = false,
		icon = "res://assets/icons/factions/dangxia_valley.png",
	},
	&"xuanbing_palace": {
		name = "玄冰宫", parent_alignment = &"zhengdao", is_major = false,
		icon = "res://assets/icons/factions/xuanbing_palace.png",
	},
	&"dongyu": {
		name = "东域", parent_alignment = &"zhengdao", is_major = false,
		icon = "res://assets/icons/factions/dongyu.png",
	},
	&"xingdou_sect": {
		name = "星斗宗", parent_alignment = &"zhengdao", is_major = false,
		icon = "res://assets/icons/factions/xingdou_sect.png",
	},
	&"wei_family": {
		name = "卫家", parent_alignment = &"zhengdao", is_major = false,
		icon = "res://assets/icons/factions/wei_family.png",
	},
	# --- 魔道门派 (parent_alignment=&"modao") ---
	&"xuehai_temple": {
		name = "血海殿", parent_alignment = &"modao", is_major = false,
		icon = "res://assets/icons/factions/xuehai_temple.png",
	},
	&"meiying_pavilion": {
		name = "魅影阁", parent_alignment = &"modao", is_major = false,
		icon = "res://assets/icons/factions/meiying_pavilion.png",
	},
	&"samsara_hall": {
		name = "轮回殿", parent_alignment = &"modao", is_major = false,
		icon = "res://assets/icons/factions/samsara_hall.png",
	},
	&"xuesha_cult": {
		name = "血煞教", parent_alignment = &"modao", is_major = false,
		icon = "res://assets/icons/factions/xuesha_cult.png",
	},
	&"heisha_cult": {
		name = "黑煞教", parent_alignment = &"modao", is_major = false,
		icon = "res://assets/icons/factions/heisha_cult.png",
	},
	&"yunmeng": {
		name = "云蒙", parent_alignment = &"modao", is_major = false,
		icon = "res://assets/icons/factions/yunmeng.png",
	},
	# --- 跨阵营中立标签 (parent_alignment=&"") ---
	&"suixing_islands": {
		name = "碎星群岛", parent_alignment = &"", is_major = false,
		icon = "res://assets/icons/factions/suixing_islands.png",
	},
	&"guixu_abyss": {
		name = "归墟之境", parent_alignment = &"", is_major = false,
		icon = "res://assets/icons/factions/guixu_abyss.png",
	},
	&"wanxiang_pavilion": {
		name = "万象阁", parent_alignment = &"", is_major = false,
		icon = "res://assets/icons/factions/wanxiang_pavilion.png",
	},
	&"jiyin_island": {
		name = "极阴岛", parent_alignment = &"", is_major = false,
		icon = "res://assets/icons/factions/jiyin_island.png",
	},
}

## CardSystem 在场景树的路径（动态查找——避免硬引用全局名导致脚本解析依赖
## CardSystem 是否已注册为 Autoload。语义等价 ADR-0018 的 is_instance_valid(CardSystem)）。
const _CARD_SYSTEM_PATH: String = "/root/CardSystem"

## 测试注入——非空时 _get_card_system 直接返回此节点，绕过场景树查找。[br]
## 生产代码不设置此字段（默认 null → 走场景树动态查找）。[br]
## 测试用它注入未加入场景树的 CardSystem 实例，避免 _ready() 触发模板目录加载清空测试夹具。
var _test_card_system: Node = null


# === 查询 API ====================================================================

## 查询标签元数据 —— O(1) 字典查询。[br]
## [br][param tag_id] 标签 ID（StringName）。[br]
## [br][b]返回[/b]: 标签元数据字典；无效 tag_id 返回空字典 + push_warning。[br]
## [br][b]来源[/b]: ADR-0018 §关键接口。
func get_tag_info(tag_id: StringName) -> Dictionary:
	if not FACTION_LIBRARY.has(tag_id):
		push_warning("FactionSystem: 未知 tag_id '%s'" % tag_id)
		return {}
	return FACTION_LIBRARY[tag_id]


## 获取所有大阵营标签列表（正道/魔道）。[br]
## [br][b]返回[/b]: 大阵营 tag_id 的 [Array]（[code]is_major=true[/code] 者）。[br]
## [br][b]来源[/b]: ADR-0018 §关键接口。
func get_major_alignments() -> Array[StringName]:
	var result: Array[StringName] = []
	for tag_id in FACTION_LIBRARY:
		if FACTION_LIBRARY[tag_id].is_major:
			result.append(tag_id)
	return result


## 门派标签 → 大阵营推导 —— O(1)。[br]
## [br][param tag_id] 标签 ID。[br]
## [br][b]返回[/b]: 大阵营 tag_id；大阵营自身返回自身；跨阵营标签或无效 tag_id 返回 [code]&""[/code]。[br]
## [br][b]来源[/b]: ADR-0018 §关键接口。
func derive_major_alignment(tag_id: StringName) -> StringName:
	var info: Dictionary = get_tag_info(tag_id)
	if info.is_empty():
		return &""
	if info.is_major:
		return tag_id  # 自身就是大阵营
	return info.get("parent_alignment", &"") as StringName


## 获取角色的全部阵营标签 —— 通过 CardSystem 查询模板（跨 Epic 依赖）。[br]
## [br][param character_id] 角色实例 ID。[br]
## [br][b]返回[/b]: 角色的 faction_tags；CardSystem 不可用或模板缺失返回空数组。[br]
## [br][b]来源[/b]: ADR-0018 §关键接口 + ADR-0006（CardTemplate.faction_tags 是唯一运行时来源）。
func get_tags_of_character(character_id: int) -> Array[StringName]:
	var cs: Node = _get_card_system()
	if cs == null or not cs.has_method("get_template_by_instance_id"):
		return []
	var template: Variant = cs.call("get_template_by_instance_id", character_id)
	if template == null:
		return []
	# faction_tags 是 Array[StringName]——返回前做类型归一以匹配签名。
	var tags: Array = template.faction_tags if "faction_tags" in template else []
	var result: Array[StringName] = []
	for tag in tags:
		result.append(tag as StringName)
	return result


## 角色是否属于某大阵营 —— O(3)（最多 3 标签推导）。[br]
## [br][param character_id] 角色实例 ID。[br]
## [br][param alignment] 大阵营 tag_id。[br]
## [br][b]返回[/b]: 角色任一标签推导为该大阵营则 true。[br]
## [br][b]来源[/b]: ADR-0018 §关键接口。
func belongs_to_alignment(character_id: int, alignment: StringName) -> bool:
	var tags: Array[StringName] = get_tags_of_character(character_id)
	for tag in tags:
		if derive_major_alignment(tag) == alignment:
			return true
	return false


# === 场上阵营统计（Story 002）=====================================================

## 统计场上含指定标签或其大阵营的角色数量 —— 实时遍历上场角色。[br]
## [br]遍历 [method _get_field_characters] 返回的存活角色，对每个角色查询其 [code]faction_tags[/code]，[br]
## 任一标签直接匹配 [param tag_or_alignment]，或推导为大阵营后匹配，则该角色计入一次（[code]break[/code] 避免重复）。[br]
## [br][b]复杂度[/b]: O(场角色数 × 3) —— 场上 ≤6 角色、每人 ≤3 标签，最坏 18 次 StringName 判等 <0.001ms。[br]
## [br][param tag_or_alignment] 标签 ID 或大阵营 ID（如 [code]&"zhengdao"[/code]）。[br]
## [br][b]返回[/b]: 匹配的角色数；CardSystem 不可用或场上为空时返回 0。[br]
## [br][b]来源[/b]: ADR-0018 §关键接口 §统计 API。
func count_on_field(tag_or_alignment: StringName) -> int:
	var field_chars: Array = _get_field_characters()
	var count: int = 0
	for char_instance in field_chars:
		var cid: int = _get_instance_id(char_instance)
		if cid == 0:
			continue
		var tags: Array[StringName] = get_tags_of_character(cid)
		for tag in tags:
			# 判定：直接匹配 或 门派推导为大阵营匹配
			if tag == tag_or_alignment or derive_major_alignment(tag) == tag_or_alignment:
				count += 1
				break  # 同一角色只计一次（AC-004）
	return count


## 返回场上所有标签的计数快照。[br]
## [br]遍历 [constant FACTION_LIBRARY] 全部 18 标签，调用 [method count_on_field]，仅保留 count > 0 的条目。[br]
## [br][b]返回[/b]: [Dictionary]——键为 tag_id，值为该标签的场上角色数。[br]
## [br][b]来源[/b]: ADR-0018 §关键接口 §统计 API。
func get_field_faction_distribution() -> Dictionary:
	var dist: Dictionary = {}
	for tag_id in FACTION_LIBRARY:
		var c: int = count_on_field(tag_id)
		if c > 0:
			dist[tag_id] = c
	return dist


## 阵法激活条件判定 —— 检查场上某标签/大阵营角色数是否达到阈值。[br]
## [br][param requirement] 格式 [code]{ tag_id: StringName, min_count: int }[/code]——[br]
##   - [code]tag_id[/code] 缺失或空 → 返回 [code]false[/code][br]
##   - [code]min_count[/code] 缺失默认 0（即只要场上存在即满足）[br]
## [br][b]返回[/b]: [method count_on_field] 结果 ≥ [code]min_count[/code] 则 true。[br]
## [br][b]来源[/b]: ADR-0018 §关键接口 §判定 API + GDD §6 阵法联动。
func check_condition(requirement: Dictionary) -> bool:
	var tag_id: StringName = requirement.get("tag_id", &"") as StringName
	var min_count: int = int(requirement.get("min_count", 0))
	if tag_id.is_empty():
		return false
	return count_on_field(tag_id) >= min_count


## 两角色是否敌对 —— 基于 [method get_alignment_relation] 判定。[br]
## [br][param card_a_instance_id] 角色 A 实例 ID。[br]
## [br][param card_b_instance_id] 角色 B 实例 ID。[br]
## [br][b]返回[/b]: 关系为 [constant FactionRelation.HOSTILE] 则 true。[br]
## [br][b]来源[/b]: ADR-0018 §关键接口 §判定 API。
func is_hostile_to(card_a_instance_id: int, card_b_instance_id: int) -> bool:
	return get_alignment_relation(card_a_instance_id, card_b_instance_id) == FactionRelation.HOSTILE


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
		return FactionRelation.NEUTRAL  # 跨阵营角色 → 中立
	if a_major == b_major:
		return FactionRelation.SAME
	return FactionRelation.HOSTILE


# === 内部辅助 ====================================================================

## 动态获取 CardSystem Autoload 节点。[br]
## 用 [method SceneTree.root] 查找而非硬引用全局名 [code]CardSystem[/code]——[br]
## 避免本脚本解析依赖 CardSystem 是否已注册为 Autoload（项目 Autoload 顺序
## 验证在 Story 2-15 统一处理）。语义等价 [code]is_instance_valid(CardSystem)[/code]。
## [br][b]测试注入[/b]：若 [member _test_card_system] 非空，直接返回它（绕过场景树查找）。
func _get_card_system() -> Node:
	if _test_card_system != null:
		return _test_card_system
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(_CARD_SYSTEM_PATH)


## 获取场上存活角色列表 —— 跨 Epic 依赖 CardSystem。[br]
## [br][b]返回[/b]: [code]CardSystem.get_field_characters()[/code] 的返回值；CardSystem 不可用或无该方法时返回空数组。[br]
## [br][b]来源[/b]: ADR-0018 §关键接口——阵亡角色不在列表中（ADR-0008 战斗系统维护）。
func _get_field_characters() -> Array:
	var cs: Node = _get_card_system()
	if cs == null or not cs.has_method("get_field_characters"):
		return []
	return cs.call("get_field_characters")


## 从角色实例对象提取 card_instance_id —— 兼容 CardInstance 对象与 Dictionary 两种形态。[br]
## [br]GDD §2 角色即为卡牌——场上角色以 CardInstance 表示。[param char_instance] 可能是 CardInstance 对象，[br]
## 也可能是测试夹具用的 Dictionary。返回 0 表示无法提取（[method count_on_field] 会跳过）。
func _get_instance_id(char_instance: Variant) -> int:
	if char_instance is Object and "card_instance_id" in char_instance:
		return int(char_instance.card_instance_id)
	if char_instance is Dictionary and char_instance.has("card_instance_id"):
		return int(char_instance["card_instance_id"])
	return 0


## 取角色的首个非空大阵营推导值 —— 用于 [method get_alignment_relation]。[br]
## [br]遍历角色标签，返回第一个 [method derive_major_alignment] 非空的标签推导结果；[br]
## 跨阵营标签（[code]parent_alignment=&""[/code]）推导为空，自动跳过。[br]
## [br][b]返回[/b]: 大阵营 tag_id，或 [code]&""[/code]（角色无大阵营归属）。
func _first_major_alignment(character_id: int) -> StringName:
	var tags: Array[StringName] = get_tags_of_character(character_id)
	for tag in tags:
		var derived: StringName = derive_major_alignment(tag)
		if not derived.is_empty():
			return derived
	return &""
