class_name CharacterStatusCard
extends Control
## CharacterStatusCard —— 角色状态卡组件 L0-L5 分层（combat-ui-layout Story 002）。
##
## [b]职责[/b]：单 Control 自绘角色卡——六层从底到顶：[br]
##   L0 头像全幅背景 → L1 底部渐变遮罩（对比度保障）→ L2 左右 28px
##   功法/法宝竖排栏（各最多 3）→ L3 底部 40px HP 条+ATK → L4 buff 左下
##   （最多 5）+境界右下 → L5 待命/已行动左上。[br]
## [br][b]两块内容已拆出[/b]（本文件守 300 行软上限）：六层绘制归
## [code]character_card_painter.gd[/code]，尺寸/配色/时长常量归
## [code]character_card_style.gd[/code]。本文件剩下的是[b]状态入口[/b]——信号驱动的
## 写入方法、Tween 编排、Label 子节点摆放。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：角色数据（HP/buff/绑定）所有权在
## 战斗/绑定系统——本组件只持渲染快照，[method apply_hp] 等由系统信号驱动。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——HP 过渡 0.3s 一次性 Tween
## （§2.1 豁免），数字 ≤100ms 终值直显（GDD 批量伤害免抖条款）。[br]
##
## @experimental
## 来源: ADR-0031、design/ux/combat-ui.md §角色状态卡、
## production/qa/evidence/r02-batching-spec.md、combat-ui-layout Story 002。

## 视觉规格常量（卡宽高 / 层尺寸 / 配色 / 时长——唯一来源）。
const Style := preload("res://src/ui/combat/layout/character_card_style.gd")
## 六层绘制（L0-L5——本卡只负责摆放与状态，画笔在那边）。
const Painter := preload("res://src/ui/combat/layout/character_card_painter.gd")
## 文字子节点（创建 / 摆放 / 内容同步——三个 Label，见该模块类文档）。
const Labels := preload("res://src/ui/combat/layout/character_card_labels.gd")
## 共享纯函数（前后排缩放——story 001 唯一落地处，禁止内联）。
const Rules := preload("res://src/ui/combat/shared/combat_ui_rules.gd")
## 阵亡判定（纯函数——story 003 AC-4，本卡只派生不重判）。
const DefeatMarker := preload("res://src/ui/combat/layout/combat_card_defeat_marker.gd")

## === 渲染快照（零状态所有权——系统信号驱动写入）==============================

## 当前/最大 HP（渲染快照——所有权在战斗系统）。
var current_hp: int = 0
var max_hp: int = 0
## 角色显示名（渲染快照——解析归战斗侧的角色取数入口，
## 本卡只存只画：[method apply_name] 写入）。
var display_name: String = ""
## ATK 数值快照。
var atk_value: int = 0
## 功法/法宝图标显示数（L2——绑定数据经 [method set_bindings] 从
## BindingManager 零分配查询结果写入）。
var gongfa_count: int = 0
var fabao_count: int = 0
## buff/debuff 计数快照（L4——各占位图标，实际图标集归 interaction/美术）。
var buff_count: int = 0
var debuff_count: int = 0
## 角色境界（L4 境界角标仅当 realm > player_realm 时显示——story AC-6）。
var realm: int = 0
## 玩家境界（比较基准——由场景层注入）。
var player_realm: int = 0
## 待命/已行动标记（L5 渲染；切换信号逻辑归 story 003）。
var is_standby: bool = false
## 已行动遮罩标志（story 003 AC-2——true 时全卡幅半透明灰色遮罩）。[br]
## [br][b]语义澄清[/b]（story 002 遗留）：[member is_standby]=false 本渲染
## 「已行动对勾」，但未覆盖 GDD「灰色遮罩」完整语义——本属性补齐：
## is_acted=true 同时驱动遮罩+对勾（[method set_acted_state]），默认 false
## 使 is_standby=false 的旧语义（仅对勾）不自动出现遮罩。
var is_acted: bool = false
## 阵亡态——[b]由 [method apply_hp] 从 HP 派生[/b]，不是独立写入的状态位。[br]
## [br][b]为什么派生而不是 set_defeated()[/b]：阵亡的真理来源是战斗状态表
## （[code]CombatRosterState[/code] 的 [code]current_hp[/code] / [code]is_alive[/code]），
## 界面上再存一个「我以为他死了」的标志就是第二份真源——两处一旦不同步，
## 玩家会看到「已阵亡」的角色还满血站着。[br]
## [br][b]max_hp > 0 才判[/b]：读不到数据的角色（[code]known=false[/code]，HP 全零）
## 不算阵亡——同 [code]CombatSystem.is_character_alive[/code] 的「不因缺数据判死」。
var is_defeated: bool = false
## 前后排定位（true 前排——边框样式+缩放决策）。
var is_front_row: bool = true
## 减少动态（进场时从设置读取——进场后静态，零轮询）。
var reduce_motion: bool = false

