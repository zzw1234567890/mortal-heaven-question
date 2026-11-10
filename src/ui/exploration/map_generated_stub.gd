class_name MapGeneratedStub
extends Node
## MapGeneratedStub —— map_generated 信号的 UI 侧降级发射器（S16-3 引入）。[br]
## [br][b]角色[/b]：模拟探索系统 [code]map_generated(map_id, map_data)[/code]
## Cat 2b 信号——[b]仅在拿不到真实信号源时启用[/b]（无探索系统 / 系统未声明该
## 信号），保证节点图界面在 headless、编辑器预览、Feature 层缺失时不空白。[br]
## [br][b]生产路径不走这里[/b]：真实来源是 [code]ExplorationSystem.map_generated[/code]
## （2026-11-10 落盘），[NodeGraphLoadSource] 优先选它；降级与否由
## [method NodeGraphScreen.is_using_stub_source] 暴露，集成测试据此断言
## 「真实数据 ≠ stub」。[br]
## [br][b]载荷[/b]：[code]map_data[/code] 来自 [NodeGraphDataStub] stub 快照
## （graph/nodes/visited/current_node/ap_remaining）——与 story-003 stub 契约一致，
## 与真实信号同构，两条路径共用同一渲染入口。
##
## 来源: story-003-node-graph-data-states.md stub 裁决、ADR-0014 §决策 3 信号表。

## map_generated Cat 2b 信号（与 ADR-0014 §决策 3 信号表同构）。
signal map_generated(map_id: StringName, map_data: Dictionary)


## 发射 map_generated——载荷为 stub 快照（真实路径由 [code]ExplorationSystem.enter_map[/code] 发射）。
func emit_map_generated(map_id: StringName = &"qing_yun_jian_zong") -> void:
	map_generated.emit(map_id, NodeGraphDataStub.stub_snapshot())
