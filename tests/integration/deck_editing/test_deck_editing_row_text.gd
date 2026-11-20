extends "res://tests/integration/deck_editing/deck_editing_fixture.gd"
## 卡组编辑两栏的[b]行内文本[/b]用例（真实 .tscn + 真实 CardSystem + 真实收藏与卡组）。[br]
## [br][b]为什么另起一个文件[/b]：既有 [code]test_deck_editing_flow.gd[/code] 断的是
## 「行数」与「载荷去向」——它读 [code]collection_count()[/code] 与
## [code]payload_at()[/code]，两条都不经过行控件的文本。[br]
## 而 [code]DeckEditingView.count_of[/code] 数的是它[b]渲染那一刻自己记下的数[/b]，
## [code]payload_at[/code] 读的是 [code]Button[/code] 上的元数据——两者在「控件建出来了
## 但一个字都没写上 / 写上了但不可见」时[b]照样正确[/b]。于是出现「读数说 3 行、6 行，
## 屏幕上一个字都没有」这种两条口径各自自洽、合起来骗人的状态。[br]
## [br][b]所以这里断的是文本本身[/b]：[member Button.text] 是渲染器与屏幕阅读器读的
## 同一份东西——它非空且含中文卡名，才等于「行里真的有字」。[br]
## [br][b]为什么实例化 .tscn 而不是 [code]ScreenScript.new()[/code][/b]：玩家到达的是场景
## （[code]SceneManager.SCENE_PATHS[/code] 指向它），[code]_init[/code] → 进树 →
## [code]_ready[/code] 的时序由引擎给；手 new 一个控件是另一条路径，测不出场景装配的问题。[br]
## [br][b]为什么等模板而不是直接断言[/b]：[code]CardSystem._ready[/code] 用
## [code]load_threaded_request[/code] 异步装载模板，装载完成前
## [code]get_template_by_instance_id[/code] 一律返回 null——右栏那一张直接不出行
## （[code]DeckViewRows.build[/code] 的口径是「取不到就不臆造」）。
## 这时断「6 行」会红，但红的原因是环境没就绪、不是界面错——用例必须先等环境。[br]
##
## 来源: .claude/docs/coding-standards.md（§验证驱动开发——UI 用截图/渲染实证）、
## .claude/rules/test-standards.md、先例 [code]test_deck_editing_flow.gd[/code]。

## 卡组编辑场景（玩家实际到达的那一份）。
const SCENE_PATH: String = "res://src/ui/deck_editing/deck_editing.tscn"

## 等模板装载的帧上限（超限即判环境未就绪——不无限等，也不静默放行）。
const MAX_TEMPLATE_FRAMES: int = 240

## 三张模板的中文卡名（[code]assets/cards/templates/*.tres[/code] 的 [code]name[/code]）
## ——用例断言行文本含的是[b]它[/b]，不是 [code]template_id[/code]、不是
## [code]#实例号[/code]。
const NAME_PILL: String = "玉灵丹"
const NAME_ARTIFACT: String = "中品法器"
const NAME_TALISMAN: String = "基础攻击"


## 两栏每一行的文本都非空、且含该行那张卡的中文名。[br]
## [br]这是本轮要抓住的那个现象：[code]count_of[/code] 报的行数与屏幕上真的有字
## 是两件事，只有读 [member Button.text] 才能把两者钉在一起。
func test_both_columns_render_chinese_names_in_every_row() -> void:
	# Arrange：环境就绪 + 一份确定的收藏与卡组
	assert_true(await _await_templates_ready(), "模板未在帧上限内装载完成——环境未就绪")
	assert_true(seed_collection(), "收藏未铺成（模板或校验不可用）")
	seed_deck()
	_mount_scene()

	# Assert：行数先站住（否则下面逐行断言会在空数组上空转）
	assert_eq(screen.collection_count(), 3, "左栏应按模板合并成 3 行")
	assert_eq(screen.deck_count(), 6, "右栏应逐实例列出 6 行")

	# Assert：左栏每一行都写着自己的中文卡名
	var left_texts: Array = screen.collection_texts()
	for index: int in range(left_texts.size()):
		var text: String = str(left_texts[index])
		var expected: String = _name_of_template(_template_of_row(0, index))
		assert_false(text.strip_edges().is_empty(), "左栏第 %d 行的文本是空的" % index)
		assert_true(text.contains(expected),
				"左栏第 %d 行应含「%s」，实际是「%s」" % [index, expected, text])

	# Assert：右栏每一行同理（逐实例——三张丹药应各出现一次）
	var right_texts: Array = screen.deck_texts()
	for index: int in range(right_texts.size()):
		var text: String = str(right_texts[index])
		var expected: String = _name_of_instance(_instance_of_row(1, index))
		assert_false(text.strip_edges().is_empty(), "右栏第 %d 行的文本是空的" % index)
		assert_true(text.contains(expected),
				"右栏第 %d 行应含「%s」，实际是「%s」" % [index, expected, text])


