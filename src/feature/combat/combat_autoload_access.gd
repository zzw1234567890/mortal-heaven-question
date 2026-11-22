extends RefCounted
## CombatAutoloadAccess —— 战斗域查找 Autoload 的唯一入口（从 combat_system.gd 集中）。[br]
## [br][b]为什么要单独一件[/b]：战斗域此前有 [b]三份[/b] 逐字重复的查找实现——
## [code]combat_system.gd[/code] 的 10 个 [code]_get_X()[/code]、
## [code]combat_rewards.gd[/code] / [code]combat_roster_ops.gd[/code] 各自私有的
## [code]_autoload()[/code] 副本，以及 [code]combat_phase_manager.gd[/code] 的第四个副本。
## 四处都写着「拿 SceneTree.root 找 /root/X，找不到返回 null」，改一处口径要改四遍。[br]
## [br][b]口径逐字不动[/b]（既有行为）：[br]
##   1. [b]经 SceneTree.root 查[/b]，不用 [code]get_node_or_null("/root/X")[/code]
##      的 Autoload 快捷路径——后者在 [code]--headless[/code] 与 GUT 的
##      [code]add_child_autofree[/code] 夹具下与前者可观察行为一致，但前者能显式处理
##      「没有 SceneTree」（[code]Engine.get_main_loop()[/code] 非 SceneTree）的情形；[br]
##   2. [b]测试环境缺该 Autoload 时返回 null，不抛错、不 push_error[/b]——
##      既有用例大量在「只有 CombatSystem 一条 Autoload」的裸树上跑，抛错会让它们全红；[br]
##   3. 返回的是 [Node] 而非具体类型，调用方自行 [code]has_method[/code] 守卫。[br]
## [br][b]为什么是 static[/b]：本件不持状态、不需要 [code]_parent[/code]，
## 做成静态方法后门面与各子模块直接 [code]CombatAutoloadAccess.find(&"X")[/code]，
## 不必各自持有实例——也就不会再有人复制第五份。[br]
## [br]来源: ADR-0008 §架构原则、tech-debt DEBT-CBT-018-3。

## Autoload 名字常量——与 [code]project.godot[/code] 的 [code][autoload][/code] 段逐字对应。
## 集中在此是为了让「战斗域依赖哪些全局单例」一眼可数（此前散在 10 个 getter 体内）。
const COST_SYSTEM: StringName = &"CostSystem"
const REALM_SYSTEM: StringName = &"RealmSystem"
const CARD_EFFECT_ENGINE: StringName = &"CardEffectEngine"
const CARD_SYSTEM: StringName = &"CardSystem"
const STATUS_EFFECT_SYSTEM: StringName = &"StatusEffectSystem"
const DEPLOYMENT_SYSTEM: StringName = &"DeploymentSystem"
const AI_SYSTEM: StringName = &"AISystem"
const RESOURCE_SYSTEM: StringName = &"ResourceSystem"
const CULTIVATION_SYSTEM: StringName = &"CultivationSystem"
const GAME_STATE_MANAGER: StringName = &"GameStateManager"
const SAVE_LOAD_SYSTEM: StringName = &"SaveLoadSystem"
const INPUT_MANAGER: StringName = &"InputManager"
const SCENE_MANAGER: StringName = &"SceneManager"


## 按 Autoload 名字查找节点——测试环境缺该 Autoload 或没有 SceneTree 时返回 null。[br]
## [br][param node_name] Autoload 名（用本件顶部的 [code]*_SYSTEM[/code] 常量）。
static func find(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(node_name)))
