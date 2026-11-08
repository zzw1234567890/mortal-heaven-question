class_name CombatLayout
extends Control
## CombatLayout —— 战场四区域布局骨架（combat-ui-layout Story 001）。
##
## [b]职责[/b]：战斗 UI 场景根——五区域容器（顶部条 / 敌方区 / 中线 /
## 己方区 / 底部条）按 UX Layout Zones 表以 **anchor 百分比** 搭建，
## 外加右上角撤退按钮位 + 暂停按钮位预留 + 进场过渡编排。
## 区域内容（角色卡/手牌/阶段指示器）由 002-006 story 填充。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本类不持有游戏状态——
## 布局常量为渲染参数；进场过渡的进度是瞬态视觉状态（§2.1 豁免）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——进场过渡用一次性
## Tween（完成即停），HUD 隐藏由 [signal post_transition] 驱动。[br]
## [br][b]anchor 百分比响应式[/b]（story 禁止像素硬编码布局）：
## 区域位置尺寸按 1920×1080 基准的百分比 anchor 设定，任意 16:9 分辨率
## 等比缩放（control-manifest「分辨率基准 1920×1080」）。
##
## @experimental
## 来源: ADR-0031、design/ux/combat-ui.md §Layout Zones/§Transitions、
## combat-ui-layout Story 001。

## === 区域常量（1920×1080 基准 → anchor 百分比）=============================

## 备战面板脚本（story 007——全屏覆盖层，默认隐藏）。
const DeployPanelScript := preload("res://src/ui/combat/deploy/deploy_panel.gd")
## 结算/撤退/渡劫警示宿主脚本（story 008——全屏覆盖层，默认隐藏）。
const SettlementHostScript := preload("res://src/ui/combat/settlement/settlement_host.gd")
## 撤退规则纯函数（story 008——撤退按钮渲染态判定与文案）。
const RetreatRulesScript := preload("res://src/ui/combat/shared/retreat_rules.gd")
## 反馈编排器（story 003——伤害飘字 / HP 条 / 阵亡淡出的生产装配点）。
const FeedbackScript := preload("res://src/ui/combat/feedback/combat_feedback_coordinator.gd")
## 角色卡装配台（Sprint 18——把敌我名册变成战场上的角色卡）。
const ActorStageScript := preload("res://src/ui/combat/layout/combat_actor_stage.gd")
## 撤退按钮文案（GDD §10「撤退按钮始终在战斗中可点击」）。
const TEXT_RETREAT_BUTTON: String = "撤退"

## 顶部条高度（px）→ anchor 百分比（60/1080）。
const TOPBAR_HEIGHT_RATIO: float = 60.0 / 1080.0
## 敌方区高度（~340px → 340/1080）。
const ENEMY_AREA_HEIGHT_RATIO: float = 340.0 / 1080.0
## 己方区高度（~340px → 340/1080）。
const ALLY_AREA_HEIGHT_RATIO: float = 340.0 / 1080.0
## 底部条高度（~180px → 180/1080）。
const BOTTOMBAR_HEIGHT_RATIO: float = 180.0 / 1080.0

## === 过渡常量（UX Transitions & Animations）=================================

## 顶部条滑入时长（秒，ease-out）。
const T_TOPBAR_SEC: float = 0.3
## 敌方区淡入时长（延迟 0.1s）。
const T_ENEMY_SEC: float = 0.4
const T_ENEMY_DELAY_SEC: float = 0.1
## 己方区淡入时长（延迟 0.2s）。
const T_ALLY_SEC: float = 0.4
const T_ALLY_DELAY_SEC: float = 0.2
## 底部条滑入时长（延迟 0.3s）。
const T_BOTTOMBAR_SEC: float = 0.3
const T_BOTTOMBAR_DELAY_SEC: float = 0.3
## 滑入位移距离（px——从区域外滑入的偏移量，瞬态视觉参数非布局值）。
const SLIDE_OFFSET_PX: float = 60.0

## === 中线颜色（UX「全宽 1px 淡墨」）=========================================

const MIDLINE_COLOR: Color = Color(0.30, 0.30, 0.32, 0.6)

