extends GutTest
## 「已游玩时长」端到端测试——唯一数据源 → 三条读取路径 → 落盘 → 读档续算。[br]
## [br][b]覆盖[/b]（对应本轮任务单的四条要求）：[br]
##   1. [b]单向对齐[/b]：计时器累计 Δ 之后，自动存档 meta、暂停菜单 meta
##      （[method SaveLoadSystem.build_slot_meta]）、存档容器顶层
##      [code]playtime_seconds[/code] 三处读到[b]同一个数[/b]；[br]
##   2. [b]往返[/b]：存 → 读 → 计时器基线等于存档值，再累加 Δ 后等于「存档值 + Δ」；[br]
##   3. [b]落盘闭环[/b]：meta.json 的槽位记录带上时长，主菜单摘要行据此显示；[br]
##   4. [b]负数/缺失防御[/b]：不含该字段的老档读进来仍是 0，不崩。[br]
## [br][b]注入时间源[/b]：[method SessionClock.advance] 是公开接缝——用例直接喂
## 固定 delta，不 await 真实帧、不等真时间。[br]
## [br][b]隔离[/b]：GSM 的 session / player 域在 before_each 快照、after_each 还原
## （Autoload 跨套件共享）；存档写在专用测试根目录，跑完删净。
##
## 来源: design/gdd/save-load-system.md §存档容器、design/gdd/achievement-system.md
## §ach_speed_run、任务单「playtime_seconds 三重缺失」修复。

const SLS := preload("res://src/foundation/save_load_system.gd")
const AutoSaveScript := preload("res://src/foundation/save_auto_save.gd")
const MainMenuLogic := preload("res://src/ui/main_menu/main_menu_logic.gd")

## 用例存档根目录——专用子目录，不动真实槽位。
const TEST_ROOT: String = "user://test_playtime_paths/"

## 用例初始时长（秒）——非整分钟，便于看出取整行为。
const SEED_SEC: int = 1234
## 往返用例累加的 Δ（整秒——用 advance 注入，不等真时间）。
const DELTA_SEC: int = 30

## 存档根可覆盖的 SLS 子类（[code]_get_save_root[/code] 是既定测试覆盖点）。
class TestSLS extends "res://src/foundation/save_load_system.gd":
	func _get_save_root() -> String:
		return "user://test_playtime_paths/"


var sls: Node = null
var gsm: Node = null
var clock: Node = null
var _session_before: Dictionary = {}
var _player_before: Dictionary = {}


func before_each() -> void:
	gsm = get_node_or_null(NodePath("/root/GameStateManager"))
	clock = get_node_or_null(NodePath("/root/SessionClock"))
	assert_not_null(gsm, "本套用例需要真实 GameStateManager Autoload")
	assert_not_null(clock, "本套用例需要真实 SessionClock Autoload（project.godot 已注册）")
	_session_before = (gsm.session as Dictionary).duplicate(true)
	_player_before = (gsm.player as Dictionary).duplicate(true)
	_remove_test_root()
	sls = TestSLS.new()
	sls._ready()


func after_each() -> void:
	gsm.session = _session_before.duplicate(true)
	gsm.player = _player_before.duplicate(true)
	clock.call(&"reset_remainder")
	_remove_test_root()
	if sls != null:
		sls.free()
		sls = null


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 单向对齐：三条路径读到同一个数
# ═══════════════════════════════════════════════════════════════════════════════

func test_three_readers_see_same_playtime_after_accumulate() -> void:
	# Arrange——把时长摆到一个已知值，再用注入的 delta 累加
	gsm.session["playtime_seconds"] = SEED_SEC
	clock.call(&"reset_remainder")
	var added: int = int(clock.call(&"advance", 5.0))
	assert_eq(added, 5, "注入 5.0s 应产出 5 整秒（零头已清零）")

	# Act——三条读取路径
	var source: int = int(gsm.session["playtime_seconds"])
	var autosave_meta: Dictionary = AutoSaveScript.new(sls).build_meta(gsm)
	var pause_meta: Dictionary = sls.call(&"build_slot_meta", gsm)
	var container: Dictionary = sls.call(&"_build_save_container",
			gsm.serialize(), {})

	# Assert——同一个数，不是「差不多」
	assert_eq(source, SEED_SEC + 5, "唯一数据源应是基线 + 累加值")
	assert_eq(int(autosave_meta.get("playtime_seconds", -1)), source,
			"自动存档 meta 应读同一个数")
	assert_eq(int(pause_meta.get("playtime_seconds", -1)), source,
			"暂停菜单 meta 应读同一个数")
	assert_eq(int(container.get("playtime_seconds", -1)), source,
			"存档容器顶层字段应读同一个数")


func test_pause_menu_meta_matches_autosave_meta() -> void:
	# 两者共用一个构建入口（build_slot_meta → SaveAutoSave.build_meta）
	gsm.session["playtime_seconds"] = SEED_SEC
	var autosave_meta: Dictionary = AutoSaveScript.new(sls).build_meta(gsm)
	var pause_meta: Dictionary = sls.call(&"build_slot_meta", gsm)
	assert_eq(pause_meta, autosave_meta, "两个入口应产出同一份 meta（无第二份口径）")


func test_container_playtime_is_zero_when_session_key_missing() -> void:
	# 老档 / 手工改过的内存状态——缺键不臆造时长
	gsm.session.erase("playtime_seconds")
	var container: Dictionary = sls.call(&"_build_save_container",
			gsm.serialize(), {})
	assert_eq(int(container.get("playtime_seconds", -1)), 0, "缺键应回落 0")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 往返：读档后基线 = 存档值，再累加 Δ = 存档值 + Δ
# ═══════════════════════════════════════════════════════════════════════════════

