extends GutTest
## Story 001 验收测试：FactionSystem 阵营标签库 + 纯查询 API。
##
## 覆盖 AC-001 到 AC-015 + AC-019/020（共 17 条 AC）。
## AC-016~018（get_tags_of_character / belongs_to_alignment）跨 Epic 依赖
## CardSystem.get_template_by_instance_id，移至 Story 002 集成测试。
##
## 测试策略：
##   - FS_SCRIPT.new() 构造 FactionSystem 实例（不调 _ready，纯查询无副作用）
##   - 不依赖 GSM / CardSystem——AC-001~015/019/020 均为纯查询或元数据校验
##   - 动态分派：var fs: Node 持有，返回值显式类型注解（控制清单 2026-08-05 规则）

const FS_SCRIPT: GDScript = preload("res://src/core/faction_system.gd")

var fs: Node = null


func before_each() -> void:
	fs = FS_SCRIPT.new()


func after_each() -> void:
	if fs != null:
		fs.free()
		fs = null


# ============================================================================
# AC-001：extends Node，不声明 class_name
# ============================================================================

func test_ac001_extends_node_no_class_name() -> void:
	assert_eq(FS_SCRIPT.get_instance_base_type(), "Node", "FactionSystem 应 extends Node")
	# Autoload 脚本不声明 class_name——get_global_name() 返回空字符串
	assert_eq(FS_SCRIPT.get_global_name(), &"", "FactionSystem 不应声明 class_name")


# ============================================================================
# AC-002：FactionRelation 枚举定义（SAME=0, HOSTILE=1, NEUTRAL=2）
# ============================================================================

func test_ac002_faction_relation_enum_values() -> void:
	assert_eq(int(FS_SCRIPT.FactionRelation.SAME), 0, "SAME 应为 0")
	assert_eq(int(FS_SCRIPT.FactionRelation.HOSTILE), 1, "HOSTILE 应为 1")
	assert_eq(int(FS_SCRIPT.FactionRelation.NEUTRAL), 2, "NEUTRAL 应为 2")


func test_faction_relation_enum_has_three_values() -> void:
	var count: int = FS_SCRIPT.FactionRelation.size()
	assert_eq(count, 3, "FactionRelation 枚举应有 3 个值")


# ============================================================================
# AC-003：FACTION_LIBRARY 含 18 个标签（2 大阵营 + 12 门派 + 4 跨阵营）
# ============================================================================

func test_ac003_faction_library_has_18_tags() -> void:
	assert_eq(FS_SCRIPT.FACTION_LIBRARY.size(), 18, "FACTION_LIBRARY 应含 18 个标签")


func test_faction_library_has_two_major_alignments() -> void:
	var major_count: int = 0
	var sect_count: int = 0
	var cross_count: int = 0
	for tag_id in FS_SCRIPT.FACTION_LIBRARY:
		var info: Dictionary = FS_SCRIPT.FACTION_LIBRARY[tag_id]
		if info.is_major:
			major_count += 1
		elif info.parent_alignment != &"":
			sect_count += 1
		else:
			cross_count += 1
	assert_eq(major_count, 2, "大阵营应为 2 个（正道 + 魔道）")
	assert_eq(sect_count, 12, "门派应为 12 个")
	assert_eq(cross_count, 4, "跨阵营中立标签应为 4 个")


# ============================================================================
# AC-004：get_tag_info(&"zhengdao") 返回正道定义
# ============================================================================

func test_ac004_get_tag_info_zhengdao() -> void:
	var info: Dictionary = fs.get_tag_info(&"zhengdao")
	assert_eq(info.get("name", ""), "正道", "zhengdao name 应为 '正道'")
	assert_true(info.get("is_major", false), "zhengdao 应 is_major=true")
	assert_eq(info.get("parent_alignment", &"invalid"), &"", "zhengdao parent_alignment 应为空")
	assert_eq(info.get("color", Color()), Color(0.29, 0.62, 0.43), "zhengdao color 应为青金色")


# ============================================================================
# AC-005：get_tag_info(&"modao") 返回魔道定义
# ============================================================================

func test_ac005_get_tag_info_modao() -> void:
	var info: Dictionary = fs.get_tag_info(&"modao")
	assert_eq(info.get("name", ""), "魔道", "modao name 应为 '魔道'")
	assert_true(info.get("is_major", false), "modao 应 is_major=true")
	assert_eq(info.get("parent_alignment", &"invalid"), &"", "modao parent_alignment 应为空")
	assert_eq(info.get("color", Color()), Color(0.75, 0.22, 0.17), "modao color 应为赤紫色")


# ============================================================================
# AC-006：get_tag_info(&"qixuanmen") 返回正道门派定义
# ============================================================================

