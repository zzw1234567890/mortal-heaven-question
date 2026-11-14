extends RefCounted
## ExplorationBreakthroughTable —— 打坐/洞府「境界突破」的配置读取面与文案单点。[br]
## [br][b]为什么单独一处[/b]：「这一境界突破要多少修为、成功率几何、失败掉多少」
## 是[b]数据[/b]，与「扣修为、升境界、落盘」（[ExplorationBreakthrough]）是两件事
## ——同 [code]exploration_harvest_table.gd[/code] ↔ [code]exploration_harvest.gd[/code]
## 的分工先例。[br]
## [br][b]数值全部来自配置，不硬编码等级与所需修为[/b]：[br]
##   · 「所需修为」= [b]既有境界配置表[/b] [code]RealmSystem.realm_table[L].max_cultivation[/code]
##     ——本表只做[b]读取[/b]（[method required_cultivation]），不在任何地方写死
##     1000/1500/…；境界名、最高境界数同样取自那张表；[br]
##   · 「加成」同样出自既有境界表：[code]max_deploy[/code] / [code]deck_limit[/code] /
##     [code]action_points[/code] / [code]gongfa_slots[/code] / [code]max_cultivation[/code]
##     都是 [code]get_realm_property[/code] 的查询结果，突破后按新境界自动生效
##     （见 [ExplorationBreakthrough] 类文档「属性重算走既有单写者」）；[br]
##   · 本表只承载 [code]realm_table[/code] [b]未包含[/b]的两项突破随机性参数
##     ——成功率与失败惩罚比例（按境界分层）。[br]
## [br][b]设计缺口登记[/b]：GDD [code]cultivation-system.md[/code] §边界/§调优参数只写
## 「突破失败修为损失 10%（由渡劫突破系统处理）」，[b]没有[/b]「无渡劫直接打坐突破」
## 的成功率规格；[code]exploration-system.md[/code] §节点类型一览也没有打坐/洞府类型。
## 本表按项目既有处置方式（[code]LING_CAI_CAP[/code] / [code]COLLECTION_CAP[/code]
## 同源）取一组可测的默认值并显式登记，待策划定档后只改本表。[br]
## [br]来源: design/gdd/cultivation-system.md §6 突破后修为处理 / §边界 /
## §调优参数（突破失败修为损失 -10%）、docs/decisions/ADR-0010（realm_table 唯一真理
## 来源）、ADR-0021 §_handle_tribulation_failure（失败惩罚按 max_cultivation 计）。

## 境界配置表的读取面（境界名 / 修为上限 / 最高境界数——唯一来源）。
const RealmSystemScript := preload("res://src/core/realm_system.gd")

## 既有境界表里「所需修为」的键名（读取口径单点）。
const KEY_MAX_CULTIVATION: String = "max_cultivation"
## 既有境界表里「境界中文名」的键名。
const KEY_NAME: String = "name"

## 各境界突破成功率——按境界等级索引（下标 0 = 炼气期，末档为最高境界）。
## [br][br][b]为什么逐级递减[/b]：境界越高，突破越需要机缘——与渡劫台的
## 「连续失败保护」共同构成「高境界更贵、更险」的曲线。[br]
## [br][b]末档 0.0[/b]：最高境界没有下一境界（[method max_realm] 已拦），占位不臆造。
const SUCCESS_RATE_BY_REALM: Array = [0.90, 0.80, 0.70, 0.60, 0.0]

## 各境界突破失败时的修为损失[b]比例[/b]——乘 [code]max_cultivation[/code] 后向下取整。
## [br][br][b]10% 的来源[/b]：GDD [code]cultivation-system.md[/code] §边界「突破失败
## 修为损失 10%」+ §调优参数「-10%」；[b]不等于[/b]渡劫战撤退的 15%
## （[code]TribulationSettlement.FAILURE_PENALTY_RATIO[/code]）——两者是不同事件，
## 数值刻意分开（同 [code]node_interaction_rules.gd[/code] §专属警示数值口径）。
const FAILURE_PENALTY_RATIO_BY_REALM: Array = [0.10, 0.10, 0.10, 0.10, 0.0]

