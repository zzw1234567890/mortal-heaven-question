class_name CombatBagMount
extends RefCounted
## CombatBagMount —— 战斗内「行囊」面板与入口按钮的装配（战斗根可选组件）。[br]
## [br][b]职责[/b]：实例化 [code]CombatBagHost[/code]（面板 → 结算 → 回填的编排），把它挂到
## 战场根上，并把底部条的入口按钮与出牌输入开关接过去。[b]不持有游戏状态[/b]——条目、
## HP、灵力全部经结算层现读；本模块只持装配好的宿主句柄。[br]
## [br][b]为什么不是一个「挂载模块」而与其余七组同目录[/b]：其余七组在
## [code]CombatLayout._init[/code] 时就要建（骨架 / 面板 / 覆盖层），行囊的依赖
## （战斗系统 + 存档 + 卡牌系统）那时还没接上——它必须等场景挂载侧注入完才能建。
## 生命周期不同，故归 [code]class_name[/code] 独立类，由场景容器持有。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]，开合全由按钮点击驱动。[br]
##
## 来源: design/gdd/alchemy-crafting-system.md §1c（丹药使用时机「战斗中或背包」）、
## ADR-0031 §2、DEBT-CUI-007-2（combat_layout 拆分先例）。

## 行囊宿主（面板 → 结算 → 回填的编排）。
const HostScript: GDScript = preload("res://src/feature/combat/combat_bag_host.gd")

## 宿主布局根（面板挂在它最后——顺序即绘制层级：盖住手牌区与出牌输入层）。
var _layout: Control = null
## 宿主实例（[method mount] 创建——未装配为 null）。
var host: RefCounted = null


## 构造——传入宿主布局根。
func _init(p_layout: Control = null) -> void:
	_layout = p_layout


## 装配行囊：建宿主、挂面板、接上底部条入口与出牌输入开关。[br]
## [br][param p_set_input] 出牌输入开关 [code]func(enabled: bool) -> void[/code]
## （生产传 [code]CombatSceneInteraction.set_enabled[/code]）。[br]
## [param p_use_layer] 结算层（[code]CombatBagUse[/code]）。[br]
## [param p_focus_memory] 焦点记忆（可空——整场战斗一份，见
## [code]combat_focus_memory.gd[/code]）。[br]
## [br][b]返回[/b]：是否装上了底部条入口按钮（false = 底部条结构不符——面板仍在，
## 只是没有可点的入口；宿主已 push_warning）。[br]
## [br][b]幂等[/b]：重复装配只复用同一个宿主（重复挂面板会让两层遮罩叠在一起）。
func mount(p_set_input: Callable, p_use_layer: RefCounted,
		p_focus_memory: RefCounted = null) -> bool:
	if _layout == null:
		return false
	if host == null:
		host = HostScript.new()
	var bar: Variant = _layout.get(&"combat_bottombar")
	return bool(host.call(&"mount", _layout, bar, p_set_input, p_use_layer,
			p_focus_memory))


## 打开面板（幂等——已打开时只刷新，不重复冻结出牌输入）。
func open() -> void:
	if host != null:
		host.call(&"open")


## 关闭面板并解冻出牌输入（未装配 / 未打开时为空操作）。
func close() -> void:
	if host != null:
		host.call(&"close")


## 面板是否开着（测试与调试用——未装配为 false）。
func is_open() -> bool:
	return host != null and bool(host.call(&"is_open"))


## 退订（场景退场——入口按钮是场景内节点，面板是场景内节点）。[br]
## [br][b]先关再退订[/b]：退订把宿主的手柄全部置空，之后再也解不了冻；若退场时
## 面板还开着，出牌交互层会带着「停用」状态活到下一次进战斗（输入层挂在常驻
## Autoload 的同一条链路上），表现为「进了战斗却点不动牌」。
func unbind() -> void:
	if host == null:
		return
	host.call(&"close")
	host.call(&"unbind")
	host = null