## === 瞬态视觉状态（§2.1 豁免——过渡一次性）==================================

## 进场过渡 Tween 句柄（重入 kill 重建）。
var _entrance_tween: Tween = null
## 减少动态标志（进场时从设置读取——进场后静态，零轮询）。
var reduce_motion: bool = false

## === 子节点引用（_build_layout 创建）=========================================

var topbar: Control = null
var enemy_area: Control = null
var midline: Control = null
var ally_area: Control = null
var bottombar: Control = null
## 右上角撤退按钮位（内容/点击行为归 008/interaction）。
var retreat_button_slot: Control = null
## 暂停按钮位（顶部条内——点击/ESC 转发 hud 暂停菜单，菜单本体归 hud 005）。
var pause_button_slot: Control = null

## 音频管理器引用（进入战斗触发 set_state(IN_COMBAT)——依赖注入，
## 未注入时静默跳过：story AC-7 消费 audio-manager API， AudioManager 由
## SceneManager 持有（ADR-0031 §1.2 零新增 Autoload））。
var _audio_manager: AudioManager = null

## 顶部条三组件组装器（story 004——阶段指示器/阵法区/战斗日志）。
var combat_topbar: CombatTopbar = null

## 底部条三组件组装器（story 005——费用栏/牌库计数/结束出牌按钮）。
var combat_bottombar: CombatBottombar = null

## 手牌区组装器（story 006——弧形渲染/灰显/灵能预览/敌方卡背）。
var hand_area: HandArea = null

## 备战面板（story 007——战斗开始前的部署界面；默认隐藏，由场景挂载侧
## 经 [method show_deploy_panel] 打开）。
var deploy_panel: DeployPanel = null

## 结算/撤退/渡劫警示宿主（story 008——默认隐藏，由战斗结束/撤退按钮/
## 渡劫进战前三个入口打开）。
var settlement_host: Node = null

## 反馈编排器（story 003——伤害飘字/HP 条合并刷新/阵亡淡出；生产实例化点）。
## 由场景挂载侧经 [method setup_feedback] 注入信号源与 hp_reader_cb；
## 未注入时不出反馈（不报错——UI 骨架可独立测试）。
var feedback: CombatFeedbackCoordinator = null

## 角色卡装配台（Sprint 18——把敌我名册变成战场角色卡并注册进 [member feedback]）。
## [b]类型为 Node[/b]：新脚本的全局 class_name 依赖导入缓存，用 Node + 鸭子类型
## 调用可避免「首次导入前解析失败」的次序问题（同 CombatScene 对组件的处理）。
var actor_stage: Node = null

## 撤退按钮（story 008——右上角常驻，渲染态始终可点；点击开撤退确认弹窗）。
var retreat_button: Button = null


## 注入音频管理器（战斗场景挂载时由 SceneManager.get_audio_manager() 传入）。
func set_audio_manager(p_audio_manager: AudioManager) -> void:
	_audio_manager = p_audio_manager


## 请求进入战斗音频状态（AC-7——仅触发 set_state(IN_COMBAT) 请求，
## 过渡矩阵实现归 audio-manager story 004）。未注入时无操作（布局骨架
## 独立于音频系统可测试）。
func request_in_combat_audio() -> void:
	if _audio_manager != null:
		_audio_manager.set_state(AudioEnums.AudioState.IN_COMBAT)


## 构建五区域容器 + 按钮位（_init 构建——不依赖场景树时序）。
func _init() -> void:
	_build_layout()


