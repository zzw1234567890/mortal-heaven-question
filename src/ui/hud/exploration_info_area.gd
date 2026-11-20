class_name ExplorationInfoArea
extends Control
## ExplorationInfoArea —— 探索 HUD 右下信息组组件（hud Story 006）。
##
## [b]结构[/b]：地图名 Label + AP 行（分段格 Label 「██░░」 + 计数
## 「3/5」）+ 层数 Label（「层3/5」）。三项显示均纯展示、无交互。[br]
## [br][b]Logic 内核[/b]：AP 颜色阈值 + 分段格判定走 [ApDisplayRules]
## 共享纯函数（ADR-0031 + story Control Manifest Required——HUD 与
## exploration-ui 双消费同一实现，禁止内联阈值）。[br]
## [br][b]信号订阅[/b]（story Engine Notes 逐字遵守——双路径）：[br]
##   - [code]action_points_changed(delta, current, max_val)[/code] —— 仅取
##     current（max_val 恒 0 不消费——gsm_signal_router.gd L81-83，AP 上限归
##     ExplorationSystem/ADR-0014，GSM 不跟踪）[br]
##   - [code]batch_updated[/code] —— 过滤 [code]exploration.action_points[/code]
##     与 [code]exploration.max_action_points[/code] 两条精确路径键
##     （[code]set_exploration_ap(current, max)[/code] 单帧双写 → 走 batch 路径，
##     域信号不发射——story 002 LingshiDeckBar G6 同型先例）[br]
##   - max 恒从 [code]GSM.exploration.max_action_points[/code] 读取[br]
## 刷新统一走幂等 [method _refresh]，忽略双发射重复触发。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不缓存游戏数值——每信号周期从
## GSM exploration 域 / ExplorationSystem 读取；[code]_last_*[/code] 前缀成员
## 均为瞬态交互状态（§2.1 三分类，见各成员注释）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]（story 护栏——AP 变更刷新
## 即时，信号驱动非轮询）。[br]
## [br][b]可见性边界[/b]：本组件不处理场景可见性——ContentLayer 整体显隐归
## hud.gd 可见性矩阵（Story 001；战斗隐藏由矩阵覆盖，AC 第 5 条无需新逻辑）。[br]
## [br][b]面板底色为深色半透明[/b]（反馈修订）：全局 UI 都是深色暗调，本组件此前
## 坐米白半透明面板（#F5F0E3 @0.85），玩家看到「右下角一块白底很怪」。现改为
## 深底 + 1px 暗蓝描边，文字转浅色（[constant AP_COLORS] 的 normal 同步改浅——
## 深底上墨黑字会消失）。[br]
## [br][b]mouse_filter[/b]：纯显示无交互——根与子节点全 IGNORE 透传
## （LingshiDeckBar G8 裁决先例）。
##
## [br]来源: ADR-0031、design/gdd/hud-system.md §5 探索中 HUD、
## hud Story 006（2026-10-20 QL 复核三处修订 + LP 跨域五条件）。

## === Visual 常量（数据驱动）===================================================

## AP 颜色映射（判定标识 → 美术圣经 §4.1 主色调色板）：
## 信息组坐[b]深色半透明面板[/b]（PanelBackground 的 StyleBoxFlat，
## bg_color ≈ #14161C @0.88，见 ExplorationInfoArea.tscn），故 normal 用具名浅色
## 而非墨黑——原先面板是米白半透明，normal 取墨黑 #1A1A1A，玩家反馈「右下角一块
## 白底很怪」（全局 UI 都是深色暗调），面板转深后墨黑字会直接消失在底色里。[br]
## 语义色仍取美术圣经的琉璃金 / 朱砂红：warning=琉璃金 #C8A84E（警示）/
## critical=朱砂红 #B3424A（紧急——「生命在流逝」警报编码复用先例）。
const AP_COLORS: Dictionary = {
	"normal": Color(0.90, 0.92, 0.96, 1.0),
	"warning": Color("#C8A84E"),
	"critical": Color("#B3424A"),
}

## 分段格字符（GDD hud-system.md §5「AP ██░░ 3/5」）：点亮/熄灭。
## 占位字符（真实图集图标归美术资产管线——ADR-0031 §5）。
const SEGMENT_ON: String = "█"
const SEGMENT_OFF: String = "░"

