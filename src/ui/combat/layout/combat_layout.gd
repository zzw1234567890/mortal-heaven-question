class_name CombatLayout
extends Control
## CombatLayout —— 战场五区域骨架 + 场景信号门面（combat-ui-layout Story 001）。
##
## [b]职责[/b]：搭五区域容器 + 右上角撤退按钮位 + 暂停按钮位，并把「骨架 / 备战 / 结算 /
## 反馈 / 装配 / 过渡」各组的入口透传出去。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：布局常量为渲染参数，过渡进度是瞬态视觉状态
## （§2.1 豁免）。[b]零轮询[/b]：无 [code]_process()[/code]，过渡用一次性 Tween。[br]
## [br][b]装配已拆出[/b]（DEBT-CUI-007-2）：原为 465 行单体门面，现拆成
## [code]combat_layout_{zones,deploy,settlement,feedback,assembly,entrance}_mount.gd[/code]，
## 本类只留薄转发；对外 API 与节点树顺序不变（顺序即绘制层级）。[br]
## [br]下面标着「代理属性」的成员读写直达对应挂载模块（它是唯一持有者）。
##
## @experimental
## 来源: ADR-0031、design/ux/combat-ui.md §Layout Zones/§Transitions、DEBT-CUI-007-2。

const ZonesScript: GDScript = preload(
		"res://src/ui/combat/layout/combat_layout_zones.gd")
const DeployMountScript: GDScript = preload(
		"res://src/ui/combat/layout/combat_layout_deploy_mount.gd")
const SettlementMountScript: GDScript = preload(
		"res://src/ui/combat/layout/combat_layout_settlement_mount.gd")
const FeedbackMountScript: GDScript = preload(
		"res://src/ui/combat/layout/combat_layout_feedback_mount.gd")
const AssemblyMountScript: GDScript = preload(
		"res://src/ui/combat/layout/combat_layout_assembly_mount.gd")
const EntranceMountScript: GDScript = preload(
		"res://src/ui/combat/layout/combat_layout_entrance_mount.gd")

## 区域高度常量——引用骨架模块的单一定义（外部既有引用点保持不变，不抄数值）。
const TOPBAR_HEIGHT_RATIO: float = ZonesScript.TOPBAR_HEIGHT_RATIO
const ENEMY_AREA_HEIGHT_RATIO: float = ZonesScript.ENEMY_AREA_HEIGHT_RATIO
const ALLY_AREA_HEIGHT_RATIO: float = ZonesScript.ALLY_AREA_HEIGHT_RATIO
const BOTTOMBAR_HEIGHT_RATIO: float = ZonesScript.BOTTOMBAR_HEIGHT_RATIO

## 音频管理器引用（进入战斗触发 set_state(IN_COMBAT)——未注入时静默跳过）。
var _audio_manager: AudioManager = null

## 减少动态标志（进场时从设置读取——进场后静态，零轮询）。
var reduce_motion: bool = false

## 各组挂载模块（[method _build_overlays] 创建——各自持有其装配的节点）。
var _zones: RefCounted = null
var _deploy: RefCounted = null
var _settlement: RefCounted = null
var _feedback: RefCounted = null
var _assembly: RefCounted = null
var _entrance: RefCounted = null

# === 区域与装配节点的代理属性（挂载模块是唯一持有者）=======================

## 五区域容器（内容归后续 story 组件）。
var topbar: Control:
	get: return (_zones.topbar as Control) if _zones != null else null
	set(value):
		if _zones != null:
			_zones.topbar = value

var enemy_area: Control:
	get: return (_zones.enemy_area as Control) if _zones != null else null
	set(value):
		if _zones != null:
			_zones.enemy_area = value

var midline: Control:
	get: return (_zones.midline as Control) if _zones != null else null
	set(value):
		if _zones != null:
			_zones.midline = value

var ally_area: Control:
	get: return (_zones.ally_area as Control) if _zones != null else null
	set(value):
		if _zones != null:
			_zones.ally_area = value

