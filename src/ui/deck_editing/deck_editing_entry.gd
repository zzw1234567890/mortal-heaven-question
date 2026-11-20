extends RefCounted
## DeckEditingEntry —— 「进卡组编辑」的跨场景[b]来路意图[/b]（RefCounted 静态类）。[br]
## [br][b]为什么需要[/b]：卡组编辑是一个独立场景（[code]SceneID.DECK_EDITING[/code]），
## 挂载那一刻它无从知道「是谁把我打开的」——主菜单、探索（将来的入口）都要回各自的
## 地方。这一份意图只能跨场景传递（[code]SceneManager[/code] 的转场请求里没有
## 「回来的路」这种字段）。项目内既有口径即 [code]static var[/code] 缓存
## （同 [code]CombatLaunchContext[/code] / [code]ExplorationEntryIntent[/code]）。[br]
## [br][b]一次性[/b]：[method take_origin] 取走即清——同一份来路不会让玩家回到两次，
## 也不会残留到下一次打开时冒出来。[br]
## [br][b]不在这里导航[/b]：转场请求仍必须经
## [code]SceneManager.request_scene_change[/code]（ADR-0005 唯一仲裁）；本模块只回答
## 「保存之后该回哪」，并给出配套的转场类型（音频过渡矩阵按它索引）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只有一枚场景 ID 与两个纯函数，不持节点、
## 不读 GSM。[br]
##
## 来源: ADR-0005（场景切换唯一仲裁）、ADR-0031 §2、
## design/gdd/main-menu-system.md（主菜单入口）、
## design/gdd/audio-system.md §9（过渡矩阵）、
## 先例 [code]exploration_entry_intent.gd[/code]。

## SceneManager 脚本常量——SceneID / TransitionType 枚举真理来源
## （preload 而非 Autoload 全局名——同 [code]battle_record_exit.gd[/code] 口径）。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")

## 来路场景 ID（-1 = 没记过——[method take_origin] 回落到探索）。
static var _origin_scene_id: int = -1


## 请求「进卡组编辑」，并记下来路。[br]
## [br][param p_from_scene_id] 发起方的 [enum SceneManager.SceneID]（调用方现取
## [code]get_current_scene_id()[/code]，不写魔数）。[br]
## [br][b]不在这里导航[/b]：导航由调用方发起（见文件头）。
static func request_edit(p_from_scene_id: int) -> void:
	_origin_scene_id = p_from_scene_id


## 取走来路（取后清空——见文件头「一次性」）。[br]
## [br][b]返回[/b]：来路场景 ID；没记过时回落到 [constant SceneManagerScript.SceneID.EXPLORATION]
## ——把玩家丢回主菜单比留在能继续玩的那一层更糟（同 [code]BattleRecordExit[/code]
## 对未登记屏的处置）。
static func take_origin() -> int:
	var origin: int = _origin_scene_id
	_origin_scene_id = -1
	if origin < 0:
		return SceneManagerScript.SceneID.EXPLORATION
	return origin


## 清空来路（不消费地丢弃——测试隔离用）。
static func clear() -> void:
	_origin_scene_id = -1


## 回某个场景该用哪种转场类型（音频 BGM 过渡按它索引）。[br]
## [br][b]回主菜单走 GAME_TO_MENU[/b]：音频矩阵的
## [code]任意 → MAIN_MENU[/code] 行（1.5s 淡出/淡入）由它索引；错用
## COMBAT_TO_EXPLORE 会把主菜单 BGM 接到探索的过渡参数上。
static func transition_for(p_scene_id: int) -> int:
	if p_scene_id == SceneManagerScript.SceneID.MAIN_MENU:
		return SceneManagerScript.TransitionType.GAME_TO_MENU
	return SceneManagerScript.TransitionType.COMBAT_TO_EXPLORE
