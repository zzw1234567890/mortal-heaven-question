extends RefCounted
## MapClearView —— 地图通关结算的跨场景视图缓存（[code]static var[/code]）。[br]
## [br][b]为什么需要[/b]：Boss 战胜利发生在[b]战斗结算场景[/b]
## （[code]result_screen[/code]）里，而「地图通关！」面板挂在探索薄容器回到地图选择
## 时那一刻——两者之间隔着一次场景切换。结算在切换[b]之前[/b]发生
## （[code]PlaceholderScene[/code] 里调 [code]end_exploration(BOSS_DEFEATED)[/code]），
## 面板在切换[b]之后[/b]才挂载，中间必须有个落点。项目内跨场景轻量缓存的既有口径即
## [code]static var[/code]（同 [code]CombatResultView._pending_notice[/code] /
## [code]CombatLaunchContext._pending[/code]）。[br]
## [br][b]为什么不留 [code]exploration_ended[/code] 信号[/b]：那个信号在结算那一刻
## 就发完了，此时面板还不存在于任何场景树里——信号是「当下」的，跨场景要的是
## 「留到下次挂载」。[br]
## [br][b]一次性[/b]：[method take] 取走即清——反复进出地图不会重放上一局的通关结算
## （与 [method CombatResultView.take_pending_notice] 同口径）。[br]
## [br][b]只读视图[/b]（ADR-0031 §2）：本模块存的是已算好并[b]已发放[/b]的展示数据
## （地图名 / 灵石 / 修为 / 卡牌条目），面板不重算任何数值、也不写任何状态。[br]
## [br][b]基础与首通分两段[/b]（GDD exploration-ui-system.md §7：首次通关奖励独立
## 高亮、非首次不显示该行）：[constant KEY_LING_SHI] /
## [constant KEY_CULTIVATION] / [constant KEY_CARDS] 是[b]基础通关奖励[/b]；
## 带 [code]FIRST_[/code] 前缀的三个键是[b]首通额外奖励[/b]，重复通关时全为 0 / 空。[br]
## [br][b]整数键名与 [code]rewards[/code] 同源[/b]：[code]ling_shi[/code] 沿用
## [code]CLEAR_REWARDS[/code] / [code]calculate_map_clear_rewards[/code] 的键名，
## 不在这里换个写法（同一事实不出现两个键名）。[br]
## [br][b]卡牌条目形状[/b]：直接沿用发放器 [code]CombatRewardRoller.apply[/code] 的
## 产出（[code]name / rarity / school[/code] 已补齐）——面板不做二次加工。
##
## 来源: design/gdd/exploration-ui-system.md §7 地图通关结算、
## design/gdd/exploration-system.md §5 地图通关奖励、ADR-0014 §决策 5、
## ADR-0031 §2 零状态所有权。

## 结算视图的键名（单一真理来源——发布方与面板都不裸写字符串）。
const KEY_MAP_ID: String = "map_id"
const KEY_MAP_NAME: String = "map_name"
const KEY_IS_FIRST_CLEAR: String = "is_first_clear"
const KEY_CLEAR_COUNT: String = "clear_count"
## 基础通关奖励（GDD §公式 5——按难度档给，灵石已扣境界差额惩罚）。
const KEY_LING_SHI: String = "ling_shi"
const KEY_CULTIVATION: String = "cultivation"
## 首通额外奖励（重复通关时为 0 / 空数组）。
const KEY_FIRST_LING_SHI: String = "first_ling_shi"
const KEY_FIRST_CULTIVATION: String = "first_cultivation"
## 卡牌分两段：基础一段、首通一段——面板要分开画（首通行独立高亮），
## 合并成一段后就无从区分哪张卡是首通彩头。
const KEY_CARDS: String = "cards"
const KEY_FIRST_CARDS: String = "first_cards"
const KEY_CARDS_FAILED: String = "cards_failed"

## 待展示的通关结算（空字典 = 没有待展示的结算）。
static var _pending: Dictionary = {}


## 写入待展示的通关结算（非字典按空处理——不臆造面板数据）。[br]
## [br][b]深拷贝[/b]：不与调用方共享引用（结算方后续还会改自己那份 rewards）。
static func publish(p_view: Variant) -> void:
	_pending = (p_view as Dictionary).duplicate(true) if p_view is Dictionary else {}


## 一次性取走结算视图（取后清空——同一局不会弹两次）。
static func take() -> Dictionary:
	var view: Dictionary = _pending
	_pending = {}
	return view


## 查看当前待展示的结算（不消费——测试/预览用）。
static func peek() -> Dictionary:
	return _pending.duplicate(true)


## 清空（测试隔离 / 放弃展示）。
static func clear() -> void:
	_pending = {}
