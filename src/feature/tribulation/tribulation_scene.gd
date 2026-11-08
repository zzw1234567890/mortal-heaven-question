extends "res://src/feature/combat/combat_scene.gd"
## TribulationScene —— 渡劫战斗薄容器场景（Sprint 18 场景补链）。
##
## [b]角色[/b]：闭合 [constant SceneManager.SCENE_PATHS] 的 TRIBULATION 路径
## （[code]res://src/feature/tribulation/tribulation_scene.tscn[/code]）——此前该路径
## 无资产，探索渡劫台「确认渡劫」的转场必然回退主菜单。[br]
## [br][b]与 COMBAT 的差别[/b]：同一战场根（[code]CombatRoot[/code]），额外三件事：[br]
##   1. [member is_tribulation] = true —— 结算宿主走红框 80% 撤退变体 + 渡劫战前警示；[br]
##   2. 进战前尝试 [method TribulationSystem.start_tribulation_combat]（该方法自带
##      「非 PREPARING 状态」守卫——探索侧未走准备流程时降级为普通开战）；[br]
##   3. 战斗结束的胜负处理由 [code]TribulationSystem._on_battle_ended[/code] 消费
##      （渡劫成功/失败结算属 tribulation-system epic，不在本容器）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本容器只读 [code]player.realm[/code] 等
## 展示用数值，不写任何游戏状态。
##
## @experimental
## 来源: ADR-0005、ADR-0021（渡劫系统）、ADR-0031、gate-check §B1。

## 渡劫战斗标题（GDD §渡劫准备界面）。
const TEXT_TRIBULATION_TITLE: String = "⚡ 渡劫"


func _ready() -> void:
	is_tribulation = true
	super._ready()


## 备战面板标题——渡劫专用文案（父类默认「遭遇战」）。
func _deploy_title() -> String:
	return TEXT_TRIBULATION_TITLE


## 开战——优先走渡劫系统委托（其内部进入 IN_COMBAT 状态并组装 boss config）。[br]
## [br][b]降级路径[/b]：渡劫系统不可用或状态非 PREPARING（例如玩家直接从节点图
## 撞上渡劫台）时退回父类的最小开战，并 push_warning 说明——避免玩家卡在
## 空战场无法离开。
func _start_battle(character_ids: Array) -> void:
	var ts: Node = _autoload(&"TribulationSystem")
	var cs: Node = _combat()
	if ts != null and ts.has_method(&"start_tribulation_combat") \
			and cs != null and cs.has_method(&"is_battle_active") \
			and not bool(cs.call(&"is_battle_active")):
		ts.call(&"start_tribulation_combat")
		if bool(cs.call(&"is_battle_active")):
			return
		push_warning("TribulationScene: 渡劫系统未接战（状态非 PREPARING）——"
				+ "降级为普通开战")
	super._start_battle(character_ids)