## 「已达最高境界」提示。
const TEXT_AT_MAX: String = "已达最高境界，无需突破"
## 「修为不足」提示（当前 / 所需）。
const TEXT_NOT_ENOUGH: String = "修为不足：当前 %d，所需 %d"
## 突破成功提示（旧境界 / 新境界 / 实际消耗）。
const TEXT_SUCCESS: String = "突破成功：%s → %s，消耗修为 %d"
## 突破失败提示（损失量 / 扣前 / 扣后）——损失写清楚，不含糊。
const TEXT_FAILURE: String = "突破失败：修为损失 %d（%d → %d），境界不变"
## 行动按钮文案（成功率百分比与所需修为都由本方法格式化——UI 零数值计算）。
const TEXT_ACTION: String = "尝试突破 · 成功率 %d%% · 需修为 %d"
## 顶部标题行（境界跃迁）。
const TEXT_HEADLINE: String = "%s → %s"
## 状态行——当前修为。
const TEXT_LINE_CULTIVATION: String = "当前修为 %d / %d"
## 状态行——失败代价。
const TEXT_LINE_PENALTY: String = "失败将损失修为 %d"


## 该境界突破到下一境界所需的修为——[b]读既有境界配置表[/b]，不硬编码。[br]
## [br][param p_level] 当前境界等级（1 炼气 … 5 化神）。[br]
## [br][b]返回[/b]：所需修为（= 该境界的 [code]max_cultivation[/code]）；
## 境界不在表中返回 0（调用方据此判定「不可突破」）。
static func required_cultivation(p_level: int) -> int:
	return int(_row(p_level).get(KEY_MAX_CULTIVATION, 0))


## 境界中文名——读既有境界配置表；未知等级返回空串（不臆造）。
static func realm_name(p_level: int) -> String:
	return str(_row(p_level).get(KEY_NAME, ""))


## 最高境界等级——既有境界表的条目数（新增境界只改那张表，本表不动）。
static func max_realm() -> int:
	return RealmSystemScript.realm_table.size()


## 该境界的突破成功率（越界时夹到最近档，不崩溃）。
static func success_rate_for(p_level: int) -> float:
	return float(SUCCESS_RATE_BY_REALM[
			clampi(p_level - 1, 0, SUCCESS_RATE_BY_REALM.size() - 1)])


## 该境界突破失败的修为损失比例（越界时夹到最近档）。
static func failure_ratio_for(p_level: int) -> float:
	return float(FAILURE_PENALTY_RATIO_BY_REALM[
			clampi(p_level - 1, 0, FAILURE_PENALTY_RATIO_BY_REALM.size() - 1)])


## 本次失败的绝对损失量——[code]floor(max_cultivation × 比例)[/code]。[br]
## [br][b]与渡劫同源口径[/b]：以 [code]max_cultivation[/code] 为基数（
## [code]TribulationSettlement.handle_failure[/code] 先例），而不是当前修为——
## 「修为攒得少反而损失小」会让玩家故意压修为，惩罚失去意义。[br]
## [br][param p_max_cultivation] 当前境界的修为上限（负数归零）。
static func penalty_for(p_level: int, p_max_cultivation: int) -> int:
	return int(floor(float(maxi(p_max_cultivation, 0)) * failure_ratio_for(p_level)))


## 掷骰——[param p_rate] 为成功率。[br]
## [br][b]随机源由调用方注入[/b]（[code]RandomNumberGenerator[/code]）：测试注入固定
## 种子即得确定性结果，生产注入随机实例。[br]
## [br][b]边界[/b]：[code]rate=0[/code] 恒失败（[code]randf()[/code] 取不到 0），
## [code]rate=1[/code] 恒成功（[code]randf()[/code] 取不到 1）。
static func roll_success(p_rng: RandomNumberGenerator, p_rate: float) -> bool:
	if p_rng == null:
		return false
	return p_rng.randf() < clampf(p_rate, 0.0, 1.0)


## 顶部标题行——「炼气期 → 筑基期」。
static func headline(p_level: int) -> String:
	return TEXT_HEADLINE % [realm_name(p_level), realm_name(p_level + 1)]


## 行动按钮文案（成功率按百分比取整显示，所需修为读配置）。
static func action_text(p_level: int, p_required: int) -> String:
	return TEXT_ACTION % [int(round(success_rate_for(p_level) * 100.0)), p_required]


## 状态行（面板正文——把数值格式化成中文，UI 不做任何计算）。[br]
## [br][param p_cultivation] 当前修为。[param p_max_cultivation] 当前修为上限。[br]
## [param p_required] 突破所需修为。[param p_penalty] 失败的绝对损失量。
static func status_lines(p_cultivation: int, p_max_cultivation: int,
		p_required: int, p_penalty: int) -> Array:
	return [
		TEXT_LINE_CULTIVATION % [p_cultivation, p_max_cultivation],
		"突破所需修为 %d" % p_required,
		TEXT_LINE_PENALTY % p_penalty,
	]


## 既有境界表里某一境界的整行（未知等级返回空字典——读取方据此判定无效）。
static func _row(p_level: int) -> Dictionary:
	var table: Dictionary = RealmSystemScript.realm_table
	if not table.has(p_level):
		return {}
	return table[p_level]