## 最小 map_id → 显示名常量表（story 裁决——数据驱动配置，起始仅青云剑宗；
## exploration-ui epic 扩展为完整表）。本地化注记：项目暂无本地化系统，
## 本地化入库后应替换为本地化键（LingshiDeckBar TEXT_* 常量豁免先例）。
const MAP_NAMES: Dictionary = {
	&"qing_yun_jian_zong": "青云剑宗",
}
## 未知 map_id 回退文本（QL 复核 2026-10-20 GAP-3——同 hud 通知系统未知
## 类型安全默认裁决 2026-09-10：占位文本 + push_warning，不崩溃）。
## 本地化注记同上。
const TEXT_UNKNOWN_MAP: String = "未知地域"
## 地图层显示前缀（GDD hud-system.md §5「📍 层3/5」——📍 图标归美术资产
## 管线，此处纯文本）。本地化注记同上。
const TEXT_LAYER_PREFIX: String = "层"

## 订阅过滤常量——GSM 路径键（story Engine Notes 订阅集）。
const PATH_AP: String = "exploration.action_points"
const PATH_MAX_AP: String = "exploration.max_action_points"

## === 布局常量（数据驱动——面板宽度随 AP 段数长，不写死像素）=====================
## [b]为什么要随内容变宽[/b]：分段格每格 1 AP，而境界越高段数越多（化神 13 格）。
## 段落文本的真实像素宽由字体度量决定（中文/块字符都不是「字符数 × 字号」），
## 面板 Fixed 宽度一旦小于它，段条会顶出面板并压住右侧计数——这正是玩家在
## 右下角看到的「文字显示不全」。宽度改为每次刷新技术算得，面板向右上锚点
## 反向生长（[code]grow_horizontal = BEGIN[/code]），贴边留白不变。
##
## 面板内左右留白（内容不贴面板边）。
const PANEL_PAD: float = 12.0
## 分段格与计数之间的最小间隙。
const AP_GAP: float = 8.0
## 计数区预留宽（「13/13」类文本的最大占用——与 tscn 的 ApCountLabel 锚点同宽）。
const AP_COUNT_WIDTH: float = 60.0
## 面板最小宽度（段数少时地图名/层数仍要完整显示）。
const PANEL_MIN_WIDTH: float = 200.0
## 面板高度（三行各 28px——与 tscn 的行偏移配套）。
const PANEL_HEIGHT: float = 90.0

## === 依赖注入 ==================================================================

## 注入的 GSM 引用——null 时回退 GameStateManager Autoload
## （LingshiDeckBar.setup 先例，测试可传 mock）。
var _gsm: Node = null
## 注入的 ExplorationSystem 引用——null 时回退 Autoload
## （测试传 mock：仅需 get_total_layers() 方法）。
var _exploration_system: Node = null

## === 瞬态交互状态（ADR-0031 §2.1——不进存档，刷新即弃）=========================

## 上次应用的地图名显示键——跳过重复信号触发的刷新落位（_refresh 幂等性：
## 域信号与 batch 对同一变更双发射时无操作——LingshiDeckBar._last_deck_key
## 先例）。地图名无独立刷新信号，仅随 AP 信号与移动类 batch 附带刷新。
var _last_map_key: String = ""
## 上次应用的 (current, max, layer, total) 合成键——同上幂等跳过。
var _last_ap_key: String = ""

## === 节点引用 ==================================================================

@onready var map_label: Label = $MapLabel
@onready var ap_segment_label: Label = $ApSegmentLabel
@onready var ap_count_label: Label = $ApCountLabel
@onready var layer_label: Label = $LayerLabel

## === 生命周期 ==================================================================

func _ready() -> void:
	# 纯显示组件：根与子节点全 IGNORE，不拦截下层点击（G8 裁决透传先例）。
	# tscn 中已设各 Label mouse_filter=2——此处钉根节点防场景外实例化漏配。
	mouse_filter = MOUSE_FILTER_IGNORE
	setup()

## 初始化信号订阅与首刷。[br]
## [param gsm]: 依赖注入的 GSM（测试 mock）；null 时回退 Autoload。[br]
## [param exploration_system]: 依赖注入的探索系统（测试 mock——仅需
## [code]get_total_layers()[/code]）；null 时回退 Autoload。
func setup(gsm: Node = null, exploration_system: Node = null) -> void:
	if gsm != null:
		_gsm = gsm
	if exploration_system != null:
		_exploration_system = exploration_system
	_connect_gsm_signals()
	_refresh()

