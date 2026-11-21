extends RefCounted
## CultivationViewRules —— 修炼室界面的[b]文案与判定单点[/b]（纯函数，不碰控件树）。[br]
## [br][b]为什么单独一处[/b]：[code]cultivation_screen.gd[/code] 要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「这句话怎么写、这个按钮该不该亮」与
## 「控件怎么搭、按下去调谁」是两件事（同 [code]craft_panel_rules.gd[/code] /
## [code]deck_view_sources.gd[/code] 的拆因）。[br]
## [br][b]数值一律读配置，不硬编码境界名与所需修为[/b]：境界名 / 所需修为 / 最高境界数
## 全部来自 [code]RealmSystem.realm_table[/code]（经 [code]ExplorationBreakthroughTable[/code]
## 这个既有读取面）——本模块不写死「炼气期」也不写死 1000。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：全是 static 纯函数，不读 GSM、不持节点
## ——调用方把数字传进来，本模块只负责措辞与判定。[br]
## [br][b]文案本地化豁免[/b]：项目暂无本地化系统——面向玩家的句子集中在此，
## 本地化 epic 入库后替换为 key（同 S16/S17 TEXT_* 口径）。[br]
##
## 来源: design/gdd/cultivation-system.md §4/§5/§6、ADR-0010 §realm_up 编排器、
## ADR-0031 §2、先例 [code]meditation_panel_layout.gd[/code]（文案由 Feature 层单点）。

## 配置读取面（境界名 / 所需修为 / 最高境界数——唯一来源）。
const TableScript := preload("res://src/feature/exploration/exploration_breakthrough_table.gd")
## 渡劫入口共用件——渡劫那几句回执的[b]唯一出处[/b]（探索节点图与修炼室同调它，
## 同一个失败原因在两处措辞必然漂移，故本模块只转发不另写一份）。
const LaunchScript := preload("res://src/feature/tribulation/tribulation_launch.gd")

## 每次打坐的修为增量（GDD §5 修为获取——本屏的固定档）。[br]
## [br][b]数值放这里而不是屏幕类[/b]：按钮文案与「实际加多少」必须是同一个数
## ——分两处写就必然有一天漂移成「按钮写 +50、实际加 30」。
const MEDITATE_AMOUNT: int = 50
## 修为来源标识（进 GSM 变更记录——「哪来的修为」可追溯）。
const MEDITATE_SOURCE: String = "cultivation_room"

## 固定 UI 词条。
const TEXT_TITLE: String = "🧘 修炼室"
## 「打坐」按钮文案（含增量——玩家进屏就知道按一下能给多少）。
const TEXT_MEDITATE: String = "打坐（+%d 修为）"
const TEXT_BREAKTHROUGH: String = "突破"
## 「渡劫」按钮文案（需要渡劫的境界用这一句——语义不同，文案必须跟着不同）。
const TEXT_TRIBULATION: String = "渡劫"
const TEXT_BALANCE: String = "灵石：%d"
const TEXT_REALM: String = "当前境界：%s"
const TEXT_PROGRESS: String = "修为 %d / %d"
## 数值不可读时的占位（不臆造数字）。
const TEXT_UNKNOWN: String = "—"
## 打坐完成、突破成功的回执。
const TEXT_MEDITATE_DONE: String = "打坐完毕：修为 +%d。"
## 已达最高境界时「打坐」行的原因——没有下一境界可去，攒修为无处兑现
## （溢出属性丹的发放挂在突破上，见 GDD cultivation-system.md §7）。[br]
## [br]与 [code]ExplorationBreakthroughTable.TEXT_AT_MAX[/code]（「无需突破」）刻意分开：
## 一行是「别再攒了」、一行是「别再突破了」，玩家点哪一行看到哪一句。
const TEXT_MEDITATE_AT_MAX: String = "已达最高境界，修为无处可用。"
const TEXT_BREAKTHROUGH_DONE: String = "突破成功：%s → %s，修为上限随即提升。"
## 渡劫触发回执（即将转场——说明去哪里、要做什么）。[br]
## [br][b]来源在共用件[/b]（[code]tribulation_launch.gd[/code]）：探索节点图也走
## 那同一条路，玩家在两个入口看到的必须字字相同。
const TEXT_TRIBULATION_STARTED: String = LaunchScript.TEXT_STARTED
## 渡劫归来回执（成功 / 失败）——渡劫战的结算在战斗侧，本屏只把结果讲给玩家听。
const TEXT_TRIBULATION_SUCCEEDED: String = "渡劫成功：%s → %s，修为上限随即提升。"
const TEXT_TRIBULATION_FAILED: String = "渡劫失败：修为损失 %d，境界未变。"
## 状态行：修为满且未到顶。
const TEXT_CAN_BREAK: String = "修为已满——可以突破了。"
## 状态行：修为满、该走渡劫的境界（[code]TEXT_CAN_BREAK[/code] 的渡劫版——两句话分开
## 是因为「点下去会发生什么」不同：一个直接进境，一个要先打一场）。
const TEXT_CAN_TRIBULATE: String = "修为已满，需渡劫方能进境。"
## 渡劫流程已在进行中（准备 / 渡劫战中）——不得重复触发（ADR-0021 §check_tribulation_ready）。
const TEXT_TRIBULATION_BUSY: String = LaunchScript.TEXT_BUSY
## 渡劫系统缺失——可读的降级文案（不让玩家点了没反应）。
const TEXT_TRIBULATION_UNAVAILABLE: String = LaunchScript.TEXT_TRIBULATION_UNAVAILABLE
## 渡劫去向的场景不可用（SceneManager 缺失）。
const TEXT_NO_SCENE_MANAGER_TRIBULATION: String = LaunchScript.TEXT_NO_SCENE_MANAGER
## 转场请求被拒（SceneManager 正在转场中——并发守卫）。渡劫状态已退回，可再试。
const TEXT_TRIBULATION_DEPART_FAILED: String = LaunchScript.TEXT_DEPART_FAILED
## 操作提示行。
const TEXT_HINT: String = "↑ ↓ 选行动，回车执行，Esc 返回主菜单。"
## 系统缺失时的可读降级文案。
const TEXT_UNAVAILABLE: String = "修行系统不可用——此处暂时无法打坐。"
const TEXT_UPGRADE_UNAVAILABLE: String = "境界系统不可用，突破未生效。"
const TEXT_NO_SCENE_MANAGER: String = "场景管理器不可用，暂时无法离开修炼室。"


