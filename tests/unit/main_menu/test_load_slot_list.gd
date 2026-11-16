extends GutTest
## 主菜单「读档」列表的纯函数验收：`MainMenuLogic.loadable_slots`。[br]
## [br][b]为什么需要[/b]：主菜单此前没有「读档」这条路——玩家只能点「继续游戏」，
## 由 `select_latest_save` 按时间戳替他挑一格。本轮补上第三条路径，而「列哪几格、
## 每格写什么字、空的那几格怎么办」全部落在这个纯函数里（UI 只负责画）。[br]
## [br][b]覆盖[/b]：[br]
##   1. 四格固定清单与顺序（自动存档 + 手动 1-3）；[br]
##   2. 战前快照槽不进列表——它是战斗管线的中间产物，不是给玩家读的档；[br]
##   3. 空槽位也建条目并标「（空）」，`exists=false`（界面据此置灰）；[br]
##   4. 有档的槽位文案带摘要（境界 + 时长）；[br]
##   5. 空状态防御：null / 非数组 / 脏条目一律按「都空」返回，不崩。[br]
## [br]纯函数直调——无需场景树与 Autoload（先例 [code]test_continue_button_state.gd[/code]）。
##
## 来源: design/gdd/main-menu-system.md（新游戏 / 继续游戏 / 读档三条路径）。

const LOGIC := preload("res://src/ui/main_menu/main_menu_logic.gd")

## 槽位元数据工厂（`list_slots()` 返回契约镜像——测试数据在测试内定义）。
func _slot(slot_type: int, slot_id: int, exists: bool,
		realm: String = "炼气期", playtime: int = 3600) -> Dictionary:
	return {
		"slot_type": slot_type,
		"slot_id": slot_id,
		"exists": exists,
		"name": "测试存档",
		"timestamp": "2026-11-16T00:00:00",
		"realm": realm,
		"playtime": playtime,
	}


## 取某个 [code]slot_type/slot_id[/code] 的条目（找不到返回空字典）。
func _entry_of(entries: Array, slot_type: int, slot_id: int) -> Dictionary:
	for entry: Dictionary in entries:
		if int(entry["slot_type"]) == slot_type and int(entry["slot_id"]) == slot_id:
			return entry
	return {}


# ═══════════════════════════════════════════════════════════════════════════════
# 清单与顺序
# ═══════════════════════════════════════════════════════════════════════════════

func test_loadable_slots_lists_autosave_then_three_manual_slots() -> void:
	# Act——空列表也要给出完整四格（「你还能存到哪」本身是信息）
	var entries: Array[Dictionary] = LOGIC.loadable_slots([])
	# Assert
	assert_eq(entries.size(), 4, "读档列表应固定四格（自动存档 + 手动 1-3）")
	var keys: Array = []
	for entry: Dictionary in entries:
		keys.append([int(entry["slot_type"]), int(entry["slot_id"])])
	assert_eq(keys, [[0, 0], [1, 1], [1, 2], [1, 3]],
			"顺序应为自动存档在前、手动 1-3 依次（顺序即展示顺序）")


func test_loadable_slots_excludes_battle_snapshot_slot() -> void:
	## 战前快照是战斗管线的中间产物——让玩家从主菜单读一份「打之前的状态」
	## 既不是存档语义，也会和战斗恢复流程抢同一份文件。
	# Arrange——快照槽非空
	var meta: Array = [_slot(2, 0, true)]
	# Act
	var entries: Array[Dictionary] = LOGIC.loadable_slots(meta)
	# Assert
	for entry: Dictionary in entries:
		assert_ne(int(entry["slot_type"]), 2, "快照槽不得出现在读档列表里")
	assert_true(_entry_of(entries, 2, 0).is_empty(), "按快照槽键查表应落空")


# ═══════════════════════════════════════════════════════════════════════════════
# 每格的文案与启用态
# ═══════════════════════════════════════════════════════════════════════════════

