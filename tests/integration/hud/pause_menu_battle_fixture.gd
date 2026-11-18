extends "res://tests/integration/hud/pause_menu_fixture.gd"
## PauseMenuBattleFixture —— 暂停菜单「战斗中存档」用例的共享装置。[br]
## [br][b]为什么再分一层[/b]：用例文件要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「怎么摆一场打到一半的仗」与「断言存了什么」
## 是两件事；战斗快照那三个替身只在验快照的用例里有意义，塞进基础装置会让
## [code]pause_menu_fixture.gd[/code] 继续膨胀（它已 300+ 行，本轮一例未增）。[br]
## [br][b]用法[/b]：子类 [code]extends "res://…/pause_menu_battle_fixture.gd"[/code]，
## 只写 [code]test_*[/code] 方法 + 调 [method arrange_battle]。[br]
## [br][b]文件前缀[/b]：不以 [code]test_[/code] 开头——GUT 按前缀收集，它只作为基类
## 被继承，不会被当作用例文件单独执行。[br]
## [br][b]替身全部由本文件提供[/b]——子类重复声明同名成员在 GDScript 里是解析错误，
## 整个子类文件会被 GUT 静默忽略（[code]Ignoring script … because it does not
## extend GutTest[/code]），用例一条都不跑。[br]
## [br][b]为什么不直引 Autoload[/b]：真实 CombatSystem 有 1600+ 行与一堆依赖，
## 而本组用例要验的是「快照取了哪几个数、写没写进去」——替身如实记账即可。[br]
## [br]来源: ADR-0008 §GSM 边界、ADR-0031 §2、本轮「战斗中存档 → 读档回到战斗」（A / D 项）。

## 载荷 / 上下文模块（键名与判据的真理来源）。
const PayloadScript := preload("res://src/feature/combat/battle_resume_payload.gd")
const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")

## 用例角色 ID 段（远离其它套件，防串场）。
const CHAR_A: int = 8841
const CHAR_B: int = 8842
## 来源节点 ID（读档回到战斗靠它认路）。
const NODE_ID: int = 773
## 敌人模板（载荷里落 String）。
const ENEMY_TEMPLATE: String = "san_xiu"
## 敌方残血（模板满血 16 扣到 6）——存没存住残血，是本组用例的核心证据。
const ENEMY_HP: int = 6
const ENEMY_MAX_HP: int = 16


## GSM 替身（本层版）——多出续战段的写入面：抓快照的落点是它。[br]
## [br][b]为什么如实记账而不是当哑巴[/b]：「这一仗真的写进去了吗」唯一的客观证据就是
## 这一笔；真实的 [code]_set_battle_resume[/code] 是 GSM 第二层原子方法。
class ResumeGsm:
	extends Node

	var payload: Dictionary = {"game_state": {"player": {"realm": 1}}}
	var battle_resume: Dictionary = {}
	var resume_writes: int = 0

	func serialize() -> Dictionary:
		return payload

	func _set_battle_resume(resume: Dictionary) -> void:
		battle_resume = resume.duplicate(true)
		resume_writes += 1


## 战斗系统替身——快照要读的四个面：活没活 / 打到哪 / 敌方名册 / 开战配置。[br]
## [br][b]HP 快照走 [code]snapshot_all[/code][/b]：与战斗内结算、结算回流同一取数口径
## （生产侧抓快照读的就是它，替身按同一形状作答才测得到真路径）。
class ResumeCombat:
	extends Node

	var active: bool = true
	var phase: int = 3
	var turn: int = 5
	var enemy_roster: Array = []
	var config: Dictionary = {}
	## [code]snapshot_all[/code] 的作答（我方侧，side = 0）。
	var player_hp: Dictionary = {}

	func is_battle_active() -> bool:
		return active

	func get_current_phase() -> int:
		return phase

	func get_turn_number() -> int:
		return turn

	func get_battle_enemy_roster() -> Array:
		return enemy_roster.duplicate(true)

	func get_battle_config() -> Dictionary:
		return config.duplicate(true)

	func get_roster_state() -> Variant:
		return _RosterSnapshot.new(player_hp)


