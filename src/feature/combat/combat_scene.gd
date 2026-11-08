extends Control
## CombatScene —— 战斗薄容器场景（Sprint 18 场景补链）。
##
## [b]角色[/b]：闭合 [constant SceneManager.SCENE_PATHS] 的 COMBAT 路径
## （[code]res://src/feature/combat/combat_scene.tscn[/code]）。此前该路径无资产——
## 节点图「进入战斗」经 [method SceneManager.request_scene_change] 校验通过后
## 加载失败，[code]scene_transition.gd[/code] 走「目标场景缺失 → 回退 MAIN_MENU」，
## 核心循环第一跳出口断路（gate-check 2026-11-08 §B1）。[br]
## [br][b]结构[/b]：root Control 挂载 [code]CombatRoot[/code]（combat-ui-layout
## story 001-008 交付的战场根：四区域 + 顶部/底部条 + 手牌区 + 备战面板 +
## 结算宿主）；本容器只做依赖注入与信号接线，不持有游戏状态。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不缓存战斗/卡组/角色状态；卡组上限、
## 回合阶段等一切数值经注入系统现读。[br]
## [br][b]零轮询[/b]（ADR-0031 §3）：无 [code]_process()[/code]——信号驱动。[br]
## [br][b]接线边界[/b]：出牌/目标选择/拖拽/确认出战的持久写入归
## [code]combat-ui-interaction[/code] epic（0/9 未实现）。本容器只接通
## [b]转场与面板生命期[/b]：备战确认 → [code]battle_start[/code]；备战返回/撤退确认 →
## 经 SceneManager 回探索；战斗结束 → 由 [code]CombatSystem[/code] 自行请求
## RESULT_SCREEN / DEFEAT_SCREEN 转场（[method CombatSystem._request_scene_change]）。[br]
## [br][b]自动开战[/b]：本容器[b]不[/b]自动 [code]battle_start[/code]——敌方卡组与出战
## 阵容来源属 interaction epic（story 006 的 config 扩展契约），当前以备战面板
## 「确认出战」为唯一开战入口。
##
## @experimental
## 来源: ADR-0005（场景切换唯一仲裁）、ADR-0031（表现层基线）、ADR-0008（战斗
## 生命周期）、gate-check-presentation-layer-complete-2026-11-08 §B1、
## combat-ui-layout Story 001-008。

## 战场根场景——实例化后由本容器注入依赖（脚本 new() 不会加载 .tscn 节点）。
const CombatRootScene := preload("res://src/ui/combat/layout/CombatRoot.tscn")
## SettingsStore 脚本常量——reduce_motion 偏好读取（S17 同源口径）。
const SettingsStoreScript := preload("res://src/ui/main_menu/settings_store.gd")
## SceneManager 脚本常量——SceneID / TransitionType 单一真理来源。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")

## 备战面板标题（GDD §8 备战阶段 UI）。
const TEXT_BATTLE_TITLE: String = "⚔ 遭遇战"

## [b]测试注入[/b]：可选——为 null 时按 /root 查找 Autoload。
var combat_system: Node = null
var deck_system: Node = null
var scene_manager: Node = null

## 战场根实例（[method _ready] 挂载）。
var combat_root: Control = null
## 是否渡劫战（子类/挂载侧在 [method _ready] 前设定；AC-7 变体开关）。
var is_tribulation: bool = false
## [b]测试注入[/b]：reduce_motion 覆盖（null = 读 SettingsStore）。
var reduce_motion_override: Variant = null


func _ready() -> void:
	combat_root = CombatRootScene.instantiate()
	add_child(combat_root)
	_wire_audio()
	_wire_panels()
	_wire_deployment()
	combat_root.call(&"play_entrance", _read_reduce_motion())


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
			_autoload(&"DeploymentSystem"), _autoload(&"BindingManager"))
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
## combat-ui-interaction story 006。
func _start_battle(character_ids: Array) -> void:
	var cs: Node = _combat()
	if cs == null or not cs.has_method(&"battle_start"):
		push_error("CombatScene: CombatSystem 不可用——战斗未开始")
		return
	if cs.has_method(&"is_battle_active") and bool(cs.call(&"is_battle_active")):
		return  # 已开战——重复确认守卫
	cs.call(&"battle_start", {
		"character_ids": character_ids.duplicate(),
		"layout": [],
		"is_tribulation": is_tribulation,
	})


## 备战返回——回探索（音频矩阵 COMBAT_TO_EXPLORE 行）。
func _on_deploy_back() -> void:
	_request_exploration()


## 撤退确认——战斗活跃时走战斗系统结算（battle_end → DEFEAT_SCREEN）；未开战
## 时直接回探索（防「未开战的撤退」把玩家困在战斗场景）。
func _on_retreat_confirmed() -> void:
	var cs: Node = _combat()
	if cs != null and cs.has_method(&"confirm_retreat") \
			and cs.has_method(&"is_battle_active") \
			and bool(cs.call(&"is_battle_active")):
		cs.call(&"confirm_retreat")
		return
	_request_exploration()


## 战败面板确认返回探索（战败/撤退结算面板的出口）。
func _on_defeat_confirmed() -> void:
	_request_exploration()


## 请求回探索——唯一导航入口（ADR-0005；禁止直调 change_scene_to_file）。[br]
## [br][b]from 动态取当前场景[/b]：转场完成后 [code]_current_scene_id[/code] 已为
## COMBAT（PauseMenu / MainMenu 同源先例——不写魔数）。
func _request_exploration() -> void:
	var sm: Node = _scene_manager()
	if sm == null or not sm.has_method(&"request_scene_change"):
		push_error("CombatScene: SceneManager 不可用——返回探索中止")
		return
	var from_id: int = SceneManagerScript.SceneID.COMBAT
	if sm.has_method(&"get_current_scene_id"):
		from_id = int(sm.call(&"get_current_scene_id"))
	sm.call(&"request_scene_change", from_id,
			SceneManagerScript.SceneID.EXPLORATION,
			SceneManagerScript.TransitionType.COMBAT_TO_EXPLORE)


# ═══════════════════════════════════════════════════════════════════════════════
# 数据现读（零缓存）
# ═══════════════════════════════════════════════════════════════════════════════

## 当前境界 ID（[member GameStateManager.player].realm；缺失回退 1 = 炼气）。
func _realm_id() -> int:
	var gsm: Node = _autoload(&"GameStateManager")
	if gsm == null:
		return 1
	var player: Variant = gsm.get("player")
	if player is Dictionary:
		return int((player as Dictionary).get("realm", 1))
	return 1


## 当前境界上场人数上限（RealmSystem 只读查询；缺失回退 2 = 炼气默认）。
func _max_deploy() -> int:
	var rs: Node = _autoload(&"RealmSystem")
	if rs == null or not rs.has_method(&"get_current_property"):
		return 2
	return maxi(int(rs.call(&"get_current_property", &"max_deploy")), 1)


## 读取减少动态偏好——注入覆盖优先，否则读 SettingsStore 画面分类。
func _read_reduce_motion() -> bool:
	if reduce_motion_override != null:
		return bool(reduce_motion_override)
	var store: RefCounted = SettingsStoreScript.new()
	var gfx: Dictionary = store.load_graphics_category()
	return bool(gfx.get(SettingsStoreScript.GFX_KEY_REDUCE_MOTION, false))


## 战斗系统——注入优先，否则 /root/CombatSystem。
func _combat() -> Node:
	if combat_system != null:
		return combat_system
	return _autoload(&"CombatSystem")


## 卡组系统——注入优先，否则 /root/DeckEditingSystem（[code]get_deck_summary[/code]）。
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