## 进场过渡编排（UX Transitions：滑入/淡入序列 + ≤2s 全可见）。[br]
## [param p_reduce_motion]: true 直接就位无动画（UX 减少动态替代）。[br]
## [b]编排[/b]：顶部条上方滑入 0.3s → 敌方区淡入 0.4s（延迟 0.1s）→
## 己方区淡入 0.4s（延迟 0.2s）→ 底部条下方滑入 0.3s（延迟 0.3s）。
## 串行总时长 0.3+0.1+0.4+0.2+0.4+0.3+0.3 = 2.0s 上限内（UX AC）。
func play_entrance(p_reduce_motion: bool = false) -> void:
	reduce_motion = p_reduce_motion
	if p_reduce_motion:
		_kill_entrance_tween()
		_reset_zone_transforms()
		return
	_kill_entrance_tween()
	# 起始态：滑入类区域移出 + 淡入类区域透明
	topbar.position.y -= SLIDE_OFFSET_PX
	topbar.modulate.a = 0.0
	enemy_area.modulate.a = 0.0
	ally_area.modulate.a = 0.0
	bottombar.position.y += SLIDE_OFFSET_PX
	bottombar.modulate.a = 0.0
	_entrance_tween = create_tween()
	_entrance_tween.set_parallel(true)
	# 顶部条：上方滑入 0.3s（ease-out）
	_entrance_tween.tween_property(topbar, "position:y",
			topbar.position.y + SLIDE_OFFSET_PX, T_TOPBAR_SEC) \
			.from(topbar.position.y - SLIDE_OFFSET_PX * 2.0) \
			.set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(topbar, "modulate:a", 1.0, T_TOPBAR_SEC)
	# 敌方区：淡入 0.4s 延迟 0.1s
	_entrance_tween.tween_property(enemy_area, "modulate:a", 1.0, T_ENEMY_SEC) \
			.set_delay(T_ENEMY_DELAY_SEC)
	# 己方区：淡入 0.4s 延迟 0.2s
	_entrance_tween.tween_property(ally_area, "modulate:a", 1.0, T_ALLY_SEC) \
			.set_delay(T_ALLY_DELAY_SEC)
	# 底部条：下方滑入 0.3s 延迟 0.3s（ease-out）
	_entrance_tween.tween_property(bottombar, "position:y",
			bottombar.position.y - SLIDE_OFFSET_PX, T_BOTTOMBAR_SEC) \
			.set_delay(T_BOTTOMBAR_DELAY_SEC) \
			.set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(bottombar, "modulate:a", 1.0,
			T_BOTTOMBAR_SEC).set_delay(T_BOTTOMBAR_DELAY_SEC)


## 布局就位（无过渡终态——reduce_motion 路径 + 测试断言基准）。
func _reset_zone_transforms() -> void:
	for zone: Control in [topbar, enemy_area, ally_area, bottombar]:
		if zone != null:
			zone.modulate.a = 1.0
	# anchor 布局下 position 由容器排布——滑入偏移在 reduce_motion 路径不应用
	# （play_entrance 的位移只作为过渡起始态，reset 恢复 modulate 即可）


## === 内部 ====================================================================

