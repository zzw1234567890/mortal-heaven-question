## SchoolConditions 入口与分派（继承链尾段——文件名与路径逐字不变）。
##
## [b]为什么这一段的路径不能动[/b]：[code]school_system.gd:_get_conditions[/code] 按字符串
## [code]load("res://src/core/school_system/school_conditions.gd").new()[/code] 装配本子模块；
## 改路径 = 检测引擎静默失效（[code]load[/code] 失败只在运行期报错）。
##
## [b]本层职责[/b]：唯一的两个对外方法——[method check_all_conditions]（全员满足即 true）
## 与 [method evaluate_condition]（条件类型 → 评估器的分派表，未知类型给中文兜底）。
## 两个方法都[b]只向下调用[/b]，故必须落在链尾：链序 标签规则 → 阵营/类型评估器 →
## 数值评估器 → [b]入口与分派（本段）[/b]。
extends "res://src/core/school_system/school_conditions_stat_evals.gd"
## SchoolConditions —— 流派检测条件评估引擎（[code]school_system.gd[/code] 的纯函数子模块）。
##
## [b]整条链的职责[/b]：[method check_all_conditions] + [method evaluate_condition] 分派器
## + 10 个 [code]_eval_*[/code] 评估器 + 4 个标签辅助方法。[br]
## 所有评估器接收 [code](cond, state)[/code] 并返回统一结构
## [code]{satisfied, weight, score, missing_text, skipped}[/code]——硬性条件以
## [code]weight = 0[/code] + [code]skipped = true[/code] 表示「不参与加权」。[br]
## [br][b]来源[/b]: ADR-0025 §关键接口 + GDD school-system.md §公式#1。[br]
## [br]Sprint 9 Story 2：从 [code]school_system.gd[/code] 拆出。2026-11-26 行数治理：
## 408 行单体拆成四段继承链（成员名与访问路径逐字不变，见文件末尾的链分布表）。

## 检查流派的全部条件是否满足。[br]
## [br][b]返回[/b]: 全部条件满足则 true。
func check_all_conditions(school: Dictionary, state: Dictionary) -> bool:
	var conditions: Array = school.detection.get("conditions", [])
	if conditions.is_empty():
		return false
	for cond in conditions:
		var result: Dictionary = evaluate_condition(cond, state, school.id)
		if not result.get("satisfied", false):
			return false
	return true


## 评估单个检测条件——返回 {satisfied, weight, score, missing_text, skipped}。[br]
## [br]条件类型映射：[br]
##   - [code]faction_count[/code] → 阵营人数条件（权重 40）[br]
##   - [code]faction_ratio[/code] → 阵营占比条件（权重 40）[br]
##   - [code]excluded_faction[/code] → 排除阵营条件（硬性，不参与加权）[br]
##   - [code]card_type_ratio[/code] → 卡牌类型占比（权重 20）[br]
##   - [code]min_realm[/code] → 境界条件（权重 10）[br]
##   - [code]min_alchemy_count[/code] → 炼丹次数（权重 10）[br]
##   - [code]required_characters[/code] → 必备角色（权重 30）[br]
##   - [code]avg_card_cost[/code] → 平均费用（权重 20）[br]
##   - [code]min_rarity[/code] → 最低稀有度（硬性，不参与加权）[br]
##   - [code]max_dark_gold_count[/code] → 暗金卡上限（硬性，不参与加权）[br]
## [br][b]来源[/b]: ADR-0025 §关键接口 + GDD §公式#1（权重分配）。
func evaluate_condition(cond: Dictionary, state: Dictionary, _school_id: StringName) -> Dictionary:
	var cond_type: String = cond.get("type", "")

	match cond_type:
		"faction_count":
			return _eval_faction_count(cond, state)
		"faction_ratio":
			return _eval_faction_ratio(cond, state)
		"excluded_faction":
			return _eval_excluded_faction(cond, state)
		"card_type_ratio":
			return _eval_card_type_ratio(cond, state)
		"min_realm":
			return _eval_min_realm(cond, state)
		"min_alchemy_count":
			return _eval_min_alchemy_count(cond, state)
		"required_characters":
			return _eval_required_characters(cond, state)
		"avg_card_cost":
			return _eval_avg_card_cost(cond, state)
		"min_rarity":
			return _eval_min_rarity(cond, state)
		"max_dark_gold_count":
			return _eval_max_dark_gold_count(cond, state)

	return {satisfied = false, weight = 0.0, score = 0.0, missing_text = "未知条件类型: %s" % cond_type, skipped = false}

# === 继承链分布 ===================================================================
# school_conditions_tag_rules.gd      链首  标签推导与显示名（叶子，无依赖）
# school_conditions_faction_evals.gd  第二段 阵营 / 卡牌类型条件评估器（4 条）
# school_conditions_stat_evals.gd     第三段 境界 / 炼丹 / 角色 / 费用 / 稀有度（6 条）
# school_conditions.gd                链尾  入口与分派（本文件，路径对外契约）
# 拆自 408 行单体（2026-11-26 行数治理），成员名与访问路径逐字不变。
