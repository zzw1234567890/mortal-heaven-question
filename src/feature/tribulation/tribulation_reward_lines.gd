extends RefCounted
## TribulationRewardLines —— 渡劫金卡奖励的玩家可读文案（[b]纯函数内核[/b]）。[br]
## [br][b]职责[/b]：把渡劫结算报告（[code]TribulationRewardPool.grant[/code] 的产出）
## 翻成中文行——到手几张、叫什么、什么稀有度；没到手时说明原因。[br]
## [br][b]为什么不写在结算屏里[/b]：同一个报告有三个读处（结算面板汇总、结算屏摘要、
## 战报场景），各写一份必然分叉成「一处写『获得』一处写『到手』」。文案与判定只有
## 这一份（ADR-0031 Logic 内核模式）。[br]
## [br][b]分词口径与 GDD §6 对齐[/b]：GDD 承诺的是「必定获得1张[b]金色[/b]稀有度卡牌」
## ——故句子必须带稀有度（玩家据此确认「给的是金卡」而不是普通卡）；
## 卡名缺失时回退卡牌 ID，与 [code]combat_reward_lines.gd[/code] 同一降级口径。[br]
## [br][b]文案本地化豁免[/b]：项目暂无本地化系统，全部中文集中在 [constant TEXT_*]
## （同 [code]combat_reward_lines.gd[/code] / [code]cultivation_view_rules.gd[/code] 口径）。
##
## 来源: design/gdd/tribulation-system.md §6 固定金卡奖励 + §越阶渡劫「额外+1张」、
## ADR-0021 §_handle_tribulation_success、先例 src/feature/combat/combat_reward_lines.gd。

## 载荷键（唯一出处——见 [code]tribulation_reward_pool.gd[/code]）。
const PoolScript := preload("res://src/feature/tribulation/tribulation_reward_pool.gd")

## 渡劫金卡到手行——[param] 依次为卡名、稀有度中文。
const TEXT_CARD_GAINED: String = "获得：%s（%s）"
## 稀有度缺失时的括号内容（不写空括号「（）」这种残句）。
const TEXT_RARITY_FALLBACK: String = "渡劫奖励"
## 未发放行——[param] 依次为名目、原因。
const TEXT_NOT_GRANTED: String = "未发放：%s（%s）"
## 原因缺失时的兜底（不臆造原因，但也不能空着）。
const TEXT_REASON_FALLBACK: String = "未知原因"


## 渡劫结算报告的文案行。[br]
## [br][param p_report] [code]{cards: [...], cards_failed: [...]}[/code]（可空 / 非字典
## 一律按无奖励处理）。[br]
## [br][b]返回[/b]：到手行在前、未发放行在后；报告为空时返回空数组——调用方据此
## 「不建那一行」（不显示「获得：无」这种噪声）。[br]
static func card_lines(p_report: Variant) -> Array:
	var lines: Array = []
	if not (p_report is Dictionary):
		return lines
	var source: Dictionary = p_report
	for card: Variant in _entries(source.get(PoolScript.KEY_CARDS, [])):
		lines.append(TEXT_CARD_GAINED % [_name_of(card), _rarity_of(card)])
	for failed: Variant in _entries(source.get(PoolScript.KEY_FAILED, [])):
		lines.append(TEXT_NOT_GRANTED % [_name_of(failed), _reason_of(failed)])
	return lines


# === 内部 ====================================================================

## 条目数组规范化（非数组 → 空；丢弃非字典条目）——同 [code]combat_reward_lines[/code]。
static func _entries(p_raw: Variant) -> Array:
	var result: Array = []
	if not (p_raw is Array):
		return result
	for item: Variant in p_raw:
		if item is Dictionary:
			result.append(item)
	return result


## 卡名——[code]name[/code] > [code]card_id[/code] > 池空时的名目（不臆造名字）。[br]
## [br][b]为什么最后回退到 [code]NAME_GOLD_CARD[/code][/b]：池空那条报告本来就没有具体
## 卡牌可指（[code]card_id[/code] 为空串），写成「未发放：（原因）」玩家读不懂在说什么。
static func _name_of(p_card: Variant) -> String:
	if not (p_card is Dictionary):
		return PoolScript.NAME_GOLD_CARD
	var source: Dictionary = p_card
	var name: String = str(source.get("name", ""))
	if not name.is_empty():
		return name
	var card_id: String = str(source.get("card_id", ""))
	return card_id if not card_id.is_empty() else PoolScript.NAME_GOLD_CARD


## 稀有度中文——缺失时给可读的中性词（不写空括号）。
static func _rarity_of(p_card: Variant) -> String:
	if not (p_card is Dictionary):
		return TEXT_RARITY_FALLBACK
	var rarity: String = str((p_card as Dictionary).get("rarity", ""))
	return rarity if not rarity.is_empty() else TEXT_RARITY_FALLBACK


## 未发放原因——缺失时给兜底（不臆造，但也不留空）。
static func _reason_of(p_card: Variant) -> String:
	if not (p_card is Dictionary):
		return TEXT_REASON_FALLBACK
	var reason: String = str((p_card as Dictionary).get("reason", ""))
	return reason if not reason.is_empty() else TEXT_REASON_FALLBACK
