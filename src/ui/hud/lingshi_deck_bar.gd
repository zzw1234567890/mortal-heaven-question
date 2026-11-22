class_name LingshiDeckBar
extends Control
## LingshiDeckBar —— 灵石+卡组计数组件（右上，hud Story 003）。[br]
##
## [b]结构[/b]：灵石行 Label（🪙 占位图标 + k 格式数额）+ 灵石浮动 delta Label
## （(+xx/-xx) 跳动动画）+ 卡组行 Label（📜 占位图标 + count/cap）+ 超限标记
## Label（「超限！」，仅超限时显示）。[br]
## [br][b]职责[/b]：本文件是门面——生命周期、GSM 信号订阅与幂等刷新编排、卡组三态。
## 显示词表（颜色/时长/图标/路径）在 [LingshiDeckBarStyle]，三类动画（滚动/浮动/
## 闪烁）在 [LingshiDeckBarAnim]；两者均以同名常量与同名方法在此转发，
## 既有引用点（[code]bar.animate[/code] / [code]bar._overlimit_tween[/code] 等）口径不变。[br]
## [br][b]Logic 内核[/b]：全部格式化/阈值判定走 [LingshiFormatter] 纯函数
## （ADR-0031——UI 节点只消费判定结果，禁止内联阈值 if-else）。[br]
## [br][b]信号订阅[/b]（G1 裁决 2026-09-10 双订阅）：[code]resource_changed[/code]
## （过滤灵石类型——单变更时发射）[b]及[/b] [code]batch_updated[/code]（滤
## [code]player.resources.ling_shi[/code] 精确路径键——同帧多变更时域信号不发射，
## batch_updated 为唯一入口；另滤 [code]deck.current_deck[/code] 精确路径键——卡组
## 变更唯一刷新入口，[code]deck_modified[/code] 信号当前全库无发射方不作为依赖）。
## 刷新统一走幂等 [method _refresh]，忽略双发射重复触发。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不缓存游戏数值——每信号周期从 GSM
## player 域 / DeckEditingSystem API 读取；[code]_last_*[/code] 前缀成员均为
## 瞬态交互状态（§2.1 三分类，见各成员注释）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——Tween 动画属输入驱动的纯视觉
## 变换豁免（ADR-0031 §3）。[br]
## [br][b]mouse_filter[/b]（G8 裁决先例）：父容器 LingshiDeckArea 为 IGNORE——
## 本组件纯显示无悬停交互，子 Label 全部 IGNORE 透传，不拦截下层点击。[br]
## [br][b]可见性边界[/b]（story 裁决）：本组件不处理场景可见性——ContentLayer
## 整体显隐归 hud.gd 可见性矩阵（战斗隐藏由矩阵覆盖；卡组计数「探索/商店可见」
## 与 HUD 可见场景集一致，无需单独场景判断——与 Story 001 边界一致）。
##
## [br]来源: ADR-0031、design/gdd/hud-system.md §3、design/ux/hud.md「元素 2/3」、
## hud Story 003（2026-09-10 QL-STORY-READY G1-G4 裁决）。

## 显示词表与动画模块（门面持有二者，转发外部引用的常量与动画入口）。
const Style := preload("res://src/ui/hud/lingshi_deck_bar_style.gd")
const Anim := preload("res://src/ui/hud/lingshi_deck_bar_anim.gd")

## === 显示常量（唯一出处在 [LingshiDeckBarStyle]——此处同名转发）===============

const COUNT_COLORS: Dictionary = Style.COUNT_COLORS
const COLOR_OVERLIMIT: Color = Style.COLOR_OVERLIMIT
const COLOR_DELTA_NEGATIVE: Color = Style.COLOR_DELTA_NEGATIVE
const LINGSHI_ROLL_DURATION: float = Style.LINGSHI_ROLL_DURATION
const DELTA_FLOAT_DURATION: float = Style.DELTA_FLOAT_DURATION
const OVERLIMIT_FLICKER_PERIOD: float = Style.OVERLIMIT_FLICKER_PERIOD
const PATH_LING_SHI: String = Style.PATH_LING_SHI
const PATH_DECK: String = Style.PATH_DECK
const RES_TYPE_LING_SHI: StringName = Style.RES_TYPE_LING_SHI
const ICON_LINGSHI: String = Style.ICON_LINGSHI
const ICON_DECK: String = Style.ICON_DECK
const SIGN_PLUS: String = Style.SIGN_PLUS