func test_ac006_get_tag_info_qixuanmen() -> void:
	var info: Dictionary = fs.get_tag_info(&"qixuanmen")
	assert_eq(info.get("name", ""), "青云剑宗", "qixuanmen name 应为 '青云剑宗'")
	assert_false(info.get("is_major", true), "qixuanmen 应 is_major=false")
	assert_eq(info.get("parent_alignment", &""), &"zhengdao", "qixuanmen parent_alignment 应为 zhengdao")


# ============================================================================
# AC-007：get_tag_info(&"xuehai_temple") 返回魔道门派定义
# ============================================================================

func test_ac007_get_tag_info_xuehai_temple() -> void:
	var info: Dictionary = fs.get_tag_info(&"xuehai_temple")
	assert_eq(info.get("name", ""), "血海殿", "xuehai_temple name 应为 '血海殿'")
	assert_false(info.get("is_major", true), "xuehai_temple 应 is_major=false")
	assert_eq(info.get("parent_alignment", &""), &"modao", "xuehai_temple parent_alignment 应为 modao")


# ============================================================================
# AC-008：get_tag_info(&"suixing_islands") 返回跨阵营标签
# ============================================================================

func test_ac008_get_tag_info_suixing_islands() -> void:
	var info: Dictionary = fs.get_tag_info(&"suixing_islands")
	assert_eq(info.get("name", ""), "碎星群岛", "suixing_islands name 应为 '碎星群岛'")
	assert_false(info.get("is_major", true), "suixing_islands 应 is_major=false")
	assert_eq(info.get("parent_alignment", &"invalid"), &"", "跨阵营标签 parent_alignment 应为空")


# ============================================================================
# AC-009：get_tag_info(&"nonexistent") 无效 tag_id → 空 Dictionary + push_warning
# ============================================================================

func test_ac009_get_tag_info_invalid_returns_empty_and_warns() -> void:
	var info: Dictionary = fs.get_tag_info(&"nonexistent")
	assert_eq(info, {}, "无效 tag_id 应返回空字典")
	assert_push_warning_count(1, "无效 tag_id 应 push_warning 1 次")


# ============================================================================
# AC-010：get_major_alignments 返回 2 个大阵营
# ============================================================================

func test_ac010_get_major_alignments() -> void:
	var result: Array[StringName] = fs.get_major_alignments()
	assert_eq(result.size(), 2, "应返回 2 个大阵营")
	assert_true(result.has(&"zhengdao"), "应包含 zhengdao")
	assert_true(result.has(&"modao"), "应包含 modao")


# ============================================================================
# AC-011：derive_major_alignment(&"qixuanmen") → &"zhengdao"
# ============================================================================

func test_ac011_derive_major_zhengdao_sect() -> void:
	assert_eq(fs.derive_major_alignment(&"qixuanmen"), &"zhengdao", "青云剑宗应推导为正道")


# ============================================================================
# AC-012：derive_major_alignment(&"xuehai_temple") → &"modao"
# ============================================================================

func test_ac012_derive_major_modao_sect() -> void:
	assert_eq(fs.derive_major_alignment(&"xuehai_temple"), &"modao", "血海殿应推导为魔道")


# ============================================================================
# AC-013：derive_major_alignment(&"zhengdao") → &"zhengdao"（大阵营自身）
# ============================================================================

func test_ac013_derive_major_self() -> void:
	assert_eq(fs.derive_major_alignment(&"zhengdao"), &"zhengdao", "大阵营自身应返回自身")
	assert_eq(fs.derive_major_alignment(&"modao"), &"modao", "大阵营自身应返回自身")


# ============================================================================
# AC-014：derive_major_alignment(&"suixing_islands") → &""（跨阵营无归属）
# ============================================================================

func test_ac014_derive_major_cross_faction_returns_empty() -> void:
	assert_eq(fs.derive_major_alignment(&"suixing_islands"), &"", "跨阵营标签应返回空")


# ============================================================================
# AC-015：derive_major_alignment(&"nonexistent") → &""（无效 tag_id）
# ============================================================================

func test_ac015_derive_major_invalid_returns_empty() -> void:
	assert_eq(fs.derive_major_alignment(&"nonexistent"), &"", "无效 tag_id 应返回空")


# ============================================================================
# AC-019：FactionSystem 不发射任何信号
# ============================================================================

func test_ac019_no_signals_declared() -> void:
	# get_script_signal_list() 只返回脚本自身声明的信号，不含 Node 基类内置信号。
	# 这是 Godot 4.x 中区分脚本自定义信号与引擎内置信号的正确方法。
	var script_signals: Array = FS_SCRIPT.get_script_signal_list()
	assert_eq(script_signals.size(), 0, "FactionSystem 不应声明任何自有信号")


# ============================================================================
# AC-020：FactionSystem _ready 为空或不存在（const Dictionary 编译时分配）
# ============================================================================

