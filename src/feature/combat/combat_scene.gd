extends Control
## CombatScene —— 战斗薄容器场景（Sprint 18 场景补链）。
##
## [b]角色[/b]：闭合 [constant SceneManager.SCENE_PATHS] 的 COMBAT 路径
## （[code]res://src/feature/combat/combat_scene.tscn[/code]）。此前该路径无资产——
## 节点图「进入战斗」经 [method SceneManager.request_scene_change] 校验通过后
## 加载失败，[code]scene_transition.gd[/code] 走「目标场景缺失 → 回退 MAIN_MENU」，
## 核心循环第一跳出口断路（gate-check 2026-11-08 §B1）。[br]
## [br][b]结构[/b]：root Control 挂载 [code]CombatRoot[/code]（combat-ui-layout
## story 001-008 交付的战场根）；本容器只做依赖注入与信号接线，不持有游戏状态。[br]
## [br][b]零状态所有权 / 零轮询[/b]（ADR-0031 §2/§3）：不缓存战斗/卡组/角色状态，
## 数值一律现读（[code]combat_scene_readers.gd[/code]）；无 [code]_process()[/code]。[br]
## [br][b]接线边界[/b]：本容器只接通[b]转场与面板生命期[/b]——备战确认 → [code]battle_start[/code]；
## 备战返回/撤退确认 → 经 SceneManager 回探索；战斗结束由 [code]CombatSystem[/code] 自行
## 请求 RESULT_SCREEN / DEFEAT_SCREEN。[b]不自动开战[/b]：以备战面板「确认出战」为唯一入口。[br]
## [br][b]出牌交互[/b]：输入层与手牌供给委托 [code]combat_scene_interaction.gd[/code]
## （[method _wire_interaction] 装配，开战建卡后 [code]enable()[/code] 放行）。
##
## @experimental
## 来源: ADR-0005（场景切换唯一仲裁）、ADR-0031（表现层基线）、ADR-0008（战斗
## 生命周期）、gate-check-presentation-layer-complete-2026-11-08 §B1、
## combat-ui-layout Story 001-008。

## 战场根场景——实例化后由本容器注入依赖（脚本 new() 不会加载 .tscn 节点）。
const CombatRootScene := preload("res://src/ui/combat/layout/CombatRoot.tscn")
## 结算回流接线——battle_ended → CombatResultView（Sprint 18 结算回流）。
const ResultBridgeScript := preload("res://src/ui/combat/shared/combat_result_bridge.gd")
## 只读取数模块——境界 / 上场上限 / 不动效偏好（容器不承载取数逻辑）。
const ReadersScript := preload("res://src/feature/combat/combat_scene_readers.gd")
## 出牌交互接线（输入层 + 手牌供给——交互契约，非转场逻辑）。
const InteractionScript := preload("res://src/feature/combat/combat_scene_interaction.gd")
## 出口与撤退流转（备战返回 / 撤退确认 / 战败确认 / 回探索）。
const ExitsScript := preload("res://src/feature/combat/combat_scene_exits.gd")

## 备战面板标题（GDD §8 备战阶段 UI）。
const TEXT_BATTLE_TITLE: String = "⚔ 遭遇战"

## [b]测试注入[/b]：可选——为 null 时按 /root 查找 Autoload。
var combat_system: Node = null
var deck_system: Node = null
var scene_manager: Node = null
var deployment_system: Node = null

## 战场根实例（[method _ready] 挂载）。
var combat_root: Control = null
## 是否渡劫战（子类/挂载侧在 [method _ready] 前设定；AC-7 变体开关）。
var is_tribulation: bool = false
## [b]测试注入[/b]：reduce_motion 覆盖（null = 读 SettingsStore）。
var reduce_motion_override: Variant = null

## 结算回流接线（battle_ended → CombatResultView——结算/战败场景据此取数）。
var result_bridge: RefCounted = null

## 只读取数模块实例（境界 / 上场上限 / 不动效偏好——惰性创建）。
var _readers_instance: RefCounted = null
## 出牌交互接线（输入层 + 手牌供给——[method _wire_interaction] 创建）。
var interaction_wiring: RefCounted = null
## 出口与撤退流转（[method _ready] 创建）。
var exits: RefCounted = null


## 退场先断开结算发布器——信号源是常驻 Autoload，不断开会让旧容器继续发布。
func _exit_tree() -> void:
	if result_bridge != null:
		result_bridge.call(&"unbind")
	result_bridge = null
	if interaction_wiring != null:
		interaction_wiring.call(&"unbind")
	interaction_wiring = null


func _ready() -> void:
	combat_root = CombatRootScene.instantiate()
	add_child(combat_root)
	exits = ExitsScript.new()
	exits.call(&"setup", _combat(), _scene_manager())
	_wire_audio()
	_wire_panels()
	_wire_deployment()
	_wire_feedback()
	_wire_result_bridge()
	_wire_interaction()
	combat_root.call(&"play_entrance", _read_reduce_motion())


