class_name CombatResultView
extends RefCounted
## CombatResultView —— 结算结果对象（Sprint 18 结算回流——[b]可读视图[/b]）。[br]
## [br][b]职责[/b]：把 [signal CombatSystem.battle_ended] 的载荷
## （[code]rewards[/code]，含 [code]record[/code]）折成一个只读对象，
## 供结算/战败占位场景与后续正式界面消费。[br]
## [br][b]为什么是独立类而非裸 Dictionary[/b]：展示端要「读」而不是「猜」——
## 胜负中英对照、剩余 HP、条目数都用具名属性暴露，缺字段时给出明确默认值，
## 不把 [code]payload.get("record", {}).get("player", {})...[/code] 散落到各场景。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本类只持一份[b]载荷拷贝[/b]（打完即固定），
## 不读 GSM / 战斗系统，也不回写任何东西——UI 侧拿到的是一份「历史记录」。[br]
## [br][b]信息不足时的默认值[/b]（上游没给 [code]record[/code] 的旧载荷、或字段缺失）：[br]
##   · [code]result[/code] 缺失 → [constant RESULT_NONE]；[br]
##   · HP / 条目数缺失 → 0；[br]
##   · [code]outcome[/code] 缺失 → 由 [code]result[/code] 推导。[br]
##   —— 展示端据此渲染「无战绩数据」，不臆造数字。[br]
## [br]来源: production/session-state/active.md（Sprint 18 结算回流）、ADR-0031 §2、
## ADR-0008 §信号分类。

## 奖励文案内核（与结算面板/回探索提示同一份口径）。
const RewardLines := preload("res://src/feature/combat/combat_reward_lines.gd")
## 渡劫金卡文案内核——渡劫战才有的那段「获得：×××（金）」（GDD §6）。
const TribRewardLines := preload("res://src/feature/tribulation/tribulation_reward_lines.gd")
## 名字兜底口径（[code]resolve_name[/code]——与战斗内建表/播报同源）。
const NameRules := preload("res://src/feature/combat/combat_roster_seeding.gd")

## 结局枚举——[b]直接引[/b] [enum CombatSystem.CombatResult]（本文件曾镜像一份
## 0/1/2/3 的字面量；同一份数字抄两处必然漂移，故改为单一出处）。
const CombatScript := preload("res://src/feature/combat_system.gd")
const RESULT_NONE: int = CombatScript.CombatResult.NONE
const RESULT_VICTORY: int = CombatScript.CombatResult.VICTORY
const RESULT_DEFEAT: int = CombatScript.CombatResult.DEFEAT
const RESULT_RETREAT: int = CombatScript.CombatResult.RETREAT

## 结局 token → 中文标题（占位场景与后续界面共用；本地化 epic 后改为 key）。
const OUTCOME_TITLES: Dictionary = {
	"victory": "战斗胜利",
	"defeat": "战斗失败",
	"retreat": "撤退",
	"none": "战斗结束",
}

## [code]result[/code] → 结局 token（record 缺 [code]outcome[/code] 时回退推导）。
const OUTCOME_BY_RESULT: Dictionary = {
	RESULT_NONE: "none",
	RESULT_VICTORY: "victory",
	RESULT_DEFEAT: "defeat",
	RESULT_RETREAT: "retreat",
}

## 战斗结果（[constant RESULT_NONE] / [constant RESULT_VICTORY] / …）。
var result: int = RESULT_NONE
## 结局 token（[code]victory[/code] / [code]defeat[/code] / [code]retreat[/code] / [code]none[/code]）。
var outcome: String = "none"
## 结束时的回合数。
var turn_count: int = 0
## 本场结算的效果条目数（打出即生效 + 击杀触发）。
var effect_entries: int = 0
## 双方[b]造成[/b]的总伤害合计 [code]{player: int, enemy: int}[/code]
## （键为施加方——与 [member player] / [member enemy] 两段战报同名对齐）。[br]
## [br][b]为什么记在施加方[/b]：玩家看结算屏问的是「我这局打了多少」，不是
## 「我挨了多少」——挨打量已经由 [member player] 的 [code]remaining_hp[/code] 体现。[br]
## 旧载荷缺这两个键时取 [code]{player: 0, enemy: 0}[/code]（展示端判空，不臆造）。
var damage_dealt: Dictionary = {}
## 双方击杀数 [code]{player: int, enemy: int}[/code]（同 [member damage_dealt] 的键口径）。
var kills: Dictionary = {}
## 我方战绩 [code]{count, alive_count, remaining_hp, unknown_count, roster}[/code]。
var player: Dictionary = {}
## 敌方战绩（同上结构）。
var enemy: Dictionary = {}
## 胜利时为 [code]{lingshi, cultivation, cards}[/code]；战败/撤退为 [code]{retain_ratio}[/code]。
var rewards: Dictionary = {}
## 上游是否提供了 [code]record[/code]（false = 旧载荷，展示端应标注「无战绩数据」）。
var has_record: bool = false