## === 信号处理器（双路径——story Engine Notes 逐字遵守）=========================

## 域信号路径——[code]action_points_changed(delta, current, max_val)[/code]。[br]
## 仅取 current（max_val 恒 0 不消费——gsm_signal_router.gd L81-83）；
## delta 不消费（本组件无 delta 浮动动画）。[br]
## [param _delta]: 变更量（不消费）。[br]
## [param _current]: 新的当前 AP。[br]
## [param _max_val]: 恒 0（GSM 不跟踪 AP 上限——ADR-0014；不消费）。
func _on_action_points_changed(_delta: int, _current: int, _max_val: int) -> void:
	_refresh()

## 批量变更路径——[code]batch_updated[/code]。[br]
## 过滤 [code]exploration.action_points[/code] /
## [code]exploration.max_action_points[/code] 两条精确路径键
## （set_exploration_ap 单帧双写走此路径，域信号不发射）。[br]
## [param changes]: {路径: {old, new}} 展平字典。
func _on_batch_updated(changes: Dictionary) -> void:
	if changes.has(PATH_AP) or changes.has(PATH_MAX_AP):
		_refresh()

## === 刷新（幂等）===============================================================

## 从 GSM exploration 域 / ExplorationSystem 读取现状 → 纯函数判定 →
## 应用视觉。每信号周期从源读取，不持有游戏状态副本（ADR-0031 §2）。
func _refresh() -> void:
	var g: Node = _get_gsm()
	if g == null or not ("exploration" in g):
		push_warning("ExplorationInfoArea._refresh: GSM 不可用——跳过本次刷新")
		return
	var exploration: Dictionary = g.exploration
	var current: int = int(exploration.get("action_points", 0))
	var max_val: int = int(exploration.get("max_action_points", 0))
	var map_id: StringName = exploration.get("current_map", &"")
	var layer: int = int(exploration.get("node_position", {}).get("layer", 0))

	_apply_map_name(map_id)
	_apply_ap(current, max_val)
	_apply_layer(layer)

## 应用地图名显示：map_id → 常量表显示名；未知 map_id → 占位文本
## 「未知地域」+ push_warning（QL 复核 GAP-3 回退定义）。
func _apply_map_name(map_id: StringName) -> void:
	var display: String = MAP_NAMES.get(map_id, TEXT_UNKNOWN_MAP)
	# 幂等守卫先行（M-1 修复：守卫在 push_warning 之前——未知地图常态走回退
	# 路径，若每次刷新都告警会在 AP 双发射下刷屏；首见告警一次，重复静默跳过）。
	if display == _last_map_key:
		return
	if not MAP_NAMES.has(map_id) and str(map_id) != "":
		push_warning("ExplorationInfoArea: 未知 map_id %s——显示占位文本「未知地域」" % map_id)
	_last_map_key = display
	map_label.text = display

## 应用 AP 显示：分段格文本 + 计数文本 + 颜色（ApDisplayRules 共享纯函数
## 判定——禁止内联阈值）。分段格每格 1 AP、已消耗熄灭（AC 第 4 条）。[br]
## [br][b]同时把面板按段数撑到够宽[/b]（见 [method _fit_width]）——段条文本一旦
## 宽过面板，它会顶出面板右缘并压住计数（玩家反馈的「右下角文字显示不全」）。
func _apply_ap(current: int, max_val: int) -> void:
	var state: Dictionary = ApDisplayRules.get_ap_color_threshold(current, max_val)
	var segments: Array = state[&"segments"]

	# 分段格文本：██░░（B-1 同源防御：LabelSettings 非 null 时直写独立
	# duplicate 实例的 font_color，否则回退 theme override——见 _set_label_color）。
	var seg_text: String = ""
	for on: bool in segments:
		seg_text += SEGMENT_ON if on else SEGMENT_OFF
	ap_segment_label.text = seg_text
	ap_count_label.text = "%d/%d" % [current, max_val]
	_fit_width(seg_text)

	var ap_key: String = "%d/%d" % [current, max_val]
	if ap_key == _last_ap_key:
		return  # 幂等：双发射重复触发时无操作
	_last_ap_key = ap_key
	_set_label_color(ap_segment_label, AP_COLORS.get(state[&"color"], AP_COLORS["normal"]))
	_set_label_color(ap_count_label, AP_COLORS.get(state[&"color"], AP_COLORS["normal"]))

