extends GutTest
## 卡面 target_type → 目标选择策略（combat-ui-interaction 001 / 本轮）。[br]
## [br][b]背景[/b]：此前卡面 [code]target_type[/code] 是「只写不读」的资产字段——
## UI 一律接受多目标，单目标卡选两个目标也能出。本文件锁定词表 → 模式的映射，
## 以及「未知词不锁死」的兼容口径。[br]
## [br]纯函数——零依赖，不触碰 Autoload / 节点。

const Policy := preload("res://src/ui/combat/shared/combat_target_policy.gd")

## 资产目录里现存的词（锁白名单——新增词必须在本文件归类）。
const ASSET_VOCABULARY: Array = [&"single_enemy", &"self"]


## 资产现有词表全部被收录（且不是「未知」兜底）。
func test_asset_vocabulary_is_covered() -> void:
	for raw: StringName in ASSET_VOCABULARY:
		assert_ne(Policy.mode_of(raw), Policy.MODE_ANY,
				"资产词 %s 必须归类（不能落到未知兜底）" % raw)


## 单体敌方 → 需玩家点目标，且不允许持有多个。
func test_single_enemy_needs_one_target() -> void:
	assert_eq(Policy.mode_of(&"single_enemy"), Policy.MODE_SINGLE, "单体模式")
	assert_true(Policy.needs_player_target(&"single_enemy"), "需要玩家点目标")
	assert_false(Policy.allows_multiple(&"single_enemy"), "单目标卡不允许多选")
	assert_eq(Policy.describe(&"single_enemy"), "单体", "提示文案")


## 自身 → 无目标可选、不自动出（仍需玩家确认）。
func test_self_needs_no_target() -> void:
	assert_eq(Policy.mode_of(&"self"), Policy.MODE_SELF, "自身模式")
	assert_false(Policy.needs_player_target(&"self"), "自身不需要点目标")
	assert_false(Policy.allows_multiple(&"self"), "自身不持有多目标")
	assert_eq(Policy.describe(&"self"), "自身", "提示文案")


## 全体 → 系统填满目标、无需玩家点。
func test_all_enemy_fills_targets() -> void:
	assert_eq(Policy.mode_of(&"all_enemy"), Policy.MODE_AUTO_ALL, "全体模式")
	assert_true(Policy.fills_all(&"all_enemy"), "由系统填满")
	assert_false(Policy.needs_player_target(&"all_enemy"), "无需玩家点")
	assert_false(Policy.allows_multiple(&"all_enemy"), "不由玩家累加")


## 多选 → 允许持有多个，需玩家点。
func test_multi_enemy_allows_multiple() -> void:
	assert_eq(Policy.mode_of(&"multi_enemy"), Policy.MODE_MULTI, "多选模式")
	assert_true(Policy.needs_player_target(&"multi_enemy"), "需要玩家点")
	assert_true(Policy.allows_multiple(&"multi_enemy"), "允许多选")


## 空串 / 未收录词 → 未知模式（保持旧行为，不把卡锁死）。
func test_unknown_type_falls_back_to_any() -> void:
	assert_eq(Policy.mode_of(&""), Policy.MODE_ANY, "空串 → 未知")
	assert_eq(Policy.mode_of(&"random_enemy"), Policy.MODE_ANY, "随机敌方 → 未知（UI 不选）")
	assert_eq(Policy.mode_of(&"lowest_hp_enemy"), Policy.MODE_ANY, "条件选择 → 未知")
	assert_false(Policy.needs_player_target(&""), "未知词不强制点目标")
	assert_true(Policy.allows_multiple(&""), "未知词保持旧的多目标行为")
	assert_eq(Policy.describe(&""), "", "未知词无提示文案")


## 同义词收敛（资产历史写法不统一——只在映射层收敛一次）。
func test_aliases_normalize() -> void:
	assert_eq(Policy.mode_of(&"enemy"), Policy.MODE_SINGLE, "enemy → 单体敌方")
	assert_eq(Policy.mode_of(&"aoe_enemy"), Policy.MODE_AUTO_ALL, "aoe_enemy → 全体")
	assert_eq(Policy.mode_of(&"multi_target"), Policy.MODE_MULTI, "multi_target → 多选")
	assert_eq(Policy.normalize(&"  self  "), &"self", "去空白后收敛")


## 非字符串输入不崩（Variant 宽松兼容）。
func test_tolerates_non_string_input() -> void:
	assert_eq(Policy.mode_of(null), Policy.MODE_ANY, "null → 未知")
	assert_eq(Policy.mode_of(42), Policy.MODE_ANY, "整数 → 未知")