## HP 条显示宽度（Tween 插值目标——0..1 比例）。[br]
## [br][b]绘制模块会读它[/b]（[code]character_card_painter.draw_hp_bar[/code]）：
## 本卡是这份瞬态视觉状态的唯一持有者，画笔不该另存一份。
var _hp_display_ratio: float = 1.0
## HP 过渡 Tween 句柄（重入 kill 重建——批量伤害直算终值条款）。
var _hp_tween: Tween = null
## 沙漏淡出透明度（>0 时 L5 继续绘制沙漏——待命→已就绪 0.3s 淡出通道；
## 瞬态视觉状态 §2.1 豁免）。绘制模块同读。
var _badge_alpha: float = 0.0
## 沙漏淡出 Tween 句柄（重入 kill）。
var _badge_tween: Tween = null
## 文字子节点表（[code]{stat, name, defeat}[/code]——[CharacterCardLabels.create] 的产出）。
var _labels: Dictionary = {}
## 名+数值合并 Label（R-02 §3 文字合并——单 Label 不拆多）。
var _stat_label: Label = null
## 角色显示名 Label（L5 名牌——[method apply_name] 写入；敌方此前无名可分）。
var _name_label: Label = null
## 阵亡戳记 Label（文本取自 [code]CombatCardDefeatMarker.style[/code]，未阵亡时隐藏）。
var _defeat_label: Label = null
## 头像纹理（每角色唯一独立纹理——R-02 §3 头像分组；null 时色块占位）。
var portrait: Texture2D = null

## === 常量转发（外部文档与既有引用读的是卡上的名字）============================

const CARD_WIDTH: float = Style.CARD_WIDTH
const CARD_HEIGHT: float = Style.CARD_HEIGHT
const SIDE_BAR_WIDTH: float = Style.SIDE_BAR_WIDTH
const ICON_SIZE: float = Style.ICON_SIZE
const ICON_GAP: float = Style.ICON_GAP
const SIDE_ICON_LIMIT: int = Style.SIDE_ICON_LIMIT
const BOTTOM_BAR_HEIGHT: float = Style.BOTTOM_BAR_HEIGHT
const BUFF_LIMIT: int = Style.BUFF_LIMIT
const BADGE_SIZE: float = Style.BADGE_SIZE
const HP_TWEEN_SEC: float = Style.HP_TWEEN_SEC
const BADGE_FADE_SEC: float = Style.BADGE_FADE_SEC
const FRONT_BORDER_COLOR: Color = Style.FRONT_BORDER_COLOR
const BACK_BORDER_COLOR: Color = Style.BACK_BORDER_COLOR
const BORDER_WIDTH: float = Style.BORDER_WIDTH
const DASH_LENGTH: float = Style.DASH_LENGTH
const BOTTOM_BAR_BG: Color = Style.BOTTOM_BAR_BG
const HP_TRACK_COLOR: Color = Style.HP_TRACK_COLOR
const ATK_COLOR: Color = Style.ATK_COLOR
const ACTED_OVERLAY_COLOR: Color = Style.ACTED_OVERLAY_COLOR


## _init 构建文字子节点（不依赖场景树时序——创建归 [CharacterCardLabels]）。
func _init() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	_labels = Labels.create(self)
	_stat_label = _labels["stat"]
	_name_label = _labels["name"]
	_defeat_label = _labels["defeat"]


func _draw() -> void:
	Painter.draw_all(self)


## === 信号驱动更新入口（战斗系统信号 → 渲染快照）==============================

## 应用 HP 变更（战斗系统 HP 变更信号驱动）。[br]
## [br][b]批量伤害免抖[/b]（GDD 公式 3）：同帧多次调用直算终值——Tween 重入
## kill 重建，从当前显示比例向终值单次 0.3s 过渡；数字 ≤100ms 终值直显
## （Label 直接更新——无数字 Tween）。[br]
## [param p_current]: 新当前 HP。[param p_max]: 最大 HP（守卫 0 → 比例 1.0，
## 防除零——QA 规格 AC-1 edge）。
func apply_hp(p_current: int, p_max: int) -> void:
	current_hp = maxi(p_current, 0)
	max_hp = maxi(p_max, 0)
	is_defeated = DefeatMarker.is_defeated(current_hp, max_hp)
	var target_ratio: float = Painter.hp_ratio(self)
	if reduce_motion:
		_hp_display_ratio = target_ratio
		_kill_hp_tween()
	else:
		_kill_hp_tween()
		_hp_tween = create_tween()
		_hp_tween.tween_method(_set_hp_display_ratio,
			_hp_display_ratio, target_ratio, HP_TWEEN_SEC)
	_refresh()


