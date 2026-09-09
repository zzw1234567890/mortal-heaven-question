extends CanvasLayer
## HUD —— 全局抬头显示骨架（hud Epic Story 001）。
##
## [b]节点形态[/b]：场景内 CanvasLayer（ADR-0031 §1——零新增 Autoload），
## 由调用方（游戏启动流程）通过 [code]SceneManager.register_persistent()[/code]
## 挂载到 PersistentLayer，场景切换不销毁。[br]
## [br][b]结构[/b]（两个一级分支，骨架仅挂载点）：[br]
##   - [code]ContentLayer[/code]（Control）——内容分支，受可见性矩阵控制；
##     下分四个区域容器（RealmBarArea 左上 / LingshiDeckArea 右上 /
##     ExplorationInfoArea 右下 / NotificationArea 顶部通知），由 Story 002/003 填充[br]
##   - [code]PauseOverlay[/code]（Control，PROCESS_MODE_ALWAYS）——暂停菜单挂载点，
##     [b]不受[/b]可见性矩阵控制（GAP-1 裁决豁免），本体归 Story 005[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2 / AC-6）：本脚本不持有任何游戏状态副本，
## 无 [code]_cache[/code]/[code]_last[/code] 前缀成员。[br]
## [br][b]零轮询[/b]（AC-4）：可见性切换仅由 [signal post_transition] 信号驱动，
## 无 [code]_process()[/code]。
##
## [br]来源: ADR-0031（表现层架构基线）、GDD design/gdd/hud-system.md、
## hud Story 001（2026-09-08 GAP 裁决）。

## === 可见性矩阵 ==============================================================

## SceneID → 内容分支可见性（GAP-3 裁决——按 GDD 收紧，2026-09-08）。[br]
## [br]数据驱动 const Dictionary——矩阵调整只改此处，便于审阅。[br]
## [b]LOADING 不入表[/b]：内部中间态保持前一状态（确定性规则——不可见性
## 目标态由 [code]post_transition[/code] 的 [code]to[/code] 目标落定，
## [code]pre_transition[/code] 期间不处理）。
const SCENE_VISIBILITY: Dictionary = {
	0:  false,  # MAIN_MENU       —— 主菜单自含导航（GAP-3 裁决）
	1:  false,  # IDENTITY_SELECT —— 开局流程独立（GAP-3 裁决）
	2:  true,   # DECK_EDITING    —— GDD 边界澄清（2026-09-05）
	3:  true,   # EXPLORATION     —— 含地图选择内部状态
	4:  false,  # COMBAT          —— combat-ui 接管（边界澄清 2026-09-05）
	5:  false,  # TRIBULATION     —— 渡劫为战斗变体（GAP-3 裁决）
	6:  true,   # SHOP
	7:  true,   # EVENT_PANEL
	8:  false,  # RESULT_SCREEN   —— 结算独立全屏（GAP-3 裁决）
	9:  false,  # DEFEAT_SCREEN   —— 战败独立全屏（GAP-3 裁决）
	10: true,   # CULTIVATION     —— GDD 边界澄清（2026-09-05）
}

## === 内部状态 ==================================================================

## 注入的 SceneManager 引用（依赖注入——测试可用 mock 替代 Autoload）。
var _scene_manager: Node = null

## === 节点引用 ==================================================================

@onready var content_layer: Control = $ContentLayer
@onready var pause_overlay: Control = $PauseOverlay

## === 生命周期 ==================================================================

## 注入 SceneManager 并订阅转场信号（调用方挂载后调用一次）。[br]
## 依赖注入而非直引 Autoload——测试可传入轻量 mock（先例：
## [code]tests/integration/scene_manager/test_loading_screen.gd[/code]）。
func setup(scene_manager: Node) -> void:
	_scene_manager = scene_manager
	if _scene_manager == null:
		push_error("HUD.setup: scene_manager 为 null——无法订阅转场信号")
		return
	if not _scene_manager.has_signal(&"post_transition"):
		push_error("HUD.setup: scene_manager 缺少 post_transition 信号")
		_scene_manager = null
		return
	_scene_manager.post_transition.connect(_on_post_transition)

## === 信号处理器 ================================================================

## 转场完成 → 按可见性矩阵设置内容分支。[br]
## [b]PauseOverlay 豁免[/b]（GAP-1 裁决）：矩阵只写 [member content_layer.visible]，
## 暂停分支由暂停逻辑独立管理（Story 005）。[br]
## [param to] 为 LOADING 时不入矩阵（保持前一状态——确定性规则）。
func _on_post_transition(_from: int, to: int) -> void:
	if not SCENE_VISIBILITY.has(to):
		# LOADING（99）及未来未注册 ID——保持前一状态
		return
	content_layer.visible = SCENE_VISIBILITY[to]
