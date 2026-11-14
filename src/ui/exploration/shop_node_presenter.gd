class_name ShopNodePresenter
extends RefCounted
## ShopNodePresenter —— 商店/回复节点的「确认之后」接线。[br]
## [br][b]为什么在弹窗宿主之外[/b]：宿主按 GDD §4c 分发表只负责「弹哪个确认框」，
## 确认之后的动作分两类——商店是 [b]UI overlay[/b]（B9 裁决：不开新场景），
## 回复是[b]一句提示[/b]。这两件事都属于「面板编排」，塞进宿主会让它既管分发表
## 又管两个界面的生命周期；与 [EventNodePresenter] 同层的拆法一致。[br]
## [br][b]商店流程[/b]：[code]popup_host.shop_opened[/code]（玩家点了「进入商店」）
## → 上架 [ShopPanelScreen] → 玩家点商品 → [code]ExplorationShop.purchase[/code]
## （Feature 层扣费/入收藏）→ 面板回填系统给的文案并刷新余额与可负担态。[br]
## [br][b]回复流程[/b]：[code]popup_host.rest_used[/code]（玩家点了「休息」）——
## 回血量已由宿主经探索系统 API 结算完毕，本类只把系统返回值变成一句提示；
## 不再自己算一遍（UI 零数值计算）。[br]
## [br][b]灵泉流程[/b]：[code]popup_host.spring_used[/code]（玩家点了「使用灵泉」）
## ——行动力已由 [code]ExplorationSystem.use_action_spring[/code] 回复并夹到上限，
## 本类同样只把返回值变成一句提示（回复量 0 = 已满，走另一句文案）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本类不写任何玩法数据——扣费与入收藏
## 全在 [code]ExplorationShop[/code]，回血全在 [code]ExplorationSystem.rest_at_node[/code]。
## [br][br][b]提示出口[/b]：注入 [code]notify_cb[/code]（HUD 通知区域）；未注入时
## 只留 [method last_hint] 与 push_warning（headless 测试与 HUD 未挂载的降级路径）。
## [br][br][b]节点图冻结[/b]（GDD §4c「商店 overlay——节点图冻结」）：与确认弹窗
## 走同一套冻结（[code]NodePopupStage[/code] + 交互组件的键盘路径开关），在
## [code]popup_closed[/code] 时接管。[br]
## [b]为什么必须等弹窗关闭再冻结[/b]：确认派发的顺序是
## [code]shop_opened.emit()[/code] → [code]close_popup()[/code]（宿主
## [method NodeInteractionPopupHost._on_confirmed]）——弹窗的舞台解冻发生在后者。
## 若在 [code]shop_opened[/code] 里冻结，舞台保存到的「原值」已是「冻结中」，
## 关闭商店后节点图会永远解不开冻。[br]
## [b]为什么不用 [code]InputManager[/code] 的 MODAL 输入锁[/b]：锁栈在
## [code]InputManager._on_tree_changed[/code] 里被整体清空（引擎的
## [code]tree_changed[/code] 每帧至多一次，面板入树即触发）——同帧 push 的锁会被
## 立刻抹掉，商店开着时键盘仍能走位。冻结走的是普通字段，不受树变更影响。
##
## 来源: GDD exploration-system.md §4c/§8、exploration-ui-system.md §4c、
## ADR-0031 §2、B9 裁决（商店 = UI overlay）、先例
## [code]node_graph_interaction_mount.gd[/code] 的弹窗期间键盘冻结。

const ShopPanelScript := preload("res://src/ui/exploration/shop_panel_screen.gd")
## 商店结算（货架 + 购买——Feature 层，本类只调它的公开方法）。
const ShopScript := preload("res://src/feature/exploration/exploration_shop.gd")

## 回复点提示文案（空回复量走另一句——「回复 0 点」读起来像 bug）。
const TEXT_REST_HEALED: String = "歇脚处：全队回复 %d 点生命"
const TEXT_REST_FULL: String = "歇脚处：全队安然无恙"
## 灵泉提示文案（回复量为 0 时走「已满」——满行动力时不该显示「回复 0 点」）。
const TEXT_SPRING_RESTORED: String = "灵泉：回复 %d 点行动力"
const TEXT_SPRING_FULL: String = "灵泉：行动力已满"
## 提示类型（HUD 通知区域色档——green = 获得/正向）。
const NOTIFY_TYPE: String = "green"

## 探索系统（回复点 API 调用方；本类只读它的返回值）。
var _system: Node = null
## 弹窗宿主（商店/回复确认信号源）。
var _popup_host: Control = null
## 面板宿主（商店 overlay 的挂载点——通常是节点图屏幕）。
var _host: Control = null
## 提示出口 [code]func(type: String, text: String) -> int[/code]（可空）。
var _notify: Callable = Callable()
## 商店 overlay 期间的节点图冻结 / 解冻（由宿主注入——通常接 [NodePopupStage]）。[br]
## [b]缺省为空[/b]：宿主未提供时面板仍上架，只是节点图不冻结（headless 单测路径）。
var _freeze: Callable = Callable()
var _unfreeze: Callable = Callable()
## 是否已冻结（幂等守卫——重复 [method _on_shop_opened] 不重复冻结）。
var _frozen: bool = false