## 结算回流接线——订阅 battle_ended，把载荷折成 CombatResultView 并发布到
## 跨场景缓存（结算/战败场景据此读回）。[br]
## [br][b]为什么在场景侧接而不在战斗系统内发布[/b]：战斗系统属 Feature 层，
## 不应知道「有 UI 要显示战绩」；发布时机与展示端同属表现层（ADR-0031 §2）。[br]
## [br][b]降级[/b]：战斗系统不可用时静默跳过（同 [method _wire_feedback]）。
func _wire_result_bridge() -> void:
	var cs: Node = _combat()
	if cs == null:
		return
	result_bridge = ResultBridgeScript.new()
	result_bridge.call(&"bind", cs)


## 出牌交互层 + 手牌供给——装配与开关全部委托 [code]combat_scene_interaction.gd[/code]
## （手势入口、供牌时机、退订；本容器只负责「何时开战 / 何时退场」）。
func _wire_interaction() -> void:
	interaction_wiring = InteractionScript.new()
	interaction_wiring.call(&"wire", combat_root, _combat(), _autoload(&"CostSystem"),
			_read_reduce_motion())


## 音频——注入 AudioManager 并请求进入战斗音频状态（AC-7；未注入时静默跳过）。
func _wire_audio() -> void:
	var sm: Node = _scene_manager()
	if sm == null or not sm.has_method(&"get_audio_manager"):
		return
	var am: Variant = sm.call(&"get_audio_manager")
	if am != null:
		combat_root.call(&"set_audio_manager", am)
	combat_root.call(&"request_in_combat_audio")


## 顶部条/底部条/手牌区信号接线（数据源现读 Autoload——缺失时静默跳过，
## 各组件自带 null 守卫）。
func _wire_panels() -> void:
	var cs: Node = _combat()
	var topbar: Variant = combat_root.get("combat_topbar")
	if topbar != null:
		topbar.call(&"bind_signals", cs, _autoload(&"FormationSystem"))
	var bottombar: Variant = combat_root.get("combat_bottombar")
	if bottombar != null:
		bottombar.call(&"bind_signals", cs, _autoload(&"CostSystem"))
		bottombar.call(&"set_reduce_motion", _read_reduce_motion())
	var hand: Variant = combat_root.get("hand_area")
	if hand != null:
		hand.call(&"bind_signals", cs)
		hand.call(&"set_reduce_motion", _read_reduce_motion())
	# 结算/撤退/渡劫警示宿主（交接后战斗结束 → 面板；确认信号走下方出口）
	combat_root.call(&"setup_settlement", cs, _deck(), is_tribulation)
	if is_tribulation:
		combat_root.call(&"show_pre_battle_warning")


## 备战面板——注入依赖、下发名册并打开（与战斗系统信号接线由本容器负责）。
func _wire_deployment() -> void:
	var deploy: Variant = combat_root.get("deploy_panel")
	if deploy == null:
		return
	deploy.call(&"setup", _autoload(&"GameStateManager"), _autoload(&"CardSystem"),
			deployment_system if deployment_system != null else _autoload(&"DeploymentSystem"),
			_autoload(&"BindingManager"))
	deploy.connect(&"confirm_requested", _on_deploy_confirmed)
	deploy.connect(&"back_requested", _on_deploy_back)
	combat_root.call(&"show_deploy_panel", _max_deploy(), _realm_id(),
			_deploy_title())
	# 结算宿主出口（持久写入归 interaction epic——本容器只做最小闭环：
	# 撤退确认 → 战斗系统；战败确认 → 回探索）
	var host: Variant = combat_root.get("settlement_host")
	if host != null:
		host.connect(&"retreat_confirmed", _on_retreat_confirmed)
		host.connect(&"defeat_confirmed", _on_defeat_confirmed)


## 战斗表现层接线（Sprint 18 / DEBT-CBT-018-1 残留闭环）。[br]
## 把 [code]CombatFeedbackCoordinator[/code] 从「只有测试在用」变成生产组件：
## 信号源接 CombatSystem + DeploymentSystem，HP 终值走
## [code]Callable(CombatSystem, "get_character_hp")[/code]——UI 不缓存 HP。[br]
## [br][b]降级[/b]：战斗系统不可用时静默跳过（不把「缺数据源」变成崩溃）。
func _wire_feedback() -> void:
	var cs: Node = _combat()
	if cs == null:
		return
	var reader: Callable = Callable()
	if cs.has_method(&"get_character_hp"):
		reader = Callable(cs, &"get_character_hp")
	combat_root.call(&"setup_feedback", cs,
			deployment_system if deployment_system != null else _autoload(&"DeploymentSystem"),
			reader, _autoload(&"CardSystem"), _autoload(&"BindingManager"),
			_read_reduce_motion())


# ═══════════════════════════════════════════════════════════════════════════════
# 出口（唯一导航入口 = SceneManager.request_scene_change）
# ═══════════════════════════════════════════════════════════════════════════════

