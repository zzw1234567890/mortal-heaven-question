extends GutTest
## GSMAtomicWrites 公开面锁定守卫——拆分重构前置护栏。
##
## [b]为什么需要这条守卫[/b]：[code]src/foundation/gsm/gsm_atomic_writes.gd[/code]（555 行）要按职责
## 拆成继承链。拆分的唯一硬约束是「对外 API 逐位不变」——方法名、形参个数、默认参数个数[b]与值[/b]、
## 实例字段，一个都不许改。危险在于[b]编译器不会替我们发现断链[/b]：[code]game_state_manager.gd[/code]
## 用 [code]load("res://src/foundation/gsm/gsm_atomic_writes.gd").new()[/code] 按[b]路径[/b]取这个类，
## 再经 [code]_atomic_writes.方法名(...)[/code] 的[b]按名动态分派[/b]转发全部 52 个方法
## （[code]_atomic_writes[/code] 的静态类型是 [code]RefCounted[/code]，编译器只认得出
## [code]RefCounted[/code] 自带的那些）——名字打错或漏拆只是运行时 [code]push_error[/code]，
## 不报语法错。
##
## [b]本类与前两轮（[code]combat_system[/code] / [code]deployment_system[/code]）的形态差异[/b]：
## 它不是 Autoload、没有 [code]class_name[/code]、也不被任何测试直接 [code]new()[/code]——
## 消费者只有 [code]game_state_manager.gd[/code] 一个（52 条同名转发 wrapper）。故本用例除了锁
## 反射面，还[b]额外锁住消费通道[/b]：52 个方法名在 GSM 实例上必须同样可按名解析。
##
## [b]锁什么[/b]：
##   · 52 个方法（29 含 [method init] 的公开 + 23 私有）的[形参个数 / 默认参数个数 / 默认参数值]
##   · 4 个实例字段存在且[b]未被 static 化[/b]（两个实例互不影响）
##   · 脚本级「零」面：0 信号 / 0 常量 / 0 枚举 / 无 [code]class_name[/code]——拆分时凭空多出
##     一个信号或全局名，会改变其他 Autoload 的解析环境
##   · [code]resource_path[/code] 逐字不变（GSM 按路径 [code]load[/code]，这是唯一的入口）
##   · 面内不得出现未登记的方法（新增/改名都要显式更新本快照）
##   · GSM 消费通道：52 个名字在 GSM 实例上全部可按名解析，且经 GSM 走一趟真写入仍生效
##   · 接缝仍接通：[method init] 之后三个子域委托对象全部就位
##
## [b]不锁什么[/b]：函数体实现、注释、成员落在哪个文件——这些正是拆分要动的东西。
##
## 来源: .claude/docs/coding-standards.md §文件行数限制（300 行软上限）、
## ADR-0001 §第二层原子写入、ADR-0006/0014/0015/0019/0021/0022/0023/0026 §GSM 集成合约。

const AW_SCRIPT := preload("res://src/foundation/gsm/gsm_atomic_writes.gd")
const GSM_SCRIPT := preload("res://src/foundation/game_state_manager.gd")

## 公开方法快照——[code]{方法名: [形参个数, [默认参数值...]]}[/code]，按反射实测值登记。
const EXPECTED_PUBLIC: Dictionary = {
	"add_card_to_collection": [1, []],
	"add_cultivation": [2, [""]],
	"add_required_event_completion": [1, []],
	"add_visited_node": [1, []],
	"advance_chapter": [1, []],
	"allocate_card_id": [0, []],
	"battle_end": [1, []],
	"battle_start": [1, []],
	"change_realm": [1, []],
	"clear_exploration_navigation": [0, []],
	"enable_validation": [1, []],
	"init": [1, []],
	"reincarnation_reset": [0, []],
	"remove_card_from_collection": [1, []],
	"reset_exploration_visited": [1, []],
	"restore_action_points": [1, []],
	"set_ending_chosen": [1, []],
	"set_exploration_ap": [2, []],
	"set_exploration_map": [1, []],
	"set_exploration_position": [2, []],
	"set_identity": [1, []],
	"set_input_locks": [1, []],
	"set_narrative_boss_defeated": [1, []],
	"set_narrative_boss_unlocked": [1, []],
	"set_narrative_flag": [2, []],
	"set_session_scene": [2, []],
	"set_talent": [2, []],
	"unlock_talent": [1, []],
	"update_exploration_map_state": [2, []],
}