## 商店结算实例（每次打开按当前节点重置货架）。
var _shop: RefCounted = null
## 当前商店面板（未打开为 null）。
var _panel: Control = null
## 最近一次提示文案（测试断言用；未发过为空串）。
var _last_hint: String = ""


## 接线：连接弹窗宿主的商店/回复确认信号。[br]
## [br][param p_exploration_system] 探索系统（可空——回复提示仍会发，只是数值为 0）。[br]
## [param p_popup_host] 弹窗宿主（[code]shop_opened[/code] / [code]rest_used[/code] 信号源）。[br]
## [param p_host] 商店 overlay 的挂载宿主。[br]
## [param p_notify] 提示出口 [code]func(type, text)[/code]（可空）。[br]
## [param p_freeze] / [param p_unfreeze] 商店面板期间的节点图冻结/解冻（可空——
## 宿主通常传弹窗舞台的对应方法，见类文档「为什么必须等弹窗关闭再冻结」）。
func attach(p_exploration_system: Object, p_popup_host: Control, p_host: Control,
		p_notify: Callable = Callable(), p_freeze: Callable = Callable(),
		p_unfreeze: Callable = Callable()) -> void:
	_system = p_exploration_system as Node
	_popup_host = p_popup_host
	_host = p_host
	_notify = p_notify
	_freeze = p_freeze
	_unfreeze = p_unfreeze
	if _popup_host == null or not is_instance_valid(_popup_host):
		return
	var shop_handler := Callable(self, &"_on_shop_opened")
	if _popup_host.has_signal(&"shop_opened") \
			and not _popup_host.is_connected(&"shop_opened", shop_handler):
		_popup_host.connect(&"shop_opened", shop_handler)
	var rest_handler := Callable(self, &"_on_rest_used")
	if _popup_host.has_signal(&"rest_used") \
			and not _popup_host.is_connected(&"rest_used", rest_handler):
		_popup_host.connect(&"rest_used", rest_handler)
	var spring_handler := Callable(self, &"_on_spring_used")
	if _popup_host.has_signal(&"spring_used") \
			and not _popup_host.is_connected(&"spring_used", spring_handler):
		_popup_host.connect(&"spring_used", spring_handler)
	var closed_handler := Callable(self, &"_on_popup_closed")
	if _popup_host.has_signal(&"popup_closed") \
			and not _popup_host.is_connected(&"popup_closed", closed_handler):
		_popup_host.connect(&"popup_closed", closed_handler)


# ═══════════════════════════════════════════════════════════════════════════════
# 查询（测试/宿主）
# ═══════════════════════════════════════════════════════════════════════════════

## 商店 overlay 是否打开。
func is_panel_open() -> bool:
	return _panel != null and is_instance_valid(_panel)


## 当前商店面板（未打开为 null——测试读它的渲染结果）。
func panel() -> Variant:
	return _panel if is_panel_open() else null


## 商店结算实例（未打开过为 null）。
func shop() -> Variant:
	return _shop


## 最近一次提示文案（空串 = 没发过）。
func last_hint() -> String:
	return _last_hint


## 关闭商店 overlay（「离开」按钮 / 宿主强制关闭）。
func close_panel() -> void:
	if _shop != null:
		_shop.call(&"close")
	if is_panel_open():
		_panel.queue_free()
	_panel = null
	_release_freeze()


## 探索系统引用（测试/宿主查询用——未接线时为 null）。
func exploration_system() -> Node:
	return _system


## 商店面板期间节点图是否处于冻结态（测试断言用）。[br]
## [br][b]无冻结回调[/b]（宿主未注入）时为 false——面板上架但不冻结，如实报告。
func is_node_graph_frozen() -> bool:
	return _frozen


# ═══════════════════════════════════════════════════════════════════════════════
# 商店
# ═══════════════════════════════════════════════════════════════════════════════

## 商店确认——上架商店 overlay 并刷新余额/商品态。[br]
## [br][b]冻结延后到 [code]popup_closed[/code][/b]：此刻确认弹窗尚未关闭，
## 它的舞台解冻紧随本信号之后（见类文档「为什么必须等弹窗关闭再冻结」）。
func _on_shop_opened(p_node_id: int, p_inventory: Dictionary) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	if _shop == null:
		_shop = ShopScript.new()
	_shop.call(&"open", p_node_id, p_inventory)
	_open_panel()
	_refresh("点击商品即可购买。")


