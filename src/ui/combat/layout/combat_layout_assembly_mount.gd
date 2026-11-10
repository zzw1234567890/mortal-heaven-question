extends RefCounted
## CombatLayoutAssemblyMount —— 战场角色卡装配台的接线（combat_layout 拆分模块·装配组）。
##
## [b]职责[/b]：实例化 [code]CombatActorStage[/code]（把敌我名册变成战场角色卡并注册进
## 反馈编排器），转发三件事——[method setup]（注入数据源并绑定编排器）、
## [method build_roster] / [method clear_roster]（开战建卡 / 退场清卡）、
## [method play_card] / [method current_caster_id]（UI 出牌入口与施法者查询）。[br]
## [b]不持有游戏状态[/b]：名册、HP、ATK 全部经装配台的读取链路现读。
##
## [b]为什么单独成文件[/b]：[code]combat_layout.gd[/code] 是场景挂载侧唯一持有的节点，
## 四组接线此前挤在同一个类里（465 行）。本模块只负责「装配这一组」。
##
## 来源: Sprint 18 / DEBT-CBT-018-1、DEBT-CBT-018-10 第四阶段、
## DEBT-CUI-007-2（combat_layout 拆分）。

## 角色卡装配台脚本（Sprint 18——敌我名册 → 战场角色卡）。
const StageScript: GDScript = preload("res://src/ui/combat/layout/combat_actor_stage.gd")
## 施法者裁定纯函数——[code]NO_CASTER[/code] 哨兵的唯一来源（本模块不裸写 -1）。
const CasterRulesScript: GDScript = preload(
		"res://src/ui/combat/shared/combat_caster_rules.gd")
## 出牌交互闭环控制器（选中 → 目标 → 确认）。
const PlayControllerScript: GDScript = preload(
		"res://src/ui/combat/shared/combat_play_controller.gd")

## 宿主布局根（装配台挂在这里）。
var _layout: Control = null
## 出牌交互闭环控制器（惰性创建——[method play_controller]）。
var _play_controller: RefCounted = null
## 装配台实例（[method build] 创建）。[b]类型为 Variant[/b]：新脚本的全局 class_name
## 依赖导入缓存，鸭子类型调用可避免「首次导入前解析失败」的次序问题。
var stage: Variant = null


## 构造——传入宿主布局根。
func _init(p_layout: Control) -> void:
	_layout = p_layout


## 构建装配台并落到两侧容器。
## [param p_ally_area] 己方区（前排贴中线）。[param p_enemy_area] 敌方区。
func build(p_ally_area: Control, p_enemy_area: Control) -> void:
	stage = StageScript.new()
	stage.name = "ActorStage"
	_layout.add_child(stage)
	stage.call(&"set_containers", p_ally_area, p_enemy_area)


## 注入数据源并绑定反馈编排器——此后建的卡自动注册（HP 条 / 飘字 / 阵亡淡出才有对象）。
## [br][param p_combat] 战斗系统（信号源 + 名册快照）。[param p_deployment] 部署系统（我方阵位）。[br]
## [param p_card_system] 卡牌系统（角色卡初始 ATK/HP 模板回退，可空）。[br]
## [param p_binding_manager] 绑定管理器（图标数预留接缝，可空）。[br]
## [param p_coordinator] 反馈编排器（可空——为空时只接线不注册）。
func setup(p_combat: Node, p_deployment: Node, p_card_system: Node = null,
		p_binding_manager: Node = null, p_coordinator: Variant = null) -> void:
	if stage == null:
		return
	stage.call(&"setup", p_combat, p_deployment, p_card_system, p_binding_manager)
	if p_coordinator != null:
		stage.call(&"bind_coordinator", p_coordinator)


## 按开战名册构建战场角色卡（开战入口调用）。[br]
## [param p_player_ids] 开战配置里的我方角色 ID（空 → 回退读 DeploymentSystem 阵位）。
func build_roster(p_player_ids: Array = []) -> void:
	if stage == null:
		return
	stage.call(&"build_roster", p_player_ids)


## 清空战场角色卡（战斗结束 / 场景退场——防悬空注册与残留）。
func clear_roster() -> void:
	if stage != null:
		stage.call(&"clear_roster")


## UI 出牌请求——裁定施法者后转交 [code]CombatSystem.play_card()[/code]。[br]
## [br][b]接线边界[/b]：拖拽 / 点选 / 数字键的出牌手势本体归 combat-ui-interaction epic
## （0/9 未实现）；它们落地时直接调本方法即可，不必自己拼 [code]caster_id[/code]。
func play_card(p_card_instance_id: int, p_target_indices: Array) -> bool:
	if stage == null:
		push_warning("CombatLayout.play_card: 角色卡装配台未装配——出牌中止")
		return false
	return bool(stage.call(&"play_card", p_card_instance_id, p_target_indices))


## 当前裁定出的施法者角色 ID（无阵位 / 全阵亡时为 [constant CasterRulesScript.NO_CASTER]）。
## [br][b]为什么本层不裸写 -1[/b]：[code]-1 = 不猜[/code] 是跨三层的同一约定，
## 哨兵只在 [code]combat_caster_rules.gd[/code] 定义一处，这里引用它保持可检索。
func current_caster_id() -> int:
	if stage == null:
		return CasterRulesScript.NO_CASTER
	return int(stage.call(&"current_caster_id"))


## 出牌交互闭环控制器（选中 → 目标 → 确认 → 反馈）。[br]
## [br][b]惰性创建 + 单例[/b]：UI 的多处手势（拖拽 / 数字键 / 手柄）必须共用同一个
## 控制器——各建一个会让「选中的是哪张」出现多份真理来源。[br]
## [br][b]装配台缺失时返回空的控制器（而非 null）[/b]：交互层不必到处判空；空控制器
## 的 [code]confirm()[/code] 会走「无桥」路径返回拒绝结果，不崩溃。[br]
## [br][b]桥数据源现读[/b]：每次调 [method _wire_play_controller] 都重取——装配台
## 重新 [method setup] 后（换战斗系统）控制器不该继续拿着旧桥。
func play_controller() -> RefCounted:
	if _play_controller == null:
		_play_controller = PlayControllerScript.new()
	if stage != null:
		_play_controller.call(&"setup", stage.call(&"get_play_bridge"))
	return _play_controller


## 出牌交互闭环的拒绝结果载体（UI 提示文本的唯一来源）。[br]
## 门面转发用——交互层只需 [code]controller.confirm().message[/code]。
func confirm_play() -> Dictionary:
	return play_controller().call(&"confirm")


## 选中一张手牌（走闭环控制器的唯一入口——UI 手势调这个）。[br]
## [b]返回[/b]: 选中后能否确认（非法时不可确认，见 HandSelectionModel）。
func select_hand_card(p_card_instance_id: int, p_affordable: bool = true,
		p_psychic: bool = false) -> bool:
	return bool(play_controller().call(&"select_card", p_card_instance_id,
			p_affordable, p_psychic))