## 私有方法快照——GSM 门面按名转发它们（[code]_set_battle_*[/code] / [code]_set_deck_*[/code] /
## [code]_set_resource_*[/code] 等），且产品代码里有 4 处 [code]gsm.call("_set_...")[/code]
## 直呼其名，同属「面」，一并锁。
const EXPECTED_PRIVATE: Dictionary = {
	"_increment_battle_turn": [0, []],
	"_retroactive_validate_collection": [0, []],
	"_set_battle_active": [1, []],
	"_set_battle_bindings": [1, []],
	"_set_battle_cost": [2, []],
	"_set_battle_deployment_snapshot": [1, []],
	"_set_battle_formation_snapshot": [1, []],
	"_set_battle_phase": [1, []],
	"_set_battle_resume": [1, []],
	"_set_battle_status_snapshot": [1, []],
	"_set_battle_turn": [1, []],
	"_set_consecutive_tribulation_failures": [1, []],
	"_set_deck_cards": [1, []],
	"_set_deck_change_log": [1, []],
	"_set_deck_limit_modifier": [1, []],
	"_set_deck_session_remove_count": [1, []],
	"_set_deck_slots": [1, []],
	"_set_player_character_hp": [2, []],
	"_set_player_unavailable_characters": [1, []],
	"_set_resource_ling_cai": [2, []],
	"_set_resource_ling_shi": [1, []],
	"_set_tribulation_state": [1, []],
	"_validate_card_ref": [1, []],
}

## 实例字段快照——拆分后仍是[b]实例[/b]字段（不得因搬文件误写成 static）。
const EXPECTED_FIELDS: Array[String] = [
	"_battle_writes", "_exploration_writes", "_gsm", "_narrative_writes",
]

## GSM 入口路径——[code]game_state_manager.gd[/code] 按这一串字符 load，逐字不变。
const EXPECTED_PATH: String = "res://src/foundation/gsm/gsm_atomic_writes.gd"

## 三个子域委托字段——[method init] 之后必须全部就位（接缝仍接通）。
const EXPECTED_SUBMODULES: Array[String] = [
	"_battle_writes", "_exploration_writes", "_narrative_writes",
]

var aw: RefCounted = null
var gsm: Node = null


func before_each() -> void:
	gsm = GSM_SCRIPT.new()
	gsm._ready()
	aw = AW_SCRIPT.new()
	aw.init(gsm)


func after_each() -> void:
	if aw != null:
		aw = null
	if gsm != null:
		gsm.free()
		gsm = null


## 反射收集方法表——[code]name -> {args, default_args}[/code]。
func _method_table() -> Dictionary:
	var table: Dictionary = {}
	for m: Dictionary in aw.get_method_list():
		table[String(m["name"])] = m
	return table


## 逐一比对快照中的方法：存在 + 形参个数 + 默认参数个数 + 默认参数值。
func _assert_methods(snapshot: Dictionary, label: String) -> void:
	var table: Dictionary = _method_table()
	var checked: int = 0
	for method_name: String in snapshot:
		var expected: Array = snapshot[method_name]
		assert_true(table.has(method_name), "%s方法 %s 应存在（拆分后不得丢）" % [label, method_name])
		if not table.has(method_name):
			continue
		var entry: Dictionary = table[method_name]
		var args: Array = entry.get("args", [])
		var defaults: Array = entry.get("default_args", [])
		var want_defaults: Array = expected[1]
		assert_eq(args.size(), int(expected[0]),
			"%s方法 %s 形参个数应不变" % [label, method_name])
		assert_eq(defaults.size(), want_defaults.size(),
			"%s方法 %s 默认参数个数应不变" % [label, method_name])
		assert_eq(defaults, want_defaults,
			"%s方法 %s 默认参数值应逐位不变" % [label, method_name])
		checked += 1
	assert_eq(checked, snapshot.size(), "%s方法快照应全部比对到" % label)


# ============================================================================
# 1. 方法面：29 公开（含 init）+ 23 私有，签名逐位不变
# ============================================================================

func test_public_methods_locked() -> void:
	assert_eq(EXPECTED_PUBLIC.size(), 29, "公开方法快照应 29 个")
	_assert_methods(EXPECTED_PUBLIC, "公开")


func test_private_methods_locked() -> void:
	assert_eq(EXPECTED_PRIVATE.size(), 23, "私有方法快照应 23 个")
	_assert_methods(EXPECTED_PRIVATE, "私有")