func test_load_restores_baseline_and_accumulates_from_it() -> void:
	# Arrange——存一份带时长的档（走真实写盘）
	gsm.session["playtime_seconds"] = SEED_SEC
	gsm.player["identity_id"] = "test_identity"
	assert_eq(int(sls.save_game(SLS.SaveSlotType.MANUAL, 1, gsm.serialize(),
			sls.call(&"build_slot_meta", gsm))), SLS.SaveResult.SUCCESS,
			"前置条件：真实载荷必须写得进存档")

	# Act——把内存改成另一个值（模拟「另一局」），再读回来
	gsm.session["playtime_seconds"] = 999999
	var load_result: Dictionary = sls.load_game(SLS.SaveSlotType.MANUAL, 1)
	assert_eq(int(load_result.get("result", -1)), SLS.LoadResult.SUCCESS,
			"读档应成功")

	# Assert——基线回到存档值
	var baseline: int = int(clock.call(&"seconds_played"))
	assert_eq(baseline, SEED_SEC, "读档后计时器基线应等于存档值（不是 0，也不是本局时长）")

	# Act——再累加 Δ（注入时间源）
	var added: int = int(clock.call(&"advance", float(DELTA_SEC)))
	# Assert——存档值 + Δ
	assert_eq(added, DELTA_SEC, "注入 Δ 应产出 Δ 整秒")
	assert_eq(int(clock.call(&"seconds_played")), SEED_SEC + DELTA_SEC,
			"累加后应等于「存档值 + Δ」")


func test_load_starts_from_zero_baseline_when_save_has_no_playtime() -> void:
	# 老档（不含时长字段）——读进来走默认 0，然后从 0 往上加
	gsm.session["playtime_seconds"] = 555
	gsm.player["identity_id"] = "test_identity"
	assert_eq(int(sls.save_game(SLS.SaveSlotType.MANUAL, 2, gsm.serialize(), {})),
			SLS.SaveResult.SUCCESS, "前置条件：写得进")
	gsm.session["playtime_seconds"] = 777
	assert_eq(int(sls.load_game(SLS.SaveSlotType.MANUAL, 2).get("result", -1)),
			SLS.LoadResult.SUCCESS, "读档应成功")
	assert_eq(int(clock.call(&"seconds_played")), 555,
			"基线应等于存档里的值（555），不是读档前的 777")
	clock.call(&"advance", 3.0)
	assert_eq(int(clock.call(&"seconds_played")), 558, "再累加 3 应为 558")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 落盘闭环：meta.json 带时长 → 主菜单摘要行显示
# ═══════════════════════════════════════════════════════════════════════════════

func test_saved_slot_meta_feeds_main_menu_summary() -> void:
	# 3700s = 1小时1分——验证「写进去的是这个数，读出来显示的也是这个」
	gsm.session["playtime_seconds"] = 3700
	gsm.player["identity_id"] = "test_identity"
	assert_eq(int(sls.save_game(SLS.SaveSlotType.MANUAL, 1, gsm.serialize(),
			sls.call(&"build_slot_meta", gsm))), SLS.SaveResult.SUCCESS,
			"前置条件：写得进")

	var latest: Dictionary = MainMenuLogic.select_latest_save(sls.list_slots())
	assert_eq(int(latest.get("playtime", -1)), 3700,
			"meta.json 槽位记录应带出时长——主菜单读的正是这一份")
	var summary: String = MainMenuLogic.build_save_summary(latest)
	assert_true(summary.ends_with("· 游玩 1小时1分"),
			"摘要行应收尾于「游玩 1小时1分」，实得：%s" % summary)


func test_saved_slot_meta_below_one_minute_shows_sub_minute_text() -> void:
	gsm.session["playtime_seconds"] = 59
	gsm.player["identity_id"] = "test_identity"
	assert_eq(int(sls.save_game(SLS.SaveSlotType.MANUAL, 1, gsm.serialize(),
			sls.call(&"build_slot_meta", gsm))), SLS.SaveResult.SUCCESS,
			"前置条件：写得进")
	var summary: String = MainMenuLogic.build_save_summary(
			MainMenuLogic.select_latest_save(sls.list_slots()))
	assert_true(summary.ends_with("· 游玩不到 1 分钟"),
			"59 秒应收尾于「游玩不到 1 分钟」（连写、不带空格），实得：%s" % summary)


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 读档清理 input_locks（session 变成持久域后的副作用收尾）
# ═══════════════════════════════════════════════════════════════════════════════

func test_load_clears_session_input_locks() -> void:
	# session 现在会落盘，而 input_locks 是运行时的锁镜像——读档后必须清空，
	# 否则 InputManager.has_lock 会照着一份过期的锁栈说谎
	gsm.session["playtime_seconds"] = 10
	gsm.session["input_locks"] = ["scene_manager", "combat_system"]
	gsm.player["identity_id"] = "test_identity"
	assert_eq(int(sls.save_game(SLS.SaveSlotType.MANUAL, 3, gsm.serialize(), {})),
			SLS.SaveResult.SUCCESS, "前置条件：写得进")
	assert_eq(int(sls.load_game(SLS.SaveSlotType.MANUAL, 3).get("result", -1)),
			SLS.LoadResult.SUCCESS, "读档应成功")
	assert_eq(gsm.session.get("input_locks", ["<缺键>"]), [],
			"读档后 input_locks 应清空")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 删除测试存档根目录（含文件）。
func _remove_test_root() -> void:
	if not DirAccess.dir_exists_absolute(TEST_ROOT):
		return
	var dir: DirAccess = DirAccess.open(TEST_ROOT)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			DirAccess.remove_absolute(TEST_ROOT + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(TEST_ROOT)
