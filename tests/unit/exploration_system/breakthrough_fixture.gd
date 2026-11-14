extends GutTest
## BreakthroughFixture —— 打坐/洞府突破用例的共享装置（单元测试侧）。[br]
## [br][b]为什么单独一处[/b]：用例文件要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「怎么摆玩家状态、怎么挑种子」与
## 「断言什么」是两件事（同 [code]craft_node_fixture.gd[/code] 先例）。[br]
## [br][b]文件前缀[/b]：本文件不以 [code]test_[/code] 开头——GUT 按前缀收集，因此它
## 只作为基类被继承，不会被当作用例文件单独执行。[br]
## [br][b]数值全部读配置[/b]：所需修为 / 成功率 / 惩罚比例都从
## [code]RealmSystem.realm_table[/code] 与 [code]ExplorationBreakthroughTable[/code]
## 读出，装置里[b]不写死[/b] 1000 / 0.10 这类字面量——改配置不会让用例失效。[br]
## [br][b]装置[/b]：真实 GSM（Autoload）+ 真实 RealmSystem，用例前后快照还原
## [code]player[/code]（同 [code]test_exploration_harvest[/code] 口径）。[br]
##
## 来源: design/gdd/cultivation-system.md §4/§6/§边界/§调优参数、
## docs/decisions/ADR-0010 §realm_up 编排器。

const BreakthroughScript := preload(
		"res://src/feature/exploration/exploration_breakthrough.gd")
const TableScript := preload(
		"res://src/feature/exploration/exploration_breakthrough_table.gd")
const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
## 既有境界配置表（唯一真理来源——用例拿它做[b]期望值[/b]，不另抄一份数字）。
const RealmScript := preload("res://src/core/realm_system.gd")

## 炼气期——用例默认境界（最低档，成功率与惩罚都取配置首档）。
const REALM_QI: int = 1
## 种子扫描上限（成功率最低档也有 10% 命中率，千次足够）。
const SEED_SCAN: int = 1000

var es: Node = null
var service: RefCounted = null
## 炼气期突破所需修为（由配置读出——每个用例的算账基准）。
var required: int = 0
var _player_before: Dictionary = {}


func before_each() -> void:
	_player_before = (GameStateManager.player as Dictionary).duplicate(true)
	required = TableScript.required_cultivation(REALM_QI)
	es = ES_SCRIPT.new()
	es.set("_dag_ready", true)
	service = BreakthroughScript.new(es)
	_reset_player(REALM_QI, required)


func after_each() -> void:
	GameStateManager.player = _player_before
	if es != null:
		es.free()
		es = null
	service = null


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 摆好玩家状态（修为上限默认按境界表读——不硬编码）。[br]
## [br][param p_max_override] ≥0 时覆盖上限（用于「惩罚大于持有量」的边界用例）。
func _reset_player(p_realm: int, p_cultivation: int, p_max_override: int = -1) -> void:
	GameStateManager.player.realm = p_realm
	GameStateManager.player.cultivation = p_cultivation
	GameStateManager.player.max_cultivation = p_max_override if p_max_override >= 0 \
			else TableScript.required_cultivation(p_realm)
	GameStateManager.player.cultivation_full = false


## 注入一颗固定种子的随机源（同种子同结果的唯一开关——生产路径自建随机实例）。
func _inject_seed(p_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	service.set("rng", rng)


## 注入一颗「必成」的种子。
func _inject_success_seed(p_realm: int) -> void:
	_inject_seed(find_seed(p_realm, true))


## 注入一颗「必败」的种子。
func _inject_failure_seed(p_realm: int) -> void:
	_inject_seed(find_seed(p_realm, false))


## 找一颗掷出指定结果的种子——从 0 起顺序扫描，结果确定。[br]
## [br][b]为什么不写死字面量[/b]：成功率来自配置表，改档位会换掉首个命中种子；
## 扫描让用例对数值调整免疫，同时保持确定性（扫描顺序固定）。
func find_seed(p_realm: int, p_want_success: bool) -> int:
	var rate: float = TableScript.success_rate_for(p_realm)
	for candidate: int in SEED_SCAN:
		var probe := RandomNumberGenerator.new()
		probe.seed = candidate
		if TableScript.roll_success(probe, rate) == p_want_success:
			return candidate
	fail_test("在 %d 个种子里找不到「%s」的结果（成功率 %.2f）"
			% [SEED_SCAN, "成功" if p_want_success else "失败", rate])
	return -1