func test_no_untracked_script_methods() -> void:
	# 面内不得出现未登记的方法——新增/改名都要显式更新本快照。
	# 判据：get_method_list() 减去 RefCounted 及其祖先的内建方法，再减去已登记快照。
	var builtin: Dictionary = {}
	for m: Dictionary in ClassDB.class_get_method_list(&"RefCounted"):
		builtin[String(m["name"])] = true
	var untracked: Array[String] = []
	for m: Dictionary in aw.get_method_list():
		var method_name: String = String(m["name"])
		if builtin.has(method_name):
			continue
		if EXPECTED_PUBLIC.has(method_name) or EXPECTED_PRIVATE.has(method_name):
			continue
		if untracked.has(method_name):
			continue
		untracked.append(method_name)
	assert_eq(untracked.size(), 0, "不应出现未登记的方法：%s" % str(untracked))


# ============================================================================
# 2. 脚本级「零」面与入口路径：无信号 / 无常量 / 无枚举 / 无 class_name
# ============================================================================

func test_script_level_surface_is_empty() -> void:
	# 本类不含信号——它的「信号出口」全部走 GSM（[code]_gsm.card_collection_changed[/code]
	# 等）。拆分时误把某个方法写成信号，或凭空多出一个常量，都会改变脚本级面。
	assert_eq(aw.get_script().get_script_signal_list().size(), 0, "不应有脚本级信号")
	assert_eq(aw.get_script().get_script_constant_map().size(), 0, "不应有脚本级常量")
	# 实例信号表 -= RefCounted 内建信号（[code]script_changed[/code] / [code]property_list_changed[/code]）
	# ——剩下的就是本脚本自己声明的，应当为空。
	var builtin_signals: Dictionary = {}
	for s: Dictionary in ClassDB.class_get_signal_list(&"RefCounted"):
		builtin_signals[String(s["name"])] = true
	var own_signals: Array[String] = []
	for s: Dictionary in aw.get_signal_list():
		var signal_name: String = String(s["name"])
		if not builtin_signals.has(signal_name) and not own_signals.has(signal_name):
			own_signals.append(signal_name)
	assert_eq(own_signals.size(), 0, "实例信号表不应有自己声明的信号：%s" % str(own_signals))


func test_no_class_name_declared() -> void:
	# 本类靠[路径]被 load，没有 class_name——凭空加一个会多出一个全局符号，
	# 而 Autoload 全局名冲突正是本工程反复防的一类事故。
	assert_eq(aw.get_script().get_global_name(), &"", "不应声明 class_name")


func test_entry_path_unchanged() -> void:
	# GSM 用 load(这一串字符) 取类，路径即契约。
	assert_eq((AW_SCRIPT as Script).resource_path, EXPECTED_PATH,
		"入口路径应逐字不变（game_state_manager.gd 按路径 load）")


# ============================================================================
# 3. 字段面：4 个实例字段在册，且仍是实例字段（未被 static 化）
# ============================================================================

func test_instance_fields_locked() -> void:
	var found: Dictionary = {}
	for p: Dictionary in aw.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			found[String(p["name"])] = true
	for field_name: String in EXPECTED_FIELDS:
		assert_true(found.has(field_name), "实例字段 %s 应存在" % field_name)
	assert_eq(found.size(), EXPECTED_FIELDS.size(),
		"脚本实例字段应恰好 %d 个：%s" % [EXPECTED_FIELDS.size(), str(found.keys())])


func test_fields_not_staticized() -> void:
	# 两个实例互不影响——若拆分时把 var 误写成 static var，此处立刻变红。
	var other: RefCounted = AW_SCRIPT.new()
	other.init(gsm)

	aw.set("_gsm", null)
	assert_true(other.get("_gsm") != null, "另一实例的 _gsm 不受影响")

	aw.set("_battle_writes", null)
	assert_true(other.get("_battle_writes") != null, "另一实例的 _battle_writes 不受影响")
	# RefCounted 出作用域自动释放——不能 free()（那会报 "Attempted to free a RefCounted object"）。


func test_seam_wires_all_submodules() -> void:
	# 接缝仍接通：init() 之后三个子域委托全部就位（战斗 / 探索 / 叙事）。
	for field_name: String in EXPECTED_SUBMODULES:
		assert_not_null(aw.get(field_name), "init() 后 %s 应就位" % field_name)
	# 未 init 的新实例三个委托都还是空——证明它们是 init 接的，不是别处塞的。
	var raw: RefCounted = AW_SCRIPT.new()
	for field_name: String in EXPECTED_SUBMODULES:
		assert_null(raw.get(field_name), "未 init 时 %s 应为空" % field_name)


# ============================================================================
# 4. 消费通道：52 个名字在 GSM 实例上全部可按名解析
# ============================================================================

