extends Control
## ExplorationScene —— 探索阶段薄容器场景（exploration-ui Story S16-2）。
##
## [b]角色[/b]：闭合 [constant SceneManager.SCENE_PATHS] 的 EXPLORATION 占位
## 路径（[code]res://src/feature/exploration/exploration_scene.tscn[/code]）——
## 身份选择→探索的第一跳可端到端演示（Sprint 16 冲刺目标「核心循环可演示
## 第一跳」）。[br]
## [br][b]结构[/b]：root Control 挂载 [code]MapSelectScreen[/code] 实例（story 002
## 交付）；[code]enter_map_requested[/code] 意图后挂载 [code]NodeGraphScreen[/code]
##（story 003 交付——节点图主界面）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本容器不持有游戏状态，仅负责子界面
## 挂载。[method MapSelectScreen] 的 [signal enter_map_requested] 已连
## [method _on_enter_map_requested]（挂载 NodeGraphScreen）；[signal reentry_requested]
## 意图仍无下游消费者（重入实际编排归探索系统，Feature 层补齐后接）。[br]
##
## 来源: ADR-0031 §1、ADR-0005（场景切换唯一仲裁）、story-002/story-003。

## MapSelectScreen 场景常量——实例化地图选择界面（含静态节点树，须用
## PackedScene.instantiate() 而非脚本 new()——脚本 new 不加载 .tscn 节点）。
const MapSelectScreenScene := preload("res://src/ui/exploration/map_select_screen.tscn")
## NodeGraphScreen 场景常量——节点图主界面（story 003 主交付）。
const NodeGraphScreenScene := preload("res://src/ui/exploration/node_graph_screen.tscn")

## 地图选择界面实例（挂载子节点）。
var map_select_screen: Control = null
## 节点图主界面实例（进入地图后挂载）。
var node_graph_screen: Control = null


func _ready() -> void:
	map_select_screen = MapSelectScreenScene.instantiate()
	add_child(map_select_screen)
	# 节点图构建（story 003）：MapSelectScreen 进入意图 → 挂载 NodeGraphScreen
	# 并触发地图加载（真实源连 map_generated / stub 源发 stub 信号）
	map_select_screen.enter_map_requested.connect(_on_enter_map_requested)


## 进入地图意图（MapSelectScreen.enter_map_requested）——挂载节点图主界面并
## 触发加载。[br]
## [b]stub 先行[/b]（story 003）：进入/重入实际编排归探索系统（Feature 层
## map_generated 信号未实现），本 story 以 UI 侧 stub 信号发射器驱动节点图构建；
## Feature 层补齐后仅替换信号源。
func _on_enter_map_requested(_map_id: StringName) -> void:
	if node_graph_screen != null:
		return
	node_graph_screen = NodeGraphScreenScene.instantiate()
	add_child(node_graph_screen)
	node_graph_screen.trigger_map_load()
