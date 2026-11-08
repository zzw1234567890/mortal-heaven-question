extends Node
## MockPopupDeps —— 节点交互弹窗宿主的桩依赖（exploration-ui Story 006）。
##
## 一个 Node 同时充当三个接缝：[br]
##   - [b]探索系统[/b]：[code]use_action_spring(node_id) -> int[/code] /
##     [code]rest_at_node(node_id) -> int[/code]（效果数值由系统返回——UI 零计算）
##   - [b]场景管理器[/b]：[code]request_scene_change(from, to, type) -> bool[/code]
##     （记录每次请求，供「恰好一次 / 不切换」断言）
##   - [b]境界系统[/b]：[code]get_realm_property(level, key) -> Variant[/code]
##
## 契约对齐 [code]src/feature/exploration_system.gd[/code]（灵泉/回复 API）与
## [code]src/foundation/scene_manager.gd[/code]（request_scene_change 签名）。
## 「Feature 层 API 尚未实现」的退化路径由测试内 [code]BareNode[/code] 覆盖
## （无方法节点——不覆盖 [method Node.has_method] 以免与引擎契约冲突）。
##
## 来源: story-006-node-interaction-popups.md AC-4/AC-5/AC-6/AC-8、
## ADR-0005 §关键接口 request_scene_change、ADR-0014 §决策 3。

## 灵泉 API 返回值（回复量——测试注入）。
var spring_restore_result: int = 0
## 回复点 API 返回值（治疗量——测试注入）。
var rest_heal_result: int = 0
## 灵泉 API 调用次数。
var spring_calls: int = 0
## 回复点 API 调用次数。
var rest_calls: int = 0
## 场景切换请求记录——元素为 {from, to, type}。
var scene_changes: Array = []
## 境界属性表（level → {key: value}）。
var realm_table: Dictionary = {1: {"max_deploy": 2}, 5: {"max_deploy": 6}}


## 探索系统接缝：灵泉——回复全部行动力，返回系统计算的回复量。
func use_action_spring(_node_id: int) -> int:
	spring_calls += 1
	return spring_restore_result


## 探索系统接缝：回复点——全队回复 50% 已损失 HP，返回系统计算的治疗量。
func rest_at_node(_node_id: int) -> int:
	rest_calls += 1
	return rest_heal_result


## 场景管理器接缝：记录请求并接受（不执行真实转场——测试不触碰 SceneManager Autoload）。
func request_scene_change(from_scene: int, to_scene: int, transition_type: int) -> bool:
	scene_changes.append({"from": from_scene, "to": to_scene, "type": transition_type})
	return true


## 境界系统接缝：只读属性查询（未知境界返回 null——与真实实现一致）。
func get_realm_property(level: int, key: StringName) -> Variant:
	var entry: Dictionary = realm_table.get(level, {})
	return entry.get(key)