# ═══════════════════════════════════════════════════════════════════════════════
# 文案
# ═══════════════════════════════════════════════════════════════════════════════

## 境界行（「当前境界：炼气期」）；等级不在配置表时用占位符（不臆造名字）。
static func realm_line(p_realm: int) -> String:
	var name: String = TableScript.realm_name(p_realm)
	return TEXT_REALM % (name if not name.strip_edges().is_empty() else TEXT_UNKNOWN)


## 修为行（「修为 100 / 1000」）——数字由[b]文字[/b]承载，进度条只作第二通道。
static func progress_line(p_current: int, p_max: int) -> String:
	return TEXT_PROGRESS % [p_current, p_max]


## 灵石行（只读——本屏不持有资源，[code]ResourceSystem[/code] 才是写入口）。
static func balance_line(p_ling_shi: int) -> String:
	return TEXT_BALANCE % p_ling_shi


## 「打坐」按钮文案（增量由 [constant MEDITATE_AMOUNT] 单点填充）。
static func meditate_line() -> String:
	return TEXT_MEDITATE % MEDITATE_AMOUNT


## 突破状态行——可突破 / 不可突破的中文原因。[br]
## [br][b]状态行与拒绝提示共用一套措辞[/b]：屏幕上同时出现两处「为什么不能突破」是最
## 容易漂移的地方，故两处都从 [method refusal_line] 取。
static func status_line(p_realm: int, p_cultivation: int, p_can_break: bool) -> String:
	if allows_breakthrough(p_realm, p_can_break):
		return TEXT_CAN_BREAK
	return refusal_line(p_realm, p_cultivation)


## 不可突破的中文原因（已达最高境界 / 修为不足）。[br]
## [br][b]修为不足那条自带数字[/b]（当前 / 所需）——玩家据此知道还差多少；
## 两个数字都读配置与实况，不写死。
static func refusal_line(p_realm: int, p_cultivation: int) -> String:
	if p_realm >= TableScript.max_realm():
		return TableScript.TEXT_AT_MAX
	return TableScript.TEXT_NOT_ENOUGH % [p_cultivation,
			TableScript.required_cultivation(p_realm)]


# ═══════════════════════════════════════════════════════════════════════════════
# 判定
# ═══════════════════════════════════════════════════════════════════════════════

## 本次是否可以突破。[br]
## [br][b]为什么要自己加「未到顶」这一道[/b]：[code]CultivationSystem.check_breakthrough[/code]
## 只看修为满没满，到顶时它仍返回 true；而 [code]RealmSystem.realm_up[/code] 会因超出
## 最高境界报错拒绝——不在这里拦住就会变成「按钮能点、点了报错」。到顶时的正确呈现是
## 「已满但不可突破」，措辞由 [method refusal_line] 给出。
static func allows_breakthrough(p_realm: int, p_can_break: bool) -> bool:
	return p_can_break and p_realm < TableScript.max_realm()


## 进度条填充比例（0.0-1.0）。[br]
## [br][b]上限为 0 时给 0 而不是除零[/b]：系统缺失 / 存档异常都可能读到 0——
## 那不是一个「满」的进度条，而是一个不可读的状态。
static func fill_ratio(p_current: int, p_max: int) -> float:
	if p_max <= 0:
		return 0.0
	return clampf(float(p_current) / float(p_max), 0.0, 1.0)


## 打坐完成回执。
static func meditate_done_line(p_amount: int) -> String:
	return TEXT_MEDITATE_DONE % p_amount


## 突破成功回执（旧境界名 / 新境界名——名字取自配置表）。[br]
## [br][b]刻意不写「新上限是多少」[/b]：上限的重算走 GSM 帧末信号
## （[code]realm_changed[/code] → [code]CultivationSystem.update_max_cultivation[/code]），
## 写死了就会在到账前与屏幕上的数字自相矛盾。
static func breakthrough_done_line(p_realm: int) -> String:
	return TEXT_BREAKTHROUGH_DONE % [TableScript.realm_name(p_realm),
			TableScript.realm_name(p_realm + 1)]


## 渡劫触发回执（转场之前写给玩家看的那一句）。
static func tribulation_started_line() -> String:
	return TEXT_TRIBULATION_STARTED


## 渡劫成功回执（旧境界名 / 新境界名——名字取自配置表，数字不写死）。[br]
## [br][b]与 [method breakthrough_done_line] 同为「跃迁」句式但句子不同[/b]：玩家回来时
## 需要能分清这次是打赢了天劫、还是走的直接突破那条路。
static func tribulation_succeeded_line(p_old_realm: int, p_new_realm: int) -> String:
	return TEXT_TRIBULATION_SUCCEEDED % [TableScript.realm_name(p_old_realm),
			TableScript.realm_name(p_new_realm)]


## 渡劫失败回执（修为损失量由结算给出——本模块不自己算，同「上限不写死」的理由）。
static func tribulation_failed_line(p_penalty: int) -> String:
	return TEXT_TRIBULATION_FAILED % p_penalty
