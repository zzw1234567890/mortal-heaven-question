class_name MeditationNodePresenter
extends RefCounted
## MeditationNodePresenter —— 打坐/洞府的「到达之后」接线。[br]
## [br][b]为什么不走 [NodeInteractionPopupHost][/b]：与采集/炼制同源——玩家到达洞府
## 要的是[b]一份可反复按的冲关面板[/b]（失败后修为还够就能再冲），不是「确认框 →
## 再点一次」。走独立通道与 [HarvestNodePresenter] / [CraftNodePresenter] 平级：
## 消费交互组件的 [code]node_interaction_forwarded[/code] 里的 [code]meditation[/code]，
## 其余类型原样放行给弹窗宿主。[br]
## [br][b]流程[/b]：交互组件转发 [code]node_interaction_forwarded(node_id, kind,
## payload)[/code] → 本类按载荷里的 [code]status[/code]（到达时由探索系统按境界配置
## 表现算）上架 [MeditationPanelScreen] → 玩家点「尝试突破」 →
## [code]ExplorationSystem.attempt_breakthrough[/code] 结算 → 重取状态 + 回填系统给的
## 中文文案 + 把同一条文案发到 HUD。[br]
## [br][b]为什么重取状态而不是就地改面板[/b]：修为、境界、上限都在 GSM 侧，且失败会
## 改变「还够不够冲」——就地改会和事实分叉。重取一次是常量开销，且顺带刷新了按钮
## 禁用态（ADR-0031 §2 零状态所有权）。[br]
## [br][b]提示取系统返回值[/b]：成功文案里的境界名与实际消耗、失败文案里的损失量都由
## Feature 层算好——UI 不自己拼一遍数字（否则两处措辞必然漂移）。[br]
## [br][b]面板不自行关闭[/b]：突破后留在面板上（可能连冲两关）——只有「离开」或取消键
## 关闭。这与商店/炼制面板同形态。[br]
## [br][b]节点图冻结[/b]：与商店/采集/炼制 overlay 同一套（舞台冻结 + 交互组件键盘路径
## 开关），在面板关闭时解冻。[br]
##
## 来源: design/gdd/cultivation-system.md §4/§6/§边界、ADR-0010 §realm_up 编排器、
## ADR-0031 §2、design/gdd/exploration-ui-system.md §4c（overlay 先例）、
## 先例 [code]craft_node_presenter.gd[/code] / [code]harvest_node_presenter.gd[/code]。

const MeditationPanelScript := preload("res://src/ui/exploration/meditation_panel_screen.gd")

## 提示类型（HUD 通知区域色档——green = 获得/正向，与商店/采集/炼制同档）。
const NOTIFY_TYPE: String = "green"
## 无通知出口时的留痕前缀（测试与 HUD 未挂载的降级路径）。
const WARN_NO_SINK: String = "MeditationNodePresenter: 无通知出口，提示未展示（%s）"

## 本 Presenter 认的交互类型（其余原样放行）。
const HANDLED_KIND: StringName = &"meditation"

## 探索系统（[code]attempt_breakthrough[/code] / [code]breakthrough_status[/code] 调用方）。
var _system: Node = null
## 面板挂载宿主（节点图屏幕）。
var _host: Control = null
## 提示出口 [code]func(type: String, text: String) -> int[/code]（可空）。
var _notify: Callable = Callable()
## 面板期间的节点图冻结 / 解冻（由宿主注入——通常接 [NodePopupStage]）。
var _freeze: Callable = Callable()
var _unfreeze: Callable = Callable()
## 是否已冻结（幂等守卫）。
var _frozen: bool = false

## 当前节点 ID（-1 = 无面板）。
var _node_id: int = -1
## 当前面板（未打开为 null）。
var _panel: Control = null
## 最近一次提示文案（测试断言用；未发过为空串）。
var _last_hint: String = ""


## 接线：连接交互组件的到达转发信号。[br]
## [br][param p_exploration_system] 探索系统（结算与状态查询的调用方）。[br]
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