## 最近一场的结算对象——跨场景传递（战斗场景销毁后结算场景仍要读得到）。[br]
## [br][b]为什么用 static var[/b]：结算场景是独立 .tscn，实例化时战斗场景已释放；
## 项目内跨场景轻量缓存的既有口径即 static var（同 [code]combat_icon_atlas.gd[/code]）。
## 写入口只有 [method publish]（战斗场景挂载侧），读出口 [method last]。
static var _last: CombatResultView = null

## 待展示的奖励通知文案——[method take_pending_notice] 一次性取走。[br]
## [br][b]为什么需要单独一份[/b]：结算/战败场景展示完就退场，回探索后玩家真正
## 面对的是节点图——奖励要有一次「已到账」的提示。发布时算好文案、探索侧取走即清，
## 同一场不会重复弹（多次进出地图也只提示一次）。
static var _pending_notice: String = ""


## 发布本场结算对象（CombatScene 在 [signal CombatSystem.battle_ended] 时调用）。[br]
## [br]同时准备回探索后的一次性奖励提示（文案内核见 [code]combat_reward_lines.gd[/code]）。
static func publish(view: CombatResultView) -> void:
	_last = view
	_pending_notice = ""
	if view == null or view.rewards.is_empty():
		return
	_pending_notice = str(RewardLines.summary_text(view.rewards))


## 最近一场的结算对象——从未打过战斗时返回 null（展示端走「无战绩数据」分支）。[br]
## [br][b]只读快照[/b]：返回的是发布时的那一份（发布后不再变动），调用方不必再拷贝。
static func last() -> CombatResultView:
	return _last


## 取走待展示的奖励提示（一次性——取后清空，探索场景重复进入不会重复弹）。[br]
## [br][b]返回[/b]：空串 = 本场没有可提示的奖励（战败/撤退/空掉落）。
static func take_pending_notice() -> String:
	var notice: String = _pending_notice
	_pending_notice = ""
	return notice


## 清空缓存——测试隔离用（生产路径不需调用：每场战斗都会重新 publish）。
static func clear() -> void:
	_last = null
	_pending_notice = ""


## 从 [signal CombatSystem.battle_ended] 载荷构造结算对象。[br]
## [br][param p_result] 结局枚举。[br]
## [param p_rewards] 信号载荷（含 [code]record[/code] / 奖励字段）。[br]
## [br][b]不抛错、不告警[/b]：载荷不完整是上游状态（如旧调用方只传 result），
## 缺的字段一律取默认值——把「读不到」变成崩溃不是展示端该做的事。
static func from_battle_ended(p_result: int, p_rewards: Dictionary = {}) -> CombatResultView:
	var view := CombatResultView.new()
	view.result = p_result
	view.rewards = (p_rewards as Dictionary).duplicate(true)
	var record: Variant = (p_rewards as Dictionary).get("record", null)
	if record is Dictionary and not (record as Dictionary).is_empty():
		view._apply_record(record as Dictionary)
		view.has_record = true
	# 结局 token 的最终裁决：[b]没有 record 时一律由 result 推导[/b]。
	# 不能只看「token 是否在表里」——[constant OUTCOME_TITLES] 含 "none"，
	# 于是「无 record 的战败载荷」会停在默认的 none 上，被渲染成「战斗结束」
	# 而不是「战斗失败」（结果与 result 自相矛盾）。
	if not view.has_record or not OUTCOME_TITLES.has(view.outcome):
		view.outcome = String(OUTCOME_BY_RESULT.get(p_result, "none"))
	return view


