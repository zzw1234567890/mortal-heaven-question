class_name EndingEvaluator
extends RefCounted
## EndingEvaluator —— 结局分支判定引擎纯函数工具类（ADR-0029）。
##
## Feature 层 RefCounted（非 Autoload）。持有 3 条结局线的 const Dictionary[br]
## 评分权重表和判定算法。通关时由 StorySystem 实例化一次，[br]
## 传入 story_flags + chapter_path + run_data，返回结局结果 Dictionary。[br]
## 自身不持有任何运行时持久状态。[br]
## [br][b]Story 6-15 范围[/b]：ENDING_TEMPLATES + evaluate 主入口。[br]
## [br]来源: ADR-0029 §决策 1/2 + GDD ending-branch-system.md §1/§2。


# === 结局线前缀映射 ==========================================================

## 结局线 → ending_id 前缀映射（GDD §公式 4 命名规则）。
const LINE_PREFIX: Dictionary = {
	"ascend": "ascension",
	"guard": "guardian",
	"return": "return",
}

## 结局线优先级——平局时按此顺序打破僵局（GDD §3）。
const LINE_PRIORITY: Array = ["ascend", "guard", "return"]

## 第 5 章偏斜加分（GDD §3 平局解决）。
const CH5_BIAS: int = 5

## 尾声插入段落上限（GDD §7）。
const EPILOGUE_MAX_LINES: int = 12


# === 结局模板（const Dictionary——编译时常量，运行时只读）==================

## 3 条结局线评分权重表（GDD §2 三条结局主线）。[br]
## 键 = 结局线 ID（String），值 = 线数据 Dictionary。[br]
## [br]每条线含：name / theme / emotion / conditions / variants / epilogue_base。[br]
## [br]conditions 数组中每项含：chapter_choice（[章号, 期望值]）或 flag 或[br]
## run_key（运行数据键 + operator + value），以及 weight 和 desc。[br]
## [br]来源: GDD ending-branch-system.md §2 + ADR-0029 §决策 2。
const ENDING_TEMPLATES: Dictionary = {
	# 飞升仙界 —— 天道终点
	"ascend": {
		"name": "飞升仙界",
		"theme": "天道终点",
		"emotion": "宏大、释然、新的开始",
		"conditions": [
			{"chapter_choice": ["ch5", "ascend"], "weight": 30, "desc": "第5章选择「飞升仙界」"},
			{"chapter_choice": ["ch4", "ascend_alone"], "weight": 15, "desc": "第4章独自飞升"},
			{"chapter_choice": ["ch4", "ascend_with_yinyue"], "weight": 15, "desc": "第4章携伴飞升"},
			{"chapter_choice": ["ch3", "defend_righteous"], "weight": 10, "desc": "坚守正道"},
			{"chapter_choice": ["ch2", "destroy_cave"], "weight": 8, "desc": "拒绝诱惑"},
			{"chapter_choice": ["ch1", "reject_mo"], "weight": 7, "desc": "拒绝墨渊"},
			{"run_key": "elites_killed", "operator": "ge", "value": 20, "weight": 5, "desc": "战力证明"},
			{"run_key": "unique_cards", "operator": "ge", "value": 100, "weight": 5, "desc": "博学广识"},
		],
		"variants": {
			"solo": {"condition": "ch4 != ascend_with_yinyue", "name": "仙道孤独"},
			"duo": {"condition": "ch4 == ascend_with_yinyue", "name": "仙侣同行"},
		},
		"epilogue_base": "天梯尽头，仙界之门缓缓开启……",
	},
	# 留在归墟之境 —— 守护之道
	"guard": {
		"name": "留在归墟之境",
		"theme": "守护之道",
		"emotion": "沉稳、担当、余生",
		"conditions": [
			{"chapter_choice": ["ch5", "guard"], "weight": 30, "desc": "第5章选择「留在归墟之境」"},
			{"chapter_choice": ["ch3", "neutral_mediate"], "weight": 15, "desc": "中立调停"},
			{"chapter_choice": ["ch2", "take_secret"], "weight": 10, "desc": "夺取秘宝"},
			{"chapter_choice": ["ch1", "accept_mo"], "weight": 8, "desc": "接受墨渊"},
			{"run_key": "craft_count", "operator": "ge", "value": 20, "weight": 8, "desc": "炼制≥20次"},
			{"flag": "yinyue_alive", "weight": 5, "desc": "银翎存活"},
			{"run_key": "identity", "operator": "in", "value": ["star_storm_wanderer", "yellow_maple_disciple"], "weight": 5, "desc": "非正非邪身份"},
		],
		"variants": {
			"lone": {"condition": "NOT (yinyue_alive AND ch4 == ascend_with_yinyue)", "name": "孤身守望"},
			"order": {"condition": "yinyue_alive AND ch4 == ascend_with_yinyue", "name": "建立新秩序"},
		},
		"epilogue_base": "你立于归墟之境最高处，俯瞰这片你守护了半生的山河……",
	},
	# 归隐东域 —— 凡人之心
	"return": {
		"name": "归隐东域",
		"theme": "凡人之心",
		"emotion": "宁静、圆满、归家",
		"conditions": [
			{"chapter_choice": ["ch5", "return"], "weight": 30, "desc": "第5章选择「归隐东域」"},
			{"chapter_choice": ["ch1", "reject_mo"], "weight": 12, "desc": "初心不改"},
			{"flag": "ch2_rebuilt_foundation", "weight": 10, "desc": "重新筑基"},
			{"chapter_choice": ["ch3", "*"], "weight": 5, "desc": "东域故乡"},
			{"run_key": "elites_killed", "operator": "le", "value": 10, "weight": 8, "desc": "不嗜杀"},
			{"run_key": "identity", "operator": "eq", "value": "seven_peaks_disciple", "weight": 10, "desc": "青云剑宗弟子"},
			{"run_key": "total_reincarnations", "operator": "ge", "value": 5, "weight": 5, "desc": "看尽繁华"},
		],
		"variants": {
			"home": {"condition": "NOT (yinyue_alive AND unlocked_talents >= 10 AND total_completions >= 3)", "name": "归隐凡间"},
			"sect": {"condition": "yinyue_alive AND unlocked_talents >= 10 AND total_completions >= 3", "name": "开宗立派"},
		},
		"epilogue_base": "你推开青云剑宗旧居的木门，夕阳从门缝洒入，屋内一切如旧……",
	},
}