## 构建五区域 + 按钮位（anchor 百分比——1920×1080 基准换算）。
func _build_layout() -> void:
	# 顶部条：顶部全宽 60px
	topbar = _make_zone("TopBar")
	_anchor_ratio(topbar, 0.0, 0.0, 1.0, TOPBAR_HEIGHT_RATIO)
	add_child(topbar)
	# 敌方区：上半场中央 ~340px（顶部条下方）
	enemy_area = _make_zone("EnemyArea")
	_anchor_ratio(enemy_area, 0.0, TOPBAR_HEIGHT_RATIO, 1.0,
			TOPBAR_HEIGHT_RATIO + ENEMY_AREA_HEIGHT_RATIO)
	add_child(enemy_area)
	# 中线分隔：水平中分线全宽（自绘 1px 淡墨线）
	midline = _make_zone("Midline")
	_anchor_ratio(midline, 0.0, 0.5, 1.0, 0.5)
	add_child(midline)
	midline.custom_minimum_size.y = 1.0
	midline.draw.connect(_draw_midline.bind(midline))
	# 己方区：下半场中央 ~340px
	ally_area = _make_zone("AllyArea")
	_anchor_ratio(ally_area, 0.0, 0.5, 1.0, 0.5 + ALLY_AREA_HEIGHT_RATIO)
	add_child(ally_area)
	# 底部条：底部全宽 ~180px
	bottombar = _make_zone("BottomBar")
	_anchor_ratio(bottombar, 0.0, 1.0 - BOTTOMBAR_HEIGHT_RATIO, 1.0, 1.0)
	add_child(bottombar)
	# 暂停按钮位（顶部条右端——内容归 004，转发归 hud 005）
	pause_button_slot = _make_zone("PauseButtonSlot")
	pause_button_slot.custom_minimum_size = Vector2(48, 48)
	_anchor_ratio(pause_button_slot, 1.0 - 48.0 / 1920.0, 6.0 / 1080.0,
			1.0 - 6.0 / 1920.0, 6.0 / 1080.0 + 48.0 / 1080.0)
	topbar.add_child(pause_button_slot)
	# 顶部条三组件组装器（story 004——日志入口/阶段指示器/阵法区；
	# 系统信号接线由场景挂载侧经 bind_signals 注入）
	combat_topbar = CombatTopbar.new()
	combat_topbar.name = "CombatTopbar"
	combat_topbar.anchor_left = 0.0
	combat_topbar.anchor_right = 1.0 - 60.0 / 1920.0  # 留出暂停按钮位右端
	combat_topbar.anchor_top = 0.0
	combat_topbar.anchor_bottom = 1.0
	combat_topbar.offset_left = 8.0
	combat_topbar.offset_top = 6.0
	combat_topbar.offset_bottom = -6.0
	topbar.add_child(combat_topbar)
	# 底部条三组件组装器（story 005——费用栏/牌库计数/结束出牌按钮；
	# 系统信号接线由场景挂载侧经 bind_signals 注入）
	combat_bottombar = CombatBottombar.new()
	combat_bottombar.name = "CombatBottombar"
	combat_bottombar.anchor_left = 0.0
	combat_bottombar.anchor_right = 1.0
	combat_bottombar.anchor_top = 0.5
	combat_bottombar.anchor_bottom = 1.0
	combat_bottombar.offset_left = 8.0
	combat_bottombar.offset_top = 8.0
	combat_bottombar.offset_bottom = -8.0
	bottombar.add_child(combat_bottombar)
	# 手牌区组装器（story 006——弧形渲染/灰显/灵能预览/敌方卡背；
	# 全屏覆盖层，卡牌按全屏坐标弧形定位——挂在根末层（bottombar 之上）；
	# 系统信号接线由场景挂载侧经 bind_signals 注入）
	hand_area = HandArea.new()
	hand_area.name = "HandArea"
	hand_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_area.anchor_left = 0.0
	hand_area.anchor_right = 1.0
	hand_area.anchor_top = 0.0
	hand_area.anchor_bottom = 1.0
	hand_area.offset_left = 0.0
	hand_area.offset_top = 0.0
	hand_area.offset_right = 0.0
	hand_area.offset_bottom = 0.0
	add_child(hand_area)
	# 撤退按钮位（右上角常驻——独立于顶部条，内容/行为归 008/interaction）
	retreat_button_slot = _make_zone("RetreatButtonSlot")
	retreat_button_slot.custom_minimum_size = Vector2(48, 48)
	add_child(retreat_button_slot)
	retreat_button_slot.anchor_left = 1.0 - 60.0 / 1920.0
	retreat_button_slot.anchor_right = 1.0 - 12.0 / 1920.0
	retreat_button_slot.anchor_top = 60.0 / 1080.0 + 8.0 / 1080.0
	retreat_button_slot.anchor_bottom = 60.0 / 1080.0 + 8.0 / 1080.0 + 48.0 / 1080.0
	# 撤退按钮本体（story 008——渲染态始终可点；点击流转由场景挂载侧接线）
	retreat_button = Button.new()
	retreat_button.name = "RetreatButton"
	retreat_button.text = TEXT_RETREAT_BUTTON
	retreat_button.custom_minimum_size = Vector2(48, 48)
	retreat_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 渲染态常驻可点（GDD §10）——disabled 恒 false，锁栈仲裁归 interaction
	retreat_button.disabled = not RetreatRulesScript.retreat_button_always_enabled()
	retreat_button_slot.add_child(retreat_button)
	# 点击转发到结算宿主（未注入依赖前宿主只开空确认弹窗——无副作用）
	retreat_button.pressed.connect(open_retreat_dialog)
	# 反馈编排器（story 003——生产实例化点；全屏透明层，飘字池挂在其下）。
	# [b]层级[/b]：手牌区之上、备战/结算覆盖层之下——飘字盖住角色卡但不遮面板。
	feedback = FeedbackScript.new()
	feedback.name = "CombatFeedback"
	feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(feedback)
	# 角色卡装配台（Sprint 18——敌我名册 → 战场角色卡 → 注册进反馈编排器）
	actor_stage = ActorStageScript.new()
	actor_stage.name = "ActorStage"
	add_child(actor_stage)
	actor_stage.call(&"set_containers", ally_area, enemy_area)
	# 备战面板（story 007——全屏覆盖层，默认隐藏；数据/信号接线由场景挂载侧注入）
	deploy_panel = DeployPanelScript.new()
	deploy_panel.name = "DeployPanel"
	deploy_panel.anchor_left = 0.0
	deploy_panel.anchor_right = 1.0
	deploy_panel.anchor_top = 0.0
	deploy_panel.anchor_bottom = 1.0
	deploy_panel.offset_left = 120.0
	deploy_panel.offset_top = 80.0
	deploy_panel.visible = false
	add_child(deploy_panel)
	# 结算/撤退/渡劫警示宿主（story 008——全屏覆盖层，默认隐藏；信号接线
	# 由场景挂载侧经 SettlementHost.setup 注入）
	settlement_host = SettlementHostScript.new()
	settlement_host.name = "SettlementHost"
	settlement_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(settlement_host)