## 按当前段条文本把面板撑到够宽（宽度 = 左右留白 + 段条 + 间隙 + 计数区）。[br]
## [br][b]为什么算而不用 [method Control.get_minimum_size][/b]：段条标签开了
## [code]clip_text[/code]（防它自己顶破面板），此时最小尺寸恒为 1px——量不出内容。
## 字体的 [method Font.get_string_size] 给的是渲染实际宽度（探针实测与未裁切时的
## 最小尺寸逐位相同），是此处可用的真实度量。[br]
## [br][b]最小宽度兜底[/b]：段数少（炼气 5 格）时不能让面板缩得比地图名还窄。
func _fit_width(p_seg_text: String) -> void:
	var seg_width: float = _text_width(ap_segment_label, p_seg_text)
	var need: float = PANEL_PAD * 2.0 + seg_width + AP_GAP + AP_COUNT_WIDTH
	custom_minimum_size = Vector2(maxf(need, PANEL_MIN_WIDTH), PANEL_HEIGHT)

## 文本的渲染像素宽——字号取 [code]label_settings[/code] 优先（它覆盖主题字号，
## 只读主题会把宽度算小——探针初版即栽在这里）。字体取不到时返回 0（按最小宽度走）。
func _text_width(p_label: Label, p_text: String) -> float:
	var font: Font = p_label.get_theme_font(&"font")
	if font == null:
		return 0.0
	var size: int = p_label.get_theme_font_size(&"font_size")
	if p_label.label_settings != null:
		size = p_label.label_settings.font_size
	return font.get_string_size(p_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## 应用层数显示：当前层 layer+1（0 基转 1 基——story AC 第 1 条）/
## 总层数（ExplorationSystem.get_total_layers() 唯一许可入口——LP 条件③）。
func _apply_layer(layer: int) -> void:
	var total: int = _read_total_layers()
	layer_label.text = "%s%d/%d" % [TEXT_LAYER_PREFIX, layer + 1, total]

## === 内部辅助 ==================================================================

## 获取 GSM——注入对象优先，否则回退 Autoload。
func _get_gsm() -> Node:
	if _gsm != null:
		return _gsm
	return get_node_or_null("/root/GameStateManager")

## 获取 ExplorationSystem——注入对象优先，否则回退 Autoload。
func _get_exploration_system() -> Node:
	if _exploration_system != null:
		return _exploration_system
	return get_node_or_null("/root/ExplorationSystem")

## 读取总层数——ExplorationSystem.get_total_layers()（跨域只读方法，
## LP 条件③：禁止调用 get_node_graph()/get_node_details() 测试桩）。
## 系统不可用时返回 1（get_total_layers 空集防御同语义——显示「层 x/1」）。
func _read_total_layers() -> int:
	var es: Node = _get_exploration_system()
	if es != null and es.has_method("get_total_layers"):
		return int(es.get_total_layers())
	push_warning("ExplorationInfoArea: ExplorationSystem 不可用——总层数显示 1")
	return 1

## 直写 Label 颜色——LabelSettings 非 null 时 duplicate 独立实例后直写
## font_color（B-1 先例：共享 SubResource 下 add_theme_color_override 永不
## 生效）；null 时回退 theme override 路径。仅首次 duplicate。
func _set_label_color(label: Label, color: Color) -> void:
	if label.label_settings != null:
		if not label.get_meta(&"_settings_owned", false):
			label.label_settings = label.label_settings.duplicate()
			label.set_meta(&"_settings_owned", true)
		label.label_settings.font_color = color
	else:
		label.add_theme_color_override("font_color", color)

## 防重复连接 GSM 双信号（story Engine Notes 订阅集）。
func _connect_gsm_signals() -> void:
	var g: Node = _get_gsm()
	if g == null:
		push_warning("ExplorationInfoArea: GSM 不可用——跳过信号订阅（setup 可重入重试）")
		return
	_connect_once(g, &"action_points_changed", _on_action_points_changed)
	_connect_once(g, &"batch_updated", _on_batch_updated)

## 连接单个 GSM 信号（has_signal 防御 + is_connected 防重复——setup 重入安全）。
func _connect_once(source: Node, signal_name: StringName, handler: Callable) -> void:
	if not source.has_signal(signal_name):
		push_warning("ExplorationInfoArea: GSM 缺少 %s 信号——跳过订阅" % signal_name)
		return
	var s: Signal = source.get(signal_name)
	if not s.is_connected(handler):
		source.connect(signal_name, handler)