## 行控件本身是可见的、且有高度。[br]
## [br][b]为什么这条单独存在[/b]：文本写对了但控件 [code]visible = false[/code]
## 或被压成 0 高，屏幕上照样什么都没有——[code]clear_box[/code] 那个「清空容器时
## 顺手把容器隐藏」的坑就是这么漏过一轮的（见
## [code]deck_editing_view.gd[/code] 的 [method DeckEditingView.rebuild]）。
## 文本断言与可见性断言合起来才等于「玩家看得见字」。
func test_every_row_control_is_visible_and_has_height() -> void:
	assert_true(await _await_templates_ready(), "模板未在帧上限内装载完成——环境未就绪")
	assert_true(seed_collection(), "收藏未铺成（模板或校验不可用）")
	seed_deck()
	_mount_scene()

	for column: int in [NavScript.COLUMN_COLLECTION, NavScript.COLUMN_DECK]:
		var rows: Array = _rows_of(column)
		assert_gt(rows.size(), 0, "第 %d 栏一行都没有" % column)
		for index: int in range(rows.size()):
			var row: Control = rows[index]
			assert_true(row.is_visible_in_tree(),
					"第 %d 栏第 %d 行的控件不在可见树上" % [column, index])
			assert_gt(row.size.y, 0.0,
					"第 %d 栏第 %d 行的高度是 0——画得再对也看不见" % [column, index])


## 行文本不是兜底号也不是模板 ID（兜底号只在模板真的读不到时才该出现）。[br]
## [br][code]CardFaceRules.fields_of[/code] 在名字为空时回退 [code]#实例号[/code]；
## 模板齐备时这行字不该出现——出现即说明「取的是 ID 而不是卡名」。
func test_row_text_is_not_a_fallback_id() -> void:
	assert_true(await _await_templates_ready(), "模板未在帧上限内装载完成——环境未就绪")
	assert_true(seed_collection(), "收藏未铺成（模板或校验不可用）")
	seed_deck()
	_mount_scene()

	for column: int in [NavScript.COLUMN_COLLECTION, NavScript.COLUMN_DECK]:
		var texts: Array = screen.collection_texts() if column == 0 else screen.deck_texts()
		for index: int in range(texts.size()):
			var text: String = str(texts[index])
			assert_false(text.begins_with("#"),
					"第 %d 栏第 %d 行显示的是实例号兜底名「%s」" % [column, index, text])
			assert_false(text.contains("pill_yu_ling_dan") or text.contains("artifact_zhong_pin_fa_qi")
					or text.contains("basic_attack"),
					"第 %d 栏第 %d 行显示的是模板 ID：「%s」" % [column, index, text])


