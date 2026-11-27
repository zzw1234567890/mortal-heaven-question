extends GutTest
## 确认弹窗正文的单元测试（2026-11-27 修「确认选择弹框提示显示有问题」）。
##
## [b]为什么单独测这个纯函数[/b]：弹窗正文以前是两个自建子节点（NameLabel +
## Avatars）画出来的，AcceptDialog 会把子节点重新铺满内容区
## （`_update_child_rects`），结果名字被印章块压住、弹窗被撑到 726px 高。
## 改成只走 `dialog_text` 之后，「正文里到底该有哪几行」这件事必须有个锁——
## 否则下次有人再加一行/删一行，只有靠截图才看得出来。
##
## [b]不测的东西[/b]：弹窗尺寸、控件树结构。那是引擎布局行为，用例在 headless 下
## 拿不到真实渲染；尺寸由截图取证（`tools/ui_shot_confirm_*.png`）。
##
## 来源: design/gdd/identity-selection-system.md §用户界面需求、ADR-0031 §2。

const Rules := preload("res://src/ui/identity_select/identity_select_rules.gd")
const Templates := preload("res://src/feature/identity/identity_templates.gd")

const IDENTITY_ID: StringName = &"azure_sword_disciple"


## 造一条 get_available_identities() 形态的预览（只填 UI 读到的键）。
func _preview(p_names: Array[String]) -> Dictionary:
	var tmpl: Dictionary = Templates.IDENTITY_TEMPLATES[IDENTITY_ID]
	var details: Array = []
	for display_name: String in p_names:
		details.append({"display_name": display_name})
	return {
		"identity_id": IDENTITY_ID,
		"name": tmpl["name"],
		"character_details": details,
	}


func test_confirm_text_lists_identity_and_characters_then_prompt() -> void:
	var text: String = Rules.confirm_text(_preview(["林渊", "苏剑鸣"]))
	var lines: PackedStringArray = text.split("\n")
	assert_eq(lines.size(), 4, "应为「身份名 / 角色行 / 空行 / 确认提示」四行")
	assert_eq(lines[0], str(Templates.IDENTITY_TEMPLATES[IDENTITY_ID]["name"]),
			"第一行必须是身份名")
	assert_eq(lines[1], Rules.TEXT_CHARACTER_HEADER + "：林渊 · 苏剑鸣",
			"第二行应把两名角色用「 · 」连起来")
	assert_eq(lines[2], "", "第三行留空，把提示和身份信息隔开")
	assert_eq(lines[3], Rules.TEXT_CONFIRM_PROMPT, "最后一行是确认提示")


func test_confirm_text_is_stable_and_has_no_stray_whitespace() -> void:
	var a: String = Rules.confirm_text(_preview(["林渊", "苏剑鸣"]))
	var b: String = Rules.confirm_text(_preview(["林渊", "苏剑鸣"]))
	assert_eq(a, b, "同一份预览必须给出同一段正文（弹窗复用，不能自变）")
	for line: String in a.split("\n"):
		assert_eq(line, line.strip_edges(), "每行首尾不许有多余空白")


func test_confirm_text_survives_missing_character_details() -> void:
	# character_details 缺失 ⇒ 角色行整行不出现，而不是出现「初始角色：」空壳
	var preview: Dictionary = _preview([])
	var text: String = Rules.confirm_text(preview)
	assert_false(text.contains(Rules.TEXT_CHARACTER_HEADER),
			"没有角色时不应留下空的角色标题行")
	assert_true(text.contains(Rules.TEXT_CONFIRM_PROMPT), "确认提示必须在")
	assert_eq(text.split("\n").size(), 3, "身份名 / 空行 / 提示")


func test_confirm_text_handles_empty_preview() -> void:
	# 空字典（预览没拿到）⇒ 只剩提示，不许抛错也不许出现空身份名行
	var text: String = Rules.confirm_text({})
	assert_eq(text.split("\n").size(), 2, "空预览时只剩「空行 + 提示」")
	assert_true(text.contains(Rules.TEXT_CONFIRM_PROMPT), "确认提示必须在")
