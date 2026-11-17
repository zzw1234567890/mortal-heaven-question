extends RefCounted
## ExplorationRewardNotice —— 回探索时的[b]战斗奖励到账提示[/b]（从 exploration_scene 拆出）。[br]
## [br][b]链路[/b]：战斗结束 → [code]CombatResultView.publish[/code] 在战斗侧备好文案 →
## 转场回探索 → 探索容器挂载时取走并请求 HUD 通知。[br]
## [br][b]为什么时机是「本场景每次挂载」[/b]（= 从战斗/结算/战败回到探索）：这是玩家
## 真正继续游玩的位置（结算/战败场景随即退场）；提示落在这里才与「已到账」的认知对齐。[br]
## [br][b]一次性[/b]：[code]CombatResultView.take_pending_notice[/code] 取走即清——
## 同一场不会重复弹，反复进出地图也不会重放旧奖励。[br]
## [br][b]为什么从场景拆出来[/b]：[code]exploration_scene.gd[/code] 已贴 300 行软上限
## （.claude/docs/coding-standards.md），而「回探索时补一条提示」与「节点图怎么挂、
## 重入怎么落地」是两件事（同 [code]map_clear_presenter.gd[/code] 先例）。[br]
## [br][b]提示出口复用 [MapSelectNotice.notification_sink][/b]：那里已有「宿主注入字段
## [code]notify_cb[/code] 优先、常驻 HUD 兜底」的唯一实现——两处各写一份必然出现
## 「一处认注入、一处不认」的口径差异。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块只把已备好的文案转交给通知区域，
## 不读 GSM、不算奖励、不写任何东西。[br]
## [br][b]文案本地化豁免[/b]：与各 [code]TEXT_*[/code] 同源口径。[br]
##
## 来源: 本轮「探索→战斗→结算→回探索」闭环、hud Story 004 通知接口、ADR-0031 §2。

## 战斗结算的跨场景缓存（待提示文案的持有者）。
const ResultViewScript := preload("res://src/feature/combat/combat_result_view.gd")
## 通知出口的唯一实现（注入优先 + HUD 兜底，见 [MapSelectNotice.notification_sink]）。
const NoticeScript := preload("res://src/ui/exploration/map_select_notice.gd")

## 提示类型——固定 [code]item[/code]（「获得/正向」语义，见
## [code]CombatRewardLines.notification_type[/code] 口径）。
const NOTIFY_TYPE: String = "item"


## 取走待提示的战斗奖励并请求一条通知（无待提示内容 / 无出口时静默）。[br]
## [br][param p_host] 宿主节点（[code]notify_cb[/code] 注入字段与 HUD 查找锚点）。[br]
## [br][b]返回[/b]：实际展示的文案（空串 = 没有可提示的奖励——测试断言用）。[br]
## [br][b]先取后判出口[/b]：有奖励但没有任何通知出口时，本条也被[b]消费掉[/b]——
## 否则它会一直挂在缓存里，等 HUD 某次恰好可用时弹出一条几分钟前的旧奖励。[br]
## [br][b]无出口不崩[/b]：只留一条 [method @GlobalScope.push_warning]（同
## [code]shop_node_presenter.gd[/code] 口径），不把缺 UI 变成崩溃。
static func flush(p_host: Node) -> String:
	var notice: String = ResultViewScript.take_pending_notice()
	if notice.is_empty():
		return ""
	var sink: Callable = NoticeScript.notification_sink(p_host)
	if not sink.is_valid():
		return ""
	sink.call(NOTIFY_TYPE, notice)
	return notice
