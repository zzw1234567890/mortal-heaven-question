extends RefCounted
## MapClearPresenter —— 地图通关结算面板的「谁来弹、几时弹、确认之后」。[br]
## [br][b]为什么挂在探索薄容器而不是节点图[/b]：Boss 战胜利发生在[b]战斗结算场景[/b]，
## 结算与 [code]MapClearView[/code] 的发布都在转场[b]之前[/b]
## （[code]PlaceholderScene._on_return_pressed[/code]）；转场落地后探索场景挂的是
## [b]地图选择界面[/b]（节点图要玩家点卡片才挂）——面板若挂在节点图上，玩家打完 Boss
## 回到地图选择时它永远不会出现。挂在薄容器上，与既有的战斗奖励提示
## （[method ExplorationScene._flush_battle_reward_notice]）同层同时机。[br]
## [br][b]「回到地图选择」出口的实现[/b]（GDD §7 末条）：Boss 胜利的转场目的地
## 本就是探索场景 = 地图选择界面，面板是叠在它上面的一层。故「确认」= 收起这层
## overlay，露出并刷新底下的地图选择界面——[b]不是[/b]再发一次
## [code]back_to_map_select_requested[/code]：那条路径会触发第二次
## [code]end_exploration(PLAYER_QUIT)[/code]（导航已清空，只会多广播一次语义失真的
## 结束事件并打一条「无活跃地图」警告）。[br]
## [br][b]一次性[/b]：[method show_pending] 经 [code]MapClearView.take[/code] 取走即清
## ——反复进出地图不会重放上一局的通关结算。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不读 GSM、不算奖励、不写状态——
## 它只做「把已备好的载荷交给面板」与「确认后回调宿主刷新」。[br]
##
## 来源: design/gdd/exploration-ui-system.md §7 地图通关结算、
## design/gdd/exploration-system.md §5、ADR-0014 §决策 5、ADR-0031 §2、
## 先例 [code]exploration_scene.gd[/code] 的战斗奖励提示。

## 面板脚本与结算载荷（键名与 [method MapClearView.take] 同源）。
const PanelScript := preload("res://src/ui/exploration/map_clear_panel_screen.gd")
const ClearView := preload("res://src/feature/exploration/map_clear_view.gd")

## 面板挂载宿主（探索薄容器）。
var _host: Control = null
## 确认回调 [code]func() -> void[/code]（宿主刷新地图列表与余额）。
var _on_confirm: Callable = Callable()
## 当前面板（未打开为 null）。
var _panel: Control = null
## 本次展示的结算载荷（测试断言用；未展示过为空字典）。
var _view: Dictionary = {}
## 卡牌详情提供者 [code]func(entry: Dictionary) -> Dictionary[/code]（可空）。
var detail_provider: Callable = Callable()


## 接线——注入宿主与确认出口（可重复调用——幂等）。[br]
## [br][param p_host] 面板挂载宿主（需已进树：面板的 [code]_init[/code] 会建控件树）。[br]
## [param p_on_confirm] 确认回调（宿主据此刷新地图选择界面；可空）。[br]
## [br][b]宿主缺失不崩[/b]：本模块只在 [method show_pending] 时判一次，未接线时不弹。
func attach(p_host: Control, p_on_confirm: Callable = Callable()) -> void:
	_host = p_host
	_on_confirm = p_on_confirm


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 有待展示的结算就弹面板。[br]
## [br][b]返回[/b]：本次是否真的弹了（无待展示结算 / 宿主不可用 / 已在展示时为 false）。[br]
## [br][b]已在展示时不重复弹[/b]：面板是叠加层，重复弹会叠出两份「地图通关！」。
## [br][b]先 peek 后 take[/b]：宿主不可用时[b]不消费[/b]载荷——否则这份结算被白白
## 吃掉，下一次挂载就再也看不到了。
func show_pending() -> bool:
	if is_panel_open():
		return false
	if _host == null or not is_instance_valid(_host):
		return false
	if ClearView.peek().is_empty():
		return false
	_view = ClearView.take()
	_open_panel()
	return true


## 面板是否打开。
func is_panel_open() -> bool:
	return _panel != null and is_instance_valid(_panel)


## 当前面板（未打开为 null——测试读它的渲染结果）。
func panel() -> Variant:
	return _panel if is_panel_open() else null


## 本次展示的结算载荷（未展示过为空字典——测试断言用）。
func view() -> Dictionary:
	return _view.duplicate(true)


## 关闭面板（宿主强制关闭 / 确认之后）。
func close_panel() -> void:
	if is_panel_open():
		_panel.queue_free()
	_panel = null


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 构建并挂载面板（上架本次结算 + 接两个出口）。[br]
## [br][b]确认**先**回调再收面板[/b]：回调要刷新底下的地图选择界面，此时面板还在树上
## 不影响刷新（两者不共享任何状态）；反过来先收面板会让「面板已消失但界面还没刷新」
## 出现一帧空档。
func _open_panel() -> void:
	_panel = PanelScript.new()
	_host.add_child(_panel)
	_panel.set(&"detail_provider", detail_provider)
	_panel.connect(&"confirmed", _on_confirmed)
	_panel.call(&"present", _view)


## 确认出口——收起 overlay 并让宿主刷新地图选择界面（见类文档「回到地图选择」）。
func _on_confirmed() -> void:
	if _on_confirm.is_valid():
		_on_confirm.call()
	close_panel()
