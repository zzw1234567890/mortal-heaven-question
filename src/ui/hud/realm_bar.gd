class_name RealmBar
extends Control
## RealmBar —— 境界+修为条组件（左上，hud Story 002）。
##
## [b]结构[/b]：境界名 Label + 修为进度条（ColorRect 底 + ColorRect 填充）+
## 「可突破！」提示 Label + 悬停 tooltip（数值 current/max）。[br]
## [br][b]Logic 内核[/b]：全部阈值/状态判定走 [CultivationBarState] 纯函数
## （ADR-0031——UI 节点只消费判定结果，禁止内联阈值 if-else）。[br]
## [br][b]信号订阅[/b]（G6 裁决）：[code]realm_changed[/code] /
## [code]cultivation_changed[/code] / [code]batch_updated[/code]（过滤
## [code]player.cultivation[/code] 与 [code]player.max_cultivation[/code] 路径，
## 另含 [code]player.is_fallen[/code] 前置接线——写入端归 realm-system 后续
## story）。刷新统一走幂等 [method _refresh]，忽略双发射重复触发。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不缓存游戏数值——每信号周期从 GSM
## player 域读取；[code]_last_*[/code] 前缀成员均为瞬态交互状态（§2.1 三分类，
## 见各成员注释）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——Tween 动画属输入驱动的纯视觉
## 变换豁免（ADR-0031 §3）。[br]
## [br][b]mouse_filter[/b]（G8 裁决）：父容器 RealmBarArea 为 IGNORE，本根节点
## 在 [method _ready] 显式设 [code]MOUSE_FILTER_STOP[/code] 使悬停事件送达。
##
## [br]来源: ADR-0031、design/gdd/hud-system.md §2、design/ux/hud.md「元素 1」、
## hud Story 002（2026-09-09 QL-STORY-READY 裁决）。

## === Visual 常量（数据驱动）===================================================

## 填充色映射（判定标识 → 美术圣经 §4.1 主色调色板）：
## blue=松石青 #4A9494（修为运转）/ purple=烟灰紫 #6E6878 /
## gold=琉璃金 #C8A84E（稀有/突破）。
const FILL_COLORS: Dictionary = {
	"blue": Color("#4A9494"),
	"purple": Color("#6E6878"),
	"gold": Color("#C8A84E"),
}

## 修为平滑填充时长——0.3s（GDD hud-system.md L254；G5 裁决：0.4s 的 UX 旧值废弃）。
const FILL_TWEEN_DURATION: float = 0.3
## 金色脉动呼吸全周期——1.0s（design/ux/hud.md L196）。
const PULSE_PERIOD: float = 1.0
## 落难占位闪烁全周期（真实破碎光效归打磨 story——见 [method _start_fallen_flicker]）。
const FALLEN_FLICKER_PERIOD: float = 0.8

## tooltip 前缀（design/ux/hud.md L187「修为 1800/2250」）。GDD 固定词条——
## 项目暂无本地化系统，本地化入库后替换为键（story 约束注记）。
const TOOLTIP_PREFIX: String = "修为 "
## 「可突破！」提示（GDD hud-system.md L66）。本地化注记同上。
const TEXT_BREAKTHROUGH: String = "可突破！"

## === 依赖注入 ==================================================================

## 注入的 GSM 引用——null 时回退 GameStateManager Autoload
## （先例：scene_manager.gd 依赖注入模式，测试可传 mock）。
var _gsm: Node = null
## realm_id → 境界名映射。[b]静态数据读取快照[/b]（story 裁决允许）：
## RealmSystem.realm_table 为编译时常量配置（非游戏状态），setup 时读一次
## 建立——不违反零状态所有权。
var _realm_names: Dictionary = {}

## === 瞬态交互状态（ADR-0031 §2.1——不进存档，刷新即弃）=========================

## 上次应用的修为比例——跳过重复信号触发的 Tween 重启（_refresh 幂等性：
## cultivation_changed 与 batch_updated 对同一变更双发射时无操作）。
var _last_ratio: float = -1.0
## 上次脉动激活状态（pulsing and show_bar 合成）——仅翻转时启停 Tween，
## 避免每信号重建循环动画。取合成值而非纯 pulsing：化神期满隐藏（pulsing=true
## 但 show_bar=false）→ 修为回落重显进度条时，纯 pulsing 不翻转会导致永无脉动
## （code-review HIGH-1 修复）。
var _last_pulsing: bool = false
## 上次落难闪烁激活状态（is_fallen and show_bar 合成）——语义同上（HIGH-1 对称修复）。
var _last_fallen: bool = false
## 平滑填充 Tween 句柄（新值到来时 kill 重建）。
var _fill_tween: Tween = null
## 金色脉动 Tween 句柄。
var _pulse_tween: Tween = null
## 落难占位闪烁 Tween 句柄。
var _fallen_tween: Tween = null