## === 依赖注入 ==================================================================

## 注入的 GSM 引用——null 时回退 GameStateManager Autoload
## （先例：realm_bar.gd 依赖注入模式，测试可传 mock）。
var _gsm: Node = null
## 注入的 DeckEditingSystem 引用——null 时回退 Autoload
## （测试传 mock：仅需 get_deck_summary() 方法）。
var _deck_system: Node = null

## === 瞬态交互状态（ADR-0031 §2.1——不进存档，刷新即弃）=========================

## 动画开关——[b]测试注入点[/b]（story AC-3 规格「自动化断言显示文本，不含动画」：
## 测试置 false 后刷新直接落位终值，绕过 0.3s 滚动 Tween 的帧内插值覆写）。
## 覆盖全部三类动画：滚动（_apply_lingshi）/ delta 浮动（_show_delta）/
## 超限闪烁（LingshiDeckBarAnim.start_overlimit_flicker——reduce-motion 静态降级）。
## 亦为未来 reduce-motion 用户设置预留接线点（TD-008 同源技债——设置系统
## 入库后由此开关接入跳过/弱化）。
var animate: bool = true

## 上次显示的灵石数额——跳过重复信号触发的动画重启（_refresh 幂等性：
## resource_changed 与 batch_updated 对同一变更双发射时无操作），
## 及 batch 路径的 delta 计算（new - old）。
var _last_lingshi: int = -1
## 上次应用的卡组 (count, cap) 合成键——同上幂等跳过 + 翻转检测。
var _last_deck_key: String = ""
## 上次超限闪烁激活状态——仅翻转时启停 Tween，避免每信号重建循环动画。
var _last_overlimit: bool = false
## 动画编排件（_ready 建；持有三个 Tween 句柄与插值中间值）。
var _anim: RefCounted = null

## === 节点引用 ==================================================================

@onready var lingshi_label: Label = $LingshiLabel
@onready var lingshi_delta_label: Label = $LingshiDeltaLabel
@onready var deck_label: Label = $DeckLabel
@onready var overlimit_label: Label = $OverlimitLabel

## 超限闪烁 Tween 句柄（转发自动画件——既有引用点读此成员）。
var _overlimit_tween: Tween:
	get:
		return null if _anim == null else _anim.call(&"overlimit_tween")

## === 生命周期 ==================================================================

func _ready() -> void:
	# 纯显示组件（G8 裁决透传先例）：根与子节点全 IGNORE，不拦截下层点击。
	# tscn 中已设各 Label mouse_filter=2——此处钉根节点防场景外实例化漏配。
	mouse_filter = MOUSE_FILTER_IGNORE
	# B-1 修复：DeckLabel/OverlimitLabel 与 LingshiLabel 共享 tscn SubResource
	# LabelSettings——label_settings 非 null 时优先于一切 theme 属性，
	# add_theme_color_override 永不生效（三态颜色死代码）。为两个 Label 各
	# duplicate 一份独立实例后直写 font_color；判空防场景外实例化未绑定情况。
	if deck_label.label_settings != null:
		deck_label.label_settings = deck_label.label_settings.duplicate()
	if overlimit_label.label_settings != null:
		overlimit_label.label_settings = overlimit_label.label_settings.duplicate()
		# 「超限！」朱砂红——原 tscn 节点级 font_color 会被共享 LabelSettings
		# 覆盖（同 B-1），duplicate 后直写。
		overlimit_label.label_settings.font_color = COLOR_OVERLIMIT
	_anim = Anim.new(self, lingshi_label, lingshi_delta_label, deck_label)
	setup()

func _exit_tree() -> void:
	if _anim != null:
		_anim.call(&"kill_all")

## 初始化信号订阅与首刷。[br]
## [param gsm]: 依赖注入的 GSM（测试 mock）；null 时回退 Autoload。[br]
## [param deck_system]: 依赖注入的卡组系统（测试 mock——仅需
## [code]get_deck_summary()[/code]）；null 时回退 Autoload。
func setup(gsm: Node = null, deck_system: Node = null) -> void:
	if gsm != null:
		_gsm = gsm
	if deck_system != null:
		_deck_system = deck_system
	_connect_gsm_signals()
	_refresh()