## 应用战绩字典（[code]CombatBattleRecord.build[/code] 的产出）。[br]
## [br][b]结局 token 只在记录里有明确取值时采用[/b]：记录缺 [code]outcome[/code]
## 时留空，交给 [method from_battle_ended] 按 [member result] 推导。
func _apply_record(record: Dictionary) -> void:
	outcome = String(record.get("outcome", "")) if record.has("outcome") else ""
	turn_count = maxi(int(record.get("turn_count", 0)), 0)
	effect_entries = maxi(int(record.get("effect_entries", 0)), 0)
	damage_dealt = _side_totals(record.get("damage_dealt"))
	kills = _side_totals(record.get("kills"))
	var p: Variant = record.get("player", {})
	player = (p as Dictionary).duplicate(true) if p is Dictionary else {}
	var e: Variant = record.get("enemy", {})
	enemy = (e as Dictionary).duplicate(true) if e is Dictionary else {}


## 双侧整数字典的规范化读取——[code]{player: int, enemy: int}[/code]。[br]
## [br][b]缺键补 0 而不是补 null[/b]：战报展示端要能无条件相加/格式化；旧载荷
## （这两个键是后加的）读到的是 0 而不是崩溃。非字典 / 非数字一律按 0 处理，
## 与 [method _apply_record] 其余字段同一条「读不到就给明确默认值」的口径。[br]
## [br][b]未知键丢弃[/b]：只取 player / enemy 两把，避免把上游的 0/1 阵营键
## 混进来让展示端读出一堆没头没尾的数。
static func _side_totals(raw: Variant) -> Dictionary:
	var out: Dictionary = {"player": 0, "enemy": 0}
	if not (raw is Dictionary):
		return out
	for key: String in out.keys():
		out[key] = maxi(int((raw as Dictionary).get(key, 0)), 0)
	return out


## 结局中文标题（占位场景标题行用）。
func title() -> String:
	return String(OUTCOME_TITLES.get(outcome, OUTCOME_TITLES["none"]))


## 是否胜利。
func is_victory() -> bool:
	return result == RESULT_VICTORY


## 我方剩余 HP 合计（[code]unknown_count > 0[/code] 时该值[b]偏低[/b]——读不到的角色不计入）。
func player_remaining_hp() -> int:
	return maxi(int(player.get("remaining_hp", 0)), 0)


## 敌方剩余 HP 合计（同 [method player_remaining_hp] 的口径）。
func enemy_remaining_hp() -> int:
	return maxi(int(enemy.get("remaining_hp", 0)), 0)


## 我方造成的总伤害（旧载荷无此项时为 0）。
func player_damage_dealt() -> int:
	return maxi(int(damage_dealt.get("player", 0)), 0)


## 敌方造成的总伤害（同 [method player_damage_dealt] 的口径）。
func enemy_damage_dealt() -> int:
	return maxi(int(damage_dealt.get("enemy", 0)), 0)


## 我方击杀数（旧载荷无此项时为 0）。
func player_kills() -> int:
	return maxi(int(kills.get("player", 0)), 0)


## 敌方击杀数（同 [method player_kills] 的口径）。
func enemy_kills() -> int:
	return maxi(int(kills.get("enemy", 0)), 0)


## 本场战报——结算屏「战报」区块的逐行内容。[br]
## [br][b]与 [method summary_lines] 的分工[/b]：那条是[b]诊断/日志[/b]用的完整摘要
## （结局枚举、触发条目数、未知数据后缀都写进去）；本方法是[b]玩家读的那一版[/b]
## ——回合数 / 我方逐人剩余 HP / 造成伤害 / 击杀数，四项都在卡片区里看得到，
## 不夹带 result 数字之类的内部字段。[br]
## [br][b]我方逐人 HP[/b]：[code]roster[/code] 里 [code]known=false[/code] 的条目
## 不编造数字，标「状态未知」——与 [method _unknown_suffix] 同一条「读不到就说读不到」。[br]
## [br][b]没有战绩数据时返回空数组[/b]（[member has_record] 为假）：展示端据此不建区块，
## 而不是显示一排 0 让人以为「打了一场什么都没发生」。
func battle_report_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if not has_record:
		return lines
	lines.append("本场回合数: %d" % turn_count)
	lines.append("我方剩余 HP:")
	var roster: Array = player.get("roster", []) if player.get("roster") is Array else []
	for raw: Variant in roster:
		if not (raw is Dictionary):
			continue
		lines.append("　· %s" % _roster_line(raw as Dictionary))
	lines.append("我方造成伤害: %d（击杀 %d）" % [player_damage_dealt(), player_kills()])
	lines.append("敌方造成伤害: %d（击杀 %d）" % [enemy_damage_dealt(), enemy_kills()])
	return lines