var bottombar: Control:
	get: return (_zones.bottombar as Control) if _zones != null else null
	set(value):
		if _zones != null:
			_zones.bottombar = value

## 右上角撤退按钮位（内容/点击行为归 008/interaction）。
var retreat_button_slot: Control:
	get: return (_zones.retreat_button_slot as Control) if _zones != null else null
	set(value):
		if _zones != null:
			_zones.retreat_button_slot = value

## 暂停按钮位（顶部条内——点击/ESC 转发 hud 暂停菜单，菜单本体归 hud 005）。
var pause_button_slot: Control:
	get: return (_zones.pause_button_slot as Control) if _zones != null else null
	set(value):
		if _zones != null:
			_zones.pause_button_slot = value

## 顶部条 / 底部条 / 手牌区组装器（story 004/005/006）。
var combat_topbar: Control:
	get: return (_zones.combat_topbar as Control) if _zones != null else null
	set(value):
		if _zones != null:
			_zones.combat_topbar = value

var combat_bottombar: Control:
	get: return (_zones.combat_bottombar as Control) if _zones != null else null
	set(value):
		if _zones != null:
			_zones.combat_bottombar = value

var hand_area: Control:
	get: return (_zones.hand_area as Control) if _zones != null else null
	set(value):
		if _zones != null:
			_zones.hand_area = value

## 备战面板（story 007——默认隐藏，由 [method show_deploy_panel] 打开）。
var deploy_panel: DeployPanel:
	get: return (_deploy.panel as DeployPanel) if _deploy != null else null
	set(value):
		if _deploy != null:
			_deploy.panel = value

## 结算/撤退/渡劫警示宿主（story 008——默认隐藏）。
var settlement_host: Node:
	get: return (_settlement.host as Node) if _settlement != null else null
	set(value):
		if _settlement != null:
			_settlement.host = value

## 反馈编排器（story 003——伤害飘字 / HP 条 / 阵亡淡出的生产实例化点）。
var feedback: CombatFeedbackCoordinator:
	get:
		return (_feedback.coordinator as CombatFeedbackCoordinator) \
				if _feedback != null else null
	set(value):
		if _feedback != null:
			_feedback.coordinator = value

## 角色卡装配台（Sprint 18）。[b]类型宽松（Node）[/b]：其 class_name 依赖导入缓存，
## 鸭子类型调用可避免「首次导入前解析失败」的次序问题。
var actor_stage: Node:
	get: return (_assembly.stage as Node) if _assembly != null else null
	set(value):
		if _assembly != null:
			_assembly.stage = value

## 撤退按钮（story 008——右上角常驻，渲染态始终可点）。
var retreat_button: Button:
	get: return (_settlement.retreat_button as Button) if _settlement != null else null
	set(value):
		if _settlement != null:
			_settlement.retreat_button = value

## 进场过渡 Tween（代理属性——供测试断言「过渡已创建」）。
var _entrance_tween: Tween:
	get: return (_entrance.tween as Tween) if _entrance != null else null


## 构建区域骨架 + 五组挂载（[code]_init[/code] 构建——不依赖场景树时序）。
func _init() -> void:
	_zones = ZonesScript.new(self)
	_zones.call(&"build")
	_build_overlays()


## 注入音频管理器（战斗场景挂载时由 SceneManager.get_audio_manager() 传入）。
func set_audio_manager(p_audio_manager: AudioManager) -> void:
	_audio_manager = p_audio_manager


## 请求进入战斗音频状态（AC-7——仅触发 set_state(IN_COMBAT) 请求，未注入时无操作）。
func request_in_combat_audio() -> void:
	if _audio_manager != null:
		_audio_manager.set_state(AudioEnums.AudioState.IN_COMBAT)


# ═══════════════════════════════════════════════════════════════════════════════
# 门面转发——参数与副作用详见各挂载模块的同名方法
# ═══════════════════════════════════════════════════════════════════════════════

