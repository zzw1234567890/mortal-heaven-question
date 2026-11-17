extends RefCounted
## PauseMenuCombatExit —— 战斗中「返回主菜单」的[b]投降收尾[/b]（从
## [PauseMenuState] 拆出）。[br]
## [br][b]为什么不能直接转场[/b]（design/ux/pause-menu.md §Events Fired
## 「修改持久游戏状态的动作」明写）：战斗中点「返回主菜单」不是一次导航，
## 而是[b]一次战败结算[/b]——[br]
## [code]确认 → 触发 COMBAT_RESIGNED（视为战败）→ 显示战败结算画面（与正常战败
## 一致）→ 玩家点击「返回」→ 回到主菜单[/code]。[br]
## 绕过结算直接跳主菜单会留下三笔烂账：战斗域没有清理（
## [code]battle.is_active[/code] 停在 true）、本场战果没有落库（[code]battle_ended[/code]
## 从不发射、[code]CombatResultView[/code] 没有快照）、撤退该扣的 50% 修为没扣
## ——玩家「点一下主菜单就白嫖一场输掉的仗」。[br]
## [br][b]为什么复用 [method CombatSystem.confirm_retreat][/b]：它就是既有撤退入口
## （[code]battle_end(CombatResult.RETREAT)[/code]）——战斗场景自己的「撤退」按钮
## 走的是同一条链（见 [code]combat_scene_exits.gd.on_retreat_confirmed[/code]）。
## 投降与撤退在规则上是同一件事（[code]RETREAT[/code] 即 DEFEAT 语义），UX 规格里
## 的 [code]COMBAT_RESIGNED[/code] 是本项目对它的称呼，没有第二套结算实现。[br]
## [br][b]投降之后谁负责转场[/b]：战斗系统自己——[code]battle_end[/code] 末段按结果
## 请求 DEFEAT_SCREEN(9)（[method CombatSystem._request_scene_change]），战败画面
## 与正常战败[b]同一个场景[/b]（规格要求「与正常战败一致」），玩家从那块「返回主菜单」
## 按钮出来。本模块[b]绝不[/b]再发一次转场请求：两条转场会撞在
## [code]SceneManager._transitioning[/code] 的并发守卫上。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不写任何玩法数据——「视为战败」
## 的全部落库由战斗系统的结算层完成，本模块只回答「该不该投降」与「触发它」。[br]
## [br][b]依赖注入[/b]：CombatSystem 由 [PauseMenu] 每次透传注入（HUD 在生产路径上
## 交 [code]/root/CombatSystem[/code]），测试换掉它即可脱离真实战斗。[br]
## [br][b]拿不到战斗系统时降级[/b]：判为「无法投降」，调用方按普通「返回主菜单」
## 处理——链没接上时退化成旧行为，比把玩家锁在一场关不掉的战斗里强。[br]
##
## 来源: design/ux/pause-menu.md（§Events Fired 战斗中放弃的完整流程 /
## §Interaction Map 战斗中特殊规则）、ADR-0005（导航唯一入口）、ADR-0008
## （战斗生命周期）、ADR-0031 §2、combat-ui-interaction Story（撤退链路）。

## 场景变体判定（[method PauseMenuLayout.is_combat]——单一真理来源，不抄一份
## SceneID 比较）。[br]
## [br]渡劫（TRIBULATION）同属战斗变体（hud GDD §状态与转换），故「战斗中」含它。
const LayoutScript := preload("res://src/ui/hud/pause_menu_layout.gd")

## CombatSystem 引用（HUD 注入；测试替换）。[br]
## [br][b]不直引 Autoload[/b]：与 [PauseMenuActions] 对 SaveLoadSystem / SceneManager
## 的口径一致——测试不必让真实战斗系统在场就能验证「确认之后走了哪条路」。
var combat_system: Node = null


## 本场景下的「返回主菜单」是否[b]必须[/b]先走投降。[br]
## [br][param p_scene_id] 当前场景 ID（[enum SceneManager.SceneID]；未知传 -1）。[br]
## [br][b]两个条件缺一不可[/b]：场景是战斗变体（否则没有战斗可放弃）[b]且[/b]战斗
## 确实活跃（[code]is_battle_active()[/code]）。后者不是多余的守卫——战斗场景在
## 备战确认之前就已经存在，此时点「返回主菜单」不该被判成投降（[code]battle_end[/code]
## 会凭空造出一场「战败」并给玩家记一次撤退）。[br]
## [br][b]返回[/b]：true = 走投降链；false = 调用方按普通返回主菜单处理。
func can_resign(p_scene_id: int) -> bool:
	if not LayoutScript.is_combat(p_scene_id):
		return false
	return _battle_active()


## 触发投降——委托战斗系统的既有撤退入口（[code]confirm_retreat[/code]）。[br]
## [br][b]调用前必须先解除暂停[/b]（归调用方）：[code]confirm_retreat[/code] 会同步
## 走到转场请求，而转场管线不含「恢复 [code]SceneTree.paused[/code]」的职责——
## 冻结态下发起转场，新场景会停在冻结帧（同 [PauseMenu] 关闭序列的注记）。[br]
## [br][b]返回[/b]：是否真的触发了投降；false = 没有活跃战斗（调用方回退普通返回，
## 不要留下一个「菜单关了但哪儿也没去」的中间态）。[br]
## [br][b]不在这里补存档[/b]：撤退结算会改写修为与资源，写盘时机归转场管线
## （[code]SceneManager[/code] Phase 2 的自动存档）——在这之前存一次底，存下的
## 是「输掉的仗还没结算」的中间态，反而把上一份干净存档盖掉。
func resign() -> bool:
	if not _battle_active():
		return false
	combat_system.call(&"confirm_retreat")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 战斗是否活跃（含「战斗系统可用且具备所需能力」的守卫）。[br]
## [br][b]能力探测而非只判非空[/b]：注入的替身可能只有 [code]is_battle_active[/code]
## 而没有 [code]confirm_retreat[/code]（半截接线）——[method resign] 会在调不存在的
## 方法处静默失败（[code]ERR_UNAVAILABLE[/code]），玩家看到的是「点了没反应」。
## 两个能力一起判，缺一即降级回普通返回。
func _battle_active() -> bool:
	if combat_system == null or not (combat_system is Node):
		return false
	if not is_instance_valid(combat_system):
		return false
	if not combat_system.has_method(&"is_battle_active") \
			or not combat_system.has_method(&"confirm_retreat"):
		return false
	return bool(combat_system.call(&"is_battle_active"))
