extends RefCounted
## CombatSceneExits —— 战斗场景的出口与撤退流转（combat-ui-interaction 001 / 本轮）。
##
## [b]职责[/b]：把「备战返回 / 撤退确认 / 战败确认」三个面板出口与「回探索」的
## 唯一导航入口收在一处——[code]combat_scene.gd[/code] 只保留「何时开战 / 何时退场」
## 的编排，不再承载导航细节（单文件 300 行软上限）。[br]
## [br][b]撤退语义[/b]：战斗活跃 → 走战斗系统 [code]confirm_retreat()[/code]
## （battle_end → DEFEAT_SCREEN）；未开战 → 直接回探索（防「未开战的撤退」把玩家
## 困在战斗场景）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：战斗系统 / SceneManager 经 [method setup]
## 注入、每次现读；本模块只持注入句柄。[br][b]零轮询[/b]：全部由面板信号驱动。
##
## 来源: ADR-0005（场景切换唯一仲裁）、ADR-0031、combat-ui-layout Story 008。

## SceneManager 脚本常量——SceneID / TransitionType 单一真理来源。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")

## 战斗系统（可空）。
var _combat: Node = null
## SceneManager（可空——缺失时出口降级为 push_error，不崩）。
var _scene_manager: Node = null


## 注入数据源（全部可空——缺失时对应出口降级，不抛错）。
func setup(p_combat: Node, p_scene_manager: Node) -> void:
	_combat = p_combat
	_scene_manager = p_scene_manager


## 备战返回——回探索（音频矩阵 COMBAT_TO_EXPLORE 行）。
func on_deploy_back() -> void:
	request_exploration()


## 撤退确认——战斗活跃时走战斗系统结算；未开战时直接回探索。
func on_retreat_confirmed() -> void:
	if _combat != null and _combat.has_method(&"confirm_retreat") \
			and _combat.has_method(&"is_battle_active") \
			and bool(_combat.call(&"is_battle_active")):
		_combat.call(&"confirm_retreat")
		return
	request_exploration()


## 战败面板确认返回探索（战败/撤退结算面板的出口）。
func on_defeat_confirmed() -> void:
	request_exploration()


## 请求回探索——唯一导航入口（ADR-0005）。[br]
## [br][b]from 动态取当前场景[/b]：不写魔数（PauseMenu / MainMenu 同源先例）。
func request_exploration() -> void:
	if _scene_manager == null or not _scene_manager.has_method(&"request_scene_change"):
		push_error("CombatScene: SceneManager 不可用——返回探索中止")
		return
	var from_id: int = SceneManagerScript.SceneID.COMBAT
	if _scene_manager.has_method(&"get_current_scene_id"):
		from_id = int(_scene_manager.call(&"get_current_scene_id"))
	_scene_manager.call(&"request_scene_change", from_id,
			SceneManagerScript.SceneID.EXPLORATION,
			SceneManagerScript.TransitionType.COMBAT_TO_EXPLORE)