# === 主入口（Story 6-15）===================================================

## 结局判定主入口——收集输入→计算得分→解析平局→判定变体→生成尾声（ADR-0029）。[br]
## [br][param event_system] EventSystem 引用（用于 get_flag() 只读查询 story_flags）。[br]
## [br][param chapter_path] 5 章结局选择路径 {"ch1": "reject_mo", ...}。[br]
## [br][param run_data] 本局运行数据快照 {elites_killed, unique_cards, craft_count, ...}。[br]
## [br][b]返回[/b]: Dictionary——{ending_id, ending_line, variant, line_name, variant_name, scores, epilogue}。[br]
## [br]来源: ADR-0029 §决策 1 + GDD §1。
func evaluate(event_system: Node, chapter_path: Dictionary, run_data: Dictionary) -> Dictionary:
	# 1. 计算三条线得分
	var scores: Dictionary = _calculate_scores(event_system, chapter_path, run_data)

	# 2. 解析平局——确定主结局线
	var ch5_choice: String = str(chapter_path.get("ch5", ""))
	var ending_line: String = _resolve_tie(scores.duplicate(), ch5_choice)

	# 3. 判定变体
	var variant: String = _determine_variant(ending_line, event_system, chapter_path, run_data)

	# 4. 组装 ending_id
	var prefix: String = str(LINE_PREFIX.get(ending_line, ending_line))
	var ending_id: String = prefix + "_" + variant

	# 5. 生成尾声叙事
	var epilogue: String = _generate_epilogue(ending_id, event_system, chapter_path)

	# 6. 获取线名和变体名
	var line_data: Dictionary = ENDING_TEMPLATES.get(ending_line, {})
	var variant_data: Dictionary = line_data.get("variants", {}).get(variant, {})

	return {
		"ending_id": ending_id,
		"ending_line": ending_line,
		"variant": variant,
		"line_name": str(line_data.get("name", "")),
		"variant_name": str(variant_data.get("name", "")),
		"scores": scores,
		"epilogue": epilogue,
	}


# === 评分计算（纯函数）=======================================================

## 计算三条结局线得分（GDD §公式 1）。[br]
## [br][param event_system] EventSystem 引用。[br]
## [br][param chapter_path] 5 章选择路径。[br]
## [br][param run_data] 运行数据。[br]
## [br][b]返回[/b]: {ascend: int, guard: int, return: int}。[br]
## [br]来源: ADR-0029 §评分计算算法 + GDD §公式 1。
func _calculate_scores(event_system: Node, chapter_path: Dictionary, run_data: Dictionary) -> Dictionary:
	var scores: Dictionary = {"ascend": 0, "guard": 0, "return": 0}

	for line: String in ENDING_TEMPLATES:
		var line_data: Dictionary = ENDING_TEMPLATES[line]
		var conditions: Array = line_data.get("conditions", [])

		for cond: Dictionary in conditions:
			var weight: int = int(cond.get("weight", 0))

			if cond.has("chapter_choice"):
				var cc: Array = cond["chapter_choice"]
				var ch: String = str(cc[0])
				var expected: String = str(cc[1])
				var actual: String = str(chapter_path.get(ch, ""))
				if actual == expected or expected == "*":
					scores[line] = int(scores[line]) + weight

			elif cond.has("flag"):
				var flag_name: StringName = StringName(str(cond["flag"]))
				var flag_val: Variant = _get_flag(event_system, flag_name, false)
				if bool(flag_val):
					scores[line] = int(scores[line]) + weight

			elif cond.has("run_key"):
				if _check_run_condition(run_data, cond):
					scores[line] = int(scores[line]) + weight

	return scores


