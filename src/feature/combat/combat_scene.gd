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
## [br][b]表现层装配[/b]：音频 / 面板 / 备战 / 反馈 / 结算回流 / 出牌交互六组接线
## 全部委托 [code]combat_scene_mounting.gd[/code]；开战建卡后由开战前置放行输入。[br]
## [br][b]开战上下文[/b]：探索节点带进来的敌方阵容 / 等级 / 掉落 / 玩家阵容经
## [code]combat_launch_context.gd[/code] 跨场景传递，本容器 [code]_ready[/code] 一次性
## 取走（[code]combat_scene_launch.gd[/code]）；缺字段时开战给可读失败，
## [b]不再兜底默认遭遇资源[/b]。
##
## @experimental
## 来源: ADR-0005（场景切换唯一仲裁）、ADR-0031（表现层基线）、ADR-0008（战斗
## 生命周期）、gate-check-presentation-layer-complete-2026-11-08 §B1、
## combat-ui-layout Story 001-008。

## 战场根场景——实例化后由本容器注入依赖（脚本 new() 不会加载 .tscn 节点）。
const CombatRootScene := preload("res://src/ui/combat/layout/CombatRoot.tscn")
## 表现层装配（音频 / 面板 / 备战 / 反馈 / 结算回流 / 出牌交互）。
const MountingScript := preload("res://src/feature/combat/combat_scene_mounting.gd")
## 只读取数模块——境界 / 上场上限 / 不动效偏好（容器不承载取数逻辑）。
const ReadersScript := preload("res://src/feature/combat/combat_scene_readers.gd")
## 出口与撤退流转（备战返回 / 撤退确认 / 战败确认 / 回探索）。
const ExitsScript := preload("res://src/feature/combat/combat_scene_exits.gd")
## 探索侧开战上下文消费（敌方阵容 / 等级 / 掉落 / 玩家阵容——可读失败）。
const LaunchScript := preload("res://src/feature/combat/combat_scene_launch.gd")
## 开战守卫与执行（布阵 / 牌堆 / 敌方阵容——本容器只负责「何时开战」）。
const LauncherScript := preload("res://src/feature/combat/combat_scene_battle_launcher.gd")

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
## 遭遇战配置覆盖（null = 无显式配置；渡劫 / 精英节点可注入变体）。[br]
## [b]仅测试与特殊变体使用[/b]——探索路径一律经 [member launch_context_override]
## 或跨场景缓存，不再读默认遭遇资源兜底。
var encounter: Resource = null
## 敌方阵容覆盖（测试 / 特殊变体已生成运行时名册时的入口；空 = 走开战上下文）。
var enemy_roster_override: Array = []
## [b]测试注入[/b]：显式开战上下文（非空时优先于跨场景缓存）。
var launch_context_override: Dictionary = {}

## 结算回流接线（battle_ended → CombatResultView——结算/战败场景据此取数）。
var result_bridge: RefCounted = null
## 行囊挂载（底部条入口 + 面板 + 出牌输入冻结——退场时 unbind）。
var bag_mount: RefCounted = null
## 探索侧开战上下文（[method _ready] 一次性取走——空 = 无上下文，开战给可读失败）。
var launch: RefCounted = null
## 开战被拒的可读失败文案（空串 = 未失败；UI/测试据此展示原因）。
var launch_failure: String = ""

## 只读取数模块 / 出牌交互接线 / 出口流转（各自惰性创建或 _ready 创建）。
var _readers_instance: RefCounted = null
var interaction_wiring: RefCounted = null
var exits: RefCounted = null


## 退场先断开结算发布器——信号源是常驻 Autoload，不断开会让旧容器继续发布。[br]
## [br][b]行囊也要退订[/b]：它接的是底部条按钮（场景内节点）与出牌输入开关；
## 不关面板就退场会把交互层留在「停用」态，下一次进战斗点不动牌。
func _exit_tree() -> void:
	if result_bridge != null:
		result_bridge.call(&"unbind")
	result_bridge = null
	if bag_mount != null:
		bag_mount.call(&"unbind")
	bag_mount = null
	if interaction_wiring != null:
		interaction_wiring.call(&"unbind")
	interaction_wiring = null


func _ready() -> void:
	combat_root = CombatRootScene.instantiate()
	add_child(combat_root)
	_consume_launch_context()
	exits = ExitsScript.new()
	exits.call(&"setup", _combat(), _scene_manager())
	# 七组表现层接线（音频 / 面板 / 备战 / 反馈 / 结算回流 / 出牌交互 / 行囊）
	var mounting: RefCounted = MountingScript.new(self, combat_root)
	var wired: Dictionary = mounting.call(&"wire_all", _on_deploy_confirmed,
			_on_deploy_back, _on_retreat_confirmed, _on_defeat_confirmed)
	result_bridge = wired.get("result_bridge")
	interaction_wiring = wired.get("interaction_wiring")
	bag_mount = wired.get("bag_mount")
	combat_root.call(&"play_entrance", _read_reduce_motion())


