class_name LingshiDeckBar
extends Control
## LingshiDeckBar —— 灵石+卡组计数组件（右上，hud Story 003）。
##
## [b]结构[/b]：灵石行 Label（🪙 占位图标 + k 格式数额）+ 灵石浮动 delta Label
## （(+xx/-xx) 跳动动画）+ 卡组行 Label（📜 占位图标 + count/cap）+ 超限标记
## Label（「超限！」，仅超限时显示）。[br]
## [br][b]Logic 内核[/b]：全部格式化/阈值判定走 [LingshiFormatter] 纯函数
## （ADR-0031——UI 节点只消费判定结果，禁止内联阈值 if-else）。[br]
## [br][b]信号订阅[/b]（G1 裁决 2026-09-10 双订阅）：[code]resource_changed[/code]
## （过滤灵石类型——单变更时发射）[b]及[/b] [code]batch_updated[/code]（过滤
## [code]player.resources.ling_shi[/code] 前缀——同帧多变更时域信号不发射，
## batch_updated 为唯一入口；另滤 [code]deck.current_deck[/code] 前缀——卡组
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

## === Visual 常量（数据驱动）===================================================

## 卡组计数颜色映射（判定标识 → 美术圣经 §4.1 主色调色板）：
## normal=墨色（默认 Label 色）/ yellow=琉璃金 #C8A84E（达上限警示）/
## red=朱砂红 #B3424A（超限警报——美术圣经「生命在流逝」编码复用为警报色）。
const COUNT_COLORS: Dictionary = {
	"normal": Color("#1A1A1A"),
	"yellow": Color("#C8A84E"),
	"red": Color("#B3424A"),
}

## 灵石数字滚动时长——0.3s（GDD hud-system.md §调优参数表「灵石数字跳动 0.3s」）。
const LINGSHI_ROLL_DURATION: float = 0.3
## 灵石 (+xx/-xx) 浮动标签上浮时长（含淡出）。
const DELTA_FLOAT_DURATION: float = 0.8
## 卡组超限红色闪烁全周期——0.8s（realm_bar FALLEN_FLICKER_PERIOD 风格先例）。
const OVERLIMIT_FLICKER_PERIOD: float = 0.8

## 订阅过滤常量——GSM 路径前缀（G1 裁决订阅集）。
const PATH_LING_SHI: String = "player.resources.ling_shi"
const PATH_DECK: String = "deck.current_deck"
## 灵石资源类型标识（resource_changed 信号第一参数——gsm_signal_router
## 从路径第三段切出）。灵石图标占位字符（真图标归美术资产管线——图集）。
const RES_TYPE_LING_SHI: StringName = &"ling_shi"
const ICON_LINGSHI: String = "🪙"
const ICON_DECK: String = "📜"
## (+xx/-xx) 前缀符号。
const SIGN_PLUS: String = "+"

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
## 灵石数字滚动 Tween 句柄（新值到来时 kill 重建）。
var _roll_tween: Tween = null
## 灵石 delta 浮动 Tween 句柄（含浮动 Label 本体的显隐编排）。
var _delta_tween: Tween = null
## 卡组超限闪烁 Tween 句柄。
var _overlimit_tween: Tween = null
## 灵石滚动动画当前插值值（Tween method 绑定的可变捕获——
## _exit_tree 后 Tween 回调不再触达节点）。
var _roll_display: int = 0

## === 节点引用 ==================================================================

@onready var lingshi_label: Label = $LingshiLabel
@onready var lingshi_delta_label: Label = $LingshiDeltaLabel
@onready var deck_label: Label = $DeckLabel
@onready var overlimit_label: Label = $OverlimitLabel

## === 生命周期 ==================================================================

func _ready() -> void:
	# 纯显示组件（G8 裁决透传先例）：根与子节点全 IGNORE，不拦截下层点击。
	# tscn 中已设各 Label mouse_filter=2——此处钉根节点防场景外实例化漏配。
	mouse_filter = MOUSE_FILTER_IGNORE
	setup()