# === 平局解决（纯函数）=======================================================

## 解析平局——第 5 章偏斜 +5 + 优先级打破僵局（GDD §3）。[br]
## [br][param scores] 得分字典（会被修改——传入前应 duplicate）。[br]
## [br][param ch5_choice] 第 5 章选择的简化值（ascend/guard/return）。[br]
## [br][b]返回[/b]: 最终结局线 ID（ascend/guard/return）。[br]
## [br]来源: ADR-0029 §评分计算算法 _resolve_tie + GDD §3。
func _resolve_tie(scores: Dictionary, ch5_choice: String) -> String:
	# 第 5 章偏斜
	if scores.has(ch5_choice):
		scores[ch5_choice] = int(scores[ch5_choice]) + CH5_BIAS

	# 最高分
	var max_val: int = int(scores["ascend"])
	if int(scores["guard"]) > max_val:
		max_val = int(scores["guard"])
	if int(scores["return"]) > max_val:
		max_val = int(scores["return"])

	# 优先级打破平局
	for line: String in LINE_PRIORITY:
		if int(scores[line]) == max_val:
			return line

	return "ascend"  # fallback——不应到达


# === 变体判定（纯函数）=======================================================

## 判定结局变体（GDD §公式 3）。[br]
## [br][param line] 主结局线（ascend/guard/return）。[br]
## [br][param event_system] EventSystem 引用。[br]
## [br][param chapter_path] 5 章选择路径。[br]
## [br][param run_data] 运行数据。[br]
## [br][b]返回[/b]: 变体 ID（solo/duo/lone/order/home/sect）。[br]
## [br]来源: ADR-0029 §评分计算算法 _determine_variant + GDD §公式 3。
func _determine_variant(line: String, event_system: Node, chapter_path: Dictionary, run_data: Dictionary) -> String:
	match line:
		"ascend":
			if str(chapter_path.get("ch4", "")) == "ascend_with_yinyue":
				return "duo"
			return "solo"

		"guard":
			var yinyue: bool = bool(_get_flag(event_system, &"yinyue_alive", false))
			var ch4_accompany: bool = str(chapter_path.get("ch4", "")) == "ascend_with_yinyue"
			if yinyue and ch4_accompany:
				return "order"
			return "lone"

		"return":
			var yinyue2: bool = bool(_get_flag(event_system, &"yinyue_alive", false))
			var talents: int = int(run_data.get("unlocked_talents", 0))
			var completions: int = int(run_data.get("total_completions", 0))
			if yinyue2 and talents >= 10 and completions >= 3:
				return "sect"
			return "home"

	return "solo"  # fallback


# === 尾声叙事生成（纯函数）===================================================

## 生成尾声叙事文本——基础文本 + story_flags 驱动的插入段落（GDD §7）。[br]
## [br][param ending_id] 结局 ID。[br]
## [br][param event_system] EventSystem 引用。[br]
## [br][param chapter_path] 5 章选择路径。[br]
## [br][b]返回[/b]: 完整尾声叙事文本。[br]
## [br]来源: ADR-0029 §尾声叙事文本生成 + GDD §7。
func _generate_epilogue(ending_id: String, event_system: Node, chapter_path: Dictionary) -> String:
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


# === 辅助方法 =================================================================

## 安全读取 EventSystem flag——兼容 null event_system（测试用）。
func _get_flag(event_system: Node, flag: StringName, default_val: Variant) -> Variant:
	if event_system == null or not is_instance_valid(event_system):
		return default_val
	if not event_system.has_method("get_flag"):
		return default_val
	return event_system.get_flag(flag, default_val)


## 检查运行数据条件。[br]
## [br][param run_data] 运行数据字典。[br]
## [br][param cond] 条件字典（含 run_key / operator / value）。
## [br][b]返回[/b]: 条件是否满足。
func _check_run_condition(run_data: Dictionary, cond: Dictionary) -> bool:
	var key: String = str(cond.get("run_key", ""))
	var op: String = str(cond.get("operator", ""))
	var expected = cond.get("value", null)
	var actual = run_data.get(key, null)

	if actual == null:
		return false

	match op:
		"ge":
			return int(actual) >= int(expected)
		"le":
			return int(actual) <= int(expected)
		"eq":
			return str(actual) == str(expected)
		"in":
			var expected_arr: Array = expected if expected is Array else []
			return expected_arr.has(str(actual))
		_:
			return false
