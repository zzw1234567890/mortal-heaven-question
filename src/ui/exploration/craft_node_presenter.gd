class_name CraftNodePresenter
extends RefCounted
## CraftNodePresenter —— 炼丹台 / 炼器台的「到达之后」接线。[br]
## [br][b]为什么不走 [NodeInteractionPopupHost][/b]：炼丹/炼器的交互形态与采集同源
## ——玩家到达后要的是[b]一份配方清单[/b]（点一下就炼），不是「确认框 → 再点一次」。
## 走独立通道与 [HarvestNodePresenter] 平级：消费交互组件的
## [code]node_interaction_forwarded[/code] 里的 [code]alchemy[/code] /
## [code]forge[/code]，其余类型原样放行给弹窗宿主。[br]
## [br][b]两个台子共用一个 Presenter[/b]：交互形态一致，差别只在面板标题与配方来源
## （[code]kind[/code]）——不复制第二份接线。[br]
## [br][b]流程[/b]：交互组件转发 [code]node_interaction_forwarded(node_id, kind,
## payload)[/code] → 本类按载荷里的 [code]entries[/code]（可炼清单，到达时由探索
## 系统从配方资源现算）上架 [CraftPanelScreen] → 玩家点配方 →
## [code]ExplorationSystem.craft_at_node[/code] 结算 → 面板重取清单 + 回填系统
## 给的文案。[br]
## [br][b]为什么重新取清单而不是就地改状态[/b]：材料持有量与「收藏已满」都在系统侧
## ——面板就地改会和 GSM 里的事实分叉。重取一次是 O(配方条数) 且顺带刷新了禁用态
## （ADR-0031 §2 零状态所有权）。[br]
## [br][b]节点图冻结[/b]：与商店/采集 overlay 同一套（舞台冻结 + 交互组件键盘路径
## 开关），在面板关闭时解冻。[br]
##
## 来源: design/gdd/alchemy-crafting-system.md §1a/§2a/§4 炼制位置/§边界/AC-1、
## design/gdd/exploration-ui-system.md §4c（overlay 先例）、ADR-0028 §craft_pill、
## ADR-0031 §2、先例 [code]harvest_node_presenter.gd[/code]。

const CraftPanelScript := preload("res://src/ui/exploration/craft_panel_screen.gd")

## 提示类型（HUD 通知区域色档——green = 获得/正向，与商店/采集同档）。
const NOTIFY_TYPE: String = "green"
## 无通知出口时的留痕前缀（测试与 HUD 未挂载的降级路径）。
const WARN_NO_SINK: String = "CraftNodePresenter: 无通知出口，提示未展示（%s）"

## 配方行数上限（防配方表异常导致的无限重试——不静默截断，仅守卫）。
const MAX_ROWS: int = 64

## 本 Presenter 认的交互类型（其余原样放行）。
const HANDLED_KINDS: Array = [&"alchemy", &"forge"]

## 探索系统（[code]craft_at_node[/code] / [code]craft_entries[/code] 调用方）。
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

## 当前节点 ID（-1 = 无面板）与配方种类。
var _node_id: int = -1
var _kind: StringName = &""
## 当前面板（未打开为 null）。
var _panel: Control = null
## 最近一次提示文案（测试断言用；未发过为空串）。
var _last_hint: String = ""


## 接线：连接交互组件的到达转发信号。[br]
## [br][param p_exploration_system] 探索系统（结算与清单的调用方）。[br]
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

## 炼制面板是否打开。
func is_panel_open() -> bool:
	return _panel != null and is_instance_valid(_panel)


## 当前面板（未打开为 null——测试读它的渲染结果）。
func panel() -> Variant:
	return _panel if is_panel_open() else null


## 当前面板对应的配方种类（未打开为空串）。
func kind() -> StringName:
	return _kind if is_panel_open() else &""


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
	_kind = &""
	_release_freeze()


# ═══════════════════════════════════════════════════════════════════════════════
# 到达消费
# ═══════════════════════════════════════════════════════════════════════════════

