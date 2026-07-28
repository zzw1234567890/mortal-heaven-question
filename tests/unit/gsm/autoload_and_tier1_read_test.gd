extends GutTest
## Story 001 验收测试：GSM Autoload 基础结构与第一层属性读取。
##
## 覆盖 AC-001、AC-002、AC-003 及补充边界测试。
## 测试通过 preload + .new() 创建独立 GSM 实例。
## [br]
## [b]注意:[/b] GSM 是 Autoload 无 class_name——通过 preload 获取脚本引用。
## 手动调用 _ready() 初始化（无需加入场景树——GSM 不依赖场景上下文）。

const GSM_SCRIPT := preload("res://src/foundation/game_state_manager.gd")

var gsm


func before_each() -> void:
	gsm = GSM_SCRIPT.new()
	gsm._ready()


func after_each() -> void:
	gsm.free()
	gsm = null


func test_initialized_flag_is_true() -> void:
	assert_true(gsm._initialized, "初始化后 _initialized 应为 true")


# ── 验收标准 AC-001 ──────────────────────────────────────────────────────

func test_ac001_default_realm_is_qi_refining() -> void:
	## AC-001: GSM 初始化完成 → player.realm 应为炼气
	assert_eq(gsm.player.realm, GSM_SCRIPT.RealmLevel.QI_REFINING, "初始境界应为 QI_REFINING (炼气)")


# ── 验收标准 AC-002 ──────────────────────────────────────────────────────

func test_ac002_initial_ling_shi_is_non_negative() -> void:
	## AC-002: GSM 初始化完成 → player.resources.ling_shi >= 0
	var ling_shi: int = gsm.player.resources.ling_shi
	assert_true(ling_shi >= 0, "初始灵石应 >= 0，实际值: %d" % ling_shi)


func test_ac002_initial_resources_all_zero() -> void:
	## AC-002 补充: 所有三项资源默认值均为 0
	assert_eq(gsm.player.resources.ling_shi, 0, "ling_shi 默认应为 0")
	assert_eq(gsm.player.resources.ling_cai, 0, "ling_cai 默认应为 0")
	assert_eq(gsm.player.resources.dan_yao_sui_pian, 0, "dan_yao_sui_pian 默认应为 0")


# ── 验收标准 AC-003 ──────────────────────────────────────────────────────

func test_ac003_get_path_equals_direct_access() -> void:
	## AC-003: get_state(path) 返回值应与直接属性读取一致
	var direct: int = gsm.player.realm
	var via_get: Variant = gsm.get_state("player.realm")
	assert_eq(direct, via_get, "get_state('player.realm') 应与 gsm.player.realm 一致")


func test_ac003_get_nested_path() -> void:
	## AC-003 补充: get_state() 对嵌套路径读取正确
	var ling_shi: int = gsm.player.resources.ling_shi
	var via_get: Variant = gsm.get_state("player.resources.ling_shi")
	assert_eq(ling_shi, via_get, "get_state('player.resources.ling_shi') 应与直接读取一致")


func test_get_nonexistent_domain_returns_null() -> void:
	## AC-003 边界: 不存在的域应返回 null
	var result: Variant = gsm.get_state("nonexistent.path")
	assert_null(result, "不存在的域应返回 null")


func test_get_nonexistent_key_returns_null() -> void:
	## AC-003 边界: 存在的域但 key 不存在应返回 null
	var result: Variant = gsm.get_state("player.nonexistent_key")
	assert_null(result, "存在的域但 key 不存在应返回 null")


func test_get_non_dict_intermediate_returns_null() -> void:
	## AC-003 边界: 路径中间层不是 Dictionary 时应返回 null
	var result: Variant = gsm.get_state("player.realm.subkey")
	assert_null(result, "中间层非字典类型应返回 null")


# ── 所有域初始化 ────────────────────────────────────────────────────────

func test_all_eight_domains_initialized() -> void:
	## 验证 8 个域全部初始化
	assert_false(gsm.meta.is_empty(), "meta 域应非空")
	assert_false(gsm.player.is_empty(), "player 域应非空")
	assert_false(gsm.collection.is_empty(), "collection 域应非空")
	assert_false(gsm.deck.is_empty(), "deck 域应非空")
	assert_null(gsm.battle, "battle 域初始应为 null")
	assert_false(gsm.exploration.is_empty(), "exploration 域应非空")
	assert_false(gsm.narrative.is_empty(), "narrative 域应非空")
	assert_false(gsm.session.is_empty(), "session 域应非空")


func test_progression_is_absent() -> void:
	## ADR-0012: progression 域不应存在于 GSM 中
	assert_null(gsm.get_state("progression"), "get_state('progression') 应返回 null")


# ── 玩家默认值 ──────────────────────────────────────────────────────────

func test_initial_cultivation_is_zero() -> void:
	assert_eq(gsm.player.cultivation, 0, "初始修为应为 0")


func test_max_cultivation_is_base_max() -> void:
	assert_eq(gsm.player.max_cultivation, 1000, "BASE_MAX 应为 1000")


func test_overflow_pool_is_zero() -> void:
	assert_eq(gsm.player.overflow_pool, 0, "溢出池初始为 0")


func test_identity_id_is_empty_string() -> void:
	assert_eq(gsm.player.identity_id, "", "初始身份 ID 应为空字符串")


func test_talents_array_is_empty() -> void:
	assert_true(gsm.player.talents.is_empty(), "初始天赋列表应为空数组")
