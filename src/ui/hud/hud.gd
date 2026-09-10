class_name Hud
extends CanvasLayer
## HUD —— 全局抬头显示骨架（hud Epic Story 001）。
##
## [b]节点形态[/b]：场景内 CanvasLayer（ADR-0031 §1——零新增 Autoload），
## 由调用方（游戏启动流程）通过 [code]SceneManager.register_persistent()[/code]
## 挂载到 PersistentLayer，场景切换不销毁。[br]
## [br][b]layer = 90[/b]（绘制顺序预算——code-review HIGH-1 修复）：CanvasLayer 按
## [code]layer[/code] 整数排序，显式编号使 PauseOverlay 在任何场景 UI 之上
## （暂停菜单必须全屏置顶）。中间区间留给场景 UI（combat-ui/exploration-ui
## 用默认 1，加载画面隐式 0——HUD 恒在其上）。[br]
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

## LOADING 的 SceneID（99）——不入矩阵，保持前一状态（确定性规则）。
## 单列常量避免在处理器中硬编码魔数。
const _LOADING_SCENE_ID: int = 99

## === 内部状态 ==================================================================

## 注入的 SceneManager 引用（依赖注入——测试可用 mock 替代 Autoload）。
var _scene_manager: Node = null

## === 节点引用 ==================================================================

@onready var content_layer: Control = $ContentLayer
@onready var pause_overlay: Control = $PauseOverlay
## 通知区域组件（H-1 修复——request_notification 转发目标，G7 裁决）。
@onready var _notification_toast_area: NotificationToastArea = $ContentLayer/NotificationArea/NotificationToastArea

## === 生命周期 ==================================================================

## 注入 SceneManager 并订阅转场信号（调用方挂载后调用一次）。[br]
## 依赖注入而非直引 Autoload——测试可传入轻量 mock（先例：
## [code]tests/integration/scene_manager/test_loading_screen.gd[/code]）。[br]
## [br][b]初始可见性同步[/b]（code-review H-1/HIGH-2 修复）：挂载后首信号前，
## 按 SceneManager 当前场景 ID 一次性同步内容分支——启动流程停留 MAIN_MENU
## 时不经转场，若无此同步 HUD 将以 Control 默认值（visible = true）叠加在
## 主菜单上。[code]get_current_scene_id()[/code] 为一次性方法调用而非轮询，
## 不违反 AC-4。[br]
## [b]重复调用防护[/b]：同一 SceneManager 重复 setup 时跳过重复连接。
func setup(scene_manager: Node) -> void:
	_scene_manager = scene_manager
	if _scene_manager == null:
		push_error("HUD.setup: scene_manager 为 null——无法订阅转场信号")
		return
	if not _scene_manager.has_signal(&"post_transition"):
		push_error("HUD.setup: scene_manager 缺少 post_transition 信号")
		_scene_manager = null
		return
	if not _scene_manager.post_transition.is_connected(_on_post_transition):
		_scene_manager.post_transition.connect(_on_post_transition)
	# 初始可见性同步——按当前场景 ID 落定（未注册 ID 时保持隐藏）
	if _scene_manager.has_method(&"get_current_scene_id"):
		var current_id: int = _scene_manager.get_current_scene_id()
		content_layer.visible = SCENE_VISIBILITY.get(current_id, false)

## === 信号处理器 ================================================================

## 通知显示请求（H-1 修复——G7 裁决 HUD 侧转发接线）：转发到通知区域组件
## [code]NotificationToastArea.request_notification[/code]。[br]
## 各系统经 HUD 公共接口请求显示通知——HUD 不主动轮询（ADR-0007 Cat 2b 动作
## 通知；组件侧另发 [signal NotificationToastArea.notification_requested] 信号
## 供未来系统连接）。[br]
## [br][param type]: 通知类型（GDD §4 类型表键；未知类型内核安全默认）。[br]
## [param text]: 通知文本。[br]
## [b]返回[/b]：通知 id（0 表示被容量规则拒绝——UI 层不渲染）。
func request_notification(type: String, text: String) -> int:
	return _notification_toast_area.request_notification(type, text)

## 转场完成 → 按可见性矩阵设置内容分支。[br]
## [b]PauseOverlay 豁免[/b]（GAP-1 裁决）：矩阵只写 [member content_layer.visible]，
## 暂停分支由暂停逻辑独立管理（Story 005）。[br]
## [param to] 为 LOADING 或未注册 ID 时不入矩阵——LOADING 保持前一状态
## （确定性规则）；未注册 ID 同样保持但 [code]push_warning[/code]
## （code-review H-2 修复——新增场景漏配矩阵时显式报警而非静默失效）。
func _on_post_transition(_from: int, to: int) -> void:
	if not SCENE_VISIBILITY.has(to):
		if to != _LOADING_SCENE_ID:
			push_warning("HUD 可见性矩阵缺少 SceneID %d——保持前一状态" % to)
		return
	content_layer.visible = SCENE_VISIBILITY[to]