## === 信号处理器（G1 裁决——统一走幂等 _refresh）===============================

## 单变更灵石信号（gsm_signal_router 单变更路径发射）。[br]
## [param type]: 资源类型（过滤 &"ling_shi"）。[br]
## [param delta]: 变更量（+25/-10——浮动标签数据源）。[br]
## [param balance]: 新余额。
func _on_resource_changed(type: StringName, delta: int, balance: int) -> void:
	if type != RES_TYPE_LING_SHI:
		return
	_refresh(delta)

## 批量变更信号（同帧多变更唯一入口 + 卡组变更唯一入口）。[br]
## [param changes]: {路径: {old, new}} 展平字典。
func _on_batch_updated(changes: Dictionary) -> void:
	# G1 裁决订阅集：灵石精确路径键（同帧多变更时 resource_changed 不发射——
	# batch 为唯一入口）+ deck.current_deck 精确路径键（卡组刷新唯一入口）。
	var lingshi_hit: bool = changes.has(PATH_LING_SHI)
	var deck_hit: bool = changes.has(PATH_DECK)
	if lingshi_hit:
		# delta 从载荷取 new-old（batch 路径无 delta 参数）。
		var entry: Dictionary = changes[PATH_LING_SHI]
		var delta: int = int(entry.get("new", 0)) - int(entry.get("old", 0))
		_refresh(delta)
	elif deck_hit:
		_refresh()

## === 刷新（幂等）===============================================================

## 从 GSM player 域 / DeckEditingSystem API 读取现状 → 纯函数判定 → 应用视觉。
## 每信号周期从源读取，不持有游戏状态副本（ADR-0031 §2）。[br]
## [param delta]: 灵石变更量（resource_changed 参数或 batch 载荷差值——
## 驱动 (+xx/-xx) 浮动动画；0 表示无变更——首刷/仅卡组刷新路径静默）。
func _refresh(delta: int = 0) -> void:
	var g: Node = _get_gsm()
	if g == null or not ("player" in g):
		push_warning("LingshiDeckBar._refresh: GSM 不可用——跳过本次刷新")
		return
	var player: Dictionary = g.player
	var lingshi: int = int(player.get("resources", {}).get("ling_shi", 0))
	var deck_state: Dictionary = _read_deck_summary()

	_apply_lingshi(lingshi, delta)
	_apply_deck(deck_state)

## 应用灵石显示：文本 + 跳动动画。[br]
## [param lingshi]: 当前灵石余额。[br]
## [param delta]: 变更量（0 表示无变更——首刷/仅卡组刷新路径静默）。[br]
## [br][b]幂等守卫[/b]：[code]lingshi == _last_lingshi[/code] 即跳过（不看 delta——
## 单变更时 GSM 先发 [code]resource_changed[/code] 再发 [code]batch_updated[/code]
## 双信号，第二个处理器若因 delta!=0 绕过守卫会 kill 重启滚动动画）。[br]
## 首刷（_last_lingshi < 0）或 delta==0 时直接落位不播动画（参照 realm_bar
## _tween_fill 的 is_first 处理）。动画本体归 [LingshiDeckBarAnim]。
func _apply_lingshi(lingshi: int, delta: int) -> void:
	var is_first: bool = _last_lingshi < 0
	if lingshi == _last_lingshi:
		return  # 幂等：双发射重复触发时无操作
	var old_val: int = _last_lingshi if _last_lingshi >= 0 else lingshi
	_last_lingshi = lingshi
	if _anim == null or is_first or delta == 0 or not is_inside_tree():
		if _anim != null:
			_anim.call(&"set_text_immediate", lingshi)
		return
	if not animate:
		# 测试注入/reduce-motion：跳过滚动动画直接落位终值（AC-3 规格
		# 「断言显示文本，不含动画」的可测性前提）；delta 浮动由动画件
		# 自行按 animate 开关决定是否播。
		_anim.call(&"set_text_immediate", lingshi)
		if delta != 0:
			_anim.call(&"show_delta", delta)
		return
	_anim.call(&"roll_to", lingshi, old_val, delta)