func test_ac020_ready_is_empty_or_absent() -> void:
	# 检查源码——_ready 不应含可执行语句（const Dictionary 编译时分配，零运行时加载开销）
	var source: String = FS_SCRIPT.source_code
	if source.find("func _ready") == -1:
		# _ready 不存在——符合"为空或不存在"
		assert_true(true, "_ready 不存在，通过")
		return
	# 若存在 _ready——提取方法体并断言其仅含注释/空行
	var start: int = source.find("func _ready")
	var body_start: int = source.find("\n", start)
	# 找下一个顶层 func 或文件末尾作为 _ready 方法体结束
	var next_func: int = source.find("\nfunc ", body_start + 1)
	var body_end: int = next_func if next_func != -1 else source.length()
	var body: String = source.substr(body_start, body_end - body_start)
	# 移除注释行和空白后应为空
	var lines: PackedStringArray = body.split("\n")
	var has_executable: bool = false
	for line in lines:
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		has_executable = true
		break
	assert_false(has_executable, "_ready 方法体应为空（const Dictionary 编译时分配，无运行时初始化）")


# ============================================================================
# 边缘情况补强：所有门派标签推导正确 + 跨阵营标签清单
# ============================================================================

func test_all_zhengdao_sects_derive_to_zhengdao() -> void:
	var zhengdao_sects: Array[StringName] = [
		&"qixuanmen", &"dangxia_valley", &"xuanbing_palace",
		&"dongyu", &"xingdou_sect", &"wei_family",
	]
	for sect in zhengdao_sects:
		assert_eq(fs.derive_major_alignment(sect), &"zhengdao",
			"正道门派 %s 应推导为 zhengdao" % sect)


func test_all_modao_sects_derive_to_modao() -> void:
	var modao_sects: Array[StringName] = [
		&"xuehai_temple", &"meiying_pavilion", &"samsara_hall",
		&"xuesha_cult", &"heisha_cult", &"yunmeng",
	]
	for sect in modao_sects:
		assert_eq(fs.derive_major_alignment(sect), &"modao",
			"魔道门派 %s 应推导为 modao" % sect)


func test_all_cross_faction_tags_return_empty_alignment() -> void:
	var cross_tags: Array[StringName] = [
		&"suixing_islands", &"guixu_abyss", &"wanxiang_pavilion", &"jiyin_island",
	]
	for tag in cross_tags:
		assert_eq(fs.derive_major_alignment(tag), &"",
			"跨阵营标签 %s 应返回空大阵营" % tag)


func test_every_library_entry_has_required_fields() -> void:
	# 所有 18 条目必须有 name / parent_alignment / is_major / icon 四个字段
	for tag_id in FS_SCRIPT.FACTION_LIBRARY:
		var info: Dictionary = FS_SCRIPT.FACTION_LIBRARY[tag_id]
		assert_true(info.has("name"), "%s 应有 name 字段" % tag_id)
		assert_true(info.has("parent_alignment"), "%s 应有 parent_alignment 字段" % tag_id)
		assert_true(info.has("is_major"), "%s 应有 is_major 字段" % tag_id)
		assert_true(info.has("icon"), "%s 应有 icon 字段" % tag_id)
		# name 应为非空字符串
		assert_true(str(info.name).length() > 0, "%s 的 name 不应为空" % tag_id)


func test_major_alignments_only_contains_is_major_entries() -> void:
	# get_major_alignments 返回的每个 tag 在库中应 is_major=true
	var majors: Array[StringName] = fs.get_major_alignments()
	for tag_id in majors:
		var info: Dictionary = fs.get_tag_info(tag_id)
		assert_true(info.is_major, "%s 应 is_major=true" % tag_id)


func test_invalid_tag_info_does_not_pollute_derive() -> void:
	# 连续调用无效 tag_id 后，有效 tag_id 仍正常工作
	assert_eq(fs.derive_major_alignment(&"nonexistent"), &"", "无效 tag_id 应返回空")
	assert_eq(fs.derive_major_alignment(&"qixuanmen"), &"zhengdao", "有效 tag_id 仍应正常推导")


func test_get_tags_of_character_without_card_system_returns_empty() -> void:
	# 测试环境无 CardSystem Autoload——应优雅返回空数组而非崩溃
	var tags: Array[StringName] = fs.get_tags_of_character(12345)
	assert_eq(tags.size(), 0, "无 CardSystem 时应返回空数组")


func test_belongs_to_alignment_without_card_system_returns_false() -> void:
	# 测试环境无 CardSystem——belongs_to_alignment 应优雅返回 false
	assert_false(fs.belongs_to_alignment(12345, &"zhengdao"),
		"无 CardSystem 时 belongs_to_alignment 应返回 false")