## 进场过渡编排（UX Transitions：≤2s 全可见；[param p_reduce_motion] 为 true 时直接就位）。
func play_entrance(p_reduce_motion: bool = false) -> void:
	reduce_motion = p_reduce_motion
	_entrance.call(&"play", topbar, enemy_area, ally_area, bottombar, p_reduce_motion)


## 打开备战面板（依赖注入由场景挂载侧在调用前完成）。
func show_deploy_panel(p_max_deploy: int, p_realm_id: int, p_battle_title: String) -> void:
	_deploy.call(&"show_panel", p_max_deploy, p_realm_id, p_battle_title)


## 关闭备战面板（确认出战 / 返回探索后由上层调用）。
func hide_deploy_panel() -> void:
	_deploy.call(&"hide_panel")


## 注入结算宿主依赖（战斗系统 / 卡组系统 / 渡劫标识）。
func setup_settlement(p_combat_system: Node, p_deck_system: Node = null,
		p_is_tribulation: bool = false) -> void:
	_settlement.call(&"setup", p_combat_system, p_deck_system, p_is_tribulation)


## 渡劫战前警示（AC-8）。[b]返回[/b]: 是否真的弹出了弹窗。
func show_pre_battle_warning() -> bool:
	return bool(_settlement.call(&"show_pre_battle_warning"))


## 打开撤退确认弹窗（AC-6/AC-7——撤退按钮或战斗系统撤退请求触发）。
func open_retreat_dialog() -> void:
	_settlement.call(&"open_retreat_dialog")


## 装配反馈编排器（伤害飘字 / HP 条 / 阵亡淡出的生产接线）。[br]
## [param p_hp_reader] HP 终值读取 Callable（生产传 [code]Callable(CombatSystem,
## "get_character_hp")[/code]）。[b]副作用[/b]：同时把角色卡装配台与编排器绑定。
func setup_feedback(p_combat_system: Node, p_deployment_system: Node,
		p_hp_reader: Callable, p_card_system: Node = null,
		p_binding_manager: Node = null, p_reduce_motion: bool = false) -> void:
	_feedback.call(&"setup", [p_combat_system, p_deployment_system], p_hp_reader,
			p_reduce_motion)
	_assembly.call(&"setup", p_combat_system, p_deployment_system, p_card_system,
			p_binding_manager, feedback)


## 按开战名册建卡（开战后调用——敌方快照与 HP 种子由 battle_start 定格）。[br]
## [param p_player_ids] 我方角色 ID（空 → 回退读 DeploymentSystem 阵位）。
func build_battle_roster(p_player_ids: Array = []) -> void:
	_assembly.call(&"build_roster", p_player_ids)


## 清空战场角色卡（战斗结束 / 场景退场——防悬空注册与残留）。
func clear_battle_roster() -> void:
	_assembly.call(&"clear_roster")


## UI 出牌请求——裁定施法者后转交 [code]CombatSystem.play_card()[/code]。
func play_card(p_card_instance_id: int, p_target_indices: Array) -> bool:
	return bool(_assembly.call(&"play_card", p_card_instance_id, p_target_indices))


## 当前裁定出的施法者角色 ID（无阵位 / 全阵亡时为 -1）。
func current_caster_id() -> int:
	return int(_assembly.call(&"current_caster_id"))


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：装配
# ═══════════════════════════════════════════════════════════════════════════════

## 五组挂载。[b]构建次序即节点次序[/b]（后者盖前者）：反馈层在手牌区之上、
## 备战 / 结算覆盖层最后——飘字盖住角色卡但不遮面板（节点树契约由
## test_layout_mount_facade 锁死）。
func _build_overlays() -> void:
	_entrance = EntranceMountScript.new(self)
	_feedback = FeedbackMountScript.new(self)
	_feedback.call(&"build")
	_assembly = AssemblyMountScript.new(self)
	_assembly.call(&"build", ally_area, enemy_area)
	_deploy = DeployMountScript.new(self)
	_deploy.call(&"build")
	_settlement = SettlementMountScript.new(self)
	_settlement.call(&"build", retreat_button_slot)
