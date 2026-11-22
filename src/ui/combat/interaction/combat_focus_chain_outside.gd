class_name CombatFocusChainOutside
extends RefCounted
## CombatFocusChainOutside —— 焦点链「链外收拢」的对外窗口（CombatFocusChain 的邻域一半）。[br]
##
## [b]职责[/b]：持有链外收拢器（[CombatFocusChainSweeper]）的实例与它的还原账，
## 对外给三件事——[method sweep] 收拢链外可聚焦控件、[method outside_nodes] 报出
## 此刻还剩谁在链外、[method restore] 把收拢改过的属性还回去。[br]
## [b]不管什么[/b]：谁算链上成员（由调用方给名单）、邻居路径怎么接、焦点落在哪
## ——本件只回答「链子以外还有谁能被 Tab 摸到」。[br]
## [br][b]为什么单独成文件[/b]：[code]combat_focus_chain.gd[/code] 拆出查询、几何与
## 写侧后仍超 300 行软上限（编码标准）；「链外」这一块有独立状态（收拢器的记账）
## 与独立的调用时机（每次阶段落定 + 退场），事例上是最完整的一块。[br]
## [br][b]豁免清单转发自收拢器[/b]：覆盖层子树名只有一处定义
## （[constant CombatFocusChainSweeper.OVERLAY_NAMES]），本件不另抄一份。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：收拢器改的是控件的渲染属性，
## 不构成游戏状态；[b]零轮询[/b]：无 [code]_process()[/code]——由阶段落定与退场显式驱动。
##
## 来源: combat-ui-layout Story 004、先例 [code]combat_focus_chain.gd[/code] 的链外收拢、
## 编码标准「单文件 ≤300 行」。

## 链外控件收拢（Tab 走到链尾时的兜底——逐控件记账，可逆、幂等）。
const Sweeper := preload(
		"res://src/ui/combat/interaction/combat_focus_sweeper.gd")

## 豁免收拢的覆盖层子树名（转发收拢器的单一定义——不在这里另抄一份）。[br]
## [br][b]为什么链不持覆盖层句柄[/b]：备战 / 结算 / 行囊面板分别挂在不同层上
## （由各自的挂载模块建），焦点链只管战场控件；豁免清单归收拢器（它才是执行方）。
const OVERLAY_NAMES: Array[String] = Sweeper.OVERLAY_NAMES

## 战场门面（[code]CombatLayout[/code]——收拢器从它整棵树里找链外可聚焦者）。
var _layout: Control = null
## 链外收拢器（构造时建——持「改过谁」的还原账）。
var _sweeper: RefCounted = null


## 构造——传入战场门面。
func _init(p_layout: Control) -> void:
	_layout = p_layout
	_sweeper = Sweeper.new()


## 收拢链外可聚焦控件（Tab 走到链尾不再跳到战斗日志折叠按钮）。[br]
## [br][b]为什么每次阶段落定都收一次[/b]：链外控件（顶栏 / 覆盖层）的出现时机
## 不由链决定——新面板挂上、旧节点显隐都会改变「谁可聚焦」，只接一次线会在那些
## 时刻漏掉。收拢是幂等的（逐控件记账），重复调用不产生额外代价。[br]
## [br][param p_keep]: 链上成员（本次不该被收的控件）。[br]
## [br][b]返回[/b]：本次收掉几个（0 = 链外本就干净 / 门面不可用）。
func sweep(p_keep: Array) -> int:
	if not _has_layout():
		return 0
	return int(_sweeper.call(&"sweep", _layout, p_keep))


## 链外可聚焦控件清单（纯查询——测试断言「链外已收干净」用）。
func outside_nodes(p_keep: Array) -> Array:
	if not _has_layout():
		return []
	return _sweeper.call(&"outside_nodes", _layout, p_keep)


## 还原收拢改过的 [member Control.focus_mode]（退场用）。[br]
## [br][b]为什么必须还原[/b]：收拢改的是别人（顶栏 / 覆盖层）的属性；不还原的话
## 下一次进战斗时那些控件仍是 [constant Control.FOCUS_NONE]，而它们本不该由链管。
func restore() -> void:
	if _sweeper != null:
		_sweeper.call(&"restore")


## 弃用本窗口（退场——先 [method restore] 再由调用方丢掉引用）。[br]
## [br][b]为什么单独有一步[/b]：退场次序上「还原」必须发生在门面还有效的时候，
## 而丢引用是之后的事——两步分开，调用方才有地方把次序写清楚。
func release() -> void:
	_sweeper = null
	_layout = null


## 门面是否可用（退场 / 未装配 → false）。[br]
## [br][b]每次收拢都问一遍[/b]：门面是场景节点，战斗退场后引用会失效——
## 收拢器不认识这件事，得由本窗口在进入前替它挡住。
func _has_layout() -> bool:
	return _layout != null and is_instance_valid(_layout) and _sweeper != null
