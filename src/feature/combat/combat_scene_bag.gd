extends RefCounted
## CombatSceneBag —— 战斗内「行囊」的场景装配（取数 → 结算 → 挂载）。[br]
## [br][b]职责[/b]：把行囊链路的四个模块拼起来并接到战场上——[br]
##   1. [code]CombatBagEntries[/code]（读真实收藏与候选池）；[br]
##   2. [code]CombatBagEffect[/code]（落效果——治疗走伤害落库、增益走状态表）；[br]
##   3. [code]CombatBagUse[/code]（六道校验 + 扣实物 + 扣灵力）；[br]
##   4. [code]CombatBagMount[/code]（面板 + 底部条入口 + 出牌输入冻结）。[br]
## [br][b]为什么单独成文件[/b]：[code]combat_scene_mounting.gd[/code] 已持六组接线，
## 行囊这一组的依赖（存档 / 卡牌系统 / 费用 / 战斗状态表）比其余各组都长，
## 塞进去会让「挂哪些组件」与「怎么把行囊接起来」两件事缠在一起。[br]
## [br][b]依赖全部经参数传入[/b]（ADR-0031 §2）：本模块不查 Autoload——查表散在这里，
## 装配点漏接某个依赖就只会静默降级（先例：PillUse 少接 GSM 后丹药只是「用不成」）。
## Autoload 一律由场景容器（[code]combat_scene.gd[/code]）取好再交进来。[br]
## [br][b]战斗状态表与落库模块走 [code]CombatSystem[/code] 的公开取数口[/b]
## （[method CombatSystem.get_roster_state] / [method CombatSystem.get_damage_settlement]）
## ——那是战斗域的公开边界，装配侧不去 call 它的下划线私有方法。[br]
## [br][b]零状态所有权[/b]：不缓存条目、HP、灵力；持有的只是装配好的模块句柄。[br]
##
## 来源: design/gdd/alchemy-crafting-system.md §1c、ADR-0031 §2、先例
## [code]combat_scene_interaction.gd[/code]（同一形状的「场景 → 组件」装配）。

## 行囊条目投影（只读取数一半）。
const EntriesScript := preload("res://src/feature/combat/combat_bag_entries.gd")
## 效果落库一半（治疗 / 加属性）。
const EffectScript := preload("res://src/feature/combat/combat_bag_effect.gd")
## 结算层（校验 + 扣实物 + 扣灵力）。
const UseScript := preload("res://src/feature/combat/combat_bag_use.gd")
## 收藏模型（背包与行囊共用的同一份只读投影）。
const ModelScript := preload("res://src/feature/inventory/inventory_model.gd")
## 行囊挂载（面板 + 入口按钮 + 输入冻结）。
const MountScript := preload("res://src/feature/combat/combat_bag_mount.gd")


## 装配并挂载行囊。[br]
## [br][param p_layout] 战场根（[code]CombatLayout[/code]）。[br]
## [param p_combat] 战斗系统（读状态表与落库模块；null 时行囊整条链路降级为不可用）。[br]
## [param p_interaction] 出牌交互接线（开面板时冻结出牌输入、并取它持有的焦点记忆）。[br]
## [param p_gsm] 存档管理器（扣实物）。[br]
## [param p_card_system] 卡牌系统（查模板）。[br]
## [param p_cost] 费用系统（读灵力 / 扣灵力）。[br]
## [br][b]返回[/b]：行囊挂载模块（退场时 [code]unbind[/code] 它）；参数不全时为 null。
func wire(p_layout: Control, p_combat: Node, p_interaction: RefCounted,
		p_gsm: Node, p_card_system: Node, p_cost: Node) -> RefCounted:
	if p_layout == null:
		return null
	var use_layer: RefCounted = build_use_layer(p_combat, p_gsm, p_card_system, p_cost)
	var mount: RefCounted = MountScript.new(p_layout)
	mount.call(&"mount", _input_toggle(p_interaction), use_layer,
			_focus_memory_of(p_interaction))
	return mount


## 交互接线持有的焦点记忆（面板开合时还原焦点用）。[br]
## [br][b]返回[/b]：记忆实例，或 null（交互层缺失 / 未实现该入口——那说明这一场
## 战斗本来就没有键盘焦点可言，静默降级）。
func _focus_memory_of(p_interaction: RefCounted) -> RefCounted:
	if p_interaction == null or not p_interaction.has_method(&"focus_memory"):
		return null
	return p_interaction.call(&"focus_memory") as RefCounted


## 拼出结算层（[code]CombatBagUse[/code]）——三层依赖一次接齐。[br]
## [br][b]返回[/b]：结算层（[param p_combat] 为 null 时仍返回可用的空壳——它自己
## 持 null 状态表与落库句柄，效果落不下去会如实返回失败，而不是让调用方拿到 null
## 再各自判一次）。[br]
## [br][b]为什么单独一个方法[/b]：装配顺序（条目 ← 状态表；效果 ← 状态表 + 落库；
## 结算 ← 前两者 + 存档 + 费用）是本链路唯一有先后要求的步骤，写在一处好核对。
func build_use_layer(p_combat: Node, p_gsm: Node, p_card_system: Node,
		p_cost: Node) -> RefCounted:
	var roster: RefCounted = _roster_of(p_combat)
	var entries: RefCounted = EntriesScript.new(
			ModelScript.new(p_gsm, p_card_system), p_card_system, p_cost, roster)
	var effect: RefCounted = EffectScript.new(_settlement_of(p_combat), roster)
	return UseScript.new(entries, effect, p_gsm, p_cost)


## 出牌输入开关——面板打开时冻结、关闭时解冻（见
## [method CombatBagHost.open] 的「隔面板点穿出牌」说明）。[br]
## [br][b]返回[/b]：可调用（交互接线缺失时为空 Callable——宿主对空 Callable 是空操作）。
func _input_toggle(p_interaction: RefCounted) -> Callable:
	if p_interaction == null or not p_interaction.has_method(&"set_enabled"):
		return Callable()
	return Callable(p_interaction, &"set_enabled")


## 战斗状态表——战斗系统缺失或未实现取数口时为 null（效果落不下去，如实失败）。
func _roster_of(p_combat: Node) -> RefCounted:
	if p_combat == null or not p_combat.has_method(&"get_roster_state"):
		return null
	return p_combat.call(&"get_roster_state") as RefCounted


## 伤害落库模块（治疗落库的唯一入口）——同上。
func _settlement_of(p_combat: Node) -> RefCounted:
	if p_combat == null or not p_combat.has_method(&"get_damage_settlement"):
		return null
	return p_combat.call(&"get_damage_settlement") as RefCounted
