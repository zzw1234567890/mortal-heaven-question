extends RefCounted
## BattleRecordExit —— 结算屏「返回」出口的[b]单一裁决点[/b]。[br]
## [br][b]为什么需要这一层[/b]：胜利结算与战败屏此前共用同一个出口
## （一律回探索），但两条路的目的地规格上并不相同——[br]
##   · [b]胜利[/b]（RESULT_SCREEN）：奖励已入账、节点已标清，玩家要[b]继续探索[/b]
##     （design/ux/exploration-ui.md §节点图主界面「战斗 UI-胜利 → 战利品确认后场景
##     切换」）；[br]
##   · [b]战败/投降[/b]（DEFEAT_SCREEN）：本局已结束，玩家要[b]回主菜单[/b]
##     （design/ux/pause-menu.md §Events Fired「显示战败结算画面 → 玩家点击
##     「返回」→ 回到主菜单」）；这条路径还被音频规格钉死——
##     [code]design/gdd/audio-system.md[/code] 把「战败→任意非主菜单状态」列为
##     [b]N/A 转换[/b]（「战败后必须回到主菜单」），转场矩阵里
##     [code]DEFEATED → MAIN_MENU[/code] 是唯一出边。[br]
## [br][b]为什么是纯函数模块而不是写在场景里[/b]：目的地 / 转场类型 / 按钮文案
## 三者必须同进同退（一个屏幕不能「按钮写着回主菜单、实际转场去探索」），而它们
## 分散在两个场景脚本里就会各写一份、各自漂移。抽成 static 模块后，
## [code]BattleRecordScene[/code] 三个覆写方法都只是转发，判据只有这一处。[br]
## [br][b]文案为什么要显式区分[/b]：「返回」是个含糊词——战败屏与胜利屏并排看时
## 玩家分不清回的是哪一层。两块屏各自写明目的地（「返回探索」/「返回主菜单」），
## 与暂停菜单的「返回主菜单」同词（design/ux/pause-menu.md §Interaction Map）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：全是 static 纯函数，不持节点、不读 GSM。[br]
##
## 来源: design/ux/pause-menu.md（§Events Fired 战斗投降链 / §Interaction Map）、
## design/ux/exploration-ui.md（§节点图主界面 进入来源）、
## design/gdd/audio-system.md（§9 过渡矩阵 N/A 转换）、
## design/gdd/combat-ui-system.md §9、ADR-0005（转场唯一仲裁）、ADR-0031 §2。

## SceneManager 脚本常量——SceneID / TransitionType 枚举真理来源
## （preload 而非 Autoload 全局名——与 placeholder_scene.gd 同源）。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")

## 回探索方向的按钮文案（胜利屏沿用占位契约的既有词条）。
const TEXT_RETURN_EXPLORE: String = "返回探索"
## 回主菜单方向的按钮文案（与暂停菜单的「返回主菜单」同词）。
const TEXT_RETURN_MAIN_MENU: String = "返回主菜单"


## 本屏「返回」的去处（[enum SceneManager.SceneID]）。[br]
## [br][b]未登记的屏一律回探索[/b]：本模块只被结算/战败两块屏消费，
## 未知取值按「继续玩下去」处理——把玩家丢回主菜单比留在原地更糟。[br]
## [br][param p_screen_id] 当前场景的 [member PlaceholderScene.screen_id]。
static func target_scene(p_screen_id: int) -> int:
	if p_screen_id == SceneManagerScript.SceneID.DEFEAT_SCREEN:
		return SceneManagerScript.SceneID.MAIN_MENU
	return SceneManagerScript.SceneID.EXPLORATION


## 本屏「返回」的转场类型（[enum SceneManager.TransitionType]——驱动音频 BGM 过渡）。[br]
## [br][b]战败走 GAME_TO_MENU[/b]：音频矩阵的
## [code]DEFEATED → MAIN_MENU[/code] 行（战败 BGM 淡出 1.0s / 主菜单 BGM 淡入
## 1.5s）由它索引；错用 COMBAT_TO_EXPLORE 会把战败 BGM 接到探索 BGM 上。
static func transition_type(p_screen_id: int) -> int:
	if p_screen_id == SceneManagerScript.SceneID.DEFEAT_SCREEN:
		return SceneManagerScript.TransitionType.GAME_TO_MENU
	return SceneManagerScript.TransitionType.COMBAT_TO_EXPLORE


## 本屏「返回」按钮的文案（两屏必须指向不同的目的地，措辞也随之不同）。[br]
## [br][b]恒非空且不含含糊的「返回」二字单独成词[/b]：占位期没有本地化系统，
## 词条集中在此处（同 [code]PlaceholderScene.TEXT_*[/code] 的豁免注记）。
static func button_text(p_screen_id: int) -> String:
	if p_screen_id == SceneManagerScript.SceneID.DEFEAT_SCREEN:
		return TEXT_RETURN_MAIN_MENU
	return TEXT_RETURN_EXPLORE


## 本屏「返回」是否回到探索（回探索才需要跑「胜利则标节点已清」这类收尾）。[br]
## [br]与 [method target_scene] 同源判定——不另写一份屏幕 ID 比较，
## 免得将来目的地一改就漏掉收尾分支。
static func returns_to_exploration(p_screen_id: int) -> bool:
	return target_scene(p_screen_id) == SceneManagerScript.SceneID.EXPLORATION
