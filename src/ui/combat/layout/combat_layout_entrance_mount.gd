extends RefCounted
## CombatLayoutEntranceMount —— 进场过渡的时间线编排（combat_layout 拆分模块·过渡组）。
##
## [b]职责[/b]：持有一条一次性 Tween，把五区域按 UX Transitions 预算（≤2s 全可见）
## 滑入 / 淡入就位；[param p_reduce_motion] 为真时直接就位、不建 Tween（无障碍替代）。[br]
## [b]零轮询[/b]（ADR-0031 §3）：只用一次性 Tween，无 [code]_process()[/code]；
## 过渡进度是瞬态视觉状态（§2.1 豁免），本模块不持有任何游戏状态。
##
## [b]幂等（2026-11-27 修）[/b]：进场是「从基准位移出去再滑回基准」，位移量绝不能
## 累加到 [member Control.position] 上。[br]
## 修前 [method play] 直接做 [code]bottombar.position.y += SLIDE_OFFSET_PX[/code]，
## 只在 Tween 结束时减回来；一旦这 0.3s 延迟窗口里 Tween 被 [method kill]（重复进场、
## 部署面板打断、场景切换）、或者 [param p_reduce_motion] 路径（只复位 alpha），
## 底条就永久停在基准下方 60px —— 表现是「结束回合」按钮落到 1080 视口之外，
## 看着在屏幕上，点下去什么都不发生（信号链完好，只是命中点在屏幕外）。
## 现在基准 y 首次进场时记一次，之后每次进场都从基准重新推导，[method kill] 与就位路径
## 都会把位置复位到基准。
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
## 各区域未进场时的基准 y（首次进场时记录，之后只读——保证位移不累加）。
var _base_y: Dictionary = {}
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
	_capture_base(zones)
	if p_reduce_motion:
		_settle(zones)
		return
	# 起始态：滑入类区域落在「基准 ± 位移」处（不是累加），淡入类区域透明
	topbar.position.y = _base_of(topbar) - SLIDE_OFFSET_PX
	topbar.modulate.a = 0.0
	enemy_area.modulate.a = 0.0
	ally_area.modulate.a = 0.0
	bottombar.position.y = _base_of(bottombar) + SLIDE_OFFSET_PX
	bottombar.modulate.a = 0.0
	tween = _layout.create_tween()
	tween.set_parallel(true)
	# 顶部条：上方滑入 0.3s（ease-out）
	tween.tween_property(topbar, "position:y", _base_of(topbar), T_TOPBAR_SEC) \
			.from(_base_of(topbar) - SLIDE_OFFSET_PX * 2.0) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(topbar, "modulate:a", 1.0, T_TOPBAR_SEC)
	# 敌方区 / 己方区：淡入 0.4s（延迟 0.1s / 0.2s）
	tween.tween_property(enemy_area, "modulate:a", 1.0, T_ENEMY_SEC) \
			.set_delay(T_ENEMY_DELAY_SEC)
	tween.tween_property(ally_area, "modulate:a", 1.0, T_ALLY_SEC) \
			.set_delay(T_ALLY_DELAY_SEC)
	# 底部条：下方滑入 0.3s 延迟 0.3s（ease-out）
	tween.tween_property(bottombar, "position:y", _base_of(bottombar), T_BOTTOMBAR_SEC) \
			.set_delay(T_BOTTOMBAR_DELAY_SEC) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(bottombar, "modulate:a", 1.0, T_BOTTOMBAR_SEC) \
			.set_delay(T_BOTTOMBAR_DELAY_SEC)


## 终止进行中的过渡（重复进场 / 退场——被 kill 的 Tween 不再回调任何属性）。[br]
## 同时把已移位的区域拉回基准：半途被打断不能让底条停在视口之外。
func kill() -> void:
	if tween != null and tween.is_valid():
		tween.kill()
	tween = null
	for node: Control in _base_y.keys():
		if is_instance_valid(node):
			node.position.y = float(_base_y[node])


## 过渡终态：位置回到基准、区域内所有区域 alpha 归 1。
func _settle(zones: Array) -> void:
	for zone: Control in zones:
		if zone != null:
			zone.position.y = _base_of(zone)
			zone.modulate.a = 1.0


## 首次进场时记录各区域基准 y（之后只读，位移永不累加）。
func _capture_base(zones: Array) -> void:
	for zone: Control in zones:
		if zone != null and not _base_y.has(zone):
			_base_y[zone] = zone.position.y


## 取某区域的基准 y（未记录时回落到当前值——不该发生，防御性）。
func _base_of(zone: Control) -> float:
	return float(_base_y.get(zone, zone.position.y))
