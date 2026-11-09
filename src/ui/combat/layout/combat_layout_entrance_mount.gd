extends RefCounted
## CombatLayoutEntranceMount —— 进场过渡的时间线编排（combat_layout 拆分模块·过渡组）。
##
## [b]职责[/b]：持有一条一次性 Tween，把五区域按 UX Transitions 预算（≤2s 全可见）
## 滑入 / 淡入就位；[param p_reduce_motion] 为真时直接就位、不建 Tween（无障碍替代）。[br]
## [b]零轮询[/b]（ADR-0031 §3）：只用一次性 Tween，无 [code]_process()[/code]；
## 过渡进度是瞬态视觉状态（§2.1 豁免），本模块不持有任何游戏状态。
##
## [b]为什么单独成文件[/b]：[code]combat_layout.gd[/code] 拆分后仍超 300 行软上限，
## 过渡块（常量 + 编排 + 收尾）是四组挂载之外唯一可整体搬走的一块。
##
## 来源: combat-ui-layout Story 001 AC-6、design/ux/combat-ui.md §Transitions、
## DEBT-CUI-007-2（combat_layout 拆分）。

## 过渡时长（秒）——顶/底条 0.3s，敌/己方区 0.4s；延迟串行总时长 0.7s（UX ≤2s）。
const T_TOPBAR_SEC: float = 0.3
const T_ENEMY_SEC: float = 0.4
const T_ENEMY_DELAY_SEC: float = 0.1
const T_ALLY_SEC: float = 0.4
const T_ALLY_DELAY_SEC: float = 0.2
const T_BOTTOMBAR_SEC: float = 0.3
const T_BOTTOMBAR_DELAY_SEC: float = 0.3
## 滑入位移距离（px——瞬态视觉参数非布局值）。
const SLIDE_OFFSET_PX: float = 60.0

## 宿主布局根（Tween 挂在它上面——Tween 的创建者必须是场景树内节点）。
var _layout: Control = null
## 活跃的进场 Tween（[method kill] 后置空；供测试与重复进场复用）。
var tween: Tween = null


## 构造——传入宿主布局根。
func _init(p_layout: Control) -> void:
	_layout = p_layout


## 编排进场过渡。[br]
## [param p_reduce_motion] 为真时直接就位（无 Tween，无障碍「减少动态」路径）。
func play(topbar: Control, enemy_area: Control, ally_area: Control,
		bottombar: Control, p_reduce_motion: bool) -> void:
	var zones: Array = [topbar, enemy_area, ally_area, bottombar]
	kill()
	if p_reduce_motion:
		_reset_alpha(zones)
		return
	# 起始态：滑入类区域移出 + 淡入类区域透明
	topbar.position.y -= SLIDE_OFFSET_PX
	topbar.modulate.a = 0.0
	enemy_area.modulate.a = 0.0
	ally_area.modulate.a = 0.0
	bottombar.position.y += SLIDE_OFFSET_PX
	bottombar.modulate.a = 0.0
	tween = _layout.create_tween()
	tween.set_parallel(true)
	# 顶部条：上方滑入 0.3s（ease-out）
	tween.tween_property(topbar, "position:y",
			topbar.position.y + SLIDE_OFFSET_PX, T_TOPBAR_SEC) \
			.from(topbar.position.y - SLIDE_OFFSET_PX * 2.0) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(topbar, "modulate:a", 1.0, T_TOPBAR_SEC)
	# 敌方区 / 己方区：淡入 0.4s（延迟 0.1s / 0.2s）
	tween.tween_property(enemy_area, "modulate:a", 1.0, T_ENEMY_SEC) \
			.set_delay(T_ENEMY_DELAY_SEC)
	tween.tween_property(ally_area, "modulate:a", 1.0, T_ALLY_SEC) \
			.set_delay(T_ALLY_DELAY_SEC)
	# 底部条：下方滑入 0.3s 延迟 0.3s（ease-out）
	tween.tween_property(bottombar, "position:y",
			bottombar.position.y - SLIDE_OFFSET_PX, T_BOTTOMBAR_SEC) \
			.set_delay(T_BOTTOMBAR_DELAY_SEC) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(bottombar, "modulate:a", 1.0, T_BOTTOMBAR_SEC) \
			.set_delay(T_BOTTOMBAR_DELAY_SEC)


## 终止进行中的过渡（重复进场 / 退场——被 kill 的 Tween 不再回调任何属性）。
func kill() -> void:
	if tween != null and tween.is_valid():
		tween.kill()
	tween = null


## 过渡终态：区域内所有区域 alpha 归 1（位置由 Tween 的终值决定，此处不改）。
func _reset_alpha(zones: Array) -> void:
	for zone: Control in zones:
		if zone != null:
			zone.modulate.a = 1.0
