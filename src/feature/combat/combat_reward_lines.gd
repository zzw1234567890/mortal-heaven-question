extends RefCounted
## CombatRewardLines —— 战斗奖励的玩家可读文案（[b]纯函数内核[/b]）。[br]
## [br][b]职责[/b]：把 [code]battle_ended[/code] 载荷里的 [code]rewards[/code]
## 翻成中文行——哪些到手、哪些没抽到、哪些发放失败。同一份文案供三处消费：[br]
##   · [code]SettlementHost[/code] 的胜利结算面板（战利品区上方汇总）；[br]
##   · [code]CombatResultView[/code] / [code]BattleRecordScene[/code] 的结算/战败场景；[br]
##   · [code]ExplorationScene[/code] 回探索后的一次性通知。[br]
## [br][b]为什么不各写一份[/b]：三处措辞一旦分叉，玩家会看到「结算写 +12、HUD 写 +10」
## 这种自相矛盾的提示。文案与判定只有这一份（ADR-0031 Logic 内核模式）。[br]
## [br][b]缺数据的降级[/b]（不臆造）：[br]
##   · 载荷没有奖励字段（旧调用方 / 战败/撤退）→ [method reward_lines] 返回空数组；[br]
##   · 灵石/修为为 0 或负 → 不出现该行；[br]
##   · 卡牌缺名称 → 回退卡牌 ID；缺概率 → 不显示括号里的百分比。[br]
## [br][b]文案本地化豁免[/b]：项目暂无本地化系统，全部中文集中在 [constant TEXT_*]
## （同 [code]settlement_rules.gd[/code] / [code]placeholder_scene.gd[/code] 口径）。
## [br]来源: GDD combat-system.md §9 战斗奖励结算、DEBT-EUI-006-4。

## 段落标题（结算面板/场景摘要用）。
const TEXT_SECTION: String = "本场奖励"
## 无任何奖励时的提示（战利品为空且无灵石/修为）。
const TEXT_NOTHING: String = "本场无奖励"
## 灵石行——[param] 为本次实得；括号里是掷骰区间（只有配置了区间才显示）。
const TEXT_LINGSHI: String = "灵石 +%d"
const TEXT_LINGSHI_RANGE: String = "灵石 +%d（区间 %d~%d 掷出）"
## 修为行。
const TEXT_CULTIVATION: String = "修为 +%d"
## 命中卡牌行（[code]（稀有度·类型）[/code] 部分可选）。
const TEXT_CARD_GAINED: String = "获得卡牌：%s%s"
## 未命中卡牌行——[code]+N%%[/code] 只在配置了 [code]chance[/code] 时出现。
const TEXT_CARD_MISSED: String = "未抽到：%s%s"
## 发放失败行（系统缺失 / 未知模板 / 收藏写入被拒）。
const TEXT_GRANT_FAILED: String = "%s 未能发放（%s）"
## 灵石/修为发放失败的物品名。
const NAME_LINGSHI: String = "灵石"
const NAME_CULTIVATION: String = "修为"
## 卡牌的降级名称（模板与载荷都没给名字时）。
const NAME_UNKNOWN_CARD: String = "未知卡牌"
## 概率括号格式（[code]%d%%[/code] 为百分比整数）。
const TEXT_CHANCE: String = "（%d%%）"
## 稀有度/类型括号格式。
const TEXT_CARD_TAG: String = "（%s·%s）"
const TEXT_CARD_TAG_ONE: String = "（%s）"


## 完整奖励文案行——结算面板/场景摘要的正文。[br]
## [br][param p_rewards] [code]battle_ended[/code] 载荷的 [code]rewards[/code]（可空）。[br]
## [br][b]返回[/b]：按「灵石 → 修为 → 到手卡牌 → 未抽到 → 发放失败」排列的行数组；
## 无奖励时返回空数组（调用方自行决定提示，[method summary_text] 会给出「本场无奖励」）。[br]
static func reward_lines(p_rewards: Dictionary) -> Array:
	var lines: Array = []
	if p_rewards == null or p_rewards.is_empty():
		return lines
	var lingshi: int = int(p_rewards.get("lingshi", 0))
	if lingshi > 0:
		var lo: int = int(p_rewards.get("lingshi_min", lingshi))
		var hi: int = int(p_rewards.get("lingshi_max", lingshi))
		var rolled: bool = bool(p_rewards.get("lingshi_rolled", false))
		if rolled and hi > lo:
			lines.append(TEXT_LINGSHI_RANGE % [lingshi, lo, hi])
		else:
			lines.append(TEXT_LINGSHI % lingshi)
	var cultivation: int = int(p_rewards.get("cultivation", 0))
	if cultivation > 0:
		lines.append(TEXT_CULTIVATION % cultivation)
	for card: Variant in _entries(p_rewards.get("cards", [])):
		lines.append(TEXT_CARD_GAINED % [_card_name(card), _card_tag(card)])
	for missed: Variant in _entries(p_rewards.get("cards_missed", [])):
		lines.append(TEXT_CARD_MISSED % [_card_name(missed), _chance_tag(missed)])
	for failed: Variant in _entries(p_rewards.get("cards_failed", [])):
		lines.append(TEXT_GRANT_FAILED % [_card_name(failed),
				str((failed as Dictionary).get("reason", "未知原因"))])
	if not bool(p_rewards.get("lingshi_granted", true)) and lingshi > 0:
		lines.append(TEXT_GRANT_FAILED % [NAME_LINGSHI, "资源系统不可用"])
	if not bool(p_rewards.get("cultivation_granted", true)) and cultivation > 0:
		lines.append(TEXT_GRANT_FAILED % [NAME_CULTIVATION, "修为系统不可用"])
	return lines


