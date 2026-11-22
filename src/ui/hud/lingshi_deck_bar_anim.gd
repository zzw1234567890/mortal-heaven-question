extends RefCounted
## LingshiDeckBarAnim —— 灵石/卡组计数组件的[b]动画编排[/b]（Tween 全归此处）。[br]
##
## [b]职责[/b]：三类动画的唯一实现——灵石数字滚动（0.3s 插值）、灵石 (±xx) 浮动
## 标签（下浮 0.8s 淡出）、卡组超限红色闪烁（0.8s 循环）；以及 [member animate]
## 关掉时的静态降级（滚动直接落位、浮动不播、超限以半透明静态红呈现）。[br]
## [br][b]不管什么[/b]：不管「该不该播」（幂等守卫与三态判定在门面
## [code]lingshi_deck_bar.gd[/code]），不读游戏状态（只收门面算好的数值），
## 不持有任何游戏数据。[br]
## [br][b]为什么单独一处[/b]：动画是纯视觉变换——每个 Tween 句柄、插值中间值、
## 归位基准都是「时序」的事；门面管的是「什么时候刷、刷成什么」。两者混在一文件时
## 刷新逻辑被埋在两百行 Tween 例外处理里，且文件超 400 行（编码标准 300 行软上限）。[br]
## [br][b]宿主以弱类型持有[/b]（[Object] + [method Object.get] / [method Object.call]）：
## 本件需要宿主的 [member animate]、[code]create_tween()[/code]、[code]is_inside_tree()[/code]，
## 但不反向声明宿主类型（门面 preload 本件，声明类型即成环）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——Tween 属输入驱动的纯视觉变换
## （ADR-0031 §3 豁免）。[br]
## [br][b]reduce-motion[/b]：[code]animate=false[/code] 时三类动画全部静态降级
## （TD-008 接线点，见技术债登记表）。
##
## 来源: design/gdd/hud-system.md §3/§调优参数表、ADR-0031 §2/§3、hud Story 003、
## 拆分自 lingshi_deck_bar.gd（行数预算）。

## 显示词表（颜色/时长/图标——本件与门面共用一份）。
const Style := preload("res://src/ui/hud/lingshi_deck_bar_style.gd")

## 宿主节点（门面——读 [member animate]、建 Tween、问是否在树上）。
var _host: Object = null
## 灵石计数 Label（滚动动画的写出目标）。
var _lingshi_label: Label = null
## 灵石 delta 浮动 Label。
var _delta_label: Label = null
## 卡组计数 Label（超限闪烁的写出目标）。
var _deck_label: Label = null

## 灵石数字滚动 Tween 句柄（新值到来时 kill 重建）。
var _roll_tween: Tween = null
## 灵石 delta 浮动 Tween 句柄（含浮动 Label 本体的显隐编排）。
var _delta_tween: Tween = null
## 卡组超限闪烁 Tween 句柄。
var _overlimit_tween: Tween = null
## 灵石滚动动画当前插值值（Tween method 绑定的可变捕获——
## _exit_tree 后 Tween 回调不再触达节点）。
var _roll_display: int = 0
## delta 浮动标签归位基准 Y——建件时缓存的初始位置（B-3 修复：每次浮动
## 从归位基准起算向下浮，动画结束复位，杜绝 18px 漂移累积）。
var _delta_home_y: float = 0.0
## delta 标签 LabelSettings 是否已 duplicate 为独立实例（B-1 同源——
## 首次直写前 duplicate，防跨场景实例共享污染）。
var _delta_settings_owned: bool = false


## 建件——绑定宿主与三个 Label（门面在 [method Node._ready] 里建）。[br]
## [br][param p_host] 门面节点（提供 animate / create_tween / is_inside_tree）。[br]
## [param p_lingshi] 灵石计数 Label。[br]
## [param p_delta] delta 浮动 Label。[br]
## [param p_deck] 卡组计数 Label。
func _init(p_host: Object, p_lingshi: Label, p_delta: Label, p_deck: Label) -> void:
	_host = p_host
	_lingshi_label = p_lingshi
	_delta_label = p_delta
	_deck_label = p_deck
	# B-3 修复：缓存 delta 标签归位基准——每次浮动从基准起算，结束复位。
	if _delta_label != null:
		_delta_home_y = _delta_label.position.y