## 逐人战报行——[code]林渊: 12/20[/code]；数据不可信时标「状态未知」不编数字。[br]
## [br][b]名字优先、编号兜底[/b]：记录里带 [code]display_name[/code] 时用它（战斗侧
## 开战时定格的真名）；缺名（旧存档载荷、模板查不到）时退回 [code]角色 #ID[/code]——
## 玩家至少能对着编号数出是哪一栏，而不是看到一行空白。[br]
## [br][b]兜底口径取自 [code]CombatRosterSeeding.fallback_name[/code][/b]：战斗内播报
## 「敌人 #100000」用的是同一句，两处各写一遍迟早会分叉成一个说「角色」一个说「敌人」。
func _roster_line(entry: Dictionary) -> String:
	var character_id: int = int(entry.get("character_id", -1))
	var name: String = NameRules.resolve_name(
			str(entry.get("display_name", "")), character_id)
	if not bool(entry.get("known", false)):
		return "%s: 状态未知" % name
	var hp: String = "%d/%d" % [int(entry.get("current_hp", 0)),
			int(entry.get("max_hp", 0))]
	if not bool(entry.get("is_alive", true)):
		return "%s: %s（已阵亡）" % [name, hp]
	return "%s: %s" % [name, hp]


## 纯文本摘要——占位场景直接 print 的内容（一行一条，便于人工核对与日志检索）。[br]
## [br][b]不含本地化 key[/b]：占位阶段的中文文案集中在此处与 [constant OUTCOME_TITLES]，
## 本地化 epic 落地后统一替换（同 [code]PlaceholderScene[/code] 的 TEXT_* 豁免口径）。
func summary_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("结局: %s (result=%d)" % [title(), result])
	# 奖励段插在结局之后、战绩之前——玩家最关心「拿到了什么」
	lines.append_array(PackedStringArray(reward_lines()))
	lines.append("回合数: %d" % turn_count)
	lines.append("触发效果条目: %d" % effect_entries)
	lines.append("我方: 存活 %d/%d，剩余 HP %d%s" % [
		int(player.get("alive_count", 0)), int(player.get("count", 0)),
		player_remaining_hp(), _unknown_suffix(player)])
	lines.append("敌方: 存活 %d/%d，剩余 HP %d%s" % [
		int(enemy.get("alive_count", 0)), int(enemy.get("count", 0)),
		enemy_remaining_hp(), _unknown_suffix(enemy)])
	return lines


## 本场奖励文案行（[code]CombatRewardLines.reward_lines()[/code] 口径——空 = 无奖励）。[br]
## [br][b]为什么放在这里而不是场景里[/b]：胜利/战败两个场景、结算面板、回探索提示
## 各有一条读取路径，口径只留一处（同 [method summary_lines] 的集中理由）。[br]
## [br][b]渡劫金卡接在末尾[/b]：渡劫战的载荷多一段 [code]tribulation_rewards[/code]
## （GDD §6 的固定金卡），普通战斗没有这一段、行数组逐字节不变。
func reward_lines() -> Array:
	var lines: Array = RewardLines.reward_lines(rewards)
	lines.append_array(tribulation_reward_lines())
	return lines


## 渡劫金卡奖励行（[code]TribulationRewardLines[/code] 口径——非渡劫战为空数组）。
func tribulation_reward_lines() -> Array:
	if not rewards.has(TribRewardLines.PoolScript.KEY_PAYLOAD):
		return []
	return TribRewardLines.card_lines(rewards.get(TribRewardLines.PoolScript.KEY_PAYLOAD))


## 本场奖励的单行摘要（回探索提示用；空 = 无需提示）。
func reward_summary() -> String:
	return str(RewardLines.summary_text(rewards))


## 未知条目提示后缀——有读不到 HP 的角色时标注，避免把「少算」看成「打空」。
func _unknown_suffix(side: Dictionary) -> String:
	var unknown: int = int(side.get("unknown_count", 0))
	return "（另有 %d 条无 HP 数据）" % unknown if unknown > 0 else ""