func test_every_method_is_reachable_through_gsm() -> void:
	# 本类唯一的消费者是 GSM 门面，它按名转发除 [method init] 之外的全部 51 个方法
	# （[method init] 是接缝装配口，GSM 在 [code]_init()[code] 里直接写
	# [code]_atomic_writes.init(self)[/code]，不经过同名 wrapper）。
	# 名字在链上解析得到 → 门面通路不断；解析不到 → 那些转发全部变成运行时 push_error。
	var missing: Array[String] = []
	for method_name: String in EXPECTED_PUBLIC:
		if method_name == "init":
			continue  # 装配口，GSM 直呼，无同名 wrapper —— 见下方 test_init_rewires_seam
		if not gsm.has_method(method_name):
			missing.append(method_name)
	for method_name: String in EXPECTED_PRIVATE:
		if not gsm.has_method(method_name):
			missing.append(method_name)
	assert_eq(missing.size(), 0, "GSM 门面应能解析全部 51 个转发名，缺失：%s" % str(missing))
	assert_eq(EXPECTED_PUBLIC.size() + EXPECTED_PRIVATE.size(), 52, "面应恰好 52 个方法")
	assert_eq(EXPECTED_PUBLIC.size() - 1 + EXPECTED_PRIVATE.size(), 51, "转发名应恰好 51 个")


func test_init_rewires_seam() -> void:
	# [method init] 是装配口——GSM 按名直呼它（[code]_atomic_writes.init(self)[/code]）。
	# 它必须仍在面上，且重复调用仍能把三个子域接回同一个 GSM。
	var fresh: RefCounted = AW_SCRIPT.new()
	assert_true(fresh.has_method("init"), "装配口 init 应仍在面上")
	fresh.init(gsm)
	fresh.init(gsm)
	for field_name: String in EXPECTED_SUBMODULES:
		assert_not_null(fresh.get(field_name), "重复 init 后 %s 仍应就位" % field_name)


# ============================================================================
# 5. 面仍然可调用：经 GSM 走一趟真写入
# ============================================================================

func test_face_still_callable_end_to_end() -> void:
	# 数值域：修为溢出进溢出池
	gsm.add_cultivation(gsm.BASE_MAX + 25)
	assert_eq(gsm.player.cultivation, gsm.BASE_MAX, "修为应顶到上限")
	assert_eq(gsm.player.overflow_pool, 25, "溢出部分应进溢出池")
	assert_true(gsm.player.cultivation_full, "应标记修为已满")

	# 身份 / 境界（第二层经 _set_by_path 写嵌套路径）
	gsm.set_identity(&"sword_immortal")
	assert_eq(gsm.player.identity_id, "sword_immortal", "身份应写入")
	gsm.change_realm(3)
	assert_eq(gsm.player.realm, 3, "境界应写入")

	# 卡牌收藏：校验未开启时拒绝写入
	assert_false(gsm.add_card_to_collection({"template_id": "t1"}),
		"校验未开启应拒绝写入")
	gsm.enable_validation({"t1": {"id": "t1"}})
	assert_true(gsm.add_card_to_collection({"template_id": "t1", "card_instance_id": 7}),
		"校验开启后应写入")
	assert_eq(gsm.collection.total_count, 1, "收藏计数应自增")
	assert_true(gsm.remove_card_from_collection(7), "应能按实例 ID 移除")
	assert_eq(gsm.collection.total_count, 0, "移除后计数应归零")

	# 会话 / 叙事 / 探索 域
	gsm.set_session_scene(4, "res://scenes/exploration.tscn")
	assert_eq(gsm.session.scene_id, 4, "场景 ID 应写入")
	gsm.set_narrative_flag(&"met_elder", true)
	assert_true(gsm.narrative.story_flags["met_elder"], "剧情 flag 应写入")
	gsm.set_exploration_ap(3, 5)
	assert_eq(gsm.exploration.action_points, 3, "行动力应写入")
	gsm.restore_action_points(5)
	assert_eq(gsm.exploration.action_points, 5, "恢复应夹到上限")

	# 天赋 / 卡组（枚举-字典两制）
	gsm.unlock_talent(&"talent_003")
	assert_true((gsm.player.talents as Array).has(&"talent_003"), "天赋应写入 talents")
	gsm.set_talent(&"ling_shi_boost", 15)
	assert_eq(gsm.player.talent_map[&"ling_shi_boost"], 15, "身份天赋效果应写入 talent_map")
	gsm._set_deck_cards([11, 12])
	assert_eq(gsm.deck.current_deck, [11, 12], "卡组应写入")