## === 节点引用 ==================================================================

@onready var realm_name_label: Label = $RealmNameLabel
@onready var bar_background: ColorRect = $BarBackground
@onready var bar_fill: ColorRect = $BarFill
@onready var breakthrough_hint_label: Label = $BreakthroughHint

## === 生命周期 ===================================================================

func _ready() -> void:
	# G8 裁决：RealmBarArea 容器为 IGNORE——根节点显式 STOP 使 tooltip 悬停可达。
	mouse_filter = MOUSE_FILTER_STOP
	setup()

func _exit_tree() -> void:
	_stop_pulse()
	_stop_fallen_flicker()
	if _fill_tween != null and _fill_tween.is_valid():
		_fill_tween.kill()

## 初始化信号订阅与首刷。[br]
## [param gsm]: 依赖注入的 GSM（测试 mock）；null 时回退 Autoload。[br]
## [param realm_table]: 境界属性表（测试注入）；空时从 RealmSystem Autoload 读取。
func setup(gsm: Node = null, realm_table: Dictionary = {}) -> void:
	if gsm != null:
		_gsm = gsm
	if not realm_table.is_empty():
		_build_realm_names(realm_table)
	elif _realm_names.is_empty():
		_build_realm_names(_default_realm_table())
	_connect_gsm_signals()
	_refresh()

## === 信号处理器（G6 裁决——统一走幂等 _refresh）===============================

func _on_realm_changed(_old_realm: int, _new_realm: int) -> void:
	_refresh()

func _on_cultivation_changed(_delta: int, _current: int, _max_val: int) -> void:
	_refresh()

func _on_batch_updated(changes: Dictionary) -> void:
	# 过滤 story 规定的两条路径 + is_fallen 前置接线（G1 写入端归后续 story，
	# 届时落难写入将经 batch_updated 广播——此处直接命中）+ player.realm
	# （code-review HIGH-3 补充：GSM 路由对同帧多变更只发 batch_updated 不发
	# realm_changed——realm 与其他路径同帧变更时唯一刷新入口是此过滤，须包含）。
	for path: String in ["player.realm", "player.cultivation", "player.max_cultivation", "player.is_fallen"]:
		if changes.has(path):
			_refresh()
			return

## === 刷新（幂等）===============================================================

## 从 GSM player 域读取现状 → 纯函数判定 → 应用视觉。每信号周期从源读取，
## 不持有游戏状态副本（ADR-0031 §2）。
func _refresh() -> void:
	var g: Node = _get_gsm()
	if g == null or not ("player" in g):
		push_warning("RealmBar._refresh: GSM 不可用——跳过本次刷新")
		return
	var player: Dictionary = g.player
	var realm_id: int = int(player.get("realm", 1))
	var current: int = int(player.get("cultivation", 0))
	var max_val: int = int(player.get("max_cultivation", 1))
	var is_fallen: bool = bool(player.get("is_fallen", false))
	var realm_name: String = str(_realm_names.get(realm_id, "未知境界"))

	var state: Dictionary = CultivationBarState.get_cultivation_bar_state(
			realm_id, realm_name, is_fallen, current, max_val)
	_apply_state(state, current, max_val, is_fallen)

## 应用纯函数判定结果到节点（color/pulsing/label/show_bar/breakthrough_hint）。
func _apply_state(state: Dictionary, current: int, max_val: int, is_fallen: bool) -> void:
	realm_name_label.text = state[&"label"]
	bar_fill.color = FILL_COLORS.get(state[&"color"], FILL_COLORS["blue"])
	tooltip_text = TOOLTIP_PREFIX + str(current) + "/" + str(max_val)
	if state[&"breakthrough_hint"]:
		breakthrough_hint_label.text = TEXT_BREAKTHROUGH
	breakthrough_hint_label.visible = state[&"breakthrough_hint"]

	var show_bar: bool = state[&"show_bar"]
	bar_background.visible = show_bar
	bar_fill.visible = show_bar

	var ratio: float = 0.0
	if max_val > 0:
		ratio = clampf(float(current) / float(max_val), 0.0, 1.0)
	_tween_fill(ratio, show_bar)
	# 翻转检测用 pulsing/fallen 与 show_bar 的合成值（成员注释——HIGH-1 修复）。
	var pulse_active: bool = state[&"pulsing"] and show_bar
	if pulse_active != _last_pulsing:
		_last_pulsing = pulse_active
		_stop_pulse()
		if pulse_active:
			_start_pulse()
	var fallen_active: bool = is_fallen and show_bar
	if fallen_active != _last_fallen:
		_last_fallen = fallen_active
		_stop_fallen_flicker()
		if fallen_active:
			_start_fallen_flicker()