## 打开备战面板（数据与信号接线由场景挂载侧在调用前经 [method DeployPanel.setup] 完成）。[br]
## [param p_max_deploy]: 当前境界上场人数上限。[br]
## [param p_realm_id]: 当前境界 ID（决定阵位布局预览）。[br]
## [param p_battle_title]: 战斗名称标题。[br]
## [br][b]未注入依赖时[/b]（审查 H1）：面板只能出空骨架——此处 push_warning 显式暴露，
## 避免「生产路径静默空面板」。
func show_deploy_panel(p_max_deploy: int, p_realm_id: int, p_battle_title: String) -> void:
	if deploy_panel == null:
		return
	if not deploy_panel.has_sources():
		push_warning("CombatLayout.show_deploy_panel: 未注入 gsm/card_system——"
				+ "面板将显示空名册（由场景挂载侧调用 DeployPanel.setup() 修复）")
	deploy_panel.set_battle_title(p_battle_title)
	# 单次取数下发（审查 H2）：max_deploy/realm_id 与名册同一次 apply_roster，
	# 避免「先按默认上限 0 刷新一遍」导致首轮全部误判为可替换 + 双重建卡
	deploy_panel.load_roster(p_max_deploy, p_realm_id)
	deploy_panel.visible = true


## 关闭备战面板（确认出战/返回探索后由上层调用）。
func hide_deploy_panel() -> void:
	if deploy_panel != null:
		deploy_panel.visible = false


## 注入结算宿主依赖（story 008——战斗系统/卡组系统/渡劫标识；
## 由场景挂载侧在战斗场景装配时调用）。[br]
## [param p_combat_system]: 战斗系统（[code]battle_ended[/code] /
## [code]retreat_requested[/code] 信号源）。[br]
## [param p_deck_system]: 卡组系统（卡组满判定取数）。[br]
## [param p_is_tribulation]: 是否渡劫战（撤退变体与战前警示的开关）。
func setup_settlement(p_combat_system: Node, p_deck_system: Node = null,
		p_is_tribulation: bool = false) -> void:
	if settlement_host == null:
		push_warning("CombatLayout.setup_settlement: 结算宿主未装配——"
				+ "战斗结束/撤退面板将不可用")
		return
	settlement_host.setup(p_combat_system, p_deck_system, p_is_tribulation)


## 渡劫战前警示（AC-8——备战界面之上弹出）。[br]
## [br][b]返回[/b]: 是否真的弹出了弹窗（非渡劫战或已确认过时为 false）。
func show_pre_battle_warning() -> bool:
	if settlement_host == null:
		push_warning("CombatLayout.show_pre_battle_warning: 结算宿主未装配")
		return false
	return settlement_host.show_pre_battle_warning()