## 突破面板是否打开。
func is_panel_open() -> bool:
	return _panel != null and is_instance_valid(_panel)


## 当前面板（未打开为 null——测试读它的渲染结果）。
func panel() -> Variant:
	return _panel if is_panel_open() else null


## 当前面板对应的节点 ID（未打开为 -1）。
func node_id() -> int:
	return _node_id if is_panel_open() else -1


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

## 交互组件到达转发——只认 [code]meditation[/code]
## （其余类型原样放行给弹窗宿主与其他 Presenter）。[br]
## [br][b]载荷契约[/b]：[code]payload.status[/code] 为到达时的突破状态（由探索系统
## 按境界配置表现算）——面板不自行查表算成功率（UI 零数值计算）。
func _on_node_interaction(p_node_id: int, p_interaction_type: StringName,
		p_payload: Dictionary = {}) -> void:
	if p_interaction_type != HANDLED_KIND:
		return
	if _host == null or not is_instance_valid(_host):
		return
	_node_id = p_node_id
	var status: Variant = p_payload.get("status", {})
	_open_panel(status if status is Dictionary else {})


## 构建并挂载突破面板（重复到达先清旧面板——同时只存在一个）。
func _open_panel(p_status: Dictionary) -> void:
	if is_panel_open():
		_panel.queue_free()
	_panel = MeditationPanelScript.new()
	_panel.name = "MeditationPanel"
	_host.add_child(_panel)
	_panel.connect(&"breakthrough_requested", _on_breakthrough_requested)
	_panel.connect(&"leave_requested", close_panel)
	_panel.call(&"present", p_status)
	_apply_freeze()


# ═══════════════════════════════════════════════════════════════════════════════
# 尝试突破 → 扣修为 / 升境界
# ═══════════════════════════════════════════════════════════════════════════════

## 玩家点了「尝试突破」——由 Feature 层结算（校验 → 掷骰 → 扣修为 → 升境界）。[br]
## [br][b]结算后重取状态[/b]：修为与境界都在 GSM 侧，就地改面板会和事实分叉；重取顺带
## 刷新「修为不足」的禁用态与失败后的新代价。[br]
## [br][b]提示取系统返回值[/b]：成败两种文案里都有实际数字（消耗/损失），UI 不自己算。
func _on_breakthrough_requested() -> void:
	if _system == null or not is_instance_valid(_system) or not is_panel_open():
		return
	if not _system.has_method(&"attempt_breakthrough"):
		push_warning("MeditationNodePresenter: 探索系统缺少 attempt_breakthrough()——突破未结算")
		return
	var result: Dictionary = _system.call(&"attempt_breakthrough")
	var message: String = str(result.get("message", ""))
	_refresh(message)
	if bool(result.get("success", false)):
		_emit_hint(message)


## 重取突破状态并刷新面板（结算后与重开时共用——单一刷新路径）。
func _refresh(p_message: String) -> void:
	if not is_panel_open():
		return
	var status: Dictionary = _status_from_system()
	if status.is_empty():
		# 系统缺失时不臆造数值——保留原面板，只把结果文案回填（可读的降级形态）。
		_panel.call(&"show_message", p_message)
		return
	_panel.call(&"present", status)
	if not p_message.strip_edges().is_empty():
		_panel.call(&"show_message", p_message)


## 系统侧的突破状态（[code]breakthrough_status[/code] 是「只读查询」的唯一入口）。[br]
## [br][b]系统缺失/无该方法[/b]：返回空字典——面板保留原状而非崩溃。
func _status_from_system() -> Dictionary:
	if _system == null or not is_instance_valid(_system):
		return {}
	if not _system.has_method(&"breakthrough_status"):
		return {}
	var raw: Variant = _system.call(&"breakthrough_status")
	return raw if raw is Dictionary else {}


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
	push_warning(WARN_NO_SINK % p_text)