## 单行摘要——回探索提示 / 通知用（多行压成一句，便于 Toast 展示）。[br]
## [br][b]返回[/b]：空串 = 无奖励（调用方不发通知）；否则形如
## 「本场奖励：灵石 +12、修为 +3、获得「培元丹」；未抽到「鬼修·残页」」。[br]
static func summary_text(p_rewards: Dictionary) -> String:
	if p_rewards == null or p_rewards.is_empty():
		return ""
	var parts: Array = []
	var lingshi: int = int(p_rewards.get("lingshi", 0))
	if lingshi > 0:
		parts.append("灵石 +%d" % lingshi)
	var cultivation: int = int(p_rewards.get("cultivation", 0))
	if cultivation > 0:
		parts.append("修为 +%d" % cultivation)
	for card: Variant in _entries(p_rewards.get("cards", [])):
		parts.append("获得「%s」" % _card_name(card))
	for missed: Variant in _entries(p_rewards.get("cards_missed", [])):
		parts.append("未抽到「%s」" % _card_name(missed))
	var failed: Array = _entries(p_rewards.get("cards_failed", []))
	if not failed.is_empty():
		parts.append("%d 张卡牌未能入库" % failed.size())
	if parts.is_empty():
		return ""
	return TEXT_SECTION + "：" + "、".join(PackedStringArray(parts))


## 面板内的奖励段（标题 + 正文行）——[code]SettlementHost[/code] 用。[br]
## [br][b]返回[/b]：[code]{title, lines}[/code]；[code]lines[/code] 为空时
## 正文应显示 [constant TEXT_NOTHING]。[br]
static func section(p_rewards: Dictionary) -> Dictionary:
	var lines: Array = reward_lines(p_rewards)
	return {
		"title": TEXT_SECTION,
		"lines": lines if not lines.is_empty() else [TEXT_NOTHING],
	}


## 通知类型——有奖励走高亮金色 [code]item[/code]，无奖励不通知（空串）。[br]
## [br][b]为什么固定 item[/b]：HUD 通知类型表里 item 是「获得/正向」语义
## （[code]notification_stack.gd[/code] TYPE_META），与本提示一致。[br]
static func notification_type(p_rewards: Dictionary) -> String:
	return "item" if not summary_text(p_rewards).is_empty() else ""


# === 内部 ====================================================================

## 条目数组规范化（非数组 → 空；丢弃非字典条目）。
static func _entries(p_raw: Variant) -> Array:
	var result: Array = []
	if not (p_raw is Array):
		return result
	for item: Variant in p_raw:
		if item is Dictionary:
			result.append(item)
	return result


## 卡牌展示名——[code]name[/code] > [code]card_id[/code] > 未知卡牌。
static func _card_name(p_card: Variant) -> String:
	if not (p_card is Dictionary):
		return NAME_UNKNOWN_CARD
	var source: Dictionary = p_card
	var name: String = str(source.get("name", ""))
	if not name.is_empty():
		return name
	var card_id: String = str(source.get("card_id", ""))
	return card_id if not card_id.is_empty() else NAME_UNKNOWN_CARD


## 稀有度/类型括号——两者都有才显示「白·丹药」，只有一项时显示「（白）」。
static func _card_tag(p_card: Variant) -> String:
	if not (p_card is Dictionary):
		return ""
	var rarity: String = str((p_card as Dictionary).get("rarity", ""))
	var school: String = str((p_card as Dictionary).get("school", ""))
	if not rarity.is_empty() and not school.is_empty():
		return TEXT_CARD_TAG % [rarity, school]
	if not rarity.is_empty() or not school.is_empty():
		return TEXT_CARD_TAG_ONE % (rarity if not rarity.is_empty() else school)
	return ""


## 概率括号——配置了 [code]chance[/code] 才显示（缺省 1.0 = 必得，没有信息量）。
static func _chance_tag(p_card: Variant) -> String:
	if not (p_card is Dictionary):
		return ""
	var source: Dictionary = p_card
	if not source.has("chance"):
		return ""
	var chance: float = clampf(float(source.get("chance", 0.0)), 0.0, 1.0)
	if chance >= 1.0:
		return ""
	return TEXT_CHANCE % int(round(chance * 100.0))