## 确认弹窗关闭——确认为商店时接管冻结（面板在场则冻，否则不冻）。[br]
## [br][b]不按弹窗种类过滤[/b]：商店面板是否在场才是「要不要冻结」的唯一依据——
## 取消路径（弹窗关闭但没进商店）时面板为 null，自然不会冻。[br]
## [br][b]为什么要重放冻结[/b]：弹窗的舞台与商店的舞台是两个实例，但交互组件的
## 键盘开关[b]只有一个[/b]——弹窗关闭时弹窗那侧的配对会把它打开。商店还在场就得
## 再关一次，故这里直接调 [method _apply_freeze]（该方法的守卫只看回调是否注入，
## 不看 [member _frozen]——正是「已冻但开关被弹窗打开」这一种情况要重放）。
func _on_popup_closed(_p_node_id: int, _p_kind: StringName) -> void:
	if not is_panel_open():
		return
	_apply_freeze()


## 构建并挂载商店面板（重复到达先清旧面板——同时只存在一个）。
func _open_panel() -> void:
	if is_panel_open():
		_panel.queue_free()
	_panel = ShopPanelScript.new()
	_panel.name = "ShopPanel"
	_host.add_child(_panel)
	_panel.connect(&"purchase_requested", _on_purchase_requested)
	_panel.connect(&"leave_requested", close_panel)


## 购买意图（面板点击）——结算在 Feature 层，本类只回填结果。
func _on_purchase_requested(p_index: int) -> void:
	if _shop == null or not is_panel_open():
		return
	var result: Dictionary = _shop.call(&"purchase", p_index)
	_refresh(str(result.get("message", "")))


## 刷新面板：余额 + 商品态（可负担/售罄）+ 结果文案。
func _refresh(p_message: String) -> void:
	if not is_panel_open() or _shop == null:
		return
	_panel.call(&"present", int(_shop.call(&"balance")), _shop.call(&"items"))
	_panel.call(&"show_message", p_message)


# ═══════════════════════════════════════════════════════════════════════════════
# 冻结（节点图在商店面板期间不吃输入——GDD §4c）
# ═══════════════════════════════════════════════════════════════════════════════

## 冻结节点图。[br]
## [br][b]不按 [member _frozen] 短路[/b]：该标志只回答「本类是冻结态」，不足以
## 回答「节点图现在是冻结态」——交互组件的键盘开关是弹窗与商店[b]共享[/b]的
## 一个开关，弹窗关闭时弹窗那侧会把它打开（见 [method _on_popup_closed]）。
## 舞台自身的 [method NodePopupStage.freeze] 幂等（不覆盖已保存的原值），
## 故重放只把键盘开关再关一次，代价为零。[br]
## [br][b]未注入回调[/b]（headless 单测 / 宿主未提供舞台）：静默跳过——面板自身的
## 全屏遮罩仍拦住鼠标，不把缺回调变成崩溃；[member _frozen] 如实保持 false。
func _apply_freeze() -> void:
	if not _freeze.is_valid():
		return
	_frozen = true
	_freeze.call()


## 解冻节点图（幂等——未冻结时不重复调用）。[br]
## [br][b]不依赖面板实例[/b]：面板被外部释放时仍要放出来（防节点图锁死）。
func _release_freeze() -> void:
	if not _frozen:
		return
	_frozen = false
	if _unfreeze.is_valid():
		_unfreeze.call()


# ═══════════════════════════════════════════════════════════════════════════════
# 回复点
# ═══════════════════════════════════════════════════════════════════════════════

## 回复点确认——提示系统结算出的回血量（宿主已调 API，本类不重算）。[br]
## [br][b]回血量 0[/b] 走「全队安然无恙」文案——「回复 0 点生命」读起来像故障。[br]
## [br][b]探索系统缺失[/b]（stub 降级）：宿主返回 0，同样走无恙文案，不臆造数值。
func _on_rest_used(_p_node_id: int, p_healed: int) -> void:
	_emit_hint(TEXT_REST_HEALED % p_healed if p_healed > 0 else TEXT_REST_FULL)


## 灵泉确认——提示系统结算出的行动力回复量（宿主已调 API，本类不重算）。[br]
## [br][b]回复量 0[/b] 走「行动力已满」文案（满行动力是常态——每次路过灵泉都会
## 撞上；「回复 0 点行动力」读起来像故障）。[br]
## [br][b]探索系统缺失[/b]（stub 降级）：宿主返回 0，同样走已满文案，不臆造数值。
func _on_spring_used(_p_node_id: int, p_restored: int) -> void:
	_emit_hint(TEXT_SPRING_RESTORED % p_restored if p_restored > 0 else TEXT_SPRING_FULL)


## 发一句提示——注入出口优先；未注入时只留痕（不把缺 UI 变成崩溃）。
func _emit_hint(p_text: String) -> void:
	_last_hint = p_text
	if _notify.is_valid():
		_notify.call(NOTIFY_TYPE, p_text)
		return
	push_warning("ShopNodePresenter: 无通知出口，提示未展示（%s）" % p_text)