## 探索侧开战上下文——一次性取走并做契约校验。[br]
## [br][b]校验失败不阻断场景挂载[/b]：玩家仍可点「返回探索」离开；失败文案
## 经 [member launch_failure] 暴露，开战时再 push_error 并拒绝开战
## （避免带着空敌方阵容打一场判不出胜负的战斗）。[br]
## [br][b]为什么不在这里 push_error[/b]：[code]_ready[/code] 阶段的错误会被
## GUT 归罪到挂载场景的测试用例；失败留给 [method _start_battle] 的可读出口。
func _consume_launch_context() -> void:
	launch = LaunchScript.new()
	launch.call(&"consume", launch_context_override)
	launch_failure = str(launch.call(&"failure_text"))


# ═══════════════════════════════════════════════════════════════════════════════
# 出口（唯一导航入口 = SceneManager.request_scene_change）
# ═══════════════════════════════════════════════════════════════════════════════

## 确认出战——隐藏备战面板并发起战斗（config 仅带已选角色；敌方卡组与阵位
## 布局的完整契约归 interaction story 006）。
func _on_deploy_confirmed(character_ids: Array) -> void:
	combat_root.call(&"hide_deploy_panel")
	_start_battle(character_ids)


## 开战是否必须有探索侧上下文（[b]子类覆写点[/b]）。[br]
## [br][b]为什么渡劫不需要[/b]：渡劫战由渡劫台直接进入，敌方配置由
## [code]TribulationSystem[/code] 组装（[code]tribulation_data.boss_config[/code]），
## 不经过探索战斗节点的「点节点 → 弹窗 → 转场」链路。
func _requires_launch_context() -> bool:
	return true


## 备战面板标题（子类覆写点——渡劫场景用渡劫标题）。[br]
## [br]探索侧给了遭遇展示名时以它为准（「⚔ 山道巡守」而非泛化的「⚔ 遭遇战」）。
func _deploy_title() -> String:
	if launch == null:
		return TEXT_BATTLE_TITLE
	return str(launch.call(&"title", TEXT_BATTLE_TITLE))


## 备战面板预选——把探索侧带来的玩家阵容点选上（玩家仍可改选；实现见
## [method CombatSceneLaunch.preselect]，容器只做转发）。
func _preselect_roster(p_deploy: Variant) -> void:
	if launch == null:
		return
	launch.call(&"preselect", p_deploy)


## 开战入口（[b]子类覆写点[/b]：渡劫场景改走 TribulationSystem 委托——
## 其状态机需在 battle_start 前进入 IN_COMBAT，否则结算不会被渡劫系统消费）。[br]
## [br][b]守卫与执行委托[/b] [code]combat_scene_battle_launcher.gd[/code]：
## 战斗系统可用 / 未在战斗中 / 开战上下文齐备，任一不满足即 push_error 并
## 拒绝开战（带着空敌方阵容开战只会得到一场判不出胜负的战斗）。
func _start_battle(character_ids: Array) -> void:
	var launcher: RefCounted = LauncherScript.new()
	var reason: String = launcher.call(&"start", _combat(), combat_root,
			interaction_wiring, launch, _requires_launch_context(), _launch_deps(),
			character_ids, _realm_id(), is_tribulation)
	if not reason.is_empty():
		push_error("CombatScene: " + reason)


## 开战前置的依赖包（AI / 布阵 / 卡组 / 显式遭遇 / 运行时名册）。
func _launch_deps() -> Dictionary:
	var ds: Node = deployment_system if deployment_system != null \
			else _autoload(&"DeploymentSystem")
	return {
		"ai": _autoload(&"AISystem"),
		"deployment": ds,
		"deck": _deck(),
		"encounter": encounter,
		"roster_override": enemy_roster_override,
	}


## 三个面板出口（备战返回 / 撤退确认 / 战败确认）——导航细节见
## [code]combat_scene_exits.gd[/code]（本容器只做转发）。
func _on_deploy_back() -> void:
	exits.call(&"on_deploy_back")


func _on_retreat_confirmed() -> void:
	exits.call(&"on_retreat_confirmed")


func _on_defeat_confirmed() -> void:
	exits.call(&"on_defeat_confirmed")


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


## 注入优先、否则查 Autoload 的三个依赖取数入口。
func _combat() -> Node:
	return combat_system if combat_system != null else _autoload(&"CombatSystem")


func _deck() -> Node:
	return deck_system if deck_system != null else _autoload(&"DeckEditingSystem")


func _scene_manager() -> Node:
	return scene_manager if scene_manager != null else _autoload(&"SceneManager")


## Autoload 动态查找（避免测试环境缺 Autoload 时的 NameError——同 CombatSystem 先例）。
func _autoload(node_name: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(node_name)))