## 状态表快照替身（只实现 [code]snapshot_all[/code]）——我方条目的形状按生产口径。
class _RosterSnapshot:
	extends RefCounted

	var _hp: Dictionary = {}

	func _init(p_hp: Dictionary) -> void:
		_hp = p_hp

	func snapshot_all() -> Array:
		var out: Array = []
		for cid: Variant in _hp.keys():
			var entry: Dictionary = _hp[cid]
			out.append({
				"character_id": int(cid), "side": 0,
				"current_hp": int(entry.get("current_hp", 0)),
				"max_hp": int(entry.get("max_hp", 0)),
				"is_alive": bool(entry.get("is_alive", true)),
			})
		return out


## 布阵系统替身——只实现快照要读的 [method get_field]（阵位列 + 前后排）。
class ResumeDeployment:
	extends Node

	var field: Array = []

	func get_field() -> Array:
		return field.duplicate(true)


var combat: ResumeCombat = null
var deployment: ResumeDeployment = null
var resume_gsm: ResumeGsm = null


func before_each() -> void:
	super()
	ContextScript.clear()
	CostSystem.clear_for_battle_end()
	combat = ResumeCombat.new()
	deployment = ResumeDeployment.new()
	resume_gsm = ResumeGsm.new()
	add_child(combat)
	add_child(deployment)
	add_child(resume_gsm)
	# 按需替身登记（基类 after_each 统一回收——留一个在树上会叠出第二个）
	_extras.append(combat)
	_extras.append(deployment)
	_extras.append(resume_gsm)
	# 三份替身注入菜单（费用不在此列——快照不注入它，走真实 CostSystem 由用例另摆）
	menu.combat_system = combat
	menu.deployment_system = deployment
	menu.gsm = resume_gsm
	menu.save_load = sl
	menu.scene_manager = sm
	sm.scene_id = SM.SceneID.COMBAT


func after_each() -> void:
	ContextScript.clear()
	CostSystem.clear_for_battle_end()
	super()


## 摆一场「打到一半」的仗：来源上下文 + 敌我双方 + 我方阵位 + 残血。[br]
## [br][b]为什么费用也摆[/b]：费用走真实 [code]CostSystem[/code]（快照不注入它），
## 摆一次才能证明「费用取的是存档那一刻的活值」而不是出厂值。
func arrange_battle() -> void:
	ContextScript.publish({
		ContextScript.KEY_NODE_ID: NODE_ID,
		ContextScript.KEY_COMBAT_TYPE: "boss",
		ContextScript.KEY_TEMPLATE_IDS: [ENEMY_TEMPLATE],
		ContextScript.KEY_ENEMY_LEVEL: 2,
		ContextScript.KEY_REWARDS: {"lingshi": 30},
		ContextScript.KEY_PLAYER_ROSTER: [CHAR_A, CHAR_B],
	})
	CostSystem.restore_for_battle(1, 4)
	deployment.field = [
		{"slot_index": 0, "character_id": CHAR_A, "is_front": true},
		{"slot_index": 3, "character_id": CHAR_B, "is_front": false},
	]
	combat.player_hp = {
		CHAR_A: {"current_hp": 4, "max_hp": 12, "is_alive": true},
		CHAR_B: {"current_hp": 5, "max_hp": 9, "is_alive": true},
	}
	combat.enemy_roster = [{
		"character_id": 100000, "template_id": ENEMY_TEMPLATE,
		"current_hp": ENEMY_HP, "max_hp": ENEMY_MAX_HP,
		"is_alive": true, "field_position": 0, "is_front_row": true,
	}]
	combat.config = {
		"character_ids": [CHAR_A, CHAR_B],
		"enemy_template_ids": [ENEMY_TEMPLATE],
		"enemy_level": 2,
		"rewards": {"lingshi": 30},
	}
