extends RefCounted
## EndingEpilogue —— 结局尾声叙事生成子模块（从 ending_evaluator.gd 拆分）。
##
## 纯函数 RefCounted 类——不持有运行时状态，所有方法为 static。[br]
## 包含 _generate_epilogue + _get_flag 辅助方法。
##
## [br]来源: ADR-0029 §尾声叙事文本生成 + GDD ending-branch-system.md §7。
## [br]Sprint 11 Story 3：从 ending_evaluator.gd 拆分。


## 尾声插入段落上限（GDD §7）。
const EPILOGUE_MAX_LINES: int = 12

## 结局线前缀映射（与 EndingEvaluator 同值——子模块内独立声明）。
const LINE_PREFIX: Dictionary = {
	"ascend": "ascension",
	"guard": "guardian",
	"return": "return",
}

## 结局模板（与 EndingEvaluator 同值——子模块内独立声明）。
const ENDING_TEMPLATES: Dictionary = {
	"ascend": {
		"epilogue_base": "天梯尽头，仙界之门缓缓开启……",
	},
	"guard": {
		"epilogue_base": "你立于归墟之境最高处，俯瞰这片你守护了半生的山河……",
	},
	"return": {
		"epilogue_base": "你推开青云剑宗旧居的木门，夕阳从门缝洒入，屋内一切如旧……",
	},
}


## 生成尾声叙事文本——基础文本 + story_flags 驱动的插入段落（GDD §7）。[br]
## [br][param ending_id] 结局 ID。[br]
## [br][param event_system] EventSystem 引用。[br]
## [br][param chapter_path] 5 章选择路径。[br]
## [br][b]返回[/b]: 完整尾声叙事文本。[br]
## [br]来源: ADR-0029 §尾声叙事文本生成 + GDD §7。
static func generate_epilogue(ending_id: String, event_system: Node, chapter_path: Dictionary) -> String:
	# 从 ending_id 提取线名（如 ascension_solo → ascend）
	var line: String = ""
	for l: String in LINE_PREFIX:
		if ending_id.begins_with(str(LINE_PREFIX[l])):
			line = l
			break
	if line.is_empty():
		line = "ascend"

	var template: Dictionary = ENDING_TEMPLATES.get(line, {})
	var base: String = str(template.get("epilogue_base", ""))
	var insertions: Array = []

	# 第 1 章选择引用
	if bool(_get_flag(event_system, &"ch1_accepted_mo_condition", false)):
		insertions.append("你记得那一日在云澜城，墨渊的夺舍条件你曾动过念头……")

	# 第 2 章选择引用
	if bool(_get_flag(event_system, &"ch2_took_bone_secret", false)):
		insertions.append("枯骨老祖的秘宝至今仍在你储物袋中——力量的代价，你已经懂了。")
	else:
		insertions.append("摧毁枯骨洞府的那一击，让你在正道中赢得了尊重。")

	# 第 3 章选择引用
	if bool(_get_flag(event_system, &"ch3_joined_demonic", false)):
		insertions.append("东域的纷争中你选择了魔道——不是因为邪恶，而是你看到了正道的虚伪。")

	# 银翎存活引用
	if bool(_get_flag(event_system, &"yinyue_alive", false)):
		insertions.append("银翎在你身旁，一同望向远方——修仙路上，有人同行是莫大的幸运。")

	# 融入基础文本——最多 12 句
	var result: String = base
	for i: int in range(insertions.size()):
		if i >= EPILOGUE_MAX_LINES:
			break
		result += "\n\n" + str(insertions[i])

	return result


## 安全读取 EventSystem flag——兼容 null event_system（测试用）。[br]
## [br][param event_system] EventSystem 引用。[br]
## [br][param flag] flag 名称。[br]
## [br][param default_val] 默认值。[br]
## [br][b]返回[/b]: flag 值或默认值。
static func _get_flag(event_system: Node, flag: StringName, default_val: Variant) -> Variant:
	if event_system == null or not is_instance_valid(event_system):
		return default_val
	if not event_system.has_method("get_flag"):
		return default_val
	return event_system.get_flag(flag, default_val)