func _exit_tree() -> void:
	_stop_overlimit_flicker()
	for t: Tween in [_roll_tween, _delta_tween]:
		if t != null and t.is_valid():
			t.kill()
	_roll_tween = null
	_delta_tween = null

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
	_refresh_with_lingshi_delta(delta)

## 批量变更信号（同帧多变更唯一入口 + 卡组变更唯一入口）。[br]
## [param changes]: {路径: {old, new}} 展平字典。
func _on_batch_updated(changes: Dictionary) -> void:
	# G1 裁决订阅集：灵石前缀（同帧多变更时 resource_changed 不发射——
	# batch 为唯一入口）+ deck.current_deck 前缀（卡组刷新唯一入口）。
	var lingshi_hit: bool = changes.has(PATH_LING_SHI)
	var deck_hit: bool = changes.has(PATH_DECK)
	if lingshi_hit:
		# delta 从载荷取 new-old（batch 路径无 delta 参数）。
		var entry: Dictionary = changes[PATH_LING_SHI]
		var delta: int = int(entry.get("new", 0)) - int(entry.get("old", 0))
		_refresh_with_lingshi_delta(delta)
	elif deck_hit:
		_refresh()

## === 刷新（幂等）===============================================================

## 从 GSM player 域 / DeckEditingSystem API 读取现状 → 纯函数判定 → 应用视觉。
## 每信号周期从源读取，不持有游戏状态副本（ADR-0031 §2）。
func _refresh() -> void:
	var g: Node = _get_gsm()
	if g == null or not ("player" in g):
		push_warning("LingshiDeckBar._refresh: GSM 不可用——跳过本次刷新")
		return
	var player: Dictionary = g.player
	var lingshi: int = int(player.get("resources", {}).get("ling_shi", 0))
	var deck_state: Dictionary = _read_deck_summary()

	_apply_lingshi(lingshi, 0)
	_apply_deck(deck_state)

