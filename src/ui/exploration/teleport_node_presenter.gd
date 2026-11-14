class_name TeleportNodePresenter
extends RefCounted
## TeleportNodePresenter —— 传送节点的「到达之后」接线。[br]
## [br][b]为什么不走 [NodeInteractionPopupHost][/b]：传送节点是 GDD §4c 2026-09-08
## B5 裁决[b]显式排除[/b]在分发表之外的（[code]DISPATCH_TABLE[/code] 里没有
## [code]teleport[/code] 键，两条既有测试锁定这一点），宿主收到它会直接返回。
## 传送的交互形态也不是「确认框」（节点图上的一次确认）而是「选层 overlay」——
## 与商店 overlay（B9 裁决）同类的面板编排，因此走与本宿主平级的独立通道。[br]
## [br][b]流程[/b]：交互组件转发 [code]node_interaction_forwarded(node_id,
## &"teleport", payload)[/code] → 本类按载荷里的 [code]targets[/code]（可跳转层
## 列表，到达时由探索系统下发）上架 [TeleportPanelScreen] → 玩家选层 →
## [code]ExplorationSystem.teleport_to_node[/code] 执行跳转 → 面板关闭 + 一句提示。[br]
## [br][b]可跳层为空[/b]（GDD §8 边界：目标层均未解锁）：不上架面板，直接发一句
## 「暂无可跳转的层」提示——与「传送节点显示为不可激活状态」同一语义的可读形态。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本类不写任何玩法数据——AP 不扣（传送
## 0 行动力）、位置与已访问全在 [code]ExplorationTeleport[/code] 里写。[br]
## [br][b]节点图冻结[/b]：与商店 overlay 同一套（舞台冻结 + 交互组件键盘路径开关），
## 在面板关闭时解冻；面板开着时节点图不吃输入（GDD §4c overlay 口径）。[br]
##
## 来源: design/gdd/exploration-system.md §4 移动规则 / §8 边界、
## design/gdd/exploration-ui-system.md §4c、ADR-0031 §2、B5 裁决（传送无确认弹窗）、
## 先例 [code]shop_node_presenter.gd[/code]。

const TeleportPanelScript := preload("res://src/ui/exploration/teleport_panel_screen.gd")

## 提示文案（跳转成功——层号 1 基，与面板行文案/HUD「层 x/y」同口径）。
const TEXT_TELEPORTED: String = "传送：已抵达第 %d 层"
## 无可用层的提示文案（GDD §8 边界「传送节点不可激活」的可读形态）。
const TEXT_NO_TARGETS: String = "传送：此处灵脉未通，暂无可跳转的层"
## 跳转被拒的提示文案（系统 reason 另附——见 [method _on_layer_chosen]）。
const TEXT_REJECTED: String = "传送失败"
## 提示类型（HUD 通知区域色档——blue = 位移/中性信息）。
const NOTIFY_TYPE: String = "blue"

## 探索系统（跳转 API 调用方；本类只读它的返回值）。
var _system: Node = null
## 节点图屏幕（面板挂载宿主）。
var _host: Control = null
## 提示出口 [code]func(type: String, text: String) -> int[/code]（可空）。
var _notify: Callable = Callable()
## 面板期间的节点图冻结 / 解冻（由宿主注入——通常接 [NodePopupStage]）。
var _freeze: Callable = Callable()
var _unfreeze: Callable = Callable()
## 是否已冻结（幂等守卫）。
var _frozen: bool = false

## 当前传送节点 ID（-1 = 无面板）。
var _node_id: int = -1
## 当前面板（未打开为 null）。
var _panel: Control = null
## 最近一次提示文案（测试断言用；未发过为空串）。
var _last_hint: String = ""


## 接线：连接交互组件的到达转发信号。[br]
## [br][param p_exploration_system] 探索系统（[code]teleport_to_node[/code] 调用方）。[br]
## [param p_interactor] 交互组件（[code]node_interaction_forwarded[/code] 信号源）。[br]
## [param p_host] 面板挂载宿主（节点图屏幕）。[br]
## [param p_notify] 提示出口 [code]func(type, text)[/code]（可空）。[br]
## [param p_freeze] / [param p_unfreeze] 面板期间的节点图冻结/解冻（可空）。
func attach(p_exploration_system: Object, p_interactor: Control, p_host: Control,
		p_notify: Callable = Callable(), p_freeze: Callable = Callable(),
		p_unfreeze: Callable = Callable()) -> void:
	_system = p_exploration_system as Node
	_host = p_host
	_notify = p_notify
	_freeze = p_freeze
	_unfreeze = p_unfreeze
	if p_interactor == null or not is_instance_valid(p_interactor):
		return
	if not p_interactor.has_signal(&"node_interaction_forwarded"):
		return
	var handler := Callable(self, &"_on_node_interaction")
	if not p_interactor.is_connected(&"node_interaction_forwarded", handler):
		p_interactor.connect(&"node_interaction_forwarded", handler)


