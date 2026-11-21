class_name NodePopupServices
extends RefCounted
## NodePopupServices —— 节点交互弹窗的外部服务调用面（从
## [code]node_interaction_popup_host.gd[/code] 拆出）。[br]
## [br][b]职责[/b]：弹窗确认后要碰的外部世界——探索系统 API（灵泉/回复点）、
## SceneManager 转场请求、RealmSystem 只读查询、快照里的渡劫判定。[br]
## [br][b]为什么独立[/b]：宿主只应回答「开哪个弹窗、派发什么」，具体调哪个
## 系统、缺依赖时怎么降级，是另一类知识——拆开后宿主不再持有 SceneManager /
## RealmSystem 的枚举与表结构，改这些只动一处。[br]
## [br][b]降级口径[/b]：依赖缺失时不抛错、不臆造数值——灵泉/回复返回 0 并
## push_warning，转场静默跳过（宿主信号仍会发出，由上层编排决定）。[br]
## [br][b]UI 零数值计算[/b]（control-manifest）：本文件只转发系统返回值，
## 不推算回复量/治疗量/境界上限。
##
## 来源: ADR-0014 §决策 3、ADR-0031 §2、exploration-ui Story 006
## （AC-4/AC-5/AC-6/AC-7）、control-manifest §Presentation。

## SceneManager 枚举真理来源（preload 避免 headless 下的全局名解析问题）。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
const RealmSystemScript := preload("res://src/core/realm_system.gd")
## 交互规则（渡劫判定与常量同源）。
const Rules := preload("res://src/ui/exploration/node_interaction_rules.gd")
## 渡劫入口共用件——顺序与收尾的唯一出处（修炼室同调它）。
const LaunchScript := preload("res://src/feature/tribulation/tribulation_launch.gd")


## 灵泉——调用探索系统 API（效果执行归 Feature 层），返回系统给出的回复量。
func use_spring(p_system: Node, p_node_id: int) -> int:
	if p_system == null:
		return 0
	if p_system.has_method(&"use_action_spring"):
		return int(p_system.call(&"use_action_spring", p_node_id))
	# Feature 层 API 未实现（story Out of Scope：效果执行归探索系统域）
	push_warning("NodeInteractionPopupHost: 探索系统缺少 use_action_spring()——灵泉效果未执行")
	return 0


## 回复点——调用探索系统 API，返回系统给出的治疗量。
func rest_party(p_system: Node, p_node_id: int) -> int:
	if p_system == null:
		return 0
	if p_system.has_method(&"rest_at_node"):
		return int(p_system.call(&"rest_at_node", p_node_id))
	push_warning("NodeInteractionPopupHost: 探索系统缺少 rest_at_node()——回复点效果未执行")
	return 0


## 请求场景切换（[b]唯一入口[/b]——control-manifest Required：禁止直调
## [code]change_scene_to_file[/code]）。缺失时仅发信号。
func request_scene_change(p_scene_manager: Node, p_to_scene: int,
		p_transition: int) -> void:
	if p_scene_manager != null and p_scene_manager.has_method(&"request_scene_change"):
		p_scene_manager.call(&"request_scene_change",
				SceneManagerScript.SceneID.EXPLORATION, p_to_scene, p_transition)


## 当前境界上场人数上限（RealmSystem 只读查询；UI 不推算境界数值）。[br]
## [param p_host] 宿主节点（RealmSystem 缺失时用于 Autoload 兜底查找，可空）。
func max_deploy(p_realm_system: Node, p_realm_id: int, p_host: Node = null) -> int:
	var rs: Node = p_realm_system
	if rs == null and p_host != null:
		rs = p_host.get_node_or_null(NodePath("/root/RealmSystem"))
	if rs != null and rs.has_method(&"get_realm_property"):
		var value: Variant = rs.call(&"get_realm_property", p_realm_id, &"max_deploy")
		if value != null:
			return int(value)
	return int((RealmSystemScript.realm_table.get(p_realm_id, {}) as Dictionary)
			.get("max_deploy", 1))


## 渡劫台是否修为圆满——“修为未满不弹窗”（AC-7）。[br]
## [b]数据源[/b]：渲染快照 nodes[node_id].tribulation_ready；快照缺失或
## 字段缺失时宽松视为圆满（详细判定归渲染层 [method NodeStateLogic.is_tribulation_not_ready]）。
func tribulation_ready(p_snapshot: Dictionary, p_node_id: int) -> bool:
	var nodes: Dictionary = p_snapshot.get("nodes", {})
	var detail: Dictionary = nodes.get(p_node_id, {})
	return Rules.tribulation_ready(detail)


## 渡劫入口（顺序 + 失败收尾 + 回执全在共用件里——两个入口同调它）。[br]
## [br][b]为什么这里不自己组织调用顺序[/b]：渡劫的正确顺序是「先触发状态机、再转场」，
## 而探索节点图此前正是少做了前半步——只转场，渡劫场景进战时状态还在
## [code]NOT_READY[/code]，[code]start_tribulation_combat[/code] 校验不过而降级成普通
## 战斗，[code]on_battle_ended[/code] 又因状态不是 [code]IN_COMBAT[/code] 直接 return，
## [b]打赢也不进境[/b]。顺序收在 [code]tribulation_launch.gd[/code] 一处，节点图与
## 修炼室便不可能再各写一套（见该类文档）。[br]
## [br][param p_from_scene] 源场景兜底值（真实 SceneManager 在时以实况为准）。[br]
## [br][b]返回[/b]：共用件的结果字典 [code]{ok, outcome, text}[/code]——调用方按
## [code]ok[/code] 决定发「已请求」还是「被拒」。[br]
func launch_tribulation(p_tribulation_system: Node, p_scene_manager: Node,
		p_host: Node, p_from_scene: int, p_cross_realm: bool = false) -> Dictionary:
	return LaunchScript.launch(resolve_tribulation(p_tribulation_system, p_host),
			p_scene_manager, p_from_scene, p_cross_realm)


## 渡劫系统（注入优先，否则 [code]/root[/code] 兜底查找——同 [method max_deploy]
## 对 RealmSystem 的口径）。[br]
## [br][b]为什么允许兜底[/b]：渡劫系统是 Autoload，探索屏幕不必为它多传一个参数；
## 注入口留着是给测试换替身用的（生产路径走现读，UI 不缓存系统引用）。
func resolve_tribulation(p_tribulation_system: Node, p_host: Node = null) -> Node:
	if p_tribulation_system != null and is_instance_valid(p_tribulation_system):
		return p_tribulation_system
	if p_host != null:
		return p_host.get_node_or_null(NodePath("/root/TribulationSystem"))
	return null