## 装配反馈编排器（伤害飘字 / HP 条 / 阵亡淡出的生产接线）。[br]
## [param p_combat_system] 信号源——[code]character_damaged[/code] /
## [code]character_died[/code] / [code]battle_ended[/code]（CombatSystem）。[br]
## [param p_deployment_system] 信号源——[code]standby_cleared[/code] /
## [code]character_deployed[/code]（DeploymentSystem，可空）。[br]
## [param p_hp_reader] HP 终值读取 Callable——[code]func(character_id) ->
## {current, max}[/code]（生产传 [code]Callable(CombatSystem, "get_character_hp")[/code]）。[br]
## [param p_card_system] 卡牌系统（角色卡初始 ATK/HP 模板回退，可空）。[br]
## [param p_binding_manager] 绑定管理器（图标数预留接缝，可空）。[br]
## [param p_reduce_motion] 减少动态（进场时读到的设置值——飘字/阵亡动画的
## 静态替代开关）。[br]
## [br][b]副作用[/b]：把信号源接进 [member feedback]，并把角色卡装配台
## [member actor_stage] 与反馈编排器绑定——此后 [method build_battle_roster]
## 建的卡会自动注册。
func setup_feedback(p_combat_system: Node, p_deployment_system: Node,
		p_hp_reader: Callable, p_card_system: Node = null,
		p_binding_manager: Node = null, p_reduce_motion: bool = false) -> void:
	if feedback == null:
		push_warning("CombatLayout.setup_feedback: 反馈编排器未装配")
		return
	feedback.setup([p_combat_system, p_deployment_system], null, p_hp_reader,
			p_reduce_motion)
	if actor_stage != null:
		actor_stage.call(&"setup", p_combat_system, p_deployment_system,
				p_card_system, p_binding_manager)
		actor_stage.call(&"bind_coordinator", feedback)


## 按开战名册构建战场角色卡（开战入口调用）。[br]
## [param p_player_ids] 开战配置里的我方角色 ID（空 → 回退读 DeploymentSystem 阵位）。[br]
## [br][b]为什么在开战后调用[/b]：敌方名册快照由 [code]battle_start[/code] 定格，
## HP 也由它种子——先开战再建卡，卡片首帧就拿到真实 HP/ATK（不是「0/0 等刷新」）。
func build_battle_roster(p_player_ids: Array = []) -> void:
	if actor_stage == null:
		return
	actor_stage.call(&"build_roster", p_player_ids)


## 清空战场角色卡（战斗结束 / 场景退场——防悬空注册与残留）。
func clear_battle_roster() -> void:
	if actor_stage != null:
		actor_stage.call(&"clear_roster")


## 打开撤退确认弹窗（AC-6/AC-7——撤退按钮点击或战斗系统撤退请求触发）。
func open_retreat_dialog() -> void:
	if settlement_host != null:
		settlement_host.request_retreat()


## 区域容器工厂（Control——内容后续 story 填充）。
func _make_zone(zone_name: String) -> Control:
	var zone := Control.new()
	zone.name = zone_name
	return zone


## anchor 百分比设置（统一入口——story 禁止像素绝对定位）。
func _anchor_ratio(zone: Control, left: float, top: float, right: float, bottom: float) -> void:
	zone.anchor_left = left
	zone.anchor_top = top
	zone.anchor_right = right
	zone.anchor_bottom = bottom
	zone.offset_left = 0
	zone.offset_top = 0
	zone.offset_right = 0
	zone.offset_bottom = 0


## 中线绘制（1px 淡墨——draw 信号接自绘 zone）。
func _draw_midline(zone: Control) -> void:
	if zone.size.y <= 0.0:
		return
	zone.draw_line(Vector2(0, zone.size.y * 0.5),
			Vector2(zone.size.x, zone.size.y * 0.5), MIDLINE_COLOR, 1.0)


func _kill_entrance_tween() -> void:
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	_entrance_tween = null