## 灵石 (+xx/-xx) 浮动标签（转发自动画件——保留方法名供既有引用点直调）。
func _show_delta(delta: int) -> void:
	if _anim != null:
		_anim.call(&"show_delta", delta)

## 应用卡组显示：计数文本 + 三态颜色 + 超限闪烁/标记（AC-005/006）。
func _apply_deck(deck_state: Dictionary) -> void:
	var count: int = int(deck_state.get("total", 0))
	var cap: int = int(deck_state.get("limit", 0))
	var state: Dictionary = LingshiFormatter.get_deck_count_state(count, cap)

	deck_label.text = ICON_DECK + Style.ICON_SEPARATOR + state[&"label"]
	# B-1 修复：直写独立 LabelSettings.font_color——deck_label 与灵石行共享
	# SubResource 时 add_theme_color_override 永不生效（label_settings 优先）。
	# 判空守卫：全库仅 tscn 实例化（集成测试 BAR_SCENE + HUD.tscn——
	# label_settings 必非 null），防御脚本裸 new() 场景外实例化时回退
	# theme override 路径（该路径下 override 生效——无 label_settings 竞争）。
	if deck_label.label_settings != null:
		deck_label.label_settings.font_color = COUNT_COLORS.get(
				state[&"color"], COUNT_COLORS["normal"])
	else:
		deck_label.add_theme_color_override("font_color",
				COUNT_COLORS.get(state[&"color"], COUNT_COLORS["normal"]))
	overlimit_label.visible = state[&"overlimit"]

	var deck_key: String = "%d/%d" % [count, cap]
	if deck_key == _last_deck_key and state[&"overlimit"] == _last_overlimit:
		return  # 幂等：双发射重复触发时无操作
	_last_deck_key = deck_key
	var overlimit: bool = state[&"overlimit"]
	if overlimit != _last_overlimit:
		_last_overlimit = overlimit
		_anim.call(&"stop_overlimit_flicker")
		if overlimit:
			_anim.call(&"start_overlimit_flicker")

## === 内部辅助 ==================================================================

## 获取 GSM——注入对象优先，否则回退 Autoload（get_node 而非全局名，
## 保持脚本可脱离 Autoload 环境解析）。
func _get_gsm() -> Node:
	if _gsm != null:
		return _gsm
	return get_node_or_null("/root/" + String(Style.AUTOLOAD_GSM))

## 获取 DeckEditingSystem——注入对象优先，否则回退 Autoload。
func _get_deck_system() -> Node:
	if _deck_system != null:
		return _deck_system
	return get_node_or_null("/root/" + String(Style.AUTOLOAD_DECK))

## 读取卡组摘要（total/limit）——UI 数据源接口（ADR-0023）。
## 系统不可用时返回全 0（get_deck_count_state 的 cap<=0 防御分支兜底——
## G3 裁决：显示 0/0 normal，不崩溃不黄）。
func _read_deck_summary() -> Dictionary:
	var ds: Node = _get_deck_system()
	if ds != null and ds.has_method("get_deck_summary"):
		var summary: Dictionary = ds.get_deck_summary()
		return {
			"total": int(summary.get("total", 0)),
			"limit": int(summary.get("limit", 0)),
		}
	push_warning("LingshiDeckBar: DeckEditingSystem 不可用——卡组计数显示 0/0")
	return {"total": 0, "limit": 0}

## 防重复连接 GSM 双信号（G1 裁决订阅集）。
func _connect_gsm_signals() -> void:
	var g: Node = _get_gsm()
	if g == null:
		push_warning("LingshiDeckBar: GSM 不可用——跳过信号订阅（setup 可重入重试）")
		return
	_connect_once(g, &"resource_changed", _on_resource_changed)
	_connect_once(g, &"batch_updated", _on_batch_updated)

func _connect_once(source: Node, signal_name: StringName, handler: Callable) -> void:
	if not source.has_signal(signal_name):
		push_warning("LingshiDeckBar: GSM 缺少 %s 信号——跳过订阅" % signal_name)
		return
	var s: Signal = source.get(signal_name)
	if not s.is_connected(handler):
		source.connect(signal_name, handler)