## 确认出战——隐藏备战面板并发起战斗（config 仅带已选角色；敌方卡组与阵位
## 布局的完整契约归 interaction story 006）。
func _on_deploy_confirmed(character_ids: Array) -> void:
	combat_root.call(&"hide_deploy_panel")
	_start_battle(character_ids)


## 备战面板标题（子类覆写点——渡劫场景用渡劫标题）。
func _deploy_title() -> String:
	return TEXT_BATTLE_TITLE


## 开战入口（[b]子类覆写点[/b]：渡劫场景改走 TribulationSystem 委托——
## 其状态机需在 battle_start 前进入 IN_COMBAT，否则结算不会被渡劫系统消费）。[br]
## [br]默认实现只保证「有阵容 → 战斗开始」的最小闭环；config 扩展契约见
## combat-ui-interaction story 006。[br]
## [br][b]阵位落地[/b]：先把所选角色写入 `DeploymentSystem.setup_field()`——
## Phase 6 END 的「己方全灭」判据读的就是阵位，不先布阵会让「阵位从未有人」
## 被读成「信息不足」，阵亡永远判不出战败（combat_end_check.gd 的信息不足原则）。
func _start_battle(character_ids: Array) -> void:
	var cs: Node = _combat()
	if cs == null or not cs.has_method(&"battle_start"):
		push_error("CombatScene: CombatSystem 不可用——战斗未开始")
		return
	if cs.has_method(&"is_battle_active") and bool(cs.call(&"is_battle_active")):
		return  # 已开战——重复确认守卫
	_setup_field(character_ids)
	cs.call(&"battle_start", {
		"character_ids": character_ids.duplicate(),
		"layout": [],
		"is_tribulation": is_tribulation,
	})
	# 开战后再建卡：敌方名册快照与 HP 种子都由 battle_start 定格，
	# 卡片首帧即拿到真实 HP/ATK（先建卡会读到 0/0）。
	combat_root.call(&"build_battle_roster", character_ids.duplicate())
	# 开完战、建完卡才放行输入并首次供牌（此前只有备战面板可交互）。
	if interaction_wiring != null:
		interaction_wiring.call(&"enable")


## 布阵——经 DeploymentSystem.setup_field 落位（失败不阻断开战：无阵位时
## 胜负判定走「信息不足则不判」，但战斗本身仍可进行）。
func _setup_field(character_ids: Array) -> void:
	var ds: Node = deployment_system
	if ds == null:
		ds = _autoload(&"DeploymentSystem")
	if ds == null or not ds.has_method(&"setup_field"):
		return
	if not bool(ds.call(&"setup_field", character_ids.duplicate(), {})):
		push_warning("CombatScene: 布阵失败（角色不可用或超出境界上限）——战斗继续，阵位为空")


## 备战返回——回探索（实现见 [code]combat_scene_exits.gd[/code]）。
func _on_deploy_back() -> void:
	exits.call(&"on_deploy_back")


## 撤退确认——战斗活跃走战斗系统结算；未开战直接回探索。
func _on_retreat_confirmed() -> void:
	exits.call(&"on_retreat_confirmed")


## 战败面板确认返回探索。
func _on_defeat_confirmed() -> void:
	exits.call(&"on_defeat_confirmed")


## 请求回探索——唯一导航入口（ADR-0005）。
func _request_exploration() -> void:
	exits.call(&"request_exploration")


# ═══════════════════════════════════════════════════════════════════════════════
# 数据现读（零缓存——实现见 combat_scene_readers.gd）
# ═══════════════════════════════════════════════════════════════════════════════

func _realm_id() -> int:
	return _readers().call(&"realm_id")


func _max_deploy() -> int:
	return _readers().call(&"max_deploy")

## 读取减少动态偏好——注入覆盖优先，否则读 SettingsStore 画面分类。
func _read_reduce_motion() -> bool:
	return bool(_readers().call(&"reduce_motion", reduce_motion_override))

## 只读取数模块（境界 / 上场上限 / 不动效偏好）——单例惰性创建。
func _readers() -> RefCounted:
	if _readers_instance == null:
		_readers_instance = ReadersScript.new()
	return _readers_instance

## 战斗系统——注入优先，否则 /root/CombatSystem。
func _combat() -> Node:
	if combat_system != null:
		return combat_system
	return _autoload(&"CombatSystem")

## 卡组系统——注入优先，否则 /root/DeckEditingSystem。
func _deck() -> Node:
	if deck_system != null:
		return deck_system
	return _autoload(&"DeckEditingSystem")

## SceneManager——注入优先，否则 /root/SceneManager。
func _scene_manager() -> Node:
	if scene_manager != null:
		return scene_manager
	return _autoload(&"SceneManager")

## Autoload 动态查找（避免测试环境缺 Autoload 时的 NameError——同 CombatSystem 先例）。
func _autoload(node_name: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(node_name)))
