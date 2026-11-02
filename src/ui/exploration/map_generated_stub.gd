class_name MapGeneratedStub
extends Node
## MapGeneratedStub —— map_generated 信号的 UI 侧 stub 发射器（S16-3）。
##
## [b]角色[/b]：模拟探索系统 [code]map_generated(map_id, map_data)[/code] Cat 2b
## 信号——Feature 层该信号尚未实现（story-003 Dependencies 依赖缺口），UI 侧以
## 本发射器驱动节点图构建（替换 story-001 的 [code]setup()[/code] 直连 stub 调用
## 为信号驱动路径）。[br]
## [br][b]生命周期[/b]：Feature 层 [code]map_generated[/code] 信号落盘后，
## [NodeGraphScreen] 改连真实信号源，本文件整体删除——信号源替换不牵连渲染路径。[br]
## [br][b]载荷[/b]：[code]map_data[/code] 来自 [NodeGraphDataStub] stub 快照
## （graph/nodes/visited/current_node/ap_remaining）——与 story-003 stub 契约一致。
##
## 来源: story-003-node-graph-data-states.md stub 先行裁决、ADR-0014 §决策 3 信号表。

## map_generated Cat 2b 信号（与 ADR-0014 §决策 3 信号表同构）。
signal map_generated(map_id: StringName, map_data: Dictionary)


## 发射 map_generated——载荷为 stub 快照（Feature 层补齐后由真实 enter_map 发射）。
func emit_map_generated(map_id: StringName = &"qing_yun_jian_zong") -> void:
	map_generated.emit(map_id, NodeGraphDataStub.stub_snapshot())
