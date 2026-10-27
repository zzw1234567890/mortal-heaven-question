extends Control
## ExplorationScene —— 探索阶段薄容器场景（exploration-ui Story S16-2）。
##
## [b]角色[/b]：闭合 [constant SceneManager.SCENE_PATHS] 的 EXPLORATION 占位
## 路径（[code]res://src/feature/exploration/exploration_scene.tscn[/code]）——
## 身份选择→探索的第一跳可端到端演示（Sprint 16 冲刺目标「核心循环可演示
## 第一跳」）。[br]
## [br][b]结构[/b]：root Control 挂载 [code]MapSelectScreen[/code] 实例（本 story
## 主交付）。节点图（story 003）后续加进同一容器。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本容器不持有游戏状态，仅负责子界面
## 挂载。[method MapSelectScreen] 的 [signal enter_map_requested] /
## [signal reentry_requested] 意图信号当前无下游消费者（进入/重入实际编排归
## 探索系统 + story 003 节点图加载——本 story 只发意图，story 003 落地时在此
## 容器内补 connect）。
##
## 来源: ADR-0031 §1、ADR-0005（场景切换唯一仲裁）、story-002-map-select-screen.md。

## MapSelectScreen 场景常量——实例化地图选择界面（含静态节点树，须用
## PackedScene.instantiate() 而非脚本 new()——脚本 new 不加载 .tscn 节点）。
const MapSelectScreenScene := preload("res://src/ui/exploration/map_select_screen.tscn")

## 地图选择界面实例（挂载子节点）。
var map_select_screen: Control = null


func _ready() -> void:
	map_select_screen = MapSelectScreenScene.instantiate()
	add_child(map_select_screen)
