extends RefCounted
## PauseMenuLayout —— 暂停菜单的[b]场景变体规则[/b]与形态工具（从 PauseMenu 拆出）。[br]
## [br][b]为什么单独一处[/b]：[code]pause_menu.gd[/code] 已贴 300 行软上限
## （.claude/docs/coding-standards.md），而「哪个场景该藏哪个按钮、焦点起点该落在
## 哪个按钮上」是[b]纯判定[/b]，与「锁怎么配对、模糊动画怎么放、ESC 从哪进来」
## 是两件事（同 [code]pause_menu_actions.gd[/code] / [code]map_select_cards.gd[/code]
## 的拆因）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不持有节点、不读 GSM——每个方法
## 都是 static 纯函数（入参 → 结论），把节点引用交给调用方去写。[br]
## [br][b]按场景调可见性的规格出处[/b]（design/ux/pause-menu.md §States & Variants）：[br]
##   - 探索中：全部按钮可用（探索支持随时存档）；[br]
##   - 战斗中：「保存并退出」隐藏——战斗不支持中退保存（另有渡劫为战斗变体）；[br]
##   - 商店/事件中：同样隐藏——过渡场景不独立存档；[br]
##   - 结算/战败屏：同为过渡场景，同上。[br]
## [br][b]为什么「未知场景 ID 一律显示」[/b]：暂停菜单只存在于游戏内场景
## （探索/战斗/商店/事件/修炼/卡组编辑），拿不到当前场景 ID 时按最宽松处理——
## 藏掉一个本该可用的按钮，玩家会以为存档功能没了；多显示一个则由动作层自身的
## 失败反馈兜底（此处不是存档合法性判定的唯一关口）。[br]
##
## 来源: design/ux/pause-menu.md（States & Variants / 键盘焦点顺序 / 战斗中特殊规则）、
## design/gdd/hud-system.md §8、ADR-0031 §2、.claude/rules/ui-code.md（双输入可达）。

## SceneManager 脚本常量——SceneID 枚举真理来源（不写魔数）。
const SMScript := preload("res://src/foundation/scene_manager.gd")


## 该场景下「保存并退出」是否可见。[br]
## [br][param scene_id] 当前场景 ID（[enum SceneManager.SceneID]；未知传 -1）。[br]
## [br][b]返回[/b]：true = 显示（可存档场景）；false = 隐藏（战斗/过渡场景）。
static func save_exit_visible(scene_id: int) -> bool:
	match scene_id:
		SMScript.SceneID.COMBAT, SMScript.SceneID.TRIBULATION, \
		SMScript.SceneID.SHOP, SMScript.SceneID.EVENT_PANEL, \
		SMScript.SceneID.RESULT_SCREEN, SMScript.SceneID.DEFEAT_SCREEN:
			return false
		_:
			return true


## 该场景是否为战斗（含渡劫变体）。[br]
## [br]确认弹窗据此补「当前战斗进度将丢失——视为战败」一行
## （design/ux/pause-menu.md §返回主菜单确认弹窗）。战斗与渡劫同属「战斗中」变体
## ——hud GDD 把渡劫定为战斗变体（同 HUD 可见性矩阵的口径）。
static func is_combat(scene_id: int) -> bool:
	return scene_id == SMScript.SceneID.COMBAT \
			or scene_id == SMScript.SceneID.TRIBULATION


## 该场景的进度行是否应显示战斗回合口径。[br]
## [br][b]当前只用于判定，不产出文案[/b]：回合数文案待战斗系统暴露读取面后接
## （本 story 的进度行仍只有「探索进度：层 N」——GAP-2 降级裁决未变）。
static func shows_combat_progress(scene_id: int) -> bool:
	return is_combat(scene_id)


## 菜单的键盘/手柄焦点起点——按传入顺序取[b]首个可见且可激活[/b]的按钮。[br]
## [br][b]为什么必须跳过隐藏/置灰的按钮[/b]：战斗中「保存并退出」被隐藏，键盘玩家
## 的焦点若落在一个看不见的按钮上，屏幕上就没有焦点环——按 Enter 又确实触发了
## 那个隐藏按钮的动作（「什么都看不见，但按回车真的存档了」）。置灰按钮同理被引擎
## 拒绝激活，停在上面等于焦点悬空。[br]
## [br][b]为什么用 [method CanvasItem.is_visible_in_tree] 而非 [member CanvasItem.visible]
## [/b]：按钮可能在某个隐藏的父容器里（菜单整体隐藏时），只查自身 [code]visible[/code]
## 会把它当成可选目标。[br]
## [br][param buttons] 候选按钮（调用方按 UX 规格的焦点顺序传入）。[br]
## [br][b]返回[/b]：首个可选按钮；全部不可选时 null（调用方保持现状，不 grab）。
static func first_focusable(buttons: Array) -> Button:
	for button: Variant in buttons:
		if button is Button and _is_focusable(button as Button):
			return button as Button
	return null


## 单个按钮是否可作为焦点起点（可见 / 未置灰 / 焦点模式允许 / 已在树内）。[br]
## [br][b]为什么要求 [method Node.is_inside_tree][/b]：[method Control.grab_focus] 对
## 不在树内的控件无效，菜单刚 [code]add_child[/code] 还没进树时抢先调用会静默失去焦点。
static func _is_focusable(button: Button) -> bool:
	if not is_instance_valid(button):
		return false
	if not button.is_inside_tree() or not button.is_visible_in_tree():
		return false
	return not button.disabled and button.focus_mode != Control.FOCUS_NONE
