extends RefCounted
## MapSelectAnimator —— 地图卡片入场动画编排（从 MapSelectScreen 拆出）。[br]
## [br][b]为什么单独一处[/b]：屏幕脚本已超 300 行软上限，而「卡片怎么飞进来」与
## 「列表怎么取、点击怎么分流」是两件事（同 [code]map_select_data.gd[/code]、
## [code]shop_panel_navigator.gd[/code] 拆分先例）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只做视觉插值，不读不写任何玩法数据
## ——卡片条目由调用方传入，本模块不持有列表。[br]
## [br][b]锁定卡遮罩不变量[/b]：锁定卡的飞入目标 alpha 保持
## [constant MapCard.LOCKED_ALPHA]，且用非过冲缓动（TRANS_QUAD——TRANS_BACK
## 会过冲短暂超过 0.45，破坏遮罩不变量，S16-2 code-review Required #2）。[br]
## [br][b]减少动态偏好[/b]：调用方（屏幕）的 [code]animate=false[/code] 时压根
## 不调本模块——测试与 reduce-motion 路径直接终态呈现（零轮询，Tween 完成即停）。[br]
##
## 来源: exploration-ui Story S16-2 B7 裁决、ADR-0031 §2/§3、
## design/gdd/exploration-ui-system.md §1。

## MapCard 脚本常量——锁定态 alpha 与控件类型（class_name 动态加载下不可靠）。
const MapCardScript := preload("res://src/ui/exploration/map_card.gd")

## 卡片入场逐张飞入时长（秒）——0.3s/张（B7 裁决）。
const CARD_ANIM_DURATION: float = 0.3
## 每张卡片飞入错峰间隔（秒）。
const CARD_ANIM_STAGGER: float = 0.08

## 当前 Tween 句柄（新请求时 kill 防悬挂）。
var _tween: Tween = null


## 播放逐张飞入动画（0.3s/张 + 0.08s 错峰）。[br]
## [br][param p_host] 宿主 Control（Tween 的创建者——必须在树内）。[br]
## [param p_card_row] 卡片行容器（按其子节点顺序错峰）。[br]
## [param p_should_lock] 判定某条卡片是否锁定的回调
## [code]func(entry: Dictionary) -> bool[/code]（锁定态走非过冲缓动）。[br]
## [br][b]未进树时静默跳过[/b]：headless 单测里宿主可能未入树，create_tween 会失败。[br]
func play_intro(p_host: Control, p_card_row: Container,
		p_should_lock: Callable) -> void:
	if p_host == null or not p_host.is_inside_tree() or p_card_row == null:
		return
	kill()
	_tween = p_host.create_tween()
	_tween.set_parallel(true)
	for i: int in range(p_card_row.get_child_count()):
		var card: Panel = p_card_row.get_child(i) as Panel
		if card == null:
			continue
		var locked: bool = p_should_lock.is_valid() and bool(p_should_lock.call(card.get(&"entry")))
		var target_alpha: float = MapCardScript.LOCKED_ALPHA if locked else 1.0
		var transition: Tween.TransitionType = Tween.TRANS_QUAD if locked \
				else Tween.TRANS_BACK
		card.modulate.a = 0.0
		_tween.tween_property(card, "modulate:a", target_alpha, CARD_ANIM_DURATION) \
				.set_delay(i * CARD_ANIM_STAGGER) \
				.set_trans(transition).set_ease(Tween.EASE_OUT)


## 终止进行中的动画（幂等——重复调用 / 宿主退树时）。
func kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
