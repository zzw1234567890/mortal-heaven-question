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


## 渡劫不要求探索侧开战上下文——敌方配置由 [code]TribulationSystem[/code] 组装
## （[code]tribulation_data.boss_config[/code]），不经探索战斗节点链路。
func _requires_launch_context() -> bool:
	return false


## 开战——优先走渡劫系统委托（其内部进入 IN_COMBAT 状态并组装 boss config）。[br]
## [br][b]降级路径[/b]：渡劫系统不可用或状态非 PREPARING（例如玩家直接从节点图
## 撞上渡劫台）时退回父类的最小开战，并 push_warning 说明——避免玩家卡在
## 空战场无法离开。[br]
## [br][b]委托路径必须先自己备齐前置[/b]：父类 [method CombatScene._start_battle]
## 经 [code]combat_scene_battle_launcher[/code] 一次做完「备数据 → 开战」，
## 而本方法把开战交给了渡劫系统——那条路上没人替我们备数据。少掉洗牌的后果
## 不是「少洗一次」而是[b]开局发 0 张手牌[/b]（开局手牌在 [code]battle_start[/code]
## 里从牌堆发），玩家出不了牌、对局永远打不完、结算永远不触发（真机走查现场：
## 「≡牌库:0｜无手牌｜第 21 回合」）。故委托前先经父类的 [method CombatScene._setup_kit]
## 走 [code]arm_field_and_deck[/code]，接战后再走 [code]attach[/code]
## ——[b]顺序与实现只有那一个工厂一处[/b]。[br]
## [br][b]降级时不能重复备[/b]：走了委托就自己收尾并 return；只有确定降级才落到
## [code]super._start_battle[/code]（它会再备一次，重复布阵虽幂等但会把上面的
## 洗牌结果覆盖成同一副牌的另一次洗牌）。
func _start_battle(character_ids: Array) -> void:
	var ts: Node = _autoload(&"TribulationSystem")
	var cs: Node = _combat()
	if ts != null and ts.has_method(&"start_tribulation_combat") \
			and cs != null and cs.has_method(&"is_battle_active") \
			and not bool(cs.call(&"is_battle_active")):
		var kit: RefCounted = _setup_kit()
		kit.call(&"arm_field_and_deck", cs, character_ids)
		ts.call(&"start_tribulation_combat")
		if bool(cs.call(&"is_battle_active")):
			kit.call(&"attach", combat_root, interaction_wiring, character_ids)
			return
		push_warning("TribulationScene: 渡劫系统未接战（状态非 PREPARING）——"
				+ "降级为普通开战")
	super._start_battle(character_ids)
