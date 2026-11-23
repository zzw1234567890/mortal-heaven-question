class_name SettlementGrantLines
extends RefCounted
## SettlementGrantLines —— 结算奖励的中文行生成与「本场掷骰奖励」缓存
## （拆分自 settlement_host）。[br]
##
## [b]职责[/b]：把结算面板要显示的中文行都由这一件生成，并记住本场掷骰奖励供发放后
## 刷新用——[br]
##   · [method victory_lines]：胜利面板的汇总行（未发放时的「实得/未抽到/未入库」）；[br]
##   · [method empty_option_lines]：候选为空时直接显示的灵石/修为汇总；[br]
##   · [method granted_lines]：发放之后的「已到账汇总」；[br]
##   · [method tribulation_lines]：渡劫金卡行。[br]
## [b]不管什么[/b]：不建面板、不接信号、不判定胜负、不调发放 API——面板归
## [SettlementHostPanels]，判定归 [code]SettlementRules[/code]，
## 发放归 [code]CombatSystem.grant_reward_selection[/code]。[br]
## [br][b]为什么单独成文件[/b]：这些行全部由[纯数据整形]构成（载荷 → 中文串），
## 与宿主的信号接线、焦点记忆是两类事；[code]settlement_host.gd[/code] 挤在一起时
## 超出 300 行软上限（编码标准）。[br]
## [br][b]为什么缓存要跟着搬[/b]：缓存（本场掷骰奖励）唯一的消费者就是
## [method granted_lines]——把它留在宿主里，等于同一份事实有两个家。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：缓存的是本场结算载荷本身（面板要显示的
## 原文），不是游戏状态的副本；游戏数据（卡组/角色）一律现读注入依赖。
##
## 来源: combat-ui-layout Story 008（AC-3/AC-5）、design/gdd/combat-ui-system.md §9、
## 拆分自 settlement_host（行数预算）。

## 奖励文案内核——与结算场景/回探索提示共用同一份口径。
const RewardLines := preload("res://src/feature/combat/combat_reward_lines.gd")
## 渡劫金卡文案内核——渡劫结算报告 → 「获得：×××（金）」的中文行（GDD §6）。
const TribRewardLines := preload("res://src/feature/tribulation/tribulation_reward_lines.gd")

## 当前战斗的掷骰奖励缓存（用于发放后刷新汇总视图——[method remember_rolled] 写入）。
var _rolled: Dictionary = {}


## 记住本场掷骰奖励（[code]battle_ended[/code] 载荷——发放后刷新汇总时要用）。[br]
## [br][b]深拷贝[/b]：面板随后要按结果改写显示，而载荷的归属是战斗系统——
## 不深拷会让「面板读到的」和「战斗系统记账的」变成同一个字典。
func remember_rolled(rewards: Dictionary) -> void:
	_rolled = rewards.duplicate(true)


## 本场掷骰奖励（只读——测试探针）。
func rolled() -> Dictionary:
	return _rolled


## 胜利面板的汇总行（发放前——哪些到手、哪些没抽到、哪些发放失败）。[br]
## [br][b]读同一份载荷两处消费[/b]：[code]cards[/code] / [code]lingshi[/code] 尚未到账，
## 面板把它们列成「本次奖励：N 选 1」供玩家选择（选项由 [code]SettlementHostData[/code]
## 映射，N 是实际条数），而全文汇总行在这里——两处读的是同一个 [param p_rewards]。
func victory_lines(p_rewards: Dictionary) -> Array:
	var lines: Array = RewardLines.reward_lines(p_rewards)
	lines.append_array(tribulation_lines(p_rewards))
	return lines


## 候选为空时的直接汇总行（灵石 / 修为 + 渡劫金卡）。[br]
## [br][b]不做选项映射[/b]：本方法只负责「没有东西可选时面板上写什么」，
## 选项由 [code]SettlementHostData.victory_options[/code] 供；
## 两者在宿主里配对使用（选项空 → 走这里）。
func empty_option_lines(p_rewards: Dictionary) -> Array:
	var lines: Array = []
	var lingshi: int = int(p_rewards.get("lingshi", 0))
	var cultivation: int = int(p_rewards.get("cultivation", 0))
	if lingshi > 0:
		lines.append("灵石 +%d" % lingshi)
	if cultivation > 0:
		lines.append("修为 +%d" % cultivation)
	lines.append_array(tribulation_lines(p_rewards))
	return lines


## 已到账汇总行（[code]grant_reward_selection[/code] 的返回值 → 面板行）。[br]
## [br][b]为什么读缓存而不是读返回值[/b]：返回值只报「这次发了什么」，
## 行里还要写「本场本该有什么」（例如没选卡时提示「未选择即放弃」）——
## 那是掷骰时就定下的事实，故一并读 [member _rolled]。[br]
## [br][b]无任何奖励时给一行提示[/b]：空面板会让玩家以为界面坏了。
func granted_lines(p_result: Dictionary) -> Array:
	var lines: Array = []
	if not bool(p_result.get("no_rolled_rewards", true)):
		var lingshi: int = int(_rolled.get("lingshi", 0))
		var cultivation: int = int(_rolled.get("cultivation", 0))
		if lingshi > 0:
			lines.append("灵石 +%d" % lingshi)
		if cultivation > 0:
			lines.append("修为 +%d" % cultivation)
		lines.append_array(card_lines(p_result.get("cards", [])))
		# 跳过卡牌时添加放弃文案
		if (p_result.get("cards", []) as Array).is_empty() \
				and not (_rolled.get("cards", []) as Array).is_empty():
			lines.append("未选择即放弃，卡牌不进收藏")
		lines.append_array(tribulation_lines(_rolled))
	if lines.is_empty():
		lines.append("本次战斗无奖励")
	return lines


## 实得卡牌行（[code]{name, rarity}[/code] 列表 → 「获得卡牌：×××（稀有度）」）。[br]
## [br][b]无名条目不产出行[/b]：名字才是这行的信息本体，缺了它写出来只会是
## 「获得卡牌：」这样的半截话。
func card_lines(p_cards: Variant) -> Array:
	var lines: Array = []
	if not (p_cards is Array):
		return lines
	for card: Variant in p_cards:
		if not (card is Dictionary):
			continue
		var name: String = str((card as Dictionary).get("name", ""))
		if name.is_empty():
			continue
		var rarity: String = str((card as Dictionary).get("rarity", ""))
		if rarity.is_empty():
			lines.append("获得卡牌：%s" % name)
		else:
			lines.append("获得卡牌：%s（%s）" % [name, rarity])
	return lines


## 渡劫金卡奖励行——载荷里没有 [code]tribulation_rewards[/code] 时返回空数组。[br]
## [br][b]为什么在宿主里再包一层[/b]：载荷键名是渡劫侧的口径（
## [code]tribulation_reward_pool.gd[/code] 的 [code]KEY_PAYLOAD[/code]），宿主/面板
## 不该自己写一遍字符串；这一层只负责「取键 → 交给文案内核」。[br]
## [br][b]普通战斗天然为空[/b]：键只在渡劫战结算时写入（见
## [code]TribulationCombat.on_battle_ended[/code]），故这一段对普通战斗不产生任何行。
func tribulation_lines(p_rewards: Dictionary) -> Array:
	if not p_rewards.has(TribRewardLines.PoolScript.KEY_PAYLOAD):
		return []
	return TribRewardLines.card_lines(p_rewards.get(TribRewardLines.PoolScript.KEY_PAYLOAD))