func test_loadable_slots_empty_slot_is_listed_but_not_existing() -> void:
	# Act
	var entries: Array[Dictionary] = LOGIC.loadable_slots([])
	var auto: Dictionary = _entry_of(entries, 0, 0)
	var manual: Dictionary = _entry_of(entries, 1, 2)
	# Assert
	assert_false(bool(auto["exists"]), "空槽位的 exists 应为 false（界面据此置灰）")
	assert_eq(str(auto["label"]), "自动存档（空）", "空槽位应写出「（空）」")
	assert_eq(str(manual["label"]), "手动存档 2（空）", "手动槽空态文案应带槽号")


func test_loadable_slots_filled_slot_shows_summary() -> void:
	# Arrange——自动槽有档
	var meta: Array = [_slot(0, 0, true, "金丹期", 3600)]
	# Act
	var entries: Array[Dictionary] = LOGIC.loadable_slots(meta)
	var auto: Dictionary = _entry_of(entries, 0, 0)
	# Assert
	assert_true(bool(auto["exists"]), "有档的槽位 exists 应为 true")
	assert_eq(str(auto["label"]), "自动存档 — 上次：金丹期 · 游玩 1小时0分",
			"有档槽位应带摘要（境界 + 时长）")
	assert_false(str(auto["label"]).contains("（空）"), "有档槽位不得标空")


func test_loadable_slots_reads_each_slot_by_its_own_key() -> void:
	## 槽位键与 SaveLoadSystem._slot_key 同口径——错位会让手动 3 显示手动 1 的内容。
	# Arrange——只有手动 3 有档，其余全空
	var meta: Array = [
		_slot(0, 0, false), _slot(1, 1, false), _slot(1, 2, false),
		_slot(1, 3, true, "元婴期", 7200),
	]
	# Act
	var entries: Array[Dictionary] = LOGIC.loadable_slots(meta)
	# Assert
	assert_true(bool(_entry_of(entries, 1, 3)["exists"]), "手动 3 应判为有档")
	assert_false(bool(_entry_of(entries, 1, 2)["exists"]), "手动 2 不得被手动 3 的档顶替")
	assert_false(bool(_entry_of(entries, 0, 0)["exists"]), "自动槽不受牵连")
	assert_eq(str(_entry_of(entries, 1, 3)["label"]), "手动存档 3 — 上次：元婴期 · 游玩 2小时0分",
			"手动 3 的摘要应来自它自己那一格")


# ═══════════════════════════════════════════════════════════════════════════════
# 空状态防御
# ═══════════════════════════════════════════════════════════════════════════════

func test_loadable_slots_null_list_returns_four_empty_slots() -> void:
	## Autoload 缺失时 UI 层回退安全默认——四个空槽位，不崩、不臆造存档。
	# Act
	var entries: Array[Dictionary] = LOGIC.loadable_slots(null)
	# Assert
	assert_eq(entries.size(), 4, "null 入参应安全返回四格空槽")
	for entry: Dictionary in entries:
		assert_false(bool(entry["exists"]), "null 入参下不得出现「有档」的假象")


func test_loadable_slots_skips_invalid_entries_without_crashing() -> void:
	# Arrange——混入脏条目
	var meta: Array = ["corrupted_entry", 42, _slot(1, 1, true)]
	# Act
	var entries: Array[Dictionary] = LOGIC.loadable_slots(meta)
	# Assert
	assert_eq(entries.size(), 4, "脏条目应被跳过，清单仍为四格")
	assert_true(bool(_entry_of(entries, 1, 1)["exists"]), "有效条目仍应被识别")


func test_loadable_slots_unknown_slot_type_does_not_shadow_real_slots() -> void:
	## 未知槽位类型不得顶掉某个真槽位的条目（键冲突防御）。
	# Arrange
	var meta: Array = [
		{"slot_type": 7, "slot_id": 1, "exists": true, "realm": "化神期", "playtime": 1},
		_slot(1, 1, true, "筑基期", 60),
	]
	# Act
	var entries: Array[Dictionary] = LOGIC.loadable_slots(meta)
	# Assert
	assert_eq(str(_entry_of(entries, 1, 1)["label"]), "手动存档 1 — 上次：筑基期 · 游玩 0小时1分",
			"手动 1 应读到自己的档，而不是未知类型的条目")