## 模板装载完成之后，界面自己会把两栏补齐（不必靠调用方再喊一次刷新）。[br]
## [br][b]为什么这条必要[/b]：[code]CardSystem._ready[/code] 用
## [code]load_threaded_request[/code] 分批装载模板（每帧 10 个），而
## [code]DeckEditingScreen._ready[/code] 只刷一次就再不回头——玩家若在装载完成前
## 进这一屏，右栏会缺行（[code]DeckViewRows.build[/code] 的「取不到不出行」口径），
## 且此后永远缺着：界面上再没有任何东西会触发第二次刷新。[br]
## [br][b]怎么摆出「未就绪」[/b]：不靠真实时序（它在测试里不可复现，模板早就装载完了），
## 而是把模板注册表暂时清空——这与「模板还没装载出来」对界面是同一件事，
## 恢复后再发 [code]templates_loaded[/code] 就是「装载完成」。[br]
## [br][b]为什么自己发信号而不是等真实装载[/b]：本用例测的是「界面有没有在模板就绪时
## 自刷」这条接线，不是 CardSystem 的装载行为（那有它自己的用例）。
func test_columns_refresh_when_templates_finish_loading() -> void:
	# Arrange：先在模板齐备的状态下挂载，确认基线是 6 行
	assert_true(await _await_templates_ready(), "模板未在帧上限内装载完成——环境未就绪")
	assert_true(seed_collection(), "收藏未铺成（模板或校验不可用）")
	seed_deck()
	_mount_scene()
	assert_eq(screen.deck_count(), 6, "基线：模板齐备时右栏应有 6 行")

	# Act：模拟「挂载那一刻模板还没装载出来」——清空注册表再刷一次
	var snapshot: Dictionary = _card_system_templates()
	_clear_card_system_templates()
	screen.refresh()
	var during: int = screen.deck_count()

	# Act：把注册表放回去并宣告「装载完成」
	_restore_card_system_templates(snapshot)
	CardSystem.emit_signal(&"templates_loaded", snapshot.size())

	# Assert
	assert_lt(during, 6, "模板未就绪时右栏本就该少行——这条前提不成立时下面的断言没有意义")
	assert_eq(screen.deck_count(), 6,
			"模板装载完成后界面应自己补齐两栏，实际仍是 %d 行" % screen.deck_count())
	for index: int in range(screen.deck_texts().size()):
		var text: String = str(screen.deck_texts()[index])
		assert_true(text.contains(NAME_PILL) or text.contains(NAME_ARTIFACT)
				or text.contains(NAME_TALISMAN),
				"补齐后的第 %d 行仍没有卡名：「%s」" % [index, text])


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 模板注册表的副本（用完必须还原——它是全进程单例，污染会波及后续用例）。
func _card_system_templates() -> Dictionary:
	return (CardSystem.get(&"templates") as Dictionary).duplicate()


## 清空模板注册表（模拟「装载尚未完成」）。
func _clear_card_system_templates() -> void:
	CardSystem.set(&"templates", {})


## 还原模板注册表。
func _restore_card_system_templates(p_snapshot: Dictionary) -> void:
	CardSystem.set(&"templates", p_snapshot)


## 实例化真实的 [code]deck_editing.tscn[/code] 并注入依赖（注入必须在进树前完成——
## [code]_ready[/code] 会现读它们）。[br]
## [br]与装置里的 [method mount_screen] 的区别只有这一处：那边 new 脚本，这边装配场景。
func _mount_scene() -> Control:
	EntryScript.request_edit(0)
	var packed: PackedScene = load(SCENE_PATH)
	screen = packed.instantiate() as Control
	screen.set(&"deck_system", DeckEditingSystem)
	screen.set(&"card_system", CardSystem)
	screen.set(&"gsm", GameStateManager)
	screen.set(&"save_load", sls)
	screen.set(&"scene_manager", sm)
	add_child_autofree(screen)
	return screen


## 等到三张模板都装载完成（每帧推进一步，超上限即返回 false——不静默放行）。
func _await_templates_ready() -> bool:
	var ids: Array = [PILL_ID, ARTIFACT_ID, TALISMAN_ID]
	for _i: int in range(MAX_TEMPLATE_FRAMES):
		var all_ready: bool = true
		for id: StringName in ids:
			if CardSystem.call(&"get_template", id) == null:
				all_ready = false
				break
		if all_ready:
			return true
		await get_tree().process_frame
	return false


## 某一栏的行控件数组。
func _rows_of(p_column: int) -> Array:
	return screen.rows_of(p_column)


## 左栏某行的模板 ID（载荷里那条）。
func _template_of_row(p_column: int, p_index: int) -> StringName:
	var payload: Dictionary = screen.payload_at(p_column, p_index)
	return StringName(str(payload.get("template_id", "")))


## 右栏某行的实例 ID。
func _instance_of_row(p_column: int, p_index: int) -> int:
	var payload: Dictionary = screen.payload_at(p_column, p_index)
	return int(payload.get("instance_id", 0))


## 模板 ID → 中文卡名（读的正是界面读的那份注册表）。
func _name_of_template(p_template_id: StringName) -> String:
	var template: Variant = CardSystem.call(&"get_template", p_template_id)
	if template == null:
		return ""
	return str((template as Object).get("name"))


## 实例 ID → 中文卡名（先按实例查模板，再读名字）。
func _name_of_instance(p_instance_id: int) -> String:
	var template: Variant = CardSystem.call(&"get_template_by_instance_id", p_instance_id)
	if template == null:
		return ""
	return str((template as Object).get("name"))