## 交互组件到达转发——只认 [code]alchemy[/code] / [code]forge[/code]
## （其余类型原样放行给弹窗宿主与其他 Presenter）。[br]
## [br][b]载荷契约[/b]：[code]payload.entries[/code] 为可炼清单（到达时由探索系统
## 从配方资源现算）——面板不自行拼装配方表（UI 零数值计算）。
func _on_node_interaction(p_node_id: int, p_interaction_type: StringName,
		p_payload: Dictionary = {}) -> void:
	if not HANDLED_KINDS.has(p_interaction_type):
		return
	if _host == null or not is_instance_valid(_host):
		return
	_node_id = p_node_id
	_kind = p_interaction_type
	_open_panel(p_payload.get("entries", []))


## 构建并挂载炼制面板（重复到达先清旧面板——同时只存在一个）。
func _open_panel(p_entries: Array) -> void:
	if is_panel_open():
		_panel.queue_free()
	_panel = CraftPanelScript.new()
	_panel.name = "CraftPanel"
	_host.add_child(_panel)
	_panel.connect(&"craft_requested", _on_craft_requested)
	_panel.connect(&"leave_requested", close_panel)
	_panel.call(&"present", _kind, _balance(), _entries_of(p_entries))
	_apply_freeze()


# ═══════════════════════════════════════════════════════════════════════════════
# 炼制 → 扣料入库
# ═══════════════════════════════════════════════════════════════════════════════

## 玩家点了某道配方——由 Feature 层结算（校验 → 扣料 → 建实例 → 入收藏）。[br]
## [br][b]结算后重取清单[/b]：材料持有量与收藏余量都在系统侧，就地改面板状态会和
## GSM 分叉；重取顺带刷新「灵材不足 / 收藏已满」的禁用态。[br]
## [br][b]提示取系统返回值[/b]：成功文案里含实际产出的稀有度——UI 不自己算一遍。
func _on_craft_requested(p_index: int) -> void:
	if _system == null or not is_instance_valid(_system) or not is_panel_open():
		return
	if not _system.has_method(&"craft_at_node"):
		push_warning("CraftNodePresenter: 探索系统缺少 craft_at_node()——炼制未结算")
		return
	var kind: StringName = _kind
	var result: Dictionary = _system.call(&"craft_at_node", kind, p_index)
	_refresh(kind, str(result.get("message", "")))
	if bool(result.get("success", false)):
		_emit_hint(str(result.get("message", "")))


## 重取可炼清单并刷新面板（结算后与重开时共用——单一刷新路径）。
func _refresh(p_kind: StringName, p_message: String) -> void:
	if not is_panel_open():
		return
	_panel.call(&"present", p_kind, _balance(),
			_entries_of(_entries_from_system(p_kind)))
	if not p_message.strip_edges().is_empty():
		_panel.call(&"show_message", p_message)


## 系统侧的可炼清单（[code]craft_entries[/code] 是「只读查询」的唯一入口）。[br]
## [br][b]系统缺失/无该方法[/b]：返回空数组——面板显示「无方可炼」而非崩溃。
func _entries_from_system(p_kind: StringName) -> Array:
	if _system == null or not is_instance_valid(_system):
		return []
	if not _system.has_method(&"craft_entries"):
		return []
	var raw: Variant = _system.call(&"craft_entries", p_kind)
	return raw if raw is Array else []


## 载荷/重取结果的规范化——只保留字典条目，并夹到 [constant MAX_ROWS] 条。[br]
## [br][b]越界即截断并告警[/b]：配方表异常时宁可少显示也不静默丢弃（不 silent cap）。
func _entries_of(p_entries: Variant) -> Array:
	var out: Array = []
	if not (p_entries is Array):
		return out
	for raw: Variant in p_entries:
		if raw is Dictionary:
			out.append(raw)
		if out.size() >= MAX_ROWS:
			push_warning("CraftNodePresenter: 配方条目超过 %d 条，已截断" % MAX_ROWS)
			break
	return out


## 各品质档位的灵材持有量（面板顶部摘要——只读系统 API，UI 不自己查 ResourceSystem）。[br]
## [br][b]系统缺失[/b]：返回空字典——面板显示全 0 而非崩溃（不臆造数值）。
func _balance() -> Dictionary:
	if _system == null or not is_instance_valid(_system):
		return {}
	if not _system.has_method(&"craft_balance"):
		return {}
	var raw: Variant = _system.call(&"craft_balance")
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