## 设置角色显示名（L5 名牌——战斗侧取数入口解析后写入）。[br]
## [br][b]为什么名要在卡上[/b]：敌方此前只有头像没有名字，玩家分不清两只同色敌人
## 谁是谁；HP 条挂了名才能读懂「这条血是谁的」。名字是渲染快照（零状态所有权），
## 解析归调用方（[code]ActorStageRoster[/code] 注入的取数入口）。[br]
## [br][b]空名不覆盖[/b]：解析失败传空串时保留既有名，避免一次读不到就把名牌抹掉。
func apply_name(p_name: String) -> void:
	if p_name.is_empty():
		return
	display_name = p_name
	_refresh()


## 应用 ATK 变更。
func apply_atk(p_atk: int) -> void:
	atk_value = p_atk
	_refresh()


## 设置绑定图标数（L2——[code]BindingManager.get_binding_ids_by_character()[/code]
## 查询结果经 slot_type 分组计数后写入；本组件不直接访问系统——零状态所有权）。
func set_bindings(p_gongfa: int, p_fabao: int) -> void:
	gongfa_count = clampi(p_gongfa, 0, SIDE_ICON_LIMIT)
	fabao_count = clampi(p_fabao, 0, SIDE_ICON_LIMIT)
	_refresh()


## 设置 buff/debuff 计数（L4——状态系统信号驱动；实际图标集归美术管线）。
func set_status_effects(p_buff: int, p_debuff: int) -> void:
	buff_count = clampi(p_buff, 0, BUFF_LIMIT)
	debuff_count = clampi(p_debuff, 0, BUFF_LIMIT)
	_refresh()


## 设置境界数据（L4——境界角标仅 realm > player_realm 时显示）。
func set_realm(p_realm: int, p_player_realm: int) -> void:
	realm = p_realm
	player_realm = p_player_realm
	_refresh()


## 设置前后排（缩放 + 边框样式决策——story AC-4）。
func set_front_row(p_front: bool) -> void:
	is_front_row = p_front
	var scale_factor: float = Rules.formation_row_scale(p_front)
	scale = Vector2(scale_factor, scale_factor)
	_refresh()


## 设置待命标记（L5 渲染——切换信号逻辑归 story 003）。[br]
## 待命→已就绪：沙漏标记 0.3s 淡出（GDD 动画表 L611——语义位立即翻转，
## 视觉通道经 [member _badge_alpha] 渐隐；reduce_motion 瞬时清除）。
func set_standby(p_standby: bool) -> void:
	if p_standby:
		is_standby = true
		_kill_badge_tween()
		_badge_alpha = 0.0
	elif is_standby:
		is_standby = false
		if reduce_motion:
			_badge_alpha = 0.0
		else:
			_badge_alpha = 1.0
			_kill_badge_tween()
			_badge_tween = create_tween()
			_badge_tween.tween_method(_set_badge_alpha, 1.0, 0.0, BADGE_FADE_SEC)
	_refresh()


## 设置已行动状态（story 003 AC-2——灰色遮罩 + 已行动对勾）。[br]
## true = 遮罩+对勾（遮罩由 [member is_acted] 驱动，对勾由
## [member is_standby]=false 驱动——两属性合一入口）；false = 清除遮罩。
func set_acted_state(p_acted: bool) -> void:
	is_acted = p_acted
	if p_acted:
		is_standby = false  # 已行动与待命互斥（FieldState 状态机语义）
		_kill_badge_tween()  # 互斥路径直接终结沙漏淡出（对勾+遮罩接替）
		_badge_alpha = 0.0
	_refresh()


## 应用减少动态（进场时读取设置——进场后静态）。
func set_reduce_motion(p_reduce: bool) -> void:
	reduce_motion = p_reduce


## HP 条当前显示比例（只读——测试据此断言血条与数字同步，不靠信号）。
func get_hp_display_ratio_for_test() -> float:
	return _hp_display_ratio


## === 内部 ====================================================================

## HP 显示比例 Tween 插值回调。
func _set_hp_display_ratio(value: float) -> void:
	_hp_display_ratio = value
	_refresh()


## 标记重绘 + 同步三个文字子节点（内容与摆放归 [CharacterCardLabels]——
## 文字是[b]子节点[/b]，与 [code]_draw()[/code] 里的绘制是两条渲染通道）。[br]
## [br][b]重绘与文字同步在同一个入口[/b]：任何状态变更方法都只调本方法，
## 不会出现「条变了字没变」。
func _refresh() -> void:
	Labels.sync(self, _labels)
	queue_redraw()


## 沙漏淡出 Tween 插值回调。
func _set_badge_alpha(value: float) -> void:
	_badge_alpha = value
	queue_redraw()


## 沙漏淡出 Tween 重入清理。
func _kill_badge_tween() -> void:
	if _badge_tween != null and _badge_tween.is_valid():
		_badge_tween.kill()
	_badge_tween = null


## HP Tween 重入清理（批量伤害终值条款——kill 重建单次过渡）。
func _kill_hp_tween() -> void:
	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()
	_hp_tween = null