## === 动画（Tween——输入驱动的纯视觉变换，零轮询豁免）===========================

## 修为平滑填充：0.3s Tween 过渡到新比例（非瞬跳）。[br]
## 首次刷新（_last_ratio < 0）直接落位——启动时不播放从 0 起的填充动画。
func _tween_fill(ratio: float, show_bar: bool) -> void:
	if ratio == _last_ratio:
		return  # 幂等：双发射重复触发时无操作
	var is_first: bool = _last_ratio < 0.0
	_last_ratio = ratio
	if _fill_tween != null and _fill_tween.is_valid():
		_fill_tween.kill()  # 先 kill 再判 show_bar——隐藏切换时残留 tween 一并清理
	if not show_bar:
		return  # 化神期满：进度条隐藏，无需动画
	var target_w: float = bar_background.size.x * ratio
	if is_first or not is_inside_tree():
		bar_fill.size.x = target_w
		return
	_fill_tween = create_tween()
	_fill_tween.tween_property(bar_fill, "size:x", target_w,
			FILL_TWEEN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## 金色脉动：1.0s 呼吸周期循环（透明度呼吸）。GDD AC-hud-002。
func _start_pulse() -> void:
	if not is_inside_tree():
		return
	bar_fill.modulate.a = 1.0
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(bar_fill, "modulate:a", 0.55,
			PULSE_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(bar_fill, "modulate:a", 1.0,
			PULSE_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	bar_fill.modulate.a = 1.0

## 落难破碎光效——[b]占位实现[/b]（story 裁定：本 story 仅 Visual 骨架，
## 以 modulate 闪烁近似「破碎感」；真实破碎特效（shader/粒子）归打磨 story）。
func _start_fallen_flicker() -> void:
	if not is_inside_tree():
		return
	bar_fill.modulate.a = 1.0
	_fallen_tween = create_tween().set_loops()
	_fallen_tween.tween_property(bar_fill, "modulate:a", 0.35,
			FALLEN_FLICKER_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_fallen_tween.tween_property(bar_fill, "modulate:a", 0.9,
			FALLEN_FLICKER_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _stop_fallen_flicker() -> void:
	if _fallen_tween != null and _fallen_tween.is_valid():
		_fallen_tween.kill()
	_fallen_tween = null
	if not _last_pulsing:
		bar_fill.modulate.a = 1.0

## === 内部辅助 ==================================================================

## 获取 GSM——注入对象优先，否则回退 Autoload（get_node 而非全局名，
## 保持脚本可脱离 Autoload 环境解析）。
func _get_gsm() -> Node:
	if _gsm != null:
		return _gsm
	return get_node_or_null("/root/GameStateManager")

## RealmSystem Autoload 的静态境界表（不可用时返回空表并以警告降级）。
func _default_realm_table() -> Dictionary:
	var rs: Node = get_node_or_null("/root/RealmSystem")
	if rs != null and "realm_table" in rs:
		return rs.realm_table
	push_warning("RealmBar: RealmSystem 不可用——realm_id 将显示为「未知境界」")
	return {}

## 从境界属性表构建 realm_id → 境界名映射（一次性静态数据读取）。
func _build_realm_names(realm_table: Dictionary) -> void:
	_realm_names.clear()
	for level: int in realm_table.keys():
		var entry: Dictionary = realm_table[level]
		_realm_names[level] = str(entry.get("name", "未知境界"))

## 防重复连接 GSM 三信号（G6 裁决订阅集）。
func _connect_gsm_signals() -> void:
	var g: Node = _get_gsm()
	if g == null:
		push_warning("RealmBar: GSM 不可用——跳过信号订阅（setup 可重入重试）")
		return
	_connect_once(g, &"realm_changed", _on_realm_changed)
	_connect_once(g, &"cultivation_changed", _on_cultivation_changed)
	_connect_once(g, &"batch_updated", _on_batch_updated)

func _connect_once(source: Node, signal_name: StringName, handler: Callable) -> void:
	if not source.has_signal(signal_name):
		push_warning("RealmBar: GSM 缺少 %s 信号——跳过订阅" % signal_name)
		return
	var s: Signal = source.get(signal_name)
	if not s.is_connected(handler):
		source.connect(signal_name, handler)
