extends GutTest
## UID 边车（[code].uid[/code]）的提交策略回归——「缺边车会不会让引用解析不稳」的收口。
##
## [b]查到的现状[/b]：[code].uid[/code] 由编辑器生成（[code]--headless --editor --quit[/code]
## 即可，不必开图形界面），内容一行 [code]uid://xxx[/code]。仓库里已有 1082 个被跟踪，
## 另有 75 个未跟踪（本轮新增脚本 + 历轮遗留的探针）。[code].gitignore[/code] 里没有
## [code].uid[/code] 条目。[br]
## [br][b]UID 是确定的还是随机的[/b]：由路径哈希得出。实测删掉
## [code]world_seam.gd.uid[/code] 后重跑编辑器，生成的仍是 [code]uid://c5gkxtx7smlog[/code]
## ——与删除前逐字相同。故「谁补的、在哪台机器补的」不影响结果。[br]
## [br][b]缺边车会不会让解析不稳[/b]：取决于引用方式。实测 [code]src/[/code] 下 39 条
## [code][ext_resource][/code] [b]全部[/b]用 [code]path="res://..."[/code]，
## [code]uid=[/code] 属性 0 条、[code]gd_scene[/code] 头的 [code]uid=[/code] 0 条、
## [code].gd[/code] 里的 [code]uid://[/code] 字符串 0 处——所以在 [code]src/[/code] 这半边
## 缺边车[b]当下不报错[/b]。但 [code]prototypes/[/code] 与 [code]resources/audio/[/code]
## 已经用上 [code]uid://[/code]（[code]battle.tscn[/code] 等），那条路上缺边车就是硬失败。[br]
## [br][b]本轮定夺：提交边车（不 ignore）[/b]。代价与理由：[br]
##   · 提交的代价≈0——UID 由路径确定，两台机器生成的字节相同，不会产生「谁的版本对」之争；[br]
##   · ignore 的代价是「新克隆的机器在首次打开编辑器前，[code]uid://[/code] 引用解析不了」，
##     而且仓库里已经跟踪了 1082 个——再 ignore 等于把既有的一半推翻，
##     出现「有的提交有的不提交」这种更难查的状态。[br]
##   · [code].gitignore[/code] 与项目其余部分无冲突（它就是按「引擎产物但需要入库」
##     这一档处理的，与 [code]*.import[/code] 同类）。[br]
## [br][b]本案守什么[/b]：不守「文件数量对得上 1082」（那会随每次加脚本而红），守的是
## 「[code]src/[/code] 下引用资源的场景不依赖 UID」这条[b]当下成立的前提[/b]——哪天有人
## 改用 [code]uid://[/code] 引用，本案转红，提醒他必须同时提交边车。[br]
## [br]依据：[code]docs/engine-reference/godot/current-best-practices.md[/code]
## 「资源 UID 边车（4.4+）」。

## 扫引用方式的源码根（[code]src/[/code] 是生产代码；探针不在此列）。
const SRC_ROOT: String = "res://src"


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 边车是「路径确定」的——不是随机数
# ═══════════════════════════════════════════════════════════════════════════════

## 已入库的边车内容必须是一行合法 [code]uid://[/code]。这条在边车被写坏
## （空文件 / 内容被误改 / 被 git 的 CRLF 转换污染）时转红。
func test_committed_uid_sidecars_are_well_formed() -> void:
	# Arrange —— 抽查生产目录下的若干边车（全扫 1082 个对每条用例都偏重）
	var samples: Array[String] = [
		"res://src/ui/main_menu/world_seam.gd.uid",
		"res://src/ui/hud/notification_toast_area.gd.uid",
		"res://src/ui/hud/notification_toast_render.gd.uid",
		"res://src/ui/hud/notification_toast_anim.gd.uid",
		"res://src/ui/identity_select/identity_select.gd.uid",
	]
	# Act + Assert
	for path: String in samples:
		assert_true(FileAccess.file_exists(path),
				"%s 应存在（新脚本提交时须一并提交其 .uid）" % path)
		var content: String = FileAccess.get_file_as_string(path).strip_edges()
		assert_true(content.begins_with("uid://"),
				"%s 内容应是以 uid:// 开头的一行，实际：%s" % [path, content])
		assert_eq(content.split("\n").size(), 1,
				"%s 应只有一行（多行说明被写坏）" % path)


# ═══════════════════════════════════════════════════════════════════════════════
# 2. src/ 的引用不依赖 UID——这是「提交边车」策略能低代价成立的前提
# ═══════════════════════════════════════════════════════════════════════════════

## [code]src/[/code] 下所有 [code].tscn[/code] 的 [code][ext_resource][/code] 都写
## [code]path="res://..."[/code]，没有 [code]uid=[/code] 属性。[br]
## [b]转红意味着[/b]：有人改用了 [code]uid://[/code] 引用——那时缺边车就是解析失败，
## 必须保证每个被引用的资源都有已提交的边车（把本文件第 1 案的抽样扩成全扫）。
func test_src_scenes_reference_by_path_not_by_uid() -> void:
	# Arrange
	var offenders: Array[String] = []
	# Act
	_scan_ext_resource(SRC_ROOT, offenders)
	# Assert
	assert_eq(offenders, [] as Array[String],
			"src/ 下场景应以 path 引用资源（改用 uid:// 前需先确保边车入库）；"
			+ "违规处：%s" % str(offenders))


## 扫节点图 / 战斗 / 主菜单三个真实场景，确认它们[b]没有[/b]写 [code]uid=[/code]。
## 与上一案成对：上一案扫全部，这一案把三张关键场景的行号钉出来，失败时能直接定位。
func test_key_scenes_have_no_uid_only_ext_resource() -> void:
	# Arrange
	var scenes: Array[String] = [
		"res://src/ui/main_menu/MainMenu.tscn",
		"res://src/feature/combat/combat_scene.tscn",
		"res://src/ui/exploration/node_graph_screen.tscn",
	]
	# Act + Assert
	for path: String in scenes:
		var text: String = FileAccess.get_file_as_string(path)
		assert_ne(text, "", "应能读到 %s" % path)
		var lines: PackedStringArray = text.split("\n")
		for i: int in range(lines.size()):
			if lines[i].begins_with("[ext_resource"):
				assert_false(lines[i].contains("uid="),
						"%s:%d 的 ext_resource 不应带 uid=（当前约定是按 path 引用）"
						% [path, i + 1])


## 递归扫目录，把 [code][ext_resource][/code] 行里带 [code]uid=[/code] 的记进
## [param p_out]（带行号，失败信息可定位）。
func _scan_ext_resource(p_dir: String, p_out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(p_dir)
	if dir == null:
		fail_test("目录打不开：%s" % p_dir)
		return
	for sub: String in dir.get_directories():
		_scan_ext_resource(p_dir.path_join(sub), p_out)
	for file: String in dir.get_files():
		if not file.ends_with(".tscn") and not file.ends_with(".tres"):
			continue
		var path: String = p_dir.path_join(file)
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in range(lines.size()):
			if lines[i].begins_with("[ext_resource") and lines[i].contains("uid="):
				p_out.append("%s:%d" % [path, i + 1])