# ═══════════════════════════════════════════════════════════════════════════════
# 查询（测试/宿主）
# ═══════════════════════════════════════════════════════════════════════════════

## 传送面板是否打开。
func is_panel_open() -> bool:
	return _panel != null and is_instance_valid(_panel)


## 当前面板（未打开为 null——测试读它的渲染结果）。
func panel() -> Variant:
	return _panel if is_panel_open() else null


## 最近一次提示文案（空串 = 没发过）。
func last_hint() -> String:
	return _last_hint


## 面板期间节点图是否处于冻结态（测试断言用）。
func is_node_graph_frozen() -> bool:
	return _frozen


## 关闭面板（「离开」按钮 / 宿主强制关闭）。
func close_panel() -> void:
	if is_panel_open():
		_panel.queue_free()
	_panel = null
	_node_id = -1
	_release_freeze()


# ═══════════════════════════════════════════════════════════════════════════════
# 到达消费
# ═══════════════════════════════════════════════════════════════════════════════

## 交互组件到达转发——只认 [code]teleport[/code]（其余类型原样放行给弹窗宿主）。[br]
## [br][b]载荷契约[/b]：[code]payload.targets[/code] 为可跳转层列表
## （[code][{layer, node_ids}][/code]）——到达时由探索系统算出并随信号下发。
func _on_node_interaction(p_node_id: int, p_interaction_type: StringName,
		p_payload: Dictionary = {}) -> void:
	if p_interaction_type != &"teleport":
		return
	if _host == null or not is_instance_valid(_host):
		return
	var targets: Array = p_payload.get("targets", [])
	if targets.is_empty():
		_emit_hint(TEXT_NO_TARGETS)
		return
	_node_id = p_node_id
	_open_panel(targets)


## 构建并挂载传送面板（重复到达先清旧面板——同时只存在一个）。
func _open_panel(p_targets: Array) -> void:
	if is_panel_open():
		_panel.queue_free()
	_panel = TeleportPanelScript.new()
	_panel.name = "TeleportPanel"
	_host.add_child(_panel)
	_panel.connect(&"layer_chosen", _on_layer_chosen)
	_panel.connect(&"leave_requested", close_panel)
	_panel.call(&"present", p_targets)
	_apply_freeze()


# ═══════════════════════════════════════════════════════════════════════════════
# 选层 → 跳转
# ═══════════════════════════════════════════════════════════════════════════════

## 玩家选了某一层——落在该层的首个可跳节点上，由 Feature 层执行跳转。[br]
## [br][b]落点由系统定[/b]（[code]target_node_of_layer[/code]）：面板只报层号，
## 不在 UI 里挑节点（UI 零数值计算）。[br]
## [br][b]先关面板再跳[/b]：跳转会触发 [code]resolve_node[/code]，若目标正好是
## 商店/灵泉一类节点，其弹窗要在没有传送面板挡路的情况下出现。
func _on_layer_chosen(p_layer: int) -> void:
	var node_id: int = _node_id
	close_panel()
	if _system == null or not is_instance_valid(_system):
		return
	if not _system.has_method(&"teleport_to_layer"):
		push_warning("TeleportNodePresenter: 探索系统缺少 teleport_to_layer()——传送未执行")
		return
	var result: Dictionary = _system.call(&"teleport_to_layer", node_id, p_layer)
	if bool(result.get("success", false)):
		_emit_hint(TEXT_TELEPORTED % (p_layer + 1))
		return
	_emit_hint("%s（%s）" % [TEXT_REJECTED, str(result.get("reason", ""))])


# ═══════════════════════════════════════════════════════════════════════════════
# 冻结 / 提示
# ═══════════════════════════════════════════════════════════════════════════════

## 冻结节点图（面板期间不吃输入）。未注入回调时静默跳过——面板自身的全屏遮罩
## 仍拦住鼠标（headless 单测路径），[member _frozen] 如实保持 false。
func _apply_freeze() -> void:
	if not _freeze.is_valid():
		return
	_frozen = true
	_freeze.call()


## 解冻节点图（幂等——未冻结时不重复调用）。不依赖面板实例：面板被外部释放时
## 仍要放出来（防节点图锁死）。
func _release_freeze() -> void:
	if not _frozen:
		return
	_frozen = false
	if _unfreeze.is_valid():
		_unfreeze.call()


## 发一句提示——注入出口优先；未注入时只留痕（不把缺 UI 变成崩溃）。
func _emit_hint(p_text: String) -> void:
	_last_hint = p_text
	if _notify.is_valid():
		_notify.call(NOTIFY_TYPE, p_text)
		return
	push_warning("TeleportNodePresenter: 无通知出口，提示未展示（%s）" % p_text)