## === 灵石数字 =================================================================

## 灵石文本直接落位终值（无动画路径——首刷 / delta==0 / 不在树上 / 动画关闭）。
func set_text_immediate(lingshi: int) -> void:
	_lingshi_label.text = _lingshi_text(lingshi)


## 滚动动画路径——从屏上当前值插值到新值（AC-007）。[br]
## [br][param p_target] 新余额。[br]
## [param p_old_val] 上一次的目标值（无进行中 Tween 时的起点）。[br]
## [param p_delta] 变更量（非 0 时同步播 delta 浮动——0 表示仅卡组刷新路径）。[br]
## [br][b]中断起点用屏上实际插值值[/b]（S-2 修复）：连续变更时上一滚动尚未播完，
## 从目标值起算会瞬跳。[br]
## [br][b]终值先写[/b]（S-1 修复）：保证异常路径下数据终态正确；起点值紧随其后
## 供渲染层显示（同帧内无渲染点，顺序无视觉差异）。
func roll_to(p_target: int, p_old_val: int, p_delta: int) -> void:
	var start_val: int = p_old_val
	if _roll_tween != null and _roll_tween.is_valid():
		start_val = _roll_display
	_roll_display = start_val
	if _roll_tween != null and _roll_tween.is_valid():
		_roll_tween.kill()
	_roll_tween = _new_tween()
	_roll_tween.tween_method(_on_roll_tick.bind(start_val, p_target),
			0.0, 1.0, Style.LINGSHI_ROLL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	set_text_immediate(p_target)
	_on_roll_tick(0.0, start_val, p_target)
	if p_delta != 0:
		show_delta(p_delta)


## Tween 滚动插值回调——按进度重格式化显示值。
func _on_roll_tick(progress: float, from_val: int, to_val: int) -> void:
	_roll_display = int(round(lerpf(float(from_val), float(to_val), progress)))
	_lingshi_label.text = _lingshi_text(_roll_display)


## 灵石 (±xx) 浮动标签：向下浮 0.8s 并淡出（2026-09-10 用户裁决：
## 顶行向上浮 18px 会顶出 HUD 顶边距 12px——改为向下浮；方向区分仅靠
## +/- 前缀；AC-004 手动验证项）。[br]
## [br][b]动画关闭时整体跳过[/b]（H-2 修复）：测试注入 / reduce-motion 下不播浮动
## （主文本落位由调用侧处理）。
func show_delta(delta: int) -> void:
	if not _animate():
		return
	# B-2 修复：tscn 默认 visible=false，必须显式置可见（此前只设 text 与
	# modulate.a，浮动标签永不显示）。
	_delta_label.visible = true
	_delta_label.text = ("%+d" % delta) if delta > 0 else str(delta)
	# 负值红色——支出警示（COLOR_DELTA_NEGATIVE；正值复位墨色——
	# 共享 LabelSettings 上一轮负值直写残留）。B-1 同源：DeltaLabel
	# 与计数器共享 tscn SubResource，须 duplicate 独立实例后直写（首次），
	# 后续轮次已是独立实例直写即可。
	var color: Color = Style.COLOR_DELTA_NEGATIVE if delta < 0 else Style.COLOR_DELTA_POSITIVE
	if _delta_label.label_settings != null:
		if not _delta_settings_owned:
			_delta_label.label_settings = _delta_label.label_settings.duplicate()
			_delta_settings_owned = true
		_delta_label.label_settings.font_color = color
	else:
		_delta_label.add_theme_color_override("font_color", color)
	_delta_label.modulate.a = 1.0
	# B-3 修复：先复位到归位基准再起浮——连续变更时上一浮动可能尚未播完，
	# 从漂移位置起算会累积偏移。
	_delta_label.position.y = _delta_home_y
	if _delta_tween != null and _delta_tween.is_valid():
		_delta_tween.kill()
	_delta_tween = _new_tween()
	_delta_tween.set_parallel(true)
	_delta_tween.tween_property(_delta_label, "modulate:a", 0.0,
			Style.DELTA_FLOAT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# B-3：目标 = 归位基准 + 18px（向下浮——2026-09-10 用户裁决）。
	_delta_tween.tween_property(_delta_label, "position:y",
			_delta_home_y + Style.DELTA_FLOAT_DISTANCE,
			Style.DELTA_FLOAT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_delta_tween.chain().tween_callback(_reset_delta_label)


## 浮动结束：隐藏 + 复位到归位基准 Y（B-2/B-3 修复）。
func _reset_delta_label() -> void:
	_delta_label.modulate.a = 0.0
	_delta_label.visible = false
	_delta_label.position.y = _delta_home_y


## === 超限闪烁 =================================================================

## 卡组超限红色闪烁：0.8s 周期循环（透明度闪烁）。持续到玩家处理超限弃牌
## （deck-editing-ui epic）——本件不负责停止条件以外的清理。[br]
## [br][b]reduce-motion 静态降级[/b]（H-2 修复）：动画关闭时不建循环 Tween，
## 超限态以半透明静态红呈现（TD-008 接线点声明兑现）。
func start_overlimit_flicker() -> void:
	if not _in_tree():
		return
	if not _animate():
		_deck_label.modulate.a = Style.OVERLIMIT_STATIC_ALPHA
		return
	_deck_label.modulate.a = 1.0
	_overlimit_tween = _new_tween().set_loops()
	_overlimit_tween.tween_property(_deck_label, "modulate:a", Style.OVERLIMIT_FLICKER_LOW_ALPHA,
			Style.OVERLIMIT_FLICKER_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_overlimit_tween.tween_property(_deck_label, "modulate:a", 1.0,
			Style.OVERLIMIT_FLICKER_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## 停止闪烁并复位透明度。[br]
## [br][b]不触碰翻转状态[/b]（H-1 修复）：翻转检测归门面（先例 realm_bar.gd
## _stop_pulse 不触碰翻转检测状态）——此前重置为 false 使超限期间每次刷新误判
## 翻转、kill/重建闪烁 Tween。
func stop_overlimit_flicker() -> void:
	if _overlimit_tween != null and _overlimit_tween.is_valid():
		_overlimit_tween.kill()
	_overlimit_tween = null
	_deck_label.modulate.a = 1.0


## 当前闪烁 Tween 句柄（门面转发给既有引用点——测试探针）。
func overlimit_tween() -> Tween:
	return _overlimit_tween


## === 生命周期 =================================================================

## 出树清理：停闪烁 + kill 滚动/浮动 Tween（门面 [method Node._exit_tree] 调）。
func kill_all() -> void:
	stop_overlimit_flicker()
	for t: Tween in [_roll_tween, _delta_tween]:
		if t != null and t.is_valid():
			t.kill()
	_roll_tween = null
	_delta_tween = null


## === 内部辅助 =================================================================

## 灵石行显示文本（图标 + k 格式数额——格式化走 LingshiFormatter 纯函数）。
func _lingshi_text(value: int) -> String:
	return Style.ICON_LINGSHI + Style.ICON_SEPARATOR + LingshiFormatter.format_lingshi(value)


## 动画开关（门面成员——测试注入 / 未来 reduce-motion 设置接线点）。
func _animate() -> bool:
	return _host != null and bool(_host.get(&"animate"))


## 宿主是否在场景树上（Tween 归属前置条件）。
func _in_tree() -> bool:
	return _host != null and bool(_host.call(&"is_inside_tree"))


## 宿主上的新 Tween（Tween 生命周期随节点——不自己 new）。
func _new_tween() -> Tween:
	return _host.call(&"create_tween") as Tween