## _refresh 变体——灵石变更携带 delta（resource_changed 参数或 batch 载荷差值），
## 驱动 (+xx/-xx) 浮动动画；卡组部分同 _refresh。
func _refresh_with_lingshi_delta(delta: int) -> void:
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
## _tween_fill 的 is_first 处理）。
func _apply_lingshi(lingshi: int, delta: int) -> void:
	var is_first: bool = _last_lingshi < 0
	if lingshi == _last_lingshi:
		return  # 幂等：双发射重复触发时无操作
	var old_val: int = _last_lingshi if _last_lingshi >= 0 else lingshi
	_last_lingshi = lingshi
	if is_first or delta == 0 or not is_inside_tree():
		lingshi_label.text = ICON_LINGSHI + " " + LingshiFormatter.format_lingshi(lingshi)
		return
	# 变更动画路径：滚动 Tween 从旧显示值插值到新值（AC-007）。
	# 不重置 label.text 到 old_val——label 已显示旧值，重置会使同帧读取者
	# （集成测试断言）读到回退值；Tween 首个回调（progress≈0）很快到来。
	if not animate:
		# 测试注入/reduce-motion：跳过滚动动画直接落位终值（AC-3 规格
		# 「断言显示文本，不含动画」的可测性前提）。
		lingshi_label.text = ICON_LINGSHI + " " + LingshiFormatter.format_lingshi(lingshi)
		if delta != 0:
			_show_delta(delta)
		return
	_roll_display = old_val
	if _roll_tween != null and _roll_tween.is_valid():
		_roll_tween.kill()
	_roll_tween = create_tween()
	_roll_tween.tween_method(_on_roll_tick.bind(old_val, lingshi),
			0.0, 1.0, LINGSHI_ROLL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 终值立即落位：Tween 完成时由 _on_roll_tick(1.0) 覆盖为同一文本——
	# 滚动动画仅是视觉插值层，数据正确性不依赖动画时序。
	lingshi_label.text = ICON_LINGSHI + " " + LingshiFormatter.format_lingshi(lingshi)
	if delta != 0:
		_show_delta(delta)

## Tween 滚动插值回调——按进度重格式化显示值。
func _on_roll_tick(progress: float, from_val: int, to_val: int) -> void:
	_roll_display = int(round(lerpf(float(from_val), float(to_val), progress)))
	lingshi_label.text = ICON_LINGSHI + " " + LingshiFormatter.format_lingshi(_roll_display)

## 灵石 (+xx/-xx) 浮动标签：向上浮 0.8s 并淡出（方向区分：增加向上浮——
## 减少同样向上浮但前缀为负号；AC-004 手动验证项）。
func _show_delta(delta: int) -> void:
	lingshi_delta_label.text = ("%+d" % delta) if delta > 0 else str(delta)
	lingshi_delta_label.modulate.a = 1.0
	if _delta_tween != null and _delta_tween.is_valid():
		_delta_tween.kill()
	_delta_tween = create_tween()
	_delta_tween.set_parallel(true)
	_delta_tween.tween_property(lingshi_delta_label, "modulate:a", 0.0,
			DELTA_FLOAT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_delta_tween.tween_property(lingshi_delta_label, "position:y",
			lingshi_delta_label.position.y - 18.0,
			DELTA_FLOAT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_delta_tween.chain().tween_callback(_reset_delta_label)

func _reset_delta_label() -> void:
	lingshi_delta_label.modulate.a = 0.0

## 应用卡组显示：计数文本 + 三态颜色 + 超限闪烁/标记（AC-005/006）。
func _apply_deck(deck_state: Dictionary) -> void:
	var count: int = int(deck_state.get("total", 0))
	var cap: int = int(deck_state.get("limit", 0))
	var state: Dictionary = LingshiFormatter.get_deck_count_state(count, cap)

	deck_label.text = ICON_DECK + " " + state[&"label"]
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
		_stop_overlimit_flicker()
		if overlimit:
			_start_overlimit_flicker()

## === 动画（Tween——输入驱动的纯视觉变换，零轮询豁免）===========================

## 卡组超限红色闪烁：0.8s 周期循环（透明度闪烁）。持续到玩家处理超限弃牌
## （deck-editing-ui epic）——本组件不负责停止条件以外的清理。
## [b]reduce-motion 技债注记[/b]（TD-008 同源）：动画未读用户减少动态偏好——
## 设置系统入库后应接入跳过/弱化，见 production tech-debt TD-008。
func _start_overlimit_flicker() -> void:
	if not is_inside_tree():
		return
	deck_label.modulate.a = 1.0
	_overlimit_tween = create_tween().set_loops()
	_overlimit_tween.tween_property(deck_label, "modulate:a", 0.35,
			OVERLIMIT_FLICKER_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_overlimit_tween.tween_property(deck_label, "modulate:a", 1.0,
			OVERLIMIT_FLICKER_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _stop_overlimit_flicker() -> void:
	if _overlimit_tween != null and _overlimit_tween.is_valid():
		_overlimit_tween.kill()
	_overlimit_tween = null
	_last_overlimit = false
	deck_label.modulate.a = 1.0

## === 内部辅助 ==================================================================

## 获取 GSM——注入对象优先，否则回退 Autoload（get_node 而非全局名，
## 保持脚本可脱离 Autoload 环境解析）。
func _get_gsm() -> Node:
	if _gsm != null:
		return _gsm
	return get_node_or_null("/root/GameStateManager")

## 获取 DeckEditingSystem——注入对象优先，否则回退 Autoload。
func _get_deck_system() -> Node:
	if _deck_system != null:
		return _deck_system
	return get_node_or_null("/root/DeckEditingSystem")

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